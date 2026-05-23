

#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$HOME/audiocraft-local"
VENV_DIR="$PROJECT_DIR/.venv"
TOOLS_DIR="$PROJECT_DIR/.tools"
UV_DIR="$TOOLS_DIR/uv-bin"
UV_BIN="$UV_DIR/uv"
OUTPUT_DIR="$PROJECT_DIR/outputs"

PROMPT="${1:-dark fantasy dungeon ambience with distant choir}"
DURATION="${2:-10}"
MODEL="${3:-facebook/musicgen-small}"
KIND="${4:-auto}"

# KIND:
#   auto  = detect from model name
#   music = force MusicGen
#   sfx   = force AudioGen

if [[ "$MODEL" == "sfx" || "$MODEL" == "audiogen" ]]; then
  MODEL="facebook/audiogen-medium"
  KIND="sfx"
fi

if [[ "$MODEL" == "music" || "$MODEL" == "musicgen" ]]; then
  MODEL="facebook/musicgen-medium"
  KIND="music"
fi

mkdir -p "$PROJECT_DIR" "$TOOLS_DIR" "$OUTPUT_DIR"
cd "$PROJECT_DIR"

echo "AudioCraft local directory: $PROJECT_DIR"
echo "Prompt: $PROMPT"
echo "Duration: $DURATION seconds"
echo "Model: $MODEL"
echo "Kind: $KIND"
echo ""

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage:
  ./run_audiocraft.sh "prompt" duration model kind

Examples:

  Music:
    ./run_audiocraft.sh "ancient roman battle music, war drums and horns" 30 facebook/musicgen-medium music

  Sound effects:
    ./run_audiocraft.sh "arrows whistling overhead, impacts into wooden shields, dry foley recording" 5 facebook/audiogen-medium sfx

  Shortcut for AudioGen:
    ./run_audiocraft.sh "horse cavalry charge, galloping, dust, shouting soldiers" 5 sfx

Arguments:
  prompt    Text prompt
  duration  Seconds
  model     Hugging Face model name, or shortcut: sfx/music
  kind      auto/music/sfx

Recommended models:
  facebook/musicgen-small
  facebook/musicgen-medium
  facebook/musicgen-large
  facebook/audiogen-medium
EOF
  exit 0
fi

echo "Checking required system tools..."

if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  echo "Installing required system tools..."
  sudo apt update
  sudo apt install -y \
    curl \
    ffmpeg \
    pkg-config \
    build-essential \
    libavformat-dev \
    libavcodec-dev \
    libavdevice-dev \
    libavutil-dev \
    libavfilter-dev \
    libswscale-dev \
    libswresample-dev
fi

if [ ! -x "$UV_BIN" ]; then
  echo "Installing uv locally inside project..."
  mkdir -p "$UV_DIR"
  curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR="$UV_DIR" sh
fi

export UV_CACHE_DIR="$PROJECT_DIR/.uv-cache"
export UV_PYTHON_INSTALL_DIR="$PROJECT_DIR/.uv-python"

echo "Installing private Python 3.10 with uv..."
"$UV_BIN" python install 3.10

RECREATE_VENV=0

if [ ! -x "$VENV_DIR/bin/python" ]; then
  RECREATE_VENV=1
else
  CURRENT_VERSION="$("$VENV_DIR/bin/python" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"

  if [ "$CURRENT_VERSION" != "3.10" ]; then
    echo "Existing venv uses Python $CURRENT_VERSION. Recreating with Python 3.10..."
    RECREATE_VENV=1
  elif ! "$VENV_DIR/bin/python" -m pip --version >/dev/null 2>&1; then
    echo "Existing venv has no pip. Recreating with pip seeded..."
    RECREATE_VENV=1
  fi
fi

if [ "$RECREATE_VENV" = "1" ]; then
  rm -rf "$VENV_DIR"
  echo "Creating private Python 3.10 venv with pip..."
  "$UV_BIN" venv --seed --python 3.10 "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

echo "Using Python:"
python --version
which python
echo ""

echo "Installing package tools..."
python -m pip install --upgrade "pip<25" setuptools wheel packaging

echo ""
echo "Installing PyTorch CUDA 12.8 for RTX 50-series..."
python -m pip install --upgrade \
  torch torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu128

echo ""
echo "Installing AudioCraft without old pinned torch dependencies..."
python -m pip install --no-deps audiocraft==1.3.0

echo ""
echo "Installing AudioCraft runtime dependencies manually..."
python -m pip install \
  "numpy<2.0.0" \
  "av==11.0.0" \
  einops \
  "flashy>=0.0.1" \
  "hydra-core>=1.1" \
  hydra_colorlog \
  julius \
  num2words \
  sentencepiece \
  "spacy==3.7.6" \
  huggingface_hub \
  tqdm \
  "transformers>=4.31.0,<4.58" \
  demucs \
  librosa \
  soundfile \
  gradio \
  torchmetrics \
  encodec \
  protobuf \
  pesq \
  pystoi \
  torchdiffeq

echo ""
echo "Forcing PyTorch CUDA 12.8 again in case another package touched it..."
python -m pip install --upgrade \
  torch torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu128

echo ""
echo "Patching AudioCraft to run without xformers..."
python - <<'PY'
from pathlib import Path
import sys

site_packages = Path(sys.prefix) / "lib"
matches = list(site_packages.glob("python*/site-packages/audiocraft/modules/transformer.py"))

if not matches:
    raise SystemExit("Could not find audiocraft/modules/transformer.py")

path = matches[0]
text = path.read_text()

if "class _AudioCraftXformersOpsFallback" not in text:
    text = text.replace(
        "from xformers import ops",
        """try:
    from xformers import ops
except Exception:
    class _AudioCraftXformersOpsFallback:
        @staticmethod
        def unbind(x, dim=0):
            return torch.unbind(x, dim=dim)

        @staticmethod
        def memory_efficient_attention(*args, **kwargs):
            raise RuntimeError(
                "xformers is not installed. AudioCraft has been patched to use PyTorch attention instead."
            )

    ops = _AudioCraftXformersOpsFallback()"""
    )

if "if _efficient_attention_backend == 'torch':\n                if current_steps == 1:" not in text:
    text = text.replace(
        """        if self.memory_efficient:
            from xformers.ops import LowerTriangularMask
""",
        """        if self.memory_efficient:
            if _efficient_attention_backend == 'torch':
                if current_steps == 1:
                    return None
                return torch.empty(0, device=device, dtype=dtype)
            from xformers.ops import LowerTriangularMask
"""
    )

if "def _verify_xformers_memory_efficient_compat():\n    if _efficient_attention_backend == 'torch':" not in text:
    text = text.replace(
        """def _verify_xformers_memory_efficient_compat():
    try:
""",
        """def _verify_xformers_memory_efficient_compat():
    if _efficient_attention_backend == 'torch':
        return
    try:
"""
    )

if "self.checkpointing.startswith('xformers') and _efficient_attention_backend == 'torch'" not in text:
    text = text.replace(
        """        self.checkpointing = checkpointing
        assert checkpointing in ['none', 'torch', 'xformers_default', 'xformers_mm']
""",
        """        self.checkpointing = checkpointing
        if self.checkpointing.startswith('xformers') and _efficient_attention_backend == 'torch':
            self.checkpointing = 'none'
        assert self.checkpointing in ['none', 'torch', 'xformers_default', 'xformers_mm']
"""
    )

path.write_text(text)
print(f"Patched: {path}")
PY

echo ""
echo "Checking GPU support..."
python - <<'PY'
import torch

print("Torch:", torch.__version__)
print("Torch CUDA runtime:", torch.version.cuda)
print("CUDA available:", torch.cuda.is_available())

if not torch.cuda.is_available():
    raise SystemExit("CUDA is not available. Check NVIDIA driver.")

print("GPU:", torch.cuda.get_device_name(0))
print("Capability:", torch.cuda.get_device_capability(0))

x = torch.randn((1024, 1024), device="cuda")
y = x @ x
torch.cuda.synchronize()
print("CUDA tensor test: OK")
PY

echo ""
echo "Generating audio..."

python - "$PROMPT" "$DURATION" "$MODEL" "$OUTPUT_DIR" "$KIND" <<'PY'
import sys
import re
import time
from pathlib import Path

import torch

from audiocraft.modules.transformer import set_efficient_attention_backend
set_efficient_attention_backend("torch")

from audiocraft.models import MusicGen, AudioGen
from audiocraft.data.audio import audio_write

prompt = sys.argv[1]
duration = int(float(sys.argv[2]))
model_name = sys.argv[3]
output_dir = Path(sys.argv[4])
kind = sys.argv[5].lower().strip()

output_dir.mkdir(parents=True, exist_ok=True)

safe_prompt = re.sub(r"[^a-zA-Z0-9_-]+", "_", prompt.lower()).strip("_")[:60]
safe_model = re.sub(r"[^a-zA-Z0-9_-]+", "_", model_name.lower()).strip("_")[:40]

if not safe_prompt:
    safe_prompt = "audiocraft_output"

device = "cuda" if torch.cuda.is_available() else "cpu"

if kind == "auto":
    lower_model = model_name.lower()

    if "audiogen" in lower_model:
        kind = "sfx"
    elif "musicgen" in lower_model:
        kind = "music"
    else:
        raise SystemExit(
            f"Could not auto-detect model type from: {model_name}\n"
            "Pass kind explicitly as the 4th argument: music or sfx"
        )

if kind in {"sfx", "sound", "soundfx", "audiogen"}:
    model_class = AudioGen
    resolved_kind = "sfx"
elif kind in {"music", "musicgen"}:
    model_class = MusicGen
    resolved_kind = "music"
else:
    raise SystemExit(
        f"Unknown kind: {kind}\n"
        "Use: auto, music, or sfx"
    )

print(f"Loading model on: {device}")
print(f"Resolved kind: {resolved_kind}")
print(f"Model class: {model_class.__name__}")
print(f"Model name: {model_name}")

model = model_class.get_pretrained(model_name, device=device)
model.set_generation_params(duration=duration)

print("Generating...")
with torch.no_grad():
    wav = model.generate([prompt])

timestamp = time.strftime("%Y%m%d_%H%M%S")
out_base = output_dir / f"{resolved_kind}_{safe_model}_{safe_prompt}_{timestamp}"

audio_write(
    str(out_base),
    wav[0].cpu(),
    model.sample_rate,
    strategy="loudness",
    loudness_compressor=True,
)

print(f"Generated: {out_base}.wav")
PY

echo ""
echo "Done."
echo "Output folder:"
echo "$OUTPUT_DIR"

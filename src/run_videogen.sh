

#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$HOME/videogen-local"
VENV_DIR="$PROJECT_DIR/.venv"
TOOLS_DIR="$PROJECT_DIR/.tools"
UV_DIR="$TOOLS_DIR/uv-bin"
UV_BIN="$UV_DIR/uv"
OUTPUT_DIR="$PROJECT_DIR/outputs"
INPUT_DIR="$PROJECT_DIR/inputs"

PROMPT="${1:-dark fantasy commander, tactical briefing, cel shaded game cinematic, subtle camera push in}"
DURATION="${2:-2}"
MODEL="${3:-Lightricks/LTX-Video}"
REFERENCE_IMAGE="${4:-}"

# Low-VRAM defaults for an ~8GB GPU.
WIDTH="${WIDTH:-512}"
HEIGHT="${HEIGHT:-320}"
FPS="${FPS:-12}"
STEPS="${STEPS:-20}"
GUIDANCE="${GUIDANCE:-3.0}"
SEED="${SEED:-12345}"
MAX_SEQUENCE_LENGTH="${MAX_SEQUENCE_LENGTH:-128}"

STYLE_LOCK="${STYLE_LOCK:-stylized dark fantasy strategy game cinematic, same recognizable commander face, same armor silhouette, same faction colors, clean readable design, non-realistic, high quality game cutscene}"

NEGATIVE_PROMPT="${NEGATIVE_PROMPT:-worst quality, low quality, blurry, jittery, distorted face, changing face, changing armor, inconsistent costume, extra fingers, bad hands, text, subtitles, watermark, logo}"

# Optional LoRA settings.
LORA_PATH="${LORA_PATH:-}"
LORA_WEIGHT_NAME="${LORA_WEIGHT_NAME:-}"
LORA_SCALE="${LORA_SCALE:-0.8}"

mkdir -p "$PROJECT_DIR" "$TOOLS_DIR" "$OUTPUT_DIR" "$INPUT_DIR"
cd "$PROJECT_DIR"

export HF_HOME="$PROJECT_DIR/.hf-cache"
export HF_HUB_ENABLE_HF_TRANSFER=1
export UV_CACHE_DIR="$PROJECT_DIR/.uv-cache"
export UV_PYTHON_INSTALL_DIR="$PROJECT_DIR/.uv-python"

# Helps reduce CUDA memory fragmentation.
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

cat <<EOF
VideoGen local directory: $PROJECT_DIR
Prompt: $PROMPT
Duration: $DURATION seconds
Model: $MODEL
Reference image: ${REFERENCE_IMAGE:-none - text-to-video mode}
Resolution: ${WIDTH}x${HEIGHT}
FPS: $FPS
Steps: $STEPS
Guidance: $GUIDANCE
Seed: $SEED
Max sequence length: $MAX_SEQUENCE_LENGTH
EOF

echo ""

if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1; then
  echo "Installing required system tools..."
  sudo apt update
  sudo apt install -y \
    curl \
    git \
    ffmpeg \
    pkg-config \
    build-essential
fi

if [ ! -x "$UV_BIN" ]; then
  echo "Installing uv locally inside project..."
  mkdir -p "$UV_DIR"
  curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR="$UV_DIR" sh
fi

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
echo "Installing video generation dependencies..."
python -m pip install --upgrade \
  accelerate \
  transformers \
  sentencepiece \
  protobuf \
  safetensors \
  "huggingface_hub[hf_transfer]" \
  hf_transfer \
  imageio \
  imageio-ffmpeg \
  pillow \
  numpy \
  ftfy

echo ""
echo "Installing latest Diffusers from GitHub for LTX offloading support..."
python -m pip install --upgrade git+https://github.com/huggingface/diffusers.git

echo ""
echo "Forcing PyTorch CUDA 12.8 again in case another package touched it..."
python -m pip install --upgrade \
  torch torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu128

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
print("VRAM total GB:", round(torch.cuda.get_device_properties(0).total_memory / 1024**3, 2))

x = torch.randn((1024, 1024), device="cuda")
y = x @ x
torch.cuda.synchronize()
print("CUDA tensor test: OK")
PY

echo ""
echo "Generating video..."

python - "$PROMPT" "$DURATION" "$MODEL" "$REFERENCE_IMAGE" "$OUTPUT_DIR" <<'PY'
import gc
import math
import os
import re
import sys
from pathlib import Path

import torch
from diffusers import LTXImageToVideoPipeline, LTXPipeline, AutoModel
from diffusers.hooks import apply_group_offloading
from diffusers.utils import export_to_video, load_image

prompt = sys.argv[1]
duration = float(sys.argv[2])
model_name = sys.argv[3]
reference_image = sys.argv[4].strip()
output_dir = Path(sys.argv[5])
output_dir.mkdir(parents=True, exist_ok=True)

width = int(os.environ.get("WIDTH", "512"))
height = int(os.environ.get("HEIGHT", "320"))
fps = int(os.environ.get("FPS", "12"))
steps = int(os.environ.get("STEPS", "20"))
guidance = float(os.environ.get("GUIDANCE", "3.0"))
seed = int(os.environ.get("SEED", "12345"))
max_sequence_length = int(os.environ.get("MAX_SEQUENCE_LENGTH", "128"))

style_lock = os.environ.get("STYLE_LOCK", "").strip()
negative_prompt = os.environ.get(
    "NEGATIVE_PROMPT",
    "worst quality, low quality, blurry, jittery, distorted face, changing face, changing armor, inconsistent costume, text, watermark, logo"
)

lora_path = os.environ.get("LORA_PATH", "").strip()
lora_weight_name = os.environ.get("LORA_WEIGHT_NAME", "").strip()
lora_scale = float(os.environ.get("LORA_SCALE", "0.8"))

# LTX prefers frame counts of 8n + 1.
requested_frames = max(9, int(math.ceil(duration * fps)))
num_frames = ((requested_frames - 1 + 7) // 8) * 8 + 1

full_prompt = f"{style_lock}. {prompt}" if style_lock else prompt
safe_name = re.sub(r"[^a-zA-Z0-9_-]+", "_", prompt.lower()).strip("_")[:70] or "videogen_output"

if not torch.cuda.is_available():
    raise SystemExit("CUDA is not available. Check NVIDIA driver.")

print("CUDA device:", torch.cuda.get_device_name(0))
print("VRAM total GB:", round(torch.cuda.get_device_properties(0).total_memory / 1024**3, 2))
print("Using low-VRAM LTX mode:")
print("- fp8 layerwise casting")
print("- transformer group offload")
print("- text encoder group offload")
print("- VAE group offload")
print("")
print(f"Resolution: {width}x{height}")
print(f"Frames: {num_frames} at {fps} fps")
print(f"Steps: {steps}")
print(f"Max sequence length: {max_sequence_length}")

torch.cuda.empty_cache()
gc.collect()

print("")
print("Loading transformer with fp8 layerwise casting...")
transformer = AutoModel.from_pretrained(
    model_name,
    subfolder="transformer",
    torch_dtype=torch.bfloat16,
)

transformer.enable_layerwise_casting(
    storage_dtype=torch.float8_e4m3fn,
    compute_dtype=torch.bfloat16,
)

if reference_image:
    ref_path = Path(reference_image).expanduser()
    if not ref_path.exists():
        raise SystemExit(f"Reference image not found: {ref_path}")

    print(f"Loading LTX image-to-video pipeline: {model_name}")
    pipe = LTXImageToVideoPipeline.from_pretrained(
        model_name,
        transformer=transformer,
        torch_dtype=torch.bfloat16,
    )
    mode = "image-to-video"
else:
    ref_path = None
    print(f"Loading LTX text-to-video pipeline: {model_name}")
    pipe = LTXPipeline.from_pretrained(
        model_name,
        transformer=transformer,
        torch_dtype=torch.bfloat16,
    )
    mode = "text-to-video"

print("")
print("Applying group offload...")
onload_device = torch.device("cuda")
offload_device = torch.device("cpu")

pipe.transformer.enable_group_offload(
    onload_device=onload_device,
    offload_device=offload_device,
    offload_type="leaf_level",
    use_stream=True,
)

# This is the key fix for your crash:
# avoid moving the entire T5 text encoder onto the GPU at once.
apply_group_offloading(
    pipe.text_encoder,
    onload_device=onload_device,
    offload_type="block_level",
    num_blocks_per_group=1,
)

apply_group_offloading(
    pipe.vae,
    onload_device=onload_device,
    offload_type="leaf_level",
)

for method_name in ("enable_vae_slicing", "enable_vae_tiling"):
    method = getattr(pipe, method_name, None)
    if callable(method):
        try:
            method()
            print(f"Enabled {method_name}")
        except Exception as exc:
            print(f"Could not enable {method_name}: {exc}")

if lora_path:
    print("")
    print(f"Loading LoRA: {lora_path}")
    kwargs = {"adapter_name": "commander"}
    if lora_weight_name:
        kwargs["weight_name"] = lora_weight_name

    pipe.load_lora_weights(lora_path, **kwargs)
    pipe.set_adapters(["commander"], adapter_weights=[lora_scale])

generator = torch.Generator(device="cuda").manual_seed(seed)

print("")
print(f"Mode: {mode}")
print(f"Prompt: {full_prompt}")
print("")

call_kwargs = dict(
    prompt=full_prompt,
    negative_prompt=negative_prompt,
    width=width,
    height=height,
    num_frames=num_frames,
    num_inference_steps=steps,
    guidance_scale=guidance,
    generator=generator,
    max_sequence_length=max_sequence_length,
)

if ref_path is not None:
    image = load_image(str(ref_path)).convert("RGB")
    call_kwargs["image"] = image

try:
    result = pipe(
        **call_kwargs,
        decode_timestep=float(os.environ.get("DECODE_TIMESTEP", "0.03")),
        decode_noise_scale=float(os.environ.get("DECODE_NOISE_SCALE", "0.025")),
    )
except TypeError:
    # Older/newer Diffusers builds may reject decode_timestep or decode_noise_scale.
    result = pipe(**call_kwargs)

video = result.frames[0]
out_path = output_dir / f"{safe_name}_seed{seed}_{num_frames}f.mp4"
export_to_video(video, str(out_path), fps=fps)

print(f"Generated: {out_path}")
PY

echo ""
echo "Done."
echo "Output folder:"
echo "$OUTPUT_DIR"

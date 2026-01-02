# Hooks

This directory contains scripts that can be used as pre-commit hooks or CI checks to maintain code quality in the repository.

## Overview

The hooks are designed to automatically check and fix common issues in bash scripts, such as:
- Removing carriage return characters (Windows line endings)
- Ensuring files end with exactly one empty line
- Removing trailing whitespaces
- Formatting and linting bash scripts

## Usage

### Running All Hooks

To run all hooks in check mode (without modifying files):

```bash
./hooks/_run_all.sh
```

This will execute all hooks with the `--check` option on the `src` directory. It will exit with status 1 if any checks fail.

### Running Individual Hooks

Each hook can be run individually with the following syntax:

```bash
./hooks/<hook_name>.sh [--check] <path>
```

- `--check`: Only check if changes are needed, do not modify files
- `<path>`: File or directory to process

**Examples:**

```bash
# Check a single file for carriage returns
./hooks/remove_carriage_return.sh --check src/my_script.sh

# Remove trailing whitespaces from all files in src directory
./hooks/remove_trailing_whitespaces.sh src

# Check if all files end with exactly one empty line
./hooks/last_line_empty.sh --check src
```

## Available Hooks

### beautify_script.sh
Formats shell scripts using Beautysh and analyzes them with ShellCheck.

**Requirements:**
- `beautysh` - Install with `pip3 install beautysh`
- `shellcheck` - Install with `apt-get install shellcheck` (Debian/Ubuntu)

### remove_carriage_return.sh
Removes carriage return characters (`\r`) from files. This is useful for files that may have been edited on Windows systems.

### last_line_empty.sh
Ensures that all files end with exactly one empty line. This is a common convention in many projects.

### remove_trailing_whitespaces.sh
Removes trailing whitespace characters (spaces or tabs) from the end of lines in files.

## Integration

### CI/CD Integration

These hooks are automatically run in the CI pipeline (see `.github/workflows/blank.yml`). The CI will fail if any checks don't pass.

### Git Pre-commit Hook (Optional)

To run these checks before every commit, you can create a git pre-commit hook:

```bash
cat > .git/hooks/pre-commit << 'EOF'
#!/usr/bin/env bash
./hooks/_run_all.sh
EOF
chmod +x .git/hooks/pre-commit
```

This will automatically run all hooks before each commit. If any checks fail, the commit will be aborted.

## How It Works

The scripts in this directory are actually symbolic links to the corresponding scripts in the `src` directory. This allows the same scripts to be used both as utility scripts and as hooks.

The `_run_all.sh` script:
1. Finds all symbolic links in the `hooks` directory (excluding files starting with `_`)
2. Executes each script with the `--check` flag
3. Collects the exit status of all scripts
4. Exits with status 1 if any check failed

## Troubleshooting

If a hook fails in CI or locally:

1. Read the error message to understand which check failed
2. Run the specific hook without `--check` to automatically fix the issue:
   ```bash
   ./hooks/<hook_name>.sh src
   ```
3. Commit the changes and try again

## Note

All hooks respect the `--check` flag. When used with `--check`, they will only report issues without modifying files. Without this flag, they will automatically fix the issues.

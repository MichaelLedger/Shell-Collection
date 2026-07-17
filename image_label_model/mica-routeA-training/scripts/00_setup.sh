#!/usr/bin/env bash
# Create the Python venv and install dependencies.
# Requires Python 3.11 (TensorFlow / coremltools wheels). Override with PYTHON=...
source "$(dirname "$0")/../config.sh"

PYTHON="${PYTHON:-python3.11}"
if ! command -v "$PYTHON" >/dev/null 2>&1; then
  echo "ERROR: $PYTHON not found. Install Python 3.11 (e.g. 'brew install python@3.11')"
  echo "or set PYTHON=/path/to/python3.11 before running."
  exit 1
fi

echo "Creating venv at $VENV_DIR using $($PYTHON --version)"
"$PYTHON" -m venv "$VENV_DIR"
activate_venv
python -m pip install --upgrade pip
python -m pip install -r "$ROUTEA_ROOT/requirements.txt"

echo
echo "Setup complete. Verify:"
python -c "import tensorflow as tf, coremltools, fiftyone; print('tf', tf.__version__, '| coremltools', coremltools.__version__)"

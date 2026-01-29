#!/bin/bash

# Whisper Server Launcher
# Starts Whisper server with large-v3 model

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WHISPER_DIR="$SCRIPT_DIR/whisper.cpp"
MODEL_PATH="$WHISPER_DIR/models/ggml-large-v3.bin"
SERVER_PATH="$WHISPER_DIR/build/bin/whisper-server"

# Check if whisper.cpp directory exists
if [[ ! -d "$WHISPER_DIR" ]]; then
    echo "Error: whisper.cpp directory not found at $WHISPER_DIR"
    echo "Please clone whisper.cpp first:"
    echo "  git clone https://github.com/ggml-org/whisper.cpp"
    exit 1
fi

# Check if model file exists
if [[ ! -f "$MODEL_PATH" ]]; then
    echo "Error: Model file not found at $MODEL_PATH"
    echo "Please download the model first:"
    echo "  cd $WHISPER_DIR"
    echo "  ./models/download-ggml-model.sh large-v3"
    exit 1
fi

# Check if server executable exists
if [[ ! -f "$SERVER_PATH" ]]; then
    echo "Error: whisper-server not found. Please build whisper.cpp first:"
    echo "  cd $WHISPER_DIR"
    echo "  cmake -B build -DGGML_CUDA=1 -DCMAKE_CUDA_ARCHITECTURES=\"121\""
    echo "  cmake --build build -j --config Release"
    exit 1
fi

# Start the server
echo "Starting Whisper server with large-v3 model..."
echo "Model: $MODEL_PATH"
echo "Server listening on: http://0.0.0.0:8025"
echo "Press Ctrl+C to stop the server"

cd "$WHISPER_DIR"
"$SERVER_PATH" -m "$MODEL_PATH" --host 0.0.0.0 --port 8025

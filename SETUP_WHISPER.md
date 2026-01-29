# Whisper Server Setup Guide

See documentation at:
- [Llama.cpp Discussion 16514](https://github.com/ggml-org/llama.cpp/discussions/16514)
- [Whisper.cpp Repository](https://github.com/ggml-org/whisper.cpp)

## Whisper Models

Available models for download:

```bash
tiny
tiny.en
tiny-q5_1
tiny.en-q5_1
tiny-q8_0
base
base.en
base-q5_1
base.en-q5_1
base-q8_0
small
small.en
small.en-tdrz
small-q5_1
small.en-q5_1
small-q8_0
medium
medium.en
medium-q5_0
medium.en-q5_0
medium-q8_0
large-v1
large-v2
large-v2-q5_0
large-v2-q8_0
large-v3
large-v3-q5_0
large-v3-turbo
large-v3-turbo-q5_0
large-v3-turbo-q8_0
```

**Choosing a model:**
- **Tiny/Base/Small**: Fast inference, lower memory usage, suitable for quick tasks and resource-constrained environments
- **Medium**: Better accuracy, higher memory requirements
- **Large-v3/Large-v3-turbo**: Highest accuracy, highest memory requirements (recommended for production use)

**Quantization options (Q5/Q8):**
- Reduced file size and memory footprint
- Slight trade-off in accuracy (usually negligible for most use cases)
- Q5 (default): Good balance of size and accuracy
- Q8: Smaller size, minimal accuracy loss, maximum compression

**Note:** The model file name must match exactly when starting the server (e.g., use `large-v3` for `large-v3.bin`, `large-v3-turbo-q5_0` for `large-v3-turbo-q5_0.bin`)

## Installation

```bash
git clone https://github.com/ggml-org/whisper.cpp
cd whisper.cpp

cmake -B build -DGGML_CUDA=1 -DCMAKE_CUDA_ARCHITECTURES="121"
cmake --build build -j --config Release

./models/download-ggml-model.sh large-v3
```

## Starting the Server

**Tip:** You can also use the provided launcher script:
**Note:** Make sure the script is executable first: `chmod +x start_whisper_server.sh`
```bash
./start_whisper_server.sh
```

### From project root
```bash
whisper.cpp/build/bin/whisper-server -m whisper.cpp/models/ggml-large-v3.bin --host 0.0.0.0 --port 8025
```

## Running the Gradio Application

```bash
uv sync
uv run python whisper_app.py
```

## Troubleshooting

If you encounter issues, try installing these dependencies **only if needed**:

```bash
sudo apt-get update
sudo apt-get install libportaudio2 portaudio19-dev
sudo apt-get install libsdl2-dev
```

**Note:** These dependencies should only be installed if you're experiencing actual problems. If everything works without errors, no installation is required.

see docs here : https://github.com/ggml-org/llama.cpp/discussions/16514, https://github.com/ggml-org/whisper.cpp

git clone https://github.com/ggml-org/whisper.cpp

cd whisper.cpp

cmake -B build -DGGML_CUDA=1 -DCMAKE_CUDA_ARCHITECTURES="121"
cmake --build build -j --config Release

./models/download-ggml-model.sh large-v3

./build/bin/whisper-server -m ./models/ggml-large-v3.bin 
or 
whisper.cpp/build/bin/whisper-server -m whisper.cpp/models/ggml-large-v3.bin --host 0.0.0.0 --port 8025

for gradio app :

uv run python web_client_transcribe.py


if problems, try to install these, other way not :

sudo apt-get update
sudo apt-get install libportaudio2 portaudio19-dev
sudo apt-get install libsdl2-dev
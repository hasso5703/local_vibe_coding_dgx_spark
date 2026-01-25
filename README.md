# DGX Spark Commands & Local Vibe-Coding Setup

This guide details the environment setup and execution for local inference on the NVIDIA DGX Spark, specifically optimized for "Vibe-Coding."

Refer to the official NVIDIA documentation: [NVIDIA Spark Nemotron Instructions](https://build.nvidia.com/spark/nemotron/instructions)

---

## 1. Environment Verification (Single User)

Check the current toolchain versions:

```bash
git --version
cmake --version
nvcc --version

```

### Example Output:

> `git version 2.43.0`
> `cmake version 3.28.3`
> `nvcc: NVIDIA (R) Cuda compiler driver... release 13.0, V13.0.88`

### Install or Update `uv`

Manage your Python environment with [uv](https://docs.astral.sh/uv/):

```bash
# Install
curl -LsSf https://astral.sh/uv/install.sh | sh

# Update
uv self update

```

### Sync and Verify Environment

```bash
uv sync
source .venv/bin/activate
hf version

```

---

## 2. Building llama.cpp with CUDA Support

Targeting the DGX Spark architecture (`sm_121`). See [llama.cpp build docs](https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md) for further details.

```bash
git clone https://github.com/ggml-org/llama.cpp
cd llama.cpp
mkdir build && cd build

# Configure for CUDA architectures 121
cmake .. -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES="121" -DLLAMA_CURL=OFF
make -j 10

```

---

## 3. Model Downloads

We recommend using **Unsloth GGUF quants** for the best performance.

### Recommended:

```bash
hf download unsloth/GLM-4.7-Flash-GGUF GLM-4.7-Flash-UD-Q8_K_XL.gguf --local-dir ~/models/GLM-4.7-Flash

```

### Other Available Models:

```bash
# Mistral Devstral
hf download unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF Devstral-Small-2-24B-Instruct-2512-UD-Q8_K_XL.gguf --local-dir ~/models/Devstral-Small-2-24B-Instruct

# Nemotron-3 Nano
hf download unsloth/Nemotron-3-Nano-30B-A3B-GGUF Nemotron-3-Nano-30B-A3B-UD-Q8_K_XL.gguf --local-dir ~/models/Nemotron-3-Nano-30B-A3B

# GPT OSS 120B
hf download unsloth/gpt-oss-120b-GGUF gpt-oss-120b-F16.gguf --local-dir ~/models/gpt-oss-120b

```

---

## 4. Running the Inference Server

To keep the server running in the background, use `screen`:

```bash
screen -S glm-47

```

### Launch Commands:

#### GLM‑4.7‑Flash (UD‑Q8_K_XL)

```bash
./bin/llama-server \
  --model ~/models/GLM-4.7-Flash/GLM-4.7-Flash-UD-Q8_K_XL.gguf \
  --jinja --min-p 0.01 --temp 0.7 --top-p 1.0 --port 8080 --host 0.0.0.0 \
  --threads -2 --ctx-size 0 --fit on --seed 3407 --n-gpu-layers 99

```
Max ctx window is 202752
also look at: [GLM‑4.7‑Flash documentation](https://unsloth.ai/docs/models/glm-4.7-flash)

#### Devstral‑Small‑2‑24B‑Instruct (UD‑Q8_K_XL) (It’s a dense model, so it will be slower than the MoE alternatives.)

```bash
./bin/llama-server --model ~/models/Devstral-Small-2-24B-Instruct/Devstral-Small-2-24B-Instruct-2512-UD-Q8_K_XL.gguf  --threads -2 --ctx-size 65536 --n-gpu-layers 99 --seed 3407 --prio 2 --temp 0.15 --jinja --port 8080 --host 0.0.0.0

```
also look at: [Devstral 2 documentation](https://unsloth.ai/docs/models/tutorials/devstral-2)

#### Nemotron‑3‑Nano‑30B‑A3B (UD‑Q8_K_XL)

```bash
./bin/llama-server --model ~/models/Nemotron-3-Nano-30B-A3B/Nemotron-3-Nano-30B-A3B-UD-Q8_K_XL.gguf --threads -8 --ctx-size 262144 --n-gpu-layers 99 --jinja --fit on --temp 0.6 --top-p 0.95 --port 8080 --host 0.0.0.0

```
--temp 1.0 --top-p 1.0 for general instruction, --temp 0.6 --top-p 0.95 for tool calling
Context size can be 1M : --ctx-size 1048576 or --ctx-size 0
also look at: [Nemotron 3 documentation](https://unsloth.ai/docs/models/nemotron-3)

#### GPT‑OSS‑120B (F16) (fastest under load, still fast at 100 k‑token context)

```bash
./bin/llama-server --model ~/models/gpt-oss-120b/gpt-oss-120b-F16.gguf --host 0.0.0.0 --port 8080 --n-gpu-layers 99 --ctx-size 0 --threads 8 --jinja -ub 2048 -b 2048 --chat-template-kwargs '{"reasoning_effort": "high"}' --temp 1.0 --top-p 1.0 --min-p 0.0 --top-k 0.0

```
also look at: [GPT OSS documentation](https://unsloth.ai/docs/models/gpt-oss-how-to-run-and-fine-tune#run-gpt-oss-120b)

*(Exit the screen with `Ctrl+A` then `D`)*

* **Port change:** Add `--port 30000` if needed.
* **Remote Access:** To request the model from a different machine, install [Tailscale](https://build.nvidia.com/spark/tailscale) and add `--host 0.0.0.0` to the command.
* **Web UI:** Test the model at `http://localhost:8080` (Benchmark: ~42 tokens/sec).

---

## 5. Vibe-Coding with Mistral Vibe

### Setup Workspace

```bash
mkdir vibe_coding_with_mistral_vibe
cd vibe_coding_with_mistral_vibe

```

### Install Mistral Vibe CLI

Refer to the [official release](https://mistral.ai/news/devstral-2-vibe-cli):

```bash
uv tool install mistral-vibe

```

### Configuration

Launch `vibe`, choose your theme, and leave the API key blank (we will handle it locally). Open `~/.vibe/config.toml` (using `code` or `nano`) and ensure the following sections exist:

```toml
[[providers]]
name = "llamacpp"
api_base = "http://127.0.0.1:8080/v1"
api_key_env_var = ""
api_style = "openai"
backend = "generic"
reasoning_field_name = "reasoning_content"

[[models]]
name = "Glm-4.7-Flash"
provider = "llamacpp"
temperature = 0.7
input_price = 0.0
output_price = 0.0

```

*Note: You can follow the same pattern for other downloaded models.*

### Activation

1. In the `vibe` interface, run `/reload`.
2. Type `/model`, press Enter until `Glm-4.7-Flash` is selected, then hit `ESC`.

---

## 6. Vibe-Coding Prompt Example

Use the following prompt (adapted from [Claude.ai Prompt Library](https://platform.claude.com/docs/en/resources/prompt-library/website-wizard)) to test the setup:

> Your task is to create a one-page website based on the given specifications, delivered as an HTML file with embedded JavaScript and CSS. The website should incorporate a variety of engaging and interactive design features...
> Create a one-page website for an online learning platform called "EduQuest" with:
> 1. Fixed navigation bar (Math, Science, Languages, Arts).
> 2. Hero section with video background and rotating tagline (every 3s).
> 3. Featured courses section.
> 4. Interactive "Learning Paths" quiz.
> 5. Success Stories/Testimonials.
> 6. Footer with contact modal.
> 
> 

---

## 7. Multiple User

*Upcoming: Support via `vLLM` will be added in a future update.*
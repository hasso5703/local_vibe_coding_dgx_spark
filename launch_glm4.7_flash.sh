#!/bin/bash

# Script de lancement du serveur GLM-4.7 Flash

# Configuration
MODEL_DIR="$HOME/models/GLM-4.7-Flash"
MODEL_NAME="GLM-4.7-Flash-UD-Q8_K_XL.gguf"
MODEL_PATH="$MODEL_DIR/$MODEL_NAME"

# Vérification du modèle
if [ ! -f "$MODEL_PATH" ]; then
    echo "❌ Modèle non trouvé: $MODEL_PATH"
    echo "Téléchargez-le avec: hf download unsloth/GLM-4.7-Flash-GGUF $MODEL_NAME --local-dir $MODEL_DIR"
    exit 1
fi

# Vérification de llama-server
if [ ! -f "./llama.cpp/build/bin/llama-server" ]; then
    echo "❌ llama-server non trouvé dans llama.cpp/build/bin/"
    exit 1
fi

# Lancement
echo "🚀 Lancement de GLM-4.7 Flash..."
./llama.cpp/build/bin/llama-server \
    --model "$MODEL_PATH" \
    --alias "GLM-4.7-Flash-Q8_K_XL" \
    --chat-template-kwargs "{\"enable_thinking\": false}" \
    --fit on \
    --temp 0.6 \
    --top-p 0.95 \
    --top-k 0 \
    --min-p 0.01 \
    --port 8080 \
    --host 0.0.0.0 \
    --threads -8 \
    --jinja \
    --kv-unified \
    --cache-type-k q8_0 --cache-type-v q8_0 \
    --flash-attn on \
    --batch-size 4096 --ubatch-size 4096 \
    --ctx-size 202752

# Georgi Gerganov's settings
# https://x.com/ggerganov/status/2016903216093417540?s=20
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
    --jinja --min-p 0.01 --temp 0.7 --top-p 1.0 \
    --port 8080 --host 0.0.0.0 \
    --threads -8 --ctx-size 0 --fit on

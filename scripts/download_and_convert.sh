#!/bin/bash
set -e

if [ -z "$HF_MODEL_NAME" ]; then
    echo "Error: HF_MODEL_NAME environment variable is not set"
    exit 1
fi

MODEL_NAME=${MODEL_NAME:-"custom-model"}
QUANTIZATION=${QUANTIZATION:-"q4_k_m"}
WORKSPACE="/workspace"
MODELS_DIR="$WORKSPACE/models"
TEMP_DIR="$WORKSPACE/temp"

mkdir -p "$MODELS_DIR"
mkdir -p "$TEMP_DIR"

echo "Downloading model: $HF_MODEL_NAME"
echo "Target model name: $MODEL_NAME"
echo "Quantization: $QUANTIZATION"

SKIP_QUANTIZATION=false
if [ -z "$QUANTIZATION" ] || [ "$QUANTIZATION" = "full" ] || [ "$QUANTIZATION" = "orig" ] || [ "$QUANTIZATION" = "f16" ] || [ "$QUANTIZATION" = "f32" ]; then
    SKIP_QUANTIZATION=true
    echo "no quantization"
else
    echo "applying quantization: $QUANTIZATION"
fi

cd "$TEMP_DIR"

if [ -n "$HF_TOKEN" ]; then
    echo "Logging in to Hugging Face..."
    echo "$HF_TOKEN" | huggingface-cli login --token
fi

echo "Downloading model..."
huggingface-cli download "$HF_MODEL_NAME" \
    --local-dir "./model" \
    --local-dir-use-symlinks False

# Verify download
if [ ! -d "./model" ] || [ ! -f "./model/config.json" ]; then
    echo "Error: Model download failed or incomplete"
    ls -la "./model" || echo "Model directory doesn't exist"
    exit 1
fi

echo "Model downloaded successfully!"

echo "Converting model to GGUF format..."

cd /opt/llama.cpp
python3 convert_hf_to_gguf.py "$TEMP_DIR/model" \
    --outfile "$MODELS_DIR/${MODEL_NAME}.gguf"

if [ ! -f "$MODELS_DIR/${MODEL_NAME}.gguf" ]; then
    echo "Error: GGUF conversion failed"
    exit 1
fi

if [ "$SKIP_QUANTIZATION" = true ]; then
    FINAL_MODEL_FILE="${MODEL_NAME}.gguf"
    echo "Skipping quantization - using original GGUF model"
    echo "GGUF model location: $MODELS_DIR/$FINAL_MODEL_FILE"
else
    echo "Quantizing model..."
        
    if command -v llama-quantize >/dev/null 2>&1; then
        QUANTIZE_CMD="llama-quantize"
    elif [ -f "/opt/llama.cpp/llama-quantize" ]; then
        QUANTIZE_CMD="/opt/llama.cpp/llama-quantize"
    else
        echo "Error: Could not find llama-quantize executable"
        echo "PATH: $PATH"
        echo "Available files in /opt/llama.cpp/:"
        ls -la /opt/llama.cpp/ | grep llama || echo "No llama executables found"
        exit 1
    fi
    
    echo "Using quantization tool: $QUANTIZE_CMD"
    $QUANTIZE_CMD "$MODELS_DIR/${MODEL_NAME}.gguf" \
        "$MODELS_DIR/${MODEL_NAME}-${QUANTIZATION}.gguf" \
        "$QUANTIZATION"
    
    if [ ! -f "$MODELS_DIR/${MODEL_NAME}-${QUANTIZATION}.gguf" ]; then
        echo "Error: Model quantization failed"
        exit 1
    fi
    
    FINAL_MODEL_FILE="${MODEL_NAME}-${QUANTIZATION}.gguf"
    echo "Model conversion completed successfully!"
    echo "GGUF model location: $MODELS_DIR/$FINAL_MODEL_FILE"
    
    rm -f "$MODELS_DIR/${MODEL_NAME}.gguf"
fi

rm -rf "$TEMP_DIR/cache"

echo "Conversion process completed!"
echo "Final model file: $MODELS_DIR/$FINAL_MODEL_FILE"

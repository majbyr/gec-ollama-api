#!/bin/bash
set -e

MODEL_NAME=${MODEL_NAME:-"custom-model"}
QUANTIZATION=${QUANTIZATION:-"q4_k_m"}

# Check which file actually exists - unquantized or quantized
if [ -f "/root/.ollama/models/${MODEL_NAME}.gguf" ]; then
    GGUF_FILE="${MODEL_NAME}.gguf"
    echo "Found unquantized model file: ${GGUF_FILE}"
elif [ -f "/root/.ollama/models/${MODEL_NAME}-${QUANTIZATION}.gguf" ]; then
    GGUF_FILE="${MODEL_NAME}-${QUANTIZATION}.gguf"
    echo "Found quantized model file: ${GGUF_FILE}"
fi

echo "Setting up Ollama model: $MODEL_NAME"
echo "Expected GGUF file: ${GGUF_FILE}"

if [ ! -f "/root/.ollama/models/${GGUF_FILE}" ]; then
    echo "Error: Model file not found at /root/.ollama/models/${GGUF_FILE}"
    echo "Available files in /root/.ollama/models/:"
    ls -la /root/.ollama/models/ || echo "Directory doesn't exist"
    echo ""
    echo "Checking for any GGUF files with different naming:"
    find /root/.ollama/models/ -name "*.gguf" -type f 2>/dev/null || echo "No GGUF files found"
    echo ""
    echo "Environment variables:"
    echo "MODEL_NAME: $MODEL_NAME"
    echo "QUANTIZATION: $QUANTIZATION"
    exit 1
fi

ollama serve &
OLLAMA_PID=$!

echo "Waiting for Ollama service to start..."
sleep 10

if ! pgrep -f "ollama serve" > /dev/null; then
    echo "Error: Ollama service failed to start"
    exit 1
fi

cat > /tmp/Modelfile << EOF
FROM /root/.ollama/models/${GGUF_FILE}
EOF

echo "Creating Ollama model..."
ollama create "$MODEL_NAME" -f /tmp/Modelfile

if ollama list | grep -q "$MODEL_NAME"; then
    echo "Model '$MODEL_NAME' created successfully in Ollama!"
    echo "Cleaning up GGUF file to save space..."
    rm -f "/root/.ollama/models/${GGUF_FILE}"
    echo "GGUF file removed: ${GGUF_FILE}"
else
    echo "Error: Failed to create model in Ollama"
    kill $OLLAMA_PID 2>/dev/null || true
    exit 1
fi

kill $OLLAMA_PID 2>/dev/null || true
wait $OLLAMA_PID 2>/dev/null || true

echo "Ollama model setup completed!"

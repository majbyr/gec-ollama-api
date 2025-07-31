#!/bin/bash
set -e

MODEL_NAME=${MODEL_NAME:-"custom-model"}

ollama serve &
OLLAMA_PID=$!

timeout=60
count=0
while ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; do
    sleep 2
    count=$((count + 2))
    if [ $count -ge $timeout ]; then
        kill $OLLAMA_PID 2>/dev/null || true
        exit 1
    fi
done

curl -s -X POST http://localhost:11434/api/generate \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"$MODEL_NAME\",
        \"prompt\": \"Hello\",
        \"options\": {
            \"num_predict\": 1
        }
    }" > /dev/null

curl -s -X POST http://localhost:11434/api/generate \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"$MODEL_NAME\",
        \"prompt\": \"\",
        \"keep_alive\": -1,
        \"options\": {
            \"num_predict\": 0
        }
    }" > /dev/null

wait $OLLAMA_PID

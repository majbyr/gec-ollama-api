# GEC Ollama API

A Docker-based solution that downloads fine-tuned models from Hugging Face, converts them to GGUF format, and deploys them with Ollama as an API. Specifically configured for Estonian Grammar Error Correction (GEC) using the Llama-3.1-8B model.

The APIs are compatible with [grammar correction API (ollama branch)](https://github.com/TartuNLP/grammar-api/tree/migration-ollama).

## Features

- Download models from Hugging Face
- Conversion from safetensors to GGUF format
- Model quantization options
- Ollama API integration with model preloading
- CPU and GPU deployment profiles

## Quick Start

### 1. Configure Your Model

The project is pre-configured for Estonian GEC model. Edit `.env` if needed:

```env
HF_MODEL_NAME=tartuNLP/Llama-3.1-8B-est-gec-july-2025
MODEL_NAME=gec
QUANTIZATION=full
```

### 2. Build and Deploy

#### Using Docker Compose

For CPU deployment:
```bash
COMPOSE_PROFILES=cpu docker compose up --build
```

For GPU deployment:
```bash
COMPOSE_PROFILES=gpu docker compose up --build
```

#### Using Docker directly

For CPU deployment:
```bash
docker build -t gec-ollama-api-cpu \
  --build-arg HF_MODEL_NAME=tartuNLP/Llama-3.1-8B-est-gec-july-2025 \
  --build-arg MODEL_NAME=gec \
  --build-arg QUANTIZATION=full \
  -f Dockerfile.cpu \
  .

docker run -d \
  --name gec-ollama-api-cpu \
  -p 11434:11434 \
  gec-ollama-api-cpu
```

For GPU deployment:
```bash
docker build -t gec-ollama-api-gpu \
  --build-arg HF_MODEL_NAME=tartuNLP/Llama-3.1-8B-est-gec-july-2025 \
  --build-arg MODEL_NAME=gec \
  --build-arg QUANTIZATION=full \
  -f Dockerfile \
  .

docker run -d \
  --name gec-ollama-api-gpu \
  --gpus all \
  -p 11434:11434 \
  gec-ollama-api-gpu
```

### 3. Test the API

Once the container is running, test the API:

```bash
# Check available models
curl http://localhost:11434/api/tags

# Test GEC model with Estonian text
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gec",
    "prompt": "### Instruction:\nReply with a corrected version of the input essay in Estonian with all grammatical and spelling errors fixed. If there are no errors, reply with a copy of the original essay.\n\n### Input:\nMul on kaks koer ja üks kass\n\n### Response:\n",
    "stream": false,
    options: {
      "temperature": 0.7,
      "top_p": 0.9,
      "top_k": 50,
      "max_tokens": 100
    }
  }'
```

## Configuration Options

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `HF_MODEL_NAME` | Hugging Face model name | `tartuNLP/Llama-3.1-8B-est-gec-july-2025` | Yes |
| `HF_TOKEN` | Hugging Face token (for private models) | - | No |
| `MODEL_NAME` | Name for the converted model | `gec` | No |
| `QUANTIZATION` | Quantization level | `full` | No |

### Quantization Options

Choose the right balance between model size and quality:

- `full`, `orig` - No quantization (keeps original precision - larger file, better quality)
- `f16`, `f32` - Specific float precision
- `q2_k` - Smallest size, lowest quality
- `q3_k_s`, `q3_k_m`, `q3_k_l` - Small size, low quality
- `q4_0`, `q4_1` - Medium size, good quality
- `q4_k_s`, `q4_k_m` - Balanced size and quality
- `q5_0`, `q5_1`, `q5_k_s`, `q5_k_m` - Larger size, better quality
- `q6_k` - Large size, high quality
- `q8_0` - Large, very high quality

**Note**: This project defaults to `full` precision for best GEC quality.

## API Endpoints

### Ollama Standard API

The service exposes the standard Ollama API on port `11434`:

- `GET /api/tags` - List available models
- `POST /api/generate` - Text generation
- `POST /api/show` - Show model info

- [DOCS](https://ollama.readthedocs.io/en/api/)

### Model Information

The deployed model is specifically fine-tuned for Estonian Grammar Error Correction:
- **Model**: `gec`
- **Language**: Estonian
- **Task**: Grammar Error Correction
- **Input Format**: Uses instruction-based prompting


## File Structure

```
gec-ollama-api/
├── .env                        # Configuration file
├── .gitignore                  # Git ignore rules
├── README.md                   # This file
├── docker-compose.yml          # Docker Compose configuration
├── Dockerfile                  # GPU Docker build
├── Dockerfile.cpu              # CPU Docker build
├── ollama/                     # Ollama configuration
│   ├── Modelfile.template      # Model template
│   ├── setup_model.sh          # Model setup script
│   └── startup.sh              # Container startup script
└── scripts/                    # Build scripts
    └── download_and_convert.sh # Model conversion script
```

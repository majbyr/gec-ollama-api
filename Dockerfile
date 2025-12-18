FROM python:3.11-slim as model-converter

RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu

RUN pip install --no-cache-dir \
    transformers \
    sentencepiece \
    protobuf \
    accelerate \
    huggingface-hub[cli] \
    datasets \
    numpy

WORKDIR /opt
RUN wget https://github.com/ggml-org/llama.cpp/releases/download/b6039/llama-b6039-bin-ubuntu-x64.zip && \
    unzip llama-b6039-bin-ubuntu-x64.zip && \
    mkdir -p llama.cpp && \
    cp -r build/bin/* llama.cpp/ && \
    rm -rf build llama-b6039-bin-ubuntu-x64.zip && \
    chmod +x llama.cpp/*

RUN git clone https://github.com/ggerganov/llama.cpp.git llama-cpp-repo && \
    ls -la llama-cpp-repo/ && \
    cp llama-cpp-repo/convert_hf_to_gguf.py llama.cpp/ && \
    find llama-cpp-repo -name "gguf*" -type d -exec cp -r {} llama.cpp/ \; || echo "No gguf directories found" && \
    rm -rf llama-cpp-repo

ENV PATH="/opt/llama.cpp:${PATH}"

WORKDIR /workspace

COPY scripts/ /workspace/scripts/
RUN chmod +x /workspace/scripts/*.sh

ARG HF_MODEL_NAME
ARG HF_TOKEN
ARG MODEL_NAME
ARG QUANTIZATION

ENV HF_MODEL_NAME=${HF_MODEL_NAME}
ENV HF_TOKEN=${HF_TOKEN}
ENV MODEL_NAME=${MODEL_NAME}
ENV QUANTIZATION=${QUANTIZATION}

# Download and convert model
RUN if [ -n "$HF_MODEL_NAME" ]; then \
        /workspace/scripts/download_and_convert.sh; \
    else \
        echo "No model specified, skipping conversion"; \
        mkdir -p /workspace/models; \
    fi

FROM ollama/ollama:latest as ollama-runtime

# Re-declare build arguments
ARG HF_MODEL_NAME
ARG HF_TOKEN
ARG MODEL_NAME=custom-model
ARG QUANTIZATION=q4_k_m

ENV HF_MODEL_NAME=${HF_MODEL_NAME}
ENV HF_TOKEN=${HF_TOKEN}
ENV MODEL_NAME=${MODEL_NAME}
ENV QUANTIZATION=${QUANTIZATION}

COPY --from=model-converter /workspace/models/ /root/.ollama/models/

COPY ollama/ /opt/ollama/
RUN chmod +x /opt/ollama/*.sh

RUN /opt/ollama/setup_model.sh

# Clean up after model is imported
RUN rm -rf /opt/ollama/setup_model.sh && \
    echo "Setup completed, showing ollama directory contents:" && \
    du -sh /root/.ollama/* 2>/dev/null || echo "No files in .ollama directory" && \
    echo "Total .ollama directory size:" && \
    du -sh /root/.ollama/ 2>/dev/null || echo "Directory doesn't exist"

FROM ollama/ollama:latest

# Re-declare build arguments
ARG HF_MODEL_NAME
ARG HF_TOKEN
ARG MODEL_NAME=custom-model
ARG QUANTIZATION=q4_k_m

ENV HF_MODEL_NAME=${HF_MODEL_NAME}
ENV HF_TOKEN=${HF_TOKEN}
ENV MODEL_NAME=${MODEL_NAME}
ENV QUANTIZATION=${QUANTIZATION}

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

COPY --from=ollama-runtime /root/.ollama/ /root/.ollama/

COPY ollama/startup.sh /opt/ollama/startup.sh
RUN chmod +x /opt/ollama/startup.sh

EXPOSE 11434

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:11434/api/tags || exit 1

ENTRYPOINT ["/opt/ollama/startup.sh"]

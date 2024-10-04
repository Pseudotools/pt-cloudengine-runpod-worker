
# Stage 1: Base image with common dependencies
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 AS base

RUN echo "Starting dockerfile"

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1 

# Install Python, git and other necessary tools
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    git \
    wget

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Clone ComfyUI repository
RUN git clone https://github.com/Pseudotools/ComfyUI /comfyui

# Change working directory to ComfyUI
WORKDIR /comfyui

# Copy requirements.txt to leverage caching
COPY requirements.txt /comfyui/requirements.txt

# Install ComfyUI dependencies
RUN pip3 install --upgrade --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 \
    && pip3 install --upgrade --no-cache-dir -r requirements.txt

# Install runpod
RUN pip3 install runpod requests

# Support for the network volume
ADD src/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# Add the start and the handler
ADD src/start.sh src/rp_handler.py test_input.json ./
RUN chmod +x /start.sh

# Stage 2: Download models
FROM base AS downloader
RUN echo "Downloading models and installing custom nodes"

ARG HUGGINGFACE_ACCESS_TOKEN
ARG MODEL_TYPE

# Change working directory to ComfyUI
WORKDIR /comfyui

# Create Ipadapter model subdirectory
RUN mkdir -p models/ipadapter

# Clone the Pseudocomfy repository into the custom_nodes/Pseudocomfy subfolder
RUN git clone https://github.com/Pseudotools/Pseudocomfy.git custom_nodes/Pseudocomfy

# Clone the ComfyUI_IPAdapter_plus repository into the custom_nodes/ComfyUI_IPAdapter_plus subfolder
RUN git clone https://github.com/Pseudotools/ComfyUI_IPAdapter_plus.git custom_nodes/ComfyUI_IPAdapter_plus


# Download clip_vision models
RUN mkdir -p models/clip_vision && \
    wget -O models/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors "https://huggingface.co/pseudotools/pseudocomfy-models/resolve/main/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors" && \
    wget -O models/clip_vision/CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors "https://huggingface.co/pseudotools/pseudocomfy-models/resolve/main/clip_vision/CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors";


# Download checkpoints/vae/LoRA to include in image based on model type
RUN if [ "$MODEL_TYPE" = "sd15" ]; then \ 
      wget -O models/checkpoints/aiAngelMix_v30.safetensors "https://huggingface.co/pseudotools/pseudocomfy-models/resolve/main/checkpoints/aiAngelMix_v30.safetensors" && \  
      wget -O models/controlnet/diffusion_pytorch_model.safetensors "https://huggingface.co/pseudotools/pseudocomfy-models/resolve/main/controlnet/diffusion_pytorch_model.safetensors" && \
      wget -O models/ipadapter/ip-adapter-plus_sd15.safetensors "https://huggingface.co/pseudotools/pseudocomfy-models/resolve/main/ipadapter/ip-adapter-plus_sd15.safetensors"; \
    elif [ "$MODEL_TYPE" = "sdxl" ]; then \
      wget -O models/checkpoints/sd_xl_base_1.0.safetensors "https://huggingface.co/pseudotools/pseudocomfy-models/resolve/main/checkpoints/sd_xl_base_1.0.safetensors" && \ 
      wget -O models/checkpoints/albedobaseXL_v21 "https://huggingface.co/pseudotools/pseudocomfy-models/resolve/main/checkpoints/albedobaseXL_v21.safetensors" && \  
      wget -O models/controlnet/control-lora-depth-rank128 "https://huggingface.co/pseudotools/pseudocomfy-models/resolve/main/controlnet/control-lora-depth-rank128.safetensors" && \
      wget -O models/ipadapter/ip-adapter-plus_sdxl_vit-h.safetensors "https://huggingface.co/pseudotools/pseudocomfy-models/resolve/main/ipadapter/ip-adapter-plus_sdxl_vit-h.safetensors"; \
    elif [ "$MODEL_TYPE" = "sd3" ]; then \
      wget --header="Authorization: Bearer ${HUGGINGFACE_ACCESS_TOKEN}" -O models/checkpoints/sd3_medium_incl_clips_t5xxlfp8.safetensors "https://huggingface.co/stabilityai/stable-diffusion-3-medium/resolve/main/sd3_medium_incl_clips_t5xxlfp8.safetensors"; \
    elif [ "$MODEL_TYPE" = "flux1-schnell" ]; then \
      wget -O models/unet/flux1-schnell.safetensors "https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/flux1-schnell.safetensors" && \
      wget -O models/clip/clip_l.safetensors "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors" && \
      wget -O models/clip/t5xxl_fp8_e4m3fn.safetensors "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors" && \
      wget -O models/vae/ae.safetensors "https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors"; \
    elif [ "$MODEL_TYPE" = "flux1-dev" ]; then \
      wget --header="Authorization: Bearer ${HUGGINGFACE_ACCESS_TOKEN}" -O models/unet/flux1-dev.safetensors "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors" && \
      wget -O models/clip/clip_l.safetensors "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors" && \
      wget -O models/clip/t5xxl_fp8_e4m3fn.safetensors "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors" && \
      wget --header="Authorization: Bearer ${HUGGINGFACE_ACCESS_TOKEN}" -O models/vae/ae.safetensors "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors"; \
    fi

# Stage 3: Final image
FROM base AS final

# Copy models from stage 2 to the final image
COPY --from=downloader /comfyui/models /comfyui/models

# Start the container
CMD /start.sh
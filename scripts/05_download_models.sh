#!/bin/bash
# ================================================
# 05_download_models.sh - Скачивание моделей EchoMimic
# ================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

STEP_FILE="/tmp/step05_complete"

if [ -f "$STEP_FILE" ]; then
    echo -e "${GREEN}✅ Модели уже скачаны. Пропускаем.${NC}"
    exit 0
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Шаг 5: Скачивание моделей EchoMimic${NC}"
echo -e "${GREEN}========================================${NC}"

COMFYUI_DIR="$HOME/ComfyUI_Echo"
MODELS_DIR="$COMFYUI_DIR/models/echo_mimic"

if [ ! -d "$COMFYUI_DIR" ]; then
    echo -e "${RED}ComfyUI не найден. Сначала выполните make comfyui${NC}"
    exit 1
fi

# Активируем окружение
if command -v conda &> /dev/null; then
    eval "$(conda shell.bash hook)"
    conda activate comfy_echo
else
    source "$HOME/comfy_echo/bin/activate"
fi

# Установка huggingface-hub
echo -e "\n${YELLOW}Установка huggingface-hub...${NC}"
pip install huggingface-hub

# Создание папки для моделей
mkdir -p "$MODELS_DIR"

# Скачивание моделей
echo -e "\n${YELLOW}Скачивание моделей (это займёт 10-20 минут)...${NC}"

echo "  - V3 Flash Model (~3.73 GB)"
huggingface-cli download BadToBest/EchoMimicV3 \
    --include "echomimicv3-flash-pro/*" \
    --local-dir "$MODELS_DIR"

echo "  - Wav2Vec2 Model (~380 MB)"
huggingface-cli download TencentGameMate/chinese-wav2vec2-base \
    --local-dir "$MODELS_DIR/chinese-wav2vec2-base"

echo "  - Transformer и VAE модели"
huggingface-cli download BadToBest/EchoMimicV3 \
    --include "transformer/*" "wan_2.1_vae.safetensors" \
    --local-dir "$MODELS_DIR"

# Проверка
echo -e "\n${YELLOW}Проверка скачанных моделей...${NC}"
ls -la "$MODELS_DIR"

# Отметка о завершении
touch "$STEP_FILE"
echo -e "\n${GREEN}✅ Шаг 5 завершён! Все модели скачаны.${NC}"
#!/bin/bash
# ================================================
# 02_create_env.sh - Создание Python окружения
# ================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

STEP_FILE="/tmp/step02_complete"

if [ -f "$STEP_FILE" ]; then
    echo -e "${GREEN}✅ Шаг 2 уже выполнен. Пропускаем.${NC}"
    exit 0
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Шаг 2: Создание окружения${NC}"
echo -e "${GREEN}========================================${NC}"

ENV_NAME="comfy_echo"
ENV_DIR="$HOME/$ENV_NAME"

# Проверяем, что Python 3.10 установлен
if ! command -v python3.10 &> /dev/null; then
    echo -e "${RED}Python 3.10 не найден. Сначала выполните make prepare${NC}"
    exit 1
fi

# Создание окружения
echo -e "\n${YELLOW}Создание окружения...${NC}"

if command -v conda &> /dev/null; then
    echo "Используем conda..."
    conda create -n $ENV_NAME python=3.10 -y
    eval "$(conda shell.bash hook)"
    conda activate $ENV_NAME
else
    echo "Используем venv..."
    if [ -d "$ENV_DIR" ]; then
        echo "Старое окружение найдено. Удаляем..."
        rm -rf "$ENV_DIR"
    fi
    python3.10 -m venv "$ENV_DIR"
    source "$ENV_DIR/bin/activate"
fi

echo -e "${GREEN}✅ Окружение создано. Python: $(python --version)${NC}"

# Обновление pip
echo -e "\n${YELLOW}Обновление pip...${NC}"
pip install --upgrade pip

# Отметка о завершении
touch "$STEP_FILE"
echo -e "\n${GREEN}✅ Шаг 2 завершён!${NC}"
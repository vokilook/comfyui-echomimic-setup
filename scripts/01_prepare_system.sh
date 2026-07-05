#!/bin/bash
# ================================================
# 01_prepare_system.sh - Подготовка системы
# Установка Python 3.10, CUDA, системных пакетов
# ================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

STEP_FILE="/tmp/step01_complete"

if [ -f "$STEP_FILE" ]; then
    echo -e "${GREEN}✅ Шаг 1 уже выполнен. Пропускаем.${NC}"
    exit 0
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Шаг 1: Подготовка системы${NC}"
echo -e "${GREEN}========================================${NC}"

# 1. Проверка CUDA
echo -e "\n${YELLOW}Проверка CUDA...${NC}"
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
else
    echo -e "${RED}CUDA не найдена! Установите драйверы NVIDIA и CUDA Toolkit.${NC}"
    echo "  sudo apt update && sudo apt install nvidia-driver-570 cuda-13-0 -y"
    exit 1
fi

# 2. Обновление системы
echo -e "\n${YELLOW}Обновление системы...${NC}"
sudo apt update
sudo apt upgrade -y

# 3. Установка базовых пакетов
echo -e "\n${YELLOW}Установка базовых пакетов...${NC}"
sudo apt install -y git curl wget build-essential ffmpeg

# 4. Установка Python 3.10
echo -e "\n${YELLOW}Установка Python 3.10...${NC}"

if command -v python3.10 &> /dev/null; then
    echo -e "${GREEN}✅ Python 3.10 уже установлен: $(python3.10 --version)${NC}"
else
    echo -e "${YELLOW}Компиляция Python 3.10 из исходников...${NC}"
    
    sudo apt install -y build-essential libssl-dev zlib1g-dev libbz2-dev \
        libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev \
        libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev
    
    cd /tmp
    wget https://www.python.org/ftp/python/3.10.13/Python-3.10.13.tgz
    tar -xzf Python-3.10.13.tgz
    cd Python-3.10.13
    ./configure --enable-optimizations --prefix=/usr/local
    make -j$(nproc)
    sudo make altinstall
    sudo ln -sf /usr/local/bin/python3.10 /usr/bin/python3.10
    
    echo -e "${GREEN}✅ Python 3.10 установлен: $(python3.10 --version)${NC}"
fi

# 5. Отметка о завершении
touch "$STEP_FILE"
echo -e "\n${GREEN}✅ Шаг 1 завершён!${NC}"
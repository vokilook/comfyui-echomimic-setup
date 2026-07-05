#!/bin/bash
# ================================================
# 03_install_comfyui.sh - Установка ComfyUI
# ================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

STEP_FILE="/tmp/step03_complete"

if [ -f "$STEP_FILE" ]; then
    echo -e "${GREEN}✅ Шаг 3 уже выполнен. Пропускаем.${NC}"
    exit 0
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Шаг 3: Установка ComfyUI${NC}"
echo -e "${GREEN}========================================${NC}"

COMFYUI_DIR="$HOME/ComfyUI_Echo"
COMFYUI_REPO="https://github.com/comfyanonymous/ComfyUI.git"

# Активируем окружение
if command -v conda &> /dev/null; then
    eval "$(conda shell.bash hook)"
    conda activate comfy_echo
else
    source "$HOME/comfy_echo/bin/activate"
fi

# Клонирование ComfyUI
echo -e "\n${YELLOW}Клонирование ComfyUI...${NC}"
if [ -d "$COMFYUI_DIR" ]; then
    echo "Папка $COMFYUI_DIR уже существует. Обновляем..."
    cd "$COMFYUI_DIR"
    git pull
else
    git clone "$COMFYUI_REPO" "$COMFYUI_DIR"
fi
cd "$COMFYUI_DIR"

# Адаптация requirements.txt для Python 3.10
echo -e "\n${YELLOW}Адаптация requirements.txt для Python 3.10...${NC}"
cp requirements.txt requirements.txt.bak

# Удаляем все строки с comfyui-
sed -i '/^comfyui-/d' requirements.txt

# Добавляем смягчённые версии
echo -e "\n# Fixed for Python 3.10 compatibility" >> requirements.txt
echo "comfyui-frontend-package>=1.45.0" >> requirements.txt
echo "comfyui-workflow-templates>=0.11.0" >> requirements.txt
echo "comfyui-embedded-docs>=0.5.0" >> requirements.txt

echo -e "${GREEN}✅ requirements.txt адаптирован${NC}"

# Установка зависимостей
echo -e "\n${YELLOW}Установка PyTorch и зависимостей...${NC}"
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu130
pip install -r requirements.txt

# Установка проблемных пакетов отдельно (если нужно)
echo -e "\n${YELLOW}Установка дополнительных пакетов...${NC}"
pip install comfyui-frontend-package comfyui-workflow-templates comfyui-embedded-docs --upgrade 2>/dev/null || true

# Отметка о завершении
touch "$STEP_FILE"
echo -e "\n${GREEN}✅ Шаг 3 завершён!${NC}"
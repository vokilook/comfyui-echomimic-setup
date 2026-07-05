#!/bin/bash
# ================================================
# ComfyUI + EchoMimic V3 Flash Installation Script
# For Ubuntu 26.04 with CUDA 13
# Автор: vokilook
# ================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}ComfyUI + EchoMimic V3 Flash Setup${NC}"
echo -e "${GREEN}========================================${NC}"

COMFYUI_DIR="$HOME/ComfyUI_Echo"
COMFYUI_REPO="https://github.com/comfyanonymous/ComfyUI.git"
ENV_NAME="comfy_echo"
PYTHON_VERSION="3.10"

# ================================================
# Шаг 1: Проверка CUDA
# ================================================
echo -e "\n${YELLOW}[1/6] Проверка CUDA...${NC}"
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
else
    echo -e "${RED}CUDA не найдена! Установите драйверы NVIDIA и CUDA Toolkit.${NC}"
    exit 1
fi

# ================================================
# Шаг 2: Создание окружения с Python 3.10
# ================================================
echo -e "\n${YELLOW}[2/6] Создание окружения...${NC}"

# Проверяем, доступен ли Python 3.10
if command -v python3.10 &> /dev/null; then
    PYTHON_CMD="python3.10"
elif command -v python3 &> /dev/null; then
    # Проверяем версию python3
    PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    if [[ "$PYTHON_VERSION" == "3.10" ]]; then
        PYTHON_CMD="python3"
    else
        echo -e "${RED}Ошибка: Python 3.10 не найден!${NC}"
        echo "Установите Python 3.10:"
        echo "  sudo apt update && sudo apt install python3.10 python3.10-venv python3.10-dev -y"
        exit 1
    fi
else
    echo -e "${RED}Ошибка: Python не найден!${NC}"
    exit 1
fi

echo "Использую Python: $($PYTHON_CMD --version)"

if command -v conda &> /dev/null; then
    echo "Используем conda..."
    conda create -n $ENV_NAME python=3.10 -y
    eval "$(conda shell.bash hook)"
    conda activate $ENV_NAME
else
    echo "Используем venv..."
    $PYTHON_CMD -m venv $HOME/$ENV_NAME
    source $HOME/$ENV_NAME/bin/activate
fi

# ================================================
# Шаг 3: Клонирование ComfyUI
# ================================================
echo -e "\n${YELLOW}[3/6] Клонирование ComfyUI...${NC}"
if [ -d "$COMFYUI_DIR" ]; then
    echo "Папка $COMFYUI_DIR уже существует. Обновляем..."
    cd $COMFYUI_DIR
    git pull
else
    git clone $COMFYUI_REPO $COMFYUI_DIR
fi
cd $COMFYUI_DIR

# ================================================
# Шаг 4: Установка зависимостей
# ================================================
echo -e "\n${YELLOW}[4/6] Установка зависимостей...${NC}"
pip install --upgrade pip
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu130
pip install -r requirements.txt

# ================================================
# Шаг 5: Установка кастомных нод
# ================================================
echo -e "\n${YELLOW}[5/6] Установка кастомных нод...${NC}"
mkdir -p $COMFYUI_DIR/custom_nodes
cd $COMFYUI_DIR/custom_nodes

echo "  - Установка EchoMimic..."
git clone https://github.com/smthemex/ComfyUI_EchoMimic.git

echo "  - Установка Video Helper Suite..."
git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git

echo "  - Установка ComfyUI-Manager..."
git clone https://github.com/ltdrdata/ComfyUI-Manager.git

# ================================================
# Шаг 6: Установка зависимостей EchoMimic
# ================================================
echo -e "\n${YELLOW}[6/6] Установка зависимостей EchoMimic...${NC}"
pip install diffusers transformers accelerate safetensors
pip install opencv-python-headless moviepy ipython
pip install facexlib basicsr gfpgan ultralytics
pip install mediapipe-silicon einops omegaconf
pip install huggingface_hub sentencepiece protobuf
pip install librosa soundfile ffmpeg-python torchcodec
pip install decord pyloudnorm

# Правильная версия OpenCV (совместимая с NumPy 1.x)
pip uninstall opencv-python opencv-contrib-python opencv-python-headless -y || true
pip install opencv-python==4.9.0.80 opencv-contrib-python==4.9.0.80 opencv-python-headless==4.9.0.80

# ================================================
# Создание скрипта запуска
# ================================================
echo -e "\n${GREEN}Создание скрипта запуска...${NC}"
cat > $COMFYUI_DIR/run_comfyui.sh << 'EOF'
#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh 2>/dev/null || source ~/anaconda3/etc/profile.d/conda.sh 2>/dev/null
conda activate comfy_echo 2>/dev/null || source ~/comfy_echo/bin/activate
cd ~/ComfyUI_Echo
python main.py --listen 0.0.0.0 --port 8188 "$@"
EOF
chmod +x $COMFYUI_DIR/run_comfyui.sh

# ================================================
# Готово!
# ================================================
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ УСТАНОВКА ЗАВЕРШЕНА!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Для запуска ComfyUI выполните:"
echo -e "  ~/ComfyUI_Echo/run_comfyui.sh"
echo -e ""
echo -e "⚠️  Не забудьте скачать модели:"
echo -e "  huggingface-cli download BadToBest/EchoMimicV3 --include \"echomimicv3-flash-pro/*\" --local-dir ~/ComfyUI_Echo/models/echo_mimic/"
echo -e "  huggingface-cli download TencentGameMate/chinese-wav2vec2-base --local-dir ~/ComfyUI_Echo/models/echo_mimic/chinese-wav2vec2-base/"
echo -e "  huggingface-cli download BadToBest/EchoMimicV3 --include \"transformer/*\" \"wan_2.1_vae.safetensors\" --local-dir ~/ComfyUI_Echo/models/echo_mimic/"
echo -e ""
echo -e "📂 Репозиторий: https://github.com/vokilook/comfyui-echomimic-setup"
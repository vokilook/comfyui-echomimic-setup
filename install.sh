#!/bin/bash
# ================================================
# ComfyUI + EchoMimic V3 Flash Installation Script
# For Ubuntu 22.04 / 24.04 / 26.04 with CUDA 13
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

# ================================================
# Шаг 1: Проверка CUDA
# ================================================
echo -e "\n${YELLOW}[1/7] Проверка CUDA...${NC}"
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
else
    echo -e "${RED}CUDA не найдена! Установите драйверы NVIDIA и CUDA Toolkit.${NC}"
    echo "  sudo apt update && sudo apt install nvidia-driver-570 cuda-13-0 -y"
    exit 1
fi

# ================================================
# Шаг 2: Установка Python 3.10 (компиляция из исходников)
# ================================================
echo -e "\n${YELLOW}[2/7] Проверка Python 3.10...${NC}"

if command -v python3.10 &> /dev/null; then
    echo -e "${GREEN}✅ Python 3.10 уже установлен: $(python3.10 --version)${NC}"
    PYTHON_CMD="python3.10"
else
    echo -e "${YELLOW}Python 3.10 не найден. Компилирую из исходников...${NC}"
    
    sudo apt update
    sudo apt install build-essential libssl-dev zlib1g-dev libbz2-dev \
        libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev \
        libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev -y
    
    cd /tmp
    wget https://www.python.org/ftp/python/3.10.13/Python-3.10.13.tgz
    tar -xzf Python-3.10.13.tgz
    cd Python-3.10.13
    ./configure --enable-optimizations --prefix=/usr/local
    make -j$(nproc)
    sudo make altinstall
    sudo ln -sf /usr/local/bin/python3.10 /usr/bin/python3.10
    
    if command -v python3.10 &> /dev/null; then
        echo -e "${GREEN}✅ Python 3.10 успешно установлен: $(python3.10 --version)${NC}"
        PYTHON_CMD="python3.10"
    else
        echo -e "${RED}Не удалось установить Python 3.10.${NC}"
        exit 1
    fi
fi

# ================================================
# Шаг 3: Установка pip и базовых пакетов
# ================================================
echo -e "\n${YELLOW}[3/7] Установка pip и базовых пакетов...${NC}"
sudo apt install git curl wget build-essential ffmpeg -y

# ================================================
# Шаг 4: Создание окружения
# ================================================
echo -e "\n${YELLOW}[4/7] Создание окружения...${NC}"

if command -v conda &> /dev/null; then
    echo "Используем conda..."
    conda create -n $ENV_NAME python=3.10 -y
    eval "$(conda shell.bash hook)"
    conda activate $ENV_NAME
else
    echo "Используем venv..."
    if [ -d "$HOME/$ENV_NAME" ]; then
        echo "Старое окружение найдено. Удаляем..."
        rm -rf "$HOME/$ENV_NAME"
    fi
    $PYTHON_CMD -m venv "$HOME/$ENV_NAME"
    source "$HOME/$ENV_NAME/bin/activate"
fi

echo -e "${GREEN}✅ Окружение создано. Python: $(python --version)${NC}"

# ================================================
# Шаг 5: Клонирование ComfyUI и АВТОМАТИЧЕСКАЯ ПРАВКА requirements.txt
# ================================================
echo -e "\n${YELLOW}[5/7] Клонирование ComfyUI...${NC}"
if [ -d "$COMFYUI_DIR" ]; then
    echo "Папка $COMFYUI_DIR уже существует. Обновляем..."
    cd "$COMFYUI_DIR"
    git pull
else
    git clone "$COMFYUI_REPO" "$COMFYUI_DIR"
fi
cd "$COMFYUI_DIR"

echo -e "\n${YELLOW}Адаптация requirements.txt для Python 3.10...${NC}"
cp requirements.txt requirements.txt.bak
sed -i 's/^comfyui-frontend-package==.*$/comfyui-frontend-package>=1.45.0/' requirements.txt
sed -i 's/^comfyui-workflow-templates==.*$/comfyui-workflow-templates>=0.11.0/' requirements.txt
sed -i 's/^comfyui-embedded-docs==.*$/comfyui-embedded-docs>=0.5.0/' requirements.txt
echo -e "${GREEN}✅ requirements.txt адаптирован${NC}"

# ================================================
# Шаг 6: Установка зависимостей ComfyUI и PyTorch
# ================================================
echo -e "\n${YELLOW}[6/7] Установка зависимостей...${NC}"
pip install --upgrade pip
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu130
pip install -r requirements.txt

# ================================================
# Шаг 7: Установка кастомных нод и зависимостей EchoMimic
# ================================================
echo -e "\n${YELLOW}[7/7] Установка EchoMimic и кастомных нод...${NC}"

mkdir -p "$COMFYUI_DIR/custom_nodes"
cd "$COMFYUI_DIR/custom_nodes"

echo "  - Установка EchoMimic..."
git clone https://github.com/smthemex/ComfyUI_EchoMimic.git

echo "  - Установка Video Helper Suite..."
git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git

echo "  - Установка ComfyUI-Manager..."
git clone https://github.com/ltdrdata/ComfyUI-Manager.git

echo "  - Установка зависимостей EchoMimic..."
pip install diffusers transformers accelerate safetensors
pip install opencv-python-headless moviepy ipython
pip install facexlib basicsr gfpgan ultralytics
pip install mediapipe-silicon einops omegaconf
pip install huggingface_hub sentencepiece protobuf
pip install librosa soundfile ffmpeg-python torchcodec
pip install decord pyloudnorm

echo "  - Установка совместимой версии OpenCV..."
pip uninstall opencv-python opencv-contrib-python opencv-python-headless -y || true
pip install opencv-python==4.9.0.80 opencv-contrib-python==4.9.0.80 opencv-python-headless==4.9.0.80

# ================================================
# Применение патчей для EchoMimic
# ================================================
echo "  - Применение патчей для EchoMimic..."

DIST_DIR="$COMFYUI_DIR/custom_nodes/ComfyUI_EchoMimic/echomimic_v3/src/dist"
mkdir -p "$DIST_DIR"

cat > "$DIST_DIR/parallel.py" << 'EOF'
def get_sequence_parallel_rank():
    return 0

def get_sequence_parallel_world_size():
    return 1

def get_sp_group():
    return None

def xFuserLongContextAttention(q, k, v, attn_mask=None, dropout_p=0.0, is_causal=False):
    import torch
    import torch.nn.functional as F
    if attn_mask is not None:
        attn_mask = attn_mask.to(q.dtype)
    return F.scaled_dot_product_attention(
        q, k, v,
        attn_mask=attn_mask,
        dropout_p=dropout_p,
        is_causal=is_causal
    )
EOF

cat > "$DIST_DIR/wan_xfuser.py" << 'EOF'
import torch
import torch.nn.functional as F

def usp_attn_forward(q, k, v, attn_mask=None, dropout_p=0.0, is_causal=False, sp_rank=0, sp_world_size=1, **kwargs):
    if sp_world_size <= 1:
        return F.scaled_dot_product_attention(q, k, v, attn_mask=attn_mask, dropout_p=dropout_p, is_causal=is_causal)
    batch_size, num_heads, seq_len, head_dim = q.shape
    local_seq_len = seq_len // sp_world_size
    start_idx = sp_rank * local_seq_len
    end_idx = start_idx + local_seq_len
    q_local = q[:, :, start_idx:end_idx, :]
    k_local = k[:, :, start_idx:end_idx, :]
    v_local = v[:, :, start_idx:end_idx, :]
    return F.scaled_dot_product_attention(q_local, k_local, v_local, attn_mask=attn_mask, dropout_p=dropout_p, is_causal=is_causal)

def get_xfuser_attention():
    return usp_attn_forward
EOF

cat > "$DIST_DIR/__init__.py" << 'EOF'
from .parallel import (
    get_sequence_parallel_rank,
    get_sequence_parallel_world_size,
    get_sp_group,
    xFuserLongContextAttention
)
from .wan_xfuser import usp_attn_forward, get_xfuser_attention
EOF

# ================================================
# Создание скриптов
# ================================================
echo -e "\n${GREEN}Создание скриптов...${NC}"

cat > "$COMFYUI_DIR/run_comfyui.sh" << 'EOF'
#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh 2>/dev/null || source ~/anaconda3/etc/profile.d/conda.sh 2>/dev/null
conda activate comfy_echo 2>/dev/null || source ~/comfy_echo/bin/activate
cd ~/ComfyUI_Echo
python main.py --listen 0.0.0.0 --port 8188 "$@"
EOF
chmod +x "$COMFYUI_DIR/run_comfyui.sh"

cat > "$COMFYUI_DIR/download_models.sh" << 'EOF'
#!/bin/bash
echo "Скачивание моделей EchoMimic..."
pip install huggingface-hub
huggingface-cli download BadToBest/EchoMimicV3 --include "echomimicv3-flash-pro/*" --local-dir ~/ComfyUI_Echo/models/echo_mimic/
huggingface-cli download TencentGameMate/chinese-wav2vec2-base --local-dir ~/ComfyUI_Echo/models/echo_mimic/chinese-wav2vec2-base/
huggingface-cli download BadToBest/EchoMimicV3 --include "transformer/*" "wan_2.1_vae.safetensors" --local-dir ~/ComfyUI_Echo/models/echo_mimic/
echo "Модели скачаны!"
EOF
chmod +x "$COMFYUI_DIR/download_models.sh"

# ================================================
# Готово!
# ================================================
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ УСТАНОВКА ЗАВЕРШЕНА!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e ""
echo -e "📌 ДАЛЬНЕЙШИЕ ДЕЙСТВИЯ:"
echo -e "─────────────────────────────"
echo -e "1. Скачайте модели:"
echo -e "   ~/ComfyUI_Echo/download_models.sh"
echo -e ""
echo -e "2. Запустите ComfyUI:"
echo -e "   ~/ComfyUI_Echo/run_comfyui.sh"
echo -e ""
echo -e "3. Откройте браузер: http://localhost:8188"
echo -e ""
echo -e "📂 Репозиторий: https://github.com/vokilook/comfyui-echomimic-setup"
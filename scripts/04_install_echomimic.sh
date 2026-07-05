#!/bin/bash
# ================================================
# 04_install_echomimic.sh - Установка EchoMimic и патчей
# ================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

STEP_FILE="/tmp/step04_complete"

if [ -f "$STEP_FILE" ]; then
    echo -e "${GREEN}✅ Шаг 4 уже выполнен. Пропускаем.${NC}"
    exit 0
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Шаг 4: Установка EchoMimic и патчей${NC}"
echo -e "${GREEN}========================================${NC}"

COMFYUI_DIR="$HOME/ComfyUI_Echo"
CUSTOM_NODES_DIR="$COMFYUI_DIR/custom_nodes"
ECHO_DIR="$CUSTOM_NODES_DIR/ComfyUI_EchoMimic"

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

# Клонирование EchoMimic
echo -e "\n${YELLOW}Установка EchoMimic...${NC}"
mkdir -p "$CUSTOM_NODES_DIR"
cd "$CUSTOM_NODES_DIR"

if [ -d "$ECHO_DIR" ]; then
    echo "EchoMimic уже установлен. Обновляем..."
    cd "$ECHO_DIR"
    git pull
else
    git clone https://github.com/smthemex/ComfyUI_EchoMimic.git
fi

# Установка VHS и ComfyUI-Manager
echo -e "\n${YELLOW}Установка Video Helper Suite и ComfyUI-Manager...${NC}"
cd "$CUSTOM_NODES_DIR"

[ -d "ComfyUI-VideoHelperSuite" ] || git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
[ -d "ComfyUI-Manager" ] || git clone https://github.com/ltdrdata/ComfyUI-Manager.git

# Установка зависимостей EchoMimic (исправлено: mediapipe==0.10.8)
echo -e "\n${YELLOW}Установка зависимостей EchoMimic...${NC}"
pip install diffusers transformers accelerate safetensors
pip install opencv-python-headless moviepy ipython
pip install facexlib basicsr gfpgan ultralytics
pip install mediapipe==0.10.8 einops omegaconf
pip install huggingface_hub sentencepiece protobuf
pip install librosa soundfile ffmpeg-python torchcodec
pip install decord pyloudnorm

# Правильный OpenCV
echo -e "\n${YELLOW}Установка совместимой версии OpenCV...${NC}"
pip uninstall opencv-python opencv-contrib-python opencv-python-headless -y 2>/dev/null || true
pip install opencv-python==4.9.0.80 opencv-contrib-python==4.9.0.80 opencv-python-headless==4.9.0.80

# Патчи для EchoMimic
echo -e "\n${YELLOW}Применение патчей для EchoMimic...${NC}"

DIST_DIR="$ECHO_DIR/echomimic_v3/src/dist"
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

# Создание скриптов
echo -e "\n${YELLOW}Создание скриптов...${NC}"

cat > "$COMFYUI_DIR/run_comfyui.sh" << 'EOF'
#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh 2>/dev/null || source ~/anaconda3/etc/profile.d/conda.sh 2>/dev/null
conda activate comfy_echo 2>/dev/null || source ~/comfy_echo/bin/activate
cd ~/ComfyUI_Echo
python main.py --listen 0.0.0.0 --port 8188 "$@"
EOF
chmod +x "$COMFYUI_DIR/run_comfyui.sh"

cat > "$COMFYUI_DIR/fix_echomimic.sh" << 'EOF'
#!/bin/bash
echo "Исправление EchoMimic_node.py..."
NODE_FILE="$HOME/ComfyUI_Echo/custom_nodes/ComfyUI_EchoMimic/EchoMimic_node.py"
if [ -f "$NODE_FILE" ]; then
    cp "$NODE_FILE" "$NODE_FILE.bak"
    echo "⚠️  Ручное исправление EchoMimic_node.py может потребоваться."
    echo "   Проверьте файл и убедитесь, что блок # pre audio исправлен."
else
    echo "Файл $NODE_FILE не найден."
fi
EOF
chmod +x "$COMFYUI_DIR/fix_echomimic.sh"

# Отметка о завершении
touch "$STEP_FILE"
echo -e "\n${GREEN}✅ Шаг 4 завершён!${NC}"
#!/bin/bash
# ================================================
# apply_patches.sh - Применение всех исправлений
# для EchoMimic после автоматической установки
# Автор: vokilook
# ================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Применение патчей для EchoMimic${NC}"
echo -e "${GREEN}========================================${NC}"

COMFYUI_DIR="$HOME/ComfyUI_Echo"
ECHO_DIR="$COMFYUI_DIR/custom_nodes/ComfyUI_EchoMimic"

# Проверка, что ComfyUI установлен
if [ ! -d "$COMFYUI_DIR" ]; then
    echo -e "${RED}Ошибка: ComfyUI не найден в $COMFYUI_DIR${NC}"
    echo "Сначала выполните ./install.sh"
    exit 1
fi

# Проверка, что EchoMimic установлен
if [ ! -d "$ECHO_DIR" ]; then
    echo -e "${RED}Ошибка: EchoMimic не найден в $ECHO_DIR${NC}"
    echo "Сначала выполните ./install.sh"
    exit 1
fi

# ================================================
# 1. Установка зависимостей EchoMimic
# ================================================
echo -e "\n${YELLOW}[1/6] Установка зависимостей EchoMimic...${NC}"
pip install diffusers transformers accelerate safetensors
pip install opencv-python-headless moviepy ipython
pip install facexlib basicsr gfpgan ultralytics
pip install mediapipe-silicon einops omegaconf
pip install huggingface_hub sentencepiece protobuf
pip install librosa soundfile ffmpeg-python torchcodec
pip install decord pyloudnorm

# ================================================
# 2. Установка правильной версии OpenCV
# ================================================
echo -e "\n${YELLOW}[2/6] Установка совместимой версии OpenCV...${NC}"
pip uninstall opencv-python opencv-contrib-python opencv-python-headless -y
pip install opencv-python==4.9.0.80 opencv-contrib-python==4.9.0.80 opencv-python-headless==4.9.0.80

# ================================================
# 3. Исправление импорта dist (parallel.py, wan_xfuser.py)
# ================================================
echo -e "\n${YELLOW}[3/6] Исправление модуля dist...${NC}"
DIST_DIR="$ECHO_DIR/echomimic_v3/src/dist"
mkdir -p "$DIST_DIR"
cd "$DIST_DIR"

cat > parallel.py << 'EOF'
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

cat > wan_xfuser.py << 'EOF'
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

cat > __init__.py << 'EOF'
from .parallel import (
    get_sequence_parallel_rank,
    get_sequence_parallel_world_size,
    get_sp_group,
    xFuserLongContextAttention
)
from .wan_xfuser import usp_attn_forward, get_xfuser_attention
EOF

echo -e "${GREEN}✅ Модуль dist создан${NC}"

# ================================================
# 4. Исправление EchoMimic_node.py (torchaudio.save)
# ================================================
echo -e "\n${YELLOW}[4/6] Исправление EchoMimic_node.py...${NC}"
NODE_FILE="$ECHO_DIR/EchoMimic_node.py"
BACKUP_FILE="$ECHO_DIR/EchoMimic_node.py.bak"

# Создаём бэкап
cp "$NODE_FILE" "$BACKUP_FILE"
echo -e "${GREEN}✅ Бэкап создан: $BACKUP_FILE${NC}"

# Находим блок # pre audio и заменяем его
python3 << 'PYTHON_SCRIPT'
import re
import os

node_file = os.path.expanduser("~/ComfyUI_Echo/custom_nodes/ComfyUI_EchoMimic/EchoMimic_node.py")

with open(node_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Определяем старый блок и новый
old_block_pattern = r'(# pre audio.*?)# pre data'
new_block = '''# pre audio
        audio_file_prefix = ''.join(random.choice("0123456789") for _ in range(6))
        audio_file = os.path.join(folder_paths.get_input_directory(), f"audio_{audio_file_prefix}_temp.wav")
        buff = io_base.BytesIO()

        # Создаём временный файл с расширением .flac
        import tempfile
        with tempfile.NamedTemporaryFile(suffix='.flac', delete=False) as tmp_file:
            temp_path = tmp_file.name

        # Сохраняем аудио в реальный файл
        torchaudio.save(temp_path, audio["waveform"].squeeze(0), audio["sample_rate"])

        # Читаем файл обратно в BytesIO
        with open(temp_path, 'rb') as f:
            buff.write(f.read())

        # Копируем временный файл в audio_file (для Echo_Predata)
        with open(temp_path, 'rb') as f_src:
            with open(audio_file, 'wb') as f_dst:
                f_dst.write(f_src.read())

        # Удаляем временный файл
        os.unlink(temp_path)

        # pre data'''

# Заменяем (с флагом DOTALL для многострочного поиска)
new_content = re.sub(old_block_pattern, new_block, content, flags=re.DOTALL)

# Проверяем, что замена произошла
if "import tempfile" in new_content:
    with open(node_file, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("✅ EchoMimic_node.py успешно исправлен")
else:
    print("⚠️ Не удалось найти блок # pre audio. Проверьте файл вручную.")
PYTHON_SCRIPT

# ================================================
# 5. Установка ffmpeg (если не установлен)
# ================================================
echo -e "\n${YELLOW}[5/6] Проверка ffmpeg...${NC}"
if ! command -v ffmpeg &> /dev/null; then
    echo "ffmpeg не найден. Устанавливаю..."
    sudo apt update
    sudo apt install ffmpeg -y
else
    echo -e "${GREEN}✅ ffmpeg уже установлен: $(ffmpeg -version | head -1)${NC}"
fi

# ================================================
# 6. Создание скрипта запуска (если нет)
# ================================================
echo -e "\n${YELLOW}[6/6] Проверка скрипта запуска...${NC}"
if [ ! -f "$COMFYUI_DIR/run_comfyui.sh" ]; then
    cat > "$COMFYUI_DIR/run_comfyui.sh" << 'EOF'
#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh 2>/dev/null || source ~/anaconda3/etc/profile.d/conda.sh 2>/dev/null
conda activate comfy_echo 2>/dev/null || source ~/comfy_echo/bin/activate
cd ~/ComfyUI_Echo
python main.py --listen 0.0.0.0 --port 8188 "$@"
EOF
    chmod +x "$COMFYUI_DIR/run_comfyui.sh"
    echo -e "${GREEN}✅ Скрипт запуска создан${NC}"
else
    echo -e "${GREEN}✅ Скрипт запуска уже существует${NC}"
fi

# ================================================
# Готово!
# ================================================
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ ВСЕ ПАТЧИ ПРИМЕНЕНЫ!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e ""
echo -e "Теперь скачайте модели:"
echo -e "  huggingface-cli download BadToBest/EchoMimicV3 --include \"echomimicv3-flash-pro/*\" --local-dir ~/ComfyUI_Echo/models/echo_mimic/"
echo -e "  huggingface-cli download TencentGameMate/chinese-wav2vec2-base --local-dir ~/ComfyUI_Echo/models/echo_mimic/chinese-wav2vec2-base/"
echo -e "  huggingface-cli download BadToBest/EchoMimicV3 --include \"transformer/*\" \"wan_2.1_vae.safetensors\" --local-dir ~/ComfyUI_Echo/models/echo_mimic/"
echo -e ""
echo -e "После скачивания моделей запустите ComfyUI:"
echo -e "  ~/ComfyUI_Echo/run_comfyui.sh"
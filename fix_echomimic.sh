#!/bin/bash
# ================================================
# fix_echomimic.sh - Автоматическое исправление EchoMimic_node.py
# Заменяет блок # pre audio на рабочую версию
# ================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Исправление EchoMimic_node.py${NC}"
echo -e "${GREEN}========================================${NC}"

NODE_FILE="$HOME/ComfyUI_Echo/custom_nodes/ComfyUI_EchoMimic/EchoMimic_node.py"

if [ ! -f "$NODE_FILE" ]; then
    echo -e "${RED}Ошибка: файл $NODE_FILE не найден!${NC}"
    exit 1
fi

# Создаём бэкап
cp "$NODE_FILE" "$NODE_FILE.bak"
echo -e "${GREEN}✅ Бэкап создан: $NODE_FILE.bak${NC}"

# Исправляем блок # pre audio с помощью Python скрипта
python3 << 'PYTHON_SCRIPT'
import re
import os

node_file = os.path.expanduser("~/ComfyUI_Echo/custom_nodes/ComfyUI_EchoMimic/EchoMimic_node.py")

with open(node_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Новый блок кода (исправленная версия)
new_block = '''        # pre audio
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

# Ищем старый блок и заменяем
pattern = r'(# pre audio.*?)# pre data'
new_content = re.sub(pattern, new_block, content, flags=re.DOTALL)

# Проверяем, что замена произошла
if "import tempfile" in new_content and "torchaudio.save(temp_path" in new_content:
    with open(node_file, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("SUCCESS")
else:
    # Если замена не сработала, пытаемся найти и заменить конкретные строки
    lines = content.split('\n')
    new_lines = []
    i = 0
    in_pre_audio = False
    pre_audio_start = -1
    pre_audio_end = -1
    
    # Находим блок # pre audio
    for i, line in enumerate(lines):
        if '# pre audio' in line:
            pre_audio_start = i
        if pre_audio_start != -1 and '# pre data' in line:
            pre_audio_end = i
            break
    
    if pre_audio_start != -1 and pre_audio_end != -1:
        # Заменяем строки с pre_audio_start по pre_audio_end
        new_lines = lines[:pre_audio_start] + new_block.split('\n') + lines[pre_audio_end:]
        with open(node_file, 'w', encoding='utf-8') as f:
            f.write('\n'.join(new_lines))
        print("SUCCESS_MANUAL")
    else:
        print("FAILED")
PYTHON_SCRIPT

# Проверяем результат
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Файл EchoMimic_node.py успешно исправлен!${NC}"
    echo -e "${GREEN}   Сделана замена блока # pre audio${NC}"
else
    echo -e "${RED}❌ Не удалось автоматически исправить файл.${NC}"
    echo -e "${YELLOW}   Попробуйте исправить вручную:${NC}"
    echo "   nano $NODE_FILE"
    echo "   Найдите блок # pre audio и замените его на исправленный код"
    echo "   (см. документацию в репозитории)"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Готово!${NC}"
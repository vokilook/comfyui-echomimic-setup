#!/bin/bash
# check_models.sh - Проверка наличия всех моделей
# Автор: vokilook

MODELS_DIR="$HOME/ComfyUI_Echo/models/echo_mimic"

echo "Проверка моделей EchoMimic..."
echo "================================"

check_file() {
    if [ -f "$1" ]; then
        SIZE=$(du -h "$1" | cut -f1)
        echo "✅ $2: $SIZE"
    else
        echo "❌ $2: НЕ НАЙДЕН"
        MISSING="$MISSING\n  - $2"
    fi
}

check_file "$MODELS_DIR/echomimicv3-flash-pro/diffusion_pytorch_model.safetensors" "V3 Flash Model"
check_file "$MODELS_DIR/chinese-wav2vec2-base/pytorch_model.bin" "Wav2Vec2 Model"
check_file "$MODELS_DIR/transformer/diffusion_pytorch_model.safetensors" "Transformer Model"
check_file "$MODELS_DIR/wan_2.1_vae.safetensors" "VAE Model"

if [ -n "$MISSING" ]; then
    echo -e "\n⚠️  Отсутствуют модели:$MISSING"
    echo "Скачайте их с HuggingFace:"
    echo "  - https://huggingface.co/BadToBest/EchoMimicV3"
    echo "  - https://huggingface.co/TencentGameMate/chinese-wav2vec2-base"
else
    echo -e "\n✅ Все модели на месте!"
fi
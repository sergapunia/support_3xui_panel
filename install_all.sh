#!/bin/bash
set -e

DOMAIN=$1

if [ -z "$DOMAIN" ]; then
    echo "❌ Использование: sudo bash install_all.sh твой_домен.com"
    exit 1
fi

REPO_URL="https://github.com/sergapunia/support_3xui_panel.git"
TARGET_DIR="/root/support_3xui_panel"

echo "🌟 ПОЛНАЯ УСТАНОВКА (Backend + Frontend)"

# 1. Клонирование (если запускается не из папки проекта)
if [ ! -f "setup_backend.sh" ]; then
    git clone "$REPO_URL" "$TARGET_DIR"
    cd "$TARGET_DIR"
fi

# 2. Права на запуск
chmod +x setup_backend.sh setup_frontend.sh

# 3. Последовательная установка
./setup_backend.sh
./setup_frontend.sh "$DOMAIN"

echo "--------------------------------------------------"
echo "🎉 УСТАНОВКА ЗАВЕРШЕНА!"
echo "🔗 Подписки (Happ): https://$DOMAIN/sub/UUID"
echo "🔗 Админка: https://$DOMAIN"
echo "--------------------------------------------------"

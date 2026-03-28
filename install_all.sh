#!/bin/bash
set -e

DOMAIN=$1
if [ -z "$DOMAIN" ]; then echo "❌ Укажите домен!"; exit 1; fi

RAW_URL="https://raw.githubusercontent.com/sergapunia/support_3xui_panel/main"

echo "🌟 ПОЛНАЯ ЧИСТАЯ УСТАНОВКА"

# Бэкенд
curl -sL "$RAW_URL/setup_backend.sh" -o /tmp/setup_backend.sh
sudo bash /tmp/setup_backend.sh

# Фронтенд
curl -sL "$RAW_URL/setup_frontend.sh" -o /tmp/setup_frontend.sh
sudo bash /tmp/setup_frontend.sh "$DOMAIN"

echo "🎉 Готово! На сервере теперь только папка бэкенда и билд фронтенда."

#!/bin/bash
set -e

DOMAIN=$1
PORT=$2

if [ -z "$DOMAIN" ] || [ -z "$PORT" ]; then 
    echo "❌ Использование: sudo bash install_all.sh ДОМЕН ПОРТ"
    exit 1
fi

# Можно использовать локальные файлы, если они в одной папке, 
# либо качать с GitHub, как у тебя было:
RAW_URL="https://raw.githubusercontent.com/sergapunia/support_3xui_panel/main"

echo "🌟 ПОЛНАЯ УСТАНОВКА (Домен: $DOMAIN, Порт: $PORT)"

echo "--- [1/2] Установка Бэкенда ---"
curl -sL "$RAW_URL/setup_backend.sh" -o /tmp/setup_backend.sh
sudo bash /tmp/setup_backend.sh "$DOMAIN" "$PORT"

echo "--- [2/2] Установка Фронтенда ---"
curl -sL "$RAW_URL/setup_frontend.sh" -o /tmp/setup_frontend.sh
sudo bash /tmp/setup_frontend.sh "$DOMAIN" "$PORT"

echo "----------------------------------------------------"
echo "🎉 ВСЁ УСТАНОВЛЕНО!"
echo "🌐 Адрес панели: https://$DOMAIN:$PORT"
echo "----------------------------------------------------"

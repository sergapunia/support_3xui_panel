#!/bin/bash
set -e

DOMAIN=$1
PORT=$2

if [ -z "$DOMAIN" ] || [ -z "$PORT" ]; then 
    echo "❌ Использование: sudo bash install_all.sh ДОМЕН ПОРТ"
    echo "Пример: sudo bash install_all.sh sergamainpanel.mooo.com 8443"
    exit 1
fi

RAW_URL="https://raw.githubusercontent.com/sergapunia/support_3xui_panel/main"

echo "🌟 ПОЛНАЯ ЧИСТАЯ УСТАНОВКА (Домен: $DOMAIN, Порт: $PORT)"

# 1. Бэкенд (передаем домен и порт для настройки ссылок подписок)
curl -sL "$RAW_URL/setup_backend.sh" -o /tmp/setup_backend.sh
sudo bash /tmp/setup_backend.sh "$DOMAIN" "$PORT"

# 2. Фронтенд (настраиваем Nginx на тот же порт)
curl -sL "$RAW_URL/setup_frontend.sh" -o /tmp/setup_frontend.sh
sudo bash /tmp/setup_frontend.sh "$DOMAIN" "$PORT"

echo "----------------------------------------------------"
echo "🎉 ВСЁ УСТАНОВЛЕНО!"
echo "🌐 Сайт: https://$DOMAIN:$PORT"
echo "🔐 API проксируется через этот же порт автоматически."
echo "----------------------------------------------------"

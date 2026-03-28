#!/bin/bash
set -e

DOMAIN=$1
PORT=$2 # Порт, на котором будет висеть Nginx

# Конфигурация
REPO_URL="https://github.com/sergapunia/support_3xui_panel.git"
TARGET_DIR="/root/support_backend"
BACKEND_DIR="$TARGET_DIR/bs_server_programm"
VENV_PATH="$BACKEND_DIR/venv"

echo "📥 Клонирование репозитория..."
sudo rm -rf "$TARGET_DIR"
git clone "$REPO_URL" "$TARGET_DIR"

if [ ! -d "$BACKEND_DIR" ]; then
    echo "❌ Ошибка: Папка $BACKEND_DIR не найдена!"
    exit 1
fi

echo "🐍 Настройка Python окружения..."
sudo apt-get update && sudo apt-get install -y python3 python3-pip python3-venv

python3 -m venv "$VENV_PATH"
source "$VENV_PATH/bin/activate"
pip install --upgrade pip
pip install fastapi uvicorn requests pydantic cryptography python-multipart

echo "⚙️ Создание службы bs_backend.service..."
sudo cat > /etc/systemd/system/bs_backend.service <<EOF
[Unit]
Description=FastAPI 3x-ui Bridge
After=network.target

[Service]
User=root
WorkingDirectory=$BACKEND_DIR
# Передаем внешний порт Nginx бэкенду
Environment="EXTERNAL_PORT=$PORT"
ExecStart=$VENV_PATH/bin/python3 main.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable bs_backend
sudo systemctl restart bs_backend

echo "✅ Бэкенд запущен (внутренний порт 8000, внешний $PORT)."

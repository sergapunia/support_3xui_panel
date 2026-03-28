#!/bin/bash
set -e

# Определяем пути относительно текущей директории
PROJECT_DIR=$(pwd)
BACKEND_DIR="$PROJECT_DIR/bs_server_programm"
VENV_PATH="$BACKEND_DIR/venv"

echo "🐍 Настройка Бэкенда (API) в $BACKEND_DIR..."

# Установка зависимостей
sudo apt-get update && sudo apt-get install -y python3 python3-pip python3-venv

# Создание venv и установка библиотек
python3 -m venv "$VENV_PATH"
source "$VENV_PATH/bin/activate"
pip install --upgrade pip
pip install fastapi uvicorn requests pydantic cryptography

# Создание системной службы
echo "⚙️ Создание службы bs_backend.service..."
sudo cat > /etc/systemd/system/bs_backend.service <<EOF
[Unit]
Description=FastAPI 3x-ui Bridge
After=network.target

[Service]
User=root
WorkingDirectory=$BACKEND_DIR
ExecStart=$VENV_PATH/bin/python3 main.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable bs_backend
sudo systemctl restart bs_backend

echo "✅ Бэкенд успешно запущен на 127.0.0.1:8000"

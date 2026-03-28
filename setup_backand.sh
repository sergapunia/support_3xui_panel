#!/bin/bash
set -e

# Конфигурация
REPO_URL="https://github.com/sergapunia/support_3xui_panel.git"
TARGET_DIR="/root/support_backend"
BACKEND_DIR="$TARGET_DIR/bs_server_programm"
VENV_PATH="$BACKEND_DIR/venv"

echo "📥 Клонирование репозитория в $TARGET_DIR..."

# 1. Очистка и клонирование
sudo rm -rf "$TARGET_DIR"
git clone "$REPO_URL" "$TARGET_DIR"

# Проверка, что папка существует
if [ ! -d "$BACKEND_DIR" ]; then
    echo "❌ Ошибка: Папка $BACKEND_DIR не найдена в репозитории!"
    exit 1
fi

echo "🐍 Настройка Бэкенда (API) в $BACKEND_DIR..."

# 2. Установка системных зависимостей
sudo apt-get update && sudo apt-get install -y python3 python3-pip python3-venv

# 3. Создание venv и установка библиотек
python3 -m venv "$VENV_PATH"
source "$VENV_PATH/bin/activate"
pip install --upgrade pip
# Добавляем python-multipart для корректной работы форм авторизации
pip install fastapi uvicorn requests pydantic cryptography python-multipart

# 4. Создание системной службы
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

# 5. Запуск
sudo systemctl daemon-reload
sudo systemctl enable bs_backend
sudo systemctl restart bs_backend

echo "✅ Бэкенд успешно запущен и работает как служба."

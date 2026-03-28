#!/bin/bash
set -e

# --- НАСТРОЙКИ ---
USER_NAME="sergapunia"
REPO_NAME="support_3xui_panel" # Замени на имя репозитория с веб-панелью
WEB_DIR="/var/www/support_panel"
# -----------------

echo "🚀 Starting Support Panel Turnkey Setup..."

# 1. Обновление и установка зависимостей
apt-get update
apt-get install -y nginx unzip curl git

# 2. Подготовка директории
rm -rf "$WEB_DIR" # Очищаем старое, если было
mkdir -p "$WEB_DIR"

# 3. Скачивание билда напрямую из GitHub Releases
echo "📥 Downloading latest web build..."
URL="https://github.com/$USER_NAME/$REPO_NAME/releases/download/latest/web-build.zip"
curl -L -o /tmp/web-build.zip "$URL"

# 4. Распаковка
echo "📦 Extracting files to $WEB_DIR..."
unzip -o /tmp/web-build.zip -d "$WEB_DIR"
rm /tmp/web-build.zip

# 5. Права доступа (чтобы Nginx мог читать файлы)
chown -R www-data:www-data "$WEB_DIR"
chmod -R 755 "$WEB_DIR"

# 6. Настройка Nginx
echo "📂 Configuring Nginx..."
cat > /etc/nginx/sites-available/support_panel <<EOF
server {
    listen 80;
    server_name _; 

    root $WEB_DIR;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Если твой FastAPI мост на этом же сервере на порту 8000
    location /api/ {
        proxy_pass http://127.0.0.1:8000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

# 7. Активация сайта
ln -sf /etc/nginx/sites-available/support_panel /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# 8. Перезапуск
nginx -t
systemctl restart nginx

echo "✅ DEPLOYMENT COMPLETE!"
echo "📍 Web Dashboard: http://$(curl -s ifconfig.me)"

#!/bin/bash
set -e

DOMAIN=$1

if [ -z "$DOMAIN" ]; then
    echo "❌ Ошибка: Укажите домен. Пример: ./setup_frontend.sh mydomain.com"
    exit 1
fi

USER_NAME="sergapunia"
REPO_NAME="support_3xui_panel"
WEB_DIR="/var/www/support_panel"

echo "🚀 Настройка Фронтенда для домена: $DOMAIN"

sudo apt-get install -y nginx unzip curl

# Подготовка папки
sudo mkdir -p "$WEB_DIR"
sudo rm -rf "$WEB_DIR/*"

# Скачивание билда Flutter
echo "📥 Загрузка последнего билда..."
URL="https://github.com/$USER_NAME/$REPO_NAME/releases/download/latest/web-build.zip"
curl -L -o /tmp/web-build.zip "$URL"
sudo unzip -o /tmp/web-build.zip -d "$WEB_DIR"

# Умный поиск конфига Nginx с SSL
CONF_FILE=$(grep -l "$DOMAIN" /etc/nginx/sites-enabled/* /etc/nginx/conf.d/* 2>/dev/null | head -n 1)

# Создаем файл с логикой проксирования (Snippet)
sudo mkdir -p /etc/nginx/snippets
sudo cat > /etc/nginx/snippets/support_logic.conf <<EOF
    # API для Happ и Фронтенда (проброс на 8000 порт)
    location /sub/ {
        proxy_pass http://127.0.0.1:8000/sub/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /auth {
        proxy_pass http://127.0.0.1:8000/auth;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    # Если обращаются в корень домена, отдаем Flutter панель
    # Если панель 3x-ui занимает корень, можно сменить на location /support/
    location / {
        root $WEB_DIR;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
EOF

if [ -n "$CONF_FILE" ]; then
    echo "🛠 Внедрение в существующий SSL конфиг: $CONF_FILE"
    if ! grep -q "support_logic.conf" "$CONF_FILE"; then
        # Вставляем инклуд сразу после строки с listen 443
        sudo sed -i '/listen 443 ssl/a \    include /etc/nginx/snippets/support_logic.conf;' "$CONF_FILE"
    fi
else
    echo "🌐 SSL конфиг не найден. Создаем новый на 80 порту..."
    CONF_FILE="/etc/nginx/sites-available/support_panel"
    sudo cat > "$CONF_FILE" <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    include /etc/nginx/snippets/support_logic.conf;
}
EOF
    sudo ln -sf "$CONF_FILE" /etc/nginx/sites-enabled/
fi

sudo nginx -t && sudo systemctl restart nginx
echo "✅ Фронтенд и Nginx настроены!"

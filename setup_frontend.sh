#!/bin/bash
set -e

DOMAIN=$1
USER_NAME="sergapunia"
REPO_NAME="support_3xui_panel"
WEB_DIR="/var/www/support_panel"

echo "🚀 Установка Фронтенда..."

sudo apt-get update && sudo apt-get install -y nginx unzip curl
sudo mkdir -p "$WEB_DIR"
sudo rm -rf "$WEB_DIR/*"

# Скачиваем билд
URL="https://github.com/$USER_NAME/$REPO_NAME/releases/download/latest/web-build.zip"
curl -L -o /tmp/web-build.zip "$URL"
sudo unzip -o /tmp/web-build.zip -d "$WEB_DIR"
rm /tmp/web-build.zip

# Конфиг Nginx (Snippet) с полной поддержкой CORS
sudo mkdir -p /etc/nginx/snippets
sudo cat > /etc/nginx/snippets/support_logic.conf <<EOF
    location /sub/ {
        proxy_pass http://127.0.0.1:8000/sub/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /auth {
        # Обработка Preflight запросов браузера
        if (\$request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '*';
            add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS, PUT, DELETE';
            add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization';
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Type' 'text/plain; charset=utf-8';
            add_header 'Content-Length' 0;
            return 204;
        }

        proxy_pass http://127.0.0.1:8000/auth;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # Добавляем заголовки CORS для обычных запросов
        add_header 'Access-Control-Allow-Origin' '*' always;
    }

    location / {
        root $WEB_DIR;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
EOF

# Привязка к существующему SSL конфигу (например, от 3x-ui)
CONF_FILE=$(grep -l "$DOMAIN" /etc/nginx/sites-enabled/* 2>/dev/null | head -n 1)

if [ -n "$CONF_FILE" ]; then
    # Если файл найден, убираем старый инклуд (если был) и ставим свежий
    sudo sed -i '/support_logic.conf/d' "$CONF_FILE"
    # Вставляем после строки с SSL
    sudo sed -i '/listen 443 ssl/a \    include /etc/nginx/snippets/support_logic.conf;' "$CONF_FILE"
else
    # Если SSL еще нет (чистый сервер)
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
echo "✅ Фронтенд и Nginx настроены."

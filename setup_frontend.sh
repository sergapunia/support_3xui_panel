#!/bin/bash
set -e

DOMAIN=$1
USER_NAME="sergapunia"
REPO_NAME="support_3xui_panel"
WEB_DIR="/var/www/support_panel"

echo "🚀 Установка Фронтенда (Build из Release)..."

sudo apt-get update && sudo apt-get install -y nginx unzip curl
sudo mkdir -p "$WEB_DIR"
sudo rm -rf "$WEB_DIR/*"

# Скачиваем билд
URL="https://github.com/$USER_NAME/$REPO_NAME/releases/download/latest/web-build.zip"
curl -L -o /tmp/web-build.zip "$URL"
sudo unzip -o /tmp/web-build.zip -d "$WEB_DIR"
rm /tmp/web-build.zip

# Конфиг Nginx (Snippet)
sudo mkdir -p /etc/nginx/snippets
sudo cat > /etc/nginx/snippets/support_logic.conf <<EOF
    location /sub/ {
        proxy_pass http://127.0.0.1:8000/sub/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    location /auth {
        proxy_pass http://127.0.0.1:8000/auth;
        proxy_set_header Host \$host;
    }
    location / {
        root $WEB_DIR;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
EOF

# Привязка к домену
CONF_FILE=$(grep -l "$DOMAIN" /etc/nginx/sites-enabled/* /etc/nginx/conf.d/* 2>/dev/null | head -n 1)

if [ -n "$CONF_FILE" ]; then
    if ! grep -q "support_logic.conf" "$CONF_FILE"; then
        sudo sed -i '/listen 443 ssl/a \    include /etc/nginx/snippets/support_logic.conf;' "$CONF_FILE"
    fi
else
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
echo "✅ Фронтенд установлен без исходного кода."

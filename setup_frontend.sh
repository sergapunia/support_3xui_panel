#!/bin/bash
set -e

DOMAIN=$1
PORT=$2
WEB_DIR="/var/www/support_panel"

if [ -z "$DOMAIN" ] || [ -z "$PORT" ]; then
    echo "❌ Ошибка: Укажите домен и порт!"
    exit 1
fi

echo "🔧 Настройка Nginx (HTTPS порт $PORT)..."

sudo mkdir -p "$WEB_DIR"
URL="https://github.com/sergapunia/support_3xui_panel/releases/download/latest/web-build.zip"
curl -L -o /tmp/web-build.zip "$URL"
sudo unzip -o /tmp/web-build.zip -d "$WEB_DIR"

sudo cat > /etc/nginx/sites-available/support_panel <<EOF
server {
    listen $PORT ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Фронтенд
    location / {
        root $WEB_DIR;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }

    # Проксирование ВСЕХ запросов к бэкенду
    location ~ ^/(auth|sub|config|inbounds|sub-link) {
        if (\$request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '*' always;
            add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS, PUT, DELETE' always;
            add_header 'Access-Control-Allow-Headers' 'Authorization,Content-Type' always;
            return 204;
        }
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        add_header 'Access-Control-Allow-Origin' '*' always;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/support_panel /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

sudo nginx -t
sudo systemctl restart nginx
sudo ufw allow $PORT/tcp 2>/dev/null || true

echo "✅ Nginx настроен на порт $PORT"

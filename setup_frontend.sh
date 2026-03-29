#!/bin/bash
set -e

DOMAIN=$1
PORT=$2
WEB_DIR="/var/www/support_panel"

if [ -z "$DOMAIN" ] || [ -z "$PORT" ]; then
    echo "❌ Ошибка: Укажите домен и порт!"
    exit 1
fi

echo "📦 Установка Nginx и Unzip..."
sudo apt-get update && sudo apt-get install -y nginx unzip curl

echo "🔍 Поиск SSL сертификатов для $DOMAIN..."
CERT_FILE="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
KEY_FILE="/etc/letsencrypt/live/$DOMAIN/privkey.pem"

if [ ! -f "$CERT_FILE" ]; then
    CERT_FILE="/root/.acme.sh/${DOMAIN}_ecc/fullchain.cer"
    KEY_FILE="/root/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.key"
fi

if [ ! -f "$CERT_FILE" ]; then
    echo "❌ Ошибка: Сертификаты не найдены!"
    exit 1
fi

echo "🔧 Настройка Nginx (HTTPS порт $PORT)..."
sudo mkdir -p "$WEB_DIR"
sudo mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

URL="https://github.com/sergapunia/support_3xui_panel/releases/download/latest/web-build.zip"
curl -L -o /tmp/web-build.zip "$URL"
sudo unzip -o /tmp/web-build.zip -d "$WEB_DIR"

# СОЗДАЕМ КОНФИГ С ИСПОЛЬЗОВАНИЕМ 'EOF' (В ОДИНАРНЫХ КАВЫЧКАХ)
sudo bash -c "cat > /etc/nginx/sites-available/support_panel <<'EOF'
server {
    listen __PORT__ ssl;
    server_name __DOMAIN__;

    ssl_certificate __CERT__;
    ssl_certificate_key __KEY__;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        root __WEBDIR__;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }

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
EOF"

# ТЕПЕРЬ ПОДСТАВЛЯЕМ НАШИ ПЕРЕМЕННЫЕ ЧЕРЕЗ SED
sudo sed -i "s|__PORT__|$PORT|g" /etc/nginx/sites-available/support_panel
sudo sed -i "s|__DOMAIN__|$DOMAIN|g" /etc/nginx/sites-available/support_panel
sudo sed -i "s|__CERT__|$CERT_FILE|g" /etc/nginx/sites-available/support_panel
sudo sed -i "s|__KEY__|$KEY_FILE|g" /etc/nginx/sites-available/support_panel
sudo sed -i "s|__WEBDIR__|$WEB_DIR|g" /etc/nginx/sites-available/support_panel

echo "🔄 Активация конфигурации..."
sudo ln -sf /etc/nginx/sites-available/support_panel /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default || true

if sudo nginx -t; then
    sudo systemctl restart nginx
    sudo ufw allow $PORT/tcp 2>/dev/null || true
    echo "✅ Nginx успешно настроен на порт $PORT"
else
    echo "❌ Ошибка в конфигурации Nginx! Посмотри файл командой: cat /etc/nginx/sites-available/support_panel"
    exit 1
fi

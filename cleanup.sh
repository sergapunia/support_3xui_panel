#!/bin/bash
set -e

PROJECT_NAME="support_3xui_panel"
INSTALL_DIR="/root/$PROJECT_NAME"
WEB_DIR="/var/www/support_panel"

echo "🗑️ Начинаем полную очистку сервера от $PROJECT_NAME..."

# 1. Остановка и удаление системных служб
echo "🛑 Останавливаем службы..."
sudo systemctl stop bs_backend.service 2>/dev/null || true
sudo systemctl disable bs_backend.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/bs_backend.service
sudo systemctl daemon-reload

# 2. Очистка Nginx
echo "🌐 Удаляем конфигурации Nginx..."
# Удаляем основной конфиг, если он был создан скриптом
sudo rm -f /etc/nginx/sites-enabled/support_panel
sudo rm -f /etc/nginx/sites-available/support_panel
# Удаляем сниппет с логикой
sudo rm -f /etc/nginx/snippets/support_logic.conf

# 3. Очистка файлов проекта
echo "📁 Удаляем файлы проекта и веб-панели..."
sudo rm -rf "$INSTALL_DIR"
sudo rm -rf "$WEB_DIR"

# 4. Проверка конфигов на наличие "грязных" инклудов
# Если мы вставляли include в существующий конфиг 3x-ui, нужно его вычистить
echo "🧹 Удаляем следы из существующих конфигов Nginx..."
grep -r "support_logic.conf" /etc/nginx/ | cut -d: -f1 | xargs -r sudo sed -i '/support_logic.conf/d'

# 5. Перезапуск Nginx
echo "🔄 Перезапуск Nginx..."
sudo nginx -t && sudo systemctl restart nginx

echo "--------------------------------------------------"
echo "✨ ОЧИСТКА ЗАВЕРШЕНА!"
echo "Сервер готов к чистой установке."
echo "--------------------------------------------------"

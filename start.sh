#!/bin/bash
set -e

echo "🚀 Starting X-UI + nginx reverse proxy..."

# nginx همیشه روی پورت ثابت 3000 گوش می‌دهد
export NGINX_PORT=3000

cd /usr/local/x-ui

mkdir -p /etc/x-ui

# مسیر پنل: بار اول تصادفی ساخته و در /etc/x-ui ماندگار می‌شود تا بین
# ری‌استارت‌ها ثابت بماند، ولی هرگز داخل این ریپوی عمومی ذخیره نشود
PANEL_PATH_FILE=/etc/x-ui/.panel_base_path
if [ -s "$PANEL_PATH_FILE" ]; then
  XUI_BASE_PATH=$(cat "$PANEL_PATH_FILE")
else
  XUI_BASE_PATH="/panel-$(head -c 12 /dev/urandom | base64 | tr -dc 'a-z0-9' | head -c 10)/"
  echo "$XUI_BASE_PATH" > "$PANEL_PATH_FILE"
fi
export XUI_BASE_PATH

# اعتبار ورود مدیریت: فقط بار اول از env اعمال می‌شود و بعدش هرگز —
# تا تغییر پسوردی که از داخل پنل انجام می‌شود با هر دیپلوی دوباره بازنویسی نشود
CREDS_MARKER=/etc/x-ui/.creds_set
if [ ! -e "$CREDS_MARKER" ] && [ -n "$XUI_USERNAME" ] && [ -n "$XUI_PASSWORD" ]; then
  echo "🔧 Applying first-boot admin credentials from env..."
  ./x-ui setting -username "$XUI_USERNAME" -password "$XUI_PASSWORD" || true
  touch "$CREDS_MARKER"
fi

echo "🔧 Applying panel settings via x-ui CLI..."
./x-ui setting -port 2053 -webBasePath "$XUI_BASE_PATH" || true

echo "✅ Panel base path for this deployment: $XUI_BASE_PATH"

echo "🔧 Building nginx.conf for port $NGINX_PORT, base path $XUI_BASE_PATH"
envsubst '${NGINX_PORT} ${XUI_BASE_PATH}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

echo "▶️  Starting x-ui in background..."
./x-ui &
X_UI_PID=$!

sleep 2

echo "▶️  Starting nginx in foreground on port $NGINX_PORT..."
nginx -t
exec nginx -g "daemon off;"

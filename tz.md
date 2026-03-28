# Subscription API — Client Guide

## What is this?

Your Bridge server exposes a **subscription link** that Happ, Shadowrocket, v2rayNG, and similar VPN apps understand natively. When you add this URL, the app creates a **named card** (not "Other servers") with:

- Your custom display name
- Traffic progress bar (used / limit)
- Expiry date (if set)
- Auto-refresh every hour

---

## Subscription URL format

```
https://<bridge_public_url из config.json>/sub/<client_id>
```

`client_id` — UUID клиента из 3x-ui **или** его email.

### Получить готовую ссылку через API

```http
GET /sub-link/{client_id}
```

Ответ:
```json
{ "subscription_url": "https://sergamainpanel.mooo.com:8000/sub/ecbdfd57-..." }
```

Эту ссылку вставляешь в Happ.

### Прямой формат

```
https://sergamainpanel.mooo.com:8000/sub/ecbdfd57-253f-491c-b5c1-7ca128db89d0
```

или по email:

```
https://sergamainpanel.mooo.com:8000/sub/john_doe
```


---

## How to add in Happ

1. Open Happ → **+** → **Add from URL / Subscription**
2. Paste the subscription URL above
3. Tap **Import** — Happ will fetch the link, read the headers, and create a named card

The card title priority: client's `sub_name` (tgId) → client email → global `subscription.title` from `config.json`.

---

## How to set a custom card name

When creating or updating a client via the Bridge API, pass `sub_name`:

```http
POST /inbounds/{inbound_id}/clients
{
  "email": "john_doe",
  "limit_ip": 3,
  "sub_name": "🇷🇺 Russia Premium"
}
```

or update existing:

```http
PUT /inbounds/{inbound_id}/clients/john_doe
{
  "sub_name": "🇷🇺 Russia Premium"
}
```

The `sub_name` value becomes the card title in the VPN app. You can use emoji freely.

---

## HTTP response headers explained

The `/sub/{client_id}` endpoint returns these headers that VPN clients parse:

| Header | Purpose |
|---|---|
| `Profile-Title` | Card name (base64-encoded) |
| `Subscription-Userinfo` | Traffic + expiry for progress bar |
| `Profile-Update-Interval` | Auto-refresh interval (seconds, default 3600) |
| `Profile-Web-Page` | Support link shown in the card |
| `Content-Disposition` | Profile filename hint |

---

## Response body format

The body is a **base64-encoded** list of VLESS links (one per line, before encoding). Each link represents one `shortId` from the inbound. The VPN app decodes this automatically.

---

## Traffic & expiry display

- `total=0` → shown as "Unlimited"
- `expire=0` → shown as "Never expires"
- If `totalGB` is set on the client in 3x-ui, it shows as GB remaining
- If `expiryTime` is set (milliseconds), it converts to a human-readable date

---

## Quick test (curl)

```bash
curl -I https://my-bridge.example.com/sub/john_doe
```

You should see `Profile-Title`, `Subscription-Userinfo` etc. in the headers.

```bash
curl https://my-bridge.example.com/sub/john_doe | base64 -d
```

Should print all VLESS links for that client.

## Subscription card config (config.json)

Все параметры карточки хранятся в `config.json` в секции `subscription`:

```json
"subscription": {
  "title": "🇷🇺 Russia Premium VPN",
  "support_url": "https://t.me/sergapunia",
  "update_interval_sec": 3600
}
```

| Поле | Назначение |
|---|---|
| `title` | Название карточки по умолчанию (если у клиента не задан `sub_name`) |
| `support_url` | Ссылка на поддержку/бот в карточке (`Profile-Web-Page`) |
| `update_interval_sec` | Как часто клиент обновляет подписку (сек) |

### Обновить через API (без перезапуска)

```http
PATCH /config/subscription
{
  "title": "🔥 VPN Premium",
  "support_url": "https://t.me/my_bot",
  "update_interval_sec": 1800
}
```

Все поля опциональны — передавай только то, что хочешь изменить.

---

## Quick test (curl)

```bash
# Заголовки карточки
curl -I https://sergamainpanel.mooo.com:8000/sub/john_doe

# Декодировать VLESS-ссылки
curl https://sergamainpanel.mooo.com:8000/sub/john_doe | base64 -d
```

config.json:


{
  "bridge_public_url": "https://sergamainpanel.mooo.com:8000",
  "subscription": {
    "title": "🇷🇺 Russia Premium VPN",
    "description": "Fast & secure VLESS Reality | Support: @sergapunia",
    "support_url": "https://t.me/sergapunia",
    "update_interval_sec": 3600
  },
  "ip_cascad_server": "51.250.46.194",
  "port_cascad_server": 443,
  "3xui_admin": "0s0lruqQXj",
  "3xui_password": "NkbM6Sos3j",
  "host_current_server": "https://sergamainpanel.mooo.com/OOTl9lJJQ",
  "start_range_ports": 4443,
  "end_range_ports": 4443,
  "default_target": "smartcaptcha.yandexcloud.net:443",
  "default_sni": "smartcaptcha.yandexcloud.net",
  "base_inbound": {
    "remark_prefix": "Reality_Relay",
    "protocol": "vless",
    "decryption": "none",
    "encryption": "none",
    "flow": "xtls-rprx-vision",
    "fp": "chrome",
    "spiderX": "/",
    "xver": 0,
    "maxTimediff": 0,
    "proxyProtocol": 0,
    "sniffing": {
      "enabled": false,
      "destOverride": [
        "http",
        "tls",
        "quic",
        "fakedns"
      ],
      "metadataOnly": false,
      "routeOnly": false
    }
  }
}

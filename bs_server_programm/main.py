from fastapi import FastAPI, HTTPException, Body
from fastapi.responses import Response
from pydantic import BaseModel
import base64
from typing import Optional, List
import json
import os
import requests as _requests
from urllib.parse import urlparse
from panel_3xui.panel_class import XUIClient
from fastapi.middleware.cors import CORSMiddleware
import urllib.parse

app = FastAPI(title="3x-ui Transit API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"], 
)

CONFIG_PATH = os.path.join(os.path.dirname(__file__), 'panel_3xui', 'config.json')

# Конфигурация портов
BRIDGE_PORT = int(os.environ.get("BRIDGE_PORT", 8000)) 
EXTERNAL_PORT = os.environ.get("EXTERNAL_PORT", "8888") # По умолчанию 8888, если не задано

@app.on_event("startup")
def _auto_detect_bridge_url():
    try:
        if not os.path.exists(CONFIG_PATH):
            return
            
        with open(CONFIG_PATH, 'r') as f:
            conf = json.load(f)
        
        target_host = conf.get("host_current_server", "")
        if target_host:
            parsed = urlparse(target_host)
            # Принудительно используем EXTERNAL_PORT для публичных ссылок
            final_port = EXTERNAL_PORT
            
            port_suffix = f":{final_port}" if final_port not in ["80", "443"] else ""
            # Собираем URL: https://domain.com:8888
            url = f"{parsed.scheme}://{parsed.hostname}{port_suffix}"
            
            conf["bridge_public_url"] = url
            with open(CONFIG_PATH, 'w') as f:
                json.dump(conf, f, indent=2)
            print(f"✅ bridge_public_url set to: {url}")
    except Exception as e:
        print(f"⚠️ Error auto-setting bridge URL: {e}")
        
def get_xui():
    try:
        # Передаем имя файла, XUIClient сам найдет путь
        return XUIClient('config.json')
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- Models ---
class InboundCreate(BaseModel):
    remark_suffix: str
    port: int
    target: Optional[str] = None
    sni: Optional[str] = None

class InboundUpdate(BaseModel):
    remark_suffix: Optional[str] = None
    port: Optional[int] = None
    target: Optional[str] = None
    sni: Optional[str] = None

class ClientAdd(BaseModel):
    email: str
    limit_ip: Optional[int] = 0
    sub_name: Optional[str] = None

class ClientUpdate(BaseModel):
    new_email: Optional[str] = None
    limit_ip: Optional[int] = None
    total_gb: Optional[int] = None
    expiry_time: Optional[int] = None
    enable: Optional[bool] = None
    sub_name: Optional[str] = None

class AuthRequest(BaseModel):
    admin: str
    password: str
    host: str
    ip_cascad: str
    port_cascad: int

class SubscriptionConfig(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    support_url: Optional[str] = None
    update_interval_sec: Optional[int] = None

# --- Endpoints ---

@app.get("/inbounds")
def list_inbounds():
    xui = get_xui()
    res = xui.get_inbounds()
    if not res.get("success"):
        raise HTTPException(status_code=400, detail=res.get("msg", "Error fetching inbounds"))
    for ib in res['obj']:
        ib['clients'] = xui.get_clients_inbound(ib['id'])
    return res

@app.post("/inbounds")
def create_inbound(data: InboundCreate):
    xui = get_xui()
    res = xui.add_inbound(data.remark_suffix, data.port, data.target, data.sni)
    return res

@app.put("/inbounds/{inbound_id}")
def update_inbound(inbound_id: int, data: InboundUpdate):
    xui = get_xui()
    res = xui.update_inbound(inbound_id, data.remark_suffix, data.port, data.target, data.sni)
    return res

@app.delete("/inbounds/{inbound_id}")
def delete_inbound(inbound_id: int):
    xui = get_xui()
    return xui.del_inbound(inbound_id)

@app.post("/inbounds/{inbound_id}/clients")
def add_client(inbound_id: int, data: ClientAdd):
    xui = get_xui()
    return xui.add_client(inbound_id, data.email, data.limit_ip, data.sub_name)

@app.delete("/inbounds/{inbound_id}/clients/{email}")
def delete_client(inbound_id: int, email: str):
    xui = get_xui()
    return xui.del_client(inbound_id, email)

@app.put("/inbounds/{inbound_id}/clients/{email}")
def update_client(inbound_id: int, email: str, data: ClientUpdate):
    xui = get_xui()
    return xui.update_client(
        inbound_id, email, 
        data.new_email, data.limit_ip, data.total_gb, data.expiry_time, data.enable,
        data.sub_name
    )

@app.get("/config")
def get_config():
    with open(CONFIG_PATH, 'r') as f:
        return json.load(f)

@app.patch("/config/subscription")
def update_subscription_config(data: SubscriptionConfig):
    with open(CONFIG_PATH, 'r') as f:
        conf = json.load(f)
    sub = conf.setdefault("subscription", {})
    if data.title is not None: sub["title"] = data.title
    if data.description is not None: sub["description"] = data.description
    if data.support_url is not None: sub["support_url"] = data.support_url
    if data.update_interval_sec is not None: sub["update_interval_sec"] = data.update_interval_sec
    with open(CONFIG_PATH, 'w') as f:
        json.dump(conf, f, indent=2)
    return {"success": True, "subscription": sub}

@app.post("/auth")
def auth_and_save(data: AuthRequest):
    with open(CONFIG_PATH, 'r') as f:
        conf = json.load(f)
    conf['3xui_admin'] = data.admin
    conf['3xui_password'] = data.password
    conf['host_current_server'] = data.host
    conf['ip_cascad_server'] = data.ip_cascad
    conf['port_cascad_server'] = data.port_cascad
    with open(CONFIG_PATH, 'w') as f:
        json.dump(conf, f, indent=2)
    try:
        XUIClient('config.json')
        _auto_detect_bridge_url() # Сразу обновляем bridge_public_url после авторизации
        return {"success": True, "msg": "Authenticated and config updated"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Authentication failed: {str(e)}")

@app.get("/sub-link/{client_id}")
def get_subscription_link(client_id: str):
    with open(CONFIG_PATH, 'r') as f:
        conf = json.load(f)
    base = conf.get("bridge_public_url", "").rstrip("/")
    if not base:
        # Если в конфиге пусто, пробуем собрать на лету
        return {"subscription_url": f"https://{urlparse(conf['host_current_server']).hostname}:{EXTERNAL_PORT}/sub/{client_id}"}
    return {"subscription_url": f"{base}/sub/{client_id}"}
@app.get("/sub/{client_id}")
def get_subscription(client_id: str):
    """
    Эндпоинт подписки для VPN-клиентов (Happ, Hiddify, Shadowrocket и т.д.).
    Исправлено: безопасная кодировка заголовков и инфо-ссылка для описания.
    """
    xui = get_xui()
    data = xui.get_subscription_data(client_id)
    if data is None:
        raise HTTPException(status_code=404, detail=f"Client not found")

    links = data["links"]
    meta = data["meta"]

    try:
        with open(CONFIG_PATH, 'r') as f:
            conf = json.load(f)
    except Exception:
        conf = {}
        
    sub_conf = conf.get("subscription", {})

    # 1. Формируем тело подписки
    title_raw = sub_conf.get("title", "VPN Premium")
    description = sub_conf.get("description", "")
    
    output_lines = []
    
    # Трюк для Happ: Добавляем описание как "пустую" VLESS ссылку.
    # Она появится в списке как текстовая строка с иконкой инфо.
    if description:
        # Кодируем только текст после #, чтобы не сломать формат ссылки
        safe_desc = urllib.parse.quote(f"ℹ️ {description}")
        info_link = f"vless://info@127.0.0.1:0?type=tcp&security=none#{safe_desc}"
        output_lines.append(info_link)
    
    # Добавляем основные рабочие ссылки
    output_lines.extend(links)
    
    # Кодируем весь список в Base64 (стандарт для подписок)
    content_str = "\n".join(output_lines)
    content_b64 = base64.b64encode(content_str.encode("utf-8")).decode("utf-8")

    # 2. Подготовка безопасных заголовков (избегаем UnicodeEncodeError)
    update_interval = str(sub_conf.get("update_interval_sec", 3600))
    
    # Кодируем заголовок профиля в Base64. 
    # Большинство клиентов декодируют это обратно в текст с эмодзи.
    encoded_title = base64.b64encode(title_raw.encode('utf-8')).decode('utf-8')
    
    # Данные о трафике (Userinfo)
    sub_userinfo = (
        f"upload={meta['upload']}; "
        f"download={meta['download']}; "
        f"total={meta['total']}; "
        f"expire={meta['expire']}"
    )

    # Собираем заголовки
    headers = {
        # Префикс 'base64:' подсказывает приложению, как расшифровать заголовок
        "Profile-Title": f"base64:{encoded_title}", 
        "Subscription-Userinfo": sub_userinfo,
        "Profile-Update-Interval": update_interval,
    }
    
    # Запасной вариант для отображения имени (через стандарт передачи имен файлов)
    safe_filename = urllib.parse.quote(title_raw)
    headers["Content-Disposition"] = f"attachment; filename*=UTF-8''{safe_filename}"

    if sub_conf.get("support_url"):
        headers["Profile-Web-Page"] = sub_conf.get("support_url")

    return Response(
        content=content_b64, 
        headers=headers, 
        media_type="text/plain; charset=utf-8"
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

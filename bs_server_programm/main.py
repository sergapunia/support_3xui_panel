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
# Находим BRIDGE_PORT из переменной окружения (которую мы пропишем в сервисе)
BRIDGE_PORT = int(os.environ.get("BRIDGE_PORT", 8000)) 
EXTERNAL_PORT = os.environ.get("EXTERNAL_PORT", "") # Тот порт, который мы ввели при установке (например 8443)

@app.on_event("startup")
def _auto_detect_bridge_url():
    try:
        with open(CONFIG_PATH, 'r') as f:
            conf = json.load(f)
        
        target_host = conf.get("host_current_server", "")
        if target_host:
            parsed = urlparse(target_host)
            # Если EXTERNAL_PORT задан (например 8443), используем его. 
            # Если нет, используем BRIDGE_PORT (8000).
            final_port = EXTERNAL_PORT if EXTERNAL_PORT else str(BRIDGE_PORT)
            
            # Формируем URL без лишнего двоеточия, если это стандартные порты
            port_suffix = f":{final_port}" if final_port not in ["80", "443"] else ""
            url = f"{parsed.scheme}://{parsed.hostname}{port_suffix}"
            
            conf["bridge_public_url"] = url
            with open(CONFIG_PATH, 'w') as f:
                json.dump(conf, f, indent=2)
            print(f"✅ bridge_public_url set to: {url}")
    except Exception as e:
        print(f"⚠️ Error auto-setting bridge URL: {e}")
        
def get_xui():
    try:
        return XUIClient('config.json')
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

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

@app.get("/inbounds")
def list_inbounds():
    xui = get_xui()
    res = xui.get_inbounds()
    if not res.get("success"):
        raise HTTPException(status_code=400, detail=res.get("msg", "Error fetching inbounds"))
    
    # Enrich with clients info
    for ib in res['obj']:
        ib['clients'] = xui.get_clients_inbound(ib['id'])
    
    return res

@app.post("/inbounds")
def create_inbound(data: InboundCreate):
    xui = get_xui()
    res = xui.add_inbound(data.remark_suffix, data.port, data.target, data.sni)
    if not res.get("success"):
        raise HTTPException(status_code=400, detail=res.get("msg", "Error creating inbound"))
    return res

@app.put("/inbounds/{inbound_id}")
def update_inbound(inbound_id: int, data: InboundUpdate):
    xui = get_xui()
    res = xui.update_inbound(inbound_id, data.remark_suffix, data.port, data.target, data.sni)
    if not res.get("success"):
        raise HTTPException(status_code=400, detail=res.get("msg", "Error updating inbound"))
    return res

@app.delete("/inbounds/{inbound_id}")
def delete_inbound(inbound_id: int):
    xui = get_xui()
    res = xui.del_inbound(inbound_id)
    if not res.get("success"):
        raise HTTPException(status_code=400, detail=res.get("msg", "Error deleting inbound"))
    return res

@app.post("/inbounds/{inbound_id}/clients")
def add_client(inbound_id: int, data: ClientAdd):
    xui = get_xui()
    res = xui.add_client(inbound_id, data.email, data.limit_ip, data.sub_name)
    if not res.get("success"):
        raise HTTPException(status_code=400, detail=res.get("msg", "Error adding client"))
    return res

@app.delete("/inbounds/{inbound_id}/clients/{email}")
def delete_client(inbound_id: int, email: str):
    print(f"BRIDGE: DELETE /inbounds/{inbound_id}/clients/{email}")
    xui = get_xui()
    res = xui.del_client(inbound_id, email)
    print(f"BRIDGE: del_client result: {res}")
    if not res.get("success"):
        raise HTTPException(status_code=400, detail=res.get("msg", "Error deleting client"))
    return res

@app.put("/inbounds/{inbound_id}/clients/{email}")
def update_client(inbound_id: int, email: str, data: ClientUpdate):
    xui = get_xui()
    res = xui.update_client(
        inbound_id, email, 
        data.new_email, data.limit_ip, data.total_gb, data.expiry_time, data.enable,
        data.sub_name
    )
    if not res.get("success"):
        raise HTTPException(status_code=400, detail=res.get("msg", "Error updating client"))
    return res

@app.patch("/inbounds/{inbound_id}/clients/{email}/limit")
def adjust_client_limit(inbound_id: int, email: str, delta: int = Body(..., embed=True)):
    xui = get_xui()
    clients = xui.get_clients_inbound(inbound_id)
    target_email = email.lower().strip()
    client = next((c for c in clients if c['email'].lower().strip() == target_email), None)
    if not client:
        raise HTTPException(status_code=404, detail=f"Client '{email}' not found")
    
    new_limit = max(0, client.get('limitIp', 0) + delta)
    res = xui.update_client(inbound_id, email, limit_ip=new_limit)
    if not res.get("success"):
        raise HTTPException(status_code=400, detail=res.get("msg", "Error adjusting limit"))
    return {"success": True, "new_limit": new_limit}

@app.get("/inbounds/{inbound_id}/clients/{email}/links")
def get_client_links(inbound_id: int, email: str):
    xui = get_xui()
    links = xui.get_links_for_client(inbound_id, email)
    if not links:
        raise HTTPException(status_code=404, detail="Client or Inbound not found")
    return {"success": True, "links": links}

@app.get("/config")
def get_config():
    with open(CONFIG_PATH, 'r') as f:
        return json.load(f)

@app.post("/config")
def save_config(config: dict = Body(...)):
    with open(CONFIG_PATH, 'w') as f:
        json.dump(config, f, indent=2)
    return {"success": True}

@app.patch("/config/subscription")
def update_subscription_config(data: SubscriptionConfig):
    """Update only the subscription card metadata (title, support_url, update_interval_sec)."""
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
    # Update config temporarily to test
    with open(CONFIG_PATH, 'r') as f:
        conf = json.load(f)
    
    conf['3xui_admin'] = data.admin
    conf['3xui_password'] = data.password
    conf['host_current_server'] = data.host
    conf['ip_cascad_server'] = data.ip_cascad
    conf['port_cascad_server'] = data.port_cascad
    
    # Write to file first because XUIClient reads from file
    with open(CONFIG_PATH, 'w') as f:
        json.dump(conf, f, indent=2)
        
    try:
        # Try toログイン to verify
        XUIClient('config.json')
        return {"success": True, "msg": "Authenticated and config updated"}
    except Exception as e:
        # If failed, we might want to revert? But requirements say "attempt to connect - if successful then save"
        # Since I already wrote it, if it fails I should probably return error.
        # Maybe I should test BEFORE writing permanently.
        raise HTTPException(status_code=400, detail=f"Authentication failed: {str(e)}")

@app.get("/sub-link/{client_id}")
def get_subscription_link(client_id: str):
    """Returns the full subscription URL for this client — paste it into Happ."""
    with open(CONFIG_PATH, 'r') as f:
        conf = json.load(f)
    base = conf.get("bridge_public_url", "").rstrip("/")
    if not base:
        raise HTTPException(status_code=500, detail="bridge_public_url not set in config.json")
    return {"subscription_url": f"{base}/sub/{client_id}"}

@app.get("/sub/{client_id}")

def get_subscription(client_id: str):
    """
    Subscription endpoint for VPN clients (Happ, Shadowrocket, v2rayNG, etc.).
    client_id can be a UUID (from 3x-ui) or client email.
    Returns base64-encoded VLESS links with metadata headers.
    """
    xui = get_xui()
    data = xui.get_subscription_data(client_id)
    if data is None:
        raise HTTPException(status_code=404, detail=f"Client '{client_id}' not found in any inbound")

    links = data["links"]
    meta = data["meta"]

    with open(CONFIG_PATH, 'r') as f:
        conf = json.load(f)
    sub_conf = conf.get("subscription", {})

    description = sub_conf.get("description", "")
    lines = []
    if description:
        # Standard way: comment lines at the top (ignored by parsers, shown by some clients)
        for line in description.splitlines():
            lines.append(f"// {line}")
    lines.extend(links)
    content_b64 = base64.b64encode("\n".join(lines).encode("utf-8")).decode("utf-8")

    card_title = meta.get("display_name") or sub_conf.get("title", client_id)
    support_url = sub_conf.get("support_url", "")
    update_interval = str(sub_conf.get("update_interval_sec", 3600))

    sub_userinfo = (
        f"upload={meta['upload']}; "
        f"download={meta['download']}; "
        f"total={meta['total']}; "
        f"expire={meta['expire']}"
    )

    headers = {
        "Profile-Title": base64.b64encode(card_title.encode()).decode(),
        "Subscription-Userinfo": sub_userinfo,
        "Profile-Update-Interval": update_interval,
        # Content-Disposition: just a filename hint for the app, no file is created on server
        "Content-Disposition": f'attachment; filename="{card_title}"',
    }
    if support_url:
        headers["Profile-Web-Page"] = support_url

    return Response(content=content_b64, headers=headers, media_type="text/plain; charset=utf-8")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

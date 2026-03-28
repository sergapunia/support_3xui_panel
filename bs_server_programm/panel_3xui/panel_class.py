import os
import requests
import json
import uuid
import base64
import secrets
import urllib.parse
from cryptography.hazmat.primitives.asymmetric import x25519

class XUIClient:
    def __init__(self, config_name):
        base_path = os.path.dirname(os.path.abspath(__file__))
        config_path = os.path.join(base_path, config_name)
        
        if not os.path.exists(config_path):
            raise FileNotFoundError(f"❌ Configuration not found: {config_path}")
            
        with open(config_path, 'r') as f:
            self.config = json.load(f)
            
        self.base_url = self.config['host_current_server'].strip('/')
        self.session = requests.Session()
        self.login(self.config['3xui_admin'], self.config['3xui_password'])

    def _generate_reality_keys(self):
        private_key = x25519.X25519PrivateKey.generate()
        public_key = private_key.public_key()
        def b64_fix(b):
            return base64.urlsafe_b64encode(b).decode().replace('=', '')
        return b64_fix(private_key.private_bytes_raw()), b64_fix(public_key.public_bytes_raw())

    def login(self, username, password):
        login_url = f"{self.base_url}/login"
        try:
            resp = self.session.post(login_url, data={"username": username, "password": password}, timeout=10)
            if not resp.json().get("success"):
                raise Exception("Login failed")
        except Exception as e:
            raise Exception(f"Connection to 3x-ui failed: {e}")

    def _safe_post(self, url, data=None):
        resp = self.session.post(url, data=data)
        try: return resp.json()
        except: return {"success": resp.status_code == 200, "msg": resp.text}

    def _safe_get(self, url):
        resp = self.session.get(url)
        try: return resp.json()
        except: return {"success": resp.status_code == 200, "obj": resp.text}

    def get_inbounds(self):
        return self._safe_get(f"{self.base_url}/panel/api/inbounds/list")

    def get_inbound_by_id(self, inbound_id):
        return self._safe_get(f"{self.base_url}/panel/api/inbounds/get/{inbound_id}")

    def get_clients_inbound(self, inbound_id):
        res = self.get_inbound_by_id(inbound_id)
        if res.get("success") and res.get("obj"):
            settings = json.loads(res['obj']['settings'])
            return settings.get('clients', [])
        return []

    def add_inbound(self, remark_suffix, port, target=None, sni=None):
        url = f"{self.base_url}/panel/api/inbounds/add"
        priv, pub = self._generate_reality_keys()
        base = self.config['base_inbound']
        
        reality_settings = {
            "show": False, "xver": base['xver'],
            "target": target or self.config['default_target'],
            "serverNames": [sni] if sni else [self.config['default_sni']],
            "privateKey": priv, "minClientVer": "", "maxClientVer": "", "maxTimediff": base['maxTimediff'],
            "shortIds": [secrets.token_hex(4) for _ in range(4)],
            "settings": {"publicKey": pub, "fingerprint": base['fp'], "spiderX": base['spiderX']}
        }

        payload = {
            "up": 0, "down": 0, "total": 0,
            "remark": f"{base['remark_prefix']}_{remark_suffix}",
            "enable": True, "port": int(port), "protocol": base['protocol'],
            "settings": json.dumps({"clients": [], "decryption": base['decryption'], "encryption": base['encryption']}),
            "streamSettings": json.dumps({"network": "tcp", "security": "reality", "realitySettings": reality_settings}),
            "sniffing": json.dumps(base['sniffing'])
        }
        return self._safe_post(url, data=payload)

    def add_client(self, inbound_id, email, limit_ip=0, sub_name=None):
        url = f"{self.base_url}/panel/api/inbounds/addClient"
        client_data = {
            "clients": [{
                "id": str(uuid.uuid4()), "flow": self.config['base_inbound']['flow'],
                "email": email, "limitIp": limit_ip, "totalGB": 0, "expiryTime": 0, "enable": True,
                "tgId": sub_name or "", "subId": secrets.token_hex(8)
            }]
        }
        return self._safe_post(url, data={"id": int(inbound_id), "settings": json.dumps(client_data)})

    def del_client(self, inbound_id, email):
        # 1. Получаем текущие данные инбаунда
        res = self.get_inbound_by_id(inbound_id)
        if not res.get("success") or not res.get("obj"):
            return {"success": False, "msg": "Inbound not found"}

        obj = res['obj']
        # Распаковываем текущие настройки
        settings = json.loads(obj['settings'])
        clients = settings.get('clients', [])

        # 2. Фильтруем список: оставляем всех, кроме того, чей email совпал
        # Используем .strip() и .lower() для точности
        new_clients = [c for c in clients if c.get('email', '').lower().strip() != email.lower().strip()]

        if len(new_clients) == len(clients):
            return {"success": False, "msg": f"Client with email '{email}' not found in this inbound"}

        # 3. Подготавливаем payload для обновления инбаунда
        # Важно сохранить старые streamSettings и sniffing, чтобы ничего не сломать
        url = f"{self.base_url}/panel/api/inbounds/update/{inbound_id}"
        
        settings['clients'] = new_clients
        
        payload = {
            "remark": obj['remark'],
            "enable": obj['enable'],
            "port": obj['port'],
            "protocol": obj['protocol'],
            "settings": json.dumps(settings),
            "streamSettings": obj['streamSettings'],
            "sniffing": obj['sniffing']
        }

        print(f"🔄 Deleting client by email: {email}. Updating inbound {inbound_id}...")
        
        # Отправляем обновленный инбаунд без удаленного клиента
        return self._safe_post(url, data=payload)

    def get_subscription_data(self, client_id: str):
        inbounds_res = self.get_inbounds()
        if not inbounds_res.get("success"): return None

        all_links = []
        meta = {"upload": 0, "download": 0, "total": 0, "expire": 0}
        found = False

        for ib in inbounds_res.get("obj", []):
            settings = json.loads(ib['settings'])
            stream = json.loads(ib['streamSettings'])
            clients = settings.get('clients', [])

            for c in clients:
                if c.get('id') == client_id or c.get('email', '').lower() == client_id.lower():
                    found = True
                    # Статистика трафика
                    meta['upload'] = c.get('up', 0)
                    meta['download'] = c.get('down', 0)
                    # Лимит в байтах
                    total_gb = c.get('totalGB', 0)
                    meta['total'] = total_gb * 1024 * 1024 * 1024 if total_gb > 0 else 0
                    # Срок действия
                    exp = c.get('expiryTime', 0)
                    meta['expire'] = exp // 1000 if exp > 0 else 0

                    # Генерация ссылки
                    r_sets = stream.get('realitySettings', {})
                    pub_key = r_sets.get('settings', {}).get('publicKey', '')
                    sni = r_sets.get('serverNames', [''])[0]
                    
                    params = {
                        "type": "tcp", "security": "reality", "pbk": pub_key,
                        "fp": r_sets.get('settings', {}).get('fingerprint', 'chrome'),
                        "sni": sni, "sid": r_sets.get('shortIds', [''])[0],
                        "flow": c.get('flow', 'xtls-rprx-vision')
                    }
                    query = urllib.parse.urlencode(params)
                    name = c.get('tgId') or c.get('email') or "VPN"
                    link = f"vless://{c['id']}@{self.config['ip_cascad_server']}:{self.config['port_cascad_server']}?{query}#{urllib.parse.quote(name)}"
                    all_links.append(link)

        return {"links": all_links, "meta": meta} if found else None

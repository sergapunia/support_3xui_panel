import os  # Добавлен импорт
import requests
import json
import uuid
import base64
import secrets
import urllib.parse
from cryptography.hazmat.primitives.asymmetric import x25519

class XUIClient:
    def __init__(self, config_name):
        # Получаем абсолютный путь к папке, где лежит этот скрипт
        base_path = os.path.dirname(os.path.abspath(__file__))
        config_path = os.path.join(base_path, config_name)
        
        # Проверяем наличие файла
        if not os.path.exists(config_path):
            raise FileNotFoundError(f"❌ Файл конфигурации не найден по пути: {config_path}")
            
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
            resp = self.session.post(login_url, data={"username": username, "password": password})
            if not resp.json().get("success"):
                raise Exception("❌ Ошибка авторизации: проверьте логин/пароль")
            print("✅ Авторизация успешна")
        except Exception as e:
            raise Exception(f"❌ Не удалось подключиться к панели: {e}")

    def _safe_post(self, url, data=None):
        print(f"XUI: POST {url} | Payload: {data}")
        resp = self.session.post(url, data=data)
        print(f"XUI: Response Status: {resp.status_code}")
        try:
            res_json = resp.json()
            print(f"XUI: Response JSON: {res_json}")
            return res_json
        except:
            print(f"XUI: Response Text: {resp.text[:200]}") # Only first 200 chars
            if resp.status_code == 200:
                return {"success": True, "msg": "OK", "obj": resp.text}
            return {"success": False, "msg": f"Error {resp.status_code}: {resp.text}"}

    def _safe_get(self, url):
        print(f"XUI: GET {url}")
        resp = self.session.get(url)
        print(f"XUI: Response Status: {resp.status_code}")
        try:
            res_json = resp.json()
            # print(f"XUI: Response JSON: {res_json}") # Too noisy for get_inbounds
            return res_json
        except:
            print(f"XUI: Response Text: {resp.text[:200]}")
            if resp.status_code == 200:
                return {"success": True, "msg": "OK", "obj": resp.text}
            return {"success": False, "msg": f"Error {resp.status_code}: {resp.text}"}

    # --- Методы получения данных ---
    def get_inbounds(self):
        url = f"{self.base_url}/panel/api/inbounds/list"
        return self._safe_get(url)

    def get_inbound_by_id(self, inbound_id):
        url = f"{self.base_url}/panel/api/inbounds/get/{inbound_id}"
        return self._safe_get(url)

    def get_clients_inbound(self, inbound_id):
        res = self.get_inbound_by_id(inbound_id)
        if res.get("success"):
            settings = json.loads(res['obj']['settings'])
            clients = settings.get('clients', [])
            # Get onlines to enrich data
            onlines = self.get_onlines().get("obj", [])
            for c in clients:
                # onlines - это список email-ов (строк)
                c['online_count'] = sum(1 for email in onlines if email == c['email'])
            return clients
        return []

    def get_onlines(self):
        url = f"{self.base_url}/panel/api/inbounds/onlines"
        return self.session.post(url).json()

    # --- Методы создания ---
    def add_inbound(self, remark_suffix, port, target=None, sni=None):
        url = f"{self.base_url}/panel/api/inbounds/add"
        priv, pub = self._generate_reality_keys()
        base = self.config['base_inbound']
        
        sids = [secrets.token_hex(i) for i in [1, 6, 7, 8, 4, 5, 2, 3]]

        reality_settings = {
            "show": False,
            "xver": base['xver'],
            "target": target or self.config['default_target'],
            "serverNames": [sni] if sni else [self.config['default_sni']],
            "privateKey": priv,
            "minClientVer": "",
            "maxClientVer": "",
            "maxTimediff": base['maxTimediff'],
            "shortIds": sids,
            "mldsa65Seed": "",
            "settings": {
                "publicKey": pub,
                "fingerprint": base['fp'],
                "serverName": "",
                "spiderX": base['spiderX'],
                "mldsa65Verify": ""
            }
        }

        stream_settings = {
            "network": "tcp",
            "security": "reality",
            "externalProxy": [],
            "realitySettings": reality_settings,
            "tcpSettings": {"acceptProxyProtocol": False, "header": {"type": "none"}}
        }

        payload = {
            "up": 0, "down": 0, "total": 0,
            "remark": f"{base['remark_prefix']}_{remark_suffix}",
            "enable": True,
            "expiryTime": 0,
            "listen": "",
            "port": int(port),
            "protocol": base['protocol'],
            "settings": json.dumps({
                "clients": [], 
                "decryption": base['decryption'], 
                "encryption": base['encryption']
            }),
            "streamSettings": json.dumps(stream_settings),
            "sniffing": json.dumps(base['sniffing'])
        }

        return self._safe_post(url, data=payload)

    def update_inbound(self, inbound_id, remark_suffix=None, port=None, target=None, sni=None):
        url = f"{self.base_url}/panel/api/inbounds/update/{inbound_id}"
        res = self.get_inbound_by_id(inbound_id)
        if not res.get("success"):
            return res
        
        ib = res['obj']
        stream = json.loads(ib['streamSettings'])
        settings = json.loads(ib['settings'])
        
        if remark_suffix:
            ib['remark'] = f"{self.config['base_inbound']['remark_prefix']}_{remark_suffix}"
        if port:
            ib['port'] = int(port)
        if target:
            stream['realitySettings']['target'] = target
        if sni:
            stream['realitySettings']['serverNames'] = [sni]
            
        payload = {
            "up": ib['up'], "down": ib['down'], "total": ib['total'],
            "remark": ib['remark'],
            "enable": ib['enable'],
            "expiryTime": ib['expiryTime'],
            "listen": ib['listen'],
            "port": int(ib['port']),
            "protocol": ib['protocol'],
            "settings": json.dumps(settings),
            "streamSettings": json.dumps(stream),
            "sniffing": ib['sniffing']
        }
        return self._safe_post(url, data=payload)

    def add_client(self, inbound_id, email, limit_ip=0, sub_name=None):
        url = f"{self.base_url}/panel/api/inbounds/addClient"
        client_uuid = str(uuid.uuid4())
        base = self.config['base_inbound']
        
        client_data = {
            "clients": [{
                "id": client_uuid,
                "flow": base['flow'],
                "email": email,
                "limitIp": limit_ip, "totalGB": 0, "expiryTime": 0, "enable": True,
                "tgId": sub_name or "", "subId": secrets.token_hex(8)
            }]
        }

        payload = {"id": int(inbound_id), "settings": json.dumps(client_data)}
        return self._safe_post(url, data=payload)

    def del_inbound(self, inbound_id):
        url = f"{self.base_url}/panel/api/inbounds/del/{inbound_id}"
        return self._safe_post(url)

    def del_client(self, inbound_id, email):
        clients = self.get_clients_inbound(inbound_id)
        target_email = email.lower().strip()
        client = next((c for c in clients if c['email'].lower().strip() == target_email), None)
        
        if not client:
            return {"success": False, "msg": f"Client '{email}' not found in inbound {inbound_id}"}
        
        # Стандартный API 3x-ui требует ID инбаунта в POST или в URL
        url = f"{self.base_url}/panel/api/inbounds/delClient/{client['id']}"
        payload = {"id": int(inbound_id)}
        
        print(f"XUI: Attempting delete with {url}")
        res = self._safe_post(url, data=payload)
        
        if not res.get("success") and "404" in str(res.get("msg")):
             # Try alternative URL pattern with inbound_id inside the path
             url_alt = f"{self.base_url}/panel/api/inbounds/{inbound_id}/delClient/{client['id']}"
             print(f"XUI: 404 encountered, attempting alternative: {url_alt}")
             res = self._safe_post(url_alt, data=payload)
             
        return res

    def update_client(self, inbound_id, email, new_email=None, limit_ip=None, total_gb=None, expiry_time=None, enable=None, sub_name=None):
        clients = self.get_clients_inbound(inbound_id)
        target_email = email.lower().strip()
        client = next((c for c in clients if c['email'].lower().strip() == target_email), None)
        
        if not client:
            return {"success": False, "msg": f"Client '{email}' not found in inbound {inbound_id}"}
        
        if new_email: client['email'] = new_email
        if limit_ip is not None: client['limitIp'] = limit_ip
        if total_gb is not None: client['totalGB'] = total_gb
        if expiry_time is not None: client['expiryTime'] = expiry_time
        if enable is not None: client['enable'] = enable
        if sub_name is not None: client['tgId'] = sub_name
        if sub_name is not None: client['subId'] = sub_name # Ensure consistency

        client_data = {"clients": [client]}
        url = f"{self.base_url}/panel/api/inbounds/updateClient/{client['id']}"
        payload = {"id": int(inbound_id), "settings": json.dumps(client_data)}
        
        res = self._safe_post(url, data=payload)
        if not res.get("success") and "404" in str(res.get("msg")):
             url_alt = f"{self.base_url}/panel/api/inbounds/{inbound_id}/updateClient/{client['id']}"
             print(f"XUI: 404 encountered on update, attempting alternative: {url_alt}")
             res = self._safe_post(url_alt, data=payload)
        return res

    # --- Subscription endpoint helpers ---
    def get_subscription_data(self, client_id: str):
        """
        Finds a client by UUID (or email) across ALL inbounds and returns:
        - links: list of VLESS links ready for subscription
        - meta: dict with upload/download/total/expire for Subscription-Userinfo header
        - display_name: human-readable name for Profile-Title header
        Returns None if client not found in any inbound.
        """
        inbounds_res = self.get_inbounds()
        if not inbounds_res.get("success"):
            return None

        all_links = []
        meta = {"upload": 0, "download": 0, "total": 0, "expire": 0, "display_name": client_id}
        found = False

        for ib in inbounds_res.get("obj", []):
            ib_detail = self.get_inbound_by_id(ib['id'])
            if not ib_detail.get("success"):
                continue

            ib_obj = ib_detail['obj']
            stream = json.loads(ib_obj['streamSettings'])
            settings = json.loads(ib_obj['settings'])
            clients = settings.get('clients', [])

            r_sets = stream.get('realitySettings', {})
            pub_key = r_sets.get('settings', {}).get('publicKey', '')
            server_names = r_sets.get('serverNames', [''])
            sni = server_names[0] if server_names else ''
            fp = r_sets.get('settings', {}).get('fingerprint', 'chrome')

            for c in clients:
                # Match by UUID or email
                if c.get('id') == client_id or c.get('email', '').lower() == client_id.lower():
                    found = True
                    meta['upload'] = max(meta['upload'], ib_obj.get('up', 0))
                    meta['download'] = max(meta['download'], ib_obj.get('down', 0))
                    # totalGB in GB -> bytes; 0 means unlimited, we keep 0 for that
                    total_gb = c.get('totalGB', 0)
                    meta['total'] = total_gb * 1024 * 1024 * 1024 if total_gb > 0 else 0
                    expire_ms = c.get('expiryTime', 0)
                    meta['expire'] = expire_ms // 1000 if expire_ms and expire_ms > 0 else 0
                    display_name = c.get('tgId') or c.get('email') or client_id
                    meta['display_name'] = display_name

                    entry_ip = self.config['ip_cascad_server']
                    entry_port = self.config['port_cascad_server']

                    for sid in r_sets.get('shortIds', ['']):
                        params = {
                            "type": "tcp",
                            "security": "reality",
                            "pbk": pub_key,
                            "fp": fp,
                            "sni": sni,
                            "sid": sid,
                            "flow": c.get('flow', 'xtls-rprx-vision')
                        }
                        query = urllib.parse.urlencode(params)
                        remark = urllib.parse.quote(display_name)
                        link = f"vless://{c['id']}@{entry_ip}:{entry_port}?{query}#{remark}"
                        all_links.append(link)
                    # One client per inbound is enough; break inner loop
                    break

        if not found:
            return None

        return {"links": all_links, "meta": meta}

    # --- Методы генерации ссылок ---
    def get_links_for_client(self, inbound_id, email):
        res = self.get_inbound_by_id(inbound_id)
        if not res.get("success"):
            return []

        ib = res['obj']
        stream = json.loads(ib['streamSettings'])
        settings = json.loads(ib['settings'])
        
        r_sets = stream['realitySettings']
        pub_key = r_sets['settings']['publicKey']
        sni = r_sets['serverNames'][0]
        fp = r_sets['settings']['fingerprint']
        
        target_email = email.lower().strip()
        client = next((c for c in settings['clients'] if c['email'].lower().strip() == target_email), None)
        if not client:
            return []

        entry_ip = self.config['ip_cascad_server']
        entry_port = self.config['port_cascad_server']

        links = []
        for sid in r_sets['shortIds']:
            params = {
                "type": "tcp",
                "security": "reality",
                "pbk": pub_key,
                "fp": fp,
                "sni": sni,
                "sid": sid,
                "flow": client.get('flow', '')
            }
            query = urllib.parse.urlencode(params)
            
            # Если задано имя подписки (tgId), используем его. Иначе - дефолтное название.
            if client.get('tgId'):
                remark = urllib.parse.quote(client['tgId'])
            else:
                remark = urllib.parse.quote(f"{ib['remark']}-{email}-{sid[:3]}")
                
            link = f"vless://{client['id']}@{entry_ip}:{entry_port}?{query}#{remark}"
            links.append(link)
        return links

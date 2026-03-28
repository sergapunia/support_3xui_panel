All
```bash
curl -sL https://raw.githubusercontent.com/sergapunia/support_3xui_panel/main/install_all.sh | sudo bash -s -- YOUR_DOMAIN.com PORT
```

Backend
```bash
curl -sL https://raw.githubusercontent.com/sergapunia/support_3xui_panel/main/setup_backend.sh | sudo bash -s -- YOUR_DOMAIN.com PORT
```

Frontend
```bash
curl -sL https://raw.githubusercontent.com/sergapunia/support_3xui_panel/main/setup_frontend.sh | sudo bash -s -- YOUR_DOMAIN.com PORT
```
Cleanup
```bash
curl -sL https://raw.githubusercontent.com/sergapunia/support_3xui_panel/main/cleanup.sh | sudo bash
```

Back logs
```
journalctl -u bs_backend -f
```

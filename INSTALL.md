# Installation

Setup TacticalTickets on a developer machine using the interactive installers, or follow the manual steps below.

**Warnings**

- **LAN sharing** is for trusted local networks only. Do not expose the Django **development** server to the public internet.
- **Production** should use a real web server, HTTPS, and a reverse proxy — not `runserver` + Vite dev.
- After changing ports or hosts in `.env`, **restart** both backend and frontend.

---

## Quick install (recommended)

### Ubuntu / Debian / WSL

```bash
cd TacticalTickets
chmod +x install/ubuntu_install.sh scripts/run_backend.sh scripts/run_frontend.sh
./install/ubuntu_install.sh
```

### Windows (PowerShell)

```powershell
cd TacticalTickets
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install\windows_install.ps1
```

The installer will:

1. Check **Python 3.12+** and **Node.js / npm**
2. Ask for **backend port** (default `8000`) and **frontend port** (default `5173`)
3. Ask **local-only** vs **LAN sharing**
4. Create `Backend/venv`, install `requirements.txt` and `npm install`
5. Write repo-root **`.env`**
6. Run **`migrate`**
7. Optionally **`collectstatic`**
8. Create dev user via **`ensure_dev_admin`** (`admin` / `admin`, change on first SPA login)
9. Print **firewall** hints (ufw / Windows Firewall — only applied if you confirm)

---

## Host sharing modes

| Mode | Prompt choice | `BACKEND_HOST` / `FRONTEND_HOST` | Who can connect |
|------|---------------|----------------------------------|-----------------|
| **Local only** | `[1]` | `127.0.0.1` | This computer only |
| **LAN shared** | `[2]` | `0.0.0.0` | Other devices on the same LAN |

### Local only

- UI: `http://127.0.0.1:<FRONTEND_PORT>/` or `http://localhost:<FRONTEND_PORT>/`
- API: `http://127.0.0.1:<BACKEND_PORT>/api/`
- `.env`: leave `VITE_API_BASE_URL` **empty** (Vite proxies `/api/` to the backend)

### LAN shared

On the **server computer**, set repo-root `.env` (installer does this when you choose LAN sharing):

```env
BACKEND_HOST=0.0.0.0
BACKEND_PORT=8000
FRONTEND_HOST=0.0.0.0
FRONTEND_PORT=5174
LAN_IP=192.168.1.55
FRONTEND_LAN_URL=http://192.168.1.55:5174
ALLOWED_HOSTS_USE_WILDCARD=1
VITE_API_BASE_URL=http://192.168.1.55:8000/api/
```

Replace `192.168.1.55` with your machine’s LAN IPv4.

**Start servers** (reads `.env` automatically):

```bash
# Terminal 1 — backend binds 0.0.0.0:<BACKEND_PORT>
./scripts/run_backend.sh
# equivalent: python manage.py runserver 0.0.0.0:8000

# Terminal 2 — frontend binds 0.0.0.0:<FRONTEND_PORT>
./scripts/run_frontend.sh
# equivalent: npm run dev -- --host 0.0.0.0 --port 5174
```

Windows:

```powershell
.\scripts\run_backend.ps1
.\scripts\run_frontend.ps1
```

**On another computer** (same LAN), open:

`http://192.168.1.55:5174`

The SPA calls `VITE_API_BASE_URL` (`http://192.168.1.55:8000/api/`) so API traffic hits the server’s LAN IP, not `localhost` on the client device.

**Django `ALLOWED_HOSTS`**

- LAN dev default: `["*"]` when `BACKEND_HOST=0.0.0.0` and `ALLOWED_HOSTS_USE_WILDCARD=1` (trusted local networks only).
- More secure: set `ALLOWED_HOSTS_USE_WILDCARD=0` and keep `LAN_IP` set; Django allows only:

```python
ALLOWED_HOSTS = [
    "localhost",
    "127.0.0.1",
    "192.168.1.55",  # replace with your server LAN IP
]
```

**CORS / CSRF** (at backend startup): `http://localhost:<FRONTEND_PORT>`, `http://127.0.0.1:<FRONTEND_PORT>`, `http://<LAN_IP>:<FRONTEND_PORT>`, plus `FRONTEND_LAN_URL` and `CORS_EXTRA_ORIGINS`.

**Firewall (Windows)** — run PowerShell **as Administrator** (adjust ports to match `.env`):

```powershell
New-NetFirewallRule -DisplayName "Django Backend 8000" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow
New-NetFirewallRule -DisplayName "Frontend Dev 5174" -Direction Inbound -Protocol TCP -LocalPort 5174 -Action Allow
```

**Firewall (Ubuntu)** — if `ufw` is active:

```bash
sudo ufw allow 8000/tcp
sudo ufw allow 5174/tcp
```

The installer can print/run these when you confirm.

**Restart required:** changing `BACKEND_PORT`, `FRONTEND_PORT`, `ALLOWED_HOSTS`, CORS, or `VITE_API_BASE_URL` requires restarting **both** backend and frontend.

---

## Run after install

### Ubuntu

```bash
./scripts/run_backend.sh    # terminal 1
./scripts/run_frontend.sh   # terminal 2
```

### Windows

```powershell
.\scripts\run_backend.ps1    # terminal 1
.\scripts\run_frontend.ps1   # terminal 2
```

Equivalent commands (substitute values from `.env`):

- Backend: `python manage.py runserver 0.0.0.0:8000` via `Backend/run_backend.py`
- Frontend: `npm run dev -- --host 0.0.0.0 --port 5174`

---

## Change ports later

1. Edit **`TacticalTickets/.env`** (or re-run `python scripts/setup_network_ports.py`)
2. Restart **backend** and **frontend**
3. In LAN mode, update **`LAN_IP`** if your machine’s address changes

Key variables:

| Variable | Purpose |
|----------|---------|
| `BACKEND_HOST` / `BACKEND_PORT` | Django `runserver` bind |
| `FRONTEND_HOST` / `FRONTEND_PORT` | Vite dev server bind |
| `VITE_API_BASE_URL` | Browser API base (LAN IP when sharing) |
| `LAN_IP` | Server LAN IPv4 for CORS / secure `ALLOWED_HOSTS` |
| `FRONTEND_LAN_URL` | Full URL other devices use (e.g. `http://192.168.1.55:5174`) |
| `ALLOWED_HOSTS_USE_WILDCARD` | `1` = `ALLOWED_HOSTS ["*"]` in dev; `0` = host list only |
| `CORS_EXTRA_ORIGINS` | Extra origins (comma-separated) |

Ports must be **1024–65535** and **backend ≠ frontend**.

---

## Multiple installs on one computer

Use **separate clone folders** (or copies) and a **unique** `.env` per instance, e.g.:

- Instance A: `BACKEND_PORT=8000`, `FRONTEND_PORT=5173`
- Instance B: `BACKEND_PORT=8001`, `FRONTEND_PORT=5174`

Run each pair of `run_backend` / `run_frontend` scripts from its own repo directory.

---

## Access from another device (same network)

1. Install with **[2] Yes, share on local network**
2. Open firewall ports if prompted / required
3. On the other device, browse `http://<installer-displayed-LAN-IP>:<FRONTEND_PORT>/`
4. Sign in with a valid account (e.g. dev `admin` after password change)

If the UI cannot reach the API, check `.env` **`VITE_API_BASE_URL`**, **`CORS_EXTRA_ORIGINS`**, and that both servers were restarted.

---

## Manual install (without scripts)

### Prerequisites

- **Python 3.12+**
- **Node.js 20+** and **npm**

### Backend

```bash
cd Backend
python3 -m venv venv
source venv/bin/activate          # Windows: .\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Configure ports (writes `.env` at repo root):

```bash
cd ..
python scripts/setup_network_ports.py
# or: python Backend/venv/Scripts/python ../scripts/install_env.py --backend-port 8000 --frontend-port 5173 --local-only
```

```bash
cd Backend
python manage.py migrate
python manage.py ensure_dev_admin
python run_backend.py
```

### Frontend

```bash
cd Frontend
npm install
npm run dev
```

Vite reads `FRONTEND_PORT` / `FRONTEND_HOST` from repo-root `.env`.

### Superuser

- Dev default: `python manage.py ensure_dev_admin` → **admin** / **admin** (forced change in SPA)
- Custom: `python manage.py createsuperuser`

---

## Payment gateway encryption (`PAYMENTS_ENCRYPTION_KEY`)

Gateway **secret keys** and **webhook secrets** are encrypted at rest with Fernet.

| Environment | `DEBUG` | `PAYMENTS_ENCRYPTION_KEY` | Behavior |
|-------------|---------|---------------------------|----------|
| Development | `True` | optional | Warning `payments.W001`; secrets may use a **DEBUG-only** key derived from `SECRET_KEY` |
| Production | `False` | **required** | Django system check `payments.E001` blocks startup if missing |

Generate a key:

```bash
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

Add to repo-root `.env`:

```env
PAYMENTS_ENCRYPTION_KEY=your-fernet-key-here
```

Configure gateways in the app under **Settings → System → Payments → Gateways** (Stripe, Square, PayPal, etc.). Enter **public key / client ID**, **secret key**, **webhook secret**, **environment**, and **active/default** in the UI — never commit real credentials to git.

**API prefix:** `/api/payments/` (preferred). Legacy `/api/customer-payment-methods/` still works with a `Deprecation` response header.

---

## Verify

Substitute your configured ports:

1. **Backend bind:** `python run_backend.py` logs `Starting development server at http://0.0.0.0:<BACKEND_PORT>/` in LAN mode.
2. **Frontend bind:** Vite shows `Network: http://<LAN_IP>:<FRONTEND_PORT>/` when `FRONTEND_HOST=0.0.0.0`.
3. **Same PC:** `GET http://127.0.0.1:<BACKEND_PORT>/api/auth/me/` with `Authorization: Token …` after login.
4. **Another PC:** open `http://<LAN_IP>:<FRONTEND_PORT>/`, sign in; DevTools network tab should call `http://<LAN_IP>:<BACKEND_PORT>/api/…`, not `127.0.0.1`.
5. Complete **change password** if prompted for dev `admin`.

---

## Next steps

- Command reference and troubleshooting: **[MANUAL.md](MANUAL.md)**
- Unfinished features: **[UNFINISHED_FUNCTIONALITY_AUDIT.md](UNFINISHED_FUNCTIONALITY_AUDIT.md)**

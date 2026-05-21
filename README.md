<img width="635" height="562" alt="image" src="https://github.com/user-attachments/assets/c2063587-7c19-449b-a6ac-1b28a4eb96aa" />   <img width="1398" height="736" alt="image" src="https://github.com/user-attachments/assets/6e8efb58-f2be-4f89-83dd-adb197091f0b" />
<img width="1404" height="731" alt="image" src="https://github.com/user-attachments/assets/2089dfc3-722c-45af-8c0e-af39a3f8b948" />

# TacticalTickets

Repair-shop style ticketing: **Django REST Framework** API + **Vue 3** (Vite) SPA.

| Document | Purpose |
|----------|---------|
| **[INSTALL.md](INSTALL.md)** | First-time setup: Python, database, dev admin user, frontend. |
| **[MANUAL.md](MANUAL.md)** | Day-to-day reference: commands, API auth, URLs, troubleshooting. |

## Quick start (after install)

1. **Backend** — from `Backend/`: activate venv, `python run_backend.py` (port from repo `.env`, default `8000`).
2. **Frontend** — from `Frontend/`: `npm run dev` (port from repo `.env`, default `5173` or `5174` after install).
3. **Sign in** — create/reset the dev superuser with `ensure_dev_admin` (see [MANUAL.md](MANUAL.md)), then open the app and log in as `admin` / `admin`. You will be required to set a new password before using the app.

## Startup

Run commands from the **`TacticalTickets`** folder (repo root). Ports and hosts come from **`.env`** (`BACKEND_PORT`, `FRONTEND_PORT`, etc.). A browser **Connection refused** error usually means one or both servers are not running.

First-time setup: [INSTALL.md](INSTALL.md).

### Windows

Installer: `.\install\windows_install.ps1`

#### Development

Use **two** PowerShell windows (leave each running):

```powershell
cd path\to\TacticalTickets

# Terminal 1 — Django dev server (default http://127.0.0.1:8000/)
.\scripts\run_backend.ps1

# Terminal 2 — Vite dev server (default http://127.0.0.1:5173/)
.\scripts\run_frontend.ps1
```

Open the UI at the URL shown in the frontend terminal (from `FRONTEND_HOST` / `FRONTEND_PORT` in `.env`).

Equivalent manual commands:

```powershell
cd Backend
.\venv\Scripts\python.exe run_backend.py

cd ..\Frontend
npm run dev -- --host 127.0.0.1 --port 5173
```

#### Production

One script checks prerequisites, migrates, builds the SPA, then starts **Waitress** (API) and **`vite preview`** (built SPA) in separate console windows:

```powershell
cd path\to\TacticalTickets
& ".\ticketing startup.ps1"
```

Default URLs after startup:

| Service | URL |
|---------|-----|
| API (Waitress) | `http://127.0.0.1:8000/` |
| SPA (`vite preview`) | `http://127.0.0.1:5174/` |

Optional parameters:

```powershell
& ".\ticketing startup.ps1" -SkipFrontendBuild -ApiPort 8080 -WebPort 3000
```

Close each server window to stop that process. This layout is suitable for a local or LAN Windows host; harden Django (`SECRET_KEY`, `DEBUG`, `ALLOWED_HOSTS`, CORS, HTTPS) before any internet-facing deployment.

### Ubuntu / Debian / WSL

Installer:

```bash
cd path/to/TacticalTickets
chmod +x install/ubuntu_install.sh scripts/run_backend.sh scripts/run_frontend.sh
./install/ubuntu_install.sh
```

#### Development

Use **two** terminals (leave each running):

```bash
cd path/to/TacticalTickets

# Terminal 1 — Django dev server (default http://127.0.0.1:8000/)
./scripts/run_backend.sh

# Terminal 2 — Vite dev server (default http://127.0.0.1:5173/)
./scripts/run_frontend.sh
```

Open the UI at the URL shown in the frontend terminal (from `FRONTEND_HOST` / `FRONTEND_PORT` in `.env`).

Equivalent manual commands:

```bash
cd Backend
./venv/bin/python run_backend.py

cd ../Frontend
npm run dev -- --host 127.0.0.1 --port 5173
```

**LAN sharing:** use `0.0.0.0` hosts and set `VITE_API_BASE_URL` in `.env` (see [INSTALL.md](INSTALL.md)). Open firewall ports if needed:

```bash
sudo ufw allow 8000/tcp
sudo ufw allow 5174/tcp
```

#### Production

There is no single Ubuntu installer script yet; use the same layout as Windows (**Waitress** + built SPA via **`vite preview`**). Run once to prepare, then start each service in its own terminal:

```bash
cd path/to/TacticalTickets
VENV_PY=Backend/venv/bin/python

# Prepare (migrate, build SPA, install Waitress if needed)
$VENV_PY -m pip install 'waitress==3.0.2'
cd Backend && $VENV_PY manage.py migrate --noinput && $VENV_PY manage.py check
cd ../Frontend && npm ci && npm run build
```

**Terminal 1 — API (Waitress):**

```bash
cd path/to/TacticalTickets/Backend
./venv/bin/waitress-serve --listen=0.0.0.0:8000 config.wsgi:application
```

**Terminal 2 — SPA (`vite preview`):**

```bash
cd path/to/TacticalTickets/Frontend
npm run preview -- --host 0.0.0.0 --port 5174
```

Default URLs:

| Service | URL |
|---------|-----|
| API (Waitress) | `http://127.0.0.1:8000/` |
| SPA (`vite preview`) | `http://127.0.0.1:5174/` |

Optional: `manage.py collectstatic` during install or before serving behind nginx. For internet-facing hosts, use HTTPS, a reverse proxy (nginx/Caddy), and hardened env vars — not `runserver` or Vite dev. See [MANUAL.md](MANUAL.md) and [INSTALL.md](INSTALL.md).

## Layout

```
TacticalTickets/
├── Backend/          # Django project (config/, tickets app, SQLite db)
├── Frontend/         # Vue 3 + Vite SPA
├── INSTALL.md
└── MANUAL.md
```

## Production notes

Current Django settings target **local development** (DEBUG, permissive CORS, default dev credentials). Harden `SECRET_KEY`, `ALLOWED_HOSTS`, CORS, HTTPS, and authentication before any production deployment. **Windows:** `ticketing startup.ps1` automates the Waitress + `vite preview` stack (see **Startup → Windows**). **Ubuntu:** same stack via manual steps in **Startup → Ubuntu**. See [MANUAL.md](MANUAL.md) and [INSTALL.md](INSTALL.md) for payments encryption, `DEBUG=False`, and LAN details.

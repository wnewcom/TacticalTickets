# TacticalTickets — Operations manual

Reference for commands, authentication, API entry points, and common issues.

---

## Project folders

| Path | Role |
|------|------|
| `Backend/` | Django project: `manage.py`, `config/settings.py`, `tickets/` app |
| `Frontend/` | Vue 3 SPA: `npm run dev`, `src/api/api.js` (API base URL) |

---

## Backend commands (run from `Backend/` with venv activated)

### Database

```bash
python manage.py migrate
```

Creates/updates tables (SQLite by default: `Backend/db.sqlite3`).

### Create a superuser (interactive)

```bash
python manage.py createsuperuser
```

Use this if you want a custom username. For a **repeatable dev account**, use `ensure_dev_admin` instead.

### `ensure_dev_admin` — run anytime

Creates or updates the **`admin`** user:

- **Username:** `admin`  
- **Password:** `admin`  
- **Flags:** `is_staff`, `is_superuser`  
- **App behavior:** `UserProfile.must_change_password = True` so the Vue app **requires a new password** before continuing.

```bash
python manage.py ensure_dev_admin
```

**When to run it**

- First clone / new machine  
- Forgot local `admin` password  
- You want to reset the dev account to known credentials  
- After pulling changes that affect auth or profiles (if you need a clean admin state)

**Security:** Only for **local development**. Do not rely on `admin`/`admin` in production.

### Django checks

```bash
python manage.py check
```

### Run API server

```bash
python run_backend.py
```

Uses `BACKEND_HOST` and `BACKEND_PORT` from the repo-root `.env` (defaults: `127.0.0.1` and `8000`).

```bash
# From repo root (recommended)
./scripts/run_backend.sh

# Or from Backend/ with venv active
python run_backend.py
```

Equivalent:

```bash
python manage.py runserver 0.0.0.0:<BACKEND_PORT>   # LAN sharing
python manage.py runserver 127.0.0.1:<BACKEND_PORT> # local only
```

Example: `BACKEND_HOST=0.0.0.0` and `BACKEND_PORT=8000` → `http://0.0.0.0:8000/` (reachable as `http://<LAN_IP>:8000/` from other devices).

### Optional: DRF auth token via CLI

```bash
python manage.py drf_create_token <username>
```

Useful for API testing without the SPA. The SPA normally obtains a token via `POST /api/auth/token/`.

---

## Frontend commands (run from `Frontend/`)

| Command | Purpose |
|---------|---------|
| `npm install` | Install dependencies |
| `npm run dev` | Vite dev server — prefer `./scripts/run_frontend.sh` (reads `.env`) |
| `./scripts/run_frontend.sh` | `npm run dev -- --host <FRONTEND_HOST> --port <FRONTEND_PORT>` |
| `npm run build` | Type-check + production build to `dist/` |
| `npm run preview` | Preview production build locally |
| `npm run test:e2e` | Playwright (see `Frontend/e2e/README.md`) |

### API base URL

Configured in **`Frontend/src/api/apiBase.ts`** and **`Frontend/src/api/api.js`**:

- **Local only:** leave `VITE_API_BASE_URL` empty → browser uses `/api/` and Vite proxies to the backend on this PC.
- **LAN sharing:** set `VITE_API_BASE_URL=http://<LAN_IP>:<BACKEND_PORT>/api/` so phones/other PCs call the server IP (not `127.0.0.1`).
- **Local override:** `VITE_API_BASE_URL=http://127.0.0.1:<BACKEND_PORT>/api/`

`apiBase.ts` avoids using loopback when the UI is opened from another host (e.g. `http://192.168.x.x:5174`).

Ports are read from `.env`; defaults are `BACKEND_PORT=8000` and `FRONTEND_PORT=5173` (installer may use `5174`).

### Auth token storage

- Key: `tacticalTicketsAuthToken` in `localStorage` (see `Frontend/src/lib/authToken.js`).
- Sign out clears the token (`MainLayout`).

---

## Authentication flow (SPA)

1. **Login** — `POST /api/auth/token/` with JSON `username`, `password` → returns `token`.
2. **Session** — Subsequent requests send `Authorization: Token <token>`.
3. **Who am I** — `GET /api/auth/me/` returns `username`, `must_change_password`.
4. **Forced password change** — If `must_change_password` is true, the router sends the user to **`/change-password`** until they submit **`POST /api/auth/change-password/`** with `current_password` and `new_password` (min 8 characters, must differ from current).
5. **Logout** — Remove token locally; user returns to `/login`.

---

## HTTP API reference (base: `/api/`)

All ticket/customer/device endpoints expect **`Authorization: Token …`** unless you change permissions.

| Method | Path | Notes |
|--------|------|--------|
| POST | `/api/auth/token/` | Login; body: `username`, `password` |
| GET | `/api/auth/me/` | Current user + `must_change_password` |
| POST | `/api/auth/change-password/` | Body: `current_password`, `new_password` |
| GET | `/api/tickets/` | Query filters: `search`, `status`, `assigned_to`, `management_type`, `priority`, `issue_category`, `customer`, `device`, `created_from`, `created_to`, `due_from`, `due_to`, `ordering`, … |
| GET | `/api/tickets/options/` | Dropdown data: statuses, priorities, technicians, customers, devices, … |
| GET | `/api/tickets/dashboard/` | Aggregated stats (not filtered like the list) |
| CRUD | `/api/customers/`, `/api/devices/`, … | See router `Backend/tickets/urls.py` |

Django admin (separate from DRF): `http://<BACKEND_HOST>:<BACKEND_PORT>/admin/` (defaults: `127.0.0.1:8000`).

---

## Network ports and CORS

### Configuration sources

| Environment | How ports are set |
|-------------|-------------------|
| **Local dev** | Repo-root `TacticalTickets/.env`, or `python scripts/setup_network_ports.py`, or **Settings → System → Network / Ports** (writes `.env` when `DEBUG=True`) |
| **Production** | Host/server environment variables, Docker, systemd, reverse proxy, or platform settings — **not** the Network settings UI |

Variables:

| Variable | Purpose | Default (if unset) |
|----------|---------|-------------------|
| `BACKEND_HOST` | Django bind / API host | `127.0.0.1` |
| `BACKEND_PORT` | Django port | `8000` |
| `FRONTEND_HOST` | Vite bind (browser may use `localhost`) | `127.0.0.1` |
| `FRONTEND_PORT` | Vite dev/preview port | `5173` |
| `FRONTEND_BASE_URL` | OAuth redirects, emails | derived from frontend host/port |
| `VITE_API_BASE_URL` | Optional explicit API URL for frontend build | derived from backend host/port |
| `FRONTEND_LAN_URL` | URL for LAN browsers | `http://<LAN_IP>:<FRONTEND_PORT>` |
| `LAN_IP` | Server LAN IPv4 | installer-detected |
| `ALLOWED_HOSTS_USE_WILDCARD` | `1` = `["*"]` in dev LAN mode | `auto` |
| `CORS_EXTRA_ORIGINS` | Extra comma-separated origins | none |
| `VITE_API_BASE_URL` | Browser API base (required for LAN clients) | empty = Vite proxy |

### CORS / CSRF

At **Django startup**, `Backend/config/settings.py` builds:

- `CORS_ALLOWED_ORIGINS`: `http://localhost:<FRONTEND_PORT>`, `http://127.0.0.1:<FRONTEND_PORT>`, `http://<LAN_IP>:<FRONTEND_PORT>`, `FRONTEND_LAN_URL`, and `CORS_EXTRA_ORIGINS`
- `CSRF_TRUSTED_ORIGINS` matches CORS

### ALLOWED_HOSTS (development)

- **LAN default:** `ALLOWED_HOSTS = ["*"]` when `BACKEND_HOST=0.0.0.0` and `ALLOWED_HOSTS_USE_WILDCARD=1` (trusted local dev only).
- **Stricter:** `ALLOWED_HOSTS_USE_WILDCARD=0` with `LAN_IP=192.168.1.55` → only `localhost`, `127.0.0.1`, and that IP.

**Changing ports, ALLOWED_HOSTS, CORS, or `VITE_API_BASE_URL` requires restarting backend and frontend.**

### Running multiple local instances

Use a separate clone or `.env` per instance so ports do not collide.

**Instance A (defaults):**

```env
BACKEND_PORT=8000
FRONTEND_PORT=5173
```

**Instance B:**

```env
BACKEND_PORT=8010
FRONTEND_PORT=5180
```

Start each backend with `python run_backend.py` and each frontend with `npm run dev` in its tree. Playwright: `FRONTEND_PORT=5180 npm run test:e2e` (see `Frontend/e2e/README.md`).

### Production note

In production, set ports through host environment variables, process manager, Docker, reverse proxy, or deployment platform settings. The **Network / Ports** settings page is intended for local development and is read-only when `DEBUG=False`.

### API

| Method | Path |
|--------|------|
| GET | `/api/system/network-settings/` |
| PATCH | `/api/system/network-settings/` (local dev only) |
| POST | `/api/system/network-settings/reset/` (local dev only) |

---

## Troubleshooting

### `403` / “Authentication credentials were not provided”

- You are calling the API **without** a token. Sign in through the SPA or send `Authorization: Token <key>`.
- Token may be invalid/expired logic-wise: sign out and sign in again.

### Vite error: cannot load `authToken.js`

- Ensure **`Frontend/src/lib/authToken.js`** exists (or adjust imports). Extension resolution is customized in `vite.config.ts`.

### `python` / `pip` not found

- Use the venv interpreter: `Backend/venv/Scripts/python.exe` (Windows) or `Backend/venv/bin/python`.

### Wrong API port / CORS blocked after port change

- Restart **backend** after changing `BACKEND_PORT` or `FRONTEND_PORT` (CORS is applied at startup only).
- Restart **frontend** (`npm run dev`) so Vite picks up `FRONTEND_PORT` and proxy target.
- Confirm repo-root `.env` matches **Settings → Network / Ports**.
- In production, set env vars on the host; do not use the Network UI (`DEBUG=False`).

### Migrations out of date

```bash
python manage.py migrate
```

### Reset dev login only

```bash
python manage.py ensure_dev_admin
```

Then log in as `admin` / `admin` and complete the password-change screen.

---

## Build verification

**Backend**

```bash
python manage.py check
```

**Frontend**

```bash
npm run build
```

Runs `vue-tsc` and Vite build; both should pass before merging or releasing.

---

## Related files (for developers)

| Topic | Location |
|-------|----------|
| DRF auth views | `Backend/tickets/auth_views.py` |
| User profile flag | `Backend/tickets/models.py` (`UserProfile`) |
| Dev admin command | `Backend/tickets/management/commands/ensure_dev_admin.py` |
| URL routes | `Backend/config/urls.py`, `Backend/tickets/urls.py` |
| Vue router / guards | `Frontend/src/router/index.ts` |
| Axios + interceptors | `Frontend/src/api/api.js` |
| Network config (backend) | `Backend/config/network_config.py`, `Backend/config/env_loader.py` |
| Network API | `Backend/tickets/network_settings_views.py` |
| Run backend | `Backend/run_backend.py` |
| Port setup script | `scripts/setup_network_ports.py` |
| Playwright ports | `Frontend/playwright.config.ts`, `Frontend/scripts/playwright-env.mjs` |

---

## Payment gateway encryption (`PAYMENTS_ENCRYPTION_KEY`)

Gateway secrets (Stripe, Square, PayPal, etc.) are encrypted at rest using Fernet.

| Environment | `DEBUG` | `PAYMENTS_ENCRYPTION_KEY` | Behavior |
|-------------|---------|---------------------------|----------|
| Development | `True` | optional | May derive a dev key from `SECRET_KEY` with Django warning `payments.W001` |
| Production | `False` | **required** | Startup fails with `payments.E001` if unset; secrets must not use DEBUG-only derivation |

Generate a key:

```bash
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

Set in repo-root `.env` or environment:

```env
PAYMENTS_ENCRYPTION_KEY=your-fernet-key-here
```

Payments API prefix: **`/api/payments/`**. Legacy `GET/POST /api/customer-payment-methods/` remains available with deprecation headers; prefer `/api/payments/customer-payment-methods/` for new work.

---

## Document index

- **[README.md](README.md)** — Overview and quick start  
- **[INSTALL.md](INSTALL.md)** — First-time installation  

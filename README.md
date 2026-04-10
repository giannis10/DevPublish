```
   .d8888b.   88888888888
  d88P  Y88b      888
  888    888      888
  888             888
  888  88888      888
  888    888      888
  Y88b  d88Pd8b   888
   "Y8888P88Y8P   888
```

# DevPublish — Instant Web Stack for Developers

> **Show your project to the world in under 2 minutes.**  
> A smart installer that sets up a full PHP/MariaDB web server with a public HTTPS URL via Tailscale — no config files, no wasted time.

**Created by [G.T](https://linktr.ee/Giannis.Tsimpouris) · MIT License**

---

## 🎯 Who is this for?

- A **developer** who wants to show a client their site before it goes live
- A **freelancer** doing public beta testing with their client
- Anyone who needs a **public link** without renting a server

No domain, no reverse proxy config, no cloud account, no static IP required.

---

## ✨ Features

| | Feature | Description |
|---|---|---|
| 🌐 | **Apache + PHP 8.2** | Ready-to-use web server — drop your files and it runs |
| 🗄️ | **MariaDB + phpMyAdmin** | Full database stack out of the box |
| 🔗 | **Tailscale Funnel** | Public HTTPS URL with one command |
| 🎮 | **Web Manager UI** | Dashboard to toggle the public link, monitor status, view logs |
| 🔒 | **Brute-force Protection** | Rate limiting + encrypted sessions |
| ⚙️ | **Full Customization** | Choose your own path, ports, passwords — or just press Enter for defaults |
| 🐳 | **Auto Docker Install** | Installs Docker automatically if missing |
| 🔑 | **Auto Tailscale Setup** | Installs and authenticates Tailscale from within the script |
| 📄 | **Per-folder .htaccess** | Full Apache override support for every subfolder |

---

## ⚡ Quick Start

```bash
git clone https://github.com/giannis10/DevPublish.git
cd DevPublish
sudo bash install.sh
```

Follow the prompts (or press Enter for defaults) and in ~2 minutes you have:

```
✅ INSTALLATION COMPLETE!

📍 Path:        /DATA/AppData/devpublish
🌐 Website:     http://localhost:8090
🗄️  phpMyAdmin:  http://localhost:8081
🎮 Manager UI:  http://localhost:8099
🔗 Public URL:  https://your-machine.tailnet.ts.net
```

---

## 📋 Requirements

- **OS:** Ubuntu 20.04+ / Debian 11+ or any modern Linux distro
- **RAM:** 512MB minimum (1GB+ recommended)
- **Sudo:** Required for installation

The script automatically installs **Docker**, **Docker Compose** and **Tailscale** if they are missing.

---

## 📄 Per-folder .htaccess Support

DevPublish runs Apache with `AllowOverride All` and `mod_rewrite` enabled, which means **every subfolder inside `www/` can have its own `.htaccess` file** with its own rules.

### What you can control per folder:

| Capability | Example use case |
|---|---|
| **Password protection** | Lock a `/admin` folder behind HTTP auth |
| **URL rewrites** | Clean URLs for a PHP framework (`/about` → `index.php?page=about`) |
| **Access restrictions** | Block access to specific IPs or files |
| **Custom error pages** | Per-project 404, 403 pages |
| **Caching rules** | Set cache headers for static assets |
| **HTTPS redirects** | Force HTTPS on a per-folder basis |
| **PHP settings** | Override `upload_max_filesize`, `memory_limit` per project |
| **Directory listing** | Enable or disable folder browsing |

### Example: Password-protect a folder

```
www/
├── index.php           ← Public
├── beta/
│   ├── .htaccess       ← Restricts access to this folder
│   ├── .htpasswd       ← Hashed credentials
│   └── index.php
└── api/
    ├── .htaccess       ← Different rules for the API
    └── index.php
```

`www/beta/.htaccess`:
```apache
AuthType Basic
AuthName "Beta Access"
AuthUserFile /var/www/html/beta/.htpasswd
Require valid-user
```

Generate the `.htpasswd` file:
```bash
htpasswd -c www/beta/.htpasswd yourclient
```

### Example: Clean URLs for a PHP app

`www/myapp/.htaccess`:
```apache
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^(.*)$ index.php?route=$1 [QSA,L]
```

This lets you have URLs like `/myapp/about`, `/myapp/contact` all handled by a single `index.php`.

---

## 📂 Folder Structure

```
/your-install-path/
├── docker-compose.yml      # Definition of all Docker services
├── www/                    # ✏️  YOUR PROJECT FILES GO HERE
│   ├── index.php           # Default landing page
│   ├── project-a/
│   │   ├── .htaccess       # Rules specific to project-a
│   │   └── index.php
│   └── project-b/
│       ├── .htaccess       # Rules specific to project-b
│       └── index.php
├── mysql-data/             # Database files (persistent across restarts)
└── manager/
    ├── .env                # Passwords & secrets — DO NOT commit this!
    ├── server.js           # Manager backend (Node.js)
    ├── index.html          # Manager dashboard UI
    └── Dockerfile
```

---

## 🔗 How the Public URL Works

```
Client's browser
       │
       ▼
https://your-machine.tailnet.ts.net   ← Tailscale Funnel (public HTTPS)
       │
       ▼
 localhost:8090  ←  Apache/PHP Container  ←  ./www/
```

From the **Manager UI** you can:
- Toggle the public URL on/off at any time
- Check if the server is running
- Restart containers

---

## 🛠️ Manual Commands

```bash
cd /your-install-path

# Start / Stop / Restart
docker compose up -d
docker compose down
docker compose restart

# View logs
docker compose logs -f web-server
docker compose logs -f db

# Public URL on/off
sudo systemctl start devpublish-funnel    # Enable
sudo systemctl stop devpublish-funnel     # Disable
tailscale funnel status                   # Check URL
```

---

## 🔧 Configuration

After installation, settings are stored in `manager/.env`:

```env
WEB_PASSWORD=your_password      # Manager UI password
SESSION_SECRET=auto_generated   # Auto-generated, do not change
MONITOR_PORT=8090               # Port the manager monitors
```

To change ports after installation, edit `docker-compose.yml` and run `docker compose up -d --force-recreate`.

---

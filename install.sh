#!/bin/bash

# ============================================================
#   DevPublish — Instant Web Stack Installer
#   Created by G.T — https://linktr.ee/Giannis.Tsimpouris
#   https://github.com/giannis10/DevPublish
#   License: MIT
# ============================================================

# --- Colors & Styles ---
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
BRIGHT_GREEN='\033[1;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- Header ---
clear
echo -e "${BLUE}${BOLD}"
echo "   .d8888b.   88888888888 "
echo "  d88P  Y88b      888     "
echo "  888    888      888     "
echo "  888             888     "
echo "  888  88888      888     "
echo "  888    888      888     "
echo "  Y88b  d88Pd8b   888     "
echo '   "Y8888P88Y8P   888     '
echo -e "${NC}"
echo -e "  ${BOLD}DevPublish${NC} ${DIM}— Instant PHP/MariaDB Web Stack with Tailscale Public URL${NC}"
echo -e "  ${DIM}Created by G.T · https://linktr.ee/Giannis.Tsimpouris${NC}"
echo -e "${BLUE}  ─────────────────────────────────────────────────────────────${NC}\n"

# --- Root check ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}${BOLD}✗ Please run this script with sudo:${NC}"
    echo -e "  ${YELLOW}sudo bash install.sh${NC}\n"
    exit 1
fi

# ============================================================
#   HELPER FUNCTIONS
# ============================================================

print_step() {
    echo -e "\n${CYAN}${BOLD}▶ $1${NC}"
    echo -e "${BLUE}  ─────────────────────────────────────${NC}"
}

print_ok() {
    echo -e "  ${BRIGHT_GREEN}✓${NC} $1"
}

print_warn() {
    echo -e "  ${YELLOW}⚠${NC}  $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1"
}

# Prompt helper: shows question with default value in brackets
ask() {
    local prompt="$1"
    local default="$2"
    local varname="$3"
    echo -ne "  ${BOLD}${prompt}${NC} ${DIM}[${default}]${NC}: "
    read input
    eval "$varname=\"${input:-$default}\""
}

# ============================================================
#   CONFIGURATION PROMPTS
# ============================================================

print_step "Installation Setup"
echo -e "  ${DIM}Press Enter to use the default values shown in brackets.${NC}\n"

ask "📍 Installation Path" "/DATA/AppData/devpublish" INSTALL_PATH
ask "🌐 Web Server Port" "8090" WEB_PORT
ask "🗄️  phpMyAdmin Port" "8081" PMA_PORT
ask "🎮 Manager UI Port" "8099" MANAGER_PORT
ask "🔑 Database Root Password" "admin123" DB_PASS
ask "🔐 Manager UI Password" "admin123" ADMIN_PASS

# Show a summary before proceeding
echo -e "\n  ${DIM}────────────────────────────────────${NC}"
echo -e "  ${BOLD}Confirm Settings:${NC}"
echo -e "  📍 Path:        ${CYAN}$INSTALL_PATH${NC}"
echo -e "  🌐 Web:         ${CYAN}http://localhost:$WEB_PORT${NC}"
echo -e "  🗄️  phpMyAdmin:  ${CYAN}http://localhost:$PMA_PORT${NC}"
echo -e "  🎮 Manager:     ${CYAN}http://localhost:$MANAGER_PORT${NC}"
echo -e "  ${DIM}────────────────────────────────────${NC}"
echo -ne "\n  ${BOLD}Continue? (Enter to proceed / Ctrl+C to cancel):${NC} "
read

# ============================================================
#   DEPENDENCY CHECKS & INSTALLATION
# ============================================================

print_step "Checking Dependencies"

# --- Docker ---
if command -v docker &> /dev/null; then
    DOCKER_VER=$(docker --version | awk '{print $3}' | tr -d ',')
    print_ok "Docker found (${DOCKER_VER})"
else
    print_warn "Docker not found. Installing..."
    if ! curl -fsSL https://get.docker.com | sh; then
        print_error "Docker installation failed. Check your internet connection."
        exit 1
    fi
    systemctl enable docker --now &> /dev/null
    print_ok "Docker installed successfully"
fi

# --- Docker Compose plugin ---
if docker compose version &> /dev/null; then
    print_ok "Docker Compose plugin found"
else
    print_warn "Installing Docker Compose plugin..."
    apt-get update -qq && apt-get install -y -qq docker-compose-plugin
    print_ok "Docker Compose plugin installed"
fi

# --- curl ---
if command -v curl &> /dev/null; then
    print_ok "curl found"
else
    apt-get install -y -qq curl
    print_ok "curl installed"
fi

# --- openssl (used to generate the session secret) ---
if command -v openssl &> /dev/null; then
    print_ok "openssl found"
else
    apt-get install -y -qq openssl
    print_ok "openssl installed"
fi

# --- Tailscale ---
install_tailscale() {
    echo -e "  ${DIM}Installing Tailscale...${NC}"
    if ! curl -fsSL https://tailscale.com/install.sh | sh &> /dev/null; then
        print_error "Tailscale installation failed."
        return 1
    fi
    systemctl enable tailscaled --now &> /dev/null
    print_ok "Tailscale installed successfully"
    return 0
}

authenticate_tailscale() {
    echo ""
    echo -e "  ${YELLOW}${BOLD}⚡ Tailscale Authentication Required${NC}"
    echo -e "  ${DIM}A login URL will appear below — open it in your browser to authenticate.${NC}"
    echo -e "  ${DIM}On a headless server, copy the URL and open it on another device.${NC}\n"
    echo -ne "  ${BOLD}Press Enter to start authentication...${NC} "
    read

    # Run tailscale up in background and capture the auth URL
    tailscale up --accept-routes 2>&1 | grep -m1 "https://login.tailscale.com" &
    TS_UP_PID=$!

    echo ""
    echo -e "  ${CYAN}Waiting for authentication...${NC}"
    echo -e "  ${DIM}(If no URL appears, run manually: sudo tailscale up)${NC}\n"

    # Wait up to 120 seconds for the user to authenticate
    local timeout=120
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if tailscale status --json 2>/dev/null | grep -q '"BackendState":"Running"'; then
            print_ok "Tailscale authenticated successfully!"
            return 0
        fi
        sleep 3
        elapsed=$((elapsed + 3))
        echo -ne "  ${DIM}Waiting... (${elapsed}s / ${timeout}s)\r${NC}"
    done

    echo ""
    print_warn "Authentication timed out. You can authenticate later with: sudo tailscale up"
    return 1
}

if command -v tailscale &> /dev/null; then
    TS_VER=$(tailscale version 2>/dev/null | head -1)
    print_ok "Tailscale found (${TS_VER})"
else
    print_warn "Tailscale not found. Installing..."
    install_tailscale
fi

# Check if Tailscale is already authenticated
TS_BACKEND=$(tailscale status --json 2>/dev/null | grep -o '"BackendState":"[^"]*"' | cut -d'"' -f4)
if [ "$TS_BACKEND" = "Running" ]; then
    TS_HOSTNAME=$(tailscale status --json 2>/dev/null | grep -o '"DNSName":"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/\.$//')
    print_ok "Tailscale connected${TS_HOSTNAME:+ — ${CYAN}$TS_HOSTNAME${NC}}"
    TAILSCALE_OK=true
else
    print_warn "Tailscale is not authenticated."
    echo -ne "  ${BOLD}Authenticate now? (y/N):${NC} "
    read TS_AUTH_NOW
    if [[ "$TS_AUTH_NOW" =~ ^[Yy]$ ]]; then
        if authenticate_tailscale; then
            TAILSCALE_OK=true
            TS_HOSTNAME=$(tailscale status --json 2>/dev/null | grep -o '"DNSName":"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/\.$//')
        else
            TAILSCALE_OK=false
        fi
    else
        TAILSCALE_OK=false
        print_warn "Skipping authentication — run: sudo tailscale up"
    fi
fi

# ============================================================
#   FOLDER STRUCTURE
# ============================================================

print_step "Creating Folder Structure"

mkdir -p "$INSTALL_PATH/www"
mkdir -p "$INSTALL_PATH/mysql-data"
mkdir -p "$INSTALL_PATH/manager"
print_ok "Folders created at: ${CYAN}$INSTALL_PATH${NC}"

# Create a default index.php so the web server shows something immediately
if [ ! -f "$INSTALL_PATH/www/index.php" ]; then
    cat << 'PHPEOF' > "$INSTALL_PATH/www/index.php"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>DevPublish — Ready!</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: system-ui, sans-serif; background: #0f0f1a; color: #e0e0ff; display: flex; align-items: center; justify-content: center; min-height: 100vh; }
        .card { background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.1); border-radius: 16px; padding: 48px; text-align: center; max-width: 480px; }
        h1 { font-size: 2rem; margin-bottom: 8px; color: #7dd3fc; }
        p { color: #94a3b8; margin-bottom: 24px; }
        code { background: rgba(255,255,255,0.08); padding: 2px 8px; border-radius: 4px; font-size: 0.9em; }
        .badge { display: inline-block; background: #22c55e; color: #fff; padding: 4px 12px; border-radius: 20px; font-size: 0.8rem; margin-bottom: 16px; }
    </style>
</head>
<body>
    <div class="card">
        <div class="badge">✓ Server Online</div>
        <h1>DevPublish</h1>
        <p>Your server is running! Drop your files into the <code>www/</code> folder and refresh.</p>
        <p style="font-size:0.8rem; opacity:0.5;">PHP <?php echo PHP_VERSION; ?> · <?php echo date('d/m/Y H:i'); ?></p>
    </div>
</body>
</html>
PHPEOF
    print_ok "Default index.php created"
fi

# ============================================================
#   DOCKER COMPOSE STACK
# ============================================================

print_step "Creating Docker Compose Stack"

# The stack includes:
#   - web-server: Apache + PHP 8.2, serves files from ./www
#   - db: MariaDB 10.11, data stored in ./mysql-data (survives restarts)
#   - phpmyadmin: web UI for managing the database
#
# Per-folder .htaccess files are fully supported — Apache is configured
# with AllowOverride All, so each subfolder in ./www can have its own
# .htaccess to control access, rewrites, auth, caching, etc.
cat << EOF > "$INSTALL_PATH/docker-compose.yml"
name: devpublish

services:
  web-server:
    image: php:8.2-apache
    container_name: devpublish_web
    ports:
      - "$WEB_PORT:80"
    volumes:
      - ./www:/var/www/html
    # Enable .htaccess support for all directories
    command: >
      bash -c "
        sed -i 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf &&
        a2enmod rewrite &&
        apache2-foreground
      "
    restart: unless-stopped

  db:
    image: mariadb:10.11
    container_name: devpublish_db
    environment:
      MARIADB_ROOT_PASSWORD: $DB_PASS
    volumes:
      - ./mysql-data:/var/lib/mysql
    restart: unless-stopped

  phpmyadmin:
    image: phpmyadmin:latest
    container_name: devpublish_pma
    ports:
      - "$PMA_PORT:80"
    environment:
      PMA_HOST: db
      PMA_PORT: 3306
    depends_on:
      - db
    restart: unless-stopped
EOF

print_ok "docker-compose.yml created"
print_ok ".htaccess support enabled (AllowOverride All + mod_rewrite)"

# ============================================================
#   TAILSCALE FUNNEL SYSTEMD SERVICE
# ============================================================

print_step "Setting Up Tailscale Funnel Service"

if command -v tailscale &> /dev/null; then
    TS_PATH=$(which tailscale)

    # Create a systemd service so the funnel can be started/stopped easily
    cat << EOF > /etc/systemd/system/devpublish-funnel.service
[Unit]
Description=DevPublish — Tailscale Funnel (port $WEB_PORT)
After=network.target tailscaled.service

[Service]
Type=simple
ExecStart=$TS_PATH funnel $WEB_PORT
ExecStop=$TS_PATH funnel reset
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    print_ok "Systemd service created (devpublish-funnel.service)"

    # If Tailscale is authenticated, offer to enable the public URL right now
    if [ "$TAILSCALE_OK" = true ]; then
        echo -ne "\n  ${BOLD}Enable public URL now? (y/N):${NC} "
        read ENABLE_FUNNEL_NOW
        if [[ "$ENABLE_FUNNEL_NOW" =~ ^[Yy]$ ]]; then
            if systemctl start devpublish-funnel; then
                sleep 2
                PUBLIC_URL=$(tailscale funnel status 2>/dev/null | grep -o 'https://[^ ]*' | head -1)
                if [ -n "$PUBLIC_URL" ]; then
                    print_ok "Public URL is live: ${CYAN}$PUBLIC_URL${NC}"
                    FUNNEL_URL="$PUBLIC_URL"
                else
                    print_ok "Funnel started — URL will appear shortly"
                    FUNNEL_URL="Run: tailscale funnel status"
                fi
            else
                print_warn "Funnel failed to start. Try: sudo systemctl start devpublish-funnel"
            fi
        else
            echo -e "    ${DIM}To enable later: ${CYAN}sudo systemctl start devpublish-funnel${NC}"
        fi
    else
        echo -e "    ${DIM}Once authenticated, run: ${CYAN}sudo systemctl start devpublish-funnel${NC}"
    fi
else
    print_warn "Tailscale not found — funnel service skipped"
fi

# ============================================================
#   MANAGER CONFIGURATION
# ============================================================

print_step "Configuring Manager UI"

# Generate a random 32-byte session secret for secure cookie signing
SESSION_SECRET=$(openssl rand -hex 32)

cat << EOF > "$INSTALL_PATH/manager/.env"
# DevPublish Manager Configuration
# Generated: $(date '+%d/%m/%Y %H:%M')
# WARNING: Do not commit this file to version control

WEB_PASSWORD=$ADMIN_PASS
SESSION_SECRET=$SESSION_SECRET
MONITOR_PORT=$WEB_PORT
MANAGER_PORT=$MANAGER_PORT
INSTALL_PATH=$INSTALL_PATH
EOF

print_ok ".env created"
echo -e "    ${DIM}⚠  Do not commit manager/.env to git!${NC}"

# ============================================================
#   START CONTAINERS
# ============================================================

print_step "Starting Docker Containers"

echo -e "  ${DIM}Pulling images (this may take a moment on first run)...${NC}"
cd "$INSTALL_PATH"
if docker compose up -d; then
    print_ok "All containers started successfully"
else
    print_error "Failed to start containers. Check logs: ${CYAN}docker compose logs${NC}"
    exit 1
fi

# ============================================================
#   DONE
# ============================================================

echo -e "\n${BRIGHT_GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║           ✅  INSTALLATION COMPLETE!                 ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  📍 ${BOLD}Path:${NC}         ${CYAN}$INSTALL_PATH${NC}"
echo -e "  🌐 ${BOLD}Website:${NC}      ${CYAN}http://localhost:$WEB_PORT${NC}"
echo -e "  🗄️  ${BOLD}phpMyAdmin:${NC}   ${CYAN}http://localhost:$PMA_PORT${NC}"
echo -e "  🎮 ${BOLD}Manager UI:${NC}   ${CYAN}http://localhost:$MANAGER_PORT${NC}"
echo -e "  🔑 ${BOLD}DB Password:${NC}  ${DIM}$DB_PASS${NC}"

if [ -n "$FUNNEL_URL" ]; then
    echo ""
    echo -e "  🔗 ${BOLD}${BRIGHT_GREEN}Public URL:${NC}   ${CYAN}$FUNNEL_URL${NC}"
    echo -e "  ${DIM}  Share this link with anyone — no login required${NC}"
elif [ "$TAILSCALE_OK" = true ]; then
    echo ""
    echo -e "  ${YELLOW}▶ To enable public URL:${NC}"
    echo -e "    ${DIM}sudo systemctl start devpublish-funnel${NC}"
else
    echo ""
    echo -e "  ${YELLOW}▶ To enable public URL:${NC}"
    echo -e "    ${DIM}sudo tailscale up${NC}"
    echo -e "    ${DIM}sudo systemctl start devpublish-funnel${NC}"
fi

echo ""
echo -e "  ${YELLOW}▶ Drop your project files here:${NC}"
echo -e "    ${DIM}$INSTALL_PATH/www/${NC}"
echo -e "\n${BLUE}  ──────────────────────────────────────────────────────${NC}\n"

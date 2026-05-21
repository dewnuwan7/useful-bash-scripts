#!/bin/bash

# =============================================================================
# Odoo Setup & Docker Launcher
# =============================================================================
# Usage: ./setup_odoo.sh
# Make executable first: chmod +x setup_odoo.sh
# =============================================================================

set -e  # Exit immediately on error

# ── CONFIG ────────────────────────────────────────────────────────────────────

# Public base repo — cloned in full, contains nginx.conf, docker-compose.yaml,
# odoo.conf, and the custom_addons folder structure
BASE_REPO_URL="https://github.com/dewnuwan7/odoo19-docker.git"

# Where to clone the base repo (this becomes BASE_DIR for everything else)
INSTALL_DIR="$HOME/odoo"

# Private module repos (SSH) — cloned into custom_addons/
# Add or remove entries as needed
REPOS=(
    "git@github.com:dewnuwan7/hr_attendance_import.git"
    "git@github.com:dewnuwan7/payslip_reports.git"
    "git@github.com:dewnuwan7/payroll_attendance_integration.git"
    "git@github.com:dewnuwan7/whatsapp_documents.git"
)

# Python dependencies to install inside the running odoo container
# These mirror what you'd run as: pip install <name> --break-system-packages
PYTHON_DEPS=(
    "qifparse"

    # Add more packages here as needed
)

# Name of the Odoo service in docker-compose.yaml
ODOO_SERVICE="odoo"

# ── COLORS ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()   { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── GITHUB SSH SETUP ──────────────────────────────────────────────────────────
setup_github_ssh() {
    local KEY="$HOME/.ssh/id_ed25519"

    # Install openssh-client if ssh-keygen is missing
    if ! command -v ssh-keygen &>/dev/null; then
        log "ssh-keygen not found — installing openssh-client..."
        sudo apt-get install -y -qq openssh-client 2>/dev/null \
            || sudo yum install -y openssh 2>/dev/null \
            || error "Could not install openssh-client. Please install it manually."
    fi

    # Generate a key if none exists
    if [ ! -f "$KEY" ]; then
        log "No SSH key found. Generating a new ED25519 key..."
        ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)" -f "$KEY" -N ""
        log "SSH key generated at $KEY"
    else
        log "Existing SSH key found: $KEY"
    fi

    # Start ssh-agent and load the key
    eval "$(ssh-agent -s)" > /dev/null
    ssh-add "$KEY" 2>/dev/null

    # Add GitHub to known_hosts (avoids interactive fingerprint prompt)
    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    if ! grep -q "github.com" ~/.ssh/known_hosts 2>/dev/null; then
        log "Adding GitHub to known_hosts..."
        ssh-keyscan -H github.com >> ~/.ssh/known_hosts 2>/dev/null
    fi

    # Test GitHub connection — if it fails, show the public key and wait
    log "Testing GitHub SSH connection..."
    if ! ssh -T git@github.com -o BatchMode=yes -o ConnectTimeout=8 2>&1 | grep -q "successfully authenticated"; then
        echo ""
        echo -e "${YELLOW}┌─────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${YELLOW}│  GitHub SSH auth failed. Add this public key to your account │${NC}"
        echo -e "${YELLOW}│  → https://github.com/settings/ssh/new                      │${NC}"
        echo -e "${YELLOW}└─────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${GREEN}Your public key:${NC}"
        echo "──────────────────────────────────────────────────────────────"
        cat "${KEY}.pub"
        echo "──────────────────────────────────────────────────────────────"
        echo ""
        read -rp "Press [Enter] once you've added the key to GitHub, then we'll retry... "
        echo ""

        if ssh -T git@github.com -o BatchMode=yes -o ConnectTimeout=10 2>&1 | grep -q "successfully authenticated"; then
            log "GitHub SSH authentication successful!"
        else
            error "GitHub SSH auth still failing. Check the key was saved correctly and try again."
        fi
    else
        log "GitHub SSH authentication successful!"
    fi
}

setup_github_ssh

# ── CLONE OR UPDATE BASE REPO ─────────────────────────────────────────────────
log "Setting up base repo at: $INSTALL_DIR"

if [ -d "$INSTALL_DIR/.git" ]; then
    log "Base repo already exists — pulling latest..."
    git -C "$INSTALL_DIR" pull --rebase origin HEAD \
        && log "Base repo updated." \
        || warn "Pull failed — check for local conflicts."
else
    log "Cloning base repo..."
    git clone --depth=1 "$BASE_REPO_URL" "$INSTALL_DIR" \
        || error "Failed to clone base repo: $BASE_REPO_URL"
    log "Base repo cloned."
fi

# Everything from here on is relative to the cloned base repo
BASE_DIR="$INSTALL_DIR"
ADDONS_DIR="$BASE_DIR/custom_addons"

cd "$BASE_DIR"
log "Working directory: $(pwd)"

# ── CLONE OR PULL PRIVATE MODULE REPOS ───────────────────────────────────────
log "Setting up private modules in $ADDONS_DIR..."
mkdir -p "$ADDONS_DIR"
cd "$ADDONS_DIR"

for REPO in "${REPOS[@]}"; do
    REPO_NAME=$(basename "$REPO" .git)

    if [ -d "$REPO_NAME/.git" ]; then
        log "Updating: $REPO_NAME"
        git -C "$REPO_NAME" pull --rebase origin HEAD \
            && log "$REPO_NAME updated." \
            || warn "Pull failed for $REPO_NAME — check for conflicts."
    else
        log "Cloning: $REPO_NAME"
        git clone "$REPO" "$REPO_NAME" \
            && log "$REPO_NAME cloned." \
            || error "Failed to clone $REPO"
    fi
done

log "All custom modules ready."

# ── INSTALL DOCKER (if missing) ───────────────────────────────────────────────
install_docker() {
    log "Docker not found. Installing Docker Engine..."

    if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
        warn "Docker installation requires sudo privileges. You may be prompted for your password."
    fi

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="${ID}"
    else
        error "Cannot detect OS. Please install Docker manually: https://docs.docker.com/engine/install/"
    fi

    case "$OS_ID" in
        ubuntu|debian)
            log "Detected $OS_ID — installing via apt..."
            sudo apt-get update -qq
            sudo apt-get install -y -qq ca-certificates curl gnupg lsb-release

            sudo install -m 0755 -d /etc/apt/keyrings
            curl -fsSL "https://download.docker.com/linux/$OS_ID/gpg" \
                | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            sudo chmod a+r /etc/apt/keyrings/docker.gpg

            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
              https://download.docker.com/linux/$OS_ID \
              $(lsb_release -cs) stable" \
              | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

            sudo apt-get update -qq
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;

        centos|rhel|fedora|rocky|almalinux)
            log "Detected $OS_ID — installing via dnf/yum..."
            if command -v dnf &>/dev/null; then PKG_MGR="dnf"; else PKG_MGR="yum"; fi
            sudo $PKG_MGR install -y yum-utils
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo $PKG_MGR install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;

        *)
            error "Unsupported OS '$OS_ID'. Install Docker manually: https://docs.docker.com/engine/install/"
            ;;
    esac

    sudo systemctl enable --now docker
    log "Docker installed and enabled on boot."

    if ! groups "$USER" | grep -q docker; then
        sudo usermod -aG docker "$USER"
        warn "User '$USER' added to the 'docker' group."
        warn "Group change takes effect on next login — using 'sudo docker' for this session."
        DOCKER_CMD="sudo docker"
    fi
}

if ! command -v docker &>/dev/null; then
    install_docker
else
    log "Docker already installed: $(docker --version)"
fi

# ── LAUNCH DOCKER COMPOSE ─────────────────────────────────────────────────────
cd "$BASE_DIR"
log "Starting containers from: $(pwd)"

if docker compose version &>/dev/null 2>&1; then
    COMPOSE_CMD="${DOCKER_CMD:-docker} compose"
elif command -v docker-compose &>/dev/null; then
    COMPOSE_CMD="docker-compose"
else
    error "Docker Compose not found. Install it: https://docs.docker.com/compose/install/"
fi

log "Running: $COMPOSE_CMD up -d"
$COMPOSE_CMD up -d

# ── INSTALL PYTHON DEPS INSIDE ODOO CONTAINER ────────────────────────────────
if [ "${#PYTHON_DEPS[@]}" -gt 0 ]; then
    log "Waiting for the '$ODOO_SERVICE' container to be ready..."

    # Give the container up to 30s to start
    ATTEMPTS=0
    until $COMPOSE_CMD ps "$ODOO_SERVICE" 2>/dev/null | grep -q "running\|Up"; do
        sleep 2
        ATTEMPTS=$((ATTEMPTS + 1))
        if [ "$ATTEMPTS" -ge 15 ]; then
            warn "Timed out waiting for '$ODOO_SERVICE' container. Skipping pip installs."
            break
        fi
    done

    if [ "$ATTEMPTS" -lt 15 ]; then
        log "Installing Python dependencies inside '$ODOO_SERVICE' container..."
        for PKG in "${PYTHON_DEPS[@]}"; do
            log "  pip install $PKG --break-system-packages"
            $COMPOSE_CMD exec -T "$ODOO_SERVICE" \
                pip install "$PKG" --break-system-packages \
                && log "  ✔ $PKG" \
                || warn "  ✘ Failed to install $PKG — install it manually inside the container."
        done
        log "Python dependencies installed."

        # Restart Odoo so it picks up the new packages
        log "Restarting '$ODOO_SERVICE' to apply new packages..."
        $COMPOSE_CMD restart "$ODOO_SERVICE"
        log "  ✔ $ODOO_SERVICE restarted."
    fi
fi

echo ""
log "✅ Done! Odoo is starting up at http://localhost:8069"
log "   Follow logs with: $COMPOSE_CMD logs -f $ODOO_SERVICE"

# ── CLEANUP GIT SSH CREDENTIALS ───────────────────────────────────────────────
cleanup_ssh() {
    local KEY="$HOME/.ssh/id_ed25519"
    local KEY_PUB="${KEY}.pub"

    log "Cleaning up SSH credentials from this server..."

    # Remove the private key
    if [ -f "$KEY" ]; then
        rm -f "$KEY"
        log "  ✔ Private key removed: $KEY"
    else
        warn "  Private key not found (already removed?): $KEY"
    fi

    # Remove the public key
    if [ -f "$KEY_PUB" ]; then
        rm -f "$KEY_PUB"
        log "  ✔ Public key removed: $KEY_PUB"
    else
        warn "  Public key not found (already removed?): $KEY_PUB"
    fi

    # Remove github.com from known_hosts
    if grep -q "github.com" ~/.ssh/known_hosts 2>/dev/null; then
        ssh-keygen -R github.com 2>/dev/null
        log "  ✔ github.com removed from known_hosts"
    fi

    # Kill the ssh-agent started by this script
    if [ -n "$SSH_AGENT_PID" ]; then
        kill "$SSH_AGENT_PID" 2>/dev/null && log "  ✔ ssh-agent (PID $SSH_AGENT_PID) terminated."
    else
        # Fallback: kill any ssh-agent owned by this user
        pkill -u "$USER" ssh-agent 2>/dev/null && log "  ✔ ssh-agent process(es) terminated." \
            || warn "  No running ssh-agent found to kill."
    fi

    log "SSH cleanup complete. Git credentials removed from this server."
    warn "Don't forget to remove this server's public key from GitHub too:"
    warn "  → https://github.com/settings/keys"
}

cleanup_ssh

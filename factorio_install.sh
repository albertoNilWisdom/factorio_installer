#!/bin/bash

# Factorio Headless Server Installer & Auto-Updater with Backup & Config Generation
# For Ubuntu/Debian

set -euo pipefail

echo "= Factorio Headless Server Installer & Auto-Updater ="

FACTORIO_VERSION="stable"
FACTORIO_USER="factorio"
INSTALL_DIR="/opt/factorio"
SERVICE_NAME="factorio"
SAVE_NAME="Space_Age.zip"
BACKUP_DIR="/opt/factorio/backups"
SERVER_SETTINGS="$INSTALL_DIR/data/server-settings-boc.json"
MODS_DIR="$INSTALL_DIR/mods"

DOWNLOAD_URL="https://factorio.com/get-download/$FACTORIO_VERSION/headless/linux64"
DOWNLOAD_FILE="/tmp/factorio_headless.tar.xz"

mkdir -p "$BACKUP_DIR"

install_prereqs() {
    echo "Installing required packages..."
    sudo apt update && sudo apt install -y wget unzip screen lib32gcc-s1 jq
}

create_factorio_user() {
    if ! id "$FACTORIO_USER" &>/dev/null; then
        echo "Creating factorio user..."
        sudo useradd -r -m -d "$INSTALL_DIR" -s /bin/bash "$FACTORIO_USER"
    fi
}

download_factorio() {
    echo "Checking latest Factorio version..."
    wget -q -O /tmp/factorio_latest.json https://factorio.com/api/latest-releases
    LATEST_VERSION=$(jq -r '.stable.headless' /tmp/factorio_latest.json)
    
    if [ -f "$INSTALL_DIR/bin/x64/factorio" ]; then
        INSTALLED_VERSION=$("$INSTALL_DIR/bin/x64/factorio" --version | head -n1 | awk '{print $2}')
    else
        INSTALLED_VERSION="none"
    fi

    if [ "$INSTALLED_VERSION" == "$LATEST_VERSION" ]; then
        echo "Factorio is already at the latest version: $LATEST_VERSION"
        return
    fi

    echo "New version available: $LATEST_VERSION (Installed: $INSTALLED_VERSION)"
    echo "Backing up saves before upgrade..."
    timestamp=$(date +"%Y%m%d_%H%M%S")
    sudo -u "$FACTORIO_USER" tar czf "$BACKUP_DIR/saves_backup_$timestamp.tar.gz" -C "$INSTALL_DIR" saves

    echo "Downloading Factorio $LATEST_VERSION..."
    wget -q --show-progress -O "$DOWNLOAD_FILE" "$DOWNLOAD_URL"

    echo "Stopping Factorio service..."
    sudo systemctl stop "$SERVICE_NAME" || true

    echo "Extracting new version..."
    sudo tar -xJf "$DOWNLOAD_FILE" -C "$INSTALL_DIR" --strip-components=1
    rm "$DOWNLOAD_FILE"
    sudo chown -R "$FACTORIO_USER:$FACTORIO_USER" "$INSTALL_DIR"
}

generate_server_settings() {
    if [ ! -f "$SERVER_SETTINGS" ]; then
        echo "Generating default server-settings.json..."
        sudo -u "$FACTORIO_USER" tee "$SERVER_SETTINGS" > /dev/null <<EOF
{
    "name": "Beer O Clock",
    "description": "A headless Factorio server",
    "tags": ["game", "fun"],
    "max_players": 100,
    "visibility": {
        "public": false,
        "lan": true
    },
    "username": "",
    "password": "",
    "game_password": "99Biters-up2-the5-wazoo0",
    "require_user_verification": true,
    "max_upload_in_kilobytes_per_second": 0,
    "max_upload_slots": 5,
    "ignore_player_limit_for_returning_players": false,
    "allow_commands": "admins-only",
    "autosave_interval": 10,
    "autosave_slots": 5,
    "afk_autokick_interval": 0,
    "auto_pause": true
}
EOF
    else
        echo "server-settings.json already exists. Skipping."
    fi
}

create_save_if_missing() {
    if [ ! -f "$INSTALL_DIR/saves/$SAVE_NAME" ]; then
        echo "Creating new save..."
        sudo -u "$FACTORIO_USER" "$INSTALL_DIR/bin/x64/factorio" --create "$INSTALL_DIR/saves/$SAVE_NAME"
    else
        echo "Save file already exists. Skipping creation."
    fi
}

setup_systemd_service() {
    if [ ! -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        echo "Creating systemd service..."
        sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null <<EOF
[Unit]
Description=Factorio Headless Server
After=network.target

[Service]
User=$FACTORIO_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/bin/x64/factorio --start-server "$INSTALL_DIR/saves/$SAVE_NAME" --server-settings $SERVER_SETTINGS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl daemon-reload
        sudo systemctl enable "$SERVICE_NAME"
    else
        echo "Systemd service already exists. Skipping creation."
    fi
}

start_server() {
    echo "Starting Factorio server..."
    sudo systemctl start "$SERVICE_NAME"
}

install_mods() {
    echo "Installing example mod (creative-mode)..."
    mkdir -p "$MODS_DIR"
    cd "$MODS_DIR"
    if [ ! -f "creative-mode.zip" ]; then
        wget -q --show-progress -O creative-mode.zip https://mods.factorio.com/download/creative-mode/latest
        echo "Creative-mode mod downloaded."
    else
        echo "Creative-mode mod already present. Skipping."
    fi
}

main() {
    install_prereqs
    create_factorio_user
    download_factorio
    generate_server_settings
    create_save_if_missing
    setup_systemd_service
    install_mods
    start_server
    echo "= Factorio Server is Up-To-Date and Running ="
}

main

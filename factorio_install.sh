#!/bin/bash

# CONFIGURATION
FACTORIO_USER="factorio"
INSTALL_DIR="/opt/factorio"
BIN_DIR="$INSTALL_DIR/bin"
SAVE_DIR="$INSTALL_DIR/saves"
SERVICE_FILE="/etc/systemd/system/factorio.service"
MAP_URL="https://github.com/albertoNilWisdom/factorio-space-age-starter/raw/refs/heads/main/Space%20Age%20but%20the%20Vanilla%20Nauvis%20Part%20is%20Done.zip"  # Replace with your actual map URL



# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi


# Update system and install dependencies
echo "Updating system and installing dependencies..."
apt update && apt upgrade -y
apt install -y wget unzip curl xz-utils ufw

# Configure firewall port for factorio
ufw allow 34197/udp comment 'Allow Factorio server'

# Create factorio user if it doesn't exist
if ! id "$FACTORIO_USER" &>/dev/null; then
    echo "No factorio user found, creating it now..."
    useradd -r -m -d "$INSTALL_DIR" -s /usr/sbin/nologin "$FACTORIO_USER"
fi

# Download Factorio headless server latest stable
echo "Downloading Factorio headless server..."
LATEST_VERSION=$(curl -s https://factorio.com/api/latest-releases | jq -r '.stable.headless')
echo "Latest version: " $LATEST_VERSION
DOWNLOAD_URL="https://factorio.com/get-download/$LATEST_VERSION/headless/linux64"
TMP_ARCHIVE="/tmp/factorio_headless.tar.xz"
wget -O "$TMP_ARCHIVE" "$DOWNLOAD_URL"
echo "Download complete..."

# Extract only the bin directory
echo "Installing Factorio 'bin' directory to $BIN_DIR..."
cd /opt/
tar -xJf "$TMP_ARCHIVE"
chown -R $FACTORIO_USER:$FACTORIO_USER "$INSTALL_DIR"

# Download and install map
echo "Downloading map file..."
mkdir -p "$SAVE_DIR"
wget -O "$SAVE_DIR/map.zip" "$MAP_URL"
chown -R $FACTORIO_USER:$FACTORIO_USER "$SAVE_DIR"

chown -R factorio:factorio /opt/factorio

# Create systemd service
echo "Setting up systemd service..."
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Factorio Headless Server
After=network.target

[Service]
Type=simple
User=$FACTORIO_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$BIN_DIR/x64/factorio --start-server $SAVE_DIR/map.zip
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the server
echo "Enabling and starting Factorio server..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable factorio
systemctl start factorio

echo "Factorio headless server with 'bin' installed to $BIN_DIR is up and running."


#!/bin/bash
# Installation script for mod-system-utils
# Installs systemd services, configuration files, and web interface for MOD Audio on Ubuntu + PipeWire

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}MOD System Utils Installation${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Get the actual user (not root)
ACTUAL_USER=${SUDO_USER:-$USER}
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)

echo -e "${YELLOW}Installing for user: $ACTUAL_USER${NC}"
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v mod-host &> /dev/null; then
    echo -e "${RED}ERROR: mod-host not found${NC}"
    echo "Please install mod-host first: https://github.com/pilali/mod-host"
    exit 1
fi

if ! command -v mod-ui &> /dev/null; then
    echo -e "${RED}ERROR: mod-ui not found${NC}"
    echo "Please install mod-ui first: https://github.com/pilali/mod-ui"
    exit 1
fi

if ! command -v pw-jack &> /dev/null; then
    echo -e "${RED}ERROR: pw-jack not found${NC}"
    echo "Please install pipewire-jack: sudo apt install pipewire-jack"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites OK${NC}"
echo ""

# Create data directory
echo "Creating data directories..."
mkdir -p /var/modep/{lv2,pedalboards,user-files,data}
chown -R "$ACTUAL_USER:$ACTUAL_USER" /var/modep
echo -e "${GREEN}✓ Created /var/modep${NC}"

# Install systemd services
echo ""
echo "Installing systemd services..."

# Update service files with actual user
sed "s/User=pilal/User=$ACTUAL_USER/" systemd/mod-host.service > /tmp/mod-host.service.tmp
sed "s/Group=pilal/Group=$ACTUAL_USER/" /tmp/mod-host.service.tmp > /tmp/mod-host.service
cp /tmp/mod-host.service /etc/systemd/system/mod-host.service

sed "s/User=pilal/User=$ACTUAL_USER/" systemd/mod-ui.service > /tmp/mod-ui.service.tmp
sed "s/Group=pilal/Group=$ACTUAL_USER/" /tmp/mod-ui.service.tmp > /tmp/mod-ui.service
cp /tmp/mod-ui.service /etc/systemd/system/mod-ui.service

rm /tmp/mod-host.service* /tmp/mod-ui.service*

echo -e "${GREEN}✓ Installed mod-host.service${NC}"
echo -e "${GREEN}✓ Installed mod-ui.service${NC}"

# Install configuration files
echo ""
echo "Installing configuration files..."
cp config/mod-hardware-descriptor.json /etc/mod-hardware-descriptor.json
chmod 644 /etc/mod-hardware-descriptor.json
echo -e "${GREEN}✓ Installed /etc/mod-hardware-descriptor.json${NC}"

# Install web interface files
echo ""
echo "Installing web interface..."
mkdir -p /usr/local/share/mod/html
cp html/settings.html /usr/local/share/mod/html/settings.html
chmod 644 /usr/local/share/mod/html/settings.html
echo -e "${GREEN}✓ Installed settings.html${NC}"

# Reload systemd
echo ""
echo "Reloading systemd daemon..."
systemctl daemon-reload
echo -e "${GREEN}✓ Systemd reloaded${NC}"

# Summary
echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo "Next steps:"
echo ""
echo "1. Enable services to start at boot:"
echo -e "   ${YELLOW}sudo systemctl enable mod-host.service mod-ui.service${NC}"
echo ""
echo "2. Start the services:"
echo -e "   ${YELLOW}sudo systemctl start mod-host.service mod-ui.service${NC}"
echo ""
echo "3. Check service status:"
echo -e "   ${YELLOW}sudo systemctl status mod-host mod-ui${NC}"
echo ""
echo "4. Access the web interface:"
echo -e "   ${YELLOW}http://localhost/${NC}"
echo ""
echo "For troubleshooting, view logs with:"
echo -e "   ${YELLOW}sudo journalctl -u mod-host.service -f${NC}"
echo -e "   ${YELLOW}sudo journalctl -u mod-ui.service -f${NC}"
echo ""

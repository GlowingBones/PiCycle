#!/bin/bash

################################################################################
# PiCycle - Raspberry Pi Zero 2W USB Gadget Multi-Tool
# Transforms Pi Zero 2W into: HID Keyboard + Mass Storage + Network Device
# Compatible with: Windows, Linux, macOS
################################################################################

set -e

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[0;90m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

# Configuration paths
readonly BOOT_DIR=$([ -d "/boot/firmware" ] && echo "/boot/firmware" || echo "/boot")
readonly CONFIG_DIR="/etc/picycle"
readonly BACKUP_DIR="$CONFIG_DIR/backups"
readonly GADGET_SCRIPT="/usr/bin/picycle_gadget.sh"
readonly SERVICE_FILE="/etc/systemd/system/picycle.service"

# Check root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}ERROR: Please run as root (sudo)${NC}"
        exit 1
    fi
}

# Create banner
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║  ____  _ ____            _                                    ║
    ║ |  _ \(_) ___|   _ _ __ | | ___                               ║
    ║ | |_) | | |    | | | '_ \| |/ _ \                             ║
    ║ |  __/| | |___ | |_| | | | |  __/                             ║
    ║ |_|   |_|\____| \__, |_| |_|\___|                             ║
    ║                 |___/                                         ║
    ║                                                               ║
    ║        USB Composite Gadget Configuration Tool               ║
    ║        Raspberry Pi Zero 2W Edition v2.1                      ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Configure WiFi AP (Access Point mode with hidden SSID)
configure_wifi() {
    echo -e "\n${CYAN}${BOLD}WiFi Access Point Configuration${NC}"
    echo -e "${YELLOW}Setting up WiFi Access Point with hidden SSID 'PiCycle'${NC}\n"

    # Get password from user
    local wifi_pass=""
    while true; do
        read -sp "Enter WiFi password (8-63 characters): " wifi_pass
        echo ""
        if [ ${#wifi_pass} -lt 8 ] || [ ${#wifi_pass} -gt 63 ]; then
            echo -e "${RED}Password must be 8-63 characters${NC}"
            continue
        fi
        read -sp "Confirm password: " wifi_pass_confirm
        echo ""
        if [ "$wifi_pass" != "$wifi_pass_confirm" ]; then
            echo -e "${RED}Passwords do not match${NC}"
            continue
        fi
        break
    done

    # Install hostapd and dnsmasq for AP mode
    echo -e "${YELLOW}Installing Access Point packages...${NC}"
    apt install -y hostapd >/dev/null 2>&1 || true

    # Stop services during configuration
    systemctl stop hostapd 2>/dev/null || true
    systemctl stop wpa_supplicant 2>/dev/null || true

    # Configure hostapd for hidden AP
    cat > /etc/hostapd/hostapd.conf << HOSTAPDEOF
interface=wlan0
driver=nl80211
ssid=PiCycle
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=1
wpa=2
wpa_passphrase=$wifi_pass
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
HOSTAPDEOF

    chmod 600 /etc/hostapd/hostapd.conf

    # Point hostapd to config file
    sed -i 's|^#DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd 2>/dev/null || true
    echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' >> /etc/default/hostapd 2>/dev/null || true

    # Configure static IP for wlan0 AP
    # Remove any existing wlan0 config from dhcpcd.conf
    sed -i '/^interface wlan0/,/^$/d' /etc/dhcpcd.conf 2>/dev/null || true
    sed -i '/^# PiCycle WiFi AP/,/^$/d' /etc/dhcpcd.conf 2>/dev/null || true

    cat >> /etc/dhcpcd.conf << 'DHCPCDEOF'

# PiCycle WiFi AP
interface wlan0
static ip_address=192.168.4.1/24
nohook wpa_supplicant
DHCPCDEOF

    # Configure dnsmasq for WiFi AP DHCP
    cat > /etc/dnsmasq.d/wlan0.conf << 'DNSMASQWLANEOF'
# PiCycle WiFi AP DHCP
interface=wlan0
bind-interfaces
dhcp-range=192.168.4.10,192.168.4.100,255.255.255.0,24h
dhcp-option=option:router,192.168.4.1
dhcp-option=option:dns-server,192.168.4.1
DNSMASQWLANEOF

    # Unmask and enable hostapd
    systemctl unmask hostapd 2>/dev/null || true
    systemctl enable hostapd 2>/dev/null || true

    echo -e "${GREEN}✓ WiFi Access Point configured${NC}"
    echo -e "  ${CYAN}SSID:${NC} PiCycle (hidden)"
    echo -e "  ${CYAN}IP:${NC} 192.168.4.1"
    echo -e "  ${CYAN}DHCP Range:${NC} 192.168.4.10 - 192.168.4.100"
}

# Install PiCycle
install_picycle() {
    echo -e "\n${MAGENTA}${BOLD}[*] Installing PiCycle USB Composite Gadget${NC}\n"
    
    mkdir -p "$CONFIG_DIR" "$BACKUP_DIR"
    
    # Backup existing files
    echo -e "${YELLOW}[1/10] Creating backups...${NC}"
    for file in "$BOOT_DIR/config.txt" "$BOOT_DIR/cmdline.txt" "/etc/dhcpcd.conf" "/etc/modules"; do
        if [ -f "$file" ] && [ ! -f "$BACKUP_DIR/$(basename "$file").bak" ]; then
            cp "$file" "$BACKUP_DIR/$(basename "$file").bak"
            echo -e "  ${GREEN}✓${NC} Backed up $(basename "$file")"
        fi
    done
    
    # Configure WiFi
    echo -e "\n${YELLOW}[2/10] Network Configuration...${NC}"
    configure_wifi
    
    # Configure boot files
    echo -e "\n${YELLOW}[3/10] Configuring boot parameters...${NC}"
    
    sed -i '/^dtoverlay=dwc2/d' "$BOOT_DIR/config.txt"
    echo "dtoverlay=dwc2,dr_mode=peripheral" >> "$BOOT_DIR/config.txt"
    echo -e "  ${GREEN}✓${NC} config.txt configured"
    
    local cmdline=$(cat "$BOOT_DIR/cmdline.txt")
    # Remove any existing modules-load=dwc2 and clean up extra spaces
    cmdline=$(echo "$cmdline" | sed 's/modules-load=dwc2[^ ]*//g' | sed 's/  */ /g' | sed 's/^ //' | sed 's/ $//')
    # Add modules-load=dwc2 before rootwait if it exists, otherwise append it
    if echo "$cmdline" | grep -q "rootwait"; then
        cmdline=$(echo "$cmdline" | sed 's/rootwait/modules-load=dwc2 rootwait/')
    else
        cmdline="$cmdline modules-load=dwc2"
    fi
    echo "$cmdline" > "$BOOT_DIR/cmdline.txt"
    echo -e "  ${GREEN}✓${NC} cmdline.txt configured"
    
    # Configure modules
    echo -e "\n${YELLOW}[4/10] Configuring kernel modules...${NC}"
    sed -i '/^dwc2$/d' /etc/modules
    sed -i '/^libcomposite$/d' /etc/modules
    echo -e "dwc2\nlibcomposite" >> /etc/modules
    echo -e "  ${GREEN}✓${NC} Modules configured"
    
    # Install packages
    echo -e "\n${YELLOW}[5/10] Installing required packages...${NC}"
    apt update -qq
    apt install -y dosfstools avahi-daemon jq dnsmasq 2>&1 | grep -E "Setting up|already" || true
    # Stop dnsmasq default service - we'll configure it for usb0 only
    systemctl stop dnsmasq 2>/dev/null || true
    systemctl disable dnsmasq 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} Packages installed"
    
    # Configure storage size (always 8GB)
    echo -e "\n${YELLOW}[6/10] Configuring USB mass storage size...${NC}"
    local storage_mb=8192
    echo -e "  ${GREEN}✓${NC} Storage size: 8 GB"
    echo "$storage_mb" > "$CONFIG_DIR/storage_size"
    
    local available_mb=$(df / | awk 'NR==2 {print int($4/1024)}')
    if [ "$available_mb" -lt "$storage_mb" ]; then
        echo -e "  ${YELLOW}⚠${NC} Warning: Only ${available_mb}MB available"
        read -p "Continue? (y/n): " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && return
    fi
    
    # Create gadget script
    echo -e "\n${YELLOW}[7/10] Creating USB gadget script...${NC}"
    
    cat > "$GADGET_SCRIPT" << 'GADGETEOF'
#!/bin/bash
set -e
exec 2>&1

log() { echo "[$(date '+%H:%M:%S')] $1"; }

log "PiCycle gadget starting..."

# Wait for system to be ready
sleep 3

# Load modules
log "Loading libcomposite module..."
modprobe libcomposite || { log "ERROR: Failed to load libcomposite"; exit 1; }
sleep 2

# Wait for UDC
log "Waiting for UDC controller..."
UDC=""
for i in $(seq 1 20); do
    UDC=$(ls /sys/class/udc/ 2>/dev/null | head -n1)
    [ -n "$UDC" ] && break
    sleep 1
done
if [ -z "$UDC" ]; then
    log "ERROR: No UDC controller found after 20 seconds"
    exit 1
fi
log "Found UDC: $UDC"

# Mount configfs if needed
if [ ! -d /sys/kernel/config/usb_gadget ]; then
    mount -t configfs none /sys/kernel/config 2>/dev/null || true
fi

cd /sys/kernel/config/usb_gadget/ || exit 1
GADGET="picycle"

# Clean up existing gadget
if [ -d "$GADGET" ]; then
    log "Cleaning up existing gadget..."
    echo "" > "$GADGET/UDC" 2>/dev/null || true
    sleep 1
    rm -f "$GADGET/os_desc/c.1" 2>/dev/null || true
    rm -f "$GADGET/configs/c.1/rndis.usb0" 2>/dev/null || true
    rm -f "$GADGET/configs/c.1/hid.usb0" 2>/dev/null || true
    rm -f "$GADGET/configs/c.1/mass_storage.usb0" 2>/dev/null || true
    rmdir "$GADGET/configs/c.1/strings/0x409" 2>/dev/null || true
    rmdir "$GADGET/configs/c.1" 2>/dev/null || true
    rmdir "$GADGET/functions/rndis.usb0" 2>/dev/null || true
    rmdir "$GADGET/functions/hid.usb0" 2>/dev/null || true
    rmdir "$GADGET/functions/mass_storage.usb0" 2>/dev/null || true
    rmdir "$GADGET/strings/0x409" 2>/dev/null || true
    rmdir "$GADGET" 2>/dev/null || true
fi

log "Creating gadget structure..."
mkdir -p "$GADGET"
cd "$GADGET"

# Device descriptor - Composite device for Windows
echo 0x1d6b > idVendor   # Linux Foundation
echo 0x0104 > idProduct  # Multifunction Composite Gadget
echo 0x0100 > bcdDevice
echo 0x0200 > bcdUSB

# Composite device class - required for multi-function
echo 0xEF > bDeviceClass
echo 0x02 > bDeviceSubClass
echo 0x01 > bDeviceProtocol

# Strings
mkdir -p strings/0x409
echo "fedcba9876543210" > strings/0x409/serialnumber
echo "PiCycle" > strings/0x409/manufacturer
echo "PiCycle USB Gadget" > strings/0x409/product

# Config
mkdir -p configs/c.1/strings/0x409
echo "Config 1: RNDIS + HID + Mass Storage" > configs/c.1/strings/0x409/configuration
echo 250 > configs/c.1/MaxPower

# OS descriptors for Windows RNDIS auto-detection
mkdir -p os_desc
echo 1 > os_desc/use
echo 0xcd > os_desc/b_vendor_code
echo "MSFT100" > os_desc/qw_sign

# ============ Function 1: RNDIS Network ============
log "Creating RNDIS function..."
mkdir -p functions/rndis.usb0

# Force Windows to bind the in-box RNDIS driver (no INF)
# Windows expects EF/04/01 on the RNDIS interface
echo "EF" > functions/rndis.usb0/class
echo "04" > functions/rndis.usb0/subclass
echo "01" > functions/rndis.usb0/protocol

# Enable WCID / Extended OS descriptors if supported (improves Windows auto-detect)
if [ -f functions/rndis.usb0/wceis ]; then
    echo 1 > functions/rndis.usb0/wceis
fi

# Wait for os_desc interface directory to be created by kernel
log "Waiting for RNDIS os_desc interface..."
for i in $(seq 1 10); do
    [ -d "functions/rndis.usb0/os_desc/interface.rndis" ] && break
    sleep 0.5
done

if [ ! -d "functions/rndis.usb0/os_desc/interface.rndis" ]; then
    log "ERROR: RNDIS os_desc interface not created - Windows network may not work"
else
    # Set Windows OS descriptor IDs for RNDIS auto-detection
    echo "RNDIS" > functions/rndis.usb0/os_desc/interface.rndis/compatible_id
    echo "5162001" > functions/rndis.usb0/os_desc/interface.rndis/sub_compatible_id
    log "RNDIS OS descriptors configured for Windows"
fi

# Set MAC addresses
echo "48:6f:73:74:50:43" > functions/rndis.usb0/host_addr
echo "42:61:64:55:53:42" > functions/rndis.usb0/dev_addr

# ============ Function 2: HID Keyboard ============
log "Creating HID keyboard function..."
mkdir -p functions/hid.usb0
echo 1 > functions/hid.usb0/protocol      # Keyboard protocol
echo 1 > functions/hid.usb0/subclass      # Boot interface subclass
echo 8 > functions/hid.usb0/report_length # 8-byte reports

# Standard USB HID keyboard report descriptor (63 bytes)
# This is the standard boot keyboard descriptor
echo -ne '\x05\x01\x09\x06\xa1\x01\x05\x07\x19\xe0\x29\xe7\x15\x00\x25\x01\x75\x01\x95\x08\x81\x02\x95\x01\x75\x08\x81\x03\x95\x05\x75\x01\x05\x08\x19\x01\x29\x05\x91\x02\x95\x01\x75\x03\x91\x03\x95\x06\x75\x08\x15\x00\x25\x65\x05\x07\x19\x00\x29\x65\x81\x00\xc0' > functions/hid.usb0/report_desc

# ============ Function 3: Mass Storage ============
log "Creating Mass Storage function..."
STORAGE="/piusb.img"
STORAGE_SIZE=8192
[ -f /etc/picycle/storage_size ] && STORAGE_SIZE=$(cat /etc/picycle/storage_size)

# Create storage image FIRST if it doesn't exist
if [ ! -f "$STORAGE" ]; then
    log "Creating ${STORAGE_SIZE}MB storage image (this may take a while)..."
    dd if=/dev/zero of="$STORAGE" bs=1M count="$STORAGE_SIZE" status=progress 2>&1 || {
        log "ERROR: Failed to create storage image"
        exit 1
    }
    sync
    log "Formatting storage as FAT32..."
    /sbin/mkfs.vfat -F 32 -n "PICYCLE" "$STORAGE" || {
        log "ERROR: Failed to format storage"
        rm -f "$STORAGE"
        exit 1
    }
    sync
    log "Storage image created successfully"
fi

# Verify storage file
if [ ! -f "$STORAGE" ]; then
    log "ERROR: Storage file $STORAGE does not exist"
    exit 1
fi

# Now create the mass_storage function
mkdir -p functions/mass_storage.usb0

# The lun.0 directory is auto-created, wait for it
for i in $(seq 1 10); do
    [ -d "functions/mass_storage.usb0/lun.0" ] && break
    sleep 0.5
done

if [ ! -d "functions/mass_storage.usb0/lun.0" ]; then
    log "ERROR: lun.0 directory not created"
    exit 1
fi

# Configure mass storage
echo 1 > functions/mass_storage.usb0/stall
echo 0 > functions/mass_storage.usb0/lun.0/cdrom
echo 0 > functions/mass_storage.usb0/lun.0/ro
echo 1 > functions/mass_storage.usb0/lun.0/removable
echo 0 > functions/mass_storage.usb0/lun.0/nofua
echo "$STORAGE" > functions/mass_storage.usb0/lun.0/file || {
    log "ERROR: Failed to bind storage file to gadget"
    exit 1
}
log "Mass storage bound to $STORAGE"

# ============ Link functions to config ============
log "Linking functions to config..."
# USB gadget configfs resolves symlink targets from the gadget root, not from the symlink location
ln -sf functions/rndis.usb0 configs/c.1/
ln -sf functions/hid.usb0 configs/c.1/
ln -sf functions/mass_storage.usb0 configs/c.1/
ln -sf configs/c.1 os_desc/

# ============ Enable gadget ============
log "Enabling gadget on $UDC..."
echo "$UDC" > UDC || {
    log "ERROR: Failed to enable gadget"
    exit 1
}

log "Gadget enabled successfully"
sleep 2

# ============ Configure USB network interface ============
log "Configuring usb0 network interface..."
for i in $(seq 1 15); do
    if ip link show usb0 &>/dev/null; then
        log "usb0 interface found"
        ip addr flush dev usb0 2>/dev/null || true
        ip addr add 10.55.0.1/24 dev usb0
        ip link set usb0 up
        log "usb0 configured with IP 10.55.0.1/24"
        break
    fi
    sleep 1
done

if ! ip link show usb0 &>/dev/null; then
    log "WARNING: usb0 interface not found after 15 seconds"
fi

# ============ Start DHCP server for USB network ============
log "Starting DHCP server on usb0..."

# Create dnsmasq config for usb0
cat > /etc/dnsmasq.d/usb0.conf << 'DNSMASQEOF'
# PiCycle USB Network DHCP
interface=usb0
bind-interfaces
dhcp-range=10.55.0.10,10.55.0.100,255.255.255.0,12h
dhcp-option=option:router,10.55.0.1
dhcp-option=option:dns-server,10.55.0.1
dhcp-leasefile=/var/lib/misc/dnsmasq.usb0.leases
log-dhcp
DNSMASQEOF

# Create lease file directory
mkdir -p /var/lib/misc
touch /var/lib/misc/dnsmasq.usb0.leases

# Kill any existing dnsmasq on usb0 and restart
pkill -f "dnsmasq.*usb0" 2>/dev/null || true
sleep 1

# Start dnsmasq for usb0 only
if ip link show usb0 &>/dev/null; then
    /usr/sbin/dnsmasq --conf-file=/etc/dnsmasq.d/usb0.conf --pid-file=/run/dnsmasq.usb0.pid &
    sleep 1
    if pgrep -f "dnsmasq.*usb0" > /dev/null; then
        log "DHCP server started successfully"
    else
        log "WARNING: DHCP server may not have started"
    fi
fi

# ============ Set permissions on HID device ============
log "Setting up HID device permissions..."
for i in $(seq 1 10); do
    if [ -e /dev/hidg0 ]; then
        chmod 666 /dev/hidg0
        log "HID device /dev/hidg0 ready with permissions 666"
        break
    fi
    sleep 1
done

if [ ! -e /dev/hidg0 ]; then
    log "WARNING: /dev/hidg0 not created - HID keyboard may not work"
fi

# ============ Summary ============
log "=========================================="
log "PiCycle gadget setup complete!"
log "  Network: usb0 = 10.55.0.1/24"
log "  DHCP: 10.55.0.10 - 10.55.0.100"
log "  HID: $([ -e /dev/hidg0 ] && echo 'Ready' || echo 'NOT READY')"
log "  Storage: $([ -f /piusb.img ] && echo 'Ready' || echo 'NOT READY')"
log "=========================================="
GADGETEOF

    chmod +x "$GADGET_SCRIPT"
    echo -e "  ${GREEN}✓${NC} Gadget script created"
    
    # Create systemd service
    echo -e "\n${YELLOW}[8/10] Creating systemd service...${NC}"
    
    cat > "$SERVICE_FILE" << 'SERVICEEOF'
[Unit]
Description=PiCycle USB Composite Gadget
After=sysinit.target local-fs.target
Before=network.target
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/usr/bin/picycle_gadget.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=sysinit.target
SERVICEEOF

    systemctl daemon-reload
    systemctl enable picycle.service
    echo -e "  ${GREEN}✓${NC} Service enabled"
    
    # Configure network
    echo -e "\n${YELLOW}[9/10] Configuring USB network and DHCP...${NC}"
    sed -i '/^# PiCycle/,/^$/d' /etc/dhcpcd.conf
    sed -i '/^interface usb0/,/^$/d' /etc/dhcpcd.conf

    cat >> /etc/dhcpcd.conf << 'NETEOF'

# PiCycle USB Network
interface usb0
static ip_address=10.55.0.1/24
nohook wpa_supplicant
NETEOF

    # Create dnsmasq config directory
    mkdir -p /etc/dnsmasq.d
    mkdir -p /var/lib/misc

    # Pre-create the dnsmasq config for usb0
    cat > /etc/dnsmasq.d/usb0.conf << 'DNSMASQEOF'
# PiCycle USB Network DHCP
interface=usb0
bind-interfaces
dhcp-range=10.55.0.10,10.55.0.100,255.255.255.0,12h
dhcp-option=option:router,10.55.0.1
dhcp-option=option:dns-server,10.55.0.1
dhcp-leasefile=/var/lib/misc/dnsmasq.usb0.leases
log-dhcp
DNSMASQEOF

    systemctl enable ssh 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} Network and DHCP configured"


    # Web server (lightweight) + PHP for http://10.55.0.1/
    echo -e "\n${YELLOW}[WEB] Configuring web server and PHP...${NC}"

    # Determine primary non-root user for ~/PiCycle/assets and ~/www
    INVOKER_USER=""
    if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
        INVOKER_USER="$SUDO_USER"
    else
        INVOKER_USER="$(getent passwd 1000 2>/dev/null | cut -d: -f1)"
        if [ -z "$INVOKER_USER" ]; then
            INVOKER_USER="$(getent passwd 2>/dev/null | awk -F: '$3>=1000 && $3<65534 {print $1; exit}')"
        fi
    fi
    if [ -z "$INVOKER_USER" ]; then
        INVOKER_USER="root"
    fi

    INVOKER_HOME="$(getent passwd "$INVOKER_USER" 2>/dev/null | cut -d: -f6)"
    if [ -z "$INVOKER_HOME" ]; then
        INVOKER_HOME="/root"
    fi

    # Stop/disable/mask other web servers that can occupy :80
    for svc in apache2 nginx lighttpd caddy; do
        systemctl stop "$svc" 2>/dev/null || true
        systemctl disable "$svc" 2>/dev/null || true
        systemctl mask "$svc" 2>/dev/null || true
    done

    apt update -qq || true
    DEBIAN_FRONTEND=noninteractive apt install -y php-cli php-cgi curl >/dev/null 2>&1 || true
    DEBIAN_FRONTEND=noninteractive apt install -y uhttpd >/dev/null 2>&1 || true

    # Make php-cgi usable (prevents common CGI "Security Alert" failures)
    for ini in /etc/php/*/cgi/php.ini; do
        [ -f "$ini" ] || continue
        if grep -qE '^[;[:space:]]*cgi\.force_redirect' "$ini"; then
            sed -i 's/^[;[:space:]]*cgi\.force_redirect\s*=.*/cgi.force_redirect = 0/' "$ini" 2>/dev/null || true
        else
            echo "cgi.force_redirect = 0" >> "$ini"
        fi
    done

    WEBROOT="/var/www/html"
    mkdir -p "$WEBROOT"

    # Copy ~/PiCycle/assets/ into the web root (recursive, including directories and files)
    # Result: /var/www/html/index.php is served at http://10.55.0.1/
    ASSET_DIR=""

    # Prefer the sudo-invoking user's ~/PiCycle/assets
    if [ -n "${INVOKER_HOME:-}" ] && [ -d "${INVOKER_HOME}/PiCycle/assets" ]; then
        ASSET_DIR="${INVOKER_HOME}/PiCycle/assets"
    fi

    # Fallbacks
    if [ -z "$ASSET_DIR" ]; then
        for candidate in "/home/pi/PiCycle/assets" "/root/PiCycle/assets"; do
            if [ -d "$candidate" ]; then
                ASSET_DIR="$candidate"
                break
            fi
        done
    fi

    # Last resort: any /home/*/PiCycle/assets directory (most common when username is not pi)
    if [ -z "$ASSET_DIR" ]; then
        for candidate in /home/*/PiCycle/assets; do
            if [ -d "$candidate" ]; then
                ASSET_DIR="$candidate"
                break
            fi
        done
    fi

    mkdir -p "$WEBROOT"

    if [ -n "$ASSET_DIR" ] && [ -d "$ASSET_DIR" ]; then
        # Copy contents of assets into web root (preserves subdirectories)
        (cd "$ASSET_DIR" && tar cf - .) | (cd "$WEBROOT" && tar xpf -)
    fi

    # If assets did not provide index.php, create a minimal placeholder
    if [ ! -f "$WEBROOT/index.php" ]; then
        cat > "$WEBROOT/index.php" <<'PHP'
<?php
header('Content-Type: text/plain; charset=utf-8');
echo "Missing ~/PiCycle/assets/index.php\n";
?>
PHP
    fi

    # Permissions: readable by the web server, writable by the primary user
    if [ -n "${INVOKER_USER:-}" ] && [ "$INVOKER_USER" != "root" ] && id -u "$INVOKER_USER" >/dev/null 2>&1; then
        chown -R "$INVOKER_USER":"$INVOKER_USER" "$WEBROOT" 2>/dev/null || true
    fi
    chmod -R a+rX,u+w "$WEBROOT" 2>/dev/null || true
    chmod 0644 "$WEBROOT/index.php" 2>/dev/null || true

    # Ensure / redirects to /index.php if the server does not index index.php by default
    # Do not overwrite a user-provided index.html from ~/PiCycle/assets/
    if [ ! -f "$WEBROOT/index.html" ]; then
        cat > "$WEBROOT/index.html" <<'HTML'
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <meta http-equiv="refresh" content="0; url=/index.php">
    <title>Redirecting</title>
  </head>
  <body>
    <script>location.replace("/index.php");</script>
    <noscript><a href="/index.php">Continue</a></noscript>
  </body>
</html>
HTML
        chmod 0644 "$WEBROOT/index.html" 2>/dev/null || true
    fi

    # Symlink ~/www -> /var/www/html for easy access (invoker, pi, and root)
    if [ -n "$INVOKER_HOME" ] && [ -d "$INVOKER_HOME" ] && [ "$INVOKER_HOME" != "/root" ]; then
        ln -sfn "$WEBROOT" "${INVOKER_HOME}/www"
        chown -h "$INVOKER_USER":"$INVOKER_USER" "${INVOKER_HOME}/www" 2>/dev/null || true
    fi
    if id -u pi >/dev/null 2>&1; then
        PI_HOME="$(getent passwd pi 2>/dev/null | cut -d: -f6)"
        if [ -n "$PI_HOME" ] && [ -d "$PI_HOME" ]; then
            ln -sfn "$WEBROOT" "${PI_HOME}/www"
            chown -h pi:pi "${PI_HOME}/www" 2>/dev/null || true
        fi
    fi
    ln -sfn "$WEBROOT" /root/www

    # Wrapper selects uhttpd if usable, otherwise falls back to PHP built-in server
    cat > /usr/bin/picycle_web.sh <<'WEBEOF'
#!/bin/bash
set -euo pipefail

WEBROOT="/var/www/html"
MODE_FILE="/etc/picycle/web_mode"

MODE=""
if [ -f "$MODE_FILE" ]; then
  MODE="$(tr -d ' \t\r\n' < "$MODE_FILE" 2>/dev/null || true)"
fi

PHPCGI="$(command -v php-cgi 2>/dev/null || true)"
PHPBIN="$(command -v php 2>/dev/null || true)"
UHTTPD="$(command -v uhttpd 2>/dev/null || true)"

run_php_builtin() {
  [ -n "$PHPBIN" ] || exit 1
  exec "$PHPBIN" -S 0.0.0.0:80 -t "$WEBROOT"
}

run_uhttpd() {
  [ -n "$UHTTPD" ] || return 1

  # Require interpreter mapping support for .php
  if ! "$UHTTPD" --help 2>&1 | grep -qE '(^|[[:space:]])-i[[:space:]]'; then
    return 1
  fi

  ARGS=(-f -p 0.0.0.0:80 -h "$WEBROOT")

  if "$UHTTPD" --help 2>&1 | grep -qE '(^|[[:space:]])-x[[:space:]]'; then
    ARGS+=( -x /cgi-bin )
  fi

  if [ -n "$PHPCGI" ]; then
    ARGS+=( -i ".php=$PHPCGI" )
  else
    return 1
  fi

  if "$UHTTPD" --help 2>&1 | grep -qE '(^|[[:space:]])-I[[:space:]]'; then
    ARGS+=( -I index.php )
  fi

  exec "$UHTTPD" "${ARGS[@]}"
}

if [ "$MODE" = "php" ]; then
  run_php_builtin
fi

# Default: try uhttpd, then fall back to PHP built-in
run_uhttpd || run_php_builtin
WEBEOF
    chmod 0755 /usr/bin/picycle_web.sh

    # Dedicated systemd service so the web server starts on boot
    cat > /etc/systemd/system/picycle-web.service <<'EOF'
[Unit]
Description=PiCycle web server
After=network.target picycle.service
Wants=picycle.service

[Service]
Type=simple
ExecStart=/usr/bin/picycle_web.sh
Restart=on-failure
RestartSec=1

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload 2>/dev/null || true
    systemctl enable picycle-web.service 2>/dev/null || true
    systemctl restart picycle-web.service 2>/dev/null || systemctl start picycle-web.service 2>/dev/null || true

    # Self-test: ensure server is reachable and PHP is executing
    rm -f /tmp/picycle_web_test.out 2>/dev/null || true
    for _i in 1 2 3 4 5; do
        if curl -fsS http://127.0.0.1/index.php -o /tmp/picycle_web_test.out 2>/dev/null; then
            break
        fi
        sleep 1
    done

    if [ -s /tmp/picycle_web_test.out ] && grep -q "<?php" /tmp/picycle_web_test.out; then
        echo "php" > /etc/picycle/web_mode 2>/dev/null || true
        systemctl restart picycle-web.service 2>/dev/null || true
    fi

    echo -e "  ${GREEN}✓${NC} Web server configured"
    
    # Final check
    echo -e "\n${YELLOW}[10/10] Verifying installation...${NC}"
    echo -e "  ${GREEN}✓${NC} Boot config verified"
    echo -e "  ${GREEN}✓${NC} Service: $(systemctl is-enabled picycle.service 2>/dev/null)"
    echo -e "  ${GREEN}✓${NC} Storage: ${storage_mb}MB"
    
    echo -e "\n${GREEN}${BOLD}✓ PiCycle installation complete!${NC}\n"
    echo -e "${CYAN}${BOLD}IMPORTANT:${NC} ${YELLOW}Reboot required${NC}"
    echo -e "${CYAN}After reboot, Windows should show:${NC}"
    echo -e "  ${GREEN}•${NC} ${WHITE}Network adapter${NC} - Auto-configured via DHCP (10.55.0.x)"
    echo -e "  ${GREEN}•${NC} ${WHITE}USB Drive${NC} - 'PICYCLE' (${storage_mb}MB FAT32)"
    echo -e "  ${GREEN}•${NC} ${WHITE}HID Keyboard${NC} - Ready for use with picycle.py"
    echo -e ""
    echo -e "${CYAN}SSH Access:${NC}"
    echo -e "  • Via USB network: ${YELLOW}ssh pi@10.55.0.1${NC}"
    echo -e "  • Via WiFi AP: ${YELLOW}ssh pi@192.168.4.1${NC}"
    echo -e ""
    echo -e "${CYAN}Test HID keyboard:${NC}"
    echo -e "  ${YELLOW}sudo python3 picycle.py${NC}\n"
    
    read -p "Reboot now? (y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] && reboot
}

# Main program
main() {
    check_root
    show_banner
    install_picycle
}

main "$@"
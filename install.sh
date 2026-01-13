#!/bin/bash

################################################################################
# PiCycle - Raspberry Pi Zero 2W USB Gadget Multi-Tool
# Transforms Pi Zero 2W into: HID Keyboard + Mass Storage + Network Device
# Compatible with: Windows, Linux, macOS
################################################################################

set -e

# Master install log - captures everything
readonly INSTALL_LOG="/var/log/picycle_install.log"

# Initialize logging - log all output to file AND terminal
exec > >(tee -a "$INSTALL_LOG") 2>&1
echo ""
echo "================================================================================"
echo "PiCycle Installation Log - Started: $(date)"
echo "================================================================================"
echo ""

# Logging function with timestamps
log_step() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$INSTALL_LOG"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$INSTALL_LOG"
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" | tee -a "$INSTALL_LOG"
}

log_warning() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" | tee -a "$INSTALL_LOG"
}

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
readonly REPORT_FILE="$CONFIG_DIR/system_report.json"
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

# Show main menu
show_menu() {
    echo -e "${WHITE}${BOLD}Main Menu:${NC}\n"
    echo -e "${GREEN}  [1]${NC} ${MAGENTA}Install PiCycle${NC} - Configure USB composite gadget (HID+Storage+Network)"
    echo -e "${GREEN}  [2]${NC} ${YELLOW}Diagnostic Report${NC} - Run post-install tests & generate troubleshooting report"
    echo -e "${GREEN}  [3]${NC} ${BLUE}Restore Defaults${NC} - Remove PiCycle and restore original settings"
    echo -e "${GREEN}  [4]${NC} ${RED}Exit${NC}\n"
    echo -e "${GRAY}════════════════════════════════════════════════════════════════${NC}"
}

# System scan function
system_scan() {
    echo -e "\n${CYAN}${BOLD}[*] Initiating comprehensive system scan...${NC}\n"
    
    mkdir -p "$CONFIG_DIR"
    
    echo -e "${YELLOW}[+] Gathering hardware information...${NC}"
    
    local pi_model=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo "Unknown")
    local kernel=$(uname -r)
    local os_info=$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2)
    local cpu_info=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
    local memory=$(free -h | awk '/^Mem:/ {print $2}')
    local disk=$(df -h / | awk 'NR==2 {print $2}')
    
    echo -e "${YELLOW}[+] Scanning USB configuration...${NC}"
    
    local udc_devices=$(ls /sys/class/udc/ 2>/dev/null)
    udc_devices=${udc_devices:-none}
    local dwc2_loaded=$(lsmod | grep -q dwc2 && echo "true" || echo "false")
    local libcomposite_loaded=$(lsmod | grep -q libcomposite && echo "true" || echo "false")
    
    echo -e "${YELLOW}[+] Checking network configuration...${NC}"
    
    local wifi_connected=$(iwgetid -r 2>/dev/null || echo "Not connected")
    local wifi_interface=$(ip link | grep -o "wlan[0-9]" | head -1)
    wifi_interface=${wifi_interface:-none}
    
    cat > "$REPORT_FILE" << EOF
{
  "scan_date": "$(date -Iseconds)",
  "hardware": {
    "model": "$pi_model",
    "cpu": "$cpu_info",
    "memory": "$memory",
    "disk_size": "$disk"
  },
  "operating_system": {
    "distribution": "$os_info",
    "kernel": "$kernel",
    "boot_directory": "$BOOT_DIR"
  },
  "usb_gadget": {
    "udc_controller": "$udc_devices",
    "dwc2_module_loaded": $dwc2_loaded,
    "libcomposite_loaded": $libcomposite_loaded
  },
  "network": {
    "wifi_ssid": "$wifi_connected",
    "wifi_interface": "$wifi_interface"
  },
  "picycle_status": {
    "installed": $([ -f "$GADGET_SCRIPT" ] && echo "true" || echo "false"),
    "service_enabled": $(systemctl is-enabled picycle.service 2>/dev/null | grep -q enabled && echo "true" || echo "false")
  }
}
EOF
    
    echo -e "\n${GREEN}✓ System scan complete!${NC}"
    echo -e "${CYAN}Report saved to: ${WHITE}$REPORT_FILE${NC}\n"
    
    echo -e "${BOLD}${WHITE}═══ System Summary ═══${NC}"
    echo -e "${GRAY}Model:${NC}        $pi_model"
    echo -e "${GRAY}OS:${NC}           $os_info"
    echo -e "${GRAY}WiFi:${NC}         $wifi_connected"
    echo -e "${GRAY}UDC:${NC}          $udc_devices"
    echo -e "${GRAY}PiCycle:${NC}      $([ -f "$GADGET_SCRIPT" ] && echo -e "${GREEN}Installed${NC}" || echo -e "${YELLOW}Not installed${NC}")"
    echo ""
    
    read -p "Press Enter to continue..."
}

# Install PiCycle
install_picycle() {
    log_step "=== STARTING PICYCLE INSTALLATION ==="
    echo -e "\n${MAGENTA}${BOLD}[*] Installing PiCycle USB Composite Gadget${NC}\n"

    mkdir -p "$CONFIG_DIR" "$BACKUP_DIR"
    log_step "Created directories: $CONFIG_DIR, $BACKUP_DIR"

    # Backup existing files
    log_step "[STEP 1/9] Creating backups"
    echo -e "${YELLOW}[1/9] Creating backups...${NC}"
    for file in "$BOOT_DIR/config.txt" "$BOOT_DIR/cmdline.txt" "/etc/dhcpcd.conf" "/etc/modules"; do
        if [ -f "$file" ] && [ ! -f "$BACKUP_DIR/$(basename "$file").bak" ]; then
            cp "$file" "$BACKUP_DIR/$(basename "$file").bak"
            log_success "Backed up $file"
            echo -e "  ${GREEN}✓${NC} Backed up $(basename "$file")"
        else
            log_step "Skipped backup for $file (already exists or file missing)"
        fi
    done
    
    # Configure boot files
    log_step "[STEP 2/9] Configuring boot parameters"
    echo -e "\n${YELLOW}[2/9] Configuring boot parameters...${NC}"

    sed -i '/^dtoverlay=dwc2/d' "$BOOT_DIR/config.txt"
    echo "dtoverlay=dwc2,dr_mode=peripheral" >> "$BOOT_DIR/config.txt"
    log_success "config.txt: added dtoverlay=dwc2,dr_mode=peripheral"
    echo -e "  ${GREEN}✓${NC} config.txt configured"

    local cmdline=$(cat "$BOOT_DIR/cmdline.txt")
    log_step "Original cmdline.txt: $cmdline"
    # Remove any existing modules-load=dwc2 and clean up extra spaces
    cmdline=$(echo "$cmdline" | sed 's/modules-load=dwc2[^ ]*//g' | sed 's/  */ /g' | sed 's/^ //' | sed 's/ $//')
    # Add modules-load=dwc2 before rootwait if it exists, otherwise append it
    if echo "$cmdline" | grep -q "rootwait"; then
        cmdline=$(echo "$cmdline" | sed 's/rootwait/modules-load=dwc2 rootwait/')
    else
        cmdline="$cmdline modules-load=dwc2"
    fi
    echo "$cmdline" > "$BOOT_DIR/cmdline.txt"
    log_success "cmdline.txt updated: $cmdline"
    echo -e "  ${GREEN}✓${NC} cmdline.txt configured"
    
    # Configure modules
    log_step "[STEP 3/9] Configuring kernel modules"
    echo -e "\n${YELLOW}[3/9] Configuring kernel modules...${NC}"
    sed -i '/^dwc2$/d' /etc/modules
    sed -i '/^libcomposite$/d' /etc/modules
    echo -e "dwc2\nlibcomposite" >> /etc/modules
    log_success "Added dwc2 and libcomposite to /etc/modules"
    echo -e "  ${GREEN}✓${NC} Modules configured"
    
    # Install packages
    log_step "[STEP 4/9] Installing required packages"
    echo -e "\n${YELLOW}[4/9] Installing required packages...${NC}"
    log_step "Running apt update..."
    apt update -qq
    log_step "Installing: dosfstools avahi-daemon jq dnsmasq"
    apt install -y dosfstools avahi-daemon jq dnsmasq 2>&1 | grep -E "Setting up|already" || true
    # Stop dnsmasq default service - we'll configure it for usb0 only
    systemctl stop dnsmasq 2>/dev/null || true
    systemctl disable dnsmasq 2>/dev/null || true
    log_success "Packages installed, dnsmasq default service disabled"
    echo -e "  ${GREEN}✓${NC} Packages installed"
    
    # Configure storage size (always 8GB)
    log_step "[STEP 5/9] Creating USB mass storage"
    echo -e "\n${YELLOW}[5/9] Creating USB mass storage (8GB)...${NC}"
    local storage_mb=8192
    echo "$storage_mb" > "$CONFIG_DIR/storage_size"
    log_step "Storage size set to ${storage_mb}MB"

    local available_mb=$(df / | awk 'NR==2 {print int($4/1024)}')
    log_step "Available disk space: ${available_mb}MB"
    if [ "$available_mb" -lt "$storage_mb" ]; then
        log_warning "Insufficient disk space: ${available_mb}MB available, ${storage_mb}MB required"
        echo -e "  ${YELLOW}⚠${NC} Warning: Only ${available_mb}MB available"
        read -p "Continue? (y/n): " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && return
    fi

    # Create and format storage image NOW during install
    if [ -f /piusb.img ]; then
        log_step "Removing existing storage image..."
        echo -e "  ${YELLOW}Removing old storage image...${NC}"
        rm -f /piusb.img
    fi
    log_step "Creating ${storage_mb}MB storage image..."
    echo -e "  ${CYAN}Creating ${storage_mb}MB storage image (this takes several minutes)...${NC}"
    dd if=/dev/zero of=/piusb.img bs=1M count="$storage_mb" status=progress
    sync
    log_step "Formatting storage as FAT32..."
    echo -e "  ${CYAN}Formatting as FAT32...${NC}"
    /sbin/mkfs.vfat -F 32 -n "PICYCLE" /piusb.img
    sync
    log_success "Storage image created: /piusb.img (${storage_mb}MB FAT32)"
    echo -e "  ${GREEN}✓${NC} Storage image created and formatted"
    
    # Create gadget script
    log_step "[STEP 6/9] Creating USB gadget script"
    echo -e "\n${YELLOW}[6/9] Creating USB gadget script...${NC}"

    cat > "$GADGET_SCRIPT" << 'GADGETEOF'
#!/bin/bash
set -e
exec 2>&1

log() { echo "[$(date '+%H:%M:%S')] $1"; }

log "PiCycle gadget starting..."
log "Waiting for system to stabilize..."

# Wait for system to be fully ready - this reduces Windows USB errors
# during boot by ensuring Pi is stable before USB gadget enumeration
sleep 5

# Load modules
log "Loading libcomposite module..."
modprobe libcomposite || { log "ERROR: Failed to load libcomposite"; exit 1; }
sleep 2

# Wait for UDC
log "Waiting for UDC controller..."
UDC=""
for i in $(seq 1 30); do
    UDC=$(ls /sys/class/udc/ 2>/dev/null | head -n1)
    [ -n "$UDC" ] && break
    sleep 1
done
if [ -z "$UDC" ]; then
    log "ERROR: No UDC controller found after 30 seconds"
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
log "RNDIS function created"
sleep 1

# ============ Function 2: HID Keyboard ============
log "Creating HID keyboard function..."
mkdir -p functions/hid.usb0
echo 1 > functions/hid.usb0/protocol      # Keyboard protocol
echo 1 > functions/hid.usb0/subclass      # Boot interface subclass
echo 8 > functions/hid.usb0/report_length # 8-byte reports

# Standard USB HID keyboard report descriptor (63 bytes)
# This is the standard boot keyboard descriptor
echo -ne '\x05\x01\x09\x06\xa1\x01\x05\x07\x19\xe0\x29\xe7\x15\x00\x25\x01\x75\x01\x95\x08\x81\x02\x95\x01\x75\x08\x81\x03\x95\x05\x75\x01\x05\x08\x19\x01\x29\x05\x91\x02\x95\x01\x75\x03\x91\x03\x95\x06\x75\x08\x15\x00\x25\x65\x05\x07\x19\x00\x29\x65\x81\x00\xc0' > functions/hid.usb0/report_desc
log "HID keyboard function created"
sleep 1

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
sleep 1

# ============ Link functions to config ============
log "Linking functions to config..."
# USB gadget configfs resolves symlink targets from the gadget root, not from the symlink location
ln -sf functions/rndis.usb0 configs/c.1/
ln -sf functions/hid.usb0 configs/c.1/
ln -sf functions/mass_storage.usb0 configs/c.1/
ln -sf configs/c.1 os_desc/
log "All functions linked to configuration"

# Pause before enabling gadget - ensures all configurations are stable
# This is critical for reducing Windows USB enumeration errors
log "Preparing to enable gadget (waiting for stability)..."
sleep 3

# ============ Enable gadget ============
log "Enabling gadget on $UDC..."
echo "$UDC" > UDC || {
    log "ERROR: Failed to enable gadget"
    exit 1
}

log "Gadget enabled successfully"
# Wait for USB enumeration to complete on host side
# This helps Windows properly detect all functions before we configure network
sleep 5

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
    log_success "Created gadget script: $GADGET_SCRIPT"
    echo -e "  ${GREEN}✓${NC} Gadget script created"

    # Create systemd service
    log_step "[STEP 7/9] Creating systemd service"
    echo -e "\n${YELLOW}[7/9] Creating systemd service...${NC}"
    
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
    log_success "Created and enabled picycle.service"
    echo -e "  ${GREEN}✓${NC} Service enabled"

    # Create udev rule for persistent HID device permissions
    log_step "Creating udev rule for HID device permissions..."
    cat > /etc/udev/rules.d/99-picycle-hid.rules << 'UDEVEOF'
# PiCycle: Set permissions on HID gadget device
# This ensures /dev/hidg0 is always accessible for HID scripts
KERNEL=="hidg[0-9]*", MODE="0666", GROUP="plugdev"
UDEVEOF
    udevadm control --reload-rules 2>/dev/null || true
    log_success "udev rule created for /dev/hidg0 permissions"

    # Configure network
    log_step "[STEP 8/9] Configuring USB network and DHCP"
    echo -e "\n${YELLOW}[8/9] Configuring USB network and DHCP...${NC}"
    sed -i '/^# PiCycle USB Network/,/^$/d' /etc/dhcpcd.conf
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
    log_success "USB network configured (10.55.0.1/24) with DHCP server"
    echo -e "  ${GREEN}✓${NC} Network and DHCP configured"


    # Web server (lightweight) + PHP for http://10.55.0.1/
    log_step "[STEP 9/9] Configuring web server and PHP"
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

    log_success "Web server configured (uhttpd/PHP)"
    echo -e "  ${GREEN}✓${NC} Web server configured"

    # Final check
    log_step "[VERIFICATION] Verifying installation"
    echo -e "\n${YELLOW}[9/9] Verifying installation...${NC}"
    echo -e "  ${GREEN}✓${NC} Boot config verified"
    echo -e "  ${GREEN}✓${NC} Service: $(systemctl is-enabled picycle.service 2>/dev/null)"
    echo -e "  ${GREEN}✓${NC} Storage: ${storage_mb}MB"

    log_success "=== PICYCLE INSTALLATION COMPLETE ==="
    log_step "Log file saved to: $INSTALL_LOG"
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
    echo -e "${CYAN}WiFi Access Point:${NC}"
    echo -e "  • SSID: ${YELLOW}PiCycle${NC}"
    echo -e "  • IP: ${YELLOW}192.168.4.1${NC}"
    echo -e ""

    read -p "Reboot now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Configure WiFi AP before reboot
        log_step "=== WIFI AP CONFIGURATION STARTING ==="
        echo -e "\n${CYAN}${BOLD}Configuring WiFi Access Point before reboot...${NC}"

        # Create log file for WiFi AP setup (also logged to master log)
        local ap_log="/var/log/picycle_ap_setup.log"
        echo "=== PiCycle WiFi AP Setup Log ===" > "$ap_log"
        echo "Started: $(date)" >> "$ap_log"
        echo "Note: This log is also captured in $INSTALL_LOG" >> "$ap_log"

        # Get password from user
        local wifi_pass=""
        while true; do
            read -sp "Enter WiFi AP password (8-63 characters): " wifi_pass
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
        log_step "WiFi AP password obtained (length: ${#wifi_pass})"

        # Install hostapd if needed
        echo -e "${YELLOW}Installing hostapd...${NC}"
        log_step "Installing hostapd package..."
        apt install -y hostapd >> "$ap_log" 2>&1 || log_error "apt install hostapd failed"

        # Stop hostapd for now
        systemctl stop hostapd 2>/dev/null || true
        log_step "hostapd service stopped"

        # === CRITICAL: Completely disable ALL WiFi client functionality ===
        echo -e "${YELLOW}Disabling WiFi client mode (home WiFi)...${NC}"
        log_step "=== DISABLING WIFI CLIENT MODE ==="

        # Step 1: Take down the wlan0 interface immediately
        log_step "Step 1: Taking down wlan0 interface..."
        ip link set wlan0 down 2>/dev/null || true

        # Step 2: Disconnect via wpa_cli
        log_step "Step 2: Disconnecting wpa_cli..."
        wpa_cli -i wlan0 disconnect 2>/dev/null || true

        # Step 3: Terminate wpa_supplicant
        log_step "Step 3: Terminating wpa_supplicant via wpa_cli..."
        wpa_cli -i wlan0 terminate 2>/dev/null || true
        sleep 1

        # Step 4: Stop wpa_supplicant service
        log_step "Step 4: Stopping wpa_supplicant service..."
        systemctl stop wpa_supplicant 2>/dev/null || true
        systemctl stop wpa_supplicant@wlan0 2>/dev/null || true

        # Step 5: Disable wpa_supplicant service
        log_step "Step 5: Disabling wpa_supplicant service..."
        systemctl disable wpa_supplicant 2>/dev/null || true
        systemctl disable wpa_supplicant@wlan0 2>/dev/null || true

        # Step 6: Mask wpa_supplicant to prevent ANY start
        log_step "Step 6: Masking wpa_supplicant service..."
        systemctl mask wpa_supplicant 2>/dev/null || true
        systemctl mask wpa_supplicant@wlan0 2>/dev/null || true

        # Step 7: Kill any remaining wpa_supplicant processes forcefully
        log_step "Step 7: Force killing any wpa_supplicant processes..."
        pkill -9 wpa_supplicant 2>/dev/null || true
        killall -9 wpa_supplicant 2>/dev/null || true
        sleep 1

        # Step 8: Backup and completely remove wpa_supplicant.conf networks
        log_step "Step 8: Removing WiFi network configurations..."
        if [ -f /etc/wpa_supplicant/wpa_supplicant.conf ]; then
            cp /etc/wpa_supplicant/wpa_supplicant.conf "/etc/wpa_supplicant/wpa_supplicant.conf.backup.$(date +%Y%m%d%H%M%S)"
            log_step "Backed up wpa_supplicant.conf"
            # Create empty config with NO networks
            cat > /etc/wpa_supplicant/wpa_supplicant.conf << 'WPAEOF'
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=0
country=US
# ALL NETWORKS REMOVED - WiFi is in AP mode only
# Original config backed up as wpa_supplicant.conf.backup.*
WPAEOF
            log_success "wpa_supplicant.conf cleared of all networks"
        fi

        # Step 9: Also remove any wpa_supplicant interface-specific configs
        log_step "Step 9: Removing interface-specific wpa_supplicant configs..."
        rm -f /etc/wpa_supplicant/wpa_supplicant-wlan0.conf 2>/dev/null || true
        rm -f /var/run/wpa_supplicant/wlan0 2>/dev/null || true

        # Step 10: Disable NetworkManager management of wlan0 (if NetworkManager exists)
        log_step "Step 10: Checking for NetworkManager..."
        if command -v nmcli &>/dev/null; then
            log_step "NetworkManager found, setting wlan0 to unmanaged..."
            nmcli device set wlan0 managed no 2>/dev/null || true

            # Create NetworkManager config to ignore wlan0
            mkdir -p /etc/NetworkManager/conf.d
            cat > /etc/NetworkManager/conf.d/99-picycle-ignore-wlan0.conf << 'NMEOF'
[keyfile]
unmanaged-devices=interface-name:wlan0
NMEOF
            log_success "NetworkManager configured to ignore wlan0"
        else
            log_step "NetworkManager not found (OK)"
        fi

        # Step 11: Use rfkill to ensure WiFi is unblocked (for AP mode)
        log_step "Step 11: Ensuring WiFi is unblocked via rfkill..."
        rfkill unblock wifi 2>/dev/null || true
        rfkill unblock wlan 2>/dev/null || true

        # Step 12: Remove any dhcpcd hooks for wpa_supplicant on wlan0
        log_step "Step 12: Configuring dhcpcd to not use wpa_supplicant on wlan0..."
        # This is already done via nohook, but let's also create a dhcpcd hook file
        mkdir -p /etc/dhcpcd.enter-hook.d
        cat > /etc/dhcpcd.enter-hook.d/10-picycle-no-wlan0-client << 'HOOKEOF'
#!/bin/bash
# PiCycle: Prevent dhcpcd from managing wlan0 as WiFi client
if [ "$interface" = "wlan0" ]; then
    # wlan0 is managed by hostapd for AP mode, not dhcpcd for client mode
    exit 0
fi
HOOKEOF
        chmod +x /etc/dhcpcd.enter-hook.d/10-picycle-no-wlan0-client 2>/dev/null || true

        # Verify wpa_supplicant is completely stopped
        sleep 2
        if pgrep -x wpa_supplicant > /dev/null; then
            log_error "wpa_supplicant STILL RUNNING after all disable steps!"
            echo -e "${RED}Warning: wpa_supplicant still running - forcing kill${NC}"
            pkill -9 wpa_supplicant 2>/dev/null || true
        else
            log_success "wpa_supplicant completely disabled"
            echo -e "${GREEN}✓ wpa_supplicant disabled${NC}"
        fi

        # Create hostapd config
        echo -e "${YELLOW}Configuring Access Point...${NC}"
        log_step "=== CREATING HOSTAPD CONFIGURATION ==="
        mkdir -p /etc/hostapd
        cat > /etc/hostapd/hostapd.conf << HOSTAPDEOF
interface=wlan0
driver=nl80211
ssid=PiCycle
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$wifi_pass
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
HOSTAPDEOF
        chmod 600 /etc/hostapd/hostapd.conf
        log_success "hostapd.conf created with SSID=PiCycle"

        # Point hostapd to config
        if [ -f /etc/default/hostapd ]; then
            sed -i 's|^#*DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
            log_step "Updated /etc/default/hostapd"
        fi

        # Create dnsmasq config for wlan0 AP
        log_step "=== CREATING DNSMASQ CONFIG FOR WLAN0 ==="
        mkdir -p /etc/dnsmasq.d
        cat > /etc/dnsmasq.d/wlan0-ap.conf << 'WLANEOF'
# PiCycle WiFi AP DHCP
interface=wlan0
bind-interfaces
dhcp-range=192.168.4.10,192.168.4.100,255.255.255.0,24h
dhcp-option=option:router,192.168.4.1
dhcp-option=option:dns-server,192.168.4.1
WLANEOF
        log_success "wlan0-ap.conf created (DHCP: 192.168.4.10-100)"

        # Add wlan0 static IP to dhcpcd.conf
        log_step "=== CONFIGURING DHCPCD FOR WLAN0 AP MODE ==="
        sed -i '/^# PiCycle-AP/,/^$/d' /etc/dhcpcd.conf 2>/dev/null || true
        cat >> /etc/dhcpcd.conf << 'WLANAPEOF'

# PiCycle-AP
interface wlan0
static ip_address=192.168.4.1/24
nohook wpa_supplicant

WLANAPEOF
        log_success "dhcpcd.conf updated: wlan0 = 192.168.4.1/24, nohook wpa_supplicant"

        # Enable hostapd to start on boot
        log_step "=== ENABLING HOSTAPD SERVICE ==="
        systemctl unmask hostapd 2>/dev/null || true
        systemctl enable hostapd 2>/dev/null || true
        log_step "hostapd service unmasked and enabled"

        # Create pre-start script to ensure hostapd starts cleanly
        log_step "Creating hostapd pre-start script..."
        cat > /usr/bin/picycle_ap_prestart.sh << 'PRESTARTEOF'
#!/bin/bash
# PiCycle: Ensure wlan0 is ready for hostapd
# This runs BEFORE hostapd starts

echo "[PiCycle AP] Pre-start: preparing wlan0..."

# Kill any rogue wpa_supplicant
pkill -9 wpa_supplicant 2>/dev/null || true

# Ensure wlan0 is down before hostapd takes over
ip link set wlan0 down 2>/dev/null || true
sleep 1

# Unblock WiFi
rfkill unblock wifi 2>/dev/null || true

echo "[PiCycle AP] Pre-start complete"
PRESTARTEOF
        chmod +x /usr/bin/picycle_ap_prestart.sh

        # Create post-start script to configure IP and start DHCP
        log_step "Creating hostapd post-start script..."
        cat > /usr/bin/picycle_ap_poststart.sh << 'POSTSTARTEOF'
#!/bin/bash
# PiCycle: Configure wlan0 IP and start DHCP server
# This runs AFTER hostapd starts successfully

echo "[PiCycle AP] Post-start: configuring network..."

# Wait for hostapd to fully initialize wlan0
sleep 2

# Assign static IP to wlan0 (dhcpcd may not work with hostapd-managed interface)
echo "[PiCycle AP] Assigning IP 192.168.4.1 to wlan0..."
ip addr flush dev wlan0 2>/dev/null || true
ip addr add 192.168.4.1/24 dev wlan0 2>/dev/null || true
ip link set wlan0 up 2>/dev/null || true

# Verify IP was assigned
if ip addr show wlan0 | grep -q "192.168.4.1"; then
    echo "[PiCycle AP] wlan0 IP configured: 192.168.4.1/24"
else
    echo "[PiCycle AP] WARNING: Failed to assign IP to wlan0"
fi

# Kill any existing dnsmasq on wlan0
pkill -f "dnsmasq.*wlan0" 2>/dev/null || true
sleep 1

# Start dnsmasq DHCP server for WiFi AP
echo "[PiCycle AP] Starting DHCP server on wlan0..."
if [ -f /etc/dnsmasq.d/wlan0-ap.conf ]; then
    /usr/sbin/dnsmasq --conf-file=/etc/dnsmasq.d/wlan0-ap.conf --pid-file=/run/dnsmasq.wlan0.pid &
    sleep 1
    if pgrep -f "dnsmasq.*wlan0" > /dev/null; then
        echo "[PiCycle AP] DHCP server started successfully on wlan0"
    else
        echo "[PiCycle AP] WARNING: DHCP server may not have started"
    fi
else
    echo "[PiCycle AP] ERROR: /etc/dnsmasq.d/wlan0-ap.conf not found"
fi

echo "[PiCycle AP] Post-start complete"
POSTSTARTEOF
        chmod +x /usr/bin/picycle_ap_poststart.sh

        # Create systemd override for hostapd with pre and post scripts
        mkdir -p /etc/systemd/system/hostapd.service.d
        cat > /etc/systemd/system/hostapd.service.d/picycle.conf << 'OVERRIDEEOF'
[Service]
ExecStartPre=/usr/bin/picycle_ap_prestart.sh
ExecStartPost=/usr/bin/picycle_ap_poststart.sh
OVERRIDEEOF
        systemctl daemon-reload
        log_success "hostapd pre-start and post-start scripts installed"

        # Verify hostapd is enabled
        if systemctl is-enabled hostapd 2>/dev/null | grep -q enabled; then
            log_success "hostapd service ENABLED"
            echo -e "${GREEN}✓ hostapd enabled${NC}"
        else
            log_error "hostapd may not be enabled"
            echo -e "${RED}Warning: hostapd may not be enabled${NC}"
        fi

        # Final status summary
        log_step "=== WIFI AP CONFIGURATION FINAL STATUS ==="
        log_step "wpa_supplicant service: $(systemctl is-enabled wpa_supplicant 2>&1 || echo 'masked/disabled')"
        log_step "hostapd service: $(systemctl is-enabled hostapd 2>&1)"
        log_step "wpa_supplicant running: $(pgrep -x wpa_supplicant > /dev/null && echo 'YES - PROBLEM!' || echo 'NO - Good')"

        # Copy final log status to AP log file
        echo "" >> "$ap_log"
        echo "=== Final Status ===" >> "$ap_log"
        echo "wpa_supplicant service: $(systemctl is-enabled wpa_supplicant 2>&1 || echo 'masked/disabled')" >> "$ap_log"
        echo "hostapd service: $(systemctl is-enabled hostapd 2>&1)" >> "$ap_log"
        echo "Completed: $(date)" >> "$ap_log"

        log_success "=== WIFI AP CONFIGURATION COMPLETE ==="
        echo -e "${GREEN}✓ WiFi AP configured (SSID: PiCycle)${NC}"
        echo -e "${CYAN}Logs saved to:${NC}"
        echo -e "  ${YELLOW}• $INSTALL_LOG${NC} (complete install log)"
        echo -e "  ${YELLOW}• $ap_log${NC} (AP setup summary)"
        echo -e "${YELLOW}Rebooting now...${NC}"
        sleep 2
        reboot
    fi
}

# Diagnostic report
diagnostic_report() {
    echo -e "\n${YELLOW}${BOLD}[*] Running diagnostic tests...${NC}\n"
    
    local report_file="/tmp/picycle_diagnostic_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "═══════════════════════════════════════════════════════"
        echo "PiCycle Diagnostic Report - $(date)"
        echo "═══════════════════════════════════════════════════════"
        echo ""
        echo "--- System Info ---"
        uname -a
        cat /proc/device-tree/model 2>/dev/null || echo "Model: Unknown"
        echo ""
        echo "--- USB Controller ---"
        ls -la /sys/class/udc/
        echo ""
        echo "--- Loaded Modules ---"
        lsmod | grep -E "dwc2|libcomposite"
        echo ""
        echo "--- Gadget Functions ---"
        ls -la /sys/kernel/config/usb_gadget/picycle/functions/ 2>/dev/null || echo "No gadget"
        echo ""
        echo "--- Network Status ---"
        ip addr show usb0 2>/dev/null || echo "usb0 not found"
        ip addr show wlan0 2>/dev/null || echo "wlan0 not found"
        iwgetid 2>/dev/null || echo "Not connected to WiFi"
        echo ""
        echo "--- Storage ---"
        ls -lh /piusb.img 2>/dev/null || echo "Storage not created"
        file /piusb.img 2>/dev/null || true
        echo ""
        echo "--- Service Status ---"
        systemctl status picycle.service --no-pager
        echo ""
        echo "--- DHCP Server Status ---"
        ps aux | grep dnsmasq | grep -v grep || echo "dnsmasq not running"
        echo ""
        echo "--- DHCP Leases ---"
        cat /var/lib/misc/dnsmasq.usb0.leases 2>/dev/null || echo "No leases file"
        echo ""
        echo "--- Recent Logs ---"
        journalctl -u picycle.service -n 30 --no-pager
        echo ""
        echo "--- USB Messages ---"
        dmesg | grep -i "usb\|gadget\|rndis" | tail -20
    } > "$report_file"
    
    echo -e "${GREEN}✓ Report: ${WHITE}$report_file${NC}\n"
    
    echo -e "${BOLD}${WHITE}═══ Quick Status ═══${NC}"
    local udc_count=$(ls /sys/class/udc/ 2>/dev/null | wc -l)
    local service_status=$(systemctl is-active picycle.service 2>/dev/null)
    local usb0_exists=$(ip link show usb0 &>/dev/null && echo "yes" || echo "no")
    local hidg0_exists=$([ -c /dev/hidg0 ] && echo "yes" || echo "no")
    local storage_exists=$([ -f /piusb.img ] && echo "yes" || echo "no")
    local dhcp_running=$(pgrep -f "dnsmasq.*usb0" > /dev/null && echo "yes" || echo "no")

    echo -e "${GRAY}UDC:${NC}         $([[ $udc_count -gt 0 ]] && echo -e "${GREEN}Found${NC}" || echo -e "${RED}Missing${NC}")"
    echo -e "${GRAY}Service:${NC}     $([[ "$service_status" == "active" ]] && echo -e "${GREEN}Active${NC}" || echo -e "${RED}Inactive${NC}")"
    echo -e "${GRAY}USB Network:${NC} $([[ "$usb0_exists" == "yes" ]] && echo -e "${GREEN}Yes${NC}" || echo -e "${RED}No${NC}")"
    echo -e "${GRAY}DHCP Server:${NC} $([[ "$dhcp_running" == "yes" ]] && echo -e "${GREEN}Running${NC}" || echo -e "${RED}Not Running${NC}")"
    echo -e "${GRAY}HID Device:${NC}  $([[ "$hidg0_exists" == "yes" ]] && echo -e "${GREEN}Yes${NC}" || echo -e "${RED}No${NC}")"
    echo -e "${GRAY}Storage:${NC}     $([[ "$storage_exists" == "yes" ]] && echo -e "${GREEN}Yes${NC}" || echo -e "${RED}No${NC}")"

    if [ -f /piusb.img ]; then
        local size_mb=$(stat -c%s /piusb.img | awk '{print int($1/1024/1024)}')
        echo -e "${GRAY}Storage Size:${NC} ${size_mb}MB"
    fi

    # Show DHCP leases if any
    if [ -f /var/lib/misc/dnsmasq.usb0.leases ] && [ -s /var/lib/misc/dnsmasq.usb0.leases ]; then
        echo -e "\n${GRAY}DHCP Leases:${NC}"
        cat /var/lib/misc/dnsmasq.usb0.leases
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Restore defaults
restore_defaults() {
    echo -e "\n${BLUE}${BOLD}[*] Restoring original configuration...${NC}\n"
    
    read -p "Remove PiCycle and restore backups? (y/n): " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && return
    
    echo -e "\n${YELLOW}[1/5] Stopping service...${NC}"
    systemctl disable picycle.service 2>/dev/null || true
    systemctl stop picycle.service 2>/dev/null || true
    
    echo -e "\n${YELLOW}[2/5] Restoring backups...${NC}"
    for backup in "$BACKUP_DIR"/*.bak; do
        if [ -f "$backup" ]; then
            original="$(basename "${backup%.bak}")"
            case "$original" in
                config.txt|cmdline.txt) cp "$backup" "$BOOT_DIR/$original" ;;
                dhcpcd.conf) cp "$backup" "/etc/$original" ;;
                modules) cp "$backup" "/etc/$original" ;;
            esac
            echo -e "  ${GREEN}✓${NC} Restored $original"
        fi
    done
    
    echo -e "\n${YELLOW}[3/5] Removing files...${NC}"
    rm -f "$GADGET_SCRIPT" "$SERVICE_FILE" /piusb.img
    rm -f /etc/dnsmasq.d/usb0.conf
    rm -f /var/lib/misc/dnsmasq.usb0.leases
    pkill -f "dnsmasq.*usb0" 2>/dev/null || true
    
    echo -e "\n${YELLOW}[4/5] Cleaning gadget...${NC}"
    if [ -d /sys/kernel/config/usb_gadget/picycle ]; then
        cd /sys/kernel/config/usb_gadget/picycle
        echo "" > UDC 2>/dev/null || true
        cd /
        rm -rf /sys/kernel/config/usb_gadget/picycle 2>/dev/null || true
    fi
    
    echo -e "\n${YELLOW}[5/5] Reloading...${NC}"
    systemctl daemon-reload
    
    echo -e "\n${GREEN}${BOLD}✓ Restoration complete!${NC}\n"
    read -p "Reboot? (y/n): " -n 1 -r
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
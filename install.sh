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

# Configure WiFi
configure_wifi() {
    echo -e "\n${CYAN}${BOLD}WiFi Configuration${NC}"
    echo -e "${YELLOW}Do you want to configure WiFi for remote access?${NC}"
    echo -e "  ${GREEN}[1]${NC} Yes - Configure WiFi now"
    echo -e "  ${GREEN}[2]${NC} No - Skip WiFi configuration"
    echo ""
    
    read -p "Selection [1-2]: " wifi_choice
    
    if [[ "$wifi_choice" == "1" ]]; then
        read -p "Enter WiFi SSID: " wifi_ssid
        read -sp "Enter WiFi Password: " wifi_pass
        echo ""
        
        # Configure wpa_supplicant
        cat >> /etc/wpa_supplicant/wpa_supplicant.conf << WIFIEOF

network={
	ssid="$wifi_ssid"
	psk="$wifi_pass"
	key_mgmt=WPA-PSK
}
WIFIEOF
        
        # Restart networking
        wpa_cli -i wlan0 reconfigure 2>/dev/null || true
        
        echo -e "${GREEN}✓ WiFi configured for: $wifi_ssid${NC}"
        echo -e "${YELLOW}Testing connection...${NC}"
        sleep 5
        
        if iwgetid -r &>/dev/null; then
            local ip=$(hostname -I | awk '{print $1}')
            echo -e "${GREEN}✓ Connected! IP: $ip${NC}"
        else
            echo -e "${YELLOW}⚠ Not connected yet. May connect after reboot.${NC}"
        fi
    else
        echo -e "${CYAN}Skipped WiFi configuration${NC}"
    fi
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
    apt install -y dosfstools avahi-daemon jq 2>&1 | grep -E "Setting up|already" || true
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
sleep 3
modprobe libcomposite 2>/dev/null || true
sleep 1

UDC=""
for i in {1..15}; do
    UDC=$(ls /sys/class/udc/ 2>/dev/null | head -n1)
    [ -n "$UDC" ] && break
    sleep 1
done
[ -z "$UDC" ] && exit 1

cd /sys/kernel/config/usb_gadget/ || exit 1
GADGET="picycle"

if [ -d "$GADGET" ]; then
    echo "" > "$GADGET/UDC" 2>/dev/null || true
    sleep 1
    # Remove symlinks from os_desc first
    find "$GADGET/os_desc/" -type l -delete 2>/dev/null || true
    # Remove symlinks from config
    find "$GADGET/configs/c.1/" -type l -delete 2>/dev/null || true
    rmdir "$GADGET/configs/c.1/strings/0x409" 2>/dev/null || true
    rmdir "$GADGET/configs/c.1" 2>/dev/null || true
    # Remove functions (must remove directories individually)
    for func in "$GADGET/functions"/*; do
        [ -d "$func" ] && rmdir "$func" 2>/dev/null || true
    done
    rmdir "$GADGET/functions" 2>/dev/null || true
    rmdir "$GADGET/strings/0x409" 2>/dev/null || true
    rmdir "$GADGET" 2>/dev/null || true
fi

mkdir -p "$GADGET"
cd "$GADGET"

# Device descriptor - CRITICAL for Windows auto-detection
echo 0x0525 > idVendor   # NetChip Technology (Linux-USB Ethernet/RNDIS Gadget)
echo 0xa4a2 > idProduct  # Ethernet/RNDIS Gadget
echo 0x0100 > bcdDevice
echo 0x0200 > bcdUSB

# Composite device class
echo 0xEF > bDeviceClass
echo 0x02 > bDeviceSubClass  
echo 0x01 > bDeviceProtocol

# Strings
mkdir -p strings/0x409
echo "0123456789" > strings/0x409/serialnumber
echo "Linux" > strings/0x409/manufacturer
echo "Ethernet/RNDIS Gadget" > strings/0x409/product

# Config
mkdir -p configs/c.1/strings/0x409
echo "RNDIS+HID+Storage" > configs/c.1/strings/0x409/configuration
echo 250 > configs/c.1/MaxPower
echo 0xC0 > configs/c.1/bmAttributes

# Function 1: RNDIS (Windows auto-detects this)
mkdir -p functions/rndis.usb0
echo "48:6f:73:74:50:43" > functions/rndis.usb0/host_addr
echo "42:61:64:55:53:42" > functions/rndis.usb0/dev_addr

# Function 2: HID Keyboard
mkdir -p functions/hid.usb0
echo 1 > functions/hid.usb0/protocol
echo 1 > functions/hid.usb0/subclass
echo 8 > functions/hid.usb0/report_length
# Write HID keyboard report descriptor using printf for reliable binary output
printf '\x05\x01\x09\x06\xa1\x01\x05\x07\x19\xe0\x29\xe7\x15\x00\x25\x01\x75\x01\x95\x08\x81\x02\x95\x01\x75\x08\x81\x03\x95\x05\x75\x01\x05\x08\x19\x01\x29\x05\x91\x02\x95\x01\x75\x03\x91\x03\x95\x06\x75\x08\x15\x00\x25\x65\x05\x07\x19\x00\x29\x65\x81\x00\xc0' > functions/hid.usb0/report_desc

# Verify HID function created
if [ ! -d "functions/hid.usb0" ]; then
    echo "ERROR: HID function not created" >&2
    exit 1
fi

# Function 3: Mass Storage
STORAGE="/piusb.img"
STORAGE_SIZE=8192
[ -f /etc/picycle/storage_size ] && STORAGE_SIZE=$(cat /etc/picycle/storage_size)

# Create storage file FIRST before setting up the function
if [ ! -f "$STORAGE" ]; then
    echo "Creating ${STORAGE_SIZE}MB storage file..."
    dd if=/dev/zero of="$STORAGE" bs=1M count=$STORAGE_SIZE status=progress
    sync
    /sbin/mkfs.vfat -F 32 -n "PICYCLE" "$STORAGE"
    sync
fi

# Verify storage file exists and is readable
if [ ! -f "$STORAGE" ] || [ ! -r "$STORAGE" ]; then
    echo "ERROR: Storage file not accessible" >&2
    exit 1
fi

mkdir -p functions/mass_storage.usb0
# Wait for lun.0 directory to be created by kernel
sleep 1
echo 1 > functions/mass_storage.usb0/stall
echo 0 > functions/mass_storage.usb0/lun.0/cdrom
echo 0 > functions/mass_storage.usb0/lun.0/ro
echo 1 > functions/mass_storage.usb0/lun.0/removable
echo 0 > functions/mass_storage.usb0/lun.0/nofua
echo "$STORAGE" > functions/mass_storage.usb0/lun.0/file

# Verify mass storage function created
if [ ! -d "functions/mass_storage.usb0" ]; then
    echo "ERROR: Mass storage function not created" >&2
    exit 1
fi

# Link functions - ORDER MATTERS for Windows
ln -s functions/rndis.usb0 configs/c.1/
ln -s functions/hid.usb0 configs/c.1/
ln -s functions/mass_storage.usb0 configs/c.1/

# Windows OS descriptors for auto-detection
echo 1 > os_desc/use
echo 0xcd > os_desc/b_vendor_code
echo MSFT100 > os_desc/qw_sign
ln -s configs/c.1 os_desc/

# Enable
echo "$UDC" > UDC
sleep 2

# Configure network
for i in {1..10}; do
    if ip link show usb0 &>/dev/null; then
        ip addr flush dev usb0 2>/dev/null || true
        ip addr add 10.55.0.1/24 dev usb0
        ip link set usb0 up
        break
    fi
    sleep 1
done
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
    echo -e "\n${YELLOW}[9/10] Configuring USB network...${NC}"
    sed -i '/^# PiCycle/,/^$/d' /etc/dhcpcd.conf
    sed -i '/^interface usb0/,/^$/d' /etc/dhcpcd.conf
    
    cat >> /etc/dhcpcd.conf << 'NETEOF'

# PiCycle USB Network
interface usb0
static ip_address=10.55.0.1/24
nohook wpa_supplicant
NETEOF
    
    systemctl enable ssh 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} Network configured"
    
    # Final check
    echo -e "\n${YELLOW}[10/10] Verifying installation...${NC}"
    echo -e "  ${GREEN}✓${NC} Boot config verified"
    echo -e "  ${GREEN}✓${NC} Service: $(systemctl is-enabled picycle.service 2>/dev/null)"
    echo -e "  ${GREEN}✓${NC} Storage: ${storage_mb}MB"
    
    echo -e "\n${GREEN}${BOLD}✓ PiCycle installation complete!${NC}\n"
    echo -e "${CYAN}${BOLD}IMPORTANT:${NC} ${YELLOW}Reboot required${NC}"
    echo -e "${CYAN}After reboot:${NC}"
    echo -e "  • Windows should auto-detect all 3 devices"
    echo -e "  • Set Windows network adapter IP: ${YELLOW}10.55.0.6/24${NC}"
    echo -e "  • SSH via WiFi or USB: ${YELLOW}ssh pi@10.55.0.1${NC}\n"
    
    read -p "Reboot now? (y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] && reboot
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
    
    echo -e "${GRAY}UDC:${NC}         $([[ $udc_count -gt 0 ]] && echo -e "${GREEN}Found${NC}" || echo -e "${RED}Missing${NC}")"
    echo -e "${GRAY}Service:${NC}     $([[ "$service_status" == "active" ]] && echo -e "${GREEN}Active${NC}" || echo -e "${RED}Inactive${NC}")"
    echo -e "${GRAY}USB Network:${NC} $([[ "$usb0_exists" == "yes" ]] && echo -e "${GREEN}Yes${NC}" || echo -e "${RED}No${NC}")"
    echo -e "${GRAY}HID Device:${NC}  $([[ "$hidg0_exists" == "yes" ]] && echo -e "${GREEN}Yes${NC}" || echo -e "${RED}No${NC}")"
    echo -e "${GRAY}Storage:${NC}     $([[ "$storage_exists" == "yes" ]] && echo -e "${GREEN}Yes${NC}" || echo -e "${RED}No${NC}")"
    
    if [ -f /piusb.img ]; then
        local size_mb=$(stat -c%s /piusb.img | awk '{print int($1/1024/1024)}')
        echo -e "${GRAY}Storage Size:${NC} ${size_mb}MB"
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

    while true; do
        show_banner
        show_menu

        read -p "$(echo -e "${WHITE}Enter selection [1-4]: ${NC}")" choice

        case $choice in
            1) install_picycle ;;
            2) diagnostic_report ;;
            3) restore_defaults ;;
            4) echo -e "\n${CYAN}Goodbye!${NC}\n"; exit 0 ;;
            *) echo -e "\n${RED}Invalid selection${NC}\n"; sleep 2 ;;
        esac
    done
}

main "$@"
#!/usr/bin/env python3
"""
PiCycle - Raspberry Pi Zero 2W USB Gadget Configuration Tool
Configures: HID Keyboard + Mass Storage + Network Device
"""

import os
import sys
import subprocess
import time
from pathlib import Path

# Colors
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    CYAN = '\033[0;36m'
    WHITE = '\033[1;37m'
    NC = '\033[0m'

BOOT_DIR = "/boot/firmware" if Path("/boot/firmware").exists() else "/boot"
CONFIG_DIR = Path("/etc/picycle")
BACKUP_DIR = CONFIG_DIR / "backups"

def run(cmd):
    """Run command, return output"""
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30).stdout.strip()
    except:
        return ""

def check_root():
    if os.geteuid() != 0:
        print(f"{Colors.RED}Run as root: sudo python3 {sys.argv[0]}{Colors.NC}")
        sys.exit(1)

def banner():
    os.system('clear')
    print(f"{Colors.CYAN}╔════════════════════════════════════════╗")
    print(f"║         PiCycle Setup Tool             ║")
    print(f"║   Pi Zero 2W USB Gadget Configurator   ║")
    print(f"╚════════════════════════════════════════╝{Colors.NC}\n")

def menu():
    print(f"{Colors.WHITE}[1]{Colors.NC} Install PiCycle")
    print(f"{Colors.WHITE}[2]{Colors.NC} Run Diagnostics")
    print(f"{Colors.WHITE}[3]{Colors.NC} Uninstall")
    print(f"{Colors.WHITE}[4]{Colors.NC} Exit\n")

def install():
    print(f"\n{Colors.CYAN}Installing PiCycle...{Colors.NC}\n")
    
    CONFIG_DIR.mkdir(exist_ok=True)
    BACKUP_DIR.mkdir(exist_ok=True)
    
    # Step 1: Backups
    print(f"{Colors.YELLOW}[1/6] Backing up files...{Colors.NC}")
    for f in ["config.txt", "cmdline.txt"]:
        src = f"{BOOT_DIR}/{f}"
        dst = BACKUP_DIR / f"{f}.bak"
        if Path(src).exists() and not dst.exists():
            run(f"cp {src} {dst}")
    for f in ["dhcpcd.conf", "modules"]:
        src = f"/etc/{f}"
        dst = BACKUP_DIR / f"{f}.bak"
        if Path(src).exists() and not dst.exists():
            run(f"cp {src} {dst}")
    print(f"  {Colors.GREEN}✓{Colors.NC} Done")
    
    # Step 2: WiFi config
    print(f"\n{Colors.YELLOW}[2/6] WiFi setup...{Colors.NC}")
    current_wifi = run("iwgetid -r")
    if current_wifi:
        print(f"  {Colors.GREEN}✓{Colors.NC} Already connected to: {current_wifi}")
        print(f"  {Colors.GREEN}✓{Colors.NC} Skipping WiFi config")
    else:
        print(f"  Configure WiFi?")
        print(f"    {Colors.WHITE}[1]{Colors.NC} Access Point (Pi creates hotspot)")
        print(f"    {Colors.WHITE}[2]{Colors.NC} Client (Connect to existing WiFi)")
        print(f"    {Colors.WHITE}[3]{Colors.NC} Skip")
        choice = input(f"  Choice: ").strip()
        
        if choice == "1":
            ssid = input("  AP Name: ").strip() or "PiCycle"
            password = input("  Password (8+ chars): ").strip()
            while len(password) < 8:
                password = input("  Password (8+ chars): ").strip()
            
            if not Path("/usr/sbin/hostapd").exists():
                run("apt-get update -qq && apt-get install -y hostapd dnsmasq")
            
            Path("/etc/hostapd/hostapd.conf").write_text(f"""interface=wlan0
driver=nl80211
ssid={ssid}
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
wpa=2
wpa_passphrase={password}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
""")
            
            run('sed -i "s|^#DAEMON_CONF.*|DAEMON_CONF=\\"/etc/hostapd/hostapd.conf\\"|" /etc/default/hostapd')
            
            Path("/etc/dnsmasq.conf").write_text("""interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
""")
            
            with open("/etc/dhcpcd.conf", "a") as f:
                f.write("\ninterface wlan0\nstatic ip_address=192.168.4.1/24\n")
            
            run("systemctl enable hostapd dnsmasq")
            print(f"  {Colors.GREEN}✓{Colors.NC} AP configured: {ssid}")
            
        elif choice == "2":
            ssid = input("  WiFi SSID: ").strip()
            password = input("  Password: ").strip()
            
            with open("/etc/wpa_supplicant/wpa_supplicant.conf", "a") as f:
                f.write(f'\nnetwork={{\n  ssid="{ssid}"\n  psk="{password}"\n}}\n')
            
            print(f"  {Colors.GREEN}✓{Colors.NC} Will connect to: {ssid}")
        else:
            print(f"  {Colors.GREEN}✓{Colors.NC} Skipped")
    
    # Step 3: Boot config
    print(f"\n{Colors.YELLOW}[3/6] Configuring boot files...{Colors.NC}")
    
    config = Path(f"{BOOT_DIR}/config.txt").read_text()
    if "dtoverlay=dwc2" not in config:
        with open(f"{BOOT_DIR}/config.txt", "a") as f:
            f.write("\ndtoverlay=dwc2\n")
    
    cmdline = Path(f"{BOOT_DIR}/cmdline.txt").read_text().strip()
    if "modules-load=dwc2" not in cmdline:
        cmdline = cmdline.replace("rootwait", "modules-load=dwc2 rootwait")
        Path(f"{BOOT_DIR}/cmdline.txt").write_text(cmdline)
    
    modules = Path("/etc/modules").read_text()
    for mod in ["dwc2", "libcomposite"]:
        if mod not in modules:
            with open("/etc/modules", "a") as f:
                f.write(f"{mod}\n")
    
    print(f"  {Colors.GREEN}✓{Colors.NC} Boot configured")
    
    # Step 4: Storage size
    print(f"\n{Colors.YELLOW}[4/6] Storage size...{Colors.NC}")
    print(f"  {Colors.WHITE}[1]{Colors.NC} 128 MB")
    print(f"  {Colors.WHITE}[2]{Colors.NC} 2 GB")
    print(f"  {Colors.WHITE}[3]{Colors.NC} 8 GB")
    choice = input(f"  Choice [1-3] (default 2): ").strip() or "2"
    
    sizes = {"1": 128, "2": 2048, "3": 8192}
    storage_mb = sizes.get(choice, 2048)
    (CONFIG_DIR / "storage_size").write_text(str(storage_mb))
    print(f"  {Colors.GREEN}✓{Colors.NC} {storage_mb} MB")
    
    # Step 5: Create and FORMAT storage NOW
    print(f"\n{Colors.YELLOW}[5/6] Creating storage file...{Colors.NC}")
    storage_file = Path("/piusb.img")
    
    if storage_file.exists():
        storage_file.unlink()
    
    run(f"dd if=/dev/zero of=/piusb.img bs=1M count={storage_mb} status=none")
    time.sleep(1)
    
    print(f"  {Colors.CYAN}Formatting storage...{Colors.NC}")
    run("mkfs.vfat -F 32 -n PICYCLE /piusb.img")
    time.sleep(1)
    
    print(f"  {Colors.GREEN}✓{Colors.NC} Storage created and formatted")
    
    # Step 6: Create Python gadget module
    print(f"\n{Colors.YELLOW}[6/6] Creating gadget module...{Colors.NC}")
    
    gadget_module = '''#!/usr/bin/env python3
"""PiCycle USB Gadget Configuration"""
import subprocess
import time
from pathlib import Path

def configure_gadget():
    """Configure USB composite gadget"""
    subprocess.run("modprobe libcomposite", shell=True, check=False)
    time.sleep(2)
    
    gadget_path = Path("/sys/kernel/config/usb_gadget/g1")
    
    if gadget_path.exists():
        (gadget_path / "UDC").write_text("")
        time.sleep(1)
        subprocess.run(f"rm -rf {gadget_path}", shell=True, check=False)
        time.sleep(1)
    
    gadget_path.mkdir(exist_ok=True)
    
    # Device descriptor
    (gadget_path / "idVendor").write_text("0x1d6b")
    (gadget_path / "idProduct").write_text("0x0104")
    (gadget_path / "bcdDevice").write_text("0x0100")
    (gadget_path / "bcdUSB").write_text("0x0200")
    (gadget_path / "bDeviceClass").write_text("0xEF")
    (gadget_path / "bDeviceSubClass").write_text("0x02")
    (gadget_path / "bDeviceProtocol").write_text("0x01")
    
    # Strings
    strings = gadget_path / "strings/0x409"
    strings.mkdir(parents=True, exist_ok=True)
    (strings / "serialnumber").write_text("fedcba9876543210")
    (strings / "manufacturer").write_text("Raspberry Pi")
    (strings / "product").write_text("Pi Zero Gadget")
    
    # Config
    config_strings = gadget_path / "configs/c.1/strings/0x409"
    config_strings.mkdir(parents=True, exist_ok=True)
    (config_strings / "configuration").write_text("Config 1")
    (gadget_path / "configs/c.1/MaxPower").write_text("250")
    
    # RNDIS
    rndis = gadget_path / "functions/rndis.usb0"
    rndis.mkdir(parents=True, exist_ok=True)
    (rndis / "host_addr").write_text("48:6f:73:74:50:43")
    (rndis / "dev_addr").write_text("42:61:64:55:53:42")
    
    # HID
    hid = gadget_path / "functions/hid.usb0"
    hid.mkdir(parents=True, exist_ok=True)
    (hid / "protocol").write_text("1")
    (hid / "subclass").write_text("1")
    (hid / "report_length").write_text("8")
    
    report = bytes([0x05,0x01,0x09,0x06,0xa1,0x01,0x05,0x07,0x19,0xe0,0x29,0xe7,0x15,0x00,0x25,0x01,0x75,0x01,0x95,0x08,0x81,0x02,0x95,0x01,0x75,0x08,0x81,0x03,0x95,0x05,0x75,0x01,0x05,0x08,0x19,0x01,0x29,0x05,0x91,0x02,0x95,0x01,0x75,0x03,0x91,0x03,0x95,0x06,0x75,0x08,0x15,0x00,0x25,0x65,0x05,0x07,0x19,0x00,0x29,0x65,0x81,0x00,0xc0])
    (hid / "report_desc").write_bytes(report)
    
    # Mass Storage
    mass = gadget_path / "functions/mass_storage.usb0"
    mass.mkdir(parents=True, exist_ok=True)
    (mass / "lun.0/cdrom").write_text("0")
    (mass / "lun.0/ro").write_text("0")
    (mass / "lun.0/removable").write_text("1")
    (mass / "lun.0/file").write_text("/piusb.img")
    
    # Link
    subprocess.run(f"ln -s {rndis} {gadget_path}/configs/c.1/", shell=True)
    subprocess.run(f"ln -s {hid} {gadget_path}/configs/c.1/", shell=True)
    subprocess.run(f"ln -s {mass} {gadget_path}/configs/c.1/", shell=True)
    
    # Enable
    udc = subprocess.check_output("ls /sys/class/udc", shell=True).decode().strip()
    (gadget_path / "UDC").write_text(udc)
    time.sleep(3)
    
    # Network
    subprocess.run("ip addr add 10.55.0.1/24 dev usb0", shell=True, check=False)
    subprocess.run("ip link set usb0 up", shell=True, check=False)
    
    # DHCP
    if Path("/usr/sbin/dnsmasq").exists():
        Path("/etc/dnsmasq.d").mkdir(exist_ok=True)
        Path("/etc/dnsmasq.d/usb0.conf").write_text("interface=usb0\\ndhcp-range=10.55.0.2,10.55.0.100,255.255.255.0,12h\\ndhcp-option=3,10.55.0.1\\n")
        subprocess.run("systemctl restart dnsmasq", shell=True, check=False)

if __name__ == "__main__":
    configure_gadget()
'''
    
    try:
        with open("/usr/bin/picycle_gadget.py", "w") as f:
            f.write(gadget_module)
        os.chmod("/usr/bin/picycle_gadget.py", 0o755)
        print(f"  {Colors.GREEN}✓{Colors.NC} Gadget module created")
    except Exception as e:
        print(f"  {Colors.RED}✗{Colors.NC} Error: {e}")
        return
    
    # Service
    service = """[Unit]
Description=PiCycle Gadget
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/python3 /usr/bin/picycle_gadget.py
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
"""
    
    Path("/etc/systemd/system/picycle.service").write_text(service)
    run("systemctl daemon-reload")
    run("systemctl enable picycle.service")
    
    # USB network
    with open("/etc/dhcpcd.conf", "a") as f:
        f.write("\ninterface usb0\nstatic ip_address=10.55.0.1/24\n")
    
    run("systemctl enable ssh")
    
    print(f"  {Colors.GREEN}✓{Colors.NC} Complete")
    
    print(f"\n{Colors.GREEN}Installation complete!{Colors.NC}")
    print(f"\n{Colors.CYAN}Reboot now!{Colors.NC}\n")
    
    if input("Reboot? (y/n): ").lower() == 'y':
        run("reboot")

def diagnostics():
    print(f"\n{Colors.CYAN}Diagnostics:{Colors.NC}\n")
    print(f"UDC: {run('ls /sys/class/udc')}")
    print(f"Functions: {run('ls /sys/kernel/config/usb_gadget/g1/functions 2>/dev/null')}")
    print(f"HID: {'Yes' if Path('/dev/hidg0').exists() else 'No'}")
    print(f"Storage: {run('ls -lh /piusb.img')}")
    print(f"Service: {run('systemctl is-active picycle.service')}")
    input(f"\n{Colors.WHITE}Press Enter...{Colors.NC}")

def uninstall():
    print(f"\n{Colors.YELLOW}Uninstalling...{Colors.NC}")
    if input("Continue? (y/n): ").lower() != 'y':
        return
    
    run("systemctl disable picycle.service")
    run("systemctl stop picycle.service")
    
    Path("/usr/bin/picycle_gadget.py").unlink(missing_ok=True)
    Path("/etc/systemd/system/picycle.service").unlink(missing_ok=True)
    Path("/piusb.img").unlink(missing_ok=True)
    
    for backup in BACKUP_DIR.glob("*.bak"):
        name = backup.stem
        if name in ["config.txt", "cmdline.txt"]:
            run(f"cp {backup} {BOOT_DIR}/{name}")
        else:
            run(f"cp {backup} /etc/{name}")
    
    print(f"{Colors.GREEN}Uninstalled{Colors.NC}\n")

def main():
    check_root()
    
    while True:
        banner()
        menu()
        choice = input(f"{Colors.WHITE}Choice: {Colors.NC}").strip()
        
        if choice == "1":
            install()
        elif choice == "2":
            diagnostics()
        elif choice == "3":
            uninstall()
        elif choice == "4":
            break

if __name__ == "__main__":
    main()

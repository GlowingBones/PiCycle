<!--
PiCycle README
Style notes:
- Keep relative paths so GitHub renders assets correctly.
- Avoid overly long lines where practical.
-->

<p align="center">
  <img src="assets/images/picycle.png" alt="PiCycle" width="360">
</p>

<h1 align="center">PiCycle</h1>

<p align="center">
  Raspberry Pi Zero 2 W USB gadget: HID keyboard, mass storage, and a USB network interface at the same time.
</p>

<p align="center">
  <strong><B>Status:</B></strong> work in progress. Expect breaking changes.
</p>

## What it does

PiCycle configures a Raspberry Pi Zero 2 W to present multiple USB functions concurrently:

- HID keyboard (for scripted keystrokes)
- Mass storage (exposed over USB)
- USB Ethernet (network emulator) with a local web interface

## Hardware

- Raspberry Pi Zero 2 W: https://a.co/d/dgyNJGX
- USB Dongle Expansion Board with Case: https://a.co/d/4QbcUZW
- microSD (TF) card, 64 GB recommended: https://a.co/d/89mxLgg

## Software

- Raspberry Pi OS Lite (64-bit)

## Install

1. Flash Raspberry Pi OS Lite (64-bit) to the microSD (TF) card.
2. Boot the Pi and log in.
3. From your home directory, run:

```bash
sudo raspi-config nonint do_expand_rootfs
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y git
git clone --recursive https://github.com/GlowingBones/PiCycle.git
cd PiCycle
sudo bash ./install.sh
```

4. When prompted to reboot, select **Yes**.

## Connect

PiCycle provides two ways to reach the web interface:

### Option A: USB network (recommended)

Using the USB dongle expansion board, plug the PiCycle device directly into your computer's USB port.

Open:

- http://10.55.0.1/

### Option B: WiFi access point

Connect to SSID `PiCycle`, then open:

- http://192.168.4.1

## Safety and legal

PiCycle can generate HID keystrokes. Use only on systems you own or have explicit permission to test. Review and validate any automation before running it.

## License

See the repository for licensing information.

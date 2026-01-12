# PiCycle 

Currently a work in progress and not fully functional.

<center><img style="width: 25%; height: 25%;" alt="PiCycle" src="https://raw.githubusercontent.com/GlowingBones/PiCycle/refs/heads/main/assets/images/picycle.png"></center>

PiCycle (Raspberry Pi Zero 2W as a HID keyboard, Mass storage device, and Network emulator all at the same time) is not only a nifty little tool, but is is also a proff of concept that even a horrible coder such as myself can leveage AI with plain language articulated dirrections and a bit of swearing to acomplish useful application code.

To build this project you will need:
  ⦁	Pi Zero 2 WH-Pi Zero 2 W (https://a.co/d/dgyNJGX)
  ⦁	USB Dongle Expansion Board with Case (https://a.co/d/4QbcUZW)
  ⦁	TF Card 64GB with Adapter, High Speed Memory Card, UHS-I C10 A1 (https://a.co/d/89mxLgg)

Step by Step installation:

  install Pi OS on TF card

  from your ~ directory do the following

  sudo raspi-config nonint do_expand_rootfs

  sudo apt-get install git -y

  sudo apt-get update && sudo apt-get upgrade -y

  git clone --recursive https://github.com/GlowingBones/PiCycle.git

  cd PiCycle

  sudo bash ./install.sh

  When asked enter and confirm wifi AP password.

  Click yes when asked to reboot.

After the Pi has rebooted open your browser to http://10.55.0.1/ via the emulated USB network or connect to SSID PiCycle and open your browser to http://192.168.?.?
  


# PiCycle 

Currently a work in progress and not fully functional.

<center><img style="width: 25%; height: 25%;" alt="PiCycle" src="https://raw.githubusercontent.com/GlowingBones/PiCycle/refs/heads/main/assets/images/picycle.png"></center>

PiCycle (Raspberry Pi Zero 2W as a HID keyboard, Mass storage device, and Network emulator all at the same time) is not only a nifty little tool, but is is also a proff of concept that even a horrible coder such as myself can leveage AI with plain language articulated dirrections and a bit of swearing to acomplish useful application code.

<B>To build this project you will need:</B> <BR>
  ⦁	Pi Zero 2 WH-Pi Zero 2 W (https://a.co/d/dgyNJGX)<BR>
  ⦁	USB Dongle Expansion Board with Case (https://a.co/d/4QbcUZW)<BR>
  ⦁	TF Card 64GB with Adapter, High Speed Memory Card, UHS-I C10 A1 (https://a.co/d/89mxLgg)<BR>

<B>Step by Step installation:</B><BR>
⦁	  install Raspberry Pi OS Lite (64-bit) on TF card<BR>
⦁	  from your ~ directory do the following<BR>
⦁	  sudo raspi-config nonint do_expand_rootfs<BR>
⦁	  sudo apt-get install git -y<BR>
⦁	  sudo apt-get update && sudo apt-get upgrade -y<BR>
⦁	  git clone --recursive https://github.com/GlowingBones/PiCycle.git<BR>
⦁	  cd PiCycle<BR>
⦁	  sudo bash ./install.sh<BR>
⦁	  When asked enter and confirm wifi AP password.<BR>
⦁	  Click yes when asked to reboot.<BR>


After the Pi has rebooted open your browser to http://10.55.0.1/ via the emulated USB network or connect to SSID PiCycle and open your browser to http://192.168.4.1
  


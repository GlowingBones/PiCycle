#!/usr/bin/env python3
"""
PiCycle HID Keyboard Tester - DuckyScript Compatible
Interactive tool to send keystrokes via USB HID
"""

import sys
import time
import os

HID_DEVICE = "/dev/hidg0"

# Modifier keys (byte 0)
MODIFIERS = {
    'ctrl': 0x01, 'shift': 0x02, 'alt': 0x04, 'gui': 0x08,
    'right_ctrl': 0x10, 'right_shift': 0x20, 'right_alt': 0x40, 'right_gui': 0x80
}

# Keycodes (bytes 2-7)
KEYCODES = {
    'a': 0x04, 'b': 0x05, 'c': 0x06, 'd': 0x07, 'e': 0x08, 'f': 0x09,
    'g': 0x0a, 'h': 0x0b, 'i': 0x0c, 'j': 0x0d, 'k': 0x0e, 'l': 0x0f,
    'm': 0x10, 'n': 0x11, 'o': 0x12, 'p': 0x13, 'q': 0x14, 'r': 0x15,
    's': 0x16, 't': 0x17, 'u': 0x18, 'v': 0x19, 'w': 0x1a, 'x': 0x1b,
    'y': 0x1c, 'z': 0x1d,
    '1': 0x1e, '2': 0x1f, '3': 0x20, '4': 0x21, '5': 0x22,
    '6': 0x23, '7': 0x24, '8': 0x25, '9': 0x26, '0': 0x27,
    'enter': 0x28, 'esc': 0x29, 'backspace': 0x2a, 'tab': 0x2b,
    'space': 0x2c, '-': 0x2d, '=': 0x2e, '[': 0x2f, ']': 0x30,
    '\\': 0x31, ';': 0x33, "'": 0x34, '`': 0x35, ',': 0x36,
    '.': 0x37, '/': 0x38, 'caps': 0x39,
    'f1': 0x3a, 'f2': 0x3b, 'f3': 0x3c, 'f4': 0x3d, 'f5': 0x3e,
    'f6': 0x3f, 'f7': 0x40, 'f8': 0x41, 'f9': 0x42, 'f10': 0x43,
    'f11': 0x44, 'f12': 0x45, 'print': 0x46, 'scroll': 0x47,
    'pause': 0x48, 'insert': 0x49, 'home': 0x4a, 'pageup': 0x4b,
    'delete': 0x4c, 'end': 0x4d, 'pagedown': 0x4e,
    'right': 0x4f, 'left': 0x50, 'down': 0x51, 'up': 0x52
}

# Characters that need shift
SHIFT_MAP = {
    '!': '1', '@': '2', '#': '3', '$': '4', '%': '5', '^': '6',
    '&': '7', '*': '8', '(': '9', ')': '0', '_': '-', '+': '=',
    '{': '[', '}': ']', '|': '\\', ':': ';', '"': "'",
    '<': ',', '>': '.', '?': '/', '~': '`'
}


class HIDKeyboard:
    """USB HID Keyboard interface"""
    
    def __init__(self, device=HID_DEVICE):
        self.device = device
        if not os.path.exists(device):
            raise FileNotFoundError(f"HID device not found: {device}")
        if not os.access(device, os.W_OK):
            raise PermissionError(f"No write permission. Run with sudo.")
    
    def send_report(self, modifier, keycode):
        """Send raw 8-byte HID report"""
        report = bytes([modifier, 0, keycode, 0, 0, 0, 0, 0])
        with open(self.device, 'rb+') as hid:
            hid.write(report)
    
    def release_all(self):
        """Release all keys"""
        self.send_report(0, 0)
    
    def press_key(self, key, modifier=0, duration=0.05):
        """Press and release a key"""
        key_lower = key.lower()
        
        # Handle shifted characters
        if key in SHIFT_MAP:
            modifier |= MODIFIERS['shift']
            key_lower = SHIFT_MAP[key]
        # Handle uppercase letters
        elif key.isupper() and len(key) == 1:
            modifier |= MODIFIERS['shift']
            key_lower = key.lower()
        
        if key_lower not in KEYCODES:
            print(f"Warning: Unknown key '{key}'")
            return
        
        keycode = KEYCODES[key_lower]
        
        # Press
        self.send_report(modifier, keycode)
        time.sleep(duration)
        
        # Release
        self.release_all()
        time.sleep(0.01)
    
    def type_string(self, text, delay=0.05):
        """Type a string of text"""
        for char in text:
            if char == '\n':
                self.press_key('enter', duration=delay)
            else:
                self.press_key(char, duration=delay)
    
    def combo(self, *keys):
        """Press a key combination (e.g., ctrl+alt+delete)"""
        modifier = 0
        keycode = 0
        
        for key in keys:
            key_lower = key.lower()
            if key_lower in MODIFIERS:
                modifier |= MODIFIERS[key_lower]
            elif key_lower in KEYCODES:
                keycode = KEYCODES[key_lower]
        
        # Press combo
        self.send_report(modifier, keycode)
        time.sleep(0.1)
        
        # Release
        self.release_all()


def parse_duckyscript(kbd, script):
    """Parse and execute DuckyScript commands"""
    
    # DuckyScript to internal key mapping
    ducky_map = {
        'GUI': 'gui', 'WINDOWS': 'gui', 'CTRL': 'ctrl', 'CONTROL': 'ctrl',
        'SHIFT': 'shift', 'ALT': 'alt', 'ENTER': 'enter', 'ESCAPE': 'esc',
        'ESC': 'esc', 'TAB': 'tab', 'SPACE': 'space', 'BACKSPACE': 'backspace',
        'DELETE': 'delete', 'HOME': 'home', 'END': 'end', 'PAGEUP': 'pageup',
        'PAGEDOWN': 'pagedown', 'UP': 'up', 'DOWN': 'down', 'LEFT': 'left',
        'RIGHT': 'right', 'UPARROW': 'up', 'DOWNARROW': 'down',
        'LEFTARROW': 'left', 'RIGHTARROW': 'right',
        'F1': 'f1', 'F2': 'f2', 'F3': 'f3', 'F4': 'f4', 'F5': 'f5',
        'F6': 'f6', 'F7': 'f7', 'F8': 'f8', 'F9': 'f9', 'F10': 'f10',
        'F11': 'f11', 'F12': 'f12', 'CAPSLOCK': 'caps', 'PRINTSCREEN': 'print',
        'SCROLLLOCK': 'scroll', 'PAUSE': 'pause', 'INSERT': 'insert'
    }
    
    lines = script.strip().split('\n') if '\n' in script else [script]
    
    for line in lines:
        line = line.strip()
        if not line or line.startswith('#') or line.startswith('REM'):
            continue
        
        parts = line.split(None, 1)
        command = parts[0].upper()
        args = parts[1] if len(parts) > 1 else ""
        
        if command == 'STRING':
            kbd.type_string(args)
        
        elif command == 'DELAY':
            delay_ms = int(args)
            time.sleep(delay_ms / 1000.0)
        
        elif command == 'REPEAT':
            # Not implemented yet
            continue
        
        else:
            # Key press or combo
            keys = [ducky_map.get(k.upper(), k.lower()) for k in line.split()]
            if len(keys) == 1:
                kbd.press_key(keys[0])
            else:
                kbd.combo(*keys)


def print_banner():
    """Print banner"""
    print("\033[1;36m")
    print("╔══════════════════════════════════════════════════════╗")
    print("║     PiCycle HID Keyboard Tester - DuckyScript       ║")
    print("╚══════════════════════════════════════════════════════╝")
    print("\033[0m")


def print_menu():
    """Print menu"""
    print("\n\033[1;33mCommands:\033[0m")
    print("  \033[1;32mtype <text>\033[0m     - Type text string")
    print("  \033[1;32mkey <key>\033[0m       - Press single key (e.g., 'enter', 'f1')")
    print("  \033[1;32mcombo <keys>\033[0m    - Key combo (e.g., 'ctrl alt delete')")
    print("  \033[1;32mducky <cmd>\033[0m     - DuckyScript command")
    print("  \033[1;32mtest\033[0m            - Run test sequence (opens Notepad)")
    print("  \033[1;32mhelp\033[0m            - Show available keys")
    print("  \033[1;32mquit\033[0m            - Exit")
    print("\n\033[1;35mDuckyScript Examples:\033[0m")
    print("  \033[0;36mducky GUI r\033[0m              - Open Windows Run")
    print("  \033[0;36mducky STRING notepad\033[0m    - Type 'notepad'")
    print("  \033[0;36mducky ENTER\033[0m              - Press Enter")
    print("  \033[0;36mducky CTRL ALT DELETE\033[0m   - Ctrl+Alt+Del")
    print("  \033[0;36mducky DELAY 1000\033[0m        - Wait 1 second")
    print()


def show_keys():
    """Show available keys"""
    print("\n\033[1;36mAvailable Keys:\033[0m")
    print("\n\033[1mLetters:\033[0m a-z (case sensitive)")
    print("\033[1mNumbers:\033[0m 0-9")
    print("\033[1mSpecial:\033[0m enter, esc, tab, space, backspace, delete, home, end")
    print("\033[1mArrows:\033[0m up, down, left, right")
    print("\033[1mFunction:\033[0m f1-f12")
    print("\033[1mModifiers:\033[0m ctrl, shift, alt, gui (Windows key)")
    print()


def run_test(kbd):
    """Run automated test"""
    print("\n\033[1;35m[*] Running HID test sequence...\033[0m")
    
    print("  \033[1;33m→\033[0m Opening Run dialog (GUI+R)")
    kbd.combo('gui', 'r')
    time.sleep(0.5)
    
    print("  \033[1;33m→\033[0m Typing 'notepad'")
    kbd.type_string('notepad')
    
    print("  \033[1;33m→\033[0m Pressing Enter")
    kbd.press_key('enter')
    time.sleep(1.5)
    
    print("  \033[1;33m→\033[0m Typing test message")
    kbd.type_string('PiCycle HID Keyboard Test!\nAll systems operational!')
    
    print("\033[1;32m[✓] Test complete! Check Windows for Notepad window\033[0m\n")


def interactive_mode():
    """Run interactive mode"""
    print_banner()
    
    try:
        kbd = HIDKeyboard()
        print("\033[1;32m[✓] HID device ready: /dev/hidg0\033[0m")
    except FileNotFoundError:
        print(f"\033[1;31m[✗] Error: {HID_DEVICE} not found!")
        print("Make sure PiCycle is installed and running.\033[0m")
        return
    except PermissionError:
        print(f"\033[1;31m[✗] Error: Permission denied!")
        print("Run with: sudo python3 hid_test.py\033[0m")
        return
    
    print_menu()
    
    while True:
        try:
            cmd = input("\033[1;36mPiCycle>\033[0m ").strip()
            
            if not cmd:
                continue
            
            parts = cmd.split(None, 1)
            command = parts[0].lower()
            args = parts[1] if len(parts) > 1 else ""
            
            if command in ['quit', 'exit']:
                print("\033[1;33mGoodbye!\033[0m")
                break
            
            elif command == 'help':
                show_keys()
            
            elif command == 'menu':
                print_menu()
            
            elif command == 'type':
                if args:
                    print(f"\033[1;33m[→] Typing: {args}\033[0m")
                    kbd.type_string(args)
                    print("\033[1;32m[✓] Done\033[0m")
                else:
                    print("\033[1;31mUsage: type <text>\033[0m")
            
            elif command == 'key':
                if args:
                    print(f"\033[1;33m[→] Pressing: {args}\033[0m")
                    kbd.press_key(args)
                    print("\033[1;32m[✓] Done\033[0m")
                else:
                    print("\033[1;31mUsage: key <keyname>\033[0m")
            
            elif command == 'combo':
                if args:
                    keys = args.split()
                    print(f"\033[1;33m[→] Combo: {' + '.join(keys)}\033[0m")
                    kbd.combo(*keys)
                    print("\033[1;32m[✓] Done\033[0m")
                else:
                    print("\033[1;31mUsage: combo <key1> <key2> ...\033[0m")
            
            elif command == 'ducky':
                if args:
                    print(f"\033[1;33m[→] Executing DuckyScript\033[0m")
                    parse_duckyscript(kbd, args)
                    print("\033[1;32m[✓] Done\033[0m")
                else:
                    print("\033[1;31mUsage: ducky <script>\033[0m")
            
            elif command == 'test':
                run_test(kbd)
            
            else:
                print(f"\033[1;31mUnknown command: {command}\033[0m")
                print("Type 'menu' for help")
        
        except KeyboardInterrupt:
            print("\n\033[1;33mGoodbye!\033[0m")
            break
        except Exception as e:
            print(f"\033[1;31m[✗] Error: {e}\033[0m")


def main():
    """Main entry point"""
    if len(sys.argv) > 1:
        # Command line mode: quick type
        try:
            kbd = HIDKeyboard()
            text = " ".join(sys.argv[1:])
            kbd.type_string(text)
        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        # Interactive mode
        interactive_mode()


if __name__ == "__main__":
    main()

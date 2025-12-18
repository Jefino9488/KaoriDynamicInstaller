# Kaorios Framework Patcher

A Magisk/DynamicInstaller module that patches `framework.jar` for Play Integrity, Pixel spoofing, and Google Photos unlimited storage.

## Features

- **Play Integrity Support** - Pass device attestation checks
- **Pixel Device Spoofing** - Spoof device properties for specific apps
- **Google Photos Unlimited** - Enable unlimited storage for Google Photos
- **Android 15 Compatibility** - Includes invoke-custom bytecode fixes

## Installation

1. Download the latest release ZIP
2. Flash via **Magisk Manager**, **KernelSU**, or custom recovery
3. Reboot

## Requirements

- Android 14+ (API 34+)
- Magisk 20.4+ or KernelSU
- Unlocked bootloader

## Credits

| Project | Description |
|---------|-------------|
| [Kaorios Toolbox](https://github.com/Wuang26/Kaorios-Toolbox) | Core utility classes and APK for Play Integrity |
| [Dynamic Installer](https://github.com/BlassGO/DynamicInstaller) | Installation framework for Android modules |
| [Apktool](https://github.com/iBotPeaches/Apktool) | APK/DEX decompilation and recompilation |

## Disclaimer

Use at your own risk. Modifying system files may void warranty or cause issues.

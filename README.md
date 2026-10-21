# devices_m3.asm

A DOS/Windows utility that enumerates and displays information about devices installed in the system, split into two major sections with Russian explanations for each device.

## Overview

The `devices_m3.asm` version outputs device information divided into two large sections, each with Russian descriptions for every device:

1. **Devices potentially available for software control** — COM ports, USB, network adapters, audio, HID, cameras, Bluetooth, storage, and other devices with accessible software interfaces.
2. **Other Windows devices** — ACPI, system resources, motherboard, virtual and service devices, as well as devices that could not be confidently assigned to the first category.

For each device the utility displays:
- Name
- Description
- Manufacturer
- Class
- Hardware ID
- Instance ID
- A Russian-language explanation

## Classification Notes

The category is determined based on Windows PnP data, so this is a **preliminary classification**: the mere presence of a device in the list does not guarantee that it can be directly controlled by software.

## Usage

Run the utility. After reviewing the output, press **Enter** to exit.

## Requirements

- Windows
- Assembler toolchain compatible with the source (see build instructions)

## Build

_Add your build instructions here._

## License

_Add license information here._
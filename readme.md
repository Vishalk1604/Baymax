# 🏥 Health Tracker - IoT Health Monitoring System

<div align="center">
  
![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue?logo=flutter)
![ESP32](https://img.shields.io/badge/ESP32-Bluetooth%20LE-green)
![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart)
![License](https://img.shields.io/badge/License-MIT-yellow)
![Status](https://img.shields.io/badge/Status-Active%20Development-brightgreen)

A real-time health monitoring mobile application that connects to ESP32-based sensors via Bluetooth Low Energy (BLE) to track vital signs including heart rate, SpO2 levels, and body temperature.

</div>

---

## 📋 Table of Contents
- [Overview](#-overview)
- [Features](#-features)
- [Technologies & Tools](#-technologies--tools)
- [System Architecture](#-system-architecture)
- [Installation & Setup](#-installation--setup)
- [Usage Instructions](#-usage-instructions)
- [Testing Guide](#-testing-guide)
- [Project Structure](#-project-structure)
- [Hardware Specifications](#-hardware-specifications)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🎯 Overview

Health Tracker is an IoT-based health monitoring system designed to provide real-time biometric measurements through a user-friendly mobile interface. The system consists of three main components:

1. **Flutter Mobile App** - Cross-platform iOS/Android application
2. **ESP32 Microcontroller** - IoT device with BLE connectivity
3. **Sensor Array** - MAX30105 (Heart Rate & SpO2) and MLX90614 (Temperature)

The app communicates wirelessly with the ESP32 via Bluetooth Low Energy, sends commands to trigger sensor readings, and displays real-time health metrics on an intuitive dashboard.

---

## ✨ Features

### Mobile Application
- ✅ **Real-time Health Monitoring** - Display heart rate, SpO2, and temperature readings
- ✅ **Wireless Connectivity** - BLE connection to ESP32 with auto-reconnection
- ✅ **Check-up Trigger** - One-touch button to initiate sensor readings
- ✅ **Connection Management** - Device scanning and pairing interface
- ✅ **Modern UI** - Clean, card-based design with gradient aesthetics
- ✅ **Reading Cards** - Visual representation of vital signs with color coding
- ✅ **Connection Status** - Real-time indicator of device connectivity
- ✅ **Settings Panel** - Device management and configuration options

### ESP32 Firmware
- ✅ **BLE Communication** - Custom GATT service with read/write characteristics
- ✅ **Multi-Sensor Support** - Integrated MAX30105 and MLX90614 drivers
- ✅ **I2C Bus Management** - Simultaneous control of multiple I2C sensors
- ✅ **Command Processing** - Responsive to mobile app commands
- ✅ **Data Packaging** - Efficient binary protocol for sensor data transmission
- ✅ **Serial Diagnostics** - Comprehensive debug output for troubleshooting

### Data Features
- ✅ **Heart Rate Monitoring** - BPM tracking with peak detection algorithm
- ✅ **Blood Oxygen (SpO2)** - Percentage-based oxygen saturation measurement
- ✅ **Temperature Sensing** - Non-contact infrared temperature measurement
- ✅ **Timestamp Recording** - Automatic timestamp for each reading
- ✅ **Data Validation** - Checksum verification for received data

---

## 🛠 Technologies & Tools

### Frontend
| Technology | Version | Purpose |
|-----------|---------|---------|
| Flutter | 3.0+ | Cross-platform mobile framework |
| Dart | 3.0+ | Programming language |
| Provider | 6.0.0 | State management |
| flutter_blue_plus | 1.31.9 | BLE communication |
| Material Design 3 | Latest | UI components & theming |

### Backend (IoT)
| Technology | Version | Purpose |
|-----------|---------|---------|
| ESP32 | Dev Module | Microcontroller |
| Arduino IDE | 2.0+ | Development environment |
| C++ | 17 | ESP32 firmware language |
| BLE (Bluetooth 5.0) | - | Wireless communication |

### Sensors & Hardware
| Component | Model | Function |
|-----------|-------|----------|
| Pulse Oximeter | MAX30105 | Heart Rate & SpO2 |
| IR Thermometer | MLX90614 | Temperature measurement |
| Microcontroller | ESP32 | Central processing unit |
| Communication | BLE 5.0 | Wireless protocol |

### Development Tools
- Arduino IDE 2.0+
- Android Studio / Xcode
- Visual Studio Code
- Git & GitHub
- Serial Monitor (diagnostics)

---

## 🏗 System Architecture

### High-Level Architecture
```
┌─────────────────────┐         BLE          ┌──────────────────┐
│   Flutter Mobile    │◄─────────────────►   │  ESP32 Device    │
│      App (iOS/      │    (Custom GATT)     │  with Sensors    │
│     Android)        │                      │                  │
└─────────────────────┘                      └──────────────────┘
         │                                            │
         │                                    ┌───────┴────────┐
    Display:                                  │                │
    • Heart Rate                         MAX30105         MLX90614
    • SpO2                          (HR + SpO2)      (Temperature)
    • Temperature                        I2C Bus
    • Connection Status
```

### Communication Protocol
```
Request Flow:
App → ESP32: [0x01] (Read Request)
             ↓
ESP32: Collects sensor data (100 samples)
             ↓
ESP32 → App: [HR_H][HR_L][SpO2][TEMP_H][TEMP_L][CHECKSUM]
             ↓
App: Parses and displays readings
```

---

## 📦 Installation & Setup

### Prerequisites
- **Mobile Development:**
  - Flutter SDK (3.0+)
  - Android SDK / Xcode
  - Dart SDK (3.0+)

- **ESP32 Development:**
  - Arduino IDE 2.0+
  - ESP32 Board Support Package
  - USB-to-Serial driver

- **Hardware:**
  - ESP32 Dev Module
  - MAX30105 Pulse Oximeter Module
  - MLX90614 Temperature Sensor
  - Jumper wires & USB cable

### Step 1: Clone Repository
```bash
git clone https://github.com/yourusername/health-tracker.git
cd health-tracker
```

### Step 2: Flutter App Setup
```bash
# Navigate to Flutter project
cd flutter_app

# Install dependencies
flutter pub get

# Run on device/emulator
flutter run
```

### Step 3: ESP32 Firmware Setup

#### 3a. Install Arduino IDE Libraries
Open Arduino IDE → Sketch → Include Library → Manage Libraries:
1. Search and install: **SparkFun MAX3010x Pulse and Proximity Sensor**
2. Search and install: **Adafruit MLX90614**
3. ESP32 BLE libraries (built-in)

#### 3b. Configure Board
- Go to Tools → Board → ESP32 Dev Module
- Upload Speed: 921600
- Flash Frequency: 80 MHz
- Flash Mode: DIO
- Partition Scheme: Default (4MB with spiffs)

#### 3c. Upload Code
```bash
# Copy ESP32 code from /esp32/arduino/arduino.ino
# Open in Arduino IDE
# Select COM port
# Click Upload
```

### Step 4: Hardware Wiring

**I2C Bus Configuration (ESP32):**
```
GPIO 21 (SDA) ──┬──→ MAX30105 SDA
                └──→ MLX90614 SDA

GPIO 22 (SCL) ──┬──→ MAX30105 SCL
                └──→ MLX90614 SCL

3.3V ────┬──→ MAX30105 VCC
         └──→ MLX90614 VCC

GND ─────┬──→ MAX30105 GND
         └──→ MLX90614 GND
```

**Optional I2C Pull-ups:**
- 4.7kΩ resistor: GPIO 21 to 3.3V
- 4.7kΩ resistor: GPIO 22 to 3.3V

---

## 🎮 Usage Instructions

### Initial Setup
1. **Power on ESP32** - Device will start BLE advertising
2. **Open Health Tracker App** - Launch the mobile application
3. **Grant Permissions** - Allow Bluetooth and Location permissions when prompted

### Connecting Device
1. Navigate to **Settings** tab
2. Tap **"Scan for Devices"**
3. Select **"ESP32_HEALTH"** from the list
4. Wait for connection confirmation (status indicator turns green)

### Taking Readings
1. From **Home** tab, tap the **blue "+"** button in the bottom center
2. Place your **finger on the MAX30105 sensor**
3. Keep steady for 5-10 seconds while the app collects data
4. Readings will automatically display on the Home screen

### Viewing Results
- **Heart Rate**: Displayed in BPM (beats per minute)
- **SpO2**: Displayed as percentage (%)
- **Temperature**: Displayed in Celsius (°C)
- **Timestamp**: Automatic recording of reading time

### Disconnecting
1. Go to **Settings** tab
2. Tap **"Disconnect"** button
3. Status will change to "Not Connected"

---

## 🧪 Testing Guide

### Unit Testing (Flutter)

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/bluetooth_service_test.dart

# Run with coverage
flutter test --coverage
```

### Manual Testing Checklist

#### Bluetooth Connectivity
- [ ] App scans and finds ESP32
- [ ] Successfully connects to device
- [ ] Connection status updates in real-time
- [ ] Reconnects automatically after disconnect
- [ ] Handles BLE errors gracefully

#### Sensor Readings
- [ ] Heart rate readings are within 60-100 BPM range
- [ ] SpO2 readings are between 95-100%
- [ ] Temperature readings are between 35-39°C
- [ ] All three values display simultaneously
- [ ] Readings are stable and consistent

#### UI/UX
- [ ] App loads without crashing
- [ ] Navigation between tabs works smoothly
- [ ] Loading dialog appears during reading
- [ ] Error messages are clear and helpful
- [ ] Cards display readings with proper formatting
- [ ] Color coding matches reading values

#### Data Transmission
- [ ] Data packets transmit within 5 seconds
- [ ] Checksum validation prevents corrupted data
- [ ] No data loss during transmission
- [ ] Multiple consecutive readings work correctly

### ESP32 Serial Output Testing

```
Expected Serial Output:
ESP32 Health Tracker Starting...
✓ MAX30105 initialized successfully
✓ MLX90614 initialized successfully
✓ BLE initialized and advertising as 'ESP32_HEALTH'

>>> Device connected to app!
Reading request received
--- Starting sensor readings ---
Collecting RED and IR samples...
Calculating SpO2 and Heart Rate...
Reading temperature...

=== Readings Received ===
Heart Rate: 72 bpm
SpO2: 98%
Temperature: 36.8 °C

✓ Data sent successfully via BLE
```

### Hardware Testing
- [ ] MAX30105 LED lights up when finger present
- [ ] MLX90614 responds to temperature changes
- [ ] I2C devices detected on addresses 0x57 and 0x5A
- [ ] No I2C communication errors on serial output

---

## 📁 Project Structure

```
health-tracker/
├── flutter_app/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/
│   │   │   ├── home_screen.dart
│   │   │   ├── history_screen.dart
│   │   │   └── settings_screen.dart
│   │   ├── services/
│   │   │   └── bluetooth_service.dart
│   │   ├── models/
│   │   │   └── health_reading.dart
│   │   ├── widgets/
│   │   │   ├── reading_card.dart
│   │   │   └── loading_dialog.dart
│   │   └── theme/
│   │       └── app_theme.dart
│   ├── pubspec.yaml
│   └── README.md
│
├── esp32/
│   └── arduino/
│       └── arduino.ino (Main firmware)
│
├── docs/
│   ├── DESIGN_DOCUMENT.md
│   ├── ARCHITECTURE.md
│   ├── API_PROTOCOL.md
│   └── TROUBLESHOOTING.md
│
├── README.md (this file)
├── LICENSE
└── .gitignore
```

---

## 🔧 Hardware Specifications

### ESP32 Dev Module
- **Processor**: Tensilica Xtensa 32-bit LX6 Dual-core
- **Frequency**: 240 MHz
- **RAM**: 520 KB SRAM
- **Flash**: 4 MB (typical)
- **Bluetooth**: BLE 5.0
- **I2C Ports**: 2 (I2C0, I2C1)
- **Operating Voltage**: 3.3V
- **Power Consumption**: ~80mA (active)

### MAX30105 Pulse Oximeter
- **I2C Address**: 0x57
- **Sampling Rate**: Up to 3200 Hz
- **Operating Voltage**: 3.3V - 5.0V
- **Current**: 10mA (typical)
- **Features**: Red/IR/Green LEDs
- **Output**: PPG waveform

### MLX90614 IR Thermometer
- **I2C Address**: 0x5A
- **Temperature Range**: -40°C to 85°C
- **Accuracy**: ±0.5°C
- **Operating Voltage**: 3.3V - 5.0V
- **Current**: 1.5mA (typical)
- **Features**: Non-contact measurement

---

## 📡 BLE Communication Protocol

### GATT Service
```
Service UUID: 0000180A-0000-1000-8000-00805F9B34FB

Characteristics:
├── RX (Write) UUID: 00002A24-0000-1000-8000-00805F9B34FB
│   └── Receives commands from app
│
└── TX (Notify) UUID: 00002A25-0000-1000-8000-00805F9B34FB
    └── Sends sensor data to app
```

### Data Packet Format
```
[BYTE 0] [BYTE 1] [BYTE 2] [BYTE 3] [BYTE 4] [BYTE 5]
[HR_H]   [HR_L]   [SpO2]   [TEMP_H] [TEMP_L] [CHECKSUM]

Heart Rate: (BYTE0 << 8) | BYTE1 (range: 0-255 BPM)
SpO2: BYTE2 (range: 0-100%)
Temperature: ((BYTE3 << 8) | BYTE4) / 100.0 (°C)
Checksum: BYTE0 ^ BYTE1 ^ BYTE2 ^ BYTE3 ^ BYTE4
```

---

## 🐛 Troubleshooting

### App Issues

**"Bluetooth not available"**
- Enable Bluetooth on your phone
- Grant location permission (required for BLE scanning on Android)

**"Cannot find ESP32_HEALTH"**
- Ensure ESP32 is powered on
- Check serial output shows "BLE advertising started"
- Restart ESP32 and app

**"Connection timeout"**
- Move closer to ESP32 device
- Restart both devices
- Check for interference from other BLE devices

**"No readings displayed"**
- Ensure finger is firmly on MAX30105 sensor
- Check LED is lighting up (red glow)
- Wait 10 seconds for sensor stabilization

### ESP32 Issues

**"MAX30105 not found"**
- Verify SDA (GPIO 21) and SCL (GPIO 22) connections
- Add 4.7kΩ pull-up resistors if needed
- Check power supply voltage (3.3V)

**"MLX90614 not responding"**
- Verify I2C address is 0x5A (use I2C scanner)
- Check connections to GPIO 21 and 22
- Ensure pull-up resistors are installed

**"BLE advertising not starting"**
- Power cycle ESP32
- Check serial output for errors
- Verify board configuration is correct

### For More Help
See [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for detailed diagnostic procedures.

---

## 📸 Screenshots

### Mobile App UI

<img width="540" height="1200" alt="image" src="https://github.com/user-attachments/assets/feab9164-bc34-4ed6-8e6f-276da280c3c1" />

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Code Standards
- Follow Flutter/Dart style guide
- Follow Arduino C++ best practices
- Add comments for complex logic
- Test thoroughly before submitting PR

---

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

---

## 👥 Authors

- **Your Name** - Initial work and design
- Contributors welcome!

---

## 📞 Support & Contact

For issues, questions, or suggestions:
- Open an issue on GitHub
- Contact: your.email@example.com
- Documentation: See [docs/](docs/) folder

---

## 🙏 Acknowledgments

- SparkFun for MAX30105 library
- Adafruit for MLX90614 library
- Flutter and Dart communities
- ESP32 community support

---

## 📚 Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [ESP32 Documentation](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/)
- [BLE Communication Guide](https://www.bluetooth.com/specifications/gatt/)
- [Arduino IDE Setup](https://docs.arduino.cc/software/ide-v2)

---

<div align="center">

Made with ❤️ for health monitoring

⭐ If you found this helpful, please consider giving it a star!

</div>

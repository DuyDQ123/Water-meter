# 🌟 IoT Digi - Smart IoT Platform

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)  
[![ESP32](https://img.shields.io/badge/ESP32-E7352C?style=for-the-badge&logo=espressif&logoColor=white)](https://www.espressif.com)  
[![PHP](https://img.shields.io/badge/PHP-777BB4?style=for-the-badge&logo=php&logoColor=white)](https://www.php.net)

## 📱 Overview

IoT Digi is a smart IoT platform that allows you to:
- 📸 Monitor ESP32 camera streams
- 💡 Control LED lights
- 📊 Track sensor data
- 📖 Perform OCR (Optical Character Recognition)
- 👥 Manage users and devices

## 🚀 Getting Started

### Prerequisites

- [x] XAMPP
- [x] Flutter SDK
- [x] Arduino IDE
- [x] ESP32 board
- [x] ESP8266 board (optional)

### 🔧 Installation

#### 1. Set Up the Backend

1. Install XAMPP and start Apache + MySQL services.
2. Copy the entire project into the `htdocs` directory.
3. Create the database and tables:
```bash
php setup_auth_db.php
2. Set Up the ESP32 Camera
Open the esp32cam folder in Arduino IDE.

Update config.h with your WiFi credentials:

#define WIFI_SSID "your_wifi_ssid"
#define WIFI_PASS "your_wifi_password"
Upload the code to your ESP32-CAM board.

3. Set Up the ESP32 Sender (Optional)
Open the esp32send folder in Arduino IDE.

Update config.h similarly.

Upload the code to your ESP32 device.

4. Set Up the Flutter App
Navigate to the Flutter project folder:

cd iotdigi
Install dependencies:

flutter pub get
Run the app:

flutter run
📱 App Usage
🔐 Login/Register
Use the registration screen to create a new account.

Login with your registered credentials.

🎮 Main Features
Camera Stream: View real-time video feed from ESP32-CAM.

LED Control: Control LED lights remotely.

Sensor Data: Monitor sensor readings.

OCR: Extract text from images.

👑 Admin Panel
Manage connected devices.

Monitor notifications.

Manage user accounts.

🤝 Contributions
All contributions are welcome! Please:

Fork the project.

Create a new branch (git checkout -b feature/AmazingFeature).

Commit your changes (git commit -m 'Add some AmazingFeature').

Push to the branch (git push origin feature/AmazingFeature).

Open a Pull Request.

📝 License
This project is licensed under the MIT License - see the LICENSE file for details.

🙏 Acknowledgments
Flutter team

ESP32 community

All contributors



# 💧 Water-meter IoT System 🚰

## 📸 Project Overview

This project includes two main modules:
- **esp32cam**: ESP32-CAM for image capture, OCR (Optical Character Recognition), LED control, and image streaming.
- **esp32send**: Standard ESP32 (with DHT sensor & OLED display) for temperature/humidity monitoring, OLED display, and data posting to server.

## 📁 Folder Structure

- `esp32cam/` – ESP32-CAM code (image capture, OCR, LED control)
- `esp32send/` – ESP32 code for DHT sensor, OLED, and server communication
- `video_upload/` – PHP backend for receiving data from ESP32

## 🛠️ Hardware Requirements

- ESP32-CAM (AI-Thinker or compatible)
- ESP32 DevKit (or similar)
- DHT22 Sensor 🌡️
- OLED I2C 128x64 Display 🖥️
- Jumper wires, suitable power supply

## ⚙️ Setup Instructions

1. **Clone the repository:**
   ```bash
   git clone https://github.com/DuyDQ123/Warter-metter.git
   ```

2. **Install Arduino Libraries:**
   - `WiFi.h`
   - `HTTPClient.h`
   - `ArduinoJson.h`
   - `DHT sensor library`
   - `Adafruit SSD1306`
   - `Adafruit GFX`
   - `esp_camera` (for ESP32-CAM)

3. **Configure WiFi & Server:**
   - Edit WiFi credentials and server URLs in each `config.h` file to match your network.

4. **Upload Code:**
   - Flash `esp32cam/esp32cam.ino` to your ESP32-CAM.
   - Flash `esp32send/esp32send.ino` to your ESP32 DevKit.

5. **Run PHP Backend:**
   - Place the `video_upload` folder in your web server directory (e.g., `XAMPP/htdocs`).
   - Make sure PHP and MySQL are running.

## 🚀 Usage

- Access the endpoints printed in the Serial Monitor after ESP32-CAM boots to control the LED or trigger OCR.
- The standard ESP32 will automatically send temperature and humidity data to the server and display it on the OLED.

## 📜 License

MIT License

---

**Author:**  
DuyDQ123  
[GitHub Repository](https://github.com/DuyDQ123/Warter-metter)

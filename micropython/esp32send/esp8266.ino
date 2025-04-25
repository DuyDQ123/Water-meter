void setup() {
    Serial.begin(115200); // Khởi động Serial Monitor
    Serial.println("Starting fake sensor simulation...");
}

void loop() {
    // Giả lập dữ liệu cảm biến
    float temperature = random(200, 350) / 10.0; // Giá trị nhiệt độ từ 20.0°C đến 35.0°C
    float humidity = random(400, 800) / 10.0;    // Giá trị độ ẩm từ 40.0% đến 80.0%

    // Hiển thị dữ liệu lên Serial Monitor
    Serial.println("Fake Sensor Data:");
    Serial.print("Temperature: ");
    Serial.print(temperature);
    Serial.println(" °C");
    Serial.print("Humidity: ");
    Serial.print(humidity);
    Serial.println(" %");
    Serial.println("-------------------------");

    delay(2000); // Chờ 2 giây trước khi lặp lại
}

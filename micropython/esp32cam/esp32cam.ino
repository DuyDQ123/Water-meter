#include "esp_camera.h"
#include "esp_wifi.h"
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"

// Camera pins
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

// Network configuration
const char* ssid = "WIFI_KTX";
const char* password = "16092003";

// API endpoints and configuration
const char* NGROK_URL = "eb38-2001-ee0-4b4c-80-d8b5-d2be-f1d0-3443.ngrok-free.app";
const char* SERVER_URL = "http://192.168.1.4";
const char* OCR_API_URL = "https://api.ocr.space/parse/image";
const char* OCR_API_KEY = "K85797055088957";
String IMG_URL;

// LED configuration
const int LED_PIN = 4;
const int MAX_BRIGHTNESS = 800;

// HTTP server for brightness control
WiFiServer brightnessServer(81);

// Task handles
TaskHandle_t ledTaskHandle;
TaskHandle_t ocrTaskHandle;
TaskHandle_t streamingTaskHandle;

// Mutex for thread safety
SemaphoreHandle_t httpMutex;

void sendHTTPResponse(WiFiClient client, String status, String contentType, String body) {
  client.printf("HTTP/1.1 %s\r\n", status.c_str());
  client.printf("Content-Type: %s\r\n", contentType.c_str());
  client.println("Access-Control-Allow-Origin: *");
  client.println("Connection: close");
  client.println();
  client.println(body);
}

void setup() {
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);
  
  Serial.begin(115200);
  Serial.println("Starting ESP32-CAM...");
  
  pinMode(LED_PIN, OUTPUT);
  analogWrite(LED_PIN, 0);
  
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());
  
  IMG_URL = "https://" + String(NGROK_URL) + "/Warter-metter-main/video_stream/uploaded_image.jpg";
  
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.frame_size = FRAMESIZE_VGA;
  config.jpeg_quality = 12;
  config.fb_count = 2;
  
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x", err);
    return;
  }

  sensor_t * s = esp_camera_sensor_get();
  s->set_hmirror(s, 1);   // 1 = enable , 0 = disable
  s->set_vflip(s, 1);     // 1 = enable , 0 = disable
  
  httpMutex = xSemaphoreCreateMutex();
  brightnessServer.begin();
  
  // Create tasks with different priorities
  xTaskCreatePinnedToCore(
    handleLED,
    "LED_Task",
    4096,
    NULL,
    3,  // Highest priority
    &ledTaskHandle,
    0
  );
  
  xTaskCreatePinnedToCore(
    handleOCR,
    "OCR_Task",
    8192,
    NULL,
    2,  // Medium priority
    &ocrTaskHandle,
    0
  );
  
  xTaskCreatePinnedToCore(
    handleStreaming,
    "Streaming_Task",
    8192,
    NULL,
    1,  // Lowest priority
    &streamingTaskHandle,
    1
  );
}

void handleLED(void * parameter) {
  while(true) {
    WiFiClient client = brightnessServer.available();
    if (client) {
      String request = "";
      unsigned long timeout = millis();
      
      while (millis() - timeout < 1000) {
        while (client.available()) {
          char c = client.read();
          request += c;
          if (c == '\n') {
            timeout = millis();
          }
        }
        
        if (request.indexOf("\r\n\r\n") != -1) {
          break;
        }
      }
      
      if (request.indexOf("GET /slider?value=") >= 0) {
        int startPos = request.indexOf("value=") + 6;
        int endPos = request.indexOf(" ", startPos);
        if (endPos == -1) {
          endPos = request.indexOf("\r", startPos);
        }
        
        if (endPos != -1) {
          String valueStr = request.substring(startPos, endPos);
          int value = valueStr.toInt();
          value = constrain(value, 0, MAX_BRIGHTNESS);
          
          int mappedValue = map(value, 0, MAX_BRIGHTNESS, 0, 255);
          analogWrite(LED_PIN, mappedValue);
          Serial.printf("Set brightness to %d (mapped from %d)\n", mappedValue, value);
          sendHTTPResponse(client, "200 OK", "text/plain", "Brightness adjusted");
        } else {
          sendHTTPResponse(client, "400 Bad Request", "text/plain", "Invalid brightness value");
        }
      }
      
      client.stop();
    }
    
    vTaskDelay(1); // Small delay to prevent watchdog triggering
  }
}

void handleOCR(void * parameter) {
  TickType_t xLastWakeTime;
  const TickType_t xFrequency = pdMS_TO_TICKS(10000);
  xLastWakeTime = xTaskGetTickCount();
  
  while(true) {
    vTaskDelayUntil(&xLastWakeTime, xFrequency);
    
    if(WiFi.status() == WL_CONNECTED) {
      if(xSemaphoreTake(httpMutex, portMAX_DELAY) == pdTRUE) {
        Serial.println("\n=== Starting OCR Processing ===");
        
        HTTPClient http;
        String boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW";
        String body = "--" + boundary + "\r\n";
        body += "Content-Disposition: form-data; name=\"url\"\r\n\r\n";
        body += IMG_URL + "\r\n";
        body += "--" + boundary + "\r\n";
        body += "Content-Disposition: form-data; name=\"OCREngine\"\r\n\r\n";
        body += "2\r\n";
        body += "--" + boundary + "--\r\n";
        
        Serial.println("Sending image URL to OCR API: " + IMG_URL);
        
        http.begin(OCR_API_URL);
        http.addHeader("Content-Type", "multipart/form-data; boundary=" + boundary);
        http.addHeader("apikey", OCR_API_KEY);
        
        int httpResponseCode = http.POST(body);
        Serial.printf("OCR API Response Code: %d\n", httpResponseCode);
        
        if(httpResponseCode == 200) {
          String response = http.getString();
          DynamicJsonDocument doc(1024);
          DeserializationError error = deserializeJson(doc, response);
          
          if(!error) {
            String parsedText = doc["ParsedResults"][0]["ParsedText"] | "none";
            if(parsedText != "none" && parsedText.length() > 0) {
              Serial.println("Successfully extracted text: " + parsedText);
              
              HTTPClient phpHttp;
              phpHttp.begin(String(SERVER_URL) + "/Warter-metter-main/post.php");
              phpHttp.addHeader("Content-Type", "application/json");
              
              DynamicJsonDocument resultDoc(200);
              resultDoc["ocr_text"] = parsedText;
              
              String jsonResult;
              serializeJson(resultDoc, jsonResult);
              
              int phpResponseCode = phpHttp.POST(jsonResult);
              String phpResponse = phpHttp.getString();
              Serial.println("Database save response: " + phpResponse);
              
              phpHttp.end();
            } else {
              Serial.println("No text detected in image");
            }
          }
        }
        
        http.end();
        xSemaphoreGive(httpMutex);
        Serial.println("=== OCR Processing Complete ===\n");
      }
    }
  }
}

void handleStreaming(void * parameter) {
  while(true) {
    camera_fb_t * fb = esp_camera_fb_get();
    if(!fb) {
      vTaskDelay(1);
      continue;
    }
    
    if(WiFi.status() == WL_CONNECTED) {
      if(xSemaphoreTake(httpMutex, 0) == pdTRUE) {  // Non-blocking mutex take
        HTTPClient http;
        http.begin(String(SERVER_URL) + "/Warter-metter-main/post.php");
        
        String boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW";
        http.addHeader("Content-Type", "multipart/form-data; boundary=" + boundary);
        
        String head = "--" + boundary + "\r\n";
        head += "Content-Disposition: form-data; name=\"file\"; filename=\"frame.jpg\"\r\n";
        head += "Content-Type: image/jpeg\r\n\r\n";
        
        String tail = "\r\n--" + boundary + "--\r\n";
        
        uint32_t imageLen = fb->len;
        uint32_t extraLen = head.length() + tail.length();
        uint32_t totalLen = imageLen + extraLen;
        
        http.addHeader("Content-Length", String(totalLen));
        
        uint8_t *buffer = (uint8_t*)malloc(totalLen);
        if (buffer) {
          uint32_t pos = 0;
          memcpy(buffer, head.c_str(), head.length());
          pos += head.length();
          memcpy(buffer + pos, fb->buf, fb->len);
          pos += fb->len;
          memcpy(buffer + pos, tail.c_str(), tail.length());
          
          http.POST(buffer, totalLen);
          free(buffer);
        }
        
        http.end();
        xSemaphoreGive(httpMutex);
      }
    }
    
    esp_camera_fb_return(fb);
    vTaskDelay(1);
  }
}

void loop() {
  vTaskDelete(NULL); // Delete the loop task since we're using FreeRTOS tasks
}
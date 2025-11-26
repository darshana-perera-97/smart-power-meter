#include <ESP8266WiFi.h>
#include <WiFiClientSecure.h>
#include <ESP8266HTTPClient.h>
#include <SoftwareSerial.h>
#include <PZEM004Tv30.h>

// ---------- CONFIG ----------
const char* ssid     = "Xiomi";
const char* password = "dddddddd";

const String firebaseDB = "https://power-meter-7d423-default-rtdb.asia-southeast1.firebasedatabase.app";
const String apiKey    = "AIzaSyCM3qjVP_Y5OBKs0ti8aZbbWbaasx-dhAM";
const char* locationPath = "/002";      // Upload path
const char* switchPath   = "/switch/002"; // Path to read switch value

const unsigned long SEND_INTERVAL = 1000UL; // 1 second
const int READ_ATTEMPTS = 5;
const unsigned long READ_DELAY_MS = 150;

// Pins
#define PZEM_RX_PIN D6   // PZEM RX pin (NodeMCU receives)
#define PZEM_TX_PIN D5   // PZEM TX pin (NodeMCU transmits)
#define RELAY_PIN   D4   // Relay connected to D4

SoftwareSerial pzemSerial(PZEM_RX_PIN, PZEM_TX_PIN);
PZEM004Tv30 pzem(pzemSerial);

WiFiClientSecure httpsClient;
HTTPClient https;

unsigned long lastSend = 0;
volatile bool sending = false;

// Last known good readings fallback
float lastVoltage = 0.0;
float lastCurrent = 0.0;
float lastPower   = 0.0;
float lastEnergy  = 0.0;

void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  Serial.printf("Connecting to WiFi '%s'...\n", ssid);
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 15000) {
    delay(200);
    Serial.print(".");
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi connected, IP: " + WiFi.localIP().toString());
  } else {
    Serial.println("\nWiFi connect failed (will retry later).");
  }
}

bool tryReadPZEM(float &voltage, float &current, float &power, float &energy) {
  voltage = current = power = energy = 0.0;
  for (int attempt = 1; attempt <= READ_ATTEMPTS; ++attempt) {
    float v = pzem.voltage();
    float i = pzem.current();
    float p = pzem.power();
    float e = pzem.energy();

    Serial.printf("  raw read #%d -> V=%.3f  I=%.3f  P=%.3f  E=%.3f\n", attempt,
                  isnan(v) ? NAN : v,
                  isnan(i) ? NAN : i,
                  isnan(p) ? NAN : p,
                  isnan(e) ? NAN : e);

    if (!isnan(v) && v > 1.0) voltage = v;
    if (!isnan(i) && i > 0.001) current = i;
    if (!isnan(p) && p >= 0) power = p;
    if (!isnan(e) && e >= 0) energy = e;

    if (voltage > 0.5 || current > 0.001) {
      return true;
    }
    delay(READ_DELAY_MS);
  }
  voltage = current = power = energy = 0.0;
  return false;
}

bool uploadPayload(const String &json) {
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("WiFi not connected, abort upload");
      return false;
    }
  }

  String url = firebaseDB + String(locationPath) + ".json?auth=" + apiKey;

  if (https.begin(httpsClient, url)) {
    https.addHeader("Content-Type", "application/json");
    int httpCode = https.PUT(json);
    if (httpCode > 0) {
      Serial.printf("HTTP %d\n", httpCode);
      String resp = https.getString();
      Serial.println("Resp: " + resp);
      https.end();
      return (httpCode >= 200 && httpCode < 300);
    } else {
      Serial.printf("HTTP error: %s\n", https.errorToString(httpCode).c_str());
    }
    https.end();
  } else {
    Serial.println("HTTPS begin failed");
  }
  return false;
}

bool readSwitchValue(bool &switchState) {
  switchState = false;
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("WiFi not connected, cannot read switch value");
      return false;
    }
  }

  String url = firebaseDB + String(switchPath) + ".json?auth=" + apiKey;

  if (https.begin(httpsClient, url)) {
    int httpCode = https.GET();
    if (httpCode > 0) {
      if (httpCode == HTTP_CODE_OK) {
        String payload = https.getString();
        Serial.println("Switch value JSON payload:");
        Serial.println(payload);

        // Simple parse for 'true' or 'false' in payload (expected boolean)
        payload.trim();
        if (payload == "true") {
          switchState = true;
        } else if (payload == "false") {
          switchState = false;
        } else {
          Serial.println("Unexpected switch value format.");
          https.end();
          return false;
        }
        https.end();
        return true;
      } else {
        Serial.printf("HTTP GET failed, code: %d\n", httpCode);
      }
    } else {
      Serial.printf("HTTP GET error: %s\n", https.errorToString(httpCode).c_str());
    }
    https.end();
  } else {
    Serial.println("HTTPS begin failed for reading switch");
  }
  return false;
}

void setup() {
  Serial.begin(115200);
  delay(50);
  Serial.println("\nPZEM -> NodeMCU -> Firebase relay control (1 Hz, last-known fallback)");

  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW); // Start with relay off

  pzemSerial.begin(9600);
  delay(200);
  randomSeed(analogRead(A0));

  connectWiFi();
  httpsClient.setInsecure(); // Skip certificate verification for dev
}

void loop() {
  unsigned long now = millis();
  if (now - lastSend < SEND_INTERVAL) return;

  if (sending) {
    lastSend = now;
    Serial.println("Previous upload still running — skipping this second");
    return;
  }

  sending = true;
  lastSend = now;

  Serial.println("\n--- Cycle start ---");

  float voltage = 0, current = 0, power = 0, energy = 0;
  bool ok = tryReadPZEM(voltage, current, power, energy);

  String status = "no_reading";
  if (ok) {
    lastVoltage = voltage;
    lastCurrent = current;
    lastPower   = power;
    lastEnergy  = energy;
    status = "ok";
    Serial.printf("Valid read. V=%.3f I=%.3f P=%.3f E=%.3f\n", voltage, current, power, energy);
  } else {
    voltage = lastVoltage;
    current = lastCurrent;
    power   = lastPower;
    energy  = lastEnergy;
    Serial.println("No valid reading — uploading last known values instead.");
    Serial.printf(" lastKnown V=%.3f I=%.3f P=%.3f E=%.3f\n", voltage, current, power, energy);
  }

  int randKey = random(1000, 10000);
  const int batteryFixed = 79;
  const char deviceId[] = "003";

  String json = "{";
  json += "\"battery\":" + String(batteryFixed) + ",";
  json += "\"current\":" + String(current, 3) + ",";
  json += "\"device\":\"" + String(deviceId) + "\",";
  json += "\"key\":" + String(randKey) + ",";
  json += "\"livepower\":" + String(power, 3) + ",";
  json += "\"totalpower\":" + String(energy, 3) + ",";
  json += "\"voltage\":" + String(voltage, 3) + ",";
  json += "\"status\":\"" + status + "\"";
  json += "}";

  Serial.println("Uploading JSON: " + json);
  bool success = uploadPayload(json);
  if (!success) {
    Serial.println("Upload failed (will retry next cycle).");
  } else {
    Serial.println("Upload OK.");
  }

  // Read switch value from Firebase and control relay
  bool switchState = false;
  if (readSwitchValue(switchState)) {
    Serial.printf("Controlling relay on pin D4 based on switch value: %s\n", switchState ? "ON" : "OFF");
    digitalWrite(RELAY_PIN, switchState ? LOW : HIGH);
  } else {
    Serial.println("Failed to read switch value - relay state unchanged.");
  }

  sending = false;
}

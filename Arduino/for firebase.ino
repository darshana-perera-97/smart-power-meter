// NodeMCU (ESP8266) + PZEM-004T -> Firebase every 1 second
// Behavior:
//  - Try up to 5 reads to get a valid reading.
//  - If valid reading found: update lastKnown and upload with status "ok".
//  - If no valid reading: upload lastKnown values with status "no_reading" (avoids zeros).
//  - Serial debug prints every cycle.
// Requirements:
//  - PZEM004Tv30 library installed (or change to PZEM004T if your module needs it)

#include <ESP8266WiFi.h>
#include <WiFiClientSecure.h>
#include <ESP8266HTTPClient.h>
#include <SoftwareSerial.h>
#include <PZEM004Tv30.h>

// ---------- CONFIG ----------
const char* ssid     = "Xiomi";
const char* password = "12345678";

const String firebaseDB = "https://power-meter-7d423-default-rtdb.asia-southeast1.firebasedatabase.app";
const String apiKey     = "AIzaSyCM3qjVP_Y5OBKs0ti8aZbbWbaasx-dhAM";
const char* locationPath = "/002"; // writes to .../002.json

const unsigned long SEND_INTERVAL = 1000UL; // 1 second
const int READ_ATTEMPTS = 5;                // try this many times to get a valid reading
const unsigned long READ_DELAY_MS = 150;    // ms between read attempts
// ----------------------------

// Use safe pins (not boot mode pins)
#define PZEM_RX_PIN D6   // NodeMCU pin connected to PZEM TX (NodeMCU receives here)
#define PZEM_TX_PIN D5   // NodeMCU pin connected to PZEM RX (NodeMCU transmits here)

SoftwareSerial pzemSerial(PZEM_RX_PIN, PZEM_TX_PIN); // rx, tx
PZEM004Tv30 pzem(pzemSerial);

WiFiClientSecure httpsClient;
HTTPClient https;

unsigned long lastSend = 0;
volatile bool sending = false;

// last known good values (start as zeros but will update once a real read occurs)
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

// Attempt multiple reads; return true if a valid reading found and fill out values
bool tryReadPZEM(float &voltage, float &current, float &power, float &energy) {
  voltage = current = power = energy = 0.0;
  for (int attempt = 1; attempt <= READ_ATTEMPTS; ++attempt) {
    float v = pzem.voltage();
    float i = pzem.current();
    float p = pzem.power();
    float e = pzem.energy();

    // Debug each raw read for visibility
    Serial.printf("  raw read #%d -> V=%.3f  I=%.3f  P=%.3f  E=%.3f\n", attempt,
                  isnan(v) ? NAN : v,
                  isnan(i) ? NAN : i,
                  isnan(p) ? NAN : p,
                  isnan(e) ? NAN : e);

    // Accept as valid if voltage or current > small threshold and not NaN
    if (!isnan(v) && v > 1.0) voltage = v;
    if (!isnan(i) && i > 0.001) current = i;
    if (!isnan(p) && p >= 0) power = p;
    if (!isnan(e) && e >= 0) energy = e;

    if (voltage > 0.5 || current > 0.001) {
      // we got something sensible
      return true;
    }

    delay(READ_DELAY_MS);
  }
  // No valid reading after attempts
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

void setup() {
  Serial.begin(115200);
  delay(50);
  Serial.println("\nPZEM -> NodeMCU -> Firebase (1 Hz, last-known fallback)");

  pzemSerial.begin(9600);
  delay(200); // give PZEM time to boot
  randomSeed(analogRead(A0));

  connectWiFi();
  httpsClient.setInsecure(); // dev: skip cert verification
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
    // update last known only when we actually got good values
    lastVoltage = voltage;
    lastCurrent = current;
    lastPower   = power;
    lastEnergy  = energy;
    status = "ok";
    Serial.printf("Valid read. V=%.3f I=%.3f P=%.3f E=%.3f\n", voltage, current, power, energy);
  } else {
    // keep last known values (avoid uploading zeros)
    voltage = lastVoltage;
    current = lastCurrent;
    power   = lastPower;
    energy  = lastEnergy;
    Serial.println("No valid reading — uploading last known values instead.");
    Serial.printf(" lastKnown V=%.3f I=%.3f P=%.3f E=%.3f\n", voltage, current, power, energy);
  }

  int randKey = random(1000, 10000); // 4-digit random
  const int batteryFixed = 79;
  const char deviceId[] = "003";

  // Build JSON (exact fields required; status added)
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

  sending = false;
}

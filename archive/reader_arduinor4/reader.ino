/*
*/
#include <Wire.h>
#include <SPI.h>
#include <Adafruit_PN532.h>

//arduino_secrets.h header file
#include <WiFiS3.h>
#define SECRET_SSID "playmates"
#define SECRET_PASS "since1953"
///////please enter your sensitive data in the Secret tab/arduino_secrets.h
char ssid[] = SECRET_SSID;        // your network SSID (name)
char pass[] = SECRET_PASS;    // your network password (use for WPA, or use as key for WEP)
int status = WL_IDLE_STATUS;     // the WiFi radio's status

#include <ArduinoMqttClient.h>
WiFiClient wifiClient;
MqttClient mqttClient(wifiClient);
const char broker[] = "mqtt.playmates";
int        port     = 1883;
const char topic[]  = "rfid/reader01/tag";


#define CARD_READ_VERIFY    2       /* times to check before reporting no card present */
#define CARD_READ_TIMEOUT   50     /* ms */
#define CARD_MISSING_TAG    "None"  /* tag to report when no card present */

// PN532 breakout or shield with I2C, define just the pins connected
// to the IRQ and reset lines.  Use the values below (2, 3) for the shield!
#define PN532_IRQ   (2)
#define PN532_RESET (3)  // Not connected by default on the NFC Shield

// function to call to reset arduino
void(* resetFunc) (void) = 0;//declare reset function at address 0

// PN532 breakout or shield with an I2C connection:
Adafruit_PN532 nfc(PN532_IRQ, PN532_RESET);

// Last card UID we read
char last_uid[32];
// Current card UID we are reading
char now_uid[32];
// number of times to check for card before reporting removal
int read_count = 0;

void printMacAddress(byte mac[]) {
  for (int i = 0; i < 6; i++) {
    if (i > 0) {
      Serial.print(":");
    }
    if (mac[i] < 16) {
      Serial.print("0");
    }
    Serial.print(mac[i], HEX);
  }
  Serial.println();
}

void printCurrentNet() {
  // print the SSID of the network you're attached to:
  Serial.print("SSID: ");
  Serial.println(WiFi.SSID());

  // print the MAC address of the router you're attached to:
  byte bssid[6];
  WiFi.BSSID(bssid);
  Serial.print("BSSID: ");
  printMacAddress(bssid);

  // print the received signal strength:
  long rssi = WiFi.RSSI();
  Serial.print("signal strength (RSSI):");
  Serial.println(rssi);

  // print the encryption type:
  byte encryption = WiFi.encryptionType();
  Serial.print("Encryption Type:");
  Serial.println(encryption, HEX);
  Serial.println();
}

void printWifiData() {
  // print your board's IP address:
  IPAddress ip = WiFi.localIP();
  Serial.print("IP Address: ");
  
  Serial.println(ip);

  // print your MAC address:
  byte mac[6];
  WiFi.macAddress(mac);
  Serial.print("MAC address: ");
  printMacAddress(mac);
}



void setup(void) {
  Serial.begin(115200);
  while (!Serial) {
    delay(10); // for Leonardo/Micro/Zero
  }

  Serial.print("INFO: Starting up...");

  // check for the WiFi module:
  if (WiFi.status() == WL_NO_MODULE) {
    Serial.println("Communication with WiFi module failed!");
    // don't continue
    while (true);
  }

  // attempt to connect to WiFi network:
  while (status != WL_CONNECTED) {
    Serial.print("Attempting to connect to WPA SSID: ");
    Serial.println(ssid);
    // Connect to WPA/WPA2 network:
    status = WiFi.begin(ssid, pass);

    // wait 10 seconds for connection:
    delay(10000);
  }

  // you're connected now, so print out the data:
  Serial.print("You're connected to the network");
  printCurrentNet();
  printWifiData();

  Serial.print("Attempting to connect to the MQTT broker: ");
  Serial.println(broker);

  mqttClient.setUsernamePassword("m5go", "_m5go");

  if (!mqttClient.connect(broker, port)) {
    Serial.print("MQTT connection failed! Error code = ");
    Serial.println(mqttClient.connectError());

    while (1);
  }

  nfc.begin();
  uint32_t versiondata = nfc.getFirmwareVersion();
  if (!versiondata) {
    Serial.print("ERROR: Didn't find PN53x board");

    while (1) {
      resetFunc();  // halt
    }
  }
  // Got ok data, print it out!
  Serial.print("INFO: Found chip PN5"); Serial.println((versiondata>>24) & 0xFF, HEX);
  Serial.print("INFO: Firmware ver. "); Serial.print((versiondata>>16) & 0xFF, DEC);
  Serial.print('.'); Serial.println((versiondata>>8) & 0xFF, DEC);
}



void loop(void) {
  uint8_t card_present;
  uint8_t uid[] = { 0, 0, 0, 0, 0, 0, 0 };  // Buffer to store the returned UID
  uint8_t uidLength;                        // Length of the UID (4 or 7 bytes depending on ISO14443A card type)

  mqttClient.poll();

  // Wait for an ISO14443A type cards (Mifare, etc.).  When one is found
  // 'uid' will be populated with the UID, and uidLength will indicate
  // if the uid is 4 bytes (Mifare Classic) or 7 bytes (Mifare Ultralight)
  card_present = nfc.readPassiveTargetID(PN532_MIFARE_ISO14443A, uid, &uidLength, CARD_READ_TIMEOUT);
  // Serial.print("Card Present = "); Serial.println(card_present);
  if (card_present) {
    if (uidLength == 4) {
      sprintf(now_uid, "%2.2x-%2.2x-%2.2x-%2.2x", uid[0], uid[1], uid[2], uid[3]);
    } else if (uidLength == 7) {
      sprintf(now_uid, "%2.2x-%2.2x-%2.2x-%2.2x-%2.2x-%2.2x-%2.2x", uid[0], uid[1], uid[2], uid[3], uid[4], uid[5], uid[6]);
    }
  } else {
    // clear card
    strcpy(now_uid, CARD_MISSING_TAG);
  }

  // Serial.print(read_count);
  // Serial.print(" ");
  // Serial.println(now_uid);

  // update read_count
  read_count = strcmp(now_uid, last_uid) ? 0 : read_count+1;

  // if card has changed, report to Serial
  if (read_count == CARD_READ_VERIFY) {
    read_count = CARD_READ_VERIFY+1;
    Serial.println(now_uid);
    mqttClient.beginMessage(topic);
    mqttClient.print(now_uid);
    mqttClient.endMessage();
  }

  // update last card seen
  strcpy(last_uid, now_uid);
  if (card_present) {
    delay(CARD_READ_TIMEOUT);
  }
}
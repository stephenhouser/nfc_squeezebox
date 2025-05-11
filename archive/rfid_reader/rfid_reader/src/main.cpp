/*
*/
#include <Arduino.h>
#include <Wire.h>
#include <SPI.h>
#include <Adafruit_PN532.h>

#define CARD_READ_VERIFY    3       /* times to check before reporting no card present */
#define CARD_READ_TIMEOUT   100     /* ms */
#define CARD_MISSING_TAG    "None"  /* tag to report when no card present */

// PN532 breakout or shield with I2C, define just the pins connected
// to the IRQ and reset lines.  Use the values below (2, 3) for the shield!
#define PN532_IRQ     19
#define PN532_RESET   18
Adafruit_PN532 nfc(PN532_IRQ, PN532_RESET);

// function to call to reset arduino
void(* resetFunc) (void) = 0;//declare reset function at address 0

// Last card UID we read
char last_uid[32];
// Current card UID we are reading
char now_uid[32];
// number of times to check for card before reporting removal
int read_count = 0;


void setup(void) {
  Serial.begin(115200);
  while (!Serial) {
    delay(10); // for Leonardo/Micro/Zero
  }

  Serial.print("INFO: Starting up...");

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
  }

  // update last card seen
  strcpy(last_uid, now_uid);
  if (card_present) {
    delay(CARD_READ_TIMEOUT);
  }
}
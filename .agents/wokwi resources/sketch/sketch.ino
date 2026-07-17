#include "BluetoothSerial.h"
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"

BluetoothSerial SerialBT;

const int LED_PINS[8] = {13, 12, 14, 27, 26, 25, 33, 32};
const int PIR_PIN = 15;
const int LDR_PIN = 34;
const int BUZZER_PIN = 4;
const int GRID_WAVE_SEQUENCE[8] = {0, 1, 2, 4, 7, 6, 5, 3};

unsigned long lastTelemetryTime = 0;
const unsigned long TELEMETRY_INTERVAL = 1000;

int lastPirState = -1;
String inputBuffer = "";

bool isArmed = false;
bool alarmTriggered = false;
unsigned long lastAlarmToggle = 0;
bool alarmState = false;

int currentMode = 0;
bool motionDetectorEnabled = true;
bool lightDetectorEnabled = true;
unsigned long lightOnDuration = 10000;
int darkThreshold = 800;
int semiThreshold = 2000;
bool buzzerSoundEnabled = true;

int selectedAnimation = 0;
int selectedLedsMask = 255;
int gridToPhysicalMap[8] = {0, 1, 2, 3, 4, 5, 6, 7};
unsigned long lastAnimUpdate = 0;
int animStep = 0;
bool animToggle = false;

unsigned long motionTriggerTime = 0;
bool motionActive = false;

// Identify selected LED variables
bool identifyActive = false;
int identifyLedNum = 0;
unsigned long identifyStartTime = 0;
unsigned long lastIdentifyToggle = 0;
bool identifyLedState = false;

void setup() {
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);

  Serial.begin(115200);
  SerialBT.begin("esp32 abdellah");

  for (int i = 0; i < 8; i++) {
    pinMode(LED_PINS[i], OUTPUT);
    digitalWrite(LED_PINS[i], LOW);
  }

  pinMode(PIR_PIN, INPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);
}

void sendSystemState() {
  SerialBT.print("SYS:MODE=");
  SerialBT.print(currentMode);
  SerialBT.print(",M=");
  SerialBT.print(motionDetectorEnabled ? 1 : 0);
  SerialBT.print(",S=");
  SerialBT.print(lightDetectorEnabled ? 1 : 0);
  SerialBT.print(",O=");
  SerialBT.print(lightOnDuration / 1000);
  SerialBT.print(",TD=");
  SerialBT.print(darkThreshold);
  SerialBT.print(",TS=");
  SerialBT.print(semiThreshold);
  SerialBT.print(",B=");
  SerialBT.print(buzzerSoundEnabled ? 1 : 0);
  SerialBT.print(",A=");
  SerialBT.print(selectedAnimation);
  SerialBT.print(",AR=");
  SerialBT.println(selectedLedsMask);
}

void runAutoLEDs() {
  int ldrValue = analogRead(LDR_PIN);
  bool motionDetected = (digitalRead(PIR_PIN) == HIGH);

  if (motionDetected && motionDetectorEnabled) {
    motionActive = true;
    motionTriggerTime = millis();
  }

  if (motionActive && motionDetectorEnabled) {
    if (millis() - motionTriggerTime >= lightOnDuration) {
      motionActive = false;
    }
  }

  bool shouldBeOn = false;
  int ledsMode = 0;

  if (motionDetectorEnabled && lightDetectorEnabled) {
    shouldBeOn = motionActive;
    if (shouldBeOn) {
      if (ldrValue < darkThreshold) ledsMode = 2;
      else if (ldrValue < semiThreshold) ledsMode = 1;
      else ledsMode = 0;
    }
  } else if (!motionDetectorEnabled && lightDetectorEnabled) {
    shouldBeOn = true;
    if (ldrValue < darkThreshold) ledsMode = 2;
    else if (ldrValue < semiThreshold) ledsMode = 1;
    else ledsMode = 0;
  } else if (motionDetectorEnabled && !lightDetectorEnabled) {
    shouldBeOn = motionActive;
    if (shouldBeOn) {
      ledsMode = 2;
    }
  } else if (!motionDetectorEnabled && !lightDetectorEnabled) {
    shouldBeOn = true;
    ledsMode = 2;
  }

  if (shouldBeOn) {
    if (ledsMode == 2) {
      for (int i = 0; i < 8; i++) {
        digitalWrite(LED_PINS[i], HIGH);
      }
    } else if (ledsMode == 1) {
      for (int i = 0; i < 8; i++) {
        if (i == 2 || i == 3 || i == 4 || i == 7) {
          digitalWrite(LED_PINS[i], HIGH);
        } else {
          digitalWrite(LED_PINS[i], LOW);
        }
      }
    } else {
      for (int i = 0; i < 8; i++) {
        digitalWrite(LED_PINS[i], LOW);
      }
    }
  } else {
    for (int i = 0; i < 8; i++) {
      digitalWrite(LED_PINS[i], LOW);
    }
  }
}

void runSelectedAnimation() {
  unsigned long now = millis();

  for (int i = 0; i < 8; i++) {
    int physIdx = gridToPhysicalMap[i];
    if (!((selectedLedsMask >> physIdx) & 1)) {
      digitalWrite(LED_PINS[physIdx], LOW);
    }
  }

  if (selectedAnimation == 0) {
    if (now - lastAnimUpdate >= 150) {
      lastAnimUpdate = now;
      for (int attempts = 0; attempts < 8; attempts++) {
        animStep = (animStep + 1) % 8;
        int gridIdx = GRID_WAVE_SEQUENCE[animStep];
        int physIdx = gridToPhysicalMap[gridIdx];
        if ((selectedLedsMask >> physIdx) & 1) {
          break;
        }
      }
      int activeGridIdx = GRID_WAVE_SEQUENCE[animStep];
      int activePhysIdx = gridToPhysicalMap[activeGridIdx];
      for (int i = 0; i < 8; i++) {
        int physIdx = gridToPhysicalMap[i];
        if (((selectedLedsMask >> physIdx) & 1) && (physIdx == activePhysIdx)) {
          digitalWrite(LED_PINS[physIdx], HIGH);
        } else {
          digitalWrite(LED_PINS[physIdx], LOW);
        }
      }
    }
  } else if (selectedAnimation == 1) {
    if (now - lastAnimUpdate >= 500) {
      lastAnimUpdate = now;
      animToggle = !animToggle;
      for (int i = 0; i < 8; i++) {
        int physIdx = gridToPhysicalMap[i];
        if ((selectedLedsMask >> physIdx) & 1) {
          digitalWrite(LED_PINS[physIdx], animToggle ? HIGH : LOW);
        }
      }
    }
  } else if (selectedAnimation == 2) {
    if (now - lastAnimUpdate >= 100) {
      lastAnimUpdate = now;
      animToggle = !animToggle;
      for (int i = 0; i < 8; i++) {
        int physIdx = gridToPhysicalMap[i];
        if ((selectedLedsMask >> physIdx) & 1) {
          digitalWrite(LED_PINS[physIdx], animToggle ? HIGH : LOW);
        }
      }
    }
  } else if (selectedAnimation == 3) {
    if (now - lastAnimUpdate >= 200) {
      lastAnimUpdate = now;
      animToggle = !animToggle;
      for (int i = 0; i < 8; i++) {
        int physIdx = gridToPhysicalMap[i];
        if ((selectedLedsMask >> physIdx) & 1) {
          if (i % 2 == 0) {
            digitalWrite(LED_PINS[physIdx], animToggle ? HIGH : LOW);
          } else {
            digitalWrite(LED_PINS[physIdx], animToggle ? LOW : HIGH);
          }
        }
      }
    }
  } else if (selectedAnimation == 4) {
    if (now - lastAnimUpdate >= 150) {
      lastAnimUpdate = now;
      for (int attempts = 0; attempts < 8; attempts++) {
        animStep = (animStep + 1) % 8;
        int gridIdx = GRID_WAVE_SEQUENCE[animStep];
        int physIdx = gridToPhysicalMap[gridIdx];
        if ((selectedLedsMask >> physIdx) & 1) {
          break;
        }
      }
      int offGridIdx = GRID_WAVE_SEQUENCE[animStep];
      int offPhysIdx = gridToPhysicalMap[offGridIdx];
      for (int i = 0; i < 8; i++) {
        int physIdx = gridToPhysicalMap[i];
        if ((selectedLedsMask >> physIdx) & 1) {
          digitalWrite(LED_PINS[physIdx], (physIdx == offPhysIdx) ? LOW : HIGH);
        }
      }
    }
  } else if (selectedAnimation == 5) {
    if (now - lastAnimUpdate >= 150) {
      lastAnimUpdate = now;
      animStep = (animStep + 1) % 6;
      for (int i = 0; i < 8; i++) {
        digitalWrite(LED_PINS[i], LOW);
      }
      if (animStep == 0) {
        int phys = gridToPhysicalMap[3];
        if ((selectedLedsMask >> phys) & 1) digitalWrite(LED_PINS[phys], HIGH);
      } else if (animStep == 1) {
        int phys0 = gridToPhysicalMap[0];
        int phys5 = gridToPhysicalMap[5];
        if ((selectedLedsMask >> phys0) & 1) digitalWrite(LED_PINS[phys0], HIGH);
        if ((selectedLedsMask >> phys5) & 1) digitalWrite(LED_PINS[phys5], HIGH);
      } else if (animStep == 2) {
        int phys1 = gridToPhysicalMap[1];
        int phys6 = gridToPhysicalMap[6];
        if ((selectedLedsMask >> phys1) & 1) digitalWrite(LED_PINS[phys1], HIGH);
        if ((selectedLedsMask >> phys6) & 1) digitalWrite(LED_PINS[phys6], HIGH);
      } else if (animStep == 3) {
        int phys2 = gridToPhysicalMap[2];
        int phys7 = gridToPhysicalMap[7];
        if ((selectedLedsMask >> phys2) & 1) digitalWrite(LED_PINS[phys2], HIGH);
        if ((selectedLedsMask >> phys7) & 1) digitalWrite(LED_PINS[phys7], HIGH);
      } else if (animStep == 4) {
        int phys4 = gridToPhysicalMap[4];
        if ((selectedLedsMask >> phys4) & 1) digitalWrite(LED_PINS[phys4], HIGH);
      }
    }
  } else if (selectedAnimation == 6) {
    if (now - lastAnimUpdate >= 250) {
      lastAnimUpdate = now;
      animStep = (animStep + 1) % 4;
      for (int i = 0; i < 8; i++) {
        digitalWrite(LED_PINS[i], LOW);
      }
      if (animStep == 0) {
        int p3 = gridToPhysicalMap[3];
        int p4 = gridToPhysicalMap[4];
        if ((selectedLedsMask >> p3) & 1) digitalWrite(LED_PINS[p3], HIGH);
        if ((selectedLedsMask >> p4) & 1) digitalWrite(LED_PINS[p4], HIGH);
      } else if (animStep == 1) {
        int p0 = gridToPhysicalMap[0];
        int p2 = gridToPhysicalMap[2];
        int p5 = gridToPhysicalMap[5];
        int p7 = gridToPhysicalMap[7];
        if ((selectedLedsMask >> p0) & 1) digitalWrite(LED_PINS[p0], HIGH);
        if ((selectedLedsMask >> p2) & 1) digitalWrite(LED_PINS[p2], HIGH);
        if ((selectedLedsMask >> p5) & 1) digitalWrite(LED_PINS[p5], HIGH);
        if ((selectedLedsMask >> p7) & 1) digitalWrite(LED_PINS[p7], HIGH);
      } else if (animStep == 2) {
        int p1 = gridToPhysicalMap[1];
        int p6 = gridToPhysicalMap[6];
        if ((selectedLedsMask >> p1) & 1) digitalWrite(LED_PINS[p1], HIGH);
        if ((selectedLedsMask >> p6) & 1) digitalWrite(LED_PINS[p6], HIGH);
      }
    }
  } else if (selectedAnimation == 7) {
    if (now - lastAnimUpdate >= 200) {
      lastAnimUpdate = now;
      animStep = (animStep + 1) % 4;
      for (int i = 0; i < 8; i++) {
        digitalWrite(LED_PINS[i], LOW);
      }
      if (animStep == 0) {
        int p0 = gridToPhysicalMap[0];
        int p7 = gridToPhysicalMap[7];
        if ((selectedLedsMask >> p0) & 1) digitalWrite(LED_PINS[p0], HIGH);
        if ((selectedLedsMask >> p7) & 1) digitalWrite(LED_PINS[p7], HIGH);
      } else if (animStep == 1) {
        int p2 = gridToPhysicalMap[2];
        int p5 = gridToPhysicalMap[5];
        if ((selectedLedsMask >> p2) & 1) digitalWrite(LED_PINS[p2], HIGH);
        if ((selectedLedsMask >> p5) & 1) digitalWrite(LED_PINS[p5], HIGH);
      } else if (animStep == 2) {
        int p1 = gridToPhysicalMap[1];
        int p6 = gridToPhysicalMap[6];
        int p3 = gridToPhysicalMap[3];
        int p4 = gridToPhysicalMap[4];
        if ((selectedLedsMask >> p1) & 1) digitalWrite(LED_PINS[p1], HIGH);
        if ((selectedLedsMask >> p6) & 1) digitalWrite(LED_PINS[p6], HIGH);
        if ((selectedLedsMask >> p3) & 1) digitalWrite(LED_PINS[p3], HIGH);
        if ((selectedLedsMask >> p4) & 1) digitalWrite(LED_PINS[p4], HIGH);
      }
    }
  } else if (selectedAnimation == 8) {
    if (now - lastAnimUpdate >= 150) {
      lastAnimUpdate = now;
      animStep = (animStep + 1) % 8;
      for (int i = 0; i < 8; i++) {
        digitalWrite(LED_PINS[i], LOW);
      }
      int gridIdx1 = GRID_WAVE_SEQUENCE[animStep];
      int gridIdx2 = GRID_WAVE_SEQUENCE[(animStep + 4) % 8];
      int p1 = gridToPhysicalMap[gridIdx1];
      int p2 = gridToPhysicalMap[gridIdx2];
      if ((selectedLedsMask >> p1) & 1) digitalWrite(LED_PINS[p1], HIGH);
      if ((selectedLedsMask >> p2) & 1) digitalWrite(LED_PINS[p2], HIGH);
    }
  }
}

void loop() {
  while (SerialBT.available() > 0) {
    char c = SerialBT.read();
    if (c == '\n' || c == '\r') {
      inputBuffer.trim();
      if (inputBuffer.length() > 0) {
        processCommand(inputBuffer);
        inputBuffer = "";
      }
    } else {
      inputBuffer += c;
    }
  }

  if (identifyActive) {
    unsigned long now = millis();
    if (now - identifyStartTime >= 1000) {
      identifyActive = false;
      digitalWrite(LED_PINS[identifyLedNum - 1], LOW);
      digitalWrite(BUZZER_PIN, LOW);
    } else {
      if (now - lastIdentifyToggle >= 100) {
        lastIdentifyToggle = now;
        identifyLedState = !identifyLedState;
        for (int i = 0; i < 8; i++) {
          if (i == identifyLedNum - 1) {
            digitalWrite(LED_PINS[i], identifyLedState ? HIGH : LOW);
          } else {
            digitalWrite(LED_PINS[i], LOW);
          }
        }
        if (now - identifyStartTime < 200 && buzzerSoundEnabled) {
          digitalWrite(BUZZER_PIN, HIGH);
        } else {
          digitalWrite(BUZZER_PIN, LOW);
        }
      }
    }
  } else if (currentMode == 1) {
    runAutoLEDs();
  } else if (currentMode == 2) {
    runSelectedAnimation();
  }

  if (isArmed && !alarmTriggered) {
    if (digitalRead(PIR_PIN) == HIGH) {
      alarmTriggered = true;
      SerialBT.println("ALARM:1");
    }
  }

  if (alarmTriggered) {
    unsigned long currentMillis = millis();
    if (currentMillis - lastAlarmToggle >= 100) {
      lastAlarmToggle = currentMillis;
      alarmState = !alarmState;
      for (int i = 0; i < 8; i++) {
        digitalWrite(LED_PINS[i], alarmState ? HIGH : LOW);
      }
      digitalWrite(BUZZER_PIN, alarmState ? HIGH : LOW);
    }
  } else {
    int currentPirState = digitalRead(PIR_PIN);
    if (currentPirState != lastPirState) {
      lastPirState = currentPirState;
      SerialBT.print("PIR:");
      SerialBT.println(lastPirState);
      if (!isArmed && buzzerSoundEnabled) {
        if (currentMode == 0 || (currentMode == 1 && motionDetectorEnabled)) {
          digitalWrite(BUZZER_PIN, HIGH);
          delay(100);
          digitalWrite(BUZZER_PIN, LOW);
        }
      }
    }

    unsigned long now = millis();
    if (now - lastTelemetryTime >= TELEMETRY_INTERVAL) {
      lastTelemetryTime = now;
      int ldrValue = analogRead(LDR_PIN);
      SerialBT.print("LDR:");
      SerialBT.println(ldrValue);
      sendSystemState();
    }
  }
}

void processCommand(String cmd) {
  Serial.print("Received Command: ");
  Serial.println(cmd);

  if (cmd == "PING") {
    SerialBT.println("PONG");
  } else if (cmd.startsWith("L") && cmd.indexOf(":") > 0) {
    if (isArmed || currentMode == 1 || currentMode == 2) return;
    int colonIdx = cmd.indexOf(":");
    int ledNum = cmd.substring(1, colonIdx).toInt();
    int state = cmd.substring(colonIdx + 1).toInt();
    if (ledNum >= 1 && ledNum <= 8) {
      digitalWrite(LED_PINS[ledNum - 1], state == 1 ? HIGH : LOW);
    }
  } else if (cmd.startsWith("D:")) {
    int state = cmd.substring(2).toInt();
    if (state == 1) {
      isArmed = true;
      for (int i = 0; i < 8; i++) {
        digitalWrite(LED_PINS[i], LOW);
      }
      digitalWrite(BUZZER_PIN, HIGH);
      delay(100);
      digitalWrite(BUZZER_PIN, LOW);
    } else {
      isArmed = false;
      if (alarmTriggered) {
        alarmTriggered = false;
        SerialBT.println("ALARM:0");
      }
      for (int i = 0; i < 8; i++) {
        digitalWrite(LED_PINS[i], LOW);
      }
      digitalWrite(BUZZER_PIN, HIGH);
      delay(50);
      digitalWrite(BUZZER_PIN, LOW);
      delay(50);
      digitalWrite(BUZZER_PIN, HIGH);
      delay(50);
      digitalWrite(BUZZER_PIN, LOW);
    }
  } else if (cmd.startsWith("M:")) {
    motionDetectorEnabled = (cmd.substring(2).toInt() == 1);
    sendSystemState();
  } else if (cmd.startsWith("S:")) {
    lightDetectorEnabled = (cmd.substring(2).toInt() == 1);
    sendSystemState();
  } else if (cmd.startsWith("O:")) {
    lightOnDuration = cmd.substring(2).toInt() * 1000;
    sendSystemState();
  } else if (cmd.startsWith("TD:")) {
    darkThreshold = cmd.substring(3).toInt();
    sendSystemState();
  } else if (cmd.startsWith("TS:")) {
    semiThreshold = cmd.substring(3).toInt();
    sendSystemState();
  } else if (cmd.startsWith("B:")) {
    buzzerSoundEnabled = (cmd.substring(2).toInt() == 1);
    sendSystemState();
  } else if (cmd.startsWith("A:")) {
    selectedAnimation = cmd.substring(2).toInt();
    sendSystemState();
  } else if (cmd.startsWith("AR:")) {
    selectedLedsMask = cmd.substring(3).toInt();
    sendSystemState();
  } else if (cmd.startsWith("MAP:")) {
    String mapData = cmd.substring(4);
    int startIdx = 0;
    for (int i = 0; i < 8; i++) {
      int commaIdx = mapData.indexOf(',', startIdx);
      if (commaIdx > 0) {
        gridToPhysicalMap[i] = mapData.substring(startIdx, commaIdx).toInt();
        startIdx = commaIdx + 1;
      } else {
        gridToPhysicalMap[i] = mapData.substring(startIdx).toInt();
        break;
      }
    }
    sendSystemState();
  } else if (cmd.startsWith("MODE:")) {
    currentMode = cmd.substring(5).toInt();
    for (int i = 0; i < 8; i++) {
      digitalWrite(LED_PINS[i], LOW);
    }
    digitalWrite(BUZZER_PIN, LOW);
    sendSystemState();
  } else if (cmd.startsWith("ID:")) {
    int ledNum = cmd.substring(3).toInt();
    if (ledNum >= 1 && ledNum <= 8) {
      identifyActive = true;
      identifyLedNum = ledNum;
      identifyStartTime = millis();
      lastIdentifyToggle = 0;
      identifyLedState = false;
      if (buzzerSoundEnabled) {
        digitalWrite(BUZZER_PIN, HIGH);
      }
    }
  }
}

# Smart House Architecture - 2-Floor Layout (8 LEDs)

## 1. House Architecture (بنية وهندسة المنزل)
The physical model is a two-story house containing 4 independent rooms:

### Ground Floor (الطابق السفلي)
* **Room 1 (Bottom Left / الغرفة اليسرى السفلية):** Contains the breadboard and ESP32 control center. Houses **LED 1** and **LED 2**.
* **Room 2 (Bottom Right / الغرفة اليمنى السفلية):** Independent space housing **LED 3** and **LED 4**.

### First Floor (الطابق العلوي)
* **Room 3 (Top Left / الغرفة اليسرى العلوية):** Houses **LED 5** and **LED 6**.
* **Room 4 (Top Right / الغرفة اليمنى العلوية):** Houses **LED 7** and **LED 8**.

---

## 2. Electronic Component Distribution (توزيع المكونات الإلكترونية)
* **Microcontroller (لوحة التحكم المركزية):** ESP32 DevKit v4 mounted on the breadboard in Room 1.
* **Actuators (نظام الإضاءة):** 8 LEDs (2 per room) each connected with a **220 Ohm** current-limiting resistor on the positive terminal (anode).
* **PIR Motion Sensor (مستشعر الحركة):** Positioned at the exact center of the top floor hallway (Central Hallway) for broad coverage.
* **LDR Sensor (مستشعر الضوء):** Wired with a **10k Ohm** resistor to form a voltage divider circuit, placed to read ambient light.
* **Buzzer (النظام الصوتي):** Mounted on the breadboard (Room 1) for system alerts and tone feedback.

---

## 3. Pin Mapping Register (خريطة التوصيل البرمجي)

| Component | Signal Type | GPIO Pin | Location |
| --- | --- | --- | --- |
| **LED 1** | Digital Output | `13` | Room 1 (Bottom Left) |
| **LED 2** | Digital Output | `12` | Room 1 (Bottom Left) |
| **LED 3** | Digital Output | `14` | Room 2 (Bottom Right) |
| **LED 4** | Digital Output | `27` | Room 2 (Bottom Right) |
| **LED 5** | Digital Output | `26` | Room 3 (Top Left) |
| **LED 6** | Digital Output | `25` | Room 3 (Top Left) |
| **LED 7** | Digital Output | `33` | Room 4 (Top Right) |
| **LED 8** | Digital Output | `32` | Room 4 (Top Right) |
| **PIR Sensor** | Digital Input | `15` | Central Top Floor Hallway |
| **LDR Sensor** | Analog Input | `34` | Ambient Light position |
| **Buzzer** | Digital Output | `4` | Room 1 (Breadboard) |

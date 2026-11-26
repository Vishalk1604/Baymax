//Mobile App Integrated Health Monitor - Heart Rate, SpO2, and Temperature
#include <Wire.h>
#include "MAX30105.h"
#include "heartRate.h"

#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Adafruit_MLX90614.h>

#include <BluetoothSerial.h>

/* ================= I2C PIN DEFINITIONS ================= */
#define OLED_SDA 21
#define OLED_SCL 22
#define SENSOR_SDA 25
#define SENSOR_SCL 26

/* ================= MEASUREMENT STATE MACHINE ================= */
enum MeasurementState {
    STATE_IDLE,
    STATE_WAIT_FINGER,
    STATE_MEASURING_HR_SPO2,
    STATE_WAIT_TEMP,
    STATE_MEASURING_TEMP,
    STATE_COMPLETE
};

MeasurementState currentState = STATE_IDLE;

/* ================= OLED ================= */
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET -1

// Create separate Wire instance for OLED
TwoWire Wire_OLED = TwoWire(0);
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire_OLED, OLED_RESET);

// Create separate Wire instance for sensors
TwoWire Wire_Sensors = TwoWire(1);

/* ================= BLUETOOTH ================= */
BluetoothSerial SerialBT;

/* ================= SENSORS ================= */
MAX30105 particleSensor;
Adafruit_MLX90614 mlx = Adafruit_MLX90614();

/* ================= MAX30102 CONFIG ================= */
const byte LED_BRIGHTNESS = 0x24;
const byte SAMPLE_AVG = 4;
const byte LED_MODE = 2;
const int SAMPLE_RATE = 400;
const int PULSE_WIDTH = 411;
const int ADC_RANGE = 4096;

/* ================= HEART RATE ================= */
const byte RATE_SIZE = 4;
byte rates[RATE_SIZE];
byte rateSpot = 0;
long lastBeat = 0;
float beatsPerMinute = 0;
int beatAvg = 0;

/* ================= SPO2 ================= */
long irValue, redValue;
float irDCValue = 0, redDCValue = 0;
float irACValueSqSum = 0, redACValueSqSum = 0;
int samplesCount = 0;
const int SAMPLES_RECORDED = 25;
int spo2 = 0;

/* ================= STATE ================= */
bool fingerDetected = false;
unsigned long startTime = 0;
const unsigned long STABILIZATION_TIME = 5000;
bool mlxAvailable = false;

/* ================= MEASUREMENT SESSION ================= */
struct MeasurementData {
    float heartRate = 0;
    int spo2Value = 0;
    float temperature = 0;
};
MeasurementData finalReadings;

/* ================= HR/SPO2 AVERAGING ================= */
const int HR_BUFFER_SIZE = 20;
int hrBuffer[HR_BUFFER_SIZE];
int hrBufferIndex = 0;
int hrBufferCount = 0;
float avgHeartRate = 0;

const int SPO2_BUFFER_SIZE = 15;
int spo2Buffer[SPO2_BUFFER_SIZE];
int spo2BufferIndex = 0;
int spo2BufferCount = 0;
float avgSpo2 = 0;

/* ================= TEMP AVERAGING ================= */
const int TEMP_BUFFER_SIZE = 20;
float tempBuffer[TEMP_BUFFER_SIZE];
int tempBufferIndex = 0;
int tempBufferCount = 0;
float avgTemp = 0;
float baselineTemp = 0;
bool tempChangeDetected = false;
const float TEMP_CHANGE_THRESHOLD = 2; // 0.5°C change required
unsigned long tempMeasureStartTime = 0;
const unsigned long TEMP_MEASURE_DURATION = 10000; // 10 seconds

/* ================= APP COMMUNICATION ================= */
String receivedCommand = "";
bool readingInProgress = false;
unsigned long readingStartTime = 0;
const unsigned long MAX_READING_TIME = 60000; // 60 seconds timeout

void setup() {
    Serial.begin(115200);

    // Initialize Bluetooth
    SerialBT.begin("BAYMAX");  // Device name visible on phone

    Serial.println("BAYMAX Starting...");
    Serial.println("Bluetooth: Waiting for connection...");

    // Initialize I2C buses
    Wire_OLED.begin(OLED_SDA, OLED_SCL, 100000);
    Wire_Sensors.begin(SENSOR_SDA, SENSOR_SCL, 100000);
    delay(100);

    /* OLED INIT - Address 0x3C confirmed */
    if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
        Serial.println("OLED Init Failed!");
        while (1) delay(1000);
    }

    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);
    display.setTextSize(2);
    display.setCursor(10, 20);
    display.println("BAYMAX");
    display.display();

    Serial.println("OLED: OK");

    /* MLX90614 INIT - Address 0x5A confirmed */
    mlxAvailable = mlx.begin(0x5A, &Wire_Sensors);

    if (mlxAvailable) {
        Serial.println("MLX90614: OK");
    } else {
        Serial.println("MLX90614: Not Available");
    }

    /* MAX30102 INIT - Address 0x57 confirmed */
    if (!particleSensor.begin(Wire_Sensors, I2C_SPEED_STANDARD)) {
        Serial.println("MAX30102 Init Failed!");
        display.clearDisplay();
        display.setTextSize(1);
        display.setCursor(0, 20);
        display.println("Sensor Error!");
        display.display();
        while (1) delay(1000);
    }

    // Configure MAX30102
    particleSensor.setup(
            LED_BRIGHTNESS,
            SAMPLE_AVG,
            LED_MODE,
            SAMPLE_RATE,
            PULSE_WIDTH,
            ADC_RANGE
    );

    particleSensor.setPulseAmplitudeRed(LED_BRIGHTNESS);
    particleSensor.setPulseAmplitudeIR(LED_BRIGHTNESS);

    Serial.println("MAX30102: OK");
    Serial.println("System Ready!");

    delay(2000);
    display.clearDisplay();
    display.display();
}

void loop() {
    // Handle app communication
    handleSerialCommand();

    // State machine for measurement
    switch (currentState) {
        case STATE_IDLE:
            handleIdleState();
            break;

        case STATE_WAIT_FINGER:
            handleWaitFingerState();
            break;

        case STATE_MEASURING_HR_SPO2:
            handleMeasuringHRSpO2State();
            break;

        case STATE_WAIT_TEMP:
            handleWaitTempState();
            break;

        case STATE_MEASURING_TEMP:
            handleMeasuringTempState();
            break;

        case STATE_COMPLETE:
            handleCompleteState();
            break;
    }

    delay(25);
}

void showInstructions(const char *msg1, const char *msg2 = "") {
    display.clearDisplay();
    display.setTextSize(2);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(0, 10);
    display.println(msg1);
    if (msg2[0] != '\0') {
        display.setCursor(0, 35);
        display.println(msg2);
    }
    display.display();
}

/* ================= SERIAL COMMUNICATION ================= */
void handleSerialCommand() {
    while (SerialBT.available()) {
        char c = SerialBT.read();
        if (c == '\n') {
            processCommand(receivedCommand);
            receivedCommand = "";
        } else {
            receivedCommand += c;
        }
    }
}

void processCommand(String cmd) {
    cmd.trim();
    cmd.toLowerCase();

    if (cmd == "start") {
        startMeasurement();
    }
}

void startMeasurement() {
    if (readingInProgress) {
        sendToApp("ERROR", "Measurement already in progress");
        return;
    }

    readingInProgress = true;
    readingStartTime = millis();
    currentState = STATE_WAIT_FINGER;
    resetAllBuffers();
    baselineTemp = 0;
    tempChangeDetected = false;

    SerialBT.println("ACK"); // Acknowledge to app
}

/* ================= STATE HANDLERS ================= */
void handleIdleState() {
    display.clearDisplay();
    display.setTextSize(1);
    display.setCursor(0, 20);
    display.println("Waiting for app...");
    display.display();
}

void handleWaitFingerState() {
    irValue = particleSensor.getIR();
    redValue = particleSensor.getRed();

    // Check for finger placement
    if (irValue < 50000) {
        showInstructions("Put finger\non sensor", "Waiting...");
        delay(100);
        return;
    }

    // Finger detected, move to measuring
    fingerDetected = true;
    startTime = millis();
    currentState = STATE_MEASURING_HR_SPO2;
    resetHRSpo2Buffers();
    showInstructions("Finger detected", "Measuring...");
    SerialBT.println("STATUS:HR_SPO2_MEASURING");
}

void handleMeasuringHRSpO2State() {
    irValue = particleSensor.getIR();
    redValue = particleSensor.getRed();

    // Check if finger is still present
    if (irValue < 50000) {
        showInstructions("Put finger back", "on sensor");
        delay(100);
        return;
    }

    // Detect heartbeat
    if (checkForBeat(irValue)) {
        long delta = millis() - lastBeat;
        lastBeat = millis();
        beatsPerMinute = 60 / (delta / 1000.0);

        if (beatsPerMinute > 40 && beatsPerMinute < 200) {
            addToHRBuffer((int)beatsPerMinute);
            calculateAverageHR();
        }
    }

    // Calculate SpO2
    calculateSpO2();
    addToSpo2Buffer(spo2);
    calculateAverageSpo2();

    // Update display
    static unsigned long lastDisplay = 0;
    if (millis() - lastDisplay > 500) {
        displayMeasurementProgress("HR & SpO2", (int)avgHeartRate, (int)avgSpo2);
        lastDisplay = millis();
    }

    // Transition after stabilization time
    if (millis() - startTime > STABILIZATION_TIME && hrBufferCount >= 10) {
        currentState = STATE_WAIT_TEMP;
        showInstructions("Now measure", "temperature");
        delay(1000);
    }

    // Timeout check
    if (millis() - readingStartTime > MAX_READING_TIME) {
        sendToApp("ERROR", "HR/SPO2 measurement timeout");
        resetMeasurement();
    }
}

void handleWaitTempState() {
    if (mlxAvailable) {
        float currentTemp = mlx.readObjectTempC();

        if (baselineTemp == 0 && !isnan(currentTemp) && currentTemp > -40 && currentTemp < 125) {
            baselineTemp = currentTemp;
            showInstructions("Put head near", "temp sensor");
        } else if (baselineTemp > 0) {
            float tempDiff = abs(currentTemp - baselineTemp);

            if (tempDiff >= TEMP_CHANGE_THRESHOLD) {
                tempChangeDetected = true;
                tempMeasureStartTime = millis();
                currentState = STATE_MEASURING_TEMP;
                resetTempBuffer();
                showInstructions("Measuring", "temperature");
                SerialBT.println("STATUS:TEMP_MEASURING");
            }
        }
    } else {
        // No temp sensor, skip to complete
        currentState = STATE_COMPLETE;
    }

    // Timeout check
    if (millis() - readingStartTime > MAX_READING_TIME) {
        sendToApp("ERROR", "Temperature measurement timeout");
        resetMeasurement();
    }
}

void handleMeasuringTempState() {
    if (mlxAvailable) {
        float temp = mlx.readObjectTempC();

        if (!isnan(temp) && temp > -40 && temp < 125) {
            addToTempBuffer(temp);
            calculateAverageTemp();

            // Display progress
            static unsigned long lastDisplay = 0;
            if (millis() - lastDisplay > 500) {
                displayTempProgress((int)avgTemp, tempBufferCount);
                lastDisplay = millis();
            }
        }
    }

    // End measurement after duration
    if (millis() - tempMeasureStartTime > TEMP_MEASURE_DURATION) {
        finalReadings.temperature = avgTemp;
        currentState = STATE_COMPLETE;
    }

    // Timeout check
    if (millis() - readingStartTime > MAX_READING_TIME) {
        sendToApp("ERROR", "Temperature measurement timeout");
        resetMeasurement();
    }
}

void handleCompleteState() {
    // Store final readings
    finalReadings.heartRate = avgHeartRate;
    finalReadings.spo2Value = (int)avgSpo2;

    // Display results
    displayFinalResults();

    // Send to app
    sendFinalDataToApp();

    // Reset
    delay(3000);
    readingInProgress = false;
    currentState = STATE_IDLE;
    resetMeasurement();
}

/* ================= BUFFER MANAGEMENT ================= */
void resetAllBuffers() {
    resetHRSpo2Buffers();
    resetTempBuffer();
}

void resetHRSpo2Buffers() {
    hrBufferCount = 0;
    hrBufferIndex = 0;
    spo2BufferCount = 0;
    spo2BufferIndex = 0;
    avgHeartRate = 0;
    avgSpo2 = 0;
}

void resetTempBuffer() {
    tempBufferCount = 0;
    tempBufferIndex = 0;
    avgTemp = 0;
}

void addToHRBuffer(int hr) {
    hrBuffer[hrBufferIndex] = hr;
    hrBufferIndex = (hrBufferIndex + 1) % HR_BUFFER_SIZE;
    if (hrBufferCount < HR_BUFFER_SIZE) {
        hrBufferCount++;
    }
}

void calculateAverageHR() {
    if (hrBufferCount == 0) return;

    float sum = 0;
    for (int i = 0; i < hrBufferCount; i++) {
        sum += hrBuffer[i];
    }
    avgHeartRate = sum / hrBufferCount;
}

void addToSpo2Buffer(int spo2Val) {
    spo2Buffer[spo2BufferIndex] = spo2Val;
    spo2BufferIndex = (spo2BufferIndex + 1) % SPO2_BUFFER_SIZE;
    if (spo2BufferCount < SPO2_BUFFER_SIZE) {
        spo2BufferCount++;
    }
}

void calculateAverageSpo2() {
    if (spo2BufferCount == 0) return;

    float sum = 0;
    for (int i = 0; i < spo2BufferCount; i++) {
        sum += spo2Buffer[i];
    }
    avgSpo2 = sum / spo2BufferCount;
}

void addToTempBuffer(float temp) {
    tempBuffer[tempBufferIndex] = temp;
    tempBufferIndex = (tempBufferIndex + 1) % TEMP_BUFFER_SIZE;
    if (tempBufferCount < TEMP_BUFFER_SIZE) {
        tempBufferCount++;
    }
}

void calculateAverageTemp() {
    if (tempBufferCount == 0) return;

    float sum = 0;
    for (int i = 0; i < tempBufferCount; i++) {
        sum += tempBuffer[i];
    }
    avgTemp = sum / tempBufferCount;
}

void resetMeasurement() {
    resetAllBuffers();
    resetMeasurements();
    fingerDetected = false;
    tempChangeDetected = false;
    baselineTemp = 0;
}

/* ================= DISPLAY ================= */
void displayInstructions(const char *line1, const char *line2) {
    display.clearDisplay();
    display.setTextSize(2);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(0, 10);
    display.println(line1);
    display.setCursor(0, 35);
    display.println(line2);
    display.display();
}

void displayMeasurementProgress(const char *label, int value1, int value2) {
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);

    display.setCursor(0, 0);
    display.println(label);

    display.setCursor(0, 15);
    display.print("HR: ");
    display.print(value1);
    display.println(" bpm");

    display.setCursor(0, 30);
    display.print("SpO2: ");
    display.print(value2);
    display.println("%");

    display.setCursor(0, 50);
    display.print("Samples: ");
    display.println(hrBufferCount);

    display.display();
}

void displayTempProgress(int temp, int samples) {
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);

    display.setCursor(0, 0);
    display.println("Measuring Temp");

    display.setCursor(0, 20);
    display.print("Temp: ");
    display.print(avgTemp, 2);
    display.println(" C");

    display.setCursor(0, 40);
    display.print("Samples: ");
    display.println(samples);

    display.display();
}

void displayFinalResults() {
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);

    display.setCursor(0, 0);
    display.println("=== FINAL RESULTS ===");

    display.setCursor(0, 15);
    display.print("HR: ");
    display.print((int)finalReadings.heartRate);
    display.println(" bpm");

    display.setCursor(0, 28);
    display.print("SpO2: ");
    display.print(finalReadings.spo2Value);
    display.println("%");

    display.setCursor(0, 41);
    display.print("Temp: ");
    display.print(finalReadings.temperature, 2);
    display.println(" C");

    display.display();
}


void showMessage(const char *msg) {
    display.clearDisplay();
    display.setTextSize(1);
    display.setCursor(0, 20);
    display.print(msg);
    display.display();
}

/* ================= SPO2 ================= */
void calculateSpO2() {
    samplesCount++;
    irDCValue = irDCValue * 0.95 + irValue * 0.05;
    redDCValue = redDCValue * 0.95 + redValue * 0.05;

    float irAC = irValue - irDCValue;
    float redAC = redValue - redDCValue;

    irACValueSqSum += irAC * irAC;
    redACValueSqSum += redAC * redAC;

    if (samplesCount >= SAMPLES_RECORDED) {
        float irRMS = sqrt(irACValueSqSum / SAMPLES_RECORDED);
        float redRMS = sqrt(redACValueSqSum / SAMPLES_RECORDED);

        if (irDCValue > 0 && redDCValue > 0) {
            float R = (redRMS / redDCValue) / (irRMS / irDCValue);
            spo2 = constrain(110 - 25 * R, 70, 100);
        }

        samplesCount = 0;
        irACValueSqSum = 0;
        redACValueSqSum = 0;
    }
}

void resetMeasurements() {
    beatAvg = 0;
    spo2 = 0;
    rateSpot = 0;
    irDCValue = redDCValue = 0;
    irACValueSqSum = redACValueSqSum = 0;
    samplesCount = 0;
}

/* ================= APP COMMUNICATION ================= */
void sendToApp(const char *status, const char *message) {
    String response = String(status) + ":" + String(message);
    SerialBT.println(response);
}

void sendFinalDataToApp() {
    // Format: DATA:HR={hr},SPO2={spo2},TEMP={temp}
    String dataString = "DATA:HR=";
    dataString += String((int)finalReadings.heartRate);
    dataString += ",SPO2=";
    dataString += String(finalReadings.spo2Value);
    dataString += ",TEMP=";
    dataString += String(finalReadings.temperature, 1);

    SerialBT.println(dataString);
    sendToApp("SUCCESS", "Readings complete");
}
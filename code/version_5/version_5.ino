#include <U8g2lib.h>
#include <Wire.h>
#include <math.h>
#include <Typing_Detection_inferencing.h>
#include <driver/i2s.h>
#include <HardwareSerial.h>
#include <DFRobot_DF1201S.h>
#include <Adafruit_VEML7700.h>
#include "Adafruit_SGP30.h"

// 使用ESP32内置的BLE库
#include "BLEDevice.h"
#include "BLEServer.h"
#include "BLEUtils.h"
#include "BLE2902.h"

// ==== BLE相关 ====
BLEServer* pServer = NULL;
BLECharacteristic* pCommandCharacteristic = NULL;
BLECharacteristic* pStatusCharacteristic = NULL;
BLECharacteristic* pSensorCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

#define SERVICE_UUID        "12345678-1234-1234-1234-123456789abc"
#define COMMAND_CHAR_UUID   "87654321-4321-4321-4321-cba987654321"
#define STATUS_CHAR_UUID    "11111111-2222-3333-4444-555555555555"
#define SENSOR_CHAR_UUID    "22222222-3333-4444-5555-666666666666"

// ==== OLED ====
U8G2_SSD1309_128X64_NONAME2_F_HW_I2C u8g2(U8G2_R0, U8X8_PIN_NONE);
const int SCREEN_WIDTH = 128;
const int SCREEN_HEIGHT = 64;

// ==== Pomodoro硬件 ====
const int AIN1 = 25, AIN2 = 33, PWMA = 32;
const int BIN1 = 27, BIN2 = 14, PWMB = 13;
const int STBY = 26, buttonPin = 23;

// ==== Eye动画参数 ====
const int eyeGap = 40, eyeRadiusX = 11, eyeRadiusY = 10, eyeCenterY = 32, eyeCenterX = 64;
const unsigned long COUNTDOWN_WINDOW_MS = 10000UL;
const unsigned long EYE_WINDOW_MS = 20000UL;
const unsigned long BLINK_PERIOD_MS = 5000UL;
const unsigned long BLINK_DUR_MS = 800UL;

// ==== Pomodoro 状态 ====
enum PomodoroState { IDLE, FOCUS, BREAK };
PomodoroState currentState = IDLE;
bool pomodoroRunning = false;
bool pomotoroPaused = false;  // 新增暂停状态
int pomodoroRound = 0, totalRounds = 4;
unsigned long stateStartTime = 0, lastMoveTime = 0;
unsigned long pausedTime = 0;  // 暂停累计时间
bool showingCountdown = true;
unsigned long displaySwitchTime = 0, lastCountdownUpdate = 0;
bool moveForwardNext = true;  // 控制交替方向

// ==== 可自定义的时间设置（毫秒）====
unsigned long focusTimeMs = 25UL * 60 * 1000;  // 默认3分钟（测试用）
unsigned long breakTimeMs = 5UL * 60 * 1000;  // 默认1分钟（测试用）

// ==== Typing 检测参数 ====
#define I2S_WS   15
#define I2S_SCK  2
#define I2S_SD   4
#define EI_RATE  8000
#define WIN_MS   1000
#define WIN_LEN  (EI_RATE * WIN_MS / 1000)
static int16_t audioBuf[WIN_LEN];
static ei::signal_t eiSignal;

// ==== DFPlayer Pro ====
HardwareSerial dfSerial(2);
DFRobot_DF1201S player;

// ==== Typing 检测状态 ====
uint16_t noTypingSec = 0;
unsigned long lastTypingCheck = 0;

// ==== 光照和空气质量传感器 ====
Adafruit_VEML7700 veml;
Adafruit_SGP30 sgp;
unsigned long lastLightCheck = 0;
unsigned long lastAirCheck = 0;
unsigned long lastSensorDataSend = 0;
const unsigned long SENSOR_INTERVAL = 30000UL; // 30秒
const unsigned long SENSOR_SEND_INTERVAL = 5000UL; // 5秒发送一次传感器数据

// 传感器数据变量
float currentLux = 0;
uint16_t currentTVOC = 0;
uint16_t currentECO2 = 0;

// ==== 函数声明 ====
void moveForward(int durationMs = 1000);
void stopMotors();
void playMp3(uint16_t fileNum);
void showCenteredText(const char* text);
void drawCenteredStr(int y, const char* text);
void displayCountdown(PomodoroState state, unsigned long remMs);
void updateDisplay();
void drawEyesFrame(unsigned long phaseMs);
void drawEyes(int radY);
void drawEye(int cx, int cy, int rx, int ry);
void initI2S();
int get_data(size_t off, size_t len, float *out);
void initBLE();
void startPomodoro();
void pausePomodoro();
void resumePomodoro();
void stopPomodoro();
void sendStatus();
void sendSensorData();
void handleBLECommand(String command);

// ==== Pomodoro控制函数 ====
void startPomodoro() {
    if (!pomodoroRunning) {
        pomodoroRunning = true;
        pomotoroPaused = false;
        currentState = FOCUS;
        stateStartTime = millis();
        pausedTime = 0;
        pomodoroRound = 0;
        showingCountdown = true;
        displaySwitchTime = millis();
        lastCountdownUpdate = 0;
        lastLightCheck = millis();
        lastAirCheck = millis();
        showCenteredText("Pomodoro\nStarted!");
        Serial.println("🍅 Pomodoro started via BLE");
        delay(1000);
    }
}

void pausePomodoro() {
    if (pomodoroRunning && !pomotoroPaused) {
        pomotoroPaused = true;
        pausedTime = millis();
        showCenteredText("Paused");
        Serial.println("⏸️ Pomodoro paused via BLE");
    }
}

void resumePomodoro() {
    if (pomodoroRunning && pomotoroPaused) {
        pomotoroPaused = false;
        stateStartTime += (millis() - pausedTime);
        displaySwitchTime += (millis() - pausedTime);
        Serial.println("▶️ Pomodoro resumed via BLE");
    }
}

void stopPomodoro() {
    pomodoroRunning = false;
    pomotoroPaused = false;
    currentState = IDLE;
    pomodoroRound = 0;
    pausedTime = 0;
    showCenteredText("Stopped\nvia App");
    Serial.println("⏹️ Pomodoro stopped via BLE");
    delay(1000);
    showCenteredText("Press Button\nor Use App");
}

// ==== 发送状态到App ====
void sendStatus() {
    if (deviceConnected && pStatusCharacteristic) {
        String status = "";
        status += "STATE:" + String(currentState) + ",";
        status += "RUNNING:" + String(pomodoroRunning) + ",";
        status += "PAUSED:" + String(pomotoroPaused) + ",";
        // 使用ESP32端的totalRounds变量
        status += "ROUND:" + String(pomodoroRound + 1) + "/" + String(totalRounds) + ",";
        
        if (pomodoroRunning && !pomotoroPaused) {
            unsigned long elapsed = millis() - stateStartTime;
            unsigned long duration = (currentState == FOCUS) ? focusTimeMs : breakTimeMs;
            unsigned long remaining = (elapsed >= duration) ? 0 : duration - elapsed;
            status += "REMAINING:" + String(remaining / 1000);
        } else {
            status += "REMAINING:0";
        }
        
        pStatusCharacteristic->setValue(status.c_str());
        pStatusCharacteristic->notify();
    }
}

// ==== 发送传感器数据到App ====
void sendSensorData() {
    if (deviceConnected && pSensorCharacteristic) {
        String sensorData = "";
        sensorData += "LUX:" + String(currentLux, 1) + ",";
        sensorData += "TVOC:" + String(currentTVOC) + ",";
        sensorData += "ECO2:" + String(currentECO2) + ",";
        sensorData += "TYPING_IDLE:" + String(noTypingSec);
        
        pSensorCharacteristic->setValue(sensorData.c_str());
        pSensorCharacteristic->notify();
    }
}

// ==== BLE命令处理 ====
void handleBLECommand(String command) {
    Serial.println("📱 Received BLE command: " + command);
    
    if (command == "START") {
        startPomodoro();
    } else if (command == "PAUSE") {
        pausePomodoro();
    } else if (command == "RESUME") {
        resumePomodoro();
    } else if (command == "STOP") {
        stopPomodoro();
    } else if (command.startsWith("SET_FOCUS,")) {
        int seconds = command.substring(10).toInt();
        focusTimeMs = seconds * 1000UL;
        Serial.println("📱 Focus time set to: " + String(seconds) + "s");
    } else if (command.startsWith("SET_BREAK,")) {
        int seconds = command.substring(10).toInt();
        breakTimeMs = seconds * 1000UL;
        Serial.println("📱 Break time set to: " + String(seconds) + "s");
    } else if (command.startsWith("SET_ROUNDS,")) {  // 新增轮数处理
        int rounds = command.substring(11).toInt();
        totalRounds = rounds;
        Serial.println("📱 Total rounds set to: " + String(rounds));
    } else if (command == "GET_STATUS") {
        sendStatus();
    } else if (command == "GET_SENSORS") {
        sendSensorData();
    } else if (command == "MOVE_FORWARD") {
        moveForward(1000);
        Serial.println("📱 Manual move forward via BLE");
    }
}
// ==== BLE回调类 ====
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        deviceConnected = true;
        Serial.println("📱 BLE Device connected");
    };

    void onDisconnect(BLEServer* pServer) {
        deviceConnected = false;
        Serial.println("📱 BLE Device disconnected");
    }
};

class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        String value = pCharacteristic->getValue().c_str();
        handleBLECommand(value);
    }
};

// ==== BLE初始化 ====
void initBLE() {
    Serial.println("📡 Initializing BLE...");
    
    BLEDevice::init("PomoBot");
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());

    BLEService *pService = pServer->createService(SERVICE_UUID);

    // 命令特征值
    pCommandCharacteristic = pService->createCharacteristic(
                        COMMAND_CHAR_UUID,
                        BLECharacteristic::PROPERTY_READ |
                        BLECharacteristic::PROPERTY_WRITE
                      );
    pCommandCharacteristic->setCallbacks(new MyCallbacks());

    // 状态特征值
    pStatusCharacteristic = pService->createCharacteristic(
                             STATUS_CHAR_UUID,
                             BLECharacteristic::PROPERTY_READ |
                             BLECharacteristic::PROPERTY_NOTIFY
                           );
    pStatusCharacteristic->addDescriptor(new BLE2902());

    // 传感器数据特征值
    pSensorCharacteristic = pService->createCharacteristic(
                             SENSOR_CHAR_UUID,
                             BLECharacteristic::PROPERTY_READ |
                             BLECharacteristic::PROPERTY_NOTIFY
                           );
    pSensorCharacteristic->addDescriptor(new BLE2902());

    pService->start();
    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(false);
    pAdvertising->setMinPreferred(0x0);
    BLEDevice::startAdvertising();
    Serial.println("📡 BLE advertising started - Device name: PomoBot");
}

// ==== 原有函数 - 保持不变 ====
void moveForward(int durationMs) {
    digitalWrite(AIN1, HIGH); digitalWrite(AIN2, LOW);
    digitalWrite(BIN1, HIGH); digitalWrite(BIN2, LOW);
    analogWrite(PWMA, 180); analogWrite(PWMB, 180);
    delay(durationMs);
    stopMotors();
}

void moveBackward(int durationMs) {
    digitalWrite(AIN1, LOW); digitalWrite(AIN2, HIGH);
    digitalWrite(BIN1, LOW); digitalWrite(BIN2, HIGH);
    analogWrite(PWMA, 180); analogWrite(PWMB, 180);
    delay(durationMs);
    stopMotors();
}

void stopMotors() { 
    analogWrite(PWMA, 0); 
    analogWrite(PWMB, 0); 
}

void playMp3(uint16_t fileNum) {
    player.playFileNum(fileNum);
}

void drawCenteredStr(int y, const char* txt) {
    int w = u8g2.getUTF8Width(txt);
    int x = (SCREEN_WIDTH - w) / 2;
    u8g2.drawUTF8(x, y, txt);
}

void showCenteredText(const char* text) {
    char buf[128]; 
    strncpy(buf, text, sizeof(buf)); 
    buf[127] = '\0';
    const char* lines[4]; 
    int n = 0;
    char* tok = strtok(buf, "\n");
    while (tok && n < 4) { 
        lines[n++] = tok; 
        tok = strtok(NULL, "\n"); 
    }
    u8g2.clearBuffer(); 
    u8g2.setFont(u8g2_font_helvB12_tr);
    int lineSpacing = 16; 
    int totalH = (n - 1) * lineSpacing; 
    int sy = (SCREEN_HEIGHT - totalH) / 2;
    for (int i = 0; i < n; i++) 
        drawCenteredStr(sy + i * lineSpacing, lines[i]);
    u8g2.sendBuffer();
}

void displayCountdown(PomodoroState st, unsigned long remMs) {
    char ts[6]; 
    unsigned int sec = remMs / 1000UL; 
    sprintf(ts, "%02d:%02d", sec / 60, sec % 60);
    u8g2.clearBuffer();
    u8g2.setFont(u8g2_font_helvB10_tr); 
    drawCenteredStr(16, (st == FOCUS) ? "Focus" : "Break");
    u8g2.setFont(u8g2_font_fub20_tr);  
    drawCenteredStr(42, ts);
    u8g2.setFont(u8g2_font_helvB08_tr); 
    char rs[16]; 
    sprintf(rs, "Round %d/%d", pomodoroRound + 1, totalRounds); 
    drawCenteredStr(60, rs);
    u8g2.sendBuffer();
}

void updateDisplay() {
    unsigned long now = millis();
    unsigned long winDur = showingCountdown ? COUNTDOWN_WINDOW_MS : EYE_WINDOW_MS;
    if (now - displaySwitchTime >= winDur) { 
        showingCountdown = !showingCountdown; 
        displaySwitchTime = now; 
        lastCountdownUpdate = 0; 
    }
    if (showingCountdown) {
        if (now - lastCountdownUpdate >= 1000UL) {
            lastCountdownUpdate = now;
            unsigned long dur = (currentState == FOCUS) ? focusTimeMs : breakTimeMs;
            unsigned long rem = (now - stateStartTime >= dur) ? 0 : dur - (now - stateStartTime);
            displayCountdown(currentState, rem);
        }
    } else {
        drawEyesFrame(now - displaySwitchTime); 
        delay(50);
    }
}

void drawEyesFrame(unsigned long phaseMs) {
    unsigned long bp = phaseMs % BLINK_PERIOD_MS; 
    int ry = eyeRadiusY;
    if (bp < BLINK_DUR_MS) {
        float p = bp / (float)BLINK_DUR_MS;
        if      (p < 0.25f) ry = eyeRadiusY - (int)((eyeRadiusY - 6) * (p / 0.25f));
        else if (p < 0.50f) ry = 6 - (int)((6 - 2) * ((p - 0.25f) / 0.25f));
        else if (p < 0.75f) ry = 2  + (int)((6 - 2) * ((p - 0.50f) / 0.25f));
        else                ry = 6 + (int)((eyeRadiusY - 6) * ((p - 0.75f) / 0.25f));
    }
    drawEyes(ry);
}

void drawEyes(int radY) {
    u8g2.clearBuffer();
    int lx = eyeCenterX - eyeGap / 2;
    int rx = eyeCenterX + eyeGap / 2;
    drawEye(lx, eyeCenterY, eyeRadiusX, radY);
    drawEye(rx, eyeCenterY, eyeRadiusX, radY);
    u8g2.sendBuffer();
}

void drawEye(int cx, int cy, int rx, int ry) {
    u8g2.setDrawColor(1);
    if (ry >= 3) {
        for (int y = -ry; y <= ry; y++) {
            int w = (int)(rx * sqrtf(1.0f - (float)y * y / (ry * ry)));
            u8g2.drawHLine(cx - w, cy + y, 2 * w);
        }
    } else {
        u8g2.drawBox(cx - rx, cy - 1, rx * 2, 3);
    }
}

void initI2S() {
    i2s_config_t cfg = {
        .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_RX),
        .sample_rate = EI_RATE,
        .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
        .channel_format = I2S_CHANNEL_FMT_ONLY_LEFT,
        .communication_format = I2S_COMM_FORMAT_I2S_MSB,
        .intr_alloc_flags = 0,
        .dma_buf_count = 4,
        .dma_buf_len = 512,
    };
    i2s_pin_config_t pins = {
        .bck_io_num   = I2S_SCK,
        .ws_io_num    = I2S_WS,
        .data_out_num = I2S_PIN_NO_CHANGE,
        .data_in_num  = I2S_SD
    };
    i2s_driver_install(I2S_NUM_0, &cfg, 0, NULL);
    i2s_set_pin(I2S_NUM_0, &pins);
}

int get_data(size_t off, size_t len, float *out) {
    for (size_t i = 0; i < len; i++) out[i] = (float)audioBuf[off+i];
    return 0;
}

// ==== Setup函数 ====
void setup() {
    Serial.begin(115200);
    delay(1000);
    Serial.println("=== PomoBot with BLE Starting ===");

    // 先初始化BLE
    initBLE();

    // Pomodoro硬件
    pinMode(buttonPin, INPUT_PULLUP);
    pinMode(AIN1, OUTPUT); pinMode(AIN2, OUTPUT); pinMode(PWMA, OUTPUT);
    pinMode(BIN1, OUTPUT); pinMode(BIN2, OUTPUT); pinMode(PWMB, OUTPUT);
    pinMode(STBY, OUTPUT); digitalWrite(STBY, HIGH);

    // OLED
    u8g2.begin();
    showCenteredText("BLE Ready\nPress Button\nor Use App");

    // I2S麦克风
    initI2S();
    eiSignal.total_length = WIN_LEN;
    eiSignal.get_data     = &get_data;
    Serial.println("🔊 Typing detector ready.");

    // DFPlayer Pro
    dfSerial.begin(115200, SERIAL_8N1, 16, 17);
    if (!player.begin(dfSerial)) {
        Serial.println("❌ DFPlayer Pro init failed!");
        showCenteredText("DFPlayer\nFailed");
        delay(2000);
        // 不要卡死，继续运行其他功能
    } else {
        player.setVol(10);
        player.switchFunction(player.MUSIC);
        player.setPlayMode(player.SINGLE);
        Serial.println("🎵 DFPlayer Pro ready.");
    }

    // VEML7700 & SGP30 初始化
    Wire.begin(21, 22);
    if (!veml.begin()) {
        Serial.println("❌ VEML7700 sensor not found!");
        showCenteredText("VEML7700\nNot Found");
        delay(2000);
    } else {
        veml.setGain(VEML7700_GAIN_1);
        veml.setIntegrationTime(VEML7700_IT_100MS);
        Serial.println("✅ VEML7700 ready");
    }

    if (!sgp.begin(&Wire)) {
        Serial.println("❌ SGP30 not found!");
        showCenteredText("SGP30\nNot Found");
        delay(2000);
    } else {
        if (!sgp.IAQinit()) {
            Serial.println("❌ SGP30 IAQ init failed!");
        } else {
            Serial.print("✅ SGP30 ready, serial #");
            Serial.print(sgp.serialnumber[0], HEX);
            Serial.print(sgp.serialnumber[1], HEX);
            Serial.println(sgp.serialnumber[2], HEX);
        }
    }

    Serial.println("=== Setup Complete ===");
    Serial.println("📡 BLE Device Name: PomoBot");
    Serial.println("🔘 Physical button still works");
    Serial.println("📱 App control available");
    
    showCenteredText("All Ready!\nButton or App\nto Start");
    delay(2000);
    showCenteredText("Press Button\nor Use App");
}

// ==== 主循环 - 保持原有逻辑，添加BLE功能 ====
void loop() {
    // BLE连接管理
    if (!deviceConnected && oldDeviceConnected) {
        delay(500);
        pServer->startAdvertising();
        Serial.println("📡 Restart BLE advertising");
        oldDeviceConnected = deviceConnected;
    }
    if (deviceConnected && !oldDeviceConnected) {
        oldDeviceConnected = deviceConnected;
        Serial.println("📱 App connected!");
    }

    // 定期发送状态和传感器数据到App
    static unsigned long lastStatusUpdate = 0;
    if (deviceConnected && millis() - lastStatusUpdate > 2000) {
        sendStatus();
        lastStatusUpdate = millis();
    }

    if (deviceConnected && millis() - lastSensorDataSend > SENSOR_SEND_INTERVAL) {
        sendSensorData();
        lastSensorDataSend = millis();
    }

    // ========== 原有按钮逻辑（保持不变）==========
    static bool pomodoroStarted = false;
    if (!pomodoroRunning && digitalRead(buttonPin) == HIGH && !pomodoroStarted) {
        delay(20);
        if (digitalRead(buttonPin) == HIGH) {
            pomodoroRunning = true;
            currentState = FOCUS; 
            stateStartTime = millis(); 
            pomodoroRound = 0;
            showingCountdown = true; 
            displaySwitchTime = millis(); 
            lastCountdownUpdate = 0;
            showCenteredText("Pomodoro\nStarted!");
            Serial.println("🍅 Pomodoro started via button");
            delay(1000);
            pomodoroStarted = true;
            lastLightCheck = millis();
            lastAirCheck = millis();
        }
    }
    if (digitalRead(buttonPin) == LOW) pomodoroStarted = false;

    // ========== 原有Typing检测逻辑（保持不变）==========
    if (pomodoroRunning && currentState == FOCUS && !pomotoroPaused) {
        if (millis() - lastTypingCheck >= 1000) {
            lastTypingCheck = millis();

            size_t rb = 0, off = 0;
            while (off < WIN_LEN) {
                i2s_read(I2S_NUM_0, audioBuf+off, (WIN_LEN-off)*sizeof(int16_t), &rb, portMAX_DELAY);
                off += rb/2;
            }
            
            ei_impulse_result_t r;
            if (run_classifier(&eiSignal, &r, false) == EI_IMPULSE_OK) {
                float typingProb = r.classification[1].value;
                Serial.printf("typingProb: %.2f | idleSec: %u\n", typingProb, noTypingSec);

                if (typingProb < 0.7) {
                    noTypingSec++;
                } else {
                    noTypingSec = 0;
                }
                
                if (noTypingSec >= 180) {
                    noTypingSec = 0;
                    playMp3(3);
                    Serial.println("🔔 Play typing reminder");
                }
            }
        }
    } else {
        noTypingSec = 0;
    }

    // ========== 原有Pomodoro主循环（保持不变）==========
    if (pomodoroRunning && !pomotoroPaused) {
        unsigned long now = millis();
        unsigned long elapsed = now - stateStartTime;
        unsigned long dur = (currentState == FOCUS) ? focusTimeMs : breakTimeMs;

        if (elapsed >= dur) {
            if (currentState == FOCUS) {
                currentState = BREAK;
                showCenteredText("Start\nBreak!");
                playMp3(1);
                delay(1000);
            } else {
                pomodoroRound++;
                if (pomodoroRound >= totalRounds) {
                    pomodoroRunning = false;
                    currentState = IDLE;
                    showCenteredText("Session\nComplete!");
                    playMp3(6);
                    delay(2000);
                    showCenteredText("Press Button\nor Use App");
                    return;
                }
                currentState = FOCUS;
                showCenteredText("Start\nFocus!");
                playMp3(4);
                delay(1000);
            }
            stateStartTime = now;
            showingCountdown = true; 
            displaySwitchTime = now; 
            lastCountdownUpdate = 0; 
            lastMoveTime = now;
        }
        updateDisplay();

        if (currentState == BREAK && now - lastMoveTime >= 30000UL) {
    if (moveForwardNext) {
        moveForward(1000);   // 第一次、第三次……
    } else {
        moveBackward(1000);  // 第二次、第四次……
    }
    moveForwardNext = !moveForwardNext;  // 每次翻转
    lastMoveTime = now;
}
        


        // ========== 原有传感器检测逻辑（保持不变）==========
        if (now - lastLightCheck >= SENSOR_INTERVAL) {
            lastLightCheck = now;
            currentLux = veml.readLux();
            Serial.print("Lux: "); Serial.println(currentLux);
            if (currentLux < 100) {
                showCenteredText("Low light\nTake care of\nyour eyes");
                delay(3000);
            }
        }

        if (now - lastAirCheck >= SENSOR_INTERVAL) {
            lastAirCheck = now;
            if (sgp.IAQmeasure()) {
                currentTVOC = sgp.TVOC;
                currentECO2 = sgp.eCO2;
                Serial.print("TVOC: "); Serial.print(currentTVOC); Serial.print(" ppb\t");
                Serial.print("eCO2: "); Serial.print(currentECO2); Serial.println(" ppm");
                if (currentTVOC > 800 || currentECO2 > 1000) {
                    showCenteredText("Air not fresh\nopen a window");
                    delay(3000);
                }
            } else {
                Serial.println("SGP30 Measurement failed");
            }
        }
    } else if (pomodoroRunning && pomotoroPaused) {
        // 暂停状态显示
        static unsigned long lastPauseUpdate = 0;
        if (millis() - lastPauseUpdate > 1000) {
            showCenteredText("PAUSED\n\nUse App\nto Resume");
            lastPauseUpdate = millis();
        }
    } else {
        // 空闲状态也读取传感器数据（用于App显示）
        unsigned long now = millis();
        if (now - lastLightCheck >= SENSOR_INTERVAL) {
            lastLightCheck = now;
            currentLux = veml.readLux();
        }
        if (now - lastAirCheck >= SENSOR_INTERVAL) {
            lastAirCheck = now;
            if (sgp.IAQmeasure()) {
                currentTVOC = sgp.TVOC;
                currentECO2 = sgp.eCO2;
            }
        }
    }
}
# PomoBot 🤖 — Your Desk Companion
Meet PomoBot — your tiny desk companion that helps you stay on track with the Pomodoro Technique🍅, keeping you focused and productive all day.  

<img src="src/cover_1.jpg" alt="" width="400" >  

Introduction Video: https://youtu.be/2wCO7o7NCIg

# 🌟 Features
### * ⏱️ Pomodoro Timer.  
<img src="src/time_setting.jpg" alt="" width="300"> <img src="src/cover_2.jpg" alt="" width="270">  
<br>25 minutes of focus time and 5 minutes of break time. You can also customize the duration and number of rounds through the app.  

### * 🤝 Desk Companion
<img src="src/cover_3.jpg" alt="" width="400" >
  <br>During focus time, it stays quietly by your side. During breaks, it moves around to remind you to relax and take a short rest.  

### * ⌨️ Typing Activity Detection
<img src="src/typing.jpg" alt="" width="350" >
  <br>Built-in machine learning detects typing sounds. If no activity is detected for a while, it gently prompts you to get back on track.  

### * 🌱 Study Environment Monitoring
<img src="src/sensors.jpg" alt="" width="300" > <img src="src/cover_light.jpg" alt="" width="300" > <img src="src/cover_air.jpg" alt="" width="300" >
  <br>A light sensor ensures proper brightness, while a CO₂ sensor alerts you when it’s time to open a window.

# Installation
## Hardware  
### 1. Circuit Design  
* Microcontroller:  ESP32
* Sensors:
  <br>VEML7700 Light Sensor
  <br>SGP30 eCO₂ & TVOC Air Quality Sensor
  <br>INMP441 Microphone (for typing sound detection)
* Actuators:
  <br>N20 DC Motor (for movement)
  <br>TB6612 Motor Driver
  <br>Speaker (for gentle alerts or reminders)
* Display: SD1309 OLED Screen
* Inputs: Push Button
 #### Circuit Diagram
<img src="src/curcuit.jpg" alt="" width="400">

### 2. Machine Learning Model
<br>Detects typing activity based on sound
<br>Input: Audio from microphone
<br>Output: “Typing” or “Not Typing”
<br>Link: https://studio.edgeimpulse.com/studio/716593

## Software  
* Download the latest APK release directly from the [Releases](https://github.com/yingwuhola/Pomobot/releases) pages.  
* Install the APK on your Android device. 


<img src="src/app_1.jpg" alt="" width="200"> <img src="src/app_2.jpg" alt="" width="200"> <img src="src/app_3.jpg" alt="" width="200"> <img src="src/app_4.jpg" alt="" width="200"> <img src="src/app_5.jpg" alt="" width="200"> <img src="src/app_6.jpg" alt="" width="200">
* BLE Bluetooth Connection
* Pomodoro Start/Pause Control
* Custom Time Settings
* Environment Data Monitoring

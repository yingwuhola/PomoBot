import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'bluetooth_service.dart';

class PomodoroPage extends StatefulWidget {
  @override
  _PomodoroPageState createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage> 
    with TickerProviderStateMixin {
  
  // Pomodoro status
  String currentState = "IDLE";
  bool isRunning = false;
  bool isPaused = false;
  int remainingSeconds = 0;
  String currentRound = "1/4";

  // Settings
  int focusMinutes = 3;
  int breakMinutes = 1;
  int totalRounds = 4;

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initAnimations();
    _listenToBluetoothStatus();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
  }

  void _listenToBluetoothStatus() {
    // 监听状态更新
    PomodoroBluetoothService().statusStream.listen((status) {
      if (mounted) {
        setState(() {
          currentState = _getStateName(int.tryParse(status['STATE'] ?? '0') ?? 0);
          isRunning = status['RUNNING'] == '1';
          isPaused = status['PAUSED'] == '1';
          currentRound = status['ROUND'] ?? '1/4';
          remainingSeconds = int.tryParse(status['REMAINING'] ?? '0') ?? 0;
        });
      }
    });
    
    // 监听连接状态变化
    PomodoroBluetoothService().connectionStream.listen((connected) {
      print("Connection status changed: $connected");
      if (mounted) {
        // 强制刷新整个页面
        setState(() {});
        
        if (!connected) {
          // 断开连接时重置状态
          setState(() {
            currentState = "IDLE";
            isRunning = false;
            isPaused = false;
            remainingSeconds = 0;
            currentRound = "1/4";
          });
          _showSnackBar("Disconnected from robot");
        } else {
          _showSnackBar("Connected to robot");
        }
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      focusMinutes = prefs.getInt('focus_minutes') ?? 3;
      breakMinutes = prefs.getInt('break_minutes') ?? 1;
      totalRounds = prefs.getInt('total_rounds') ?? 4;
    });
  }

  _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('focus_minutes', focusMinutes);
    await prefs.setInt('break_minutes', breakMinutes);
    await prefs.setInt('total_rounds', totalRounds);
  }

  String _getStateName(int state) {
    switch (state) {
      case 0: return "IDLE";
      case 1: return "FOCUS";
      case 2: return "BREAK";
      default: return "UNKNOWN";
    }
  }

  _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Pomodoro Robot', 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.red[600],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              PomodoroBluetoothService().isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
              color: Colors.white,
            ),
            onPressed: PomodoroBluetoothService().isConnected 
                ? () => PomodoroBluetoothService().disconnect() 
                : _showConnectionDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildConnectionCard(),
            SizedBox(height: 16),
            _buildPomodoroCard(),
            SizedBox(height: 16),
            _buildControlButtons(),
            SizedBox(height: 16),
            _buildSettingsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard() {
    // 直接使用PomodoroBluetoothService的isConnected状态
    bool isConnected = PomodoroBluetoothService().isConnected;
    
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isConnected 
                ? [Colors.green[400]!, Colors.green[600]!]
                : [Colors.grey[400]!, Colors.grey[600]!],
          ),
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: isConnected ? _pulseAnimation.value : 1.0,
                  child: Icon(
                    isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                    size: 40,
                    color: Colors.white,
                  ),
                );
              },
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isConnected ? 'Connected' : 'Not Connected',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    isConnected ? 'Robot is ready' : 'Tap to connect',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
            if (!isConnected)
              GestureDetector(
                onTap: _showConnectionDialog,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Connect',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPomodoroCard() {
    return Card(
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: EdgeInsets.all(32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: currentState == "FOCUS" 
                ? [Colors.red[400]!, Colors.red[700]!]
                : currentState == "BREAK"
                ? [Colors.green[400]!, Colors.green[700]!]
                : [Colors.blue[400]!, Colors.blue[700]!],
          ),
        ),
        child: Column(
          children: [
            Icon(
              currentState == "FOCUS" ? Icons.work : 
              currentState == "BREAK" ? Icons.coffee : Icons.home,
              size: 48,
              color: Colors.white,
            ),
            SizedBox(height: 16),
            Text(
              currentState == "FOCUS" ? "Focus Time" : 
              currentState == "BREAK" ? "Break Time" : "Ready",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 20),
            Text(
              _formatTime(remainingSeconds),
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'monospace',
              ),
            ),
            SizedBox(height: 12),
            Text(
              "Round $currentRound",
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
            if (isPaused)
              Container(
                margin: EdgeInsets.only(top: 16),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "PAUSED",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: Icons.play_arrow,
              label: "Start",
              color: Colors.green,
              onPressed: PomodoroBluetoothService().isConnected && !isRunning ? () {
                PomodoroBluetoothService().sendCommand("START");
                Future.delayed(Duration(milliseconds: 500), () {
                  PomodoroBluetoothService().sendCommand("GET_STATUS");
                });
              } : null,
            ),
            _buildControlButton(
              icon: isPaused ? Icons.play_arrow : Icons.pause,
              label: isPaused ? "Resume" : "Pause",
              color: Colors.orange,
              onPressed: PomodoroBluetoothService().isConnected && isRunning 
                  ? () => PomodoroBluetoothService().sendCommand(isPaused ? "RESUME" : "PAUSE") 
                  : null,
            ),
            _buildControlButton(
              icon: Icons.stop,
              label: "Stop",
              color: Colors.red,
              onPressed: PomodoroBluetoothService().isConnected && isRunning 
                  ? () => PomodoroBluetoothService().sendCommand("STOP") 
                  : null,
            ),
          ],
        ),
        SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: PomodoroBluetoothService().isConnected 
                ? () => PomodoroBluetoothService().sendCommand("MOVE_FORWARD") 
                : null,
            icon: Icon(Icons.directions_walk),
            label: Text("Move Robot"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: onPressed != null ? color : Colors.grey[300],
            foregroundColor: Colors.white,
            shape: CircleBorder(),
            padding: EdgeInsets.all(24),
            elevation: 8,
          ),
          child: Icon(icon, size: 32),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: onPressed != null ? color : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.purple[600], size: 28),
                SizedBox(width: 12),
                Text("Time Settings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 20),
            _buildTimeSetting("Focus Time", focusMinutes, (value) {
              setState(() { focusMinutes = value; });
              _saveSettings();
              PomodoroBluetoothService().sendCommand("SET_FOCUS,${value * 60}");
            }),
            SizedBox(height: 20),
            _buildTimeSetting("Break Time", breakMinutes, (value) {
              setState(() { breakMinutes = value; });
              _saveSettings();
              PomodoroBluetoothService().sendCommand("SET_BREAK,${value * 60}");
            }),
            SizedBox(height: 20),
            _buildRoundSetting("Total Rounds", totalRounds, (value) {
              setState(() { totalRounds = value; });
              _saveSettings();
              PomodoroBluetoothService().sendCommand("SET_ROUNDS,$value");
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSetting(String label, int value, Function(int) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        Row(
          children: [
            IconButton(
              onPressed: value > 1 ? () => onChanged(value - 1) : null,
              icon: Icon(Icons.remove_circle_outline, color: Colors.red),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text("$value min", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              onPressed: value < 60 ? () => onChanged(value + 1) : null,
              icon: Icon(Icons.add_circle_outline, color: Colors.green),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoundSetting(String label, int value, Function(int) onChanged) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: value > 1 ? () => onChanged(value - 1) : null,
                  icon: Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                  iconSize: 20,
                  constraints: BoxConstraints(minWidth: 30, minHeight: 30),
                  padding: EdgeInsets.all(4),
                ),
                Container(
                  width: 40,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Center(
                    child: Text(
                      "$value", 
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: value < 10 ? () => onChanged(value + 1) : null,
                  icon: Icon(Icons.add_circle_outline, color: Colors.green, size: 20),
                  iconSize: 20,
                  constraints: BoxConstraints(minWidth: 30, minHeight: 30),
                  padding: EdgeInsets.all(4),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  _showConnectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.bluetooth_searching, color: Colors.blue),
                  SizedBox(width: 12),
                  Text("Connect to Robot"),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                height: 350,
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: PomodoroBluetoothService().isScanning ? null : () async {
                          setDialogState(() {});
                          try {
                            await PomodoroBluetoothService().requestPermissions();
                            await PomodoroBluetoothService().startScan();
                            // 每秒刷新UI来显示新发现的设备
                            Timer.periodic(Duration(seconds: 1), (timer) {
                              if (!PomodoroBluetoothService().isScanning) {
                                timer.cancel();
                              } else {
                                setDialogState(() {});
                              }
                            });
                          } catch (e) {
                            _showSnackBar("Scan failed: $e");
                          }
                        },
                        icon: PomodoroBluetoothService().isScanning 
                            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(Icons.search),
                        label: Text(PomodoroBluetoothService().isScanning ? "Scanning..." : "Start Scan"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    if (PomodoroBluetoothService().isScanning)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          "Looking for devices...",
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ),
                    SizedBox(height: 16),
                    Expanded(
                      child: PomodoroBluetoothService().foundDevices.isEmpty 
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    PomodoroBluetoothService().isScanning ? "Scanning..." : "No devices found",
                                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                  ),
                                  if (!PomodoroBluetoothService().isScanning) ...[
                                    SizedBox(height: 8),
                                    Text(
                                      "Make sure your robot is powered on\nand click 'Start Scan'",
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: PomodoroBluetoothService().foundDevices.length,
                              itemBuilder: (context, index) {
                                fbp.BluetoothDevice device = PomodoroBluetoothService().foundDevices[index];
                                return Card(
                                  margin: EdgeInsets.symmetric(vertical: 2),
                                  child: ListTile(
                                    leading: Icon(Icons.bluetooth, color: Colors.blue),
                                    title: Text(
                                      device.platformName.isNotEmpty 
                                          ? device.platformName 
                                          : "Unknown Device",
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      device.remoteId.toString(),
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    ),
                                    trailing: Icon(Icons.arrow_forward_ios, size: 16),
                                    onTap: () async {
                                      Navigator.of(context).pop();
                                      try {
                                        await PomodoroBluetoothService().connectToDevice(device);
                                        _showSnackBar("Connected successfully!");
                                        // 强制刷新页面状态
                                        setState(() {});
                                      } catch (e) {
                                        _showSnackBar("Connection failed: $e");
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    PomodoroBluetoothService().stopScan();
                    Navigator.of(context).pop();
                  },
                  child: Text("Cancel"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
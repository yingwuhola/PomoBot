import 'package:flutter/material.dart';
import 'bluetooth_service.dart';

class SensorsPage extends StatefulWidget {
  @override
  _SensorsPageState createState() => _SensorsPageState();
}

class _SensorsPageState extends State<SensorsPage> {
  // Sensor data
  double currentLux = 0.0;
  int currentTVOC = 0;
  int currentECO2 = 0;
  int typingIdleSeconds = 0;

  @override
  void initState() {
    super.initState();
    _listenToSensorData();
  }

  void _listenToSensorData() {
    PomodoroBluetoothService().sensorStream.listen((sensorData) {
      if (mounted) {
        setState(() {
          currentLux = double.tryParse(sensorData['LUX'] ?? '0') ?? 0.0;
          currentTVOC = int.tryParse(sensorData['TVOC'] ?? '0') ?? 0;
          currentECO2 = int.tryParse(sensorData['ECO2'] ?? '0') ?? 0;
          typingIdleSeconds = int.tryParse(sensorData['TYPING_IDLE'] ?? '0') ?? 0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Environment Sensors', 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.blue[600],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildConnectionStatus(),
            SizedBox(height: 20),
            _buildSensorCard(),
            SizedBox(height: 20),
            _buildDetailedSensorCards(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: PomodoroBluetoothService().isConnected 
                ? [Colors.green[400]!, Colors.green[600]!]
                : [Colors.grey[400]!, Colors.grey[600]!],
          ),
        ),
        child: Row(
          children: [
            Icon(
              PomodoroBluetoothService().isConnected ? Icons.sensors : Icons.sensors_off,
              size: 40,
              color: Colors.white,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    PomodoroBluetoothService().isConnected ? 'Sensors Active' : 'Sensors Offline',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    PomodoroBluetoothService().isConnected 
                        ? 'Real-time data available' 
                        : 'Connect to robot first',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCard() {
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
                Icon(Icons.dashboard, color: Colors.blue[600], size: 28),
                SizedBox(width: 12),
                Text(
                  "Sensor Overview",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildSensorItem("Light", "${currentLux.toStringAsFixed(1)} lux", 
                    Icons.wb_sunny, _getLightColor(currentLux)),
                _buildSensorItem("Air Quality", "$currentTVOC ppb", 
                    Icons.air, _getAirQualityColor(currentTVOC)),
                _buildSensorItem("CO2", "$currentECO2 ppm", 
                    Icons.cloud, _getCO2Color(currentECO2)),
                _buildSensorItem("Typing", "${typingIdleSeconds}s idle", 
                    Icons.keyboard, _getTypingColor(typingIdleSeconds)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedSensorCards() {
    return Column(
      children: [
        _buildDetailedSensorCard(
          "Light Sensor",
          Icons.wb_sunny,
          currentLux,
          "lux",
          _getLightColor(currentLux),
          _getLightDescription(currentLux),
          Colors.amber,
        ),
        SizedBox(height: 16),
        _buildDetailedSensorCard(
          "Air Quality (TVOC)",
          Icons.air,
          currentTVOC.toDouble(),
          "ppb",
          _getAirQualityColor(currentTVOC),
          _getAirQualityDescription(currentTVOC),
          Colors.green,
        ),
        SizedBox(height: 16),
        _buildDetailedSensorCard(
          "CO2 Level",
          Icons.cloud,
          currentECO2.toDouble(),
          "ppm",
          _getCO2Color(currentECO2),
          _getCO2Description(currentECO2),
          Colors.blue,
        ),
        SizedBox(height: 16),
        _buildTypingCard(),
      ],
    );
  }

  Widget _buildDetailedSensorCard(
    String title,
    IconData icon,
    double value,
    String unit,
    Color statusColor,
    String description,
    Color cardColor,
  ) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [cardColor.withOpacity(0.1), cardColor.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: cardColor, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            "${value.toStringAsFixed(1)} $unit",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: statusColor, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.purple.withOpacity(0.1), Colors.purple.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.keyboard, color: Colors.purple, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Typing Activity",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            "${typingIdleSeconds}s",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _getTypingColor(typingIdleSeconds),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            "idle",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getTypingColor(typingIdleSeconds),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            LinearProgressIndicator(
              value: (typingIdleSeconds / 60).clamp(0.0, 1.0),
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(_getTypingColor(typingIdleSeconds)),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getTypingColor(typingIdleSeconds).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getTypingColor(typingIdleSeconds).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: _getTypingColor(typingIdleSeconds), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getTypingDescription(typingIdleSeconds),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Color and description helper methods
  Color _getLightColor(double lux) {
    if (lux < 100) return Colors.orange;
    if (lux < 500) return Colors.yellow[700]!;
    return Colors.green;
  }

  Color _getAirQualityColor(int tvoc) {
    if (tvoc > 800) return Colors.red;
    if (tvoc > 400) return Colors.orange;
    return Colors.green;
  }

  Color _getCO2Color(int eco2) {
    if (eco2 > 1000) return Colors.red;
    if (eco2 > 600) return Colors.orange;
    return Colors.green;
  }

  Color _getTypingColor(int idleSeconds) {
    if (idleSeconds > 20) return Colors.orange;
    if (idleSeconds > 10) return Colors.yellow[700]!;
    return Colors.green;
  }

  String _getLightDescription(double lux) {
    if (lux < 100) return "Too dark - consider turning on lights";
    if (lux < 500) return "Adequate lighting for work";
    return "Excellent lighting conditions";
  }

  String _getAirQualityDescription(int tvoc) {
    if (tvoc > 800) return "Poor air quality - ventilate the room";
    if (tvoc > 400) return "Moderate air quality";
    return "Good air quality";
  }

  String _getCO2Description(int eco2) {
    if (eco2 > 1000) return "High CO2 - open windows for fresh air";
    if (eco2 > 600) return "Moderate CO2 levels";
    return "Low CO2 - good ventilation";
  }

  String _getTypingDescription(int idleSeconds) {
    if (idleSeconds > 20) return "Long idle time - take a break or stretch";
    if (idleSeconds > 10) return "Moderate activity";
    return "Active typing detected";
  }
}
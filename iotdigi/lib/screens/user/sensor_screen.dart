import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class SensorScreen extends StatefulWidget {
  const SensorScreen({super.key});

  @override
  State<SensorScreen> createState() => _SensorScreenState();
}

class _SensorScreenState extends State<SensorScreen> {
  double _temperature = 0.0;
  double _humidity = 0.0;
  final bool _isGasDetected = false;
  bool _isConnected = false;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _timer;
  List<Map<String, dynamic>> _sensorHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchSensorData();
    // Fetch data every 5 seconds
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchSensorData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchSensorData() async {
    if (!_isLoading) {
      setState(() {
        _errorMessage = null;
      });
    }

    try {
      // Replace YOUR_PC_IP_ADDRESS with your computer's local IP address (e.g., 192.168.1.100)
      final response = await http.get(Uri.parse('http://192.168.1.159/iotdigi-main/get.php'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['latest_sensor_reading'] != null) {
          setState(() {
            _temperature = double.parse(data['latest_sensor_reading']['temperature'].toString());
            _humidity = double.parse(data['latest_sensor_reading']['humidity'].toString());
            _isConnected = true;
            _isLoading = false;
            _errorMessage = null;
            _sensorHistory = List<Map<String, dynamic>>.from(data['sensor_readings']);
          });
        } else {
          throw Exception('Invalid data format');
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _isLoading = false;
        _errorMessage = 'Failed to fetch sensor data: ${e.toString()}';
      });
      debugPrint('Error fetching sensor data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchSensorData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConnectionStatus(),
            const SizedBox(height: 24),
            _buildSensorCard(
              title: 'Current Readings',
              child: Column(
                children: [
                  _buildSensorValue(
                    icon: Icons.thermostat,
                    label: 'Temperature',
                    value: '${_temperature.toStringAsFixed(1)}°C',
                  ),
                  const SizedBox(height: 16),
                  _buildSensorValue(
                    icon: Icons.water_drop,
                    label: 'Humidity',
                    value: '${_humidity.toStringAsFixed(1)}%',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSensorCard(
              title: 'Sensor History',
              child: Column(
                children: _sensorHistory.map((reading) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          reading['timestamp'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.thermostat, size: 16, color: Colors.orange),
                            Text(' ${reading['temperature']}°C  '),
                            Icon(Icons.water_drop, size: 16, color: Colors.blue),
                            Text(' ${reading['humidity']}%'),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: _isConnected ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isConnected ? Icons.check_circle : Icons.error,
            color: _isConnected ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            _isConnected ? 'Connected' : 'Disconnected',
            style: TextStyle(
              color: _isConnected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard({required String title, required Widget child}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSensorValue({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
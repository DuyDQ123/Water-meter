import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:convert';

class SensorScreen extends StatefulWidget {
  const SensorScreen({super.key});

  @override
  State<SensorScreen> createState() => _SensorScreenState();
}

class _SensorScreenState extends State<SensorScreen> {
  final client = MqttServerClient('your_mqtt_broker', '');
  double _temperature = 0.0;
  double _humidity = 0.0;
  bool _isGasDetected = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _connectMQTT();
  }

  @override
  void dispose() {
    client.disconnect();
    super.dispose();
  }

  Future<void> _connectMQTT() async {
    client.logging(on: true);
    client.port = 1883;
    client.keepAlivePeriod = 60;
    client.onConnected = _onConnected;
    client.onDisconnected = _onDisconnected;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_client')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    client.connectionMessage = connMessage;

    try {
      await client.connect();
    } catch (e) {
      debugPrint('MQTT connection failed: $e');
      client.disconnect();
    }
  }

  void _onConnected() {
    setState(() => _isConnected = true);
    
    client.subscribe('sensors/dht22', MqttQos.atLeastOnce);
    client.subscribe('sensors/mq2', MqttQos.atLeastOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (var message in messages) {
        final payload = (message.payload as MqttPublishMessage).payload.message;
        final topic = message.topic;
        final data = json.decode(utf8.decode(payload));

        if (topic == 'sensors/dht22') {
          setState(() {
            _temperature = data['temperature'].toDouble();
            _humidity = data['humidity'].toDouble();
          });
        } else if (topic == 'sensors/mq2') {
          setState(() {
            _isGasDetected = data['gas_detected'];
          });
        }
      }
    });
  }

  void _onDisconnected() {
    setState(() => _isConnected = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConnectionStatus(),
          const SizedBox(height: 24),
          _buildSensorCard(
            title: 'Temperature & Humidity',
            child: Column(
              children: [
                _buildSensorValue(
                  icon: Icons.thermostat,
                  label: 'Temperature',
                  value: '$_temperature°C',
                ),
                const SizedBox(height: 16),
                _buildSensorValue(
                  icon: Icons.water_drop,
                  label: 'Humidity',
                  value: '$_humidity%',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSensorCard(
            title: 'Gas Detection',
            child: _buildSensorValue(
              icon: Icons.warning,
              label: 'Gas Status',
              value: _isGasDetected ? 'Gas Detected!' : 'Normal',
              valueColor: _isGasDetected ? Colors.red : Colors.green,
            ),
          ),
        ],
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
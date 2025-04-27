import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:convert';

class Device {
  final String id;
  String name;
  bool isOnline;
  double temperature;
  double humidity;
  bool gasDetected;
  double ledBrightness;

  Device({
    required this.id,
    required this.name,
    this.isOnline = false,
    this.temperature = 0.0,
    this.humidity = 0.0,
    this.gasDetected = false,
    this.ledBrightness = 0.0,
  });
}

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final client = MqttServerClient('your_mqtt_broker', '');
  final List<Device> _devices = [];
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _connectMQTT();
    // Add some sample devices
    _devices.addAll([
      Device(id: 'device1', name: 'ESP32-CAM 1'),
      Device(id: 'device2', name: 'ESP32-CAM 2'),
    ]);
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
        .withClientIdentifier('flutter_admin_client')
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
    
    // Subscribe to all device topics
    client.subscribe('devices/+/status', MqttQos.atLeastOnce);
    client.subscribe('sensors/+/dht22', MqttQos.atLeastOnce);
    client.subscribe('sensors/+/mq2', MqttQos.atLeastOnce);
    client.subscribe('esp32cam/+/led/status', MqttQos.atLeastOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (var message in messages) {
        final payload = (message.payload as MqttPublishMessage).payload.message;
        final topic = message.topic;
        final data = json.decode(utf8.decode(payload));
        
        // Extract device ID from topic
        final deviceId = topic.split('/')[1];
        final device = _devices.firstWhere(
          (d) => d.id == deviceId,
          orElse: () => Device(id: deviceId, name: 'Device $deviceId'),
        );

        if (mounted) {
          setState(() {
            if (topic.endsWith('/status')) {
              device.isOnline = data['online'] ?? false;
            } else if (topic.contains('/dht22')) {
              device.temperature = data['temperature']?.toDouble() ?? 0.0;
              device.humidity = data['humidity']?.toDouble() ?? 0.0;
            } else if (topic.contains('/mq2')) {
              device.gasDetected = data['gas_detected'] ?? false;
            } else if (topic.contains('/led/status')) {
              device.ledBrightness = data['brightness']?.toDouble() ?? 0.0;
            }
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
    return RefreshIndicator(
      onRefresh: _connectMQTT,
      child: Column(
        children: [
          _buildConnectionStatus(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];
                return _buildDeviceCard(device);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: _isConnected ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isConnected ? Icons.check_circle : Icons.error,
            color: _isConnected ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            _isConnected ? 'Connected to MQTT Broker' : 'Disconnected',
            style: TextStyle(
              color: _isConnected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(Device device) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: ExpansionTile(
        leading: Icon(
          Icons.device_hub,
          color: device.isOnline ? Colors.green : Colors.grey,
        ),
        title: Text(device.name),
        subtitle: Text(device.isOnline ? 'Online' : 'Offline'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSensorRow(
                  'Temperature',
                  '${device.temperature.toStringAsFixed(1)}°C',
                  Icons.thermostat,
                ),
                const SizedBox(height: 8),
                _buildSensorRow(
                  'Humidity',
                  '${device.humidity.toStringAsFixed(1)}%',
                  Icons.water_drop,
                ),
                const SizedBox(height: 8),
                _buildSensorRow(
                  'Gas Status',
                  device.gasDetected ? 'Detected!' : 'Normal',
                  Icons.warning,
                  valueColor: device.gasDetected ? Colors.red : Colors.green,
                ),
                const SizedBox(height: 8),
                _buildSensorRow(
                  'LED Brightness',
                  '${device.ledBrightness.round()}%',
                  Icons.lightbulb,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorRow(String label, String value, IconData icon, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(label),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
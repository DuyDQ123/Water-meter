import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:convert';

class LedControlScreen extends StatefulWidget {
  const LedControlScreen({super.key});

  @override
  State<LedControlScreen> createState() => _LedControlScreenState();
}

class _LedControlScreenState extends State<LedControlScreen> {
  final client = MqttServerClient('your_mqtt_broker', '');
  double _brightness = 0.0;
  bool _isConnected = false;
  bool _isSending = false;

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
        .withClientIdentifier('flutter_client_led')
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
    
    // Subscribe to LED status updates
    client.subscribe('esp32cam/led/status', MqttQos.atLeastOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (var message in messages) {
        final payload = (message.payload as MqttPublishMessage).payload.message;
        final data = json.decode(utf8.decode(payload));
        
        if (mounted) {
          setState(() {
            _brightness = data['brightness'].toDouble();
          });
        }
      }
    });
  }

  void _onDisconnected() {
    setState(() => _isConnected = false);
  }

  Future<void> _updateBrightness(double value) async {
    if (!_isConnected || _isSending) return;

    setState(() {
      _brightness = value;
      _isSending = true;
    });

    final builder = MqttClientPayloadBuilder();
    builder.addString(json.encode({
      'brightness': value.round(),
    }));

    client.publishMessage(
      'esp32cam/led/control',
      MqttQos.atLeastOnce,
      builder.payload!,
    );

    // Add a small delay to prevent too many messages
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (mounted) {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConnectionStatus(),
          const SizedBox(height: 32),
          _buildLedControl(),
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

  Widget _buildLedControl() {
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
            Row(
              children: [
                const Icon(Icons.lightbulb),
                const SizedBox(width: 8),
                const Text(
                  'LED Brightness',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_brightness.round()}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Slider(
              value: _brightness,
              min: 0,
              max: 100,
              divisions: 100,
              label: '${_brightness.round()}%',
              onChanged: _isConnected ? _updateBrightness : null,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPresetButton('Off', 0),
                _buildPresetButton('25%', 25),
                _buildPresetButton('50%', 50),
                _buildPresetButton('75%', 75),
                _buildPresetButton('100%', 100),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton(String label, double value) {
    return ElevatedButton(
      onPressed: _isConnected ? () => _updateBrightness(value) : null,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 36),
      ),
      child: Text(label),
    );
  }
}
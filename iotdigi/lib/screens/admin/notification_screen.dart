import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:convert';

class Alert {
  final String deviceId;
  final String type;
  final String message;
  final DateTime timestamp;
  bool isRead;

  Alert({
    required this.deviceId,
    required this.type,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final client = MqttServerClient('your_mqtt_broker', '');
  final List<Alert> _alerts = [];
  bool _isConnected = false;
  // Temporarily removed notifications
  // final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    // _initNotifications();
    _connectMQTT();
  }

  @override
  void dispose() {
    client.disconnect();
    super.dispose();
  }

  // Temporarily removed notifications
  // Future<void> _initNotifications() async {
  //   // Implementation removed
  // }

  // Future<void> _showNotification(Alert alert) async {
  //   // Implementation removed
  // }

  Future<void> _connectMQTT() async {
    client.logging(on: true);
    client.port = 1883;
    client.keepAlivePeriod = 60;
    client.onConnected = _onConnected;
    client.onDisconnected = _onDisconnected;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_admin_notifications')
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
    
    // Subscribe to all alert topics
    client.subscribe('alerts/+/gas', MqttQos.atLeastOnce);
    client.subscribe('alerts/+/fire', MqttQos.atLeastOnce);
    client.subscribe('alerts/+/system', MqttQos.atLeastOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (var message in messages) {
        final payload = (message.payload as MqttPublishMessage).payload.message;
        final topic = message.topic;
        final data = json.decode(utf8.decode(payload));
        
        final parts = topic.split('/');
        final deviceId = parts[1];
        final alertType = parts[2].toUpperCase();

        final alert = Alert(
          deviceId: deviceId,
          type: alertType,
          message: data['message'] ?? 'No message provided',
          timestamp: DateTime.now(),
        );

        if (mounted) {
          setState(() {
            _alerts.insert(0, alert);
          });
          // _showNotification(alert);
        }
      }
    });
  }

  void _onDisconnected() {
    setState(() => _isConnected = false);
  }

  void _markAllAsRead() {
    setState(() {
      for (var alert in _alerts) {
        alert.isRead = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildConnectionStatus(),
          Expanded(
            child: _alerts.isEmpty
                ? const Center(
                    child: Text(
                      'No alerts yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _alerts.length,
                    itemBuilder: (context, index) {
                      final alert = _alerts[index];
                      return _buildAlertCard(alert);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _alerts.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _markAllAsRead,
              label: const Text('Mark all as read'),
              icon: const Icon(Icons.done_all),
            )
          : null,
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
            _isConnected ? 'Monitoring Alerts' : 'Connection Lost',
            style: TextStyle(
              color: _isConnected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Alert alert) {
    Color cardColor;
    IconData alertIcon;

    switch (alert.type) {
      case 'GAS':
        cardColor = Colors.orange.withOpacity(0.1);
        alertIcon = Icons.warning;
        break;
      case 'FIRE':
        cardColor = Colors.red.withOpacity(0.1);
        alertIcon = Icons.local_fire_department;
        break;
      default:
        cardColor = Colors.blue.withOpacity(0.1);
        alertIcon = Icons.info;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: alert.isRead ? null : cardColor,
      child: ListTile(
        leading: Icon(alertIcon, color: alert.isRead ? Colors.grey : null),
        title: Text(
          '${alert.type}: ${alert.message}',
          style: TextStyle(
            fontWeight: alert.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Device: ${alert.deviceId}\n${alert.timestamp.toString().split('.')[0]}',
        ),
        trailing: !alert.isRead
            ? IconButton(
                icon: const Icon(Icons.mark_email_read),
                onPressed: () {
                  setState(() {
                    alert.isRead = true;
                  });
                },
              )
            : null,
        isThreeLine: true,
      ),
    );
  }
}
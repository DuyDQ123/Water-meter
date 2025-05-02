import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class Device {
  final String id;
  String name;
  String? lastReading;
  String? lastUpdate;

  Device({
    required this.id,
    required this.name,
    this.lastReading,
    this.lastUpdate,
  });
}

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  static const String serverUrl = 'http://192.168.1.159/iotdigi-main';
  final List<Device> _devices = [];
  bool _isLoading = false;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchDevices();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchDevices();
    });
  }

  Future<void> _fetchDevices() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$serverUrl/get_devices.php'),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Không thể kết nối đến máy chủ');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['devices'] != null) {
          setState(() {
            _devices.clear();
            for (var deviceData in data['devices']) {
              _devices.add(Device(
                id: deviceData['id'].toString(),
                name: deviceData['name'],
                lastReading: deviceData['last_reading'],
                lastUpdate: deviceData['last_update'],
              ));
            }
            _isLoading = false;
          });
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchDevices,
      child: Column(
        children: [
          _buildStatusBar(),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          Expanded(
            child: _buildDeviceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    if (_isLoading && _devices.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_devices.isEmpty) {
      return const Center(
        child: Text('Không tìm thấy thiết bị nào'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        return _buildDeviceCard(device);
      },
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.blue.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isLoading ? Icons.sync : Icons.info,
            size: 16,
            color: Colors.blue,
          ),
          const SizedBox(width: 8),
          Text(
            _isLoading ? 'Đang cập nhật...' : 'Tự động cập nhật mỗi 10 giây',
            style: const TextStyle(color: Colors.blue),
          ),
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh, size: 16),
              onPressed: _fetchDevices,
              tooltip: 'Cập nhật ngay',
            ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(Device device) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: ListTile(
        leading: const Icon(Icons.camera),
        title: Text(device.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (device.lastUpdate != null)
              Text('Cập nhật lúc: ${_formatDateTime(device.lastUpdate!)}'),
            if (device.lastReading != null)
              Text('Chỉ số: ${device.lastReading}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: () {
                // TODO: View camera stream
              },
              tooltip: 'Xem camera',
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                // TODO: Configure device
              },
              tooltip: 'Cài đặt',
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(String dateTimeStr) {
    final dt = DateTime.parse(dateTimeStr);
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
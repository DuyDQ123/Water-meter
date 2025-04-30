import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';

class Device {
  final String id;
  String name;
  double? locationLat;
  double? locationLng;
  double? lastBillAmount;
  String? billDate;
  String? lastReading;
  String? lastUpdate;

  Device({
    required this.id,
    required this.name,
    this.locationLat,
    this.locationLng,
    this.lastBillAmount,
    this.billDate,
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
  GoogleMapController? _mapController;
  bool _showMap = false;
  Timer? _refreshTimer;
  final _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _fetchDevices();
    // Auto refresh every 5 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
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
          throw TimeoutException('Không thể kết nối đến server');
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
                locationLat: deviceData['location_lat']?.toDouble(),
                locationLng: deviceData['location_lng']?.toDouble(),
                lastBillAmount: deviceData['last_bill_amount']?.toDouble(),
                billDate: deviceData['bill_date'],
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
    _mapController?.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Set<Marker> _createMarkers() {
    return _devices.where((device) => 
      device.locationLat != null && device.locationLng != null
    ).map((device) {
      return Marker(
        markerId: MarkerId(device.id),
        position: LatLng(device.locationLat!, device.locationLng!),
        infoWindow: InfoWindow(
          title: device.name,
          snippet: device.lastBillAmount != null 
              ? 'Hoá đơn gần nhất: ${_currencyFormat.format(device.lastBillAmount)}'
              : 'Chưa có hoá đơn',
        ),
      );
    }).toSet();
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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Text('Chế độ xem:'),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Danh sách'),
                  selected: !_showMap,
                  onSelected: (selected) {
                    setState(() => _showMap = !selected);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Bản đồ'),
                  selected: _showMap,
                  onSelected: (selected) {
                    setState(() => _showMap = selected);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _showMap ? _buildMap() : _buildDeviceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(21.028511, 105.804817), // Hà Nội
        zoom: 12,
      ),
      markers: _createMarkers(),
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
      },
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
        child: Text('Chưa có thiết bị nào'),
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
            _isLoading
                ? 'Đang cập nhật...'
                : 'Cập nhật tự động mỗi 5 phút',
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
      child: ExpansionTile(
        leading: const Icon(Icons.device_hub),
        title: Text(device.name),
        subtitle: Text(
            device.lastUpdate != null 
            ? 'Cập nhật: ${_formatDateTime(device.lastUpdate!)}'
            : 'Chưa có dữ liệu'
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (device.locationLat != null && device.locationLng != null)
                  _buildInfoRow(
                    'Vị trí',
                    '${device.locationLat!.toStringAsFixed(6)}, ${device.locationLng!.toStringAsFixed(6)}',
                    Icons.location_on,
                  ),
                if (device.lastReading != null)
                  _buildInfoRow(
                    'Chỉ số gần nhất',
                    device.lastReading!,
                    Icons.water_drop,
                  ),
                if (device.lastBillAmount != null)
                  _buildInfoRow(
                    'Hoá đơn gần nhất',
                    _currencyFormat.format(device.lastBillAmount),
                    Icons.receipt,
                  ),
                if (device.billDate != null)
                  _buildInfoRow(
                    'Ngày',
                    _formatDateTime(device.billDate!),
                    Icons.calendar_today,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String dateTimeStr) {
    final dt = DateTime.parse(dateTimeStr);
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
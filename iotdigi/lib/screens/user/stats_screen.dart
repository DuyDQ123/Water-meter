import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'bill_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Timer? _refreshTimer;
  List<Map<String, dynamic>> _temperatureData = [];
  List<Map<String, dynamic>> _humidityData = [];
  List<Map<String, dynamic>> _gasData = [];
  List<Map<String, dynamic>> _waterUsageData = [];
  double? _totalBill;
  bool _isLoading = true;
  String? _error;

  static const String serverUrl = 'http://192.168.1.169/iotdigi-main';
  static const List<Map<String, dynamic>> waterRates = [
    {'limit': 10, 'price': 5973, 'description': '0-10m³: 5.973 VNĐ/m³'},
    {'limit': 10, 'price': 7052, 'description': '10-20m³: 7.052 VNĐ/m³'},
    {'limit': 10, 'price': 8669, 'description': '20-30m³: 8.669 VNĐ/m³'},
    {'limit': double.infinity, 'price': 15929, 'description': '>30m³: 15.929 VNĐ/m³'}
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchData());
  }

  Future<void> _fetchData() async {
    try {
      final response = await http.get(Uri.parse('$serverUrl/get.php'));
      
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _temperatureData = List<Map<String, dynamic>>.from(data['temperature_history'] ?? []);
            _humidityData = List<Map<String, dynamic>>.from(data['humidity_history'] ?? []);
            _gasData = List<Map<String, dynamic>>.from(data['gas_history'] ?? []);
            _waterUsageData = List<Map<String, dynamic>>.from(data['ocr_readings'] ?? []);
            _isLoading = false;
            _calculateBill();
          });
        }
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error loading data';
        _isLoading = false;
      });
    }
  }

  void _calculateBill() {
    if (_waterUsageData.length < 2) return;

    try {
      final startReading = double.parse(_waterUsageData.first['ocr_text'].toString());
      final endReading = double.parse(_waterUsageData.last['ocr_text'].toString());
      final totalUsage = endReading - startReading;
      
      double bill = 0;
      var remainingUsage = totalUsage;

      for (final rate in waterRates) {
        if (remainingUsage > 0) {
          final usage = remainingUsage.clamp(0, rate['limit'] as double);
          bill += usage * (rate['price'] as int);
          remainingUsage -= usage;
        } else {
          break;
        }
      }

      setState(() => _totalBill = bill);
    } catch (e) {
      debugPrint('Error calculating bill: $e');
    }
  }

  Widget _buildChart(String title, List<Map<String, dynamic>> data, String valueKey, Color color, String unit) {
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: CustomPaint(
              painter: ChartPainter(
                data: data,
                valueKey: valueKey,
                lineColor: color,
                unit: unit,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Charts
          _buildChart('Temperature History', _temperatureData, 'temperature', Colors.red, '°C'),
          _buildChart('Humidity History', _humidityData, 'humidity', Colors.blue, '%'),
          _buildChart('Gas Level History', _gasData, 'gas_level', Colors.purple, 'ppm'),
          _buildChart('Water Usage History', _waterUsageData, 'ocr_text', Colors.green, 'm³'),

          // Water Bill Card
          if (_totalBill != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Water Bill Estimate',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total: ${_totalBill!.toStringAsFixed(0)} VNĐ',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Divider(),
                    ...waterRates.map((rate) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(rate['description'] as String),
                    )),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BillScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('View Detailed Bill'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final String valueKey;
  final Color lineColor;
  final String unit;

  ChartPainter({
    required this.data,
    required this.valueKey,
    required this.lineColor,
    required this.unit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    final path = Path();
    final values = data.map((e) => double.parse(e[valueKey].toString())).toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;

    // Draw grid lines and labels
    for (int i = 0; i <= 4; i++) {
      final y = size.height - (size.height * i / 4);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = Colors.grey[300]!
          ..strokeWidth = 0.5,
      );

      final value = minValue + (range * i / 4);
      textPainter.text = TextSpan(
        text: '${value.toStringAsFixed(1)}$unit',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 10,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-textPainter.width - 4, y - textPainter.height / 2));
    }

    // Draw data points and lines
    final pointWidth = size.width / (data.length - 1);
    path.moveTo(
      0,
      size.height - ((values.first - minValue) / range * size.height),
    );

    for (int i = 1; i < data.length; i++) {
      path.lineTo(
        pointWidth * i,
        size.height - ((values[i] - minValue) / range * size.height),
      );
    }

    canvas.drawPath(path, paint);

    // Draw points
    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      canvas.drawCircle(
        Offset(
          pointWidth * i,
          size.height - ((values[i] - minValue) / range * size.height),
        ),
        3,
        pointPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
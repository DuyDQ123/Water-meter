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

  static const String serverUrl = 'http://192.168.1.14/iotdigi-main';
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

    List<double> values = [];
    List<String> dates = [];

    if (valueKey == 'ocr_text' && data.length > 1) {
      // Group water readings by day
      Map<String, double> dailyUsage = {};
      
      for (int i = 0; i < data.length - 1; i++) {
        final current = double.parse(data[i][valueKey].toString());
        final next = double.parse(data[i + 1][valueKey].toString());
        final date = data[i]['timestamp']?.toString().substring(0, 10) ??
                    DateTime.now().subtract(Duration(days: data.length - i - 1))
                                .toString().substring(0, 10);
        
        final usage = next - current;
        dailyUsage[date] = (dailyUsage[date] ?? 0) + usage;
      }

      // Get last 30 days data
      final sortedDates = dailyUsage.keys.toList()..sort();
      final last30Days = sortedDates.length > 30
          ? sortedDates.sublist(sortedDates.length - 30)
          : sortedDates;

      for (String date in last30Days) {
        values.add(dailyUsage[date] ?? 0);
        // Extract day from date (DD/MM)
        dates.add('${date.substring(8)}-${date.substring(5, 7)}');
      }
    } else {
      values = data.map((e) => double.parse(e[valueKey].toString())).toList();
    }
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = 0.0; // Start from 0 for better visualization
    final range = maxValue - minValue;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );

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

      // Y-axis labels
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

    // Draw date labels for water usage chart
    if (valueKey == 'ocr_text' && dates.isNotEmpty) {
      // Draw date labels every 5 days
      for (int i = 0; i < dates.length; i += 5) {
        textPainter.text = TextSpan(
          text: dates[i],
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
          ),
        );
        textPainter.layout();
        
        final x = i * (size.width / dates.length);
        canvas.save();
        canvas.translate(x + 10, size.height + 5);
        canvas.rotate(-0.5); // Rotate text slightly for better readability
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }

    if (valueKey == 'ocr_text') {
      // Bar chart for water usage with uniform width
      final barWidth = (size.width / values.length) * 0.8; // 80% width for bar
      final spacing = (size.width / values.length) * 0.2; // 20% width for spacing
      
      for (int i = 0; i < values.length; i++) {
        final x = i * (barWidth + spacing);
        final height = ((values[i] - minValue) / range) * size.height;
        
        // Draw bar with gradient
        final rect = Rect.fromLTWH(
          x,
          size.height - height,
          barWidth,
          height,
        );
        
        final gradient = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withOpacity(0.7),
            lineColor.withOpacity(0.9),
          ],
        );
        
        canvas.drawRect(
          rect,
          Paint()
            ..shader = gradient.createShader(rect)
            ..style = PaintingStyle.fill,
        );
        
        // Draw border
        canvas.drawRect(
          rect,
          Paint()
            ..color = lineColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    } else {
      // Line chart for other metrics
      final paint = Paint()
        ..color = lineColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final path = Path();
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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
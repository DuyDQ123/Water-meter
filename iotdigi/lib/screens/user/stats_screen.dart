import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show listEquals;

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Timer? _refreshTimer;
  List<Map<String, dynamic>> _waterUsageData = [];
  List<MapEntry<String, double>>? _chartData;
  List<BarChartGroupData>? _cachedBarGroups;
  bool _isLoading = true;
  String? _error;
  static const String serverUrl = 'http://192.168.1.159/iotdigi-main';

  @override
  void initState() {
    super.initState();
    _fetchData();
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    // Refresh more frequently to catch OCR updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchData());
  }

  Future<void> _fetchData() async {
    try {
      final response = await http.get(Uri.parse('$serverUrl/get.php'));
      
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final newData = List<Map<String, dynamic>>.from(data['ocr_readings'] ?? []);
          if (!listEquals(_waterUsageData, newData)) {
            setState(() {
              _waterUsageData = newData;
              _chartData = null;
              _cachedBarGroups = null;
              _isLoading = false;
            });
          }
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

  List<MapEntry<String, double>> _processData() {
    if (_chartData != null) return _chartData!;
    
    debugPrint('Processing ${_waterUsageData.length} records');
    
    // Get the last 10 days
    final now = DateTime.now();
    final dates = List.generate(5, (index) {
      return now.subtract(Duration(days: 4 - index));
    });
    
    // Initialize with 0 for all days
    Map<String, double> dailyUsage = {
      for (var date in dates)
        date.toString().substring(0, 10): 0.0
    };
    
    // Calculate usage for each day
    for (int i = 0; i < _waterUsageData.length - 1; i++) {
      try {
        final current = double.parse(_waterUsageData[i]['ocr_text'].toString());
        final next = double.parse(_waterUsageData[i + 1]['ocr_text'].toString());
        final timestamp = _waterUsageData[i]['timestamp'];
        if (timestamp == null) continue;
        
        final date = timestamp.toString().substring(0, 10);
        if (!dailyUsage.containsKey(date)) continue;
        
        final usage = next - current;
        if (usage > 0) {
          dailyUsage[date] = (dailyUsage[date] ?? 0) + usage;
        }
      } catch (e) {
        debugPrint('Error processing record $i: $e');
      }
    }
    
    // Convert to sorted list
    _chartData = dates.map((date) {
      final dateStr = date.toString().substring(0, 10);
      return MapEntry(dateStr, (dailyUsage[dateStr] ?? 0).roundToDouble());
    }).toList();
    
    debugPrint('Chart data: $_chartData');
    return _chartData!;
  }

  List<BarChartGroupData> _getBarGroups() {
    if (_cachedBarGroups != null) return _cachedBarGroups!;
    
    final data = _processData();
    _cachedBarGroups = List.generate(data.length, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: data[index].value,
            color: Colors.blue.shade400,
            width: 15,
            borderRadius: BorderRadius.zero,
          ),
        ],
      );
    });
    
    return _cachedBarGroups!;
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

    final chartData = _processData();

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Water Usage (Last 5 Days)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _waterUsageData.isEmpty
                  ? const Center(child: Text('No data available'))
                  : Stack(
                      children: [
                        BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            barGroups: _getBarGroups(),
                            gridData: FlGridData(show: false),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index >= 0 && index < chartData.length) {
                                      final date = chartData[index].key;
                                      return Text(
                                        date.substring(5, 10).replaceAll('-', '/'),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                  reservedSize: 30,
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barTouchData: BarTouchData(enabled: false),
                          ),
                        ),
                        ...List.generate(chartData.length, (index) {
                          final value = chartData[index].value;
                          final barWidth = 15.0;
                          final totalWidth = MediaQuery.of(context).size.width - 32; // Padding
                          final width = (totalWidth - barWidth * chartData.length) / (chartData.length + 1);
                          final x = width + index * (barWidth + width) + barWidth / 2;

                          return Positioned(
                            left: x - 15,
                            top: 0,
                            child: Text(
                              '${value.round()} m³',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
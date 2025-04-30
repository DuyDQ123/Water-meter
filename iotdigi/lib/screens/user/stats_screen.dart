import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final List<double> waterReadings = [];
  final List<String> dates = [];
  bool isLoading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.159/iotdigi-main/get_stats.php'),
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['readings'] != null) {
          setState(() {
            waterReadings.clear();
            dates.clear();
            for (var reading in data['readings']) {
              waterReadings.add(double.tryParse(reading['value'].toString()) ?? 0.0);
              dates.add(reading['date'].toString());
            }
            debugPrint('Loaded ${waterReadings.length} readings');
          });
        } else {
          setState(() {
            error = 'Invalid data format from server';
          });
        }
      } else {
        setState(() {
          error = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error fetching stats: $e';
      });
      debugPrint('Error fetching stats: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (!isLoading && error == null)
                if (waterReadings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: Text('Chưa có dữ liệu')),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        AspectRatio(
                          aspectRatio: 1.7,
                          child: BarChart(
                            BarChartData(
                              barGroups: _createBarGroups(),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      if (value.toInt() >= 0 && 
                                          value.toInt() < dates.length) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(
                                            dates[value.toInt()],
                                            style: const TextStyle(
                                              fontSize: 10,
                                            ),
                                          ),
                                        );
                                      }
                                      return const Text('');
                                    },
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
                              gridData: FlGridData(show: false),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Chỉ số nước theo thời gian (${waterReadings.length} chỉ số)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Ngày')),
                              DataColumn(label: Text('Chỉ số')),
                            ],
                            rows: List.generate(
                              waterReadings.length,
                              (index) => DataRow(
                                cells: [
                                  DataCell(Text(dates[index])),
                                  DataCell(Text(waterReadings[index].toString())),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  List<BarChartGroupData> _createBarGroups() {
    return List.generate(waterReadings.length, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: waterReadings[index],
            color: Colors.blue,
            width: 16,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    });
  }
}
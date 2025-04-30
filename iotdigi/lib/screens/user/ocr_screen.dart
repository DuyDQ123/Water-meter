import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State createState() => _OcrScreenState();
}

class _OcrScreenState extends State {
  bool _isProcessing = false;
  String? _recognizedText;
  String? _error;
  Timer? _streamTimer;
  double _waterBill = 0;
  bool _leakAlert = false;
  double _brightness = 0;

  // Server configuration from ESP32 config
  static const String serverIP = '192.168.1.159';
  static const String localServerUrl = 'http://192.168.1.159/iotdigi-main';
  static const String controllerIP = '192.168.137.210';
  static const int ocrPort = 82;
  static const Duration _streamInterval = Duration(milliseconds: 100);

  @override
  void initState() {
    super.initState();
    _startStreaming();
    _startDataPolling();
  }

  void _startStreaming() {
    _streamTimer?.cancel();
    _streamTimer = Timer.periodic(_streamInterval, (_) {
      setState(() {}); // Force image widget to refresh
    });
  }

  void _startDataPolling() {
    Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    try {
      final response = await http.get(
        Uri.parse('$localServerUrl/get.php'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            if (data['latest_ocr_result'] != null) {
              _recognizedText = data['latest_ocr_result']['ocr_text'];
            }
            
            // Calculate water bill from OCR readings
            if (data['ocr_readings']?.isNotEmpty == true) {
              final readings = data['ocr_readings'] as List;
              if (readings.length >= 2) {
                final startReading = double.parse(readings.first['ocr_text']);
                final endReading = double.parse(readings.last['ocr_text']);
                final totalUsage = endReading - startReading;
                
                double bill = 0;
                var remainingUsage = totalUsage;
                
                final rates = [
                  {'limit': 10, 'price': 5973},
                  {'limit': 10, 'price': 7052},
                  {'limit': 10, 'price': 8669},
                  {'limit': double.infinity, 'price': 15929}
                ];

                for (final rate in rates) {
                  if (remainingUsage > 0) {
                    final usage = remainingUsage.clamp(0, rate['limit'] as double);
                    bill += usage * (rate['price'] as int);
                    remainingUsage -= usage;
                  } else {
                    break;
                  }
                }

                _waterBill = bill;
              }
            }

            _leakAlert = data['leak_alert'] ?? false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
    }
  }

  Future<void> _triggerOcr() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('http://$controllerIP:$ocrPort/trigger'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await Future.delayed(const Duration(seconds: 2));
        await _fetchData();
      } else {
        throw Exception('Failed to trigger OCR');
      }
    } catch (e) {
      setState(() => _error = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _adjustBrightness(double value) async {
    setState(() => _brightness = value);
    final brightnessValue = (value * 800).round();

    try {
      await http.get(
        Uri.parse('http://$controllerIP:81/slider?value=$brightnessValue'),
      );
    } catch (e) {
      debugPrint('Error adjusting brightness: $e');
    }
  }

  Widget _buildBrightnessButton(String label, double value) {
    final bool isActive = _brightness == value;
    return ElevatedButton(
      onPressed: () => _adjustBrightness(value),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        backgroundColor: isActive ? Theme.of(context).primaryColor : null,
        foregroundColor: isActive ? Colors.white : null,
      ),
      child: Text(label),
    );
  }

  @override
  void dispose() {
    _streamTimer?.cancel();
    super.dispose();
  }

  String _getStreamUrl() {
    return '$localServerUrl/video_stream/uploaded_image.jpg?_=${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Image.network(
                  _getStreamUrl(),
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Text('Error loading stream'));
                  },
                ),
              ),
              // LED Brightness Control
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildBrightnessButton('Off', 0),
                    _buildBrightnessButton('25%', 25),
                    _buildBrightnessButton('50%', 50),
                    _buildBrightnessButton('75%', 75),
                    _buildBrightnessButton('100%', 100),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black87,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_recognizedText != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Reading: $_recognizedText',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
              if (_waterBill > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Estimated Bill: ${_waterBill.toStringAsFixed(0)} VNĐ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
              if (_leakAlert)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cảnh báo: Có dấu hiệu rò rỉ nước trong vòng 24 giờ qua!',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ElevatedButton(
                onPressed: _isProcessing ? null : _triggerOcr,
                child: Text(_isProcessing ? 'Processing...' : 'Scan Now'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

class LedControlScreen extends StatefulWidget {
  const LedControlScreen({super.key});

  @override
  State<LedControlScreen> createState() => _LedControlScreenState();
}

class _LedControlScreenState extends State<LedControlScreen> {
  double _brightness = 0.0;
  final bool _isConnected = true;
  bool _isSending = false;
  static const String esp32CamIp = '192.168.137.89';

  Future<void> _updateBrightness(double value) async {
    if (_isSending) return;

    setState(() {
      _brightness = value;
      _isSending = true;
    });

    try {
      // Convert percentage (0-100) to ESP32 range (0-800)
      final scaledValue = (value * 8).round();
      
      final response = await http.get(
        Uri.parse('http://$esp32CamIp:81/slider?value=$scaledValue'),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode != 200) {
        throw Exception('Failed to update brightness');
      }

      // Small delay to prevent rapid requests
      await Future.delayed(const Duration(milliseconds: 100));

    } catch (e) {
      debugPrint('Error updating brightness: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update brightness: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
        // Reset brightness on error
        setState(() {
          _brightness = 0;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
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
                Icon(
                  Icons.lightbulb,
                  color: _brightness > 0 ? Colors.yellow : Colors.grey,
                ),
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
    final bool isActive = _brightness == value;
    
    return ElevatedButton(
      onPressed: _isConnected ? () => _updateBrightness(value) : null,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 36),
        backgroundColor: isActive ? Theme.of(context).primaryColor : null,
        foregroundColor: isActive ? Colors.white : null,
      ),
      child: Text(label),
    );
  }
}
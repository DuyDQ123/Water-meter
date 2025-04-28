import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:math';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State createState() => _OcrScreenState();
}

class _OcrScreenState extends State {
  bool _isProcessing = false;
  bool _isStreaming = false;
  String? _recognizedText;
  String? _error;
  Timer? _streamTimer;
  String? _lastImageUrl;
  String? _imageUrl;
  final _random = Random();

  static const String serverIp = '192.168.1.159';
  static const int ocrServerPort = 82; // Port for OCR server on ESP32CAM
  static const Duration _streamInterval = Duration(milliseconds: 100);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startStreaming();
    });
  }

  void _startStreaming() {
    if (_isProcessing) return;
    
    setState(() {
      _error = null;
      _isStreaming = true;
    });

    _streamTimer?.cancel();
    _streamTimer = Timer.periodic(_streamInterval, (timer) async {
      if (!_isStreaming) {
        timer.cancel();
        return;
      }
      setState(() {
        final newUrl = 'http://$serverIp/iotdigi-main/video_stream/uploaded_image.jpg?_=${_random.nextInt(1000000)}';
        if (newUrl != _lastImageUrl) {
          _lastImageUrl = newUrl;
        }
      });
    });
  }

  void _stopStreaming() {
    _streamTimer?.cancel();
    if (mounted) {
      setState(() {
        _isStreaming = false;
        _lastImageUrl = null;
      });
    }
  }

  @override
  void dispose() {
    _stopStreaming();
    super.dispose();
  }

  @override
  void deactivate() {
    _stopStreaming();
    super.deactivate();
  }

  Future<void> _triggerOcr() async {
    if (_isProcessing || !_isStreaming) return;

    setState(() {
      _isProcessing = true;
      _error = null;
      _recognizedText = 'Processing OCR...\nThis may take a few seconds';
    });

    try {
      // Trigger OCR using ESP32CAM's OCR server
      final response = await http.get(
        Uri.parse('http://$serverIp:$ocrServerPort/trigger'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        await Future.delayed(const Duration(seconds: 1));
        
        // Get OCR result with retries
        int retries = 0;
        while (retries < 3) {
          try {
            final resultResponse = await http.get(
              Uri.parse('http://$serverIp/iotdigi-main/get.php?type=ocr'),
            ).timeout(const Duration(seconds: 5));
            
            if (resultResponse.statusCode == 200) {
              final data = json.decode(resultResponse.body);
              if (data['status'] == 'success' && data['latest_ocr_result'] != null) {
                if (!mounted) return;
                setState(() {
                  _recognizedText = data['latest_ocr_result']['ocr_text'];
                  _imageUrl = _lastImageUrl;
                });
                return;
              }
            }
            retries++;
            await Future.delayed(const Duration(seconds: 1));
          } catch (e) {
            retries++;
            if (retries < 3) {
              await Future.delayed(const Duration(seconds: 1));
            }
          }
        }
        throw TimeoutException('Failed to get OCR result after retries');
      } else {
        throw Exception('Failed to trigger OCR');
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _error = 'Connection timed out. Please try again.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error: ${e.toString()}');
    } finally {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _startStreaming();
      });
    }
  }

  Widget _buildStreamView() {
    if (!_isStreaming || _lastImageUrl == null) {
      return const Center(
        child: Text('Start streaming to capture image'),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          _lastImageUrl!,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Text('Error loading stream'),
            );
          },
        ),
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCapturedImageView() {
    if (_imageUrl == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
      ),
      child: Image.network(
        _imageUrl!,
        fit: BoxFit.contain,
        key: ValueKey(_imageUrl),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR Scanner'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildStreamView()),
                if (_imageUrl != null)
                  Expanded(child: _buildCapturedImageView()),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black87,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_recognizedText != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _recognizedText!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : (_isStreaming ? _stopStreaming : _startStreaming),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isStreaming ? Colors.red : null,
                        ),
                        child: Text(_isStreaming ? 'Stop Stream' : 'Start Stream'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing || !_isStreaming ? null : _triggerOcr,
                        child: Text(_isProcessing ? 'Processing...' : 'Capture & OCR'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

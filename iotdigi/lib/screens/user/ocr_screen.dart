import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  String? _recognizedText;
  final TextRecognizer _textRecognizer = TextRecognizer();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _processImage() async {
    if (!_isCameraInitialized || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile image = await _controller!.takePicture();
      final inputImage = InputImage.fromFile(File(image.path));
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      // Extract numbers from the recognized text
      final RegExp regExp = RegExp(r'\d+\.?\d*');
      final matches = regExp.allMatches(recognizedText.text);
      
      setState(() {
        _recognizedText = matches.isNotEmpty 
            ? 'Water Meter Reading: ${matches.first.group(0)}'
            : 'No meter reading detected';
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _recognizedText = 'Error processing image';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              CameraPreview(_controller!),
              if (_isProcessing)
                const CircularProgressIndicator(),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.black87,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_recognizedText != null)
                Text(
                  _recognizedText!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isProcessing ? null : _processImage,
                child: Text(_isProcessing ? 'Processing...' : 'Capture Reading'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
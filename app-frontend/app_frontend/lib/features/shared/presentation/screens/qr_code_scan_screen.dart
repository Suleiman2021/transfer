import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrCodeScanScreen extends StatefulWidget {
  const QrCodeScanScreen({super.key});

  @override
  State<QrCodeScanScreen> createState() => _QrCodeScanScreenState();
}

class _QrCodeScanScreenState extends State<QrCodeScanScreen> {
  late final MobileScannerController _controller;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish(String? value) {
    final code = value?.trim();
    if (_done || code == null || code.isEmpty) return;
    _done = true;
    Navigator.of(context).pop(code);
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final capture = await _controller.analyzeImage(picked.path);
    final value = capture?.barcodes.firstOrNull?.rawValue;
    if (!mounted) return;
    if (value == null || value.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم العثور على QR في الصورة.')),
      );
      return;
    }
    _finish(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قراءة QR'),
        actions: [
          IconButton(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_library_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) =>
                _finish(capture.barcodes.firstOrNull?.rawValue),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_search_rounded),
                  label: const Text('اختيار صورة من الملفات'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

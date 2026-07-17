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
  bool _picking = false;

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
    if (_picking || _done) return;
    setState(() => _picking = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      final capture = await _controller.analyzeImage(picked.path);
      if (!mounted) return;
      final value = capture?.barcodes.firstOrNull?.rawValue;
      if (value == null || value.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم العثور على QR في الصورة.')),
        );
        return;
      }
      _finish(value);
    } on Exception catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (!msg.contains('already_active')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح معرض الصور.')),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قراءة QR'),
        actions: [
          IconButton(
            onPressed: _picking ? null : _pickImage,
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
                  onPressed: _picking ? null : _pickImage,
                  icon: _picking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.image_search_rounded),
                  label: Text(_picking ? 'جار التحليل...' : 'اختيار صورة من الملفات'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

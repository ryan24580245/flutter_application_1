import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'share_record_page.dart';

class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});
  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final value = barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;
    _handled = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => SharedRecordsPage(code: value)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('掃描 QR Code'),
        backgroundColor: const Color(0xFF2E7D9F),
        foregroundColor: Colors.white,
      ),
      body: MobileScanner(onDetect: _onDetect),
    );
  }
}
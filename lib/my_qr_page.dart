import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'share_service.dart';

const _kDurations = [
  {'key': 'hour', 'label': '1 小時'},
  {'key': 'day', 'label': '1 天'},
  {'key': 'week', 'label': '1 週'},
  {'key': 'permanent', 'label': '永久有效'},
];

class MyQrPage extends StatefulWidget {
  const MyQrPage({super.key});
  @override
  State<MyQrPage> createState() => _MyQrPageState();
}

class _MyQrPageState extends State<MyQrPage> {
  bool _loading = true;
  String? _code;
  DateTime? _expiresAt; // null 代表永久有效

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await ShareService.getMyShareStatus();
    if (!mounted) return;
    setState(() {
      _code = status?['shareCode'] as String?;
      final exp = status?['expiresAt'];
      _expiresAt = exp != null ? DateTime.tryParse(exp.toString()) : null;
      _loading = false;
    });
  }

  Future<void> _generate(String duration) async {
    setState(() => _loading = true);
    final result = await ShareService.generateShareCode(duration);
    if (!mounted) return;
    if (result == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('產生失敗，請稍後再試')));
      return;
    }
    setState(() {
      _code = result['shareCode'] as String?;
      final exp = result['expiresAt'];
      _expiresAt = exp != null ? DateTime.tryParse(exp.toString()) : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('我的 QR Code'),
        backgroundColor: const Color(0xFF2E7D9F),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _code == null
              ? _buildPicker()
              : _buildQr(),
    );
  }

  Widget _buildPicker() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('選擇 QR Code 的有效期限', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('時間到了之後，這個 QR Code 就會自動失效，別人就看不到了。',
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 24),
          ..._kDurations.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D9F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _generate(d['key']!),
                    child: Text(d['label']!, style: const TextStyle(fontSize: 16)),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildQr() {
    final expiresLabel =
        _expiresAt == null ? '永久有效' : '有效至：${DateFormat('yyyy/MM/dd HH:mm').format(_expiresAt!)}';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '讓別人掃這個 QR Code，\n就能唯讀查看你的記帳記錄',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: QrImageView(data: _code!, size: 220),
            ),
            const SizedBox(height: 16),
            Text('查看碼：$_code', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(expiresLabel, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 32),
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('重新設定期限'),
              onPressed: () => setState(() {
                _code = null;
                _expiresAt = null;
              }),
            ),
          ],
        ),
      ),
    );
  }
}
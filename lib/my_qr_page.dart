import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'share_service.dart';
import 'create_share_page.dart';

class MyQrPage extends StatefulWidget {
  const MyQrPage({super.key});
  @override
  State<MyQrPage> createState() => _MyQrPageState();
}

class _MyQrPageState extends State<MyQrPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _shares = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final shares = await ShareService.listMyShares();
    if (!mounted) return;
    setState(() {
      _shares = shares ?? [];
      _loading = false;
    });
  }

  Future<void> _createNew() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateSharePage()),
    );
    // 不管是按「完成」按鈕回來，還是用返回鍵/手勢離開，都重新整理一次列表
    _load();
  }

  void _showQr(Map<String, dynamic> share) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: share['code'], size: 200),
            const SizedBox(height: 12),
            Text('查看碼：${share['code']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉'))],
      ),
    );
  }

  Future<void> _revoke(Map<String, dynamic> share) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('撤銷這組分享碼？'),
        content: const Text('撤銷後，這個 QR Code 會立即失效，無法復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('撤銷', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await ShareService.revokeShare(share['code']);
    if (!mounted) return;
    if (ok) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('撤銷失敗，請稍後再試')));
    }
  }

  String _formatExpiry(dynamic expiresAt) {
    if (expiresAt == null) return '永久有效';
    final dt = DateTime.tryParse(expiresAt.toString());
    if (dt == null) return '永久有效';
    return '有效至 ${DateFormat('MM/dd HH:mm').format(dt)}';
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
          : _shares.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '目前沒有正在分享的 QR Code，\n點右下角建立一個吧',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _shares.length,
                  itemBuilder: (context, i) {
                    final share = _shares[i];
                    final isOneTime = share['oneTime'] == true;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text('${share['year']} 年 ${share['month']} 月'),
                        subtitle: Text(
                          isOneTime ? '${_formatExpiry(share['expiresAt'])} · 一次性' : _formatExpiry(share['expiresAt']),
                          style: TextStyle(color: isOneTime ? Colors.deepOrange : Colors.grey[600]),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.qr_code), onPressed: () => _showQr(share)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _revoke(share),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2E7D9F),
        foregroundColor: Colors.white,
        onPressed: _createNew,
        child: const Icon(Icons.add),
      ),
    );
  }
}
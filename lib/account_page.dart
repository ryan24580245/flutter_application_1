import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'sync_service.dart';
import 'database.dart';
import 'settings.dart';
import 'label_service.dart';
import 'login_page.dart';
import 'my_qr_page.dart';
import 'scan_qr_page.dart';
import 'share_record_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _loading = true;
  bool _loggedIn = false;
  String _name = '';
  bool _syncing = false;
  bool _loggingOut = false;

  bool get _busy => _syncing || _loggingOut;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final loggedIn = await AuthService.isLoggedIn();
    final name = await AuthService.getName();
    if (!mounted) return;
    setState(() {
      _loggedIn = loggedIn;
      _name = name ?? '';
      _loading = false;
    });
  }

  Future<void> _goLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginPage(onLoginSuccess: () => Navigator.pop(context)),
      ),
    );
    if (!mounted) return;
    await _loadStatus();
    if (_loggedIn) await _runSync();
  }

  // 把雲端的自建標籤跟本機的合併起來（不互相覆蓋，避免任何一邊的標籤憑空消失）
  Future<void> _syncLabels() async {
    final cloudLabels = await LabelService.getCloudLabels();
    if (cloudLabels == null) return; // 沒登入或讀取失敗，直接略過，不要動本機資料
    final localLabels = await Settings.getCustomLabels();
    final merged = <String>{...localLabels, ...cloudLabels}.toList();
    await Settings.setCustomLabels(merged);
    await LabelService.pushLabels(merged);
  }

  Future<void> _runSync() async {
    setState(() => _syncing = true);
    final ok = await SyncService.syncAfterLogin();
    await _syncLabels();
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '資料已同步完成' : '同步未完全成功，請確認網路後再試一次'),
        backgroundColor: ok ? const Color(0xFF2E7D9F) : Colors.orange,
      ),
    );
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);

    // 登出前先把這個帳號的本機異動同步上雲端
    final syncOk = await SyncService.syncAfterLogin();
    if (!syncOk) {
      // 同步沒有成功，代表本機可能還有沒上傳的記錄
      // 這時候絕對不能清空本機資料，也不能真的登出，否則這些記錄會永久消失
      if (!mounted) return;
      setState(() => _loggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('同步失敗，為了避免資料遺失，已取消登出，請確認網路後再試一次'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final labels = await Settings.getCustomLabels();
    await LabelService.pushLabels(labels);
    // 清空本機記帳資料、自建標籤、固定預算，避免下一個登入的帳號看到這個帳號留下的東西
    await AppDatabase.instance.clearTransactions();
    await Settings.clearAccountSpecificSettings();
    await AuthService.logout();
    if (!mounted) return;
    setState(() => _loggingOut = false);
    await _loadStatus();
  }

  void _goMyQr() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MyQrPage()));
  }

  void _goScan() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanQrPage()));
  }

  Future<void> _enterCode() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('輸入查看碼'),
        content: SingleChildScrollView(
          child: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: '例如：K7P2QX9A1B', border: OutlineInputBorder()),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D9F), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('查看'),
          ),
        ],
      ),
    );
    if (code == null) return;
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) return;
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => SharedRecordsPage(code: trimmed)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 同步或登出進行中時，不能切走這個畫面
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: AppBar(title: const Text('帳號'), backgroundColor: const Color(0xFF2E7D9F), foregroundColor: Colors.white),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._loggedIn
                        ? [
                            Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(children: [
                                  const CircleAvatar(
                                      backgroundColor: Color(0xFF2E7D9F), child: Icon(Icons.person, color: Colors.white)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('已登入', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                        Text(_name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: _syncing
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.sync),
                                label: Text(_syncing ? '同步中...' : '手動同步資料'),
                                onPressed: _busy ? null : _runSync,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.qr_code),
                                label: const Text('我的 QR Code（分享給別人看）'),
                                onPressed: _busy ? null : _goMyQr,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red[400], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                                onPressed: _busy ? null : _logout,
                                child: _loggingOut
                                    ? const SizedBox(
                                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('登出'),
                              ),
                            ),
                          ]
                        : [
                            Text('登入後可將記帳記錄同步到雲端，\n在其他手機登入同一帳號也能看到。',
                                style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E7D9F),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14)),
                                onPressed: _goLogin,
                                child: const Text('登入 / 註冊'),
                              ),
                            ),
                          ],
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text('查看別人分享給你的記錄', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('掃描查看他人記錄'),
                        onPressed: _busy ? null : _goScan,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.keyboard),
                        label: const Text('輸入查看碼'),
                        onPressed: _busy ? null : _enterCode,
                      ),
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 16),
                      Text('同步進行中，請稍候再離開此畫面...', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
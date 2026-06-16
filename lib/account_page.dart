import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'sync_service.dart';
import 'login_page.dart';

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

  Future<void> _runSync() async {
    setState(() => _syncing = true);
    await SyncService.syncAfterLogin();
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('資料已同步完成')));
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    await _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(title: const Text('帳號'), backgroundColor: const Color(0xFF2E7D9F), foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _loggedIn
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
                            onPressed: _syncing ? null : _runSync,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[400], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                            onPressed: _logout,
                            child: const Text('登出'),
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
              ),
            ),
    );
  }
}
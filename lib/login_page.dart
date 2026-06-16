import 'package:flutter/material.dart';
import 'auth_service.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginPage({super.key, required this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _accountCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _isLogin = true; // true=登入畫面, false=註冊畫面
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _accountCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      Map<String, dynamic> result;

      if (_isLogin) {
        result = await AuthService.login(
          _accountCtrl.text.trim(),
          _passwordCtrl.text.trim(),
        );
      } else {
        result = await AuthService.signup(
          _accountCtrl.text.trim(),
          _passwordCtrl.text.trim(),
          _nameCtrl.text.trim(),
        );
      }

      if (result['success'] == true) {
        if (_isLogin) {
          widget.onLoginSuccess(); // 登入成功，進入主畫面
        } else {
          // 註冊成功，切換回登入畫面
          setState(() {
            _isLogin = true;
            _errorMsg = '註冊成功，請登入';
          });
        }
      } else {
        setState(() {
          _errorMsg = result['error'] ?? '發生錯誤';
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = '連線失敗，請確認伺服器是否啟動';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '記帳 App',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin ? '登入' : '註冊新帳號',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),

              if (!_isLogin)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '姓名',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),

              TextField(
                controller: _accountCtrl,
                decoration: const InputDecoration(
                  labelText: '帳號',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '密碼',
                  border: OutlineInputBorder(),
                ),
              ),

              if (_errorMsg != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _errorMsg!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D9F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isLogin ? '登入' : '註冊'),
                ),
              ),

              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                    _errorMsg = null;
                  });
                },
                child: Text(_isLogin ? '還沒有帳號？點此註冊' : '已經有帳號？點此登入'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
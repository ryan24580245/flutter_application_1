import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'apiconfig.dart';

class AuthService {
  // token 是身分憑證，不放在一般的 SharedPreferences（明文存在沙盒檔案裡）
  // 改用加密過的安全儲存區：iOS 用 Keychain、Android 用 Keystore
  static const _secureStorage = FlutterSecureStorage();
  static const _timeout = Duration(seconds: 10);

  // 註冊
  static Future<Map<String, dynamic>> signup(
      String account, String password, String name) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/signup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'account': account,
              'password': password,
              'name': name,
            }),
          )
          .timeout(_timeout);
      return jsonDecode(response.body);
    } on TimeoutException {
      return {'success': false, 'error': '網路連線逾時，請重試'};
    } catch (e) {
      return {'success': false, 'error': '連線失敗，請確認網路或伺服器是否啟動'};
    }
  }

  // 登入
  static Future<Map<String, dynamic>> login(
      String account, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'account': account,
              'password': password,
            }),
          )
          .timeout(_timeout);
      final result = jsonDecode(response.body);

      // 登入成功，把 token 存起來
      if (result['success'] == true) {
        await _secureStorage.write(key: 'token', value: result['data']['token']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('name', result['data']['name']);
      }

      return result;
    } on TimeoutException {
      return {'success': false, 'error': '網路連線逾時，請重試'};
    } catch (e) {
      return {'success': false, 'error': '連線失敗，請確認網路或伺服器是否啟動'};
    }
  }

  // 取得已儲存的 token
  static Future<String?> getToken() async {
    try {
      return await _secureStorage.read(key: 'token');
    } catch (e) {
      return null;
    }
  }

  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('name');
  }

  // 登出
  static Future<void> logout() async {
    await _secureStorage.delete(key: 'token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('name');
  }

  // 檢查是否已登入
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
}
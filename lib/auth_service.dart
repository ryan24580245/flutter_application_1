import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'apiconfig.dart';

class AuthService {
  static const _secureStorage = FlutterSecureStorage();
  static const _timeout = Duration(seconds: 10);
  static final _googleSignIn = GoogleSignIn();

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

      if (result['success'] == true) {
        await _saveSession(result['data']['token'], result['data']['name']);
      }

      return result;
    } on TimeoutException {
      return {'success': false, 'error': '網路連線逾時，請重試'};
    } catch (e) {
      return {'success': false, 'error': '連線失敗，請確認網路或伺服器是否啟動'};
    }
  }

  // 用 Google 帳號登入：跳出 Google 選擇帳號畫面，驗證成功後跟自己的後端換成自己系統的 token
  static Future<Map<String, dynamic>> loginWithGoogle() async {
    try {
      final googleAccount = await _googleSignIn.signIn();
      if (googleAccount == null) {
        return {'success': false, 'error': '已取消登入'};
      }

      final googleAuth = await googleAccount.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await fb.FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await userCredential.user!.getIdToken();

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/google'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': idToken}),
          )
          .timeout(_timeout);
      final result = jsonDecode(response.body);

      if (result['success'] == true) {
        await _saveSession(result['data']['token'], result['data']['name']);
      }

      return result;
    } on TimeoutException {
      return {'success': false, 'error': '網路連線逾時，請重試'};
    } catch (e) {
      return {'success': false, 'error': 'Google 登入失敗：$e'};
    }
  }

  static Future<void> _saveSession(String token, String name) async {
    await _secureStorage.write(key: 'token', value: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', name);
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
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      // 不是用 Google 登入的話這裡本來就會沒事可做，忽略即可
    }
  }

  // 檢查是否已登入
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
}
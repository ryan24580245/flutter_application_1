import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'apiconfig.dart';
import 'auth_service.dart';

class ShareService {
  static const _timeout = Duration(seconds: 10);

  // 列出目前帳號所有「還有效」的分享碼
  static Future<List<Map<String, dynamic>>?> listMyShares() async {
    final token = await AuthService.getToken();
    if (token == null) return null;

    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/share'), headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout);
      final result = jsonDecode(response.body);
      if (result['success'] == true) {
        return List<Map<String, dynamic>>.from(result['data']['shares'] ?? []);
      }
      return null;
    } catch (e) {
      debugPrint('listMyShares 失敗: $e');
      return null;
    }
  }

  // 建立一組新的分享碼：指定要分享哪個月份、有效期限、是否一次性
  static Future<Map<String, dynamic>?> createShare({
    required int year,
    required int month,
    required String duration,
    required bool oneTime,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) return null;

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/share'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode({'year': year, 'month': month, 'duration': duration, 'oneTime': oneTime}),
          )
          .timeout(_timeout);
      final result = jsonDecode(response.body);
      if (result['success'] == true) {
        return result['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('createShare 失敗: $e');
      return null;
    }
  }

  // 提早撤銷一組分享碼
  static Future<bool> revokeShare(String code) async {
    final token = await AuthService.getToken();
    if (token == null) return false;

    try {
      final response = await http
          .delete(Uri.parse('${ApiConfig.baseUrl}/share/$code'), headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout);
      final result = jsonDecode(response.body);
      return result['success'] == true;
    } catch (e) {
      debugPrint('revokeShare 失敗: $e');
      return false;
    }
  }

  // 用掃到的分享碼，查看別人的記帳記錄（唯讀，不需要登入）
  // 月份是建立這組碼的人決定的，這裡不用也不能指定 year/month
  static Future<Map<String, dynamic>> getSharedRecords(String code) async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/share/$code')).timeout(_timeout);
      return jsonDecode(response.body);
    } on TimeoutException {
      return {'success': false, 'error': '網路連線逾時，請重試'};
    } catch (e) {
      debugPrint('getSharedRecords 失敗: $e');
      return {'success': false, 'error': '連線失敗，請確認網路或伺服器是否啟動'};
    }
  }
}
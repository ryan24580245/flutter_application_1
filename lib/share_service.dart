import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'apiconfig.dart';
import 'auth_service.dart';

class ShareService {
  static const _timeout = Duration(seconds: 10);

  // 取得目前「有效」的分享碼狀態。沒有或已過期，shareCode 會是 null
  static Future<Map<String, dynamic>?> getMyShareStatus() async {
    final token = await AuthService.getToken();
    if (token == null) return null;

    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/share/code'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
      final result = jsonDecode(response.body);
      if (result['success'] == true) {
        return result['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('getMyShareStatus 失敗: $e');
      return null;
    }
  }

  // 依指定期限產生新的分享碼：'hour' / 'day' / 'week' / 'permanent'
  static Future<Map<String, dynamic>?> generateShareCode(String duration) async {
    final token = await AuthService.getToken();
    if (token == null) return null;

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/share/code'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode({'duration': duration}),
          )
          .timeout(_timeout);
      final result = jsonDecode(response.body);
      if (result['success'] == true) {
        return result['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('generateShareCode 失敗: $e');
      return null;
    }
  }

  // 用掃到的分享碼，查看別人的記帳記錄（唯讀，不需要登入）
  // 可以指定 year / month 只查某個月份，不傳的話伺服器會預設用現在這個月
  static Future<Map<String, dynamic>> getSharedRecords(String code, {int? year, int? month}) async {
    try {
      final query = <String, String>{};
      if (year != null) query['year'] = year.toString();
      if (month != null) query['month'] = month.toString();

      final uri = Uri.parse('${ApiConfig.baseUrl}/share/$code')
          .replace(queryParameters: query.isEmpty ? null : query);

      final response = await http.get(uri).timeout(_timeout);
      return jsonDecode(response.body);
    } on TimeoutException {
      return {'success': false, 'error': '網路連線逾時，請重試'};
    } catch (e) {
      debugPrint('getSharedRecords 失敗: $e');
      return {'success': false, 'error': '連線失敗，請確認網路或伺服器是否啟動'};
    }
  }
}
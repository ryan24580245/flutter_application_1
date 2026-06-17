import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'apiconfig.dart';
import 'auth_service.dart';

class LabelService {
  static const _timeout = Duration(seconds: 10);

  // 取得雲端存的自建標籤；沒登入、沒網路或失敗都回傳 null（呼叫端應該直接略過，不要清掉本機資料）
  static Future<List<String>?> getCloudLabels() async {
    final token = await AuthService.getToken();
    if (token == null) return null;

    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/labels'), headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout);
      final result = jsonDecode(response.body);
      if (result['success'] == true) {
        return List<String>.from(result['data']['labels'] ?? []);
      }
      return null;
    } catch (e) {
      debugPrint('getCloudLabels 失敗: $e');
      return null;
    }
  }

  // 把目前整份自建標籤清單覆蓋上傳到雲端；未登入直接略過
  static Future<void> pushLabels(List<String> labels) async {
    final token = await AuthService.getToken();
    if (token == null) return;

    try {
      await http
          .put(
            Uri.parse('${ApiConfig.baseUrl}/labels'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode({'labels': labels}),
          )
          .timeout(_timeout);
    } catch (e) {
      debugPrint('pushLabels 失敗（下次同步會再試一次）: $e');
    }
  }
}
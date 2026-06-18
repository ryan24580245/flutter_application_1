import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'apiconfig.dart';
import 'auth_service.dart';
import 'models.dart';
import 'database.dart';

class SyncService {
  static const _timeout = Duration(seconds: 10);

  // 登入成功後呼叫：把本地和雲端資料合併
  // 回傳值代表「這次同步是不是完全成功」，呼叫端可以依此判斷要不要繼續做後面的動作
  // （例如：登出前的最後一次同步如果失敗，就不該清空本機資料，避免還沒上傳的東西被刪掉）
  static Future<bool> syncAfterLogin() async {
    final token = await AuthService.getToken();
    if (token == null) return true; // 沒登入，沒有東西需要同步，視為成功

    try {
      // 1. 取得雲端所有記錄
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/transaction'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
      final result = jsonDecode(response.body);
      if (result['success'] != true) {
        debugPrint('syncAfterLogin: 取得雲端資料失敗 - ${result['error']}');
        return false;
      }

      final cloudList = result['data'] as List;
      final cloudIds = cloudList.map((e) => e['_id'] as String).toSet();

      // 2. 取得本地所有記錄
      final localTxs = await AppDatabase.instance.fetchAll();
      final localIds = localTxs.map((t) => t.id).toSet();

      // 3. 本地有、雲端沒有 → 一次打包上傳
      final toUpload = localTxs.where((t) => !cloudIds.contains(t.id)).toList();
      bool uploadOk = true;
      if (toUpload.isNotEmpty) {
        uploadOk = await _uploadBatch(token, toUpload);
      }

      // 4. 雲端有、本地沒有 → 一次寫入本機
      final toDownload = <Transaction>[];
      for (final item in cloudList) {
        final id = item['_id'] as String;
        if (!localIds.contains(id)) {
          toDownload.add(Transaction(
            id: id,
            title: item['title'],
            amountCents: item['amount'],
            isIncome: item['isIncome'],
            date: DateTime.parse('${item['date']}T${item['time']}'),
          ));
        }
      }
      if (toDownload.isNotEmpty) {
        await AppDatabase.instance.insertTxBatch(toDownload);
      }

      // 上傳沒成功才算「這次同步不完全成功」
      // 下載沒做完，最多下次再補回來，不會真的丟資料；上傳沒做完才會真的遺失本機資料
      return uploadOk;
    } catch (e) {
      debugPrint('syncAfterLogin error: $e');
      return false;
    }
  }

  // 把一批本機獨有的記錄一次送到後端，回傳是否真的成功寫入
  static Future<bool> _uploadBatch(String token, List<Transaction> txs) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/transaction/batch'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'transactions': txs
                  .map((tx) => {
                        'id': tx.id,
                        'title': tx.title,
                        'amount': tx.amountCents,
                        'isIncome': tx.isIncome,
                        'date': tx.localDateStr,
                        'time': tx.localTimeStr,
                      })
                  .toList(),
            }),
          )
          .timeout(_timeout);
      final result = jsonDecode(response.body);
      return result['success'] == true;
    } catch (e) {
      debugPrint('批量上傳失敗: $e');
      return false;
    }
  }

  // 新增單筆記帳到雲端（登入時才呼叫）
  static Future<void> uploadTransaction(Transaction tx) async {
    final token = await AuthService.getToken();
    if (token == null) return;

    try {
      await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/transaction'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'id': tx.id,
              'title': tx.title,
              'amount': tx.amountCents,
              'isIncome': tx.isIncome,
              'date': tx.localDateStr,
              'time': tx.localTimeStr,
            }),
          )
          .timeout(_timeout);
    } catch (e) {
      debugPrint('uploadTransaction 失敗（下次同步會再補）: $e');
    }
  }

  // 刪除雲端記帳（登入時才呼叫）
  static Future<void> deleteTransaction(String id) async {
    final token = await AuthService.getToken();
    if (token == null) return;

    try {
      await http
          .delete(
            Uri.parse('${ApiConfig.baseUrl}/transaction/$id'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
    } catch (e) {
      debugPrint('deleteTransaction 失敗: $e');
    }
  }
}
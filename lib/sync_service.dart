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
  static Future<void> syncAfterLogin() async {
    final token = await AuthService.getToken();
    if (token == null) return;

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
        return;
      }

      final cloudList = result['data'] as List;
      final cloudIds = cloudList.map((e) => e['_id'] as String).toSet();

      // 2. 取得本地所有記錄
      final localTxs = await AppDatabase.instance.fetchAll();
      final localIds = localTxs.map((t) => t.id).toSet();

      // 3. 本地有、雲端沒有 → 一次打包上傳（不要一筆一筆等，否則資料多時會很慢）
      final toUpload = localTxs.where((t) => !cloudIds.contains(t.id)).toList();
      if (toUpload.isNotEmpty) {
        await _uploadBatch(token, toUpload);
      }

      // 4. 雲端有、本地沒有 → 一次寫入本機（同一個資料庫交易，比逐筆寫入快很多）
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
    } catch (e) {
      debugPrint('syncAfterLogin error: $e');
      // 同步失敗不影響本機正常使用
    }
  }

  // 把一批本機獨有的記錄，一次送到後端的批量上傳 API
  static Future<void> _uploadBatch(String token, List<Transaction> txs) async {
    try {
      await http
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
    } catch (e) {
      debugPrint('批量上傳失敗（下次同步會再試一次）: $e');
    }
  }

  // 新增單筆記帳到雲端（登入時才呼叫）
  static Future<void> uploadTransaction(Transaction tx) async {
    final token = await AuthService.getToken();
    if (token == null) return; // 未登入不上傳

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
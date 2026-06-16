import 'dart:convert';
import 'package:http/http.dart' as http;
import 'apiconfig.dart';
import 'auth_service.dart';
import 'models.dart';
import 'database.dart';

class SyncService {
  // 登入成功後呼叫：把本地和雲端資料合併
  static Future<void> syncAfterLogin() async {
    final token = await AuthService.getToken();
    if (token == null) return;

    try {
      // 1. 取得雲端所有記錄
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/transaction'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final result = jsonDecode(response.body);
      if (result['success'] != true) return;

      final cloudList = result['data'] as List;
      final cloudIds = cloudList.map((e) => e['_id'] as String).toSet();

      // 2. 取得本地所有記錄
      final localTxs = await AppDatabase.instance.fetchAll();
      final localIds = localTxs.map((t) => t.id).toSet();

      // 3. 本地有、雲端沒有 → 上傳
      for (final tx in localTxs) {
        if (!cloudIds.contains(tx.id)) {
          await uploadTransaction(tx);
        }
      }

      // 4. 雲端有、本地沒有 → 下載寫入本地
      for (final item in cloudList) {
        final id = item['_id'] as String;
        if (!localIds.contains(id)) {
          final tx = Transaction(
            id: id,
            title: item['title'],
            amountCents: item['amount'],
            isIncome: item['isIncome'],
            date: DateTime.parse('${item['date']}T${item['time']}'),
          );
          await AppDatabase.instance.insertTx(tx);
        }
      }
    } catch (e) {
      // 同步失敗不影響本機正常使用
    }
  }

  // 新增單筆記帳到雲端（登入時才呼叫）
  static Future<void> uploadTransaction(Transaction tx) async {
    final token = await AuthService.getToken();
    if (token == null) return; // 未登入不上傳

    try {
      await http.post(
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
          'date': tx.date.toIso8601String().substring(0, 10),
          'time':
              '${tx.date.hour.toString().padLeft(2, '0')}:${tx.date.minute.toString().padLeft(2, '0')}:${tx.date.second.toString().padLeft(2, '0')}',
        }),
      );
    } catch (e) {
      // 上傳失敗，下次同步再補
    }
  }

  // 刪除雲端記帳（登入時才呼叫）
  static Future<void> deleteTransaction(String id) async {
    final token = await AuthService.getToken();
    if (token == null) return;

    try {
      await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/transaction/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      // 刪除失敗忽略，避免影響本機操作
    }
  }
}
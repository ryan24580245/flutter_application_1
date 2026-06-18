import 'package:flutter/material.dart';
import 'models.dart';
import 'share_service.dart';

// 這個頁面完全沒有新增/刪除/編輯的按鈕，純粹顯示，唯讀
// 月份是發 QR Code 的人決定的，這裡沒有切換月份的功能
class SharedRecordsPage extends StatefulWidget {
  final String code;
  const SharedRecordsPage({super.key, required this.code});
  @override
  State<SharedRecordsPage> createState() => _SharedRecordsPageState();
}

class _SharedRecordsPageState extends State<SharedRecordsPage> {
  bool _loading = true;
  String? _error;
  String _name = '';
  int? _year;
  int? _month;
  List<Transaction> _txs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ShareService.getSharedRecords(widget.code);
    if (!mounted) return;

    if (result['success'] == true) {
      final data = result['data'];
      final list = (data['transactions'] as List).map((item) {
        return Transaction(
          id: (item['_id'] ?? item['id'] ?? '').toString(),
          title: item['title'],
          amountCents: item['amount'],
          isIncome: item['isIncome'],
          date: DateTime.tryParse('${item['date']}T${item['time']}') ?? DateTime(2000),
        );
      }).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      setState(() {
        _name = data['name'] ?? '';
        _year = data['year'];
        _month = data['month'];
        _txs = list;
        _loading = false;
      });
    } else {
      setState(() {
        _error = result['error']?.toString() ?? '查看失敗';
        _loading = false;
      });
    }
  }

  int get _incomeCents => _txs.where((t) => t.isIncome).fold(0, (s, t) => s + t.amountCents);
  int get _expenseCents => _txs.where((t) => !t.isIncome).fold(0, (s, t) => s + t.amountCents);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(_name.isEmpty ? '查看記錄' : '$_name 的記帳記錄（唯讀）'),
        backgroundColor: const Color(0xFF2E7D9F),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (!_loading && _error == null && _year != null) ...[
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('$_year 年 $_month 月', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('收入 \$${(_incomeCents / 100).toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  Text('支出 \$${(_expenseCents / 100).toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _txs.isEmpty
                        ? const Center(child: Text('這個月沒有記錄'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _txs.length,
                            itemBuilder: (context, i) {
                              final tx = _txs[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(tx.title),
                                  subtitle: Text(tx.localDateStr),
                                  trailing: Text(
                                    '${tx.isIncome ? '+' : '-'}\$${tx.amount.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: tx.isIncome ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
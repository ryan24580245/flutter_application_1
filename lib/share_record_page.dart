import 'package:flutter/material.dart';
import 'models.dart';
import 'share_service.dart';

// 這個頁面完全沒有新增/刪除/編輯的按鈕，純粹顯示，唯讀
// 每次只抓「選定月份」的資料，不會一次把全部歷史記錄抓回來造成卡頓
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
  List<Transaction> _txs = [];
  DateTime _viewMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ShareService.getSharedRecords(
      widget.code,
      year: _viewMonth.year,
      month: _viewMonth.month,
    );
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

  void _changeMonth(int delta) {
    setState(() => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + delta));
    _load();
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _viewMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: '選擇月份',
    );
    if (picked == null) return;
    setState(() => _viewMonth = DateTime(picked.year, picked.month));
    _load();
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
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
                GestureDetector(
                  onTap: _pickMonth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${_viewMonth.year} 年 ${_viewMonth.month} 月',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
              ],
            ),
          ),
          if (!_loading && _error == null)
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
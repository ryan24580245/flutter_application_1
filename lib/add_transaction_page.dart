import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';
import 'settings.dart';
import 'label_service.dart';
import 'widgets/label_widgets.dart';

const _kDefaultExpenseLabels = [
  '早餐', '午餐', '晚餐', '飲料', '零食', '宵夜',
  '超市', '便利商店', '外送',
  '交通', '油費', '停車費', '計程車', 'Uber',
  '房租', '水費', '電費', '網路費', '手機費',
  '購物', '服飾', '藥品', '醫療',
  '娛樂', '電影', '遊戲', '訂閱',
  '學費', '書籍', '文具',
  '美容', '理髮', '健身',
  '禮物', '聚餐', '旅遊',
];

const _kDefaultIncomeLabels = [
  '薪資', '獎金', '加班費', '兼職',
  '投資', '股息', '利息',
  '退款', '年終獎金', '紅包',
  '租金收入', '其他收入',
];

class AddTransactionDialog extends StatefulWidget {
  final DateTime date;
  const AddTransactionDialog({super.key, required this.date});
  @override
  State<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<AddTransactionDialog> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _newLabelCtrl = TextEditingController();
  bool _isIncome = false;
  final _uuid = const Uuid();
  List<String> _customLabels = [];

  @override
  void initState() {
    super.initState();
    _loadCustomLabels();
    _amountCtrl.addListener(() => setState(() {}));
    _titleCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _newLabelCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomLabels() async {
    final labels = await Settings.getCustomLabels();
    if (mounted) setState(() => _customLabels = labels);
  }

  Future<void> _addCustomLabel(String label) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    if (_customLabels.any((l) => l.trim() == trimmed)) return;
    final updated = [..._customLabels, trimmed];
    await Settings.setCustomLabels(updated);
    LabelService.pushLabels(updated); // 已登入才會真正上傳，未登入自動略過
    if (mounted) setState(() => _customLabels = updated);
  }

  Future<void> _removeCustomLabel(String label) async {
    final updated = _customLabels.where((l) => l != label).toList();
    await Settings.setCustomLabels(updated);
    LabelService.pushLabels(updated); // 已登入才會真正上傳，未登入自動略過
    if (mounted) setState(() => _customLabels = updated);
  }

  void _selectLabel(String label) {
    setState(() => _titleCtrl.text = label);
  }

  void _showAddLabelDialog() {
    _newLabelCtrl.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('新增快速標籤'),
        content: TextField(
          controller: _newLabelCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '標籤名稱', border: OutlineInputBorder()),
          onSubmitted: (v) {
            _addCustomLabel(v);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D9F), foregroundColor: Colors.white),
            onPressed: () {
              _addCustomLabel(_newLabelCtrl.text);
              Navigator.pop(context);
            },
            child: const Text('新增'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    final amountYuan = double.tryParse(_amountCtrl.text.trim());
    if (title.isEmpty || amountYuan == null || amountYuan <= 0) return;

    final now = DateTime.now();
    final isViewToday = widget.date.year == now.year && widget.date.month == now.month && widget.date.day == now.day;
    final txDate = isViewToday ? now : DateTime(widget.date.year, widget.date.month, widget.date.day, 12, 0, 0);

    Navigator.pop(
      context,
      Transaction(id: _uuid.v4(), title: title, amountCents: Transaction.toCents(amountYuan), isIncome: _isIncome, date: txDate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultLabels = _isIncome ? _kDefaultIncomeLabels : _kDefaultExpenseLabels;
    final canSubmit = _titleCtrl.text.trim().isNotEmpty && (double.tryParse(_amountCtrl.text.trim()) ?? 0) > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D9F),
        foregroundColor: Colors.white,
        title: const Text('新增收支'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(children: [
        Container(
          color: const Color(0xFF2E7D9F),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(children: [
            Expanded(
                child: TypeButton(
                    label: '支出', icon: Icons.arrow_upward, selected: !_isIncome, color: Colors.red,
                    onTap: () => setState(() => _isIncome = false))),
            const SizedBox(width: 12),
            Expanded(
                child: TypeButton(
                    label: '收入', icon: Icons.arrow_downward, selected: _isIncome, color: Colors.green,
                    onTap: () => setState(() => _isIncome = true))),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('金額', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixText: '\$',
                        prefixStyle:
                            TextStyle(fontSize: 28, color: _isIncome ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                        border: InputBorder.none,
                        hintText: '0',
                        hintStyle: TextStyle(color: Colors.grey[300], fontSize: 32),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('名稱', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(hintText: '輸入或選擇下方名稱', border: OutlineInputBorder()),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              if (_customLabels.isNotEmpty) ...[
                Row(children: [
                  const Text('我的標籤', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('新增'),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF2E7D9F)),
                    onPressed: _showAddLabelDialog,
                  ),
                ]),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ..._customLabels.map((label) => GestureDetector(
                        onLongPress: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('刪除標籤？'),
                              content: Text('「$label」'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                                TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('刪除', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true) _removeCustomLabel(label);
                        },
                        child: LabelChip(
                          label: label,
                          selected: _titleCtrl.text == label,
                          color: const Color(0xFF2E7D9F),
                          onTap: () => _selectLabel(label),
                        ),
                      )),
                ]),
                const SizedBox(height: 16),
              ],
              Row(children: [
                Text(_isIncome ? '常用收入' : '常用支出', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                if (_customLabels.isEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('新增標籤'),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF2E7D9F)),
                    onPressed: _showAddLabelDialog,
                  ),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ...defaultLabels.map((label) => LabelChip(
                      label: label,
                      selected: _titleCtrl.text == label,
                      color: Colors.grey[700]!,
                      onTap: () => _selectLabel(label),
                    )),
              ]),
              const SizedBox(height: 80),
            ]),
          ),
        ),
      ]),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16, top: 8),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: canSubmit ? (_isIncome ? Colors.green : Colors.red) : Colors.grey[300],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: canSubmit ? _submit : null,
            child: Text(canSubmit ? '確定新增' : '請填寫名稱和金額', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
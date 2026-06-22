import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'location_picker.dart';
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
  // 要編輯的記錄。沒給（null）= 新增；有給 = 編輯這一筆
  final Transaction? existing;
  const AddTransactionDialog({super.key, required this.date, this.existing});
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

  // 目前這筆要存的位置（沒選就維持 null）
  double? _latitude;
  double? _longitude;
  String? _address;

  // 方便判斷現在是不是「編輯模式」
  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    // 編輯模式：把這筆記錄的現有內容先填進畫面，使用者再改
    final ex = widget.existing;
    if (ex != null) {
      _isIncome = ex.isIncome;
      _titleCtrl.text = ex.title;
      _latitude = ex.latitude;
      _longitude = ex.longitude;
      _address = ex.address;
      final a = ex.amount;
      _amountCtrl.text = a == a.roundToDouble() ? a.toStringAsFixed(0) : a.toString();
    }
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

  // 打開地圖選位置頁，回來後把選到的位置存起來
  Future<void> _pickLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(initialLat: _latitude, initialLng: _longitude),
      ),
    );
    if (result == null) return;
    setState(() {
      _latitude = result['latitude'] as double?;
      _longitude = result['longitude'] as double?;
      _address = result['address'] as String?;
    });
  }

  // 用外部 Google 地圖打開這個位置
  Future<void> _openInMaps() async {
    if (_latitude == null || _longitude == null) return;
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$_latitude,$_longitude');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('無法開啟地圖')));
    }
  }

  // 位置區塊的畫面
  Widget _buildLocationCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('位置（可選）', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
            const Spacer(),
            if (_latitude != null)
              TextButton.icon(
                icon: const Icon(Icons.close, size: 16),
                label: const Text('移除'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => setState(() {
                  _latitude = null;
                  _longitude = null;
                  _address = null;
                }),
              ),
          ]),
          const SizedBox(height: 8),
          if (_latitude == null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_location_alt),
                label: const Text('在地圖上選擇位置'),
                onPressed: _pickLocation,
              ),
            )
          else ...[
            Row(children: [
              const Icon(Icons.place, color: Color(0xFF2E7D9F)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_address ?? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_location_alt),
                  label: const Text('重新選擇'),
                  onPressed: _pickLocation,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.map),
                  label: const Text('開啟地圖'),
                  onPressed: _openInMaps,
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    final amountYuan = double.tryParse(_amountCtrl.text.trim());
    if (title.isEmpty || amountYuan == null || amountYuan <= 0) return;

    final now = DateTime.now();
    // 編輯時：沿用原本的 id（才能覆蓋同一筆）和原本的日期時間（位置不亂跳）
    // 新增時：產生一個全新的 id，並用「現在實際填寫的時間」套在所選日期上
    final ex = widget.existing;
    final id = ex?.id ?? _uuid.v4();
    final txDate = ex?.date ??
        DateTime(widget.date.year, widget.date.month, widget.date.day, now.hour, now.minute, now.second);

    Navigator.pop(
      context,
      Transaction(
        id: id,
        title: title,
        amountCents: Transaction.toCents(amountYuan),
        isIncome: _isIncome,
        date: txDate,
        latitude: _latitude,
        longitude: _longitude,
        address: _address,
      ),
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
        title: Text(_isEditing ? '編輯收支' : '新增收支'),
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
              _buildLocationCard(),
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
            child: Text(canSubmit ? (_isEditing ? '儲存修改' : '確定新增') : '請填寫名稱和金額', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

class FixedBudgetPage extends StatefulWidget {
  final double current;
  final Future<void> Function(double) onSave;
  const FixedBudgetPage({super.key, required this.current, required this.onSave});
  @override
  State<FixedBudgetPage> createState() => _FixedBudgetPageState();
}

class _FixedBudgetPageState extends State<FixedBudgetPage> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.current > 0 ? widget.current.toStringAsFixed(0) : '');
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final v = double.tryParse(_ctrl.text.trim());
    if (v == null || v < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請輸入有效金額')));
      return;
    }
    await widget.onSave(v);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('固定預算已儲存')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(title: const Text('固定預算設定'), backgroundColor: const Color(0xFF2E7D9F), foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('📌 固定預算', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('每個月初，若當月尚未設定預算，\n會自動套用此固定金額。', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 20),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '每月固定預算金額', prefixText: '\$', border: OutlineInputBorder()),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D9F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _save,
              child: const Text('儲存', style: TextStyle(fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }
}

class BudgetEditPage extends StatefulWidget {
  final String title, subtitle;
  final double current;
  final Future<void> Function(double) onSave;

  const BudgetEditPage({super.key, required this.title, required this.subtitle, required this.current, required this.onSave});

  @override
  State<BudgetEditPage> createState() => _BudgetEditPageState();
}

class _BudgetEditPageState extends State<BudgetEditPage> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.current > 0 ? widget.current.toStringAsFixed(0) : '');
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final v = double.tryParse(_ctrl.text.trim());
    if (v == null || v < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請輸入有效金額')));
      return;
    }
    await widget.onSave(v);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title),
          Text(widget.subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
        backgroundColor: const Color(0xFF2E7D9F),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(widget.subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                const SizedBox(height: 20),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '預算金額', prefixText: '\$', border: OutlineInputBorder()),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D9F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _save,
              child: const Text('確定', style: TextStyle(fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }
}
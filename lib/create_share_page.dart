import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'share_service.dart';

const _kDurations = [
  {'key': 'hour', 'label': '1 小時'},
  {'key': 'day', 'label': '1 天'},
  {'key': 'week', 'label': '1 週'},
  {'key': 'permanent', 'label': '永久有效'},
];

class CreateSharePage extends StatefulWidget {
  const CreateSharePage({super.key});
  @override
  State<CreateSharePage> createState() => _CreateSharePageState();
}

class _CreateSharePageState extends State<CreateSharePage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _oneTime = true;
  bool _loading = false;
  Map<String, dynamic>? _created;

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: '選擇要分享哪個月份',
    );
    if (picked == null) return;
    setState(() => _month = DateTime(picked.year, picked.month));
  }

  Future<void> _create(String duration) async {
    setState(() => _loading = true);
    final result = await ShareService.createShare(
      year: _month.year,
      month: _month.month,
      duration: duration,
      oneTime: _oneTime,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('產生失敗，請稍後再試')));
      return;
    }
    setState(() => _created = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('建立分享'),
        backgroundColor: const Color(0xFF2E7D9F),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _created != null
              ? _buildResult()
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('要分享哪個月份？', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('對方只能看到這個月份的資料，沒辦法切換到其他月份。', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_month),
            label: Text('${_month.year} 年 ${_month.month} 月'),
            onPressed: _pickMonth,
          ),
          const SizedBox(height: 24),
          const Text('有效期限', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: CheckboxListTile(
              value: _oneTime,
              onChanged: (v) => setState(() => _oneTime = v ?? true),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: const Color(0xFF2E7D9F),
              title: const Text('設成一次性', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('對方看過一次資料後，這組碼會立即失效。', style: TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(height: 16),
          ..._kDurations.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D9F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _create(d['key']!),
                    child: Text(d['label']!, style: const TextStyle(fontSize: 16)),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final share = _created!;
    final isOneTime = share['oneTime'] == true;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${share['year']} 年 ${share['month']} 月 的分享 QR Code',
                style: const TextStyle(fontSize: 15, color: Colors.grey)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: QrImageView(data: share['code'], size: 220),
            ),
            const SizedBox(height: 16),
            Text('查看碼：${share['code']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (isOneTime) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(8)),
                child: const Text('⚠️ 一次性：被看過一次後就會立即失效', style: TextStyle(fontSize: 12, color: Colors.deepOrange)),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D9F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('完成，回到列表'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
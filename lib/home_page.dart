import 'package:flutter/material.dart';
import 'models.dart';
import 'home_view_model.dart';
import 'widgets/home_widgets.dart';
import 'add_transaction_page.dart';
import 'budget_edit_page.dart';
import 'account_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _vm = HomeViewModel();

  @override
  void initState() {
    super.initState();
    _vm.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    // 注意：這裡故意不呼叫 AppDatabase.instance.close()
    // 全域單例的資料庫連線，不應該因為某個頁面被關閉就跟著關掉，
    // 否則之後如果加了登入頁/歡迎頁當作 App 起點，HomePage 被 pop 掉時
    // 會把資料庫整個關閉，導致其他頁面再存取就直接崩潰。
    super.dispose();
  }

  void _changeDate(int d) => _vm.changeDate(_vm.viewDate.add(Duration(days: d)));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _vm.viewDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (picked != null) _vm.changeDate(picked);
  }

  Future<void> _addTransaction() async {
    final result = await Navigator.push<Transaction>(
      context,
      MaterialPageRoute(builder: (_) => AddTransactionDialog(date: _vm.viewDate), fullscreenDialog: true),
    );
    if (result == null) return;
    try {
      await _vm.addTransaction(result);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('新增失敗，請稍後再試'), backgroundColor: Colors.red));
    }
  }

  Future<void> _distribute() async {
    try {
      final msg = await _vm.distributeEvenly();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: const Color(0xFF2E7D9F)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失敗，請稍後再試'), backgroundColor: Colors.red));
    }
  }

  void _goFixed() => Navigator.push(context, MaterialPageRoute(builder: (_) => FixedBudgetPage(current: _vm.fixedBudget, onSave: _vm.setFixedBudget)));

  void _goMonthBudget() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => BudgetEditPage(title: '本月預算設定', subtitle: _vm.yearMonth, current: _vm.monthBudget, onSave: _vm.setMonthBudget)));

  void _goDayBudget() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => BudgetEditPage(title: '當日預算設定', subtitle: _vm.dateStr, current: _vm.dayBudget, onSave: _vm.setDayBudget)));

  // 帳號入口：從帳號頁返回後重新整理（可能有同步進來的新紀錄）
  Future<void> _goAccount() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountPage()));
    if (!mounted) return;
    await _vm.init();
  }

  @override
  Widget build(BuildContext context) {
    if (_vm.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D9F),
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.savings), tooltip: '固定預算', onPressed: _goFixed),
        title: const Text('💰 記帳工具', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.account_circle), tooltip: '登入 / 帳號', onPressed: _goAccount),
        ],
      ),
      body: Column(children: [
        DateNavWidget(vm: _vm, onPrev: () => _changeDate(-1), onNext: () => _changeDate(1), onPick: _pickDate),
        BudgetCardsWidget(vm: _vm, onMonthTap: _goMonthBudget, onDayTap: _goDayBudget),
        DistributeButtonWidget(vm: _vm, onTap: _distribute),
        const SizedBox(height: 8),
        Expanded(child: TransactionListWidget(vm: _vm)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTransaction,
        backgroundColor: const Color(0xFF2E7D9F),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('新增收支'),
      ),
    );
  }
}
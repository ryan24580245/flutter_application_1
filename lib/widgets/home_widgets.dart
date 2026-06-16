import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../home_view_model.dart';

final _kNf = NumberFormat('#,##0.##');

class DateNavWidget extends StatefulWidget {
  final HomeViewModel vm;
  final VoidCallback onPrev, onNext, onPick;
  const DateNavWidget({super.key, required this.vm, required this.onPrev, required this.onNext, required this.onPick});
  @override
  State<DateNavWidget> createState() => _DateNavWidgetState();
}
class _DateNavWidgetState extends State<DateNavWidget> {
  @override
  void initState() { super.initState(); widget.vm.addListener(_r); }
  @override
  void dispose() { widget.vm.removeListener(_r); super.dispose(); }
  void _r() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) => _DateNav(
        viewDate: widget.vm.viewDate,
        isToday: widget.vm.isToday,
        onPrev: widget.onPrev,
        onNext: widget.onNext,
        onPick: widget.onPick,
      );
}

class BudgetCardsWidget extends StatefulWidget {
  final HomeViewModel vm;
  final VoidCallback onMonthTap, onDayTap;
  const BudgetCardsWidget({super.key, required this.vm, required this.onMonthTap, required this.onDayTap});
  @override
  State<BudgetCardsWidget> createState() => _BudgetCardsWidgetState();
}
class _BudgetCardsWidgetState extends State<BudgetCardsWidget> {
  @override
  void initState() { super.initState(); widget.vm.addListener(_r); }
  @override
  void dispose() { widget.vm.removeListener(_r); super.dispose(); }
  void _r() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(child: _BudgetCard(
              label: '本月預算', budget: widget.vm.monthBudget, remaining: widget.vm.monthRemaining,
              color: const Color(0xFF1565C0), onTap: widget.onMonthTap)),
          const SizedBox(width: 12),
          Expanded(child: _BudgetCard(
              label: '當日預算', budget: widget.vm.dayBudget, remaining: widget.vm.dayRemaining,
              color: const Color(0xFF00796B), onTap: widget.onDayTap)),
        ]),
      );
}

class DistributeButtonWidget extends StatefulWidget {
  final HomeViewModel vm;
  final VoidCallback onTap;
  const DistributeButtonWidget({super.key, required this.vm, required this.onTap});
  @override
  State<DistributeButtonWidget> createState() => _DistributeButtonWidgetState();
}
class _DistributeButtonWidgetState extends State<DistributeButtonWidget> {
  @override
  void initState() { super.initState(); widget.vm.addListener(_r); }
  @override
  void dispose() { widget.vm.removeListener(_r); super.dispose(); }
  void _r() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    if (!widget.vm.isToday) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.calendar_month),
          label: const Text('將本月剩餘平均分配到剩餘天數'),
          style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2E7D9F),
              side: const BorderSide(color: Color(0xFF2E7D9F)),
              padding: const EdgeInsets.symmetric(vertical: 10)),
          onPressed: widget.onTap,
        ),
      ),
    );
  }
}

class TransactionListWidget extends StatefulWidget {
  final HomeViewModel vm;
  const TransactionListWidget({super.key, required this.vm});
  @override
  State<TransactionListWidget> createState() => _TransactionListWidgetState();
}
class _TransactionListWidgetState extends State<TransactionListWidget> {
  @override
  void initState() { super.initState(); widget.vm.addListener(_r); }
  @override
  void dispose() { widget.vm.removeListener(_r); super.dispose(); }
  void _r() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) => _TransactionList(
        transactions: widget.vm.dayTransactions,
        onDelete: widget.vm.deleteTransaction,
      );
}

class _DateNav extends StatelessWidget {
  final DateTime viewDate;
  final bool isToday;
  final VoidCallback onPrev, onNext, onPick;

  const _DateNav({required this.viewDate, required this.isToday, required this.onPrev, required this.onNext, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2E7D9F),
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white), onPressed: onPrev),
          GestureDetector(
            onTap: onPick,
            child: Text(
              isToday ? '今天 ${DateFormat('yyyy/MM/dd').format(viewDate)}' : DateFormat('yyyy/MM/dd').format(viewDate),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white), onPressed: onNext),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final String label;
  final double budget, remaining;
  final Color color;
  final VoidCallback onTap;

  const _BudgetCard({required this.label, required this.budget, required this.remaining, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isNeg = remaining < 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
            const Spacer(),
            const Icon(Icons.edit, color: Colors.white54, size: 14),
          ]),
          const SizedBox(height: 6),
          Text('\$${_kNf.format(budget)}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text('\$${_kNf.format(remaining)}',
              style: TextStyle(color: isNeg ? Colors.red[200] : Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(isNeg ? '⚠ 超支' : '剩餘', style: TextStyle(color: isNeg ? Colors.red[200] : Colors.white70, fontSize: 11)),
        ]),
      ),
    );
  }
}

class _TransactionList extends StatefulWidget {
  final List<Transaction> transactions;
  final Future<void> Function(String) onDelete;
  const _TransactionList({required this.transactions, required this.onDelete});
  @override
  State<_TransactionList> createState() => _TransactionListState();
}

class _TransactionListState extends State<_TransactionList> {
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text('當日收支明細', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 14)),
      ),
      Expanded(
        child: widget.transactions.isEmpty
            ? Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.receipt_long, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Text('這天還沒有記錄', style: TextStyle(color: Colors.grey[400])),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: widget.transactions.length,
                itemBuilder: (_, i) {
                  final tx = widget.transactions[i];
                  return Dismissible(
                    key: ValueKey(tx.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: Colors.red[400], borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('刪除此筆記錄？'),
                              content: Text('「${tx.title}」'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                                TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('刪除', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          ) ??
                          false;
                      if (!confirmed) return false;
                      try {
                        await widget.onDelete(tx.id);
                        return true;
                      } catch (_) {
                        if (!context.mounted) return false;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('刪除失敗，請稍後再試'), backgroundColor: Colors.red));
                        return false;
                      }
                    },
                    child: Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: tx.isIncome ? Colors.green[50] : Colors.red[50],
                          child: Icon(tx.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                              color: tx.isIncome ? Colors.green : Colors.red, size: 18),
                        ),
                        title: Text(tx.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(DateFormat('HH:mm').format(tx.date), style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                        trailing: Text(
                          '${tx.isIncome ? '+' : '-'}\$${_kNf.format(tx.amount)}',
                          style: TextStyle(color: tx.isIncome ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Text('← 左滑項目可快速刪除', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
      ),
    ]);
  }
}
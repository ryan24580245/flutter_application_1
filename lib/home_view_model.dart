import 'package:flutter/foundation.dart';
import 'models.dart';
import 'database.dart';
import 'settings.dart';
import 'sync_service.dart';

class HomeViewModel extends ChangeNotifier {
  DateTime viewDate = DateTime.now();
  bool isLoading = true;

  double fixedBudget = 0;
  double monthBudget = 0;
  double dayBudget = 0;

  List<Transaction> _monthTxs = [];
  List<Transaction> get monthTransactions => _monthTxs;

  List<Transaction> _dayTxs = [];
  List<Transaction> get dayTransactions => _dayTxs;

  MonthSummary _monthSummary = const MonthSummary(incomeCents: 0, expenseCents: 0);
  DaySummary _daySummary = const DaySummary(incomeCents: 0, expenseCents: 0);

  double get monthRemaining => monthBudget + _monthSummary.net;
  double get dayRemaining => dayBudget + _daySummary.net;

  String get yearMonth => '${viewDate.year}-${viewDate.month.toString().padLeft(2, '0')}';
  String get dateStr => '$yearMonth-${viewDate.day.toString().padLeft(2, '0')}';

  bool get isToday {
    final n = DateTime.now();
    return viewDate.year == n.year && viewDate.month == n.month && viewDate.day == n.day;
  }

  Future<void> init() async {
    isLoading = true;
    fixedBudget = await Settings.getFixed();
    await _ensureMonthBudget(viewDate.year, viewDate.month);
    await _loadAll(viewDate.year, viewDate.month, viewDate.day);
    isLoading = false;
    notifyListeners();
  }

  Future<void> _ensureMonthBudget(int year, int month) async {
    final existing = await AppDatabase.instance.getMonthBudget(year, month);
    if (existing == null && fixedBudget > 0) {
      await AppDatabase.instance.setMonthBudget(year, month, fixedBudget);
    }
  }

  Future<void> _loadAll(int year, int month, int day) async {
    try {
      final txs = await AppDatabase.instance.fetchMonth(year, month);
      final mb = await AppDatabase.instance.getMonthBudget(year, month);
      final effectiveMb = mb ?? (fixedBudget > 0 ? fixedBudget : 0);
      final mSummary = MonthSummary.fromList(txs);
      final dTxs = txs.where((t) => t.date.day == day).toList();
      final dSummary = DaySummary.fromList(dTxs);

      final db = await AppDatabase.instance.getDayBudget(year, month, day);
      double effectiveDb;
      if (db != null) {
        effectiveDb = db;
      } else {
        final lastDay = DateTime(year, month + 1, 0).day;
        final daysLeft = lastDay - day + 1;
        final mRemaining = effectiveMb + mSummary.net;
        effectiveDb = daysLeft > 0 ? mRemaining / daysLeft : 0;
      }

      _monthTxs = txs;
      _dayTxs = dTxs;
      _monthSummary = mSummary;
      _daySummary = dSummary;
      monthBudget = effectiveMb;
      dayBudget = effectiveDb;
    } catch (e) {
      debugPrint('_loadAll error: $e');
    }
  }

  void _refreshDayCache(int day) {
    _dayTxs = _monthTxs.where((t) => t.date.day == day).toList();
    _daySummary = DaySummary.fromList(_dayTxs);
  }

  Future<void> changeDate(DateTime newDate) async {
    final crossMonth = newDate.year != viewDate.year || newDate.month != viewDate.month;

    if (crossMonth) {
      _monthTxs = [];
      _dayTxs = [];
      _monthSummary = const MonthSummary(incomeCents: 0, expenseCents: 0);
      _daySummary = const DaySummary(incomeCents: 0, expenseCents: 0);
      viewDate = newDate;
      await _ensureMonthBudget(newDate.year, newDate.month);
      await _loadAll(newDate.year, newDate.month, newDate.day);
    } else {
      viewDate = newDate;
      _refreshDayCache(newDate.day);
      final db = await AppDatabase.instance.getDayBudget(newDate.year, newDate.month, newDate.day);
      if (db != null) {
        dayBudget = db;
      } else {
        final lastDay = DateTime(newDate.year, newDate.month + 1, 0).day;
        final daysLeft = lastDay - newDate.day + 1;
        dayBudget = daysLeft > 0 ? monthRemaining / daysLeft : 0;
      }
    }
    notifyListeners();
  }

  Future<void> addTransaction(Transaction tx) async {
    await AppDatabase.instance.insertTx(tx);
    SyncService.uploadTransaction(tx); // 已登入才會真正上傳，未登入自動略過

    final sameMonth = tx.date.year == viewDate.year && tx.date.month == viewDate.month;
    if (!sameMonth) {
      notifyListeners();
      return;
    }

    final idx = _insertionIndex(_monthTxs, tx);
    _monthTxs.insert(idx, tx);
    _monthSummary = _monthSummary.add(tx);

    if (tx.date.day == viewDate.day) {
      _dayTxs.insert(_insertionIndex(_dayTxs, tx), tx);
      _daySummary = _daySummary.add(tx);
    }
    notifyListeners();
  }

  Future<void> updateTransaction(Transaction tx) async {
    // 1. 更新手機本機：insertTx 用的是「同 id 就覆蓋」，所以這裡等於把舊的換成新的
    await AppDatabase.instance.insertTx(tx);
    // 2. 更新雲端（已登入才會真正送出，未登入自動略過）
    SyncService.updateTransaction(tx);
    // 3. 重新讀取當月資料
    //    編輯可能改了金額、收支類型、甚至把日期換到別天，
    //    與其一格一格手動修畫面（容易出錯），不如直接從資料庫重讀一次，
    //    保證畫面跟資料庫完全一致，最單純也最不會錯。
    await _loadAll(viewDate.year, viewDate.month, viewDate.day);
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    await AppDatabase.instance.deleteTx(id);
    SyncService.deleteTransaction(id); // 已登入才會真正刪除雲端，未登入自動略過

    final idx = _monthTxs.indexWhere((t) => t.id == id);
    if (idx == -1) {
      notifyListeners();
      return;
    }

    final tx = _monthTxs[idx];
    _monthTxs.removeAt(idx);
    _monthSummary = _monthSummary.remove(tx);

    if (tx.date.day == viewDate.day) {
      _dayTxs.removeWhere((t) => t.id == id);
      _daySummary = _daySummary.remove(tx);
    }
    notifyListeners();
  }

  int _insertionIndex(List<Transaction> list, Transaction tx) {
    int lo = 0, hi = list.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (list[mid].date.compareTo(tx.date) <= 0) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  Future<void> setFixedBudget(double v) async {
    await Settings.setFixed(v);
    fixedBudget = v;
    final existing = await AppDatabase.instance.getMonthBudget(viewDate.year, viewDate.month);
    if ((existing == null || existing == 0) && v > 0) {
      await AppDatabase.instance.setMonthBudget(viewDate.year, viewDate.month, v);
      monthBudget = v;
    }
    notifyListeners();
  }

  Future<void> setMonthBudget(double v) async {
    await AppDatabase.instance.setMonthBudget(viewDate.year, viewDate.month, v);
    monthBudget = v;
    final existingDb = await AppDatabase.instance.getDayBudget(viewDate.year, viewDate.month, viewDate.day);
    if (existingDb == null) {
      final lastDay = DateTime(viewDate.year, viewDate.month + 1, 0).day;
      final daysLeft = lastDay - viewDate.day + 1;
      dayBudget = daysLeft > 0 ? monthRemaining / daysLeft : 0;
    }
    notifyListeners();
  }

  Future<void> setDayBudget(double v) async {
    await AppDatabase.instance.setDayBudget(viewDate.year, viewDate.month, viewDate.day, v);
    dayBudget = v;
    notifyListeners();
  }

  Future<String> distributeEvenly() async {
    final today = DateTime.now();
    if (viewDate.year != today.year || viewDate.month != today.month) {
      return '只能對當月進行平均分配';
    }
    final lastDay = DateTime(today.year, today.month + 1, 0).day;
    final daysLeft = lastDay - today.day + 1;
    if (daysLeft <= 0) return '本月已無剩餘天數';

    final snapshotRemaining = monthRemaining;
    final perDay = snapshotRemaining / daysLeft;

    final entries = <({int year, int month, int day, double value})>[];
    for (int i = 0; i < daysLeft; i++) {
      final d = DateTime(today.year, today.month, today.day + i);
      entries.add((year: d.year, month: d.month, day: d.day, value: perDay));
    }

    try {
      await AppDatabase.instance.setDayBudgetBatch(entries);
    } catch (e) {
      return '儲存失敗，請稍後再試';
    }

    dayBudget = perDay;
    notifyListeners();
    return '已平均分配，每日預算 \$${perDay.toStringAsFixed(0)}';
  }
}
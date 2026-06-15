import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.init();
  runApp(const BudgetApp());
}

// ═══════════════════════════════════════════════════════════════
// 資料模型
// ═══════════════════════════════════════════════════════════════

class Transaction {
  final String id;
  final String title;
  /// 金額以「分（整數）」儲存，避免浮點誤差（例：150元 = 15000分）
  final int amountCents;
  final bool isIncome;
  final DateTime date;

  const Transaction({
    required this.id,
    required this.title,
    required this.amountCents,
    required this.isIncome,
    required this.date,
  });

  /// 顯示用（元）
  double get amount => amountCents / 100;

  /// 從元轉分（輸入時使用）
  static int toCents(double yuan) => (yuan * 100).round();

  String get _localDateStr =>
      '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String get _localTimeStr =>
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}:'
      '${date.second.toString().padLeft(2, '0')}';

  factory Transaction.fromMap(Map<String, dynamic> m) => Transaction(
        id: m['id'] as String,
        title: m['title'] as String,
        amountCents: m['amount'] as int,
        isIncome: (m['is_income'] as int) == 1,
        date: DateTime.parse('${m['date']}T${m['time']}'),
      );
}

// ═══════════════════════════════════════════════════════════════
// 月別彙總（避免每次重算 O(n)）
// ═══════════════════════════════════════════════════════════════

class MonthSummary {
  final int incomeCents;
  final int expenseCents;

  const MonthSummary({required this.incomeCents, required this.expenseCents});

  int get netCents => incomeCents - expenseCents;
  double get net => netCents / 100;

  static MonthSummary fromList(List<Transaction> txs) {
    int inc = 0, exp = 0;
    for (final t in txs) {
      if (t.isIncome) { inc += t.amountCents; } else { exp += t.amountCents; }
    }
    return MonthSummary(incomeCents: inc, expenseCents: exp);
  }

  MonthSummary add(Transaction tx) => MonthSummary(
        incomeCents: incomeCents + (tx.isIncome ? tx.amountCents : 0),
        expenseCents: expenseCents + (tx.isIncome ? 0 : tx.amountCents),
      );

  MonthSummary remove(Transaction tx) => MonthSummary(
        incomeCents: incomeCents - (tx.isIncome ? tx.amountCents : 0),
        expenseCents: expenseCents - (tx.isIncome ? 0 : tx.amountCents),
      );
}

class DaySummary {
  final int incomeCents;
  final int expenseCents;

  const DaySummary({required this.incomeCents, required this.expenseCents});

  int get netCents => incomeCents - expenseCents;
  double get net => netCents / 100;

  static DaySummary fromList(List<Transaction> txs) {
    int inc = 0, exp = 0;
    for (final t in txs) {
      if (t.isIncome) { inc += t.amountCents; } else { exp += t.amountCents; }
    }
    return DaySummary(incomeCents: inc, expenseCents: exp);
  }

  DaySummary add(Transaction tx) => DaySummary(
        incomeCents: incomeCents + (tx.isIncome ? tx.amountCents : 0),
        expenseCents: expenseCents + (tx.isIncome ? 0 : tx.amountCents),
      );

  DaySummary remove(Transaction tx) => DaySummary(
        incomeCents: incomeCents - (tx.isIncome ? tx.amountCents : 0),
        expenseCents: expenseCents - (tx.isIncome ? 0 : tx.amountCents),
      );
}

// ═══════════════════════════════════════════════════════════════
// SQLite — 結構化預算表 + 交易表
// ═══════════════════════════════════════════════════════════════

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  // 每次新增欄位或表格時遞增此版本號
  static const _kVersion = 2;

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'budget_v2.db'),
      version: _kVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // v1 基礎結構
    await _createV1(db);
    // v2 及以上的增量 migration 也在 onCreate 一次到位
    if (version >= 2) await _migrateV1toV2(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 從 oldVersion 逐步升級到 newVersion
    if (oldVersion < 2) await _migrateV1toV2(db);
    // 未來新版本：
    // if (oldVersion < 3) await _migrateV2toV3(db);
  }

  Future<void> _createV1(Database db) async {
    await db.execute('''
      CREATE TABLE transactions (
        id        TEXT PRIMARY KEY,
        title     TEXT NOT NULL,
        amount    INTEGER NOT NULL,
        is_income INTEGER NOT NULL,
        date      TEXT NOT NULL,
        time      TEXT NOT NULL
      )
    ''');
    // date 欄是查詢主力，建立 Index 避免全表掃描
    await db.execute(
        'CREATE INDEX idx_tx_date ON transactions(date)');

    await db.execute('''
      CREATE TABLE month_budgets (
        year  INTEGER NOT NULL,
        month INTEGER NOT NULL,
        value INTEGER NOT NULL,
        PRIMARY KEY (year, month)
      )
    ''');
    await db.execute('''
      CREATE TABLE day_budgets (
        year  INTEGER NOT NULL,
        month INTEGER NOT NULL,
        day   INTEGER NOT NULL,
        value INTEGER NOT NULL,
        PRIMARY KEY (year, month, day)
      )
    ''');
  }

  /// v1 → v2：示範 migration（可按需擴充）
  Future<void> _migrateV1toV2(Database db) async {
    // 目前僅確保 index 存在（若從 v1 升上來的舊 DB 沒有 index）
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tx_date ON transactions(date)
    ''');
  }

  Future<void> close() async => await _db?.close();

  Database get db {
    assert(_db != null, 'AppDatabase not initialized');
    return _db!;
  }

  // ── 交易 ────────────────────────────────────────────────────

  Future<void> insertTx(Transaction tx) async {
    try {
      await db.insert(
        'transactions',
        {
          'id': tx.id,
          'title': tx.title,
          'amount': tx.amountCents,          // 整數分，無浮點誤差
          'is_income': tx.isIncome ? 1 : 0,
          'date': tx._localDateStr,
          'time': tx._localTimeStr,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('insertTx error: $e');
      rethrow;
    }
  }

  Future<void> deleteTx(String id) async {
    try {
      await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('deleteTx error: $e');
      rethrow;
    }
  }

  /// 查詢指定年月的所有交易，用結構化欄位（date LIKE），無 LIKE 全表掃描問題
  Future<List<Transaction>> fetchMonth(int year, int month) async {
    final datePrefix =
        '$year-${month.toString().padLeft(2, '0')}';
    try {
      final rows = await db.query(
        'transactions',
        where: 'date >= ? AND date < ?',
        // 用 >= / < 搭配日期字串，因為 date 欄格式固定為 YYYY-MM-DD，
        // 字典序就是日期序，不需要 LIKE，也不受時區影響
        whereArgs: [
          '$datePrefix-01',
          // 下個月 01 號
          () {
            final next = DateTime(year, month + 1, 1);
            return '${next.year}-${next.month.toString().padLeft(2, '0')}-01';
          }(),
        ],
        orderBy: 'date ASC, time ASC',
      );
      return rows.map((r) => Transaction(
            id: r['id'] as String,
            title: r['title'] as String,
            amountCents: r['amount'] as int,
            isIncome: (r['is_income'] as int) == 1,
            date: DateTime.parse('${r['date']}T${r['time']}'),
          )).toList();
    } catch (e) {
      debugPrint('fetchMonth error: $e');
      return [];
    }
  }

  // ── 月預算（整數分）────────────────────────────────────────

  Future<double?> getMonthBudget(int year, int month) async {
    try {
      final rows = await db.query('month_budgets',
          where: 'year = ? AND month = ?', whereArgs: [year, month]);
      if (rows.isEmpty) return null;
      return (rows.first['value'] as int) / 100;
    } catch (e) {
      debugPrint('getMonthBudget error: $e');
      return null;
    }
  }

  Future<void> setMonthBudget(int year, int month, double yuan) async {
    try {
      await db.insert(
        'month_budgets',
        {'year': year, 'month': month, 'value': (yuan * 100).round()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('setMonthBudget error: $e');
      rethrow;
    }
  }

  // ── 日預算（整數分）────────────────────────────────────────

  Future<double?> getDayBudget(int year, int month, int day) async {
    try {
      final rows = await db.query('day_budgets',
          where: 'year = ? AND month = ? AND day = ?',
          whereArgs: [year, month, day]);
      if (rows.isEmpty) return null;
      return (rows.first['value'] as int) / 100;
    } catch (e) {
      debugPrint('getDayBudget error: $e');
      return null;
    }
  }

  Future<void> setDayBudget(int year, int month, int day, double yuan) async {
    try {
      await db.insert(
        'day_budgets',
        {'year': year, 'month': month, 'day': day, 'value': (yuan * 100).round()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('setDayBudget error: $e');
      rethrow;
    }
  }

  Future<void> setDayBudgetBatch(
      List<({int year, int month, int day, double value})> entries) async {
    try {
      await db.transaction((txn) async {
        for (final e in entries) {
          await txn.insert(
            'day_budgets',
            {'year': e.year, 'month': e.month, 'day': e.day,
             'value': (e.value * 100).round()},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      debugPrint('setDayBudgetBatch error: $e');
      rethrow;
    }
  }
} // end AppDatabase

// ═══════════════════════════════════════════════════════════════
// 固定預算（SharedPreferences，全域設定）
// ═══════════════════════════════════════════════════════════════

class Settings {
  static const _fixedKey = 'fixed_budget';
  static const _customLabelsKey = 'custom_labels';

  static Future<double> getFixed() async =>
      (await SharedPreferences.getInstance()).getDouble(_fixedKey) ?? 0.0;
  static Future<void> setFixed(double v) async =>
      (await SharedPreferences.getInstance()).setDouble(_fixedKey, v);

  // 自訂快速標籤
  static Future<List<String>> getCustomLabels() async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(_customLabelsKey) ?? [];
  }

  static Future<void> setCustomLabels(List<String> labels) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_customLabelsKey, labels);
  }
}

// ═══════════════════════════════════════════════════════════════
// ViewModel — 所有計算快取，O(1) 更新
// ═══════════════════════════════════════════════════════════════

class HomeViewModel extends ChangeNotifier {
  DateTime viewDate = DateTime.now();
  bool isLoading = true;

  double fixedBudget = 0;
  double monthBudget = 0;
  double dayBudget = 0;

  // 當月所有交易（已排序）
  List<Transaction> _monthTxs = [];
  List<Transaction> get monthTransactions => _monthTxs;

  // 當日交易（從月交易 filter，只在 viewDate.day 改變時重算）
  List<Transaction> _dayTxs = [];
  List<Transaction> get dayTransactions => _dayTxs;

  // 彙總快取（O(1) 讀取）
  MonthSummary _monthSummary = const MonthSummary(incomeCents: 0, expenseCents: 0);
  DaySummary _daySummary = const DaySummary(incomeCents: 0, expenseCents: 0);

  // ── 公開衍生數字 ──────────────────────────────────────────────
  double get monthRemaining => monthBudget + _monthSummary.net;
  double get dayRemaining   => dayBudget   + _daySummary.net;

  String get yearMonth =>
      '${viewDate.year}-${viewDate.month.toString().padLeft(2, '0')}';
  String get dateStr =>
      '$yearMonth-${viewDate.day.toString().padLeft(2, '0')}';

  bool get isToday {
    final n = DateTime.now();
    return viewDate.year == n.year &&
        viewDate.month == n.month &&
        viewDate.day == n.day;
  }

  // ── 初始化 ───────────────────────────────────────────────────

  Future<void> init() async {
    // 不在 isLoading=true 時就 notify，減少一次 rebuild
    isLoading = true;
    fixedBudget = await Settings.getFixed();
    await _ensureMonthBudget(viewDate.year, viewDate.month);
    await _loadAll(viewDate.year, viewDate.month, viewDate.day);
    isLoading = false;
    notifyListeners(); // 只通知一次
  }

  /// 若當月預算未設定且 fixedBudget > 0，自動套用
  Future<void> _ensureMonthBudget(int year, int month) async {
    final existing = await AppDatabase.instance.getMonthBudget(year, month);
    if (existing == null && fixedBudget > 0) {
      await AppDatabase.instance.setMonthBudget(year, month, fixedBudget);
    }
  }

  /// 一次載入所有資料，全部算完才呼叫 notifyListeners
  Future<void> _loadAll(int year, int month, int day) async {
    try {
      // 1. 月交易
      final txs = await AppDatabase.instance.fetchMonth(year, month);

      // 2. 月預算
      final mb = await AppDatabase.instance.getMonthBudget(year, month);
      final effectiveMb = mb ?? (fixedBudget > 0 ? fixedBudget : 0);

      // 3. 月彙總（掃一次 txs，O(n)，之後都 O(1)）
      final mSummary = MonthSummary.fromList(txs);

      // 4. 日交易（filter，O(n) 但只做一次）
      final dTxs = txs.where((t) => t.date.day == day).toList();

      // 5. 日彙總
      final dSummary = DaySummary.fromList(dTxs);

      // 6. 日預算
      final db = await AppDatabase.instance.getDayBudget(year, month, day);
      double effectiveDb;
      if (db != null) {
        effectiveDb = db;
      } else {
        // 月剩餘 ÷ 剩餘天數（以 viewDate 為基準）
        final lastDay = DateTime(year, month + 1, 0).day;
        final daysLeft = lastDay - day + 1;
        final mRemaining = effectiveMb + mSummary.net;
        effectiveDb = daysLeft > 0 ? mRemaining / daysLeft : 0;
      }

      // 7. 全部算完，一次賦值
      _monthTxs    = txs;
      _dayTxs      = dTxs;
      _monthSummary = mSummary;
      _daySummary   = dSummary;
      monthBudget   = effectiveMb;
      dayBudget     = effectiveDb;
    } catch (e) {
      debugPrint('_loadAll error: $e');
    }
  }

  /// 只重算日層資料（不重載月交易，同月切日用）
  void _refreshDayCache(int day) {
    _dayTxs = _monthTxs.where((t) => t.date.day == day).toList();
    _daySummary = DaySummary.fromList(_dayTxs);
  }

  // ── 切換日期 ──────────────────────────────────────────────────

  Future<void> changeDate(DateTime newDate) async {
    final crossMonth = newDate.year != viewDate.year ||
        newDate.month != viewDate.month;
    viewDate = newDate;

    if (crossMonth) {
      // 跨月：需重新載入月資料
      await _ensureMonthBudget(newDate.year, newDate.month);
      await _loadAll(newDate.year, newDate.month, newDate.day);
    } else {
      // 同月換日：只更新日層（O(n) filter，不查 DB）
      _refreshDayCache(newDate.day);
      // 更新日預算
      final db = await AppDatabase.instance
          .getDayBudget(newDate.year, newDate.month, newDate.day);
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

  // ── 交易操作（O(1) 更新彙總，O(n) 插入排序）────────────────

  Future<void> addTransaction(Transaction tx) async {
    await AppDatabase.instance.insertTx(tx);

    final sameMonth = tx.date.year == viewDate.year &&
        tx.date.month == viewDate.month;
    if (!sameMonth) {
      notifyListeners();
      return;
    }

    // 維持排序：用 insertion 找位置，避免整體 sort O(n log n)
    final idx = _insertionIndex(_monthTxs, tx);
    _monthTxs.insert(idx, tx);

    // 更新月彙總 O(1)
    _monthSummary = _monthSummary.add(tx);

    // 若是當日，更新日快取 O(1)
    if (tx.date.day == viewDate.day) {
      _dayTxs.insert(
          _insertionIndex(_dayTxs, tx), tx);
      _daySummary = _daySummary.add(tx);
    }

    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    await AppDatabase.instance.deleteTx(id);

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

  /// 二分搜尋找插入位置，維持 date 排序，O(log n)
  /// 同時間（tie）：新資料插到後面，維持先進先出的直覺
  int _insertionIndex(List<Transaction> list, Transaction tx) {
    int lo = 0, hi = list.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      // compareTo > 0 表示 list[mid] 在 tx 之後，才移 hi
      // 同時間（== 0）讓 lo 前進，新資料插到後面
      if (list[mid].date.compareTo(tx.date) <= 0) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  // ── 預算設定 ─────────────────────────────────────────────────

  Future<void> setFixedBudget(double v) async {
    await Settings.setFixed(v);
    fixedBudget = v;
    // 若當月預算為 0 或未設定，立即套用
    final existing = await AppDatabase.instance
        .getMonthBudget(viewDate.year, viewDate.month);
    if ((existing == null || existing == 0) && v > 0) {
      await AppDatabase.instance
          .setMonthBudget(viewDate.year, viewDate.month, v);
      monthBudget = v;
    }
    notifyListeners();
  }

  Future<void> setMonthBudget(double v) async {
    await AppDatabase.instance
        .setMonthBudget(viewDate.year, viewDate.month, v);
    monthBudget = v;
    notifyListeners();
  }

  Future<void> setDayBudget(double v) async {
    await AppDatabase.instance
        .setDayBudget(viewDate.year, viewDate.month, viewDate.day, v);
    dayBudget = v;
    notifyListeners();
  }

  // ── 平均分配 ─────────────────────────────────────────────────

  Future<String> distributeEvenly() async {
    final today = DateTime.now();
    if (viewDate.year != today.year || viewDate.month != today.month) {
      return '只能對當月進行平均分配';
    }
    final lastDay = DateTime(today.year, today.month + 1, 0).day;
    final daysLeft = lastDay - today.day + 1;
    if (daysLeft <= 0) return '本月已無剩餘天數';

    // 在進入 await 前先快照，避免 async 過程中其他操作改變 monthRemaining
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

// ═══════════════════════════════════════════════════════════════
// App
// ═══════════════════════════════════════════════════════════════

class BudgetApp extends StatelessWidget {
  const BudgetApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '記帳工具',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E7D9F), brightness: Brightness.light),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 首頁 — Scaffold 骨架固定不動，只有資料區更新
// ═══════════════════════════════════════════════════════════════

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
      // init 完成後才觸發第一次 build（isLoading 已是 false）
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    AppDatabase.instance.close();
    super.dispose();
  }

  void _changeDate(int d) =>
      _vm.changeDate(_vm.viewDate.add(Duration(days: d)));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _vm.viewDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) _vm.changeDate(picked);
  }

  Future<void> _addTransaction() async {
    final result = await Navigator.push<Transaction>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionDialog(date: _vm.viewDate),
        fullscreenDialog: true,
      ),
    );
    if (result == null) return;
    try {
      await _vm.addTransaction(result);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('新增失敗，請稍後再試'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _distribute() async {
    try {
      final msg = await _vm.distributeEvenly();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg), backgroundColor: const Color(0xFF2E7D9F)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('操作失敗，請稍後再試'),
          backgroundColor: Colors.red));
    }
  }

  void _goFixed() => Navigator.push(context, MaterialPageRoute(
        builder: (_) => FixedBudgetPage(
            current: _vm.fixedBudget, onSave: _vm.setFixedBudget)));

  void _goMonthBudget() => Navigator.push(context, MaterialPageRoute(
        builder: (_) => BudgetEditPage(
            title: '本月預算設定',
            subtitle: _vm.yearMonth,
            current: _vm.monthBudget,
            onSave: _vm.setMonthBudget)));

  void _goDayBudget() => Navigator.push(context, MaterialPageRoute(
        builder: (_) => BudgetEditPage(
            title: '當日預算設定',
            subtitle: _vm.dateStr,
            current: _vm.dayBudget,
            onSave: _vm.setDayBudget)));

  @override
  Widget build(BuildContext context) {
    if (_vm.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Scaffold 結構永遠只 build 一次；
    // 資料變動由各子 Widget 透過 _vm.addListener 自行 rebuild
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D9F),
        foregroundColor: Colors.white,
        leading: IconButton(
            icon: const Icon(Icons.savings),
            tooltip: '固定預算',
            onPressed: _goFixed),
        title: const Text('💰 記帳工具',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              icon: const Icon(Icons.settings),
              tooltip: '固定預算設定',
              onPressed: _goFixed),
        ],
      ),
      body: Column(children: [
        // 日期列：viewDate 變才 rebuild
        _DateNavWidget(vm: _vm, onPrev: () => _changeDate(-1),
            onNext: () => _changeDate(1), onPick: _pickDate),
        // 預算卡片：monthBudget / dayBudget / summary 變才 rebuild
        _BudgetCardsWidget(vm: _vm,
            onMonthTap: _goMonthBudget, onDayTap: _goDayBudget),
        // 平均分配按鈕
        _DistributeButtonWidget(vm: _vm, onTap: _distribute),
        const SizedBox(height: 8),
        // 清單：dayTransactions 變才 rebuild
        Expanded(child: _TransactionListWidget(vm: _vm)),
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

// ─── 各子 Widget 自己 listen vm，只重建自己 ──────────────────

class _DateNavWidget extends StatefulWidget {
  final HomeViewModel vm;
  final VoidCallback onPrev, onNext, onPick;
  const _DateNavWidget(
      {required this.vm, required this.onPrev,
       required this.onNext, required this.onPick});
  @override
  State<_DateNavWidget> createState() => _DateNavWidgetState();
}
class _DateNavWidgetState extends State<_DateNavWidget> {
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

class _BudgetCardsWidget extends StatefulWidget {
  final HomeViewModel vm;
  final VoidCallback onMonthTap, onDayTap;
  const _BudgetCardsWidget(
      {required this.vm, required this.onMonthTap, required this.onDayTap});
  @override
  State<_BudgetCardsWidget> createState() => _BudgetCardsWidgetState();
}
class _BudgetCardsWidgetState extends State<_BudgetCardsWidget> {
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
              label: '本月預算',
              budget: widget.vm.monthBudget,
              remaining: widget.vm.monthRemaining,
              color: const Color(0xFF1565C0),
              onTap: widget.onMonthTap)),
          const SizedBox(width: 12),
          Expanded(child: _BudgetCard(
              label: '當日預算',
              budget: widget.vm.dayBudget,
              remaining: widget.vm.dayRemaining,
              color: const Color(0xFF00796B),
              onTap: widget.onDayTap)),
        ]),
      );
}

class _DistributeButtonWidget extends StatefulWidget {
  final HomeViewModel vm;
  final VoidCallback onTap;
  const _DistributeButtonWidget({required this.vm, required this.onTap});
  @override
  State<_DistributeButtonWidget> createState() => _DistributeButtonWidgetState();
}
class _DistributeButtonWidgetState extends State<_DistributeButtonWidget> {
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

class _TransactionListWidget extends StatefulWidget {
  final HomeViewModel vm;
  const _TransactionListWidget({required this.vm});
  @override
  State<_TransactionListWidget> createState() => _TransactionListWidgetState();
}
class _TransactionListWidgetState extends State<_TransactionListWidget> {
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

// ═══════════════════════════════════════════════════════════════
// 日期導航
// ═══════════════════════════════════════════════════════════════

class _DateNav extends StatelessWidget {
  final DateTime viewDate;
  final bool isToday;
  final VoidCallback onPrev, onNext, onPick;

  const _DateNav({
    required this.viewDate,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2E7D9F),
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: onPrev),
          GestureDetector(
            onTap: onPick,
            child: Text(
              isToday
                  ? '今天 ${DateFormat('yyyy/MM/dd').format(viewDate)}'
                  : DateFormat('yyyy/MM/dd').format(viewDate),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white),
              onPressed: onNext),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 預算卡片
// ═══════════════════════════════════════════════════════════════

class _BudgetCard extends StatelessWidget {
  final String label;
  final double budget, remaining;
  final Color color;
  final VoidCallback onTap;

  const _BudgetCard({
    required this.label,
    required this.budget,
    required this.remaining,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat('#,##0.##');
    final isNeg = remaining < 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3))],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            const Icon(Icons.edit, color: Colors.white54, size: 14),
          ]),
          const SizedBox(height: 6),
          Text('\$${nf.format(budget)}',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text('\$${nf.format(remaining)}',
              style: TextStyle(
                  color: isNeg ? Colors.red[200] : Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          Text(isNeg ? '⚠ 超支' : '剩餘',
              style: TextStyle(
                  color: isNeg ? Colors.red[200] : Colors.white70,
                  fontSize: 11)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 收支清單（StatefulWidget，讓 Dismissible 有穩定 context）
// ═══════════════════════════════════════════════════════════════

class _TransactionList extends StatefulWidget {
  final List<Transaction> transactions;
  final Future<void> Function(String) onDelete;

  const _TransactionList({
    required this.transactions,
    required this.onDelete,
  });

  @override
  State<_TransactionList> createState() => _TransactionListState();
}

class _TransactionListState extends State<_TransactionList> {
  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat('#,##0.##');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text('當日收支明細',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
                fontSize: 14)),
      ),
      Expanded(
        child: widget.transactions.isEmpty
            ? Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.receipt_long, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text('這天還沒有記錄',
                      style: TextStyle(color: Colors.grey[400])),
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
                      decoration: BoxDecoration(
                          color: Colors.red[400],
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    // 先確認、再刪 DB、DB 成功才回傳 true 讓 Flutter 移除 widget
                    // 若 DB 失敗，回傳 false，widget 彈回原位，畫面不失同步
                    confirmDismiss: (_) async {
                      final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('刪除此筆記錄？'),
                              content: Text('「${tx.title}」'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('取消')),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('刪除',
                                        style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          ) ??
                          false;
                      if (!confirmed) return false;
                      try {
                        await widget.onDelete(tx.id);
                        return true;   // DB 刪成功 → Flutter 移除 widget
                      } catch (_) {
                        if (!context.mounted) return false;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('刪除失敗，請稍後再試'),
                                backgroundColor: Colors.red));
                        return false;  // DB 失敗 → widget 彈回，不失同步
                      }
                    },
                    child: Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor:
                              tx.isIncome ? Colors.green[50] : Colors.red[50],
                          child: Icon(
                              tx.isIncome
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: tx.isIncome ? Colors.green : Colors.red,
                              size: 18),
                        ),
                        title: Text(tx.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(DateFormat('HH:mm').format(tx.date),
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 11)),
                        trailing: Text(
                          '${tx.isIncome ? '+' : '-'}\$${nf.format(tx.amount)}',
                          style: TextStyle(
                              color: tx.isIncome ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Text('← 左滑項目可快速刪除',
            style: TextStyle(color: Colors.grey[400], fontSize: 11)),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
// 預設快速標籤
// ═══════════════════════════════════════════════════════════════

// 支出類
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

// 收入類
const _kDefaultIncomeLabels = [
  '薪資', '獎金', '加班費', '兼職',
  '投資', '股息', '利息',
  '退款', '獎金', '紅包',
  '租金收入', '其他收入',
];

// ═══════════════════════════════════════════════════════════════
// 新增交易頁面（全頁，含快速標籤）
// ═══════════════════════════════════════════════════════════════

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
    // 金額欄位變動時觸發 rebuild（讓確定按鈕即時反應）
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
    if (trimmed.isEmpty || _customLabels.contains(trimmed)) return;
    final updated = [..._customLabels, trimmed];
    await Settings.setCustomLabels(updated);
    if (mounted) setState(() => _customLabels = updated);
  }

  Future<void> _removeCustomLabel(String label) async {
    final updated = _customLabels.where((l) => l != label).toList();
    await Settings.setCustomLabels(updated);
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
          decoration: const InputDecoration(
            labelText: '標籤名稱',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            _addCustomLabel(v);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D9F),
                foregroundColor: Colors.white),
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
    final isViewToday = widget.date.year == now.year &&
        widget.date.month == now.month &&
        widget.date.day == now.day;
    final txDate = isViewToday
        ? now
        : DateTime(widget.date.year, widget.date.month, widget.date.day, 12, 0, 0);

    Navigator.pop(context, Transaction(
      id: _uuid.v4(),
      title: title,
      amountCents: Transaction.toCents(amountYuan),
      isIncome: _isIncome,
      date: txDate,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final defaultLabels =
        _isIncome ? _kDefaultIncomeLabels : _kDefaultExpenseLabels;
    final canSubmit = _titleCtrl.text.trim().isNotEmpty &&
        (double.tryParse(_amountCtrl.text.trim()) ?? 0) > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D9F),
        foregroundColor: Colors.white,
        title: const Text('新增收支'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(children: [
        // ── 收入/支出切換 ──────────────────────────────────────
        Container(
          color: const Color(0xFF2E7D9F),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(children: [
            Expanded(child: _TypeButton(
                label: '支出', icon: Icons.arrow_upward,
                selected: !_isIncome, color: Colors.red,
                onTap: () => setState(() => _isIncome = false))),
            const SizedBox(width: 12),
            Expanded(child: _TypeButton(
                label: '收入', icon: Icons.arrow_downward,
                selected: _isIncome, color: Colors.green,
                onTap: () => setState(() => _isIncome = true))),
          ]),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── 金額輸入 ──────────────────────────────────────
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('金額',
                        style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountCtrl,
                      autofocus: true,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                          fontSize: 32, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixText: '\$',
                        prefixStyle: TextStyle(
                            fontSize: 28,
                            color: _isIncome ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold),
                        border: InputBorder.none,
                        hintText: '0',
                        hintStyle:
                            TextStyle(color: Colors.grey[300], fontSize: 32),
                      ),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 16),

              // ── 名稱輸入 ──────────────────────────────────────
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('名稱',
                        style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        hintText: '輸入或選擇下方名稱',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 16),

              // ── 自訂標籤區 ─────────────────────────────────────
              if (_customLabels.isNotEmpty) ...[
                Row(children: [
                  const Text('我的標籤',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('新增'),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2E7D9F)),
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
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('取消')),
                            TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('刪除',
                                    style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) _removeCustomLabel(label);
                    },
                    child: _LabelChip(
                      label: label,
                      selected: _titleCtrl.text == label,
                      color: const Color(0xFF2E7D9F),
                      onTap: () => _selectLabel(label),
                    ),
                  )),
                ]),
                const SizedBox(height: 16),
              ],

              // ── 預設標籤區 ─────────────────────────────────────
              Row(children: [
                Text(_isIncome ? '常用收入' : '常用支出',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                if (_customLabels.isEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('新增標籤'),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2E7D9F)),
                    onPressed: _showAddLabelDialog,
                  ),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ...defaultLabels.map((label) => _LabelChip(
                  label: label,
                  selected: _titleCtrl.text == label,
                  color: Colors.grey[700]!,
                  onTap: () => _selectLabel(label),
                )),
              ]),

              const SizedBox(height: 80), // 底部留空給按鈕
            ]),
          ),
        ),
      ]),

      // ── 確定按鈕（固定在底部）──────────────────────────────
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 8,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: canSubmit
                  ? (_isIncome ? Colors.green : Colors.red)
                  : Colors.grey[300],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: canSubmit ? _submit : null,
            child: Text(
              canSubmit ? '確定新增' : '請填寫名稱和金額',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 標籤小按鈕 ──────────────────────────────────────────────────

class _LabelChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _LabelChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label, required this.icon,
    required this.selected, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : Colors.grey[300]!),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: selected ? Colors.white : Colors.grey, size: 18),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : Colors.grey,
                  fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 固定預算頁
// ═══════════════════════════════════════════════════════════════

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
    _ctrl = TextEditingController(
        text: widget.current > 0 ? widget.current.toStringAsFixed(0) : '');
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final v = double.tryParse(_ctrl.text.trim());
    if (v == null || v < 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('請輸入有效金額')));
      return;
    }
    await widget.onSave(v);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('固定預算已儲存')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
          title: const Text('固定預算設定'),
          backgroundColor: const Color(0xFF2E7D9F),
          foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('📌 固定預算',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('每個月初，若當月尚未設定預算，\n會自動套用此固定金額。',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 20),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: '每月固定預算金額',
                      prefixText: '\$',
                      border: OutlineInputBorder()),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: _save,
              child: const Text('儲存', style: TextStyle(fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 預算編輯頁（月/日共用）
// ═══════════════════════════════════════════════════════════════

class BudgetEditPage extends StatefulWidget {
  final String title, subtitle;
  final double current;
  final Future<void> Function(double) onSave;

  const BudgetEditPage({
    super.key,
    required this.title, required this.subtitle,
    required this.current, required this.onSave,
  });

  @override
  State<BudgetEditPage> createState() => _BudgetEditPageState();
}

class _BudgetEditPageState extends State<BudgetEditPage> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.current > 0 ? widget.current.toStringAsFixed(0) : '');
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final v = double.tryParse(_ctrl.text.trim());
    if (v == null || v < 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('請輸入有效金額')));
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
          Text(widget.subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
        backgroundColor: const Color(0xFF2E7D9F),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Text(widget.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text(widget.subtitle,
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                const SizedBox(height: 20),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: '預算金額',
                      prefixText: '\$',
                      border: OutlineInputBorder()),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: _save,
              child: const Text('確定', style: TextStyle(fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }
}
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'models.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;
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
    await _createV1(db);
    for (int v = 2; v <= version; v++) {
      await _applyMigration(db, v);
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (int v = oldVersion + 1; v <= newVersion; v++) {
      await _applyMigration(db, v);
    }
  }

  Future<void> _applyMigration(Database db, int version) async {
    switch (version) {
      case 2:
        await _migrateV1toV2(db);
    }
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
    await db.execute('CREATE INDEX idx_tx_date ON transactions(date)');
    await db.execute('CREATE INDEX idx_tx_date_income ON transactions(date, is_income)');
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

  Future<void> _migrateV1toV2(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_date ON transactions(date)');
  }

  // 注意：這個方法故意不在 App 的任何頁面生命週期裡被呼叫
  // 單例的資料庫連線應該活到整個 App 行程結束，不該跟著某個頁面被關閉
  Future<void> close() async => await _db?.close();

  Database get db {
    assert(_db != null, 'AppDatabase not initialized');
    return _db!;
  }

  Future<void> insertTx(Transaction tx) async {
    try {
      await db.insert(
        'transactions',
        {
          'id': tx.id,
          'title': tx.title,
          'amount': tx.amountCents,
          'is_income': tx.isIncome ? 1 : 0,
          'date': tx.localDateStr,
          'time': tx.localTimeStr,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('insertTx error: $e');
      rethrow;
    }
  }

  // 批量寫入：把多筆記錄包在「同一個資料庫交易」裡，比逐筆 insertTx 快很多
  // 同步下載雲端資料時用這個，而不是在迴圈裡一筆一筆呼叫 insertTx
  Future<void> insertTxBatch(List<Transaction> txs) async {
    if (txs.isEmpty) return;
    try {
      await db.transaction((txn) async {
        for (final tx in txs) {
          await txn.insert(
            'transactions',
            {
              'id': tx.id,
              'title': tx.title,
              'amount': tx.amountCents,
              'is_income': tx.isIncome ? 1 : 0,
              'date': tx.localDateStr,
              'time': tx.localTimeStr,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      debugPrint('insertTxBatch error: $e');
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

  // 清空本機所有記帳記錄（用在登出/切換帳號時，避免舊帳號的資料留在本機被下一個帳號看到）
  Future<void> clearTransactions() async {
    try {
      await db.delete('transactions');
    } catch (e) {
      debugPrint('clearTransactions error: $e');
      rethrow;
    }
  }

  Future<List<Transaction>> fetchMonth(int year, int month, {int limit = -1, int offset = 0}) async {
    final mm = month.toString().padLeft(2, '0');
    final nextMonth = DateTime(year, month + 1, 1);
    final nextMM = nextMonth.month.toString().padLeft(2, '0');
    final nextYYYY = nextMonth.year.toString();
    try {
      final rows = await db.query(
        'transactions',
        where: 'date >= ? AND date < ?',
        whereArgs: ['$year-$mm-01', '$nextYYYY-$nextMM-01'],
        orderBy: 'date ASC, time ASC',
        limit: limit > 0 ? limit : null,
        offset: offset > 0 ? offset : null,
      );
      return rows.map(Transaction.fromMap).toList();
    } catch (e) {
      debugPrint('fetchMonth error: $e');
      return [];
    }
  }

  /// 取得全部交易（同步用）
  Future<List<Transaction>> fetchAll() async {
    try {
      final rows = await db.query('transactions', orderBy: 'date ASC, time ASC');
      return rows.map(Transaction.fromMap).toList();
    } catch (e) {
      debugPrint('fetchAll error: $e');
      return [];
    }
  }

  Future<int> countMonth(int year, int month) async {
    final mm = month.toString().padLeft(2, '0');
    final nextMonth = DateTime(year, month + 1, 1);
    final nextMM = nextMonth.month.toString().padLeft(2, '0');
    final nextYYYY = nextMonth.year.toString();
    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM transactions WHERE date >= ? AND date < ?',
        ['$year-$mm-01', '$nextYYYY-$nextMM-01'],
      );
      return (result.first['cnt'] as int?) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<double?> getMonthBudget(int year, int month) async {
    try {
      final rows = await db.query('month_budgets', where: 'year = ? AND month = ?', whereArgs: [year, month]);
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

  Future<double?> getDayBudget(int year, int month, int day) async {
    try {
      final rows = await db.query('day_budgets',
          where: 'year = ? AND month = ? AND day = ?', whereArgs: [year, month, day]);
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

  Future<void> setDayBudgetBatch(List<({int year, int month, int day, double value})> entries) async {
    try {
      await db.transaction((txn) async {
        for (final e in entries) {
          await txn.insert(
            'day_budgets',
            {'year': e.year, 'month': e.month, 'day': e.day, 'value': (e.value * 100).round()},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      debugPrint('setDayBudgetBatch error: $e');
      rethrow;
    }
  }
}
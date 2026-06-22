import 'package:flutter/foundation.dart';

class Transaction {
  final String id;
  final String title;
  final int amountCents;
  final bool isIncome;
  final DateTime date;
  // 位置（可選）：沒有就是 null，代表這筆沒有標記位置
  final double? latitude;
  final double? longitude;
  final String? address;

  const Transaction({
    required this.id,
    required this.title,
    required this.amountCents,
    required this.isIncome,
    required this.date,
    this.latitude,
    this.longitude,
    this.address,
  });

  // 方便判斷這筆有沒有位置
  bool get hasLocation => latitude != null && longitude != null;

  double get amount => amountCents / 100;
  static int toCents(double yuan) => (yuan * 100).round();

  String get localDateStr =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String get localTimeStr =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';

  factory Transaction.fromMap(Map<String, dynamic> m) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse('${m['date']}T${m['time']}');
    } catch (_) {
      debugPrint('Transaction.fromMap: invalid date=${m['date']} time=${m['time']}, using epoch');
      parsedDate = DateTime(2000);
    }
    return Transaction(
      id: m['id'] as String,
      title: m['title'] as String,
      amountCents: m['amount'] as int,
      isIncome: (m['is_income'] as int) == 1,
      date: parsedDate,
      latitude: (m['latitude'] as num?)?.toDouble(),
      longitude: (m['longitude'] as num?)?.toDouble(),
      address: m['address'] as String?,
    );
  }
}

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
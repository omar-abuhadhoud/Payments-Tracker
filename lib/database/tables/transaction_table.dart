import 'package:payments_tracker_flutter/models/transaction_model.dart';
import '../database_helper.dart';
import 'package:intl/intl.dart';

class TransactionTable {
  static const table = DatabaseHelper.tableTransactions;

  // ---------------- CRUD METHODS ----------------

  /// Insert transaction
  static Future<int> insertTransaction(TransactionModel txn) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert(table, txn.toMap());
  }

  /// Get all unique month and year combinations that have transactions for a specific account.
  static Future<Set<DateTime>> getUniqueTransactionMonthsForAccount(
    int? accountId, {
    bool descending = true,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT DISTINCT strftime('%Y-%m-01', createdAt) as transactionMonthYear
      FROM $table
      WHERE accountId = ?
      ORDER BY transactionMonthYear ${descending ? 'DESC' : 'ASC'}
      ''',
      [accountId],
    );

    if (maps.isEmpty) return {};

    return maps.map((row) {
      // The query returns 'YYYY-MM-01', so DateTime.parse will correctly interpret it.
      return DateTime.parse(row['transactionMonthYear'] as String);
    }).toSet();
  }

  /// Get all transactions (ordered by newest first)
  static Future<List<TransactionModel>> getAllTransactions() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(table, orderBy: 'createdAt DESC');
    return result.map((row) => TransactionModel.fromMap(row)).toList();
  }

  static Future<Map<String, double>> getMonthlySummary(
    DateTime date,
    int? accountId,
  ) async {
    if (accountId == null) {
      return {'income': 0.0, 'expense': 0.0, 'overallBalance': 0.0};
    }

    final db = await DatabaseHelper.instance.database;

    // Month boundaries
    final monthStart = DateTime(date.year, date.month, 1, 0, 0, 0);
    final monthEnd = DateTime(date.year, date.month + 1, 0, 23, 59, 59);

    // Format compatible with SQLite datetime()
    String fmt(DateTime dt) => DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);

    final rows = await db.rawQuery(
      '''
    SELECT
      SUM(CASE WHEN amount > 0 AND datetime(createdAt) BETWEEN datetime(?) AND datetime(?) THEN amount ELSE 0 END) AS totalIncome,
      SUM(CASE WHEN amount < 0 AND datetime(createdAt) BETWEEN datetime(?) AND datetime(?) THEN amount ELSE 0 END) AS totalExpense,
      SUM(CASE WHEN datetime(createdAt) <= datetime(?) THEN amount ELSE 0 END) AS totalBalance
    FROM $table
    WHERE accountId = ?
  ''',
      [
        fmt(monthStart), fmt(monthEnd), // for income
        fmt(monthStart), fmt(monthEnd), // for expense
        fmt(monthEnd),
        accountId,
      ],
    );

    double income = 0.0, expense = 0.0, overall = 0.0;
    if (rows.isNotEmpty) {
      final r = rows.first;
      income = (r['totalIncome'] as num?)?.toDouble() ?? 0.0;
      expense = ((r['totalExpense'] as num?)?.toDouble() ?? 0.0).abs();
      overall = (r['totalBalance'] as num?)?.toDouble() ?? 0.0;
    }

    return {'income': income, 'expense': expense, 'overallBalance': overall};
  }

  static Future<List<Map<String, dynamic>>>
  getDailyNetWithCumulativeBalanceForMonth(
    int? accountId,
    DateTime date,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final year = date.year;
    final month = date.month;
    final monthString = month.toString().padLeft(2, '0');
    final yearString = year.toString();

    double cumulativeBalance = 0.0;

    // Get the balance from the beginning of time until the start of the current month
    final firstDayOfMonth = DateTime(year, month, 1);
    final balanceBeforeMonthResult = await db.rawQuery(
      '''
      SELECT SUM(amount) as balance
      FROM $table
      WHERE accountId = ? AND createdAt < ?
    ''',
      [accountId, firstDayOfMonth.toIso8601String()],
    );

    if (balanceBeforeMonthResult.isNotEmpty &&
        balanceBeforeMonthResult.first['balance'] != null) {
      cumulativeBalance =
          (balanceBeforeMonthResult.first['balance'] as num?)?.toDouble() ??
          0.0;
    }

    final result = await db.rawQuery(
      '''
      WITH DailySums AS (
        SELECT 
          CAST(strftime('%d', createdAt) AS INTEGER) as dayNumber,
          SUM(amount) as dailyNet
        FROM $table
        WHERE accountId = ? AND strftime('%Y', createdAt) = ? AND strftime('%m', createdAt) = ?
        GROUP BY dayNumber
      )
      SELECT 
        ds.dayNumber,
        ds.dailyNet,
        ? + SUM(ds.dailyNet) OVER (ORDER BY ds.dayNumber ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as cumulativeBalance
      FROM DailySums ds
      ORDER BY ds.dayNumber ASC
    ''',
      [accountId, yearString, monthString, cumulativeBalance],
    );

    return result.map((row) {
      return {
        'dayNumber': row['dayNumber'] as int,
        'dailyNet': (row['dailyNet'] as num?)?.toDouble() ?? 0.0,
        'cumulativeBalance':
            (row['cumulativeBalance'] as num?)?.toDouble() ?? 0.0,
      };
    }).toList();
  }

  static Future<int> getTransactionsCountForAccount(int? accountId) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      table,
      where: 'accountId = ?',
      whereArgs: [accountId],
    );
    return result.length;
  }

  /// Get single transaction by id
  static Future<TransactionModel?> getTransactionById(int id) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(table, where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) {
      return TransactionModel.fromMap(result.first);
    }
    return null;
  }

  /// Get balance until a specific transaction
  static Future<double> getBalanceUntilTransactionByTransactionIdForAccount(
    int transactionId,
    int? accountId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      '''
      SELECT SUM(amount) as balance
      FROM $table
      WHERE accountId = ? AND id <= ?
    ''',
      [accountId, transactionId],
    );

    if (result.isNotEmpty && result.first['balance'] != null) {
      return result.first['balance'] as double;
    }
    return 0.0;
  }

  /// Get total balance for a specific account
  static Future<double> getTotalBalanceForAccount(int? accountId) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      '''
      SELECT SUM(amount) as balance
      FROM $table
      WHERE accountId = ?
    ''',
      [accountId],
    );

    if (result.isNotEmpty && result.first['balance'] != null) {
      return result.first['balance'] as double;
    }
    return 0.0;
  }

  /// Get today's balance
  static Future<double> getTodayBalanceForAccount(int? accountId) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);

    final result = await db.rawQuery(
      '''
      SELECT SUM(amount) as balance
      FROM $table
      WHERE accountId = ? AND DATE(createdAt) = ?
    ''',
      [accountId, today],
    );

    if (result.isNotEmpty && result.first['balance'] != null) {
      return result.first['balance'] as double;
    }
    return 0.0;
  }

  /// Update transaction
  static Future<int> updateTransaction(TransactionModel txn) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      table,
      txn.toMap(),
      where: 'id = ?',
      whereArgs: [txn.id],
    );
  }

  /// Delete transaction
  static Future<int> deleteTransaction(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  // ---- Methods for Day-by-Day Pagination ----

  static Future<double> getTotalExpense() async {
    final db = await DatabaseHelper.instance.database;
    final expense = await db.rawQuery('''
      SELECT SUM(amount) as expense
      FROM $table
      WHERE amount<0
    ''');
    return (expense.first['expense'] as num?)?.toDouble().abs() ?? 0.0;
  }

  static Future<double> getTotalIncome() async {
    final db = await DatabaseHelper.instance.database;
    final expense = await db.rawQuery('''
      SELECT SUM(amount) as income
      FROM $table
      WHERE amount>0
    ''');
    return (expense.first['income'] as num?)?.toDouble() ?? 0.0;
  }

  /// Fetches a list of unique dates that have transactions, sorted.
  static Future<List<DateTime>> getUniqueTransactionDates({
    bool descending = true,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT DISTINCT DATE(createdAt) as transactionDate '
      'FROM $table '
      'ORDER BY transactionDate ${descending ? 'DESC' : 'ASC'}',
    );

    if (maps.isEmpty) return [];

    return maps
        .map((row) => DateTime.parse(row['transactionDate'] as String))
        .toList();
  }

  /// Fetches a list of unique dates that have transactions for a specific account, sorted.
  static Future<List<DateTime>> getUniqueTransactionDatesForAccount(
    int? accountId, {
    bool descending = true,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT DISTINCT DATE(createdAt) as transactionDate '
      'FROM $table '
      'WHERE accountId = ? '
      'ORDER BY transactionDate ${descending ? 'DESC' : 'ASC'}',
      [accountId],
    );

    if (maps.isEmpty) return [];

    return maps
        .map((row) => DateTime.parse(row['transactionDate'] as String))
        .toList();
  }

  /// Fetches all transactions for a specific date and account.
  static Future<List<TransactionModel>> getTransactionsForDateAndAccount(
    DateTime date,
    int? accountId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final dateString = date.toIso8601String().substring(0, 10);

    final List<Map<String, dynamic>> maps = await db.query(
      table,
      where: 'DATE(createdAt) = ? AND accountId = ?',
      whereArgs: [dateString, accountId],
      orderBy: 'createdAt DESC',
    );

    if (maps.isEmpty) return [];

    return maps.map((row) => TransactionModel.fromMap(row)).toList();
  }

  /// Fetches all transactions for a specific month and account.
  static Future<List<TransactionModel>> getTransactionsForMonthAndAccount(
    int year,
    int month,
    int? accountId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    // Format month to be two digits (e.g., '01' for January)
    final monthString = month.toString().padLeft(2, '0');

    final List<Map<String, dynamic>> maps = await db.query(
      table,
      where: "strftime('%Y-%m', createdAt) = ? AND accountId = ?",
      whereArgs: ['${year.toString()}-$monthString', accountId],
      orderBy: 'createdAt DESC',
    );

    if (maps.isEmpty) {
      return [];
    }

    return maps.map((row) => TransactionModel.fromMap(row)).toList();
  }

  /// Fetches all transactions for a specific date.
  static Future<List<TransactionModel>> getTransactionsForDate(
    DateTime date,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final dateString = date.toIso8601String().substring(0, 10);

    final List<Map<String, dynamic>> maps = await db.query(
      table,
      where: 'DATE(createdAt) = ?',
      whereArgs: [dateString],
      orderBy: 'createdAt DESC',
    );

    if (maps.isEmpty) return [];

    return maps.map((row) => TransactionModel.fromMap(row)).toList();
  }
}

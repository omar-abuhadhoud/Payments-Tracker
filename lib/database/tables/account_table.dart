import 'package:payments_tracker_flutter/database/database_helper.dart';
import 'package:payments_tracker_flutter/database/tables/transaction_table.dart';
import 'package:payments_tracker_flutter/models/account_model.dart';
import 'package:sqflite/sqflite.dart';

class AccountTable {
  static const table = DatabaseHelper.tableAccounts;
  static const int maxPinnedAccounts = 3;

  static Future<int> insert(AccountModel account) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert(table, account.toMap());
  }

  static Future<List<AccountModel>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(table);
    return maps.map((e) => AccountModel.fromMap(e)).toList();
  }

  static Future<List<Map<String, dynamic>>> getAllAccountsWithBalances() async {
    final db = await DatabaseHelper.instance.database;
    //get all columns from accounts table and sum of amount from transactions table for each account
    final maps = await db.rawQuery('''
      SELECT
        "$table".*,
        COALESCE(SUM("${TransactionTable.table}".amount), 0.0) as balance
      FROM $table
      LEFT JOIN ${TransactionTable.table} ON $table.id = ${TransactionTable.table}.accountId
      GROUP BY $table.id
    ''');
    return maps.map((map) {
      final account = AccountModel.fromMap(map);
      final balance =
          map['balance'] as num; // Assuming balance is a numeric type
      return {'account': account, 'balance': balance};
    }).toList();
  }

  static Future<int> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> update(AccountModel account) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      table,
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  static Future<bool> pin(int id) async {
    final db = await DatabaseHelper.instance.database;
    return db.transaction((txn) async {
      final accountRows = await txn.query(
        table,
        columns: ['pinOrder'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (accountRows.isEmpty) return false;
      if (accountRows.first['pinOrder'] != null) return true;

      final pinnedCount =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM $table WHERE pinOrder IS NOT NULL',
            ),
          ) ??
          0;
      if (pinnedCount >= maxPinnedAccounts) return false;

      final maxOrderRows = await txn.rawQuery(
        'SELECT MAX(pinOrder) AS maxPinOrder FROM $table',
      );
      final maxPinOrder = maxOrderRows.first['maxPinOrder'] as int? ?? 0;
      await txn.update(
        table,
        {'pinOrder': maxPinOrder + 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      return true;
    });
  }

  static Future<int> unpin(int id) async {
    final db = await DatabaseHelper.instance.database;
    return db.update(
      table,
      {'pinOrder': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

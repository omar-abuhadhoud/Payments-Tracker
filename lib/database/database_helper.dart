import 'dart:io'; // Needed for File operations

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart'; // Added for DateFormat, though not strictly necessary for query construction if using ISO strings
import '../models/transaction_model.dart';
import '../models/account_model.dart'; // Added for AccountModel
import './tables/account_table.dart'; // Added for AccountTable

class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const String _databaseName = 'payment_tracker.db';

  static const String tableTransactions = 'transactions';
  static const String tableAccounts = 'accounts';

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null && _database!.isOpen)
      return _database!; // Check if open
    _database = await _initDB(_databaseName);
    return _database!;
  }

  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, _databaseName);
  }

  Future<void> closeDatabase() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null; // Set to null after closing
      print('DatabaseHelper: Database closed.');
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // --- Start Added Logging ---
    print('DatabaseHelper: Initializing database at path: $path');
    try {
      final exists = await databaseExists(path);
      print('DatabaseHelper: Database file exists at path? $exists');
    } catch (e) {
      print('DatabaseHelper: Error checking if database exists: $e');
    }
    // --- End Added Logging ---

    return await openDatabase(
      path,
      version: 6,
      onCreate: (Database db, int version) async {
        // --- Added Logging ---
        print(
          'DatabaseHelper: onCreate called. Version: $version. Creating tables...',
        );
        await _createDB(db, version);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        // --- Added Logging ---
        print(
          'DatabaseHelper: onUpgrade called. Old Version: $oldVersion, New Version: $newVersion. Upgrading schema...',
        );
        await _onUpgrade(db, oldVersion, newVersion);
      },
      onOpen: (Database db) async {
        // <-- Made onOpen async
        // --- Added Logging ---
        print('DatabaseHelper: onOpen called. Database is open.');
        // Enable foreign key constraints
        await db.execute('PRAGMA foreign_keys = ON;');
        print('DatabaseHelper: Foreign key constraints ENABLED.');
      },
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS daily_closing_info');
      print(
        'DatabaseHelper: Upgraded to V3 - Dropped daily_closing_info table',
      );
    }

    if (oldVersion < 4) {
      // Create new accounts table
      await db.execute('''
        CREATE TABLE $tableAccounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL
        )
      ''');

      await db.execute(
        'ALTER TABLE $tableTransactions RENAME TO ${tableTransactions}_old',
      );

      await db.execute('''
      CREATE TABLE $tableTransactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      amount REAL NOT NULL,
      note TEXT,
      createdAt TEXT NOT NULL,
      accountId INTEGER NOT NULL,
      FOREIGN KEY (accountId) REFERENCES accounts(id) ON DELETE Restrict
    )
  ''');

      final List<Map<String, Object?>> defaultAccountCheck = await db.query(
        'accounts',
        where: 'name = ?',
        whereArgs: ['Default Account'],
      );

      int defaultAccountId;
      if (defaultAccountCheck.isEmpty) {
        defaultAccountId = await db.insert('accounts', {
          'name': 'Default Account',
        });
      } else {
        defaultAccountId = defaultAccountCheck.first['id'] as int;
      }

      await db.execute('''
    INSERT INTO $tableTransactions (id, amount, note, createdAt, accountId)
    SELECT id, amount, note, createdAt, $defaultAccountId
    FROM ${tableTransactions}_old
  ''');

      await db.execute('DROP TABLE ${tableTransactions}_old');
    }

    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE $tableTransactions RENAME TO ${tableTransactions}_old',
      );

      await db.execute('''
      CREATE TABLE $tableTransactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      amount REAL NOT NULL,
      note TEXT,
      createdAt TEXT NOT NULL,
      accountId INTEGER NOT NULL,
      FOREIGN KEY (accountId) REFERENCES accounts(id) ON DELETE CASCADE
    )
  ''');

      await db.execute('''
    INSERT INTO $tableTransactions (id, amount, note, createdAt, accountId)
    SELECT id, amount, note, createdAt, accountId
    FROM ${tableTransactions}_old
  ''');

      await db.execute('DROP TABLE ${tableTransactions}_old');
    }

    if (oldVersion < 6) {
      await db.execute(
        'ALTER TABLE $tableAccounts ADD COLUMN pinOrder INTEGER',
      );
      print('DatabaseHelper: Upgraded to V6 - Added account pin order');
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableAccounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        pinOrder INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableTransactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        note TEXT,
        createdAt TEXT NOT NULL,
        accountId INTEGER NOT NULL,
        FOREIGN KEY (accountId) REFERENCES $tableAccounts(id) ON DELETE CASCADE
      )
    ''');

    await db.insert(tableAccounts, {'name': 'Default Account'});
  }

  Future<void> resetDatabase() async {
    // Ensure database is open before reset
    final db = await instance.database;
    if (!db.isOpen) {
      print('DatabaseHelper: Database was closed. Re-opening for reset.');
      _database = await _initDB(_databaseName); // Re-initialize if closed
    }

    final tables = await _database!.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_metadata';", // Exclude android_metadata
    );

    final batch = _database!.batch();

    for (var tableMap in tables) {
      final tableName = tableMap['name'] as String;
      if (tableName == 'sqlite_sequence')
        continue; // sqlite_sequence is handled differently

      batch.delete(tableName);
      // For sqlite_sequence, we update the sequence for tables that were cleared
      batch.rawUpdate("UPDATE sqlite_sequence SET seq = 0 WHERE name = ?", [
        tableName,
      ]);
    }
    // Also specifically reset for tables that might not have entries but exist
    // This part might be redundant if tables are always in sqlite_sequence after creation
    batch.rawUpdate(
      "DELETE FROM sqlite_sequence",
    ); // Clear all sequence counts, they will be repopulated

    await batch.commit(noResult: true);
    print(
      'DatabaseHelper: resetDatabase EXECUTED. All user tables cleared, sequences reset.',
    );

    // Re-create default account after reset if necessary
    final defaultAccountCheck = await _database!.query(
      tableAccounts,
      where: 'name = ?',
      whereArgs: ['Default Account'],
    );
    if (defaultAccountCheck.isEmpty) {
      await _database!.insert(tableAccounts, {'name': 'Default Account'});
      print('DatabaseHelper: Default Account re-created after reset.');
    }
  }

  // --- Backup and Restore ---
  Future<bool> createBackup(String backupPath) async {
    try {
      await closeDatabase(); // Close DB before copying
      final dbPath = await getDatabasePath();
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.copy(backupPath);
        print('DatabaseHelper: Backup created successfully at $backupPath');
        await database; // Re-open database
        return true;
      } else {
        print('DatabaseHelper: Database file does not exist at $dbPath');
        await database; // Re-open database if it was somehow not found
        return false;
      }
    } catch (e) {
      print('DatabaseHelper: Error creating backup: $e');
      await database; // Ensure database is re-opened on error
      return false;
    }
  }

  Future<bool> restoreBackup(String backupPath) async {
    try {
      await closeDatabase(); // Close DB before restoring
      final dbPath = await getDatabasePath();
      final backupFile = File(backupPath);

      if (await backupFile.exists()) {
        await backupFile.copy(dbPath); // This overwrites the current DB
        print('DatabaseHelper: Backup restored successfully from $backupPath');
        _database = await _initDB(
          _databaseName,
        ); // Re-initialize and open the restored DB
        return true;
      } else {
        print('DatabaseHelper: Backup file does not exist at $backupPath');
        await database; // Re-open original database if backup not found
        return false;
      }
    } catch (e) {
      print('DatabaseHelper: Error restoring backup: $e');
      await database; // Ensure database is re-opened on error
      return false;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import 'package:payments_tracker_flutter/database/tables/account_table.dart';
import 'package:payments_tracker_flutter/database/tables/transaction_table.dart';
import 'package:payments_tracker_flutter/global_variables/chosen_account.dart';
import 'package:payments_tracker_flutter/models/account_model.dart';
import 'package:payments_tracker_flutter/widgets/account_card.dart';
import 'package:payments_tracker_flutter/screens/account_main_screen.dart';
import 'package:payments_tracker_flutter/database/database_helper.dart';
import 'package:payments_tracker_flutter/global_variables/app_colors.dart';

import '../widgets/basic/safe_scaffold.dart';
import '../widgets/utility.dart';

class TotalOverview extends StatefulWidget {
  const TotalOverview({Key? key}) : super(key: key);

  @override
  State<TotalOverview> createState() => _TotalOverviewState();
}

class _TotalOverviewState extends State<TotalOverview> {
  double totalExpense = 0.0;
  double totalIncome = 0.0;
  double totalBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final expense =
        await TransactionTable.getTotalExpense(); // Your DB function
    final income = await TransactionTable.getTotalIncome(); // Your DB function
    setState(() {
      totalIncome = income;
      totalExpense = expense;
      totalBalance = income - expense;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.purple.withValues(alpha: .15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          // 1. Income Row
          _buildSummaryRow('Income:', totalIncome, AppColors.incomeGreen),
          const SizedBox(height: 8),

          // 2. Expense Row
          _buildSummaryRow('Expense:', totalExpense, AppColors.expenseRed),

          const Divider(height: 20, thickness: 1), // Visual separator
          // 3. Balance Row
          _buildSummaryRow(
            'Balance:',
            totalBalance,
            totalBalance >= 0 ? AppColors.incomeGreen : AppColors.expenseRed,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, Color valueColor) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        Utility.handleNumberAppearanceForOverflow(
          number: value,
          color: valueColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ],
    );
  }
}

class ChooseAccountScreen extends StatefulWidget {
  const ChooseAccountScreen({Key? key}) : super(key: key);

  @override
  State<ChooseAccountScreen> createState() => _ChooseAccountScreenState();
}

class _ChooseAccountScreenState extends State<ChooseAccountScreen> {
  // Store accounts with their balances
  List<Map<String, dynamic>> _accountsData = [];
  List<Map<String, dynamic>> _filteredAccountsData = [];

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _resetConfirmController = TextEditingController();
  final TextEditingController _deleteConfirmController =
      TextEditingController();
  final TextEditingController _editAccountNameController =
      TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();

  bool _isInitiallyLoading = true;
  bool _isSortAscending = true; // 🔽 Asc first by default

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    _editAccountNameController.dispose();
    _resetConfirmController.dispose();
    _deleteConfirmController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(_filterAccounts);
  }

  void _filterAccounts() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      _filteredAccountsData = List.from(_accountsData);
    } else {
      _filteredAccountsData = _accountsData.where((accountData) {
        final accountName = (accountData['account'] as AccountModel).name
            .toLowerCase();
        return accountName.contains(query);
      }).toList();
    }
    _applySort();
  }

  void _applySort() {
    _filteredAccountsData.sort((a, b) {
      final double balanceA = (a['balance'] as num).toDouble();
      final double balanceB = (b['balance'] as num).toDouble();
      return _isSortAscending
          ? balanceA.compareTo(balanceB)
          : balanceB.compareTo(balanceA);
    });
  }

  Future<void> _loadAccounts() async {
    if (mounted) {
      setState(() => _isInitiallyLoading = true);
    }

    _accountsData = await AccountTable.getAllAccountsWithBalances();

    if (mounted) {
      setState(() {
        _isInitiallyLoading = false;
        _filterAccounts(); // this also applies sorting
      });
    }
  }

  void _onAccountTap(AccountModel account) {
    ChosenAccount().account = account;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AccountMainScreen()),
    ).then((_) {
      _loadAccounts();
    });
  }

  void _showTotalOverviewDrawer() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [TotalOverview()],
          ),
        );
      },
    );
  }

  Future<void> _showAddAccountDialog() async {
    _accountNameController.clear();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Account'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: _accountNameController,
                  decoration: const InputDecoration(hintText: "Account Name"),
                  autofocus: true,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () async {
                final String name = _accountNameController.text.trim();
                if (name.isNotEmpty) {
                  final newAccountModel = AccountModel(name: name);
                  await AccountTable.insert(newAccountModel);
                  _loadAccounts();
                  if (mounted) Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditAccountDialog(AccountModel account) async {
    _editAccountNameController.text = account.name;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Account Name'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: _editAccountNameController,
                  decoration: const InputDecoration(
                    hintText: "New Account Name",
                  ),
                  autofocus: true,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () async {
                final String newName = _editAccountNameController.text.trim();
                if (newName.isNotEmpty && newName != account.name) {
                  final updatedAccount = AccountModel(
                    id: account.id,
                    name: newName,
                  );
                  await AccountTable.update(updatedAccount);
                  _loadAccounts();
                  if (mounted) Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleCreateBackup() async {
    try {
      final dbPath = await DatabaseHelper.instance.getDatabasePath();
      final dbFile = File(dbPath);
      final dbBytes = await dbFile.readAsBytes();

      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Database Backup',
        fileName:
            'payments_tracker_backup_${DateTime.now().toIso8601String().split('.')[0].replaceAll(':', '-')}.db',
        type: FileType.custom,
        allowedExtensions: ['db'],
        bytes: dbBytes, // required on mobile
      );

      if (outputFile != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup created successfully!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup operation cancelled.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating backup: $e')));
      }
      // ignore: avoid_print
      print('Error during backup creation: $e');
    }
  }

  Future<void> _handleRestoreBackup() async {
    final bool? confirmRestore = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Restore'),
          content: const Text(
            'Restoring from a backup will overwrite all current data. This action cannot be undone. Are you sure?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text(
                'Restore',
                style: TextStyle(color: AppColors.expenseRed),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmRestore == true) {
      try {
        final FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          // NOTE: file_picker expects extensions WITHOUT dots
          allowedExtensions: ['db', 'sqlite', 'sqlite3'],
        );

        if (result != null && result.files.single.path != null) {
          final String backupPath = result.files.single.path!;
          final success = await DatabaseHelper.instance.restoreBackup(
            backupPath,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  success
                      ? 'Restore successful! Application will refresh data.'
                      : 'Restore failed.',
                ),
              ),
            );
            if (success) {
              await _loadAccounts();
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No backup file selected or path is invalid.'),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error restoring backup: $e')));
        }
        // ignore: avoid_print
        print('Error during backup restoration: $e');
      }
    }
  }

  Future<void> _showResetConfirmationDialog() async {
    _resetConfirmController.clear();
    bool isButtonEnabled = false;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Confirm Reset'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    const Text(
                      'This action is irreversible and will delete all data.',
                    ),
                    const Text('Please type "I am sure" to confirm.'),
                    TextField(
                      controller: _resetConfirmController,
                      decoration: const InputDecoration(hintText: 'I am sure'),
                      onChanged: (text) {
                        setStateDialog(() {
                          isButtonEnabled = text == 'I am sure';
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.expenseRed,
                  ),
                  onPressed: isButtonEnabled
                      ? () {
                          Navigator.of(context).pop();
                          _performFullReset();
                        }
                      : null,
                  child: const Text('Confirm Reset'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _performFullReset() async {
    try {
      await DatabaseHelper.instance.resetDatabase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database has been reset successfully!'),
          ),
        );
        _loadAccounts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error resetting database: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeScaffold(
      appBar: AppBar(
        title: const Text('Choose Account'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'create_backup') {
                _handleCreateBackup();
              } else if (value == 'restore_backup') {
                _handleRestoreBackup();
              } else if (value == 'reset') {
                _showResetConfirmationDialog();
              }
            },
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'create_backup',
                    child: Row(
                      children: [
                        Icon(Icons.backup),
                        SizedBox(width: 10),
                        Text('Create Backup'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'restore_backup',
                    child: Row(
                      children: [
                        Icon(Icons.restore),
                        SizedBox(width: 10),
                        Text('Restore Backup'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'reset',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever, color: AppColors.expenseRed),
                        SizedBox(width: 10),
                        Text(
                          'Reset Data',
                          style: TextStyle(color: AppColors.expenseRed),
                        ),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),

      body: _isInitiallyLoading
          ? const Center(child: CircularProgressIndicator())
          : _accountsData.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No accounts yet.\nTap the + button to add your first one!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16.0),
                ),
              ),
            )
          : Column(
              children: [
                // 🔍 Search + ↕️ Sort Row
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
                  child: Row(
                    children: [
                      Tooltip(
                        message: 'Add New Account',
                        child: IconButton(
                          onPressed: _showAddAccountDialog,
                          icon: const Icon(Icons.add),
                        ),
                      ),

                      // Expanded search field (no hard width)
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Search Accounts',
                            hintText: 'Enter account name...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      _filterAccounts();
                                    },
                                  )
                                : null,
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(20.0),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ↕️ Sort IconButton
                      Tooltip(
                        message: _isSortAscending
                            ? 'Sort by balance: ascending'
                            : 'Sort by balance: descending',
                        child: IconButton.filledTonal(
                          onPressed: () {
                            setState(() {
                              _isSortAscending = !_isSortAscending;
                              _applySort();
                            });
                          },
                          // Use clear up/down arrows for direction
                          icon: Icon(
                            _isSortAscending ? Icons.south : Icons.north,
                          ),
                        ),
                      ),

                      Tooltip(
                        message: 'Show totals',
                        child: IconButton.filledTonal(
                          onPressed: _showTotalOverviewDrawer,
                          icon: const Icon(Icons.summarize_outlined),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),
                Expanded(
                  child:
                      _filteredAccountsData.isEmpty &&
                          _searchController.text.isNotEmpty
                      ? const Center(
                          child: Text(
                            'No accounts match your search.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16.0),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredAccountsData.length,
                          itemBuilder: (context, index) {
                            final accountData = _filteredAccountsData[index];
                            final AccountModel account =
                                accountData['account'] as AccountModel;
                            final double balance =
                                (accountData['balance'] as num).toDouble();

                            return AccountCard(
                              account: account,
                              balance: balance,
                              onTap: () => _onAccountTap(account),
                              onEditPressed: () =>
                                  _showEditAccountDialog(account),
                              onDeletePressed: () async {
                                _deleteConfirmController.clear();
                                bool isDeleteButtonEnabled = false;

                                final bool?
                                confirmDelete = await showDialog<bool>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (BuildContext context) {
                                    return StatefulBuilder(
                                      builder: (context, setStateDialog) {
                                        return AlertDialog(
                                          title: const Text('Confirm Delete'),
                                          content: SingleChildScrollView(
                                            child: ListBody(
                                              children: <Widget>[
                                                Text(
                                                  'Are you sure you want to delete account "${account.name}" with all its transactions? This action is irreversible.',
                                                ),
                                                const Text(
                                                  'Please type "I am sure" to confirm.',
                                                ),
                                                TextField(
                                                  controller:
                                                      _deleteConfirmController,
                                                  decoration:
                                                      const InputDecoration(
                                                        hintText: 'I am sure',
                                                      ),
                                                  onChanged: (text) {
                                                    setStateDialog(() {
                                                      isDeleteButtonEnabled =
                                                          text == 'I am sure';
                                                    });
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          actions: <Widget>[
                                            TextButton(
                                              child: const Text('Cancel'),
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(false),
                                            ),
                                            TextButton(
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    AppColors.expenseRed,
                                              ),
                                              onPressed: isDeleteButtonEnabled
                                                  ? () => Navigator.of(
                                                      context,
                                                    ).pop(true)
                                                  : null,
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                );

                                if (confirmDelete == true) {
                                  if (account.id == null) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Cannot delete account without an ID.',
                                          ),
                                          backgroundColor: AppColors.expenseRed,
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                  await AccountTable.delete(account.id!);
                                  _loadAccounts();
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

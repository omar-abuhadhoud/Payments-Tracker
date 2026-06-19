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
  final bool showTitle;

  const TotalOverview({super.key, this.showTitle = true});

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
          if (widget.showTitle) ...[
            const Text(
              'Total Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
          ],
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
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Utility.handleNumberAppearanceForOverflow(
            number: value,
            color: valueColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class ChooseAccountScreen extends StatefulWidget {
  const ChooseAccountScreen({super.key});

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
  final ScrollController _accountsScrollController = ScrollController();

  bool _isInitiallyLoading = true;
  bool _isSortAscending = true; // 🔽 Asc first by default
  bool _isTotalOverviewDrawerOpen = false;

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
    _accountsScrollController.dispose();
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

  Widget _buildToolButton({
    required String message,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: message,
      child: IconButton.filledTonal(onPressed: onPressed, icon: Icon(icon)),
    );
  }

  Widget _buildAccountTools(BuildContext context) {
    final searchField = TextField(
      controller: _searchController,
      decoration: InputDecoration(
        labelText: 'Search Accounts',
        hintText: 'Enter account name...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _filterAccounts();
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: AppColors.purple.withValues(alpha: .08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: AppColors.purple.withValues(alpha: .28),
            width: 1.3,
          ),
        ),
      ),
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildToolButton(
          message: _isSortAscending
              ? 'Sort by balance: ascending'
              : 'Sort by balance: descending',
          icon: _isSortAscending ? Icons.south : Icons.north,
          onPressed: () {
            setState(() {
              _isSortAscending = !_isSortAscending;
              _applySort();
            });
          },
        ),
        const SizedBox(width: 4),
        _buildToolButton(
          message: 'Add New Account',
          icon: Icons.add,
          onPressed: _showAddAccountDialog,
        ),
      ],
    );

    return Material(
      color: AppColors.offWhite,
      elevation: 6,
      shadowColor: AppColors.purple.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(26),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.purple.withValues(alpha: .08)),
        ),
        child: Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 8),
            actions,
          ],
        ),
      ),
    );
  }

  double _totalOverviewDrawerBottomPadding() {
    return _isTotalOverviewDrawerOpen ? 230 : 82;
  }

  @override
  Widget build(BuildContext context) {
    return SafeScaffold(
      appBar: AppBar(
        title: const Text('Choose Account'),
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

      body: Stack(
        children: [
          _isInitiallyLoading
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
              : Utility.hideOnScroll(
                  floating: true,
                  hideable: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                        child: _buildAccountTools(context),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                  scrollable:
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
                          controller: _accountsScrollController,
                          padding: EdgeInsets.only(
                            top: 95,
                            bottom: _totalOverviewDrawerBottomPadding(),
                          ),
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
          if (!_isInitiallyLoading)
            Align(
              alignment: Alignment.bottomCenter,
              child: Utility.expandableFloatingDrawer(
                title: 'Total Overview',
                content: const TotalOverview(showTitle: false),
                isOpen: _isTotalOverviewDrawerOpen,
                onToggle: () {
                  setState(() {
                    _isTotalOverviewDrawerOpen = !_isTotalOverviewDrawerOpen;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:payments_tracker_flutter/global_variables/chosen_account.dart';

import 'package:payments_tracker_flutter/widgets/transaction_info_card.dart';
import 'package:payments_tracker_flutter/screens/add_edit_transaction_screen.dart'; // For TransactionType
import 'package:payments_tracker_flutter/models/transaction_model.dart';
import 'package:payments_tracker_flutter/database/tables/transaction_table.dart';
import 'package:payments_tracker_flutter/global_variables/app_colors.dart';

import '../widgets/basic/safe_scaffold.dart'; // Import AccountTable

class _TransactionWithBalance {
  final TransactionModel transaction;
  final double balance;

  const _TransactionWithBalance(this.transaction, this.balance);
}

class TransactionsLogScreen extends StatefulWidget {
  const TransactionsLogScreen({super.key});

  @override
  State<TransactionsLogScreen> createState() => _TransactionsLogScreenState();
}

class _TransactionsLogScreenState extends State<TransactionsLogScreen> {
  DateTime _currentDisplayedDate = DateTime.now();
  List<DateTime> _sortedDaysWithTransactions = [];
  Set<DateTime> _transactionDaysSet = {};
  late DateTime _today;
  late Future<void> _dataLoadingFuture;
  List<_TransactionWithBalance> _transactionsWithBalances = [];

  @override
  void initState() {
    super.initState();
    _today = _normalizeDate(DateTime.now());
    _currentDisplayedDate = _today; // Initialize currentDisplayedDate
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _dataLoadingFuture = _loadDataForDateAndChosenAccount(
      _currentDisplayedDate,
      isInitialLoad: true,
    );
    if (mounted) {
      setState(() {});
    }
  }

  DateTime _normalizeDate(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  Future<void> _loadDataForDateAndChosenAccount(
    DateTime dateToLoad, {
    bool isInitialLoad = false,
  }) async {
    _currentDisplayedDate = _normalizeDate(dateToLoad);

    List<DateTime> fetchedTransactionDays = _sortedDaysWithTransactions;
    if (isInitialLoad || _sortedDaysWithTransactions.isEmpty) {
      fetchedTransactionDays =
          await TransactionTable.getUniqueTransactionDatesForAccount(
            ChosenAccount().account?.id,
          );
    }

    final Set<DateTime> normalizedDaysSet = fetchedTransactionDays
        .map(_normalizeDate)
        .toSet();

    final accountId = ChosenAccount().account?.id;
    List<_TransactionWithBalance> computedTransactions = [];

    if (accountId != null) {
      final transactionsForDate =
          await TransactionTable.getTransactionsForDateAndAccount(
            _currentDisplayedDate,
            accountId,
          );

      if (transactionsForDate.isNotEmpty) {
        final List<TransactionModel> transactionsAscending =
            List<TransactionModel>.from(transactionsForDate.reversed);

        double currentBalance = 0.0;
        final TransactionModel oldestTransaction = transactionsAscending.first;
        if (oldestTransaction.id != null) {
          currentBalance =
              await TransactionTable.getBalanceUntilTransactionByTransactionIdForAccount(
                oldestTransaction.id!,
                accountId,
              );
        } else {
          currentBalance = oldestTransaction.amount;
        }

        final List<_TransactionWithBalance> ascendingWithBalances = [
          _TransactionWithBalance(oldestTransaction, currentBalance),
        ];

        for (var i = 1; i < transactionsAscending.length; i++) {
          final txn = transactionsAscending[i];
          currentBalance += txn.amount;
          ascendingWithBalances.add(
            _TransactionWithBalance(txn, currentBalance),
          );
        }

        computedTransactions = ascendingWithBalances.reversed.toList();
      }
    }

    if (mounted) {
      setState(() {
        _sortedDaysWithTransactions = fetchedTransactionDays;
        _transactionDaysSet = normalizedDaysSet;
        _transactionsWithBalances = computedTransactions;
      });
    } else {
      _sortedDaysWithTransactions = fetchedTransactionDays;
      _transactionDaysSet = normalizedDaysSet;
      _transactionsWithBalances = computedTransactions;
    }
  }

  void _triggerDataLoad(DateTime dateToLoad, {bool refreshSortedDays = false}) {
    setState(() {
      _transactionsWithBalances = [];
      _dataLoadingFuture = _loadDataForDateAndChosenAccount(
        dateToLoad,
        isInitialLoad: refreshSortedDays,
      );
    });
  }

  void _goToOlderDay() {
    if (_sortedDaysWithTransactions.isEmpty) return;

    int currentIndex = _sortedDaysWithTransactions.indexWhere(
      (d) => d.isAtSameMomentAs(_currentDisplayedDate),
    );

    if (currentIndex != -1 &&
        currentIndex + 1 < _sortedDaysWithTransactions.length) {
      _triggerDataLoad(_sortedDaysWithTransactions[currentIndex + 1]);
    } else if (currentIndex == -1) {
      DateTime? olderDay;
      for (var day in _sortedDaysWithTransactions) {
        if (day.isBefore(_currentDisplayedDate)) {
          olderDay = day;
          break;
        }
      }
      if (olderDay != null) {
        _triggerDataLoad(olderDay);
      }
    }
  }

  void _goToNewerDay() {
    int currentIndex = _sortedDaysWithTransactions.indexWhere(
      (d) => d.isAtSameMomentAs(_currentDisplayedDate),
    );

    if (currentIndex > 0) {
      _triggerDataLoad(_sortedDaysWithTransactions[currentIndex - 1]);
    } else if (currentIndex == -1) {
      // Current date is not in the list of transaction days.
      // This happens when we are on a day with no transactions.

      // Find the next available transaction day that is after the current day but not after today.
      DateTime? newerDay;
      for (int i = _sortedDaysWithTransactions.length - 1; i >= 0; i--) {
        var dayInList = _sortedDaysWithTransactions[i];
        if (dayInList.isAfter(_currentDisplayedDate) &&
            !dayInList.isAfter(_today)) {
          newerDay = dayInList;
          break;
        }
      }

      if (newerDay != null) {
        _triggerDataLoad(newerDay);
      } else if (_sortedDaysWithTransactions.isNotEmpty &&
          !_sortedDaysWithTransactions.first.isAfter(_today) &&
          _sortedDaysWithTransactions.first.isAfter(_currentDisplayedDate)) {
        _triggerDataLoad(_sortedDaysWithTransactions.first);
      }
    } else {
      // If we are at the newest transaction day (or on a day with no transactions after the newest one),
      // and it's not today, the "newer" action should take us to today.
      _goToToday();
    }
  }

  void _goToToday() {
    _triggerDataLoad(_today);
  }

  Future<void> _openDatePicker() async {
    if (_sortedDaysWithTransactions.isEmpty) {
      return;
    }

    final DateTime firstAvailableDay =
        _sortedDaysWithTransactions.last; // Oldest date in the list
    final DateTime latestAvailableDay = _sortedDaysWithTransactions.first;
    final DateTime lastAllowedDay = latestAvailableDay.isAfter(_today)
        ? _today
        : latestAvailableDay;

    DateTime normalizedInitialDate = _normalizeDate(_currentDisplayedDate);
    if (normalizedInitialDate.isBefore(firstAvailableDay)) {
      normalizedInitialDate = firstAvailableDay;
    } else if (normalizedInitialDate.isAfter(lastAllowedDay)) {
      normalizedInitialDate = lastAllowedDay;
    }

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: normalizedInitialDate,
      firstDate: firstAvailableDay,
      lastDate: lastAllowedDay,
      selectableDayPredicate: (date) {
        final DateTime normalizedDate = _normalizeDate(date);
        return _transactionDaysSet.any(
          (availableDate) => availableDate.isAtSameMomentAs(normalizedDate),
        );
      },
    );

    if (selectedDate != null && mounted) {
      _triggerDataLoad(selectedDate);
    }
  }

  bool _canGoToOlder(bool isLoading) {
    if (isLoading || _sortedDaysWithTransactions.isEmpty) return false;
    int currentIndex = _sortedDaysWithTransactions.indexWhere(
      (d) => d.isAtSameMomentAs(_currentDisplayedDate),
    );
    if (currentIndex != -1) {
      return currentIndex + 1 < _sortedDaysWithTransactions.length;
    }
    return _sortedDaysWithTransactions.any(
      (day) => day.isBefore(_currentDisplayedDate),
    );
  }

  bool _canGoToNewer(bool isLoading) {
    if (isLoading) return false;

    bool canGoToCurrent =
        !_currentDisplayedDate.isAtSameMomentAs(_today) &&
        !_currentDisplayedDate.isAfter(_today);
    if (canGoToCurrent) return true;

    if (_sortedDaysWithTransactions.isEmpty) return false;

    int currentIndex = _sortedDaysWithTransactions.indexWhere(
      (d) => d.isAtSameMomentAs(_currentDisplayedDate),
    );

    return (currentIndex != -1 && currentIndex > 0) ||
        _sortedDaysWithTransactions.any(
          (day) => day.isAfter(_currentDisplayedDate) && !day.isAfter(_today),
        );
  }

  void _handleHorizontalSwipe(DragEndDetails details, bool isLoading) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 280) return;

    if (velocity < 0 && _canGoToOlder(isLoading)) {
      _goToOlderDay();
    } else if (velocity > 0 && _canGoToNewer(isLoading)) {
      _goToNewerDay();
    }
  }

  Widget _buildBottomControls({
    required String formattedDate,
    required bool isLoading,
  }) {
    final isCurrent = _currentDisplayedDate.isAtSameMomentAs(_today);
    final canPickDate = _sortedDaysWithTransactions.isNotEmpty && !isLoading;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Material(
          color: Colors.white,
          elevation: 10,
          shadowColor: AppColors.purple.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.purple.withValues(alpha: .10),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.chevron_left,
                  color: _canGoToNewer(isLoading)
                      ? AppColors.purple.withValues(alpha: .42)
                      : AppColors.purple.withValues(alpha: .14),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: canPickDate ? _openDatePicker : null,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(
                      formattedDate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.purple,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: _canGoToOlder(isLoading)
                      ? AppColors.purple.withValues(alpha: .42)
                      : AppColors.purple.withValues(alpha: .14),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Current day',
                  child: IconButton.filledTonal(
                    onPressed: isLoading || isCurrent ? null : _goToToday,
                    icon: const Icon(Icons.today_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat(
      'EEE, MMM d, yyyy',
    ).format(_currentDisplayedDate);

    return SafeScaffold(
      appBar: AppBar(title: const Text('Transactions Log'), centerTitle: true),
      body: Stack(
        children: [
          FutureBuilder<void>(
            future: _dataLoadingFuture,
            builder: (context, snapshot) {
              bool isLoadingSnapshot =
                  snapshot.connectionState == ConnectionState.waiting;

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading transactions: ${snapshot.error}'),
                );
              }

              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (details) =>
                    _handleHorizontalSwipe(details, isLoadingSnapshot),
                child: _transactionsWithBalances.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                          child: Text(
                            'No transactions for $formattedDate.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(0, 6, 0, 112),
                        itemCount: _transactionsWithBalances.length,
                        itemBuilder: (context, index) {
                          final transactionWithBalance =
                              _transactionsWithBalances[index];
                          final transaction =
                              transactionWithBalance.transaction;

                          return TransactionInfoCard(
                            transaction: transaction,
                            balance: transactionWithBalance.balance,
                            todayDate: _today,
                            onEditPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AddEditTransactionScreen(
                                        transactionToEdit: transaction,
                                      ),
                                ),
                              );
                              if (result == true) {
                                _triggerDataLoad(_currentDisplayedDate);
                              }
                            },
                            onDeletePressed: () async {
                              final confirmDelete = await showDialog<bool>(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('Confirm Delete'),
                                    content: const Text(
                                      'Are you sure you want to delete this transaction?',
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                        child: const Text('Cancel'),
                                        onPressed: () {
                                          Navigator.of(context).pop(false);
                                        },
                                      ),
                                      TextButton(
                                        child: const Text('Delete'),
                                        onPressed: () {
                                          Navigator.of(context).pop(true);
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (confirmDelete == true &&
                                  transaction.id != null) {
                                await TransactionTable.deleteTransaction(
                                  transaction.id!,
                                );
                                _triggerDataLoad(
                                  _currentDisplayedDate,
                                  refreshSortedDays: true,
                                );
                              }
                            },
                          );
                        },
                      ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FutureBuilder<void>(
              future: _dataLoadingFuture,
              builder: (context, snapshot) {
                bool isLoadingSnapshot =
                    snapshot.connectionState == ConnectionState.waiting;
                return _buildBottomControls(
                  formattedDate: formattedDate,
                  isLoading: isLoadingSnapshot,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

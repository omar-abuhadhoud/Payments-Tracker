import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:payments_tracker_flutter/database/tables/transaction_table.dart';
import 'package:payments_tracker_flutter/models/transaction_model.dart';
import 'package:payments_tracker_flutter/global_variables/app_colors.dart';
import 'package:payments_tracker_flutter/widgets/monthly_or_daily_details_card.dart';

import '../widgets/basic/safe_scaffold.dart';
import '../widgets/transaction_list_tile_card.dart';
import '../widgets/utility.dart';

class DailyDetailsScreen extends StatefulWidget {
  final DateTime selectedDate;
  final int? accountId;
  final double? dailyNet;
  final double? cumulativeBalance;

  const DailyDetailsScreen({
    super.key,
    required this.selectedDate,
    required this.accountId,
    this.dailyNet,
    this.cumulativeBalance,
  });

  @override
  State<DailyDetailsScreen> createState() => _DailyDetailsScreenState();
}

class _DailyDetailsScreenState extends State<DailyDetailsScreen> {
  late Future<List<TransactionModel>> _transactionsFuture;

  final Color _pageBackgroundColor = Colors.white;
  final Color _primaryTextColor = AppColors.purple;
  final Color _secondaryTextColor = AppColors.purple.withOpacity(0.7);
  final Color _chipBackgroundColor = AppColors.offWhite;
  final Color _chipTextColor = AppColors.purple;

  @override
  void initState() {
    super.initState();
    _transactionsFuture = TransactionTable.getTransactionsForDateAndAccount(
      widget.selectedDate,
      widget.accountId,
    );
  }

  Widget _buildSummaryCard(List<TransactionModel> transactions) {
    final double incomeTotal = transactions
        .where((txn) => txn.amount > 0)
        .fold(0.0, (sum, txn) => sum + txn.amount);
    final double expenseTotal = transactions
        .where((txn) => txn.amount < 0)
        .fold(0.0, (sum, txn) => sum + txn.amount);

    return MonthlyOrDailyDetailsCard(
      selectedDateTime: widget.selectedDate,
      income: incomeTotal,
      expense: expenseTotal
          .abs(), // expenseTotal is negative, send absolute value
      overallBalanceEndOfMonthOrDay: widget.cumulativeBalance ?? 0,

      isMonthly: false,
    );
  }

  Widget _buildTransactionList(List<TransactionModel> transactions) {
    if (transactions.isEmpty) {
      return Center(
        child: Padding(
          // Added padding for better spacing
          padding: const EdgeInsets.all(24.0),
          child: Column(
            // Added Column for icon and text
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 60,
                color: _secondaryTextColor,
              ),
              const SizedBox(height: 16),
              Text(
                'No transactions recorded for this day.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: _primaryTextColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        vertical: 8.0,
      ), // Add padding to the list
      itemCount: transactions.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: AppColors.subtlePurple.withOpacity(0.15),
      ), // Subtle separator
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return TransactionListTileCard(transaction: transaction);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String formattedDate = DateFormat(
      'EEEE, MMMM d, yyyy',
    ).format(widget.selectedDate);

    return SafeScaffold(
      backgroundColor: _pageBackgroundColor,
      appBar: AppBar(
        title: Text(
          formattedDate,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(4.0),
        child: FutureBuilder<List<TransactionModel>>(
          future: _transactionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error loading transactions: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.expenseRed,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }

            final transactions = snapshot.data ?? [];

            return Utility.hideOnScroll(
              hideable: _buildSummaryCard(transactions),
              scrollable: Column(
                children: [
                  Padding(
                    // Title for the transaction list
                    padding: const EdgeInsets.only(
                      left: 20.0,
                      right: 20.0,
                      top: 16.0,
                      bottom: 8.0,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.list_alt_rounded, color: _primaryTextColor),
                        const SizedBox(width: 8),
                        Text(
                          'Transactions',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _primaryTextColor,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildTransactionList(transactions)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

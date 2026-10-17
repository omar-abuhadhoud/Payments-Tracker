import 'package:flutter/material.dart';
import 'package:payments_tracker_flutter/global_variables/app_colors.dart';
import 'package:payments_tracker_flutter/global_variables/chosen_account.dart';
import 'package:payments_tracker_flutter/widgets/utility.dart';

import '../database/tables/transaction_table.dart';
import '../screens/add_edit_transaction_screen.dart';
import '../screens/date_range_summary_screen.dart';
import '../screens/monthly_summary_screen.dart';
import '../screens/transactions_log_screen.dart';

enum AccountSection { add, log, monthly, dateRange }

/// Side menu shown on every top-level page of the chosen account.
class AccountDrawer extends StatelessWidget {
  final AccountSection current;

  const AccountDrawer({super.key, required this.current});

  static const double _radius = 28;

  Widget _screenFor(AccountSection section) {
    switch (section) {
      case AccountSection.add:
        return const AddEditTransactionScreen();
      case AccountSection.log:
        return const TransactionsLogScreen();
      case AccountSection.monthly:
        return const MonthlySummaryScreen();
      case AccountSection.dateRange:
        return const DateRangeSummaryScreen();
    }
  }

  void _openSection(BuildContext context, AccountSection section) {
    final navigator = Navigator.of(context);
    navigator.pop(); // close the drawer
    if (section == current) return;

    // Keep the stack as: accounts list -> one section, so back always returns to accounts
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => _screenFor(section)),
      (route) => route.isFirst,
    );
  }

  Widget _buildHeader() {
    final account = ChosenAccount().account;
    final name = account?.name ?? 'Account';
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.purple, AppColors.subtlePurple],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: .25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Balance',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .72),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: .4,
            ),
          ),
          const SizedBox(height: 4),
          FutureBuilder<double>(
            future: TransactionTable.getTotalBalanceForAccount(account?.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox(height: 30);
              final balance = snapshot.data!;
              final isPositive = balance >= 0;
              return Row(
                children: [
                  Flexible(
                    child: Utility.handleNumberAppearanceForOverflow(
                      number: balance,
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 16,
                      color: isPositive
                          ? AppColors.incomeGreen
                          : AppColors.expenseRed,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: AppColors.purple.withValues(alpha: .45),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: isSelected
            ? AppColors.purple.withValues(alpha: .09)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.purple : AppColors.offWhite,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected ? Colors.white : AppColors.purple,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: AppColors.purple,
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    height: 8,
                    width: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.purple,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionItem(
    BuildContext context,
    AccountSection section,
    IconData icon,
    String label,
  ) {
    return _buildItem(
      context,
      icon: icon,
      label: label,
      isSelected: section == current,
      onTap: () => _openSection(context, section),
    );
  }

  Widget _buildSwitchAccountButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: OutlinedButton.icon(
        onPressed: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        icon: const Icon(Icons.swap_horiz, size: 20),
        label: const Text('Switch Account'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.purple,
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: AppColors.purple.withValues(alpha: .25)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(_radius),
          bottomRight: Radius.circular(_radius),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildSectionLabel('Menu'),
                  _buildSectionItem(
                    context,
                    AccountSection.add,
                    Icons.add_rounded,
                    'Add Transaction',
                  ),
                  _buildSectionItem(
                    context,
                    AccountSection.log,
                    Icons.receipt_long_rounded,
                    'Log',
                  ),
                  _buildSectionItem(
                    context,
                    AccountSection.monthly,
                    Icons.calendar_month_rounded,
                    'Monthly',
                  ),
                  _buildSectionItem(
                    context,
                    AccountSection.dateRange,
                    Icons.date_range_rounded,
                    'Date Range',
                  ),
                ],
              ),
            ),
            _buildSwitchAccountButton(context),
          ],
        ),
      ),
    );
  }
}

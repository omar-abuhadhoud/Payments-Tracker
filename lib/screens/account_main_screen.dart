import 'package:flutter/material.dart';
import 'package:payments_tracker_flutter/global_variables/chosen_account.dart';
import 'package:payments_tracker_flutter/widgets/utility.dart';

import '../widgets/basic/safe_scaffold.dart';
import 'add_edit_transaction_screen.dart';
import 'transactions_log_screen.dart';
import 'monthly_summary_screen.dart';
import 'date_range_summary_screen.dart';
import '../database/tables/transaction_table.dart';
import '../global_variables/app_colors.dart';

class AccountMainScreen extends StatefulWidget {
  const AccountMainScreen({super.key});

  @override
  State<AccountMainScreen> createState() => _AccountMainScreenState();
}

class _AccountMainScreenState extends State<AccountMainScreen> {
  late Future<double> _accountBalanceFuture;
  double? _lastBalance; // cache last good data

  @override
  void initState() {
    super.initState();
    _loadAccountBalance();
  }

  void _loadAccountBalance() => _refreshAccountBalance();

  void _refreshAccountBalance() {
    final accountId = ChosenAccount().account?.id;
    final future = TransactionTable.getTotalBalanceForAccount(accountId).then((
      balance,
    ) {
      _lastBalance = balance; // keep cached copy
      return balance;
    });

    setState(() {
      _accountBalanceFuture = future;
    });
  }

  Future<void> _openScreen(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
    _loadAccountBalance();
  }

  Widget _buildBalancePanel(double balance) {
    final balanceColor = balance >= 0
        ? AppColors.incomeGreen
        : AppColors.expenseRed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.purple.withValues(alpha: .10)),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: .08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: balanceColor.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: balanceColor,
              size: 29,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Overall Balance',
            style: TextStyle(
              color: AppColors.purple.withValues(alpha: .68),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Utility.handleNumberAppearanceForOverflow(
            number: balance,
            color: balanceColor,
            fontSize: 33,
            fontWeight: FontWeight.w900,
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection() {
    final actions = [
      _DashboardAction(
        label: 'Add',
        icon: Icons.add_circle_outline,
        isPrimary: true,
        onPressed: () => _openScreen(const AddEditTransactionScreen()),
      ),
      _DashboardAction(
        label: 'Log',
        icon: Icons.list_alt_outlined,
        onPressed: () => _openScreen(const TransactionsLogScreen()),
      ),
      _DashboardAction(
        label: 'Monthly',
        icon: Icons.calendar_month,
        isPrimary: true,
        onPressed: () => _openScreen(const MonthlySummaryScreen()),
      ),
      _DashboardAction(
        label: 'Date Range',
        icon: Icons.date_range_outlined,
        onPressed: () => _openScreen(const DateRangeSummaryScreen()),
      ),
    ];

    return Column(
      children: [
        _buildActionTile(actions[0]),
        const SizedBox(height: 18),
        _buildActionTile(actions[1]),
        const SizedBox(height: 18),
        _buildActionTile(actions[2]),
        const SizedBox(height: 18),
        _buildActionTile(actions[3]),
      ],
    );
  }

  Widget _buildActionTile(_DashboardAction action) {
    final background = action.isPrimary ? AppColors.purple : Colors.white;
    final foreground = action.isPrimary ? Colors.white : AppColors.purple;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: action.onPressed,
        child: Container(
          height: action.isPrimary ? 64 : 60,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: action.isPrimary
                  ? Colors.transparent
                  : AppColors.purple.withValues(alpha: .12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                action.icon,
                color: foreground,
                size: action.isPrimary ? 23 : 21,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountName = ChosenAccount().account?.name ?? 'Account';
    return SafeScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(accountName),
        centerTitle: true,
      ),
      body: FutureBuilder<double>(
        future: _accountBalanceFuture,
        builder: (context, snapshot) {
          final hasLive = snapshot.hasData;
          final balance = hasLive ? snapshot.data! : _lastBalance;

          if (balance == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _buildBalancePanel(balance),
                ),
                const SizedBox(height: 32),
                _buildActionSection(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _DashboardAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });
}

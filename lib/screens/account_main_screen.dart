import 'package:flutter/material.dart';
import 'package:payments_tracker_flutter/global_variables/chosen_account.dart';
import 'package:payments_tracker_flutter/widgets/monthly_or_daily_details_card.dart';
import 'package:payments_tracker_flutter/widgets/utility.dart';

import '../widgets/basic/safe_scaffold.dart';
import 'add_edit_transaction_screen.dart';
import 'transactions_log_screen.dart';
import 'monthly_summary_screen.dart';
import '../database/tables/transaction_table.dart';
import '../global_variables/app_colors.dart';

class AccountMainScreen extends StatefulWidget {
  const AccountMainScreen({super.key});

  @override
  State<AccountMainScreen> createState() => _AccountMainScreenState();
}

class _AccountMainScreenState extends State<AccountMainScreen> {
  late Future<Map<String, double>> _monthlySummaryFuture;
  Map<String, double>? _lastSummary; // cache last good data
  DateTime selectedMonthDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadMonthlySummary();
  }

  void _loadMonthlySummary() => _refreshMonthlySummary();

  void _refreshMonthlySummary() {
    final accountId = ChosenAccount().account?.id;
    final future =
        TransactionTable.getMonthlySummary(selectedMonthDate, accountId).then((
          data,
        ) {
          _lastSummary = data; // keep cached copy
          return data;
        });

    setState(() {
      _monthlySummaryFuture = future;
    });
  }

  Future<void> _openScreen(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
    _loadMonthlySummary();
  }

  Widget _buildSummaryHeader(Map<String, double> data) {
    final balance = data['overallBalance'] ?? 0.0;
    final income = data['income'] ?? 0.0;
    final expense = data['expense'] ?? 0.0;
    final balanceColor = balance >= 0
        ? AppColors.incomeGreen
        : AppColors.expenseRed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.purple.withValues(alpha: .10)),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: .08),
            blurRadius: 22,
            offset: const Offset(0, 10),
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
                decoration: BoxDecoration(
                  color: balanceColor.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: balanceColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Balance',
                      style: TextStyle(
                        color: AppColors.purple.withValues(alpha: .72),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Utility.handleNumberAppearanceForOverflow(
                      number: balance,
                      color: balanceColor,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildMetricPill(
                  label: 'Income',
                  value: income,
                  color: AppColors.incomeGreen,
                  icon: Icons.arrow_upward,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricPill(
                  label: 'Expense',
                  value: expense,
                  color: AppColors.expenseRed,
                  icon: Icons.arrow_downward,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              final actions = [
                _DashboardAction(
                  label: 'Add',
                  icon: Icons.add_circle_outline,
                  isPrimary: true,
                  onPressed: () =>
                      _openScreen(const AddEditTransactionScreen()),
                ),
                _DashboardAction(
                  label: 'Log',
                  icon: Icons.list_alt_outlined,
                  onPressed: () => _openScreen(const TransactionsLogScreen()),
                ),
                _DashboardAction(
                  label: 'Monthly',
                  icon: Icons.calendar_month,
                  onPressed: () => _openScreen(const MonthlySummaryScreen()),
                ),
              ];

              if (isNarrow) {
                return Column(
                  children: actions
                      .map(
                        (action) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildActionTile(action),
                        ),
                      )
                      .toList(),
                );
              }

              return Row(
                children: actions
                    .map(
                      (action) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: action == actions.last ? 0 : 10,
                          ),
                          child: _buildActionTile(action),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required String label,
    required double value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.purple.withValues(alpha: .62),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Utility.handleNumberAppearanceForOverflow(
                  number: value,
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ],
            ),
          ),
        ],
      ),
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
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
              Icon(action.icon, color: foreground, size: 21),
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
      body: FutureBuilder<Map<String, double>>(
        future: _monthlySummaryFuture,
        builder: (context, snapshot) {
          final hasLive = snapshot.hasData;
          final data = hasLive ? snapshot.data! : (_lastSummary ?? {});

          if (!hasLive && _lastSummary == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final income = data['income'] ?? 0.0;
          final expense = data['expense'] ?? 0.0;
          final overallBalance = data['overallBalance'] ?? 0.0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _buildSummaryHeader(data),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: MonthlyOrDailyDetailsCard(
                  selectedDateTime: selectedMonthDate,
                  income: income,
                  expense: expense,
                  overallBalanceEndOfMonthOrDay: overallBalance,
                  isMonthly: true,
                ),
              ),
            ],
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

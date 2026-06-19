import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/tables/transaction_table.dart';
import '../global_variables/app_colors.dart';
import '../global_variables/chosen_account.dart';
import '../widgets/basic/safe_scaffold.dart';
import '../widgets/utility.dart';

class DateRangeSummaryScreen extends StatefulWidget {
  const DateRangeSummaryScreen({super.key});

  @override
  State<DateRangeSummaryScreen> createState() => _DateRangeSummaryScreenState();
}

class _DateRangeSummaryScreenState extends State<DateRangeSummaryScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  late Future<Map<String, double>> _summaryFuture;

  final DateFormat _displayDateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _startDate = DateTime(today.year, today.month, 1);
    _endDate = today;
    _summaryFuture = _fetchSummary();
  }

  Future<Map<String, double>> _fetchSummary() {
    return TransactionTable.getSummaryForDateRange(
      ChosenAccount().account?.id,
      _startDate,
      _endDate,
    );
  }

  Future<void> _selectDateRange() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selectedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: today,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      helpText: 'Select summary range',
      saveText: 'Apply',
    );

    if (selectedRange == null || !mounted) return;

    setState(() {
      _startDate = DateUtils.dateOnly(selectedRange.start);
      _endDate = DateUtils.dateOnly(selectedRange.end);
      _summaryFuture = _fetchSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final accountName = ChosenAccount().account?.name ?? 'Account';

    return SafeScaffold(
      appBar: AppBar(title: const Text('Date Range Summary')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              accountName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.purple.withValues(alpha: .70),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            _buildRangeSelector(),
            const SizedBox(height: 24),
            FutureBuilder<Map<String, double>>(
              future: _summaryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return _buildErrorCard(snapshot.error);
                }

                final summary = snapshot.data ?? const <String, double>{};
                return _buildSummary(
                  income: summary['income'] ?? 0,
                  expense: summary['expense'] ?? 0,
                  balance: summary['balance'] ?? 0,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.purple.withValues(alpha: .12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.filter_alt_outlined, color: AppColors.purple),
              SizedBox(width: 8),
              Text(
                'Filter period',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DateValue(
                  label: 'From',
                  value: _displayDateFormat.format(_startDate),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, color: AppColors.purple),
              ),
              Expanded(
                child: _DateValue(
                  label: 'To',
                  value: _displayDateFormat.format(_endDate),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectDateRange,
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Choose Date Range'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary({
    required double income,
    required double expense,
    required double balance,
  }) {
    final balanceColor = balance >= 0
        ? AppColors.incomeGreen
        : AppColors.expenseRed;

    return Column(
      children: [
        _SummaryCard(
          label: 'Balance for Range',
          value: balance,
          icon: Icons.account_balance_wallet_outlined,
          color: balanceColor,
          prominent: true,
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Total Income',
                value: income,
                icon: Icons.arrow_upward,
                color: AppColors.incomeGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: 'Total Expense',
                value: expense,
                icon: Icons.arrow_downward,
                color: AppColors.expenseRed,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorCard(Object? error) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.expenseRed.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        'Could not load the summary: $error',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.expenseRed,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DateValue extends StatelessWidget {
  const _DateValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.purple.withValues(alpha: .62),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.prominent = false,
  });

  final String label;
  final double value;
  final IconData icon;
  final Color color;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(prominent ? 22 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .20)),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: .06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: prominent ? 52 : 42,
            height: prominent ? 52 : 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: prominent ? 27 : 22),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: AppColors.purple.withValues(alpha: .72),
                fontSize: prominent ? 15 : 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Utility.handleNumberAppearanceForOverflow(
            number: value,
            color: color,
            fontSize: prominent ? 30 : 20,
            fontWeight: FontWeight.w900,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

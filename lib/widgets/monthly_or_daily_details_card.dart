import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:payments_tracker_flutter/widgets/utility.dart';

import '../global_variables/app_colors.dart';
import 'basic/basic_card.dart';

class MonthlyOrDailyDetailsCard extends StatelessWidget {
  final DateTime selectedDateTime;
  final double income;
  final double expense;
  final double overallBalanceEndOfMonthOrDay;
  final bool isMonthly; //if not then its daily

  const MonthlyOrDailyDetailsCard({
    super.key,
    required this.selectedDateTime,
    required this.income,
    required this.expense,
    required this.overallBalanceEndOfMonthOrDay,
    required this.isMonthly,
  });

  String get _formattedDate => isMonthly
      ? DateFormat.yMMMM().format(selectedDateTime)
      : DateFormat.MMMMd().format(selectedDateTime);

  double get _net => income - expense;

  @override
  Widget build(BuildContext context) {
    return BasicCard(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Details: $_formattedDate',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.purple,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.assessment, color: AppColors.purple, size: 28),
              ],
            ),

            const SizedBox(height: 16),
            Divider(
              color: AppColors.subtlePurple.withOpacity(0.2),
              thickness: 1,
            ),
            const SizedBox(height: 16),

            // Income
            _buildSummaryRow(
              label: 'Income',
              value: income,
              icon: Icons.arrow_upward,
              color: AppColors.incomeGreen,
            ),
            const SizedBox(height: 10),

            // Expense
            _buildSummaryRow(
              label: 'Expense',
              value: expense,
              icon: Icons.arrow_downward,
              color: AppColors.expenseRed,
            ),
            const SizedBox(height: 10),

            // Net
            _buildSummaryRow(
              label: 'Net',
              value: _net,
              icon: _net >= 0 ? Icons.trending_up : Icons.trending_down,
              color: _net >= 0 ? AppColors.incomeGreen : AppColors.expenseRed,
              isBold: true,
            ),

            const SizedBox(height: 16),
            Divider(
              color: AppColors.subtlePurple.withOpacity(0.2),
              thickness: 1,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  color: AppColors.purple,
                  size: 22,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Overall Balance:',
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.purple,
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: Utility.handleNumberAppearanceForOverflow(
                    number: overallBalanceEndOfMonthOrDay,
                    color: overallBalanceEndOfMonthOrDay >= 0
                        ? AppColors.incomeGreen
                        : AppColors.expenseRed,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),

            // Overall Balance
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required double value,
    required IconData icon,
    required Color color,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: AppColors.purple,
            ),
          ),
        ),
        Expanded(
          child: Utility.handleNumberAppearanceForOverflow(
            number: value,
            color: color,
            fontSize: 16,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

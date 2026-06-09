import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// import 'package:fl_chart/fl_chart.dart'; // Removed fl_chart import
import 'package:payments_tracker_flutter/database/tables/transaction_table.dart';
import 'package:payments_tracker_flutter/global_variables/chosen_account.dart';
import 'package:payments_tracker_flutter/widgets/daily_summary_card.dart';
import 'package:payments_tracker_flutter/screens/daily_details_screen.dart';
import 'package:payments_tracker_flutter/global_variables/app_colors.dart';
import 'package:payments_tracker_flutter/widgets/swipe_period_navigation.dart';

import '../widgets/basic/safe_scaffold.dart';
import '../widgets/monthly_or_daily_details_card.dart';
// import 'add_edit_transaction_screen.dart' show TransactionType; // Assuming not needed for this change

// Placeholder for the daily details screen - you'll need to create this
// import 'package:payments_tracker_flutter/screens/daily_details_screen.dart';

class MonthlySummaryScreen extends StatefulWidget {
  const MonthlySummaryScreen({super.key});

  @override
  State<MonthlySummaryScreen> createState() => _MonthlySummaryScreenState();
}

class _MonthlySummaryScreenState extends State<MonthlySummaryScreen> {
  List<DateTime> _availableMonths = [];
  int _currentMonthIndex = -1;
  List<Map<String, dynamic>> _selectedMonthChartData = [];

  double _selectedMonthIncome = 0.0;
  double _selectedMonthExpense = 0.0;
  double _selectedMonthNet = 0.0;
  double _overallBalanceAtEndOfSelectedMonth = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeScreenWithLoading();
  }

  Future<void> _initializeScreenWithLoading() async {
    setState(() {
      _isLoading = true;
    });
    await _initializeScreen();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _initializeScreen() async {
    await _processAvailableMonths();
    final DateTime now = DateTime.now();
    // Find the index of the current system month (today's month) in _availableMonths
    final int currentSystemMonthIndex = _availableMonths.indexWhere(
      (month) => month.year == now.year && month.month == now.month,
    );

    // If the current month exists in our list of months with transactions...
    if (currentSystemMonthIndex != -1) {
      setState(() {
        _currentMonthIndex = currentSystemMonthIndex;
      });
    } else {
      // Otherwise, we still want to show the current month, even if it has no transactions.
      // We add it to the list and sort again to maintain order.
      final currentMonthStart = DateTime(now.year, now.month, 1);
      if (!_availableMonths.contains(currentMonthStart)) {
        _availableMonths.add(currentMonthStart);
        _availableMonths.sort((a, b) => b.compareTo(a));
        // After adding, we find its new index. It will likely be 0 if it's the newest.
        _currentMonthIndex = _availableMonths.indexOf(currentMonthStart);
      }
    }
    await _loadDataForSelectedMonth(showLoading: false);
    /* // Old logic: Default to most recent month with transactions
    if (_availableMonths.isNotEmpty) {
      setState(() {
        _currentMonthIndex = 0; // Default to the most recent month
      });
      await _loadDataForSelectedMonth(showLoading: false);
    }
    */
  }

  Future<void> _processAvailableMonths() async {
    final Set<DateTime> uniqueMonthsSet =
        await TransactionTable.getUniqueTransactionMonthsForAccount(
          ChosenAccount().account?.id,
        );
    _availableMonths = uniqueMonthsSet.toList();
    _availableMonths.sort((a, b) => b.compareTo(a));
  }

  Future<void> _loadDataForSelectedMonth({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    if (_currentMonthIndex < 0 ||
        _currentMonthIndex >= _availableMonths.length) {
      setState(() {
        _selectedMonthChartData = [];
        _selectedMonthIncome = 0.0;
        _selectedMonthExpense = 0.0;
        _selectedMonthNet = 0.0;
        _overallBalanceAtEndOfSelectedMonth = 0.0;
        if (showLoading) _isLoading = false;
      });
      return;
    }

    final DateTime selectedMonthDate = _availableMonths[_currentMonthIndex];

    final List<Map<String, dynamic>> chartDataForeachDayOfSelectedMonth =
        await TransactionTable.getDailyNetWithCumulativeBalanceForMonth(
          ChosenAccount().account?.id,
          selectedMonthDate,
        );

    final Map<String, double> monthlySummary =
        await TransactionTable.getMonthlySummary(
          selectedMonthDate,
          ChosenAccount().account?.id,
        );

    setState(() {
      _selectedMonthChartData = chartDataForeachDayOfSelectedMonth;
      _selectedMonthIncome = monthlySummary['income'] ?? 0.0;
      _selectedMonthExpense = monthlySummary['expense'] ?? 0.0;
      _selectedMonthNet = _selectedMonthIncome - _selectedMonthExpense;
      _overallBalanceAtEndOfSelectedMonth =
          monthlySummary['overallBalance'] ?? 0;
      if (showLoading) _isLoading = false;
    });
  }

  Future<void> _goToPreviousMonth() async {
    if (_currentMonthIndex < _availableMonths.length - 1) {
      setState(() {
        _currentMonthIndex++; // 'Older' month means a higher index in the sorted list
      });
      await _loadDataForSelectedMonth();
    }
  }

  Future<void> _goToNextMonth() async {
    if (_currentMonthIndex > 0) {
      // 'Newer' month means a lower index
      setState(() {
        _currentMonthIndex--;
      });
      await _loadDataForSelectedMonth();
    }
  }

  Future<void> _goToCurrentMonth() async {
    // Find the index of the current system month (today's month) in _availableMonths
    final DateTime now = DateTime.now();
    final int currentSystemMonthIndex = _availableMonths.indexWhere(
      (month) => month.year == now.year && month.month == now.month,
    );
    // If the current month is not found, we want to show a "no data" state for this month.
    if (currentSystemMonthIndex == -1) {
      // Even if the month is not in the list (no transactions), we still want to show its summary.
      // We will calculate the summary for the current month.
      setState(() {
        _currentMonthIndex = -1; // Indicates no month is selected
      });
      // Manually calculate summary for the current month since it's not in our list.
      final Map<String, double> monthlySummary =
          await TransactionTable.getMonthlySummary(
            now,
            ChosenAccount().account?.id,
          );
      setState(() {
        _selectedMonthChartData = []; // No transactions this month
        _selectedMonthIncome = monthlySummary['income'] ?? 0.0;
        _selectedMonthExpense = monthlySummary['expense'] ?? 0.0;
        _selectedMonthNet = (_selectedMonthIncome) - (_selectedMonthExpense);
        _overallBalanceAtEndOfSelectedMonth =
            monthlySummary['overallBalance'] ?? 0.0;
      });
    } else {
      setState(() {
        _currentMonthIndex = currentSystemMonthIndex;
      });
      await _loadDataForSelectedMonth();
    }
  }

  Future<void> _openMonthPicker() async {
    if (_availableMonths.isEmpty) {
      return;
    }

    // Group months by year
    final Map<int, List<DateTime>> monthsByYear = {};
    for (var month in _availableMonths) {
      if (!monthsByYear.containsKey(month.year)) {
        monthsByYear[month.year] = [];
      }
      monthsByYear[month.year]!.add(month);
    }
    final List<int> years = monthsByYear.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final int? selectedIndex = await showDialog<int>(
      context: context,
      builder: (context) {
        return _YearMonthPicker(
          years: years,
          monthsByYear: monthsByYear,
          availableMonths: _availableMonths,
          currentMonthIndex: _currentMonthIndex,
        );
      },
    );

    if (selectedIndex != null &&
        selectedIndex >= 0 &&
        selectedIndex < _availableMonths.length &&
        selectedIndex != _currentMonthIndex) {
      setState(() {
        _currentMonthIndex = selectedIndex;
      });
      await _loadDataForSelectedMonth(showLoading: true);
    }
  }

  DateTime get _displayedMonthDate {
    if (_currentMonthIndex >= 0 &&
        _currentMonthIndex < _availableMonths.length) {
      return _availableMonths[_currentMonthIndex];
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  String get _formattedDisplayedMonth =>
      DateFormat.yMMMM().format(_displayedMonthDate);

  bool _isCurrentMonthDisplayed() {
    if (_availableMonths.isEmpty || _currentMonthIndex < 0) {
      // If there's no data or no selection, it can't be the current month.
      // Or, if there are no transactions at all, the "Current" button might point to the non-existent current month.
      // A check to see if any month in the list is the current month is also useful.
      final now = DateTime.now();
      return !_availableMonths.any(
        (month) => month.year == now.year && month.month == now.month,
      );
    }
    final DateTime now = DateTime.now();
    final DateTime displayedMonth = _availableMonths[_currentMonthIndex];
    return displayedMonth.year == now.year && displayedMonth.month == now.month;
  }

  bool _canGoToOlder() {
    if (_isLoading) return false;
    // Can go to an older month if the current index is not the last one
    return _currentMonthIndex < _availableMonths.length - 1;
  }

  bool _canGoToNewer() {
    if (_isLoading) return false;
    // Can go to a newer month if the current index is greater than 0
    return _currentMonthIndex > 0;
  }

  // _buildChart method is kept for now but not used.
  // You can remove it later if you are sure it's no longer needed.
  /*
  Widget _buildChart() {
    if (_selectedMonthChartData.isEmpty &&
        !(_currentMonthIndex >= 0 &&
            _currentMonthIndex < _availableMonths.length)) {
      return Center( 
        child: Column( 
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined, size: 50, color: Colors.blueGrey.shade300),
            const SizedBox(height: 10),
            Text(
              'No month selected or no data available.',
              textAlign: TextAlign.center, 
              style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final Map<int, double> dailyData = {
      for (var d in _selectedMonthChartData)
        d['dayNumber'] as int: d['dailyNet'] as double
    };

    List<BarChartGroupData> barGroups = [];
    double minY = 0;
    double maxY = 0;
    final DateTime currentMonthDateTime = _availableMonths[_currentMonthIndex];
    final int daysInMonth = DateUtils.getDaysInMonth(currentMonthDateTime.year, currentMonthDateTime.month);

    for (int day = 1; day <= daysInMonth; day++) {
      final value = dailyData[day] ?? 0;

      if (value < minY) minY = value;
      if (value > maxY) maxY = value;

      barGroups.add(
        BarChartGroupData(
          x: day,
          barRods: [
            BarChartRodData(
              toY: value,
              color: value >= 0 ? Colors.green.shade400 : Colors.red.shade400,
              width: 12,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    if (minY == 0 && maxY == 0) {
      minY = -100; 
      maxY = 100;
    } else {
      double padding = (maxY - minY).abs() * 0.1; 
      if (padding < 10 && (maxY - minY).abs() > 0) padding = 10; 
      else if (padding == 0) padding = 10; 

      maxY = maxY + padding;
      minY = minY - padding;
    }
    if (maxY < 0 && minY < 0) maxY = 0;
    if (minY > 0 && maxY > 0) minY = 0;


    final axisLabelStyle = TextStyle(color: Colors.grey.shade700, fontSize: 10);
    final gridLineColor = Colors.grey.shade300;
    final double gridStrokeWidth = 0.5;
    double yAxisInterval = ((maxY - minY) / 5).abs();
    if (yAxisInterval < 1) yAxisInterval = 1; 
    else if (yAxisInterval > 20 && (maxY -minY) / yAxisInterval > 8) { 
        yAxisInterval = (yAxisInterval / 10).ceil() * 10.0;
    } else {
        yAxisInterval = yAxisInterval.roundToDouble();
    }
    if (yAxisInterval == 0) yAxisInterval = 20;


    return BarChart(
      BarChartData(
        baselineY: 0,
        minY: minY,
        maxY: maxY,
        barGroups: barGroups,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final day = value.toInt();
                if (day == 1 || day % 5 == 0 || day == daysInMonth) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 4.0,
                    child: Text(day.toString(), style: axisLabelStyle),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45, 
              interval: yAxisInterval,
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max || value == 0) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 4.0,
                    child: Text(value.toStringAsFixed(0), style: axisLabelStyle),
                  );
                }
                if (value % meta.appliedInterval == 0) {
                    bool isCloseToMin = (value - meta.min).abs() < meta.appliedInterval * 0.4;
                    bool isCloseToMax = (meta.max - value).abs() < meta.appliedInterval * 0.4;
                    bool isCloseToZero = (value - 0).abs() < meta.appliedInterval * 0.4 && (meta.min < 0 && meta.max > 0);

                    if (!isCloseToMin && !isCloseToMax && !isCloseToZero) {
                         return SideTitleWidget(
                           axisSide: meta.axisSide,
                           space: 4.0,
                           child: Text(value.toStringAsFixed(0), style: axisLabelStyle),
                         );
                    }
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          verticalInterval: 1.0,
          drawHorizontalLine: true,
          horizontalInterval: yAxisInterval,
          getDrawingHorizontalLine: (value) =>
            FlLine(color: gridLineColor, strokeWidth: gridStrokeWidth),
          getDrawingVerticalLine: (value) {
            final day = value.toInt();
            if (day == 1 || day % 5 == 0 || day == daysInMonth) {
              return FlLine(color: gridLineColor, strokeWidth: gridStrokeWidth);
            }
            return FlLine(color: gridLineColor.withOpacity(0.5), strokeWidth: gridStrokeWidth / 2);
          },
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey.shade700.withOpacity(0.9),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String dayFormatted = 'Day ${group.x.toInt()}';
              return BarTooltipItem(
                '$dayFormatted\n',
                TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  shadows: [
                    Shadow(
                      blurRadius: 2.0,
                      color: Colors.black.withOpacity(0.5),
                      offset: Offset(1, 1),
                    ),
                  ]
                ),
                children: <TextSpan>[
                  TextSpan(
                    text: rod.toY.toStringAsFixed(2),
                    style: TextStyle(
                      color: rod.toY >= 0
                          ? Colors.lightGreenAccent.shade100
                          : Colors.redAccent.shade100,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                       shadows: [
                        Shadow(
                          blurRadius: 2.0,
                          color: Colors.black.withOpacity(0.5),
                          offset: Offset(1, 1),
                        ),
                      ]
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
  */

  Widget _dailyTransactionCard(
    Map<String, dynamic> data,
    DateTime currentMonthDateTime,
  ) {
    final dayNumber = data['dayNumber'] as int;
    final dailyNet = data['dailyNet'] as double;
    final cumulativeBalance = data['cumulativeBalance'] as double;

    final DateTime specificDate = DateTime(
      currentMonthDateTime.year,
      currentMonthDateTime.month,
      dayNumber,
    );

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DailyDetailsScreen(
                selectedDate: specificDate,
                accountId: ChosenAccount().account?.id,
                dailyNet: dailyNet,
                cumulativeBalance: cumulativeBalance,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: date badge + title + chevron
              Row(
                children: [
                  // Date badge
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.purple.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.purple.withOpacity(0.18),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$dayNumber',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.purple,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title: Day X - Weekday
                  Expanded(
                    child: Text(
                      'Day $dayNumber - ${DateFormat.EEEE().format(specificDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.purple,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.purple.withOpacity(0.4),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Stat pills: Net + Balance
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Net pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (dailyNet >= 0
                                  ? AppColors.greyishGreen
                                  : AppColors.greyishRed)
                              .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          dailyNet >= 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                          size: 18,
                          color: dailyNet >= 0
                              ? AppColors.greyishGreen
                              : AppColors.greyishRed,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Net: ${dailyNet.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: dailyNet >= 0
                                ? AppColors.greyishGreen
                                : AppColors.greyishRed,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Balance pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (cumulativeBalance >= 0
                                  ? AppColors.greyishGreen
                                  : AppColors.greyishRed)
                              .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          cumulativeBalance >= 0
                              ? Icons.account_balance_wallet
                              : Icons.account_balance_wallet_outlined,
                          size: 18,
                          color: cumulativeBalance >= 0
                              ? AppColors.greyishGreen
                              : AppColors.greyishRed,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Balance: ${cumulativeBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: cumulativeBalance >= 0
                                ? AppColors.greyishGreen
                                : AppColors.greyishRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyTransactionCards() {
    if (_currentMonthIndex < 0 ||
        _currentMonthIndex >= _availableMonths.length) {
      return const Center(
        child: Text("Select a month to see daily transactions."),
      );
    }

    final List<Map<String, dynamic>> daysWithTransactions =
        _selectedMonthChartData
            .where(
              (data) => data['dailyNet'] != null && data['dailyNet'] != 0.0,
            )
            .toList();

    if (daysWithTransactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 50,
                color: AppColors.purple.withOpacity(0.2),
              ),
              const SizedBox(height: 10),
              Text(
                'No transactions recorded for this month.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.purple.withOpacity(0.6),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final DateTime currentMonthDateTime = _availableMonths[_currentMonthIndex];

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 112),
      itemCount: daysWithTransactions.length,
      itemBuilder: (context, index) {
        final data = daysWithTransactions[index];
        return DailySummaryCard(
          specificDate: DateTime(
            currentMonthDateTime.year,
            currentMonthDateTime.month,
            data['dayNumber'] as int,
          ),
          dailyNet: data['dailyNet'] as double,
          cumulativeBalance: data['cumulativeBalance'] as double,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeScaffold(
      appBar: AppBar(title: const Text('Monthly Summary'), centerTitle: true),
      body: SwipePeriodNavigation(
        label: _formattedDisplayedMonth,
        isLoading: _isLoading,
        canGoOlder: _canGoToOlder(),
        canGoNewer: _canGoToNewer(),
        isCurrent: _isCurrentMonthDisplayed(),
        onGoOlder: () {
          _goToPreviousMonth();
        },
        onGoNewer: () {
          _goToNextMonth();
        },
        onGoCurrent: () {
          _goToCurrentMonth();
        },
        onPickPeriod: _availableMonths.isEmpty
            ? null
            : () {
                _openMonthPicker();
              },
        currentTooltip: 'Current month',
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              MonthlyOrDailyDetailsCard(
                isMonthly: true,
                selectedDateTime: _displayedMonthDate,
                income: _selectedMonthIncome,
                expense: _selectedMonthExpense,
                overallBalanceEndOfMonthOrDay:
                    _overallBalanceAtEndOfSelectedMonth,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _buildDailyTransactionCards(),
                ),
              ),
            ],
          ),
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
            '$label:',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.purple,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _YearMonthPicker extends StatefulWidget {
  final List<int> years;
  final Map<int, List<DateTime>> monthsByYear;
  final List<DateTime> availableMonths;
  final int currentMonthIndex;

  const _YearMonthPicker({
    required this.years,
    required this.monthsByYear,
    required this.availableMonths,
    required this.currentMonthIndex,
  });

  @override
  State<_YearMonthPicker> createState() => _YearMonthPickerState();
}

class _YearMonthPickerState extends State<_YearMonthPicker> {
  int? _selectedYear;
  String _searchText = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _selectedYear == null
            ? 'Select Year'
            : 'Select Month for $_selectedYear',
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: TextField(
                onChanged: (value) => setState(() => _searchText = value),
                decoration: InputDecoration(
                  labelText: 'Search',
                  hintText: _selectedYear == null
                      ? 'Search Year...'
                      : 'Search Month...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_selectedYear == null)
              _buildYearList()
            else
              _buildMonthList(_selectedYear!),
          ],
        ),
      ),
      actions: [
        if (_selectedYear != null)
          TextButton(
            onPressed: () => setState(() => _selectedYear = null),
            child: const Text('Back to Years'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildYearList() {
    final filteredYears = widget.years
        .where((year) => year.toString().contains(_searchText))
        .toList();

    return Flexible(
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: filteredYears.length,
        itemBuilder: (context, index) {
          final year = filteredYears[index];
          final isSelected =
              widget.availableMonths.isNotEmpty &&
              widget.currentMonthIndex != -1 &&
              widget.availableMonths[widget.currentMonthIndex].year == year;

          return ListTile(
            title: Text(year.toString()),
            selected: isSelected,
            onTap: () => setState(() => _selectedYear = year),
          );
        },
      ),
    );
  }

  Widget _buildMonthList(int year) {
    final months = widget.monthsByYear[year] ?? [];
    final filteredMonths = months
        .where(
          (month) => DateFormat.MMMM()
              .format(month)
              .toLowerCase()
              .contains(_searchText.toLowerCase()),
        )
        .toList();

    return Flexible(
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: filteredMonths.length,
        itemBuilder: (context, index) {
          final monthDate = filteredMonths[index];
          final formattedMonth = DateFormat.MMMM().format(monthDate);
          final globalIndex = widget.availableMonths.indexOf(monthDate);

          return ListTile(
            title: Text(formattedMonth),
            selected: globalIndex == widget.currentMonthIndex,
            onTap: () {
              if (globalIndex != -1) {
                Navigator.of(context).pop(globalIndex);
              }
            },
          );
        },
      ),
    );
  }
}

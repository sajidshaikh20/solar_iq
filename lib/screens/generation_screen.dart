import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../core/theme/text_styles.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_strings.dart';
import '../core/constants/app_spacing.dart';
import '../common_widgets/common_text.dart';
import '../common_widgets/common_card.dart';
import '../services/firebase_service.dart';
import '../models/generation_log.dart';
import '../models/energy_data.dart';
import 'package:fl_chart/fl_chart.dart';

class GenerationPageContent extends StatefulWidget {
  const GenerationPageContent({super.key});

  @override
  State<GenerationPageContent> createState() => _GenerationPageContentState();
}

class _GenerationPageContentState extends State<GenerationPageContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _fbService = FirebaseService();

  // Cache streams once so setState() (e.g. tab change) doesn't re-subscribe
  // and trigger MissingPluginException("cancel ...") races on teardown.
  late final Stream<EnergyData> _energyStream;
  late final Stream<List<GenerationLogEntry>> _logsStream;
  late final Stream<double> _rateStream;

  final List<String> _tabs = [
    AppStrings.tabToday,
    AppStrings.tabYesterday,
    AppStrings.tabThisMonth,
    AppStrings.tabCustom,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
    // Firebase's onValue.map returns a single-subscription stream. Wrap
    // it as a broadcast stream so both _buildLiveStatus and _buildMainStat
    // (and the chart) can listen at the same time.
    _energyStream = _fbService.getEnergyDataStream().asBroadcastStream();
    _logsStream = _fbService.getLogsStream(limit: 500).asBroadcastStream();
    _rateStream = _fbService.getElectricityRateStream().asBroadcastStream();
    dev.log('[GEN-SCREEN] initState: streams initialised',
        name: 'GenerationScreen');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<double>(
        stream: _rateStream,
        builder: (context, rateSnapshot) {
          final rate = rateSnapshot.data ?? 8.0;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                child: _buildTabBar(),
              ),
              Expanded(
                child: StreamBuilder<List<GenerationLogEntry>>(
                  stream: _logsStream,
                  builder: (context, logsSnapshot) {
                    final logs = logsSnapshot.data ?? const <GenerationLogEntry>[];
                    final today = _todayFromLogs(logs);
                    final yesterday = _yesterdayFromLogs(logs);
                    final thisMonth = _thisMonthFromLogs(logs);
                    final lastMonth = _lastMonthFromLogs(logs);
                    final total = _totalFromLogs(logs);

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                      child: Column(
                        children: [
                          _buildLiveStatus(),
                          const SizedBox(height: AppSpacing.lg),
                          _buildMainStat(today, yesterday, thisMonth, total, rate),
                          const SizedBox(height: AppSpacing.lg),
                          _buildTrendGraph(logs, rate),
                          const SizedBox(height: AppSpacing.lg),
                          _buildMonthlyComparison(thisMonth, lastMonth, rate),
                          const SizedBox(height: AppSpacing.lg),
                          _buildEnvironmentalImpact(total),
                          const SizedBox(height: AppSpacing.lg),
                          _buildDailySavingsTable(logs, rate),
                          const SizedBox(height: 120),
                        ],
                      ),
                    );
                  }
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        color: Colors.white,
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final isSelected = _tabController.index == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                _tabController.animateTo(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isSelected
                      ? AppColors.primaryAccent.withOpacity(0.15)
                      : Colors.transparent,
                  border: isSelected
                      ? const Border(
                          bottom: BorderSide(
                            color: AppColors.primaryEmerald,
                            width: 2,
                          ),
                        )
                      : null,
                ),
                child: Center(
                  child: Text(
                    _tabs[i],
                    style: isSelected
                        ? AppTextStyles.labelMedium.copyWith(
                            color: AppColors.primaryEmerald,
                            fontWeight: FontWeight.w600,
                          )
                        : AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textTertiary.withOpacity(0.6),
                          ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ---- Totals computed directly from logs (source of truth) ----
  double _todayFromLogs(List<GenerationLogEntry> logs) {
    final now = DateTime.now();
    double sum = 0;
    for (final e in logs) {
      final t = e.timestamp;
      if (t.year == now.year && t.month == now.month && t.day == now.day) {
        sum += e.units;
      }
    }
    return sum;
  }

  double _yesterdayFromLogs(List<GenerationLogEntry> logs) {
    final y = DateTime.now().subtract(const Duration(days: 1));
    double sum = 0;
    for (final e in logs) {
      final t = e.timestamp;
      if (t.year == y.year && t.month == y.month && t.day == y.day) {
        sum += e.units;
      }
    }
    return sum;
  }

  double _thisMonthFromLogs(List<GenerationLogEntry> logs) {
    final now = DateTime.now();
    double sum = 0;
    for (final e in logs) {
      final t = e.timestamp;
      if (t.year == now.year && t.month == now.month) {
        sum += e.units;
      }
    }
    return sum;
  }

  double _lastMonthFromLogs(List<GenerationLogEntry> logs) {
    final now = DateTime.now();
    final lastMonthDate = DateTime(now.year, now.month - 1);
    double sum = 0;
    for (final e in logs) {
      final t = e.timestamp;
      if (t.year == lastMonthDate.year && t.month == lastMonthDate.month) {
        sum += e.units;
      }
    }
    return sum;
  }

  double _totalFromLogs(List<GenerationLogEntry> logs) {
    double sum = 0;
    for (final e in logs) {
      sum += e.units;
    }
    return sum;
  }

  Widget _buildMainStat(double today, double yesterday, double thisMonth, double total, double rate) {
    return StreamBuilder<EnergyData>(
      stream: _energyStream,
      builder: (context, energySnapshot) {
        String value = '0';
        final index = _tabController.index;

        if (index == 0) {
          // Today: prefer live board reading, fall back to summed logs.
          if (energySnapshot.hasData &&
              energySnapshot.data!.units > 0) {
            value = energySnapshot.data!.units.toStringAsFixed(2);
          } else {
            value = today.toStringAsFixed(1);
          }
        } else if (index == 1) {
          value = yesterday.toStringAsFixed(1);
        } else if (index == 2) {
          value = thisMonth.toStringAsFixed(1);
        } else {
          value = total.toStringAsFixed(1);
        }

        final double doubleVal = double.tryParse(value) ?? 0.0;
        final double savingsVal = doubleVal * rate;

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: CommonCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [AppColors.primaryAccent, AppColors.primaryEmerald],
                            ),
                          ),
                          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          value,
                          style: AppTextStyles.headingLarge.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryEmerald,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        CommonText(
                          _tabController.index == 0
                              ? 'kWh Today'
                              : _tabController.index == 1
                                  ? 'kWh Yesterday'
                                  : _tabController.index == 2
                                      ? 'kWh This Month'
                                      : 'Lifetime kWh',
                          variant: TextVariant.caption,
                          color: AppColors.textSecondary.withOpacity(0.7),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CommonCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE65100).withOpacity(0.1),
                          ),
                          child: const Icon(Icons.currency_rupee_rounded, color: Color(0xFFE65100), size: 20),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '₹${savingsVal.toStringAsFixed(2)}',
                          style: AppTextStyles.headingLarge.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFE65100),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        CommonText(
                          _tabController.index == 0
                              ? "Today's Savings"
                              : _tabController.index == 1
                                  ? "Yesterday's Savings"
                                  : _tabController.index == 2
                                      ? "This Month's Savings"
                                      : "Lifetime Savings",
                          variant: TextVariant.caption,
                          color: AppColors.textSecondary.withOpacity(0.7),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      }
    );
  }

  Widget _buildLiveStatus() {
    return StreamBuilder<EnergyData>(
      stream: _energyStream,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return CommonCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const CommonText('Live System Status', variant: TextVariant.labelLarge),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryEmerald.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryEmerald)),
                        const SizedBox(width: 4),
                        const Text('Live', style: TextStyle(fontSize: 10, color: AppColors.primaryEmerald, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildLiveIndicator(Icons.bolt_rounded, '${data?.power.toStringAsFixed(1) ?? '0'} W', 'Power'),
                  _buildLiveIndicator(Icons.speed_rounded, '${data?.voltage.toStringAsFixed(1) ?? '0'}V', 'Voltage'),
                  _buildLiveIndicator(Icons.electric_moped_rounded, '${data?.current.toStringAsFixed(2) ?? '0'}A', 'Current'),
                ],
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildLiveIndicator(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryEmerald, size: 20),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.labelLarge.copyWith(fontSize: 14)),
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
        ],
      ),
    );
  }

  // -------- Trend graph (tab-aware) --------

  String _graphTitle() {
    switch (_tabController.index) {
      case 0:
        return 'Today (Hourly)';
      case 1:
        return 'Yesterday (Hourly)';
      case 2:
        return 'This Month (Week-wise)';
      default:
        return 'Last 7 Days';
    }
  }

  /// Build chart data for the currently selected tab.
  /// Returns a list of (label, value) pairs.
  List<MapEntry<String, double>> _buildSeries(List<GenerationLogEntry> logs) {
    final now = DateTime.now();
    final index = _tabController.index;

    if (index == 0 || index == 1) {
      // Hourly bars from 6 AM .. 8 PM (15 buckets) for today / yesterday.
      final DateTime targetDay = index == 0
          ? DateTime(now.year, now.month, now.day)
          : DateTime(now.year, now.month, now.day)
              .subtract(const Duration(days: 1));

      const int startHour = 6;
      const int endHour = 20; // inclusive
      final int buckets = endHour - startHour + 1;
      final List<double> hourly = List.filled(buckets, 0.0);

      for (final entry in logs) {
        final t = entry.timestamp;
        if (t.year == targetDay.year &&
            t.month == targetDay.month &&
            t.day == targetDay.day) {
          if (t.hour >= startHour && t.hour <= endHour) {
            hourly[t.hour - startHour] += entry.units;
          }
        }
      }

      return List<MapEntry<String, double>>.generate(buckets, (i) {
        final hour = startHour + i;
        // Show every 3rd hour as a label to keep things readable.
        final label = (i % 3 == 0)
            ? (hour == 12
                ? '12P'
                : hour > 12
                    ? '${hour - 12}P'
                    : '${hour}A')
            : '';
        return MapEntry(label, hourly[i]);
      });
    }

    if (index == 2) {
      // Week-wise totals for the current month (W1..W5).
      final DateTime monthStart = DateTime(now.year, now.month, 1);
      final DateTime nextMonth = DateTime(now.year, now.month + 1, 1);
      final int daysInMonth = nextMonth.difference(monthStart).inDays;
      // Five weekly buckets: days 1-7, 8-14, 15-21, 22-28, 29-end.
      final int totalWeeks = ((daysInMonth - 1) ~/ 7) + 1;
      final List<double> weekly = List.filled(totalWeeks, 0.0);

      for (final entry in logs) {
        final t = entry.timestamp;
        if (t.year == now.year && t.month == now.month) {
          final int weekIdx = (t.day - 1) ~/ 7;
          if (weekIdx >= 0 && weekIdx < totalWeeks) {
            weekly[weekIdx] += entry.units;
          }
        }
      }

      return List<MapEntry<String, double>>.generate(
          totalWeeks, (i) => MapEntry('W${i + 1}', weekly[i]));
    }

    // Custom tab: last 7 days, daily totals.
    final List<double> daily = List.filled(7, 0.0);
    final List<String> labels = List.filled(7, '');
    final DateTime today = DateTime(now.year, now.month, now.day);
    for (int i = 0; i < 7; i++) {
      final d = today.subtract(Duration(days: 6 - i));
      labels[i] = '${d.day}/${d.month}';
    }
    for (final entry in logs) {
      final t = entry.timestamp;
      final entryDay = DateTime(t.year, t.month, t.day);
      final diff = today.difference(entryDay).inDays;
      if (diff >= 0 && diff < 7) {
        daily[6 - diff] += entry.units;
      }
    }
    return List<MapEntry<String, double>>.generate(
        7, (i) => MapEntry(labels[i], daily[i]));
  }

  Widget _buildTrendGraph(List<GenerationLogEntry> logs, double rate) {
    final series = _buildSeries(logs);
    double maxUnits = 1.0;
    for (final e in series) {
      if (e.value > maxUnits) maxUnits = e.value;
    }
    // Add a little headroom so the tallest bar isn't flush with the top.
    maxUnits = maxUnits * 1.2;
    if (maxUnits < 5) maxUnits = 5;

    final List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < series.length; i++) {
      final v = series[i].value;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: v,
              gradient: v > 0 ? AppColors.primaryGradient : null,
              color: v > 0 ? null : Colors.transparent,
              width: series.length > 10 ? 8 : 14,
              borderRadius: BorderRadius.circular(4),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxUnits,
                color:
                    AppColors.primaryAccent.withOpacity(0.05),
              ),
            ),
          ],
        ),
      );
    }

    return CommonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CommonText(
                _graphTitle(),
                variant: TextVariant.labelLarge,
                color: AppColors.textPrimary,
              ),
              const Icon(Icons.show_chart_rounded,
                  color: AppColors.primaryEmerald, size: 20),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxUnits,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, gIdx, rod, rIdx) {
                      final label = (group.x.toInt() < series.length)
                          ? series[group.x.toInt()].key
                          : '';
                      final savings = rod.toY * rate;
                      return BarTooltipItem(
                        '${label.isEmpty ? '' : '$label\n'}'
                        '${rod.toY.toStringAsFixed(2)} kWh\n'
                        '₹${savings.toStringAsFixed(2)}',
                        const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= series.length) {
                          return const SizedBox.shrink();
                        }
                        final label = series[i].key;
                        if (label.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            label,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary
                                  .withOpacity(0.6),
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                      reservedSize: 26,
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyComparison(double thisMonthUnits, double lastMonthUnits, double rate) {
    final diffUnits = thisMonthUnits - lastMonthUnits;
    final diffSavings = diffUnits * rate;

    final isPositive = diffUnits >= 0;
    final sign = isPositive ? '+' : '';
    final trendColor = isPositive ? Colors.green.shade600 : Colors.red.shade600;

    final now = DateTime.now();
    final thisMonthName = _getMonthName(now.month);
    final lastMonthName = _getMonthName(DateTime(now.year, now.month - 1).month);

    return CommonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const CommonText('Monthly Comparison', variant: TextVariant.labelLarge),
              Icon(
                isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: trendColor,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CommonText(lastMonthName, variant: TextVariant.caption),
                  const SizedBox(height: 4),
                  CommonText(
                    '${lastMonthUnits.toStringAsFixed(1)} kWh',
                    variant: TextVariant.labelLarge,
                  ),
                  CommonText(
                    '₹ ${(lastMonthUnits * rate).toStringAsFixed(0)}',
                    variant: TextVariant.caption,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CommonText(thisMonthName, variant: TextVariant.caption),
                  const SizedBox(height: 4),
                  CommonText(
                    '${thisMonthUnits.toStringAsFixed(1)} kWh',
                    variant: TextVariant.labelLarge,
                  ),
                  CommonText(
                    '₹ ${(thisMonthUnits * rate).toStringAsFixed(0)}',
                    variant: TextVariant.caption,
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const CommonText('Difference', variant: TextVariant.bodyMedium),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$sign${diffUnits.toStringAsFixed(1)} kWh',
                    style: TextStyle(
                      color: trendColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '$sign₹${diffSavings.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: trendColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentalImpact(double totalUnits) {
    final co2 = totalUnits * 0.79; // kg CO2
    final trees = co2 / 22.0;      // trees equivalent

    return CommonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.eco_outlined, color: Colors.green.shade600, size: 20),
              const SizedBox(width: 8),
              const CommonText('Environmental Impact', variant: TextVariant.labelLarge),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    CommonText(
                      '${co2.toStringAsFixed(1)} kg',
                      variant: TextVariant.headingMedium,
                      color: Colors.green.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                    const SizedBox(height: 4),
                    CommonText(
                      'CO₂ Saved',
                      variant: TextVariant.caption,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: AppColors.borderColor),
              Expanded(
                child: Column(
                  children: [
                    CommonText(
                      trees.toStringAsFixed(1),
                      variant: TextVariant.headingMedium,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                    const SizedBox(height: 4),
                    CommonText(
                      'Trees Equivalent',
                      variant: TextVariant.caption,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailySavingsTable(List<GenerationLogEntry> logs, double rate) {
    // Group by date
    final Map<String, double> dailyUnits = {};
    for (final entry in logs) {
      final dateKey = '${entry.timestamp.year}-${entry.timestamp.month.toString().padLeft(2, '0')}-${entry.timestamp.day.toString().padLeft(2, '0')}';
      dailyUnits[dateKey] = (dailyUnits[dateKey] ?? 0.0) + entry.units;
    }

    // Sort keys descending
    final sortedDates = dailyUnits.keys.toList()..sort((a, b) => b.compareTo(a));
    final displayDates = sortedDates.take(7).toList(); // Show last 7 days of entries

    return CommonCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CommonText('Recent Daily Breakdowns', variant: TextVariant.labelLarge),
          const SizedBox(height: 16),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1.5),
              2: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.borderColor, width: 1.5)),
                ),
                children: const [
                  Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: CommonText('Date', variant: TextVariant.labelMedium, fontWeight: FontWeight.bold),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: CommonText('Units (kWh)', variant: TextVariant.labelMedium, fontWeight: FontWeight.bold),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: CommonText('Savings', variant: TextVariant.labelMedium, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              ...displayDates.map((dateStr) {
                final units = dailyUnits[dateStr] ?? 0.0;
                final savings = units * rate;
                
                final parts = dateStr.split('-');
                final day = int.parse(parts[2]);
                final month = int.parse(parts[1]);
                final formattedDate = '$day ${_getMonthAbbreviation(month)}';

                return TableRow(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.borderColor.withOpacity(0.5))),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: CommonText(formattedDate, variant: TextVariant.bodyMedium),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: CommonText('${units.toStringAsFixed(1)} kWh', variant: TextVariant.bodyMedium),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: CommonText('₹${savings.toStringAsFixed(2)}', variant: TextVariant.bodyMedium, color: const Color(0xFFE65100)),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    if (month < 1 || month > 12) return '';
    return months[month - 1];
  }

  String _getMonthAbbreviation(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (month < 1 || month > 12) return '';
    return months[month - 1];
  }
}

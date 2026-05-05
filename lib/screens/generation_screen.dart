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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: _buildTabBar(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
              child: Column(
                children: [
                  _buildLiveStatus(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildMainStat(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildTrendGraph(),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
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
  // The summaries/{uid} doc is unreliable when entries are pushed by
  // hardware that doesn't go through saveGenerationEntry. Bucketing the
  // raw logs by date guarantees Yesterday / This Month always reflect
  // what's actually in Firebase.
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

  double _totalFromLogs(List<GenerationLogEntry> logs) {
    double sum = 0;
    for (final e in logs) {
      sum += e.units;
    }
    return sum;
  }

  Widget _buildMainStat() {
    return StreamBuilder<EnergyData>(
      stream: _energyStream,
      builder: (context, energySnapshot) {
        return StreamBuilder<List<GenerationLogEntry>>(
          stream: _logsStream,
          builder: (context, logsSnapshot) {
            final logs =
                logsSnapshot.data ?? const <GenerationLogEntry>[];
            String value = '0';
            final index = _tabController.index;

            // Compute every bucket so we can log them all together for
            // diagnosis, no matter which tab is currently selected.
            final today = _todayFromLogs(logs);
            final yesterday = _yesterdayFromLogs(logs);
            final thisMonth = _thisMonthFromLogs(logs);
            final total = _totalFromLogs(logs);
            final liveUnits =
                energySnapshot.hasData ? energySnapshot.data!.units : -1;
            dev.log(
              '[GEN-STAT] tab=$index logsCount=${logs.length} '
              'today=$today yesterday=$yesterday '
              'thisMonth=$thisMonth total=$total liveUnits=$liveUnits',
              name: 'GenerationScreen',
            );

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

        return CommonCard(
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryAccent, AppColors.primaryEmerald],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryAccent.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  value,
                  key: ValueKey(value),
                  style: AppTextStyles.displayLarge.copyWith(
                    foreground: Paint()
                      ..shader = AppColors.primaryGradient.createShader(
                          const Rect.fromLTWH(0, 0, 200, 80)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              CommonText(
                _tabController.index == 0 ? AppStrings.kwhGeneratedToday : 'Total kWh Generated',
                variant: TextVariant.bodyMedium,
                color: AppColors.textSecondary.withOpacity(0.7),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  color: AppColors.primaryAccent.withOpacity(0.10),
                  border: Border.all(
                      color: AppColors.primaryAccent.withOpacity(0.25)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up_rounded,
                        color: AppColors.primaryEmerald, size: 16),
                    SizedBox(width: 6),
                    CommonText(
                      'Live Generation Data',
                      variant: TextVariant.bodySmall,
                      color: AppColors.primaryEmerald,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
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

  Widget _buildTrendGraph() {
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
            child: StreamBuilder<List<GenerationLogEntry>>(
              stream: _logsStream,
              builder: (context, snapshot) {
                final logs = snapshot.data ?? const <GenerationLogEntry>[];
                final series = _buildSeries(logs);
                dev.log(
                  '[GEN-CHART] tab=${_tabController.index} '
                  'logsCount=${logs.length} '
                  'seriesValues=${series.map((e) => e.value).toList()}',
                  name: 'GenerationScreen',
                );

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

                return BarChart(
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
                          return BarTooltipItem(
                            '${label.isEmpty ? '' : '$label\n'}'
                            '${rod.toY.toStringAsFixed(2)} kWh',
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

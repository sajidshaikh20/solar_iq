import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/text_styles.dart';
import 'emi_calculator_screen.dart';
import 'services_screen.dart';
import 'query_screen.dart';
import 'monitoring_screen.dart';
import 'roi_screen.dart';
import 'cleaning_screen.dart';
import 'installation_screen.dart';
import '../services/firebase_service.dart';
import '../models/energy_data.dart';
import '../models/generation_summary.dart';

class HomePageContent extends StatelessWidget {
  final String? userName;
  const HomePageContent({super.key, this.userName});

  @override
  Widget build(BuildContext context) {
    final menus = _menuItems(context);
    final fbService = FirebaseService();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeHeader(),
          const SizedBox(height: 20),
          _buildTotalSavingsCard(fbService),
          const SizedBox(height: 16),
        //  _buildDynamicSavingsCards(fbService),
          const SizedBox(height: 24),
          Text(
            'Quick Actions & Tools',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.05,
            ),
            itemCount: menus.length,
            itemBuilder: (context, index) => _MenuCard(item: menus[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryMint, AppColors.primaryEmerald],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryMint.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.secondaryNavy.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName ?? 'Solar User',
                  style: AppTextStyles.headingLarge.copyWith(
                    color: AppColors.secondaryNavy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<EnergyData>(
                  stream: FirebaseService().getEnergyDataStream(),
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    return Row(
                      children: [
                        _buildMiniStat(
                          Icons.bolt_rounded,
                          '${data?.power.toStringAsFixed(1) ?? '0'}W Live Power',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.solar_power_rounded,
              color: AppColors.secondaryNavy,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.secondaryNavy, size: 14),
          const SizedBox(width: 4),
          Text(
            value,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.secondaryNavy,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSavingsCard(FirebaseService fbService) {
    return StreamBuilder<double>(
      stream: fbService.getElectricityRateStream(),
      builder: (context, rateSnapshot) {
        final unitRate = rateSnapshot.data ?? 8.0;

        return StreamBuilder<GenerationSummary>(
          stream: fbService.getGenerationSummaryStream(),
          builder: (context, genSnapshot) {
            final genData = genSnapshot.data ?? GenerationSummary();
            final double totalLifetimeUnits = genData.total;

            return StreamBuilder<Map<dynamic, dynamic>?>(
              stream: fbService.getRoiDataStream(),
              builder: (context, roiSnapshot) {
                final roiData = roiSnapshot.data;

                double investment = 0.0;
                double storedRate = unitRate;
                int? paybackYear;
                double paybackPeriodMonths = 0.0;

                if (roiData != null) {
                  investment = (roiData['investment'] ?? 0).toDouble();
                  if (roiData['unitRate'] != null) {
                    storedRate = (roiData['unitRate'] as num).toDouble();
                  }
                  if (roiData['paybackYear'] != null) {
                    paybackYear = (roiData['paybackYear'] as num).toInt();
                  }
                  if (roiData['paybackPeriod'] != null) {
                    paybackPeriodMonths = (roiData['paybackPeriod'] as num).toDouble();
                  }
                }

                final double totalSavingsTillNow = totalLifetimeUnits * storedRate;
                double progress = 0.0;

                if (investment > 0) {
                  progress = (totalSavingsTillNow / investment).clamp(0.0, 1.0);
                }

                final String progressPercentageText = '${(progress * 100).toStringAsFixed(1)}%';
                
                String paybackSubtitle;
                if (investment > 0 && paybackYear != null) {
                  paybackSubtitle = '₹${investment.toStringAsFixed(0)} investment • Est. Payback Year $paybackYear';
                } else if (investment > 0) {
                  final years = paybackPeriodMonths > 0 ? (paybackPeriodMonths / 12).toStringAsFixed(1) : 'N/A';
                  paybackSubtitle = '₹${investment.toStringAsFixed(0)} total investment • Est. $years yrs';
                } else {
                  paybackSubtitle = 'Set your total investment in ROI Tracker to track payback %';
                }

                return Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                    border: Border.all(color: AppColors.borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryEmerald.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryEmerald.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: AppColors.primaryEmerald,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Total Savings Till Now',
                                      style: AppTextStyles.labelLarge.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryEmerald.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$progressPercentageText Recovered',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primaryEmerald,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '₹${totalSavingsTillNow.toStringAsFixed(2)}',
                            style: AppTextStyles.headingLarge.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryEmerald,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${totalLifetimeUnits.toStringAsFixed(1)} kWh generated)',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress > 0 ? progress : 0.02,
                          minHeight: 10,
                          backgroundColor: AppColors.primaryEmerald.withOpacity(0.12),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primaryEmerald,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(
                            Icons.insights_rounded,
                            color: AppColors.primaryEmerald,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              paybackSubtitle,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDynamicSavingsCards(FirebaseService fbService) {
    return StreamBuilder<double>(
      stream: fbService.getElectricityRateStream(),
      builder: (context, rateSnapshot) {
        final rate = rateSnapshot.data ?? 8.0;

        return StreamBuilder<GenerationSummary>(
          stream: fbService.getGenerationSummaryStream(),
          builder: (context, genSnapshot) {
            final gen = genSnapshot.data ?? GenerationSummary();
            final todaySavings = gen.today * rate;
            final yesterdaySavings = gen.yesterday * rate;
            final monthSavings = gen.thisMonth * rate;

            return Row(
              children: [
                _buildSavingsCard(
                  title: 'Today',
                  kwh: '${gen.today.toStringAsFixed(1)} kWh',
                  savings: '₹${todaySavings.toStringAsFixed(0)}',
                  color: const Color(0xFF1565C0),
                  icon: Icons.today_rounded,
                ),
                const SizedBox(width: 10),
                _buildSavingsCard(
                  title: 'Yesterday',
                  kwh: '${gen.yesterday.toStringAsFixed(1)} kWh',
                  savings: '₹${yesterdaySavings.toStringAsFixed(0)}',
                  color: const Color(0xFF0277BD),
                  icon: Icons.history_toggle_off_rounded,
                ),
                const SizedBox(width: 10),
                _buildSavingsCard(
                  title: 'This Month',
                  kwh: '${gen.thisMonth.toStringAsFixed(0)} kWh',
                  savings: '₹${monthSavings.toStringAsFixed(0)}',
                  color: const Color(0xFFE65100),
                  icon: Icons.calendar_month_rounded,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSavingsCard({
    required String title,
    required String kwh,
    required String savings,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: AppColors.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 15),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              savings,
              style: AppTextStyles.labelLarge.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              kwh,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_MenuItem> _menuItems(BuildContext context) => [
        _MenuItem(
          icon: Icons.calculate_outlined,
          title: 'EMI\nCalculator',
          color: const Color(0xFF1565C0),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EmiCalculatorScreen()),
          ),
        ),
        _MenuItem(
          icon: Icons.build_circle_outlined,
          title: 'Services',
          color: const Color(0xFF2E7D32),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ServicesScreen()),
          ),
        ),
        _MenuItem(
          icon: Icons.help_outline_rounded,
          title: 'Query\nPage',
          color: const Color(0xFF6A1B9A),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const QueryScreen()),
          ),
        ),
        _MenuItem(
          icon: Icons.monitor_heart_outlined,
          title: 'Solar Unit\nMonitoring',
          color: const Color(0xFF00695C),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MonitoringScreen()),
          ),
        ),
        _MenuItem(
          icon: Icons.trending_up_rounded,
          title: 'ROI &\nInvestment',
          color: const Color(0xFFE65100),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RoiScreen()),
          ),
        ),
        _MenuItem(
          icon: Icons.water_drop_outlined,
          title: 'Smart\nCleaning',
          color: const Color(0xFF0277BD),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CleaningScreen()),
          ),
        ),
        _MenuItem(
          icon: Icons.wb_sunny_outlined,
          title: 'New Solar\nInstallation',
          color: AppColors.primaryEmerald,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InstallationScreen()),
          ),
        ),
      ];
}

class _MenuItem {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });
}

class _MenuCard extends StatelessWidget {
  final _MenuItem item;
  const _MenuCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          border: Border.all(color: AppColors.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Open',
                      style: AppTextStyles.caption.copyWith(
                        color: item.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 12,
                      color: item.color,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

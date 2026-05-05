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

class HomePageContent extends StatelessWidget {
  final String? userName;
  const HomePageContent({super.key, this.userName});

  @override
  Widget build(BuildContext context) {
    final menus = _menuItems(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeHeader(),
          const SizedBox(height: 20),
          _buildROIProgressCard(),
          const SizedBox(height: 24),
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
                          '${data?.power.toStringAsFixed(1) ?? '0'}W',
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.secondaryNavy, size: 12),
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

  Widget _buildROIProgressCard() {
    final fbService = FirebaseService();
    return StreamBuilder(
      stream: fbService.getRoiDataStream(),
      builder: (context, snapshot) {
        double progress = 0.0;
        String progressText = "0%";
        String paybackText = "Start ROI calculation to see progress";
        double investment = 0;
        double remaining = 0;
        double paybackYears = 0;

        if (snapshot.hasData && snapshot.data != null) {
          final data = snapshot.data!;
          investment = (data['investment'] ?? 0).toDouble();
          remaining = (data['remainingRecovery'] ?? 0).toDouble();
          paybackYears = (data['paybackPeriod'] ?? 0).toDouble() / 12;

          if (investment > 0) {
            double recovered = investment - remaining;
            progress = (recovered / investment).clamp(0.0, 1.0);
            progressText = "${(progress * 100).toStringAsFixed(0)}%";
          }

          String invText = investment >= 100000
              ? "${(investment / 100000).toStringAsFixed(2)} Lakhs"
              : "₹ ${investment.toStringAsFixed(0)}";

          paybackText =
              "$invText full payback in ${paybackYears.toStringAsFixed(1)} years";
        }

        return Container(
          padding: const EdgeInsets.all(20),
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
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ROI Progress',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    progressText,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primaryEmerald,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: AppColors.primaryEmerald.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primaryEmerald,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryEmerald.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_graph_rounded,
                      color: AppColors.primaryEmerald,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      paybackText,
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

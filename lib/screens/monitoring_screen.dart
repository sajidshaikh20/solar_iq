import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/text_styles.dart';
import '../services/firebase_service.dart';
import '../models/generation_summary.dart';

class MonitoringScreen extends StatelessWidget {
  const MonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fbService = FirebaseService();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Solar Unit Monitoring'),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderColor),
        ),
      ),
      body: StreamBuilder<GenerationSummary>(
        stream: fbService.getGenerationSummaryStream(),
        builder: (context, snapshot) {
          final summary = snapshot.data ?? GenerationSummary();

          final cards = [
            _MonitoringCard(
              title: 'Today Generation',
              value: summary.today.toStringAsFixed(1),
              unit: 'kWh',
              note: 'Updated live',
              notePositive: true,
              icon: Icons.wb_sunny_rounded,
              color: AppColors.primaryEmerald,
            ),
            _MonitoringCard(
              title: 'Yesterday Generation',
              value: summary.yesterday.toStringAsFixed(1),
              unit: 'kWh',
              note: 'Previous day total',
              notePositive: true,
              icon: Icons.history_rounded,
              color: const Color(0xFF0277BD),
            ),
            _MonitoringCard(
              title: 'Current Month',
              value: summary.thisMonth.toStringAsFixed(0),
              unit: 'kWh',
              note: 'Monthly progress',
              notePositive: true,
              icon: Icons.calendar_month_rounded,
              color: const Color(0xFF2E7D32),
            ),
            _MonitoringCard(
              title: 'Lifetime',
              value: summary.total.toStringAsFixed(0),
              unit: 'kWh',
              note: 'Since installation',
              notePositive: true,
              icon: Icons.all_inclusive_rounded,
              color: const Color(0xFF6A1B9A),
            ),
          ];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildSubtitleBanner(),
                const SizedBox(height: 20),
                ...cards.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _MonitoringCardWidget(card: c),
                )),
                const SizedBox(height: 30),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildSubtitleBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryMint.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppColors.primaryMint.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.primaryEmerald, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text('Today, yesterday, month & lifetime units', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryEmerald))),
        ],
      ),
    );
  }
}

class _MonitoringCard {
  final String title;
  final String value;
  final String unit;
  final String note;
  final bool notePositive;
  final IconData icon;
  final Color color;
  const _MonitoringCard({
    required this.title, required this.value, required this.unit,
    required this.note, required this.notePositive, required this.icon, required this.color,
  });
}

class _MonitoringCardWidget extends StatelessWidget {
  final _MonitoringCard card;
  const _MonitoringCardWidget({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [card.color.withOpacity(0.15), card.color.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: card.color.withOpacity(0.2)),
            ),
            child: Icon(card.icon, color: card.color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.title, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(card.value, style: AppTextStyles.headingLarge.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(card.unit, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(card.notePositive ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 14, color: card.notePositive ? const Color(0xFF2E7D32) : Colors.redAccent),
                    const SizedBox(width: 4),
                    Text(card.note, style: AppTextStyles.caption.copyWith(color: card.notePositive ? const Color(0xFF2E7D32) : Colors.redAccent)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

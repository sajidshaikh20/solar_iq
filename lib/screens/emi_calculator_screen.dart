import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/theme/colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/text_styles.dart';
import '../../common_widgets/common_button.dart';
import '../../common_widgets/common_textfield.dart';
import 'package:fl_chart/fl_chart.dart';

class EmiCalculatorScreen extends StatefulWidget {
  const EmiCalculatorScreen({super.key});

  @override
  State<EmiCalculatorScreen> createState() => _EmiCalculatorScreenState();
}

class _EmiCalculatorScreenState extends State<EmiCalculatorScreen> {
  final _loanController = TextEditingController();
  final _rateController = TextEditingController();
  final _tenureController = TextEditingController();
  String _tenureType = 'months';

  double? _monthlyEmi;
  double? _totalInterest;
  double? _totalPayable;

  @override
  void dispose() {
    _loanController.dispose();
    _rateController.dispose();
    _tenureController.dispose();
    super.dispose();
  }

  void _calculate() {
    final principal = double.tryParse(_loanController.text);
    final annualRate = double.tryParse(_rateController.text);
    final tenureRaw = double.tryParse(_tenureController.text);

    if (principal == null || annualRate == null || tenureRaw == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields correctly.')),
      );
      return;
    }

    int tenureMonths = _tenureType == 'years'
        ? (tenureRaw * 12).toInt()
        : tenureRaw.toInt();
    final monthlyRate = annualRate / 12 / 100;

    double emi;
    if (monthlyRate == 0) {
      emi = principal / tenureMonths;
    } else {
      emi =
          principal *
          monthlyRate *
          pow(1 + monthlyRate, tenureMonths) /
          (pow(1 + monthlyRate, tenureMonths) - 1);
    }

    setState(() {
      _monthlyEmi = emi;
      _totalPayable = emi * tenureMonths;
      _totalInterest = _totalPayable! - principal;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('EMI Calculator'),
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.05),
        surfaceTintColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderColor),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInputCard(),
            const SizedBox(height: 20),
            if (_monthlyEmi != null) ...[
              _buildResultCard(),
              const SizedBox(height: 20),
              _buildBreakdownSection(),
              const SizedBox(height: 24),
              _buildSubsidyNote(),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Loan Details',
            Icons.account_balance_outlined,
            const Color(0xFF1565C0),
          ),
          const SizedBox(height: 20),
          CommonTextField(
            label: 'Loan Amount (₹)',
            hint: 'e.g. 500000',
            controller: _loanController,
            keyboardType: TextInputType.number,
            prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Text(
                '₹',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          CommonTextField(
            label: 'Annual Interest Rate (%)',
            hint: 'e.g. 8.5',
            controller: _rateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffixIcon: const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                widthFactor: 1,
                child: Text(
                  '%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: CommonTextField(
                  label: 'Tenure',
                  hint: 'e.g. 36',
                  controller: _tenureController,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              _TenureToggle(
                value: _tenureType,
                onChanged: (v) => setState(() => _tenureType = v),
              ),
            ],
          ),
          const SizedBox(height: 24),
          CommonButton(
            label: 'Calculate EMI',
            icon: Icons.calculate_rounded,
            onPressed: _calculate,
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.summarize_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Calculation Summary',
                style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: Column(
              children: [
                Text(
                  '₹ ${_monthlyEmi!.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Monthly EMI',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ResultTile(
                  label: 'Total Interest',
                  value: '₹ ${_totalInterest!.toStringAsFixed(0)}',
                  icon: Icons.percent_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ResultTile(
                  label: 'Total Payable',
                  value: '₹ ${_totalPayable!.toStringAsFixed(0)}',
                  icon: Icons.payments_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownSection() {
    final principal = double.tryParse(_loanController.text) ?? 0;
    final interest = _totalInterest ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Your EMI Breakdown',
            Icons.pie_chart_outline_rounded,
            AppColors.primaryEmerald,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 140,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 35,
                      sections: [
                        PieChartSectionData(
                          value: principal,
                          color: const Color(0xFF1565C0),
                          radius: 12,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: interest,
                          color: AppColors.primaryEmerald,
                          radius: 12,
                          showTitle: false,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _BreakdownRow(
                      label: 'Principal',
                      value: '₹ ${principal.toStringAsFixed(0)}',
                      color: const Color(0xFF1565C0),
                    ),
                    const SizedBox(height: 12),
                    _BreakdownRow(
                      label: 'Interest',
                      value: '₹ ${interest.toStringAsFixed(0)}',
                      color: AppColors.primaryEmerald,
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

  Widget _buildSubsidyNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primaryEmerald.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppColors.primaryEmerald.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.primaryEmerald,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.stars_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subsidy Eligible',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primaryEmerald,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '₹ 78,000 Special Solar Subsidy',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: AppTextStyles.labelLarge.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _TenureToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _TenureToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.borderColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: ['months', 'years'].map((opt) {
          final sel = value == opt;
          return GestureDetector(
            onTap: () => onChanged(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFF1565C0) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                opt == 'months' ? 'Mo' : 'Yr',
                style: AppTextStyles.caption.copyWith(
                  color: sel ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _ResultTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white60, size: 16),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.labelLarge.copyWith(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/text_styles.dart';
import '../../common_widgets/common_button.dart';
import '../../common_widgets/common_textfield.dart';
import '../../services/firebase_service.dart';

class ElectricityBillCalculatorScreen extends StatefulWidget {
  const ElectricityBillCalculatorScreen({super.key});

  @override
  State<ElectricityBillCalculatorScreen> createState() =>
      _ElectricityBillCalculatorScreenState();
}

class _ElectricityBillCalculatorScreenState
    extends State<ElectricityBillCalculatorScreen> {
  final _previousReadingController = TextEditingController();
  final _currentReadingController = TextEditingController();
  final _tariffRateController = TextEditingController(text: '8.00');
  final _fbService = FirebaseService();

  double? _unitsConsumed;
  double? _totalBill;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentTariff();
  }

  @override
  void dispose() {
    _previousReadingController.dispose();
    _currentReadingController.dispose();
    _tariffRateController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentTariff() async {
    try {
      final rate = await _fbService.getElectricityRateStream().first;
      if (mounted) {
        setState(() {
          _tariffRateController.text = rate.toStringAsFixed(2);
        });
      }
    } catch (e) {
      // Keep default 8.00
    }
  }

  void _calculate() {
    setState(() {
      _errorMessage = null;
      _unitsConsumed = null;
      _totalBill = null;
    });

    final previous = double.tryParse(_previousReadingController.text);
    final current = double.tryParse(_currentReadingController.text);
    final rate = double.tryParse(_tariffRateController.text);

    if (previous == null || current == null || rate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields with valid numbers.')),
      );
      return;
    }

    if (previous < 0 || current < 0 || rate < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inputs cannot be negative.')),
      );
      return;
    }

    // Safety validation rule: Meter readings can only increase ("plus jate hai, minus nahi hoga")
    if (current < previous) {
      setState(() {
        _errorMessage =
            'Current reading cannot be less than previous reading. Meter readings only increase.';
      });
      return;
    }

    final units = current - previous;
    final bill = units * rate;

    setState(() {
      _unitsConsumed = units;
      _totalBill = bill;
    });
  }

  String _formatValue(double val) {
    if (val == val.toInt()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Electricity Bill Calculator'),
        backgroundColor: Colors.white,
        elevation: 0,
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
            if (_errorMessage != null) _buildErrorCard(),
            if (_unitsConsumed != null && _totalBill != null) _buildResultCard(),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryMint.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.electric_meter_rounded,
                  color: AppColors.primaryEmerald,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text('Meter Readings', style: AppTextStyles.labelLarge),
            ],
          ),
          const SizedBox(height: 20),
          CommonTextField(
            label: 'Previous Meter Reading (kWh)',
            hint: 'e.g. 12450',
            controller: _previousReadingController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixIcon: const Icon(Icons.history_rounded, color: AppColors.primaryEmerald),
          ),
          const SizedBox(height: 16),
          CommonTextField(
            label: 'Current Meter Reading (kWh)',
            hint: 'e.g. 12575',
            controller: _currentReadingController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixIcon: const Icon(Icons.today_rounded, color: AppColors.primaryEmerald),
          ),
          const SizedBox(height: 16),
          CommonTextField(
            label: 'Electricity Tariff Rate (₹/kWh)',
            hint: 'e.g. 8.00',
            controller: _tariffRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: CommonButton(
              label: 'Calculate Bill',
              icon: Icons.calculate_outlined,
              onPressed: _calculate,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.red.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryEmerald, AppColors.primaryMint],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.receipt_long_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Calculation Details',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Units Consumed', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatValue(_unitsConsumed!)} kWh',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              Container(width: 1, height: 40, color: Colors.white30),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Total Estimated Bill', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    '₹ ${_formatValue(_totalBill!)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24, color: Colors.white30),
          Row(
            children: const [
              Icon(Icons.info_outline_rounded, color: Colors.white70, size: 14),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Formula: Units (kWh) = Current Reading - Previous Reading. Readings cannot go down.',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/text_styles.dart';
import '../common_widgets/common_button.dart';
import '../common_widgets/common_textfield.dart';
import '../services/firebase_service.dart';

class InstallationScreen extends StatefulWidget {
  const InstallationScreen({super.key});

  @override
  State<InstallationScreen> createState() => _InstallationScreenState();
}

class _InstallationScreenState extends State<InstallationScreen> {
  final _fbService = FirebaseService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _billController = TextEditingController();

  double? _recommendedSize;
  double? _estimatedGeneration;
  double? _approxCost;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _billController.dispose();
    super.dispose();
  }

  void _calculate() async {
    final bill = double.tryParse(_billController.text);
    if (bill == null || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill Name and Monthly Bill.')),
      );
      return;
    }

    // Formulas: 1 kW solar ≈ ₹1000 saved/month | 1 kW ≈ 120 kWh/month | 1 kW costs ≈ ₹50000-70000
    final size = bill / 1000;
    final generation = size * 120;
    final cost = size * 60000;

    setState(() {
      _recommendedSize = size;
      _estimatedGeneration = generation;
      _approxCost = cost;
      _isLoading = true;
    });

    // Save to database with success feedback
    try {
      final result = await _fbService.saveQuotation({
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'monthlyBill': bill,
        'recommendedSize': size,
        'estimatedGeneration': generation,
        'approxCost': cost,
      });
      
      if (mounted) {
        setState(() => _isLoading = false);
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quotation saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save quotation: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save quotation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('New Solar Installation'),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderColor),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildLeadCard(),
                  const SizedBox(height: 20),
                  if (_recommendedSize != null) _buildResultCard(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          _buildBottomButtons(context),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryMint, AppColors.primaryEmerald],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        boxShadow: [BoxShadow(color: AppColors.primaryMint.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Go Solar Today!', style: AppTextStyles.headingMedium.copyWith(color: AppColors.secondaryNavy, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Get a free instant quotation for your solar installation.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryNavy.withOpacity(0.7))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.wb_sunny_rounded, color: AppColors.secondaryNavy, size: 36),
        ],
      ),
    );
  }

  Widget _buildLeadCard() {
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
                decoration: BoxDecoration(color: AppColors.primaryEmerald.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.person_pin_outlined, color: AppColors.primaryEmerald, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Lead Details', style: AppTextStyles.labelLarge),
            ],
          ),
          const SizedBox(height: 20),
          CommonTextField(label: 'Full Name', hint: 'Your name', controller: _nameController),
          const SizedBox(height: 16),
          CommonTextField(label: 'Email Address', hint: 'email@example.com', controller: _emailController, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          CommonTextField(label: 'Phone Number', hint: '+91 XXXXX XXXXX', controller: _phoneController, keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          CommonTextField(
            label: 'Monthly Electricity Bill (₹)',
            hint: 'e.g. 5000',
            controller: _billController,
            keyboardType: TextInputType.number,
            prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Text('₹', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(color: AppColors.primaryMint.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: AppColors.primaryMint.withOpacity(0.15), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryEmerald, size: 20),
              const SizedBox(width: 8),
              Text('Quotation Details', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryEmerald)),
            ],
          ),
          const SizedBox(height: 20),
          _quoteTile(Icons.solar_power_outlined, 'Recommended Size', '${_recommendedSize!.toStringAsFixed(1)} kW', const Color(0xFF1565C0)),
          const Divider(height: 20),
          _quoteTile(Icons.bolt_rounded, 'Est. Generation', '${_estimatedGeneration!.toStringAsFixed(0)} kWh/month', const Color(0xFF2E7D32)),
          const Divider(height: 20),
          _quoteTile(Icons.currency_rupee_rounded, 'Approx Cost', '₹ ${_approxCost!.toStringAsFixed(0)}', const Color(0xFFE65100)),
        ],
      ),
    );
  }

  Widget _quoteTile(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.borderColor))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primaryMint, AppColors.primaryEmerald]),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                boxShadow: [BoxShadow(color: AppColors.primaryMint.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: ElevatedButton.icon(
                onPressed: _isLoading ? () {} : _calculate,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge))),
                icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondaryNavy))
                    : const Icon(Icons.bolt_rounded, color: AppColors.secondaryNavy, size: 20),
                label: Text(_isLoading ? 'Saving...' : 'Get Instant Quotation', style: AppTextStyles.labelLarge.copyWith(color: AppColors.secondaryNavy)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          CommonButton(label: 'Next', onPressed: () => Navigator.pop(context), height: 48),
        ],
      ),
    );
  }
}

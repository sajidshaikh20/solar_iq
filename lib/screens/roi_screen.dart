import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/text_styles.dart';
import '../common_widgets/common_textfield.dart';
import '../services/firebase_service.dart';

class RoiScreen extends StatefulWidget {
  const RoiScreen({super.key});

  @override
  State<RoiScreen> createState() => _RoiScreenState();
}

class _RoiScreenState extends State<RoiScreen> {
  final _investmentController = TextEditingController();
  final _dealRateController = TextEditingController();
  final _monthlyUnitsController = TextEditingController();
  final _unitRateController = TextEditingController(text: '8.00');
  final _fbService = FirebaseService();
  bool _isSaving = false;

  double? _monthlySaving;
  double? _remainingRecovery;
  double? _roiMonths;
  int? _paybackYear;

  @override
  void initState() {
    super.initState();
    _loadStoredData();
  }

  Future<void> _loadStoredData() async {
    // 1. Instantly load from local SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final localInv = prefs.getString('roi_investment');
      final localDeal = prefs.getString('roi_deal_rate');
      final localUnits = prefs.getString('roi_monthly_units');
      final localRate = prefs.getString('roi_unit_rate');

      if (mounted) {
        if (localInv != null && localInv.isNotEmpty) _investmentController.text = localInv;
        if (localDeal != null && localDeal.isNotEmpty) _dealRateController.text = localDeal;
        if (localUnits != null && localUnits.isNotEmpty) _monthlyUnitsController.text = localUnits;
        if (localRate != null && localRate.isNotEmpty) _unitRateController.text = localRate;

        if (_investmentController.text.isNotEmpty && _monthlyUnitsController.text.isNotEmpty) {
          _calculateSilently();
        }
      }
    } catch (_) {}

    // 2. Fetch from Firebase
    try {
      final roiData = await _fbService.getRoiDataStream().first.timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );

      if (mounted && roiData != null && roiData.isNotEmpty) {
        if (roiData['investment'] != null && (roiData['investment'] as num) > 0) {
          _investmentController.text = (roiData['investment'] as num).toStringAsFixed(0);
        }
        if (roiData['dealRate'] != null && (roiData['dealRate'] as num) > 0) {
          _dealRateController.text = (roiData['dealRate'] as num).toStringAsFixed(2);
        }
        if (roiData['monthlyUnits'] != null && (roiData['monthlyUnits'] as num) > 0) {
          _monthlyUnitsController.text = (roiData['monthlyUnits'] as num).toStringAsFixed(0);
        }
        if (roiData['unitRate'] != null && (roiData['unitRate'] as num) > 0) {
          _unitRateController.text = (roiData['unitRate'] as num).toStringAsFixed(2);
        }
        _calculateSilently();
        _saveToLocalStorage();
      }
    } catch (e) {
      // Fallback
    }
  }

  Future<void> _saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('roi_investment', _investmentController.text);
      await prefs.setString('roi_deal_rate', _dealRateController.text);
      await prefs.setString('roi_monthly_units', _monthlyUnitsController.text);
      await prefs.setString('roi_unit_rate', _unitRateController.text);
    } catch (_) {}
  }

  void _calculateSilently() {
    final investment = double.tryParse(_investmentController.text);
    final units = double.tryParse(_monthlyUnitsController.text);
    final unitRate = double.tryParse(_unitRateController.text);

    if (investment == null || units == null || unitRate == null) return;

    final saving = units * unitRate;
    final remaining = investment - saving;
    final roiMonths = investment / saving;
    final paybackYear = DateTime.now().year + (roiMonths / 12).ceil();

    setState(() {
      _monthlySaving = saving;
      _remainingRecovery = remaining.clamp(0, investment);
      _roiMonths = roiMonths;
      _paybackYear = paybackYear;
    });
  }

  @override
  void dispose() {
    _investmentController.dispose();
    _dealRateController.dispose();
    _monthlyUnitsController.dispose();
    _unitRateController.dispose();
    super.dispose();
  }

  void _calculate() {
    final investment = double.tryParse(_investmentController.text);
    final units = double.tryParse(_monthlyUnitsController.text);
    final unitRate = double.tryParse(_unitRateController.text);

    if (investment == null || units == null || unitRate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.')),
      );
      return;
    }

    final saving = units * unitRate;
    final remaining = investment - saving;
    final roiMonths = investment / saving;
    final paybackYear = DateTime.now().year + (roiMonths / 12).ceil();

    setState(() {
      _monthlySaving = saving;
      _remainingRecovery = remaining.clamp(0, investment);
      _roiMonths = roiMonths;
      _paybackYear = paybackYear;
    });

    _saveToLocalStorage();
    _saveRoiDataSilently();
  }

  Future<void> _saveRoiDataSilently() async {
    if (_monthlySaving == null) return;
    _saveToLocalStorage();
    final unitRate = double.tryParse(_unitRateController.text);
    if (unitRate != null) {
      try {
        await _fbService.saveElectricityRate(unitRate);
      } catch (_) {}
    }
    await _fbService.saveRoiData({
      'investment': double.tryParse(_investmentController.text) ?? 0,
      'dealRate': double.tryParse(_dealRateController.text) ?? 0,
      'monthlyUnits': double.tryParse(_monthlyUnitsController.text) ?? 0,
      'unitRate': unitRate ?? 8.0,
      'monthlySaving': _monthlySaving,
      'remainingRecovery': _remainingRecovery,
      'paybackPeriod': _roiMonths,
      'paybackYear': _paybackYear,
    });
  }

  Future<void> _saveRoiData() async {
    if (_monthlySaving == null) return;

    setState(() => _isSaving = true);
    _saveToLocalStorage();
    try {
      final unitRate = double.tryParse(_unitRateController.text);
      if (unitRate != null) {
        try {
          await _fbService.saveElectricityRate(unitRate);
        } catch (_) {}
      }
      final result = await _fbService.saveRoiData({
        'investment': double.tryParse(_investmentController.text) ?? 0,
        'dealRate': double.tryParse(_dealRateController.text) ?? 0,
        'monthlyUnits': double.tryParse(_monthlyUnitsController.text) ?? 0,
        'unitRate': unitRate ?? 8.0,
        'monthlySaving': _monthlySaving,
        'remainingRecovery': _remainingRecovery,
        'paybackPeriod': _roiMonths,
        'paybackYear': _paybackYear,
      });
      
      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ROI details saved globally!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving data: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('ROI & Investment Tracker'),
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
            if (_monthlySaving != null) _buildResultCard(),
            const SizedBox(height: 30),
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
                  color: const Color(0xFFE65100).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Color(0xFFE65100),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text('Investment Details', style: AppTextStyles.labelLarge),
            ],
          ),
          const SizedBox(height: 20),
          CommonTextField(
            label: 'Total Investment (₹)',
            hint: 'e.g. 300000',
            controller: _investmentController,
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
            label: 'Deal Rate (Optional)',
            hint: 'e.g. 5.5',
            controller: _dealRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          CommonTextField(
            label: 'Monthly Units (kWh)',
            hint: 'e.g. 350',
            controller: _monthlyUnitsController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          CommonTextField(
            label: 'Unit Rate (₹)',
            hint: 'e.g. 8',
            controller: _unitRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _calculate,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.primaryAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                  ),
                  child: Text(
                    'Auto-calc Saving',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primaryAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF1565C0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                  ),
                  child: Text(
                    'Live ROI Chart',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ),
              ),
            ],
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
          colors: [AppColors.primaryEmerald, AppColors.primaryMint],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE65100).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'ROI Summary',
                style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _roiTile(
                'Monthly Saving',
                '₹ ${_monthlySaving!.toStringAsFixed(0)}',
                Icons.savings_outlined,
              ),
              _roiTile(
                'Remaining Recovery',
                '₹ ${_remainingRecovery!.toStringAsFixed(0)}',
                Icons.account_balance_wallet_outlined,
              ),
              _roiTile(
                'Est. ROI',
                '${_roiMonths!.toStringAsFixed(1)} mo',
                Icons.timeline_rounded,
              ),
              _roiTile(
                'Payback Year',
                '$_paybackYear',
                Icons.event_available_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveRoiData,
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined, size: 18),
              label: Text(_isSaving ? 'Saving...' : 'Save to Dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roiTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTextStyles.labelLarge.copyWith(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white60,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

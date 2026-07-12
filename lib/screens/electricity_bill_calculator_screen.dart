import 'dart:async';
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

  StreamSubscription<Map<String, double>>? _dailyGenerationSubscription;
  Map<String, double> _dailyGenerationMap = {};
  bool _fetchFromDb = false;
  String _selectedPeriod = 'yesterday'; // 'yesterday', 'thisMonth', 'custom'
  DateTimeRange? _selectedDateRange;
  String? _dbRetrievalSummary;

  @override
  void initState() {
    super.initState();
    _loadCurrentTariff();
    _subscribeToDailyGeneration();
  }

  void _subscribeToDailyGeneration() {
    _dailyGenerationSubscription =
        _fbService.getDailyGenerationStream().listen((data) {
      if (mounted) {
        setState(() {
          _dailyGenerationMap = data;
        });
        if (_fetchFromDb) {
          _calculateFromDatabase();
        }
      }
    });
  }

  @override
  void dispose() {
    _previousReadingController.dispose();
    _currentReadingController.dispose();
    _tariffRateController.dispose();
    _dailyGenerationSubscription?.cancel();
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

  void _onModeChanged(bool fetchFromDb) {
    setState(() {
      _fetchFromDb = fetchFromDb;
      _errorMessage = null;
      _unitsConsumed = null;
      _totalBill = null;
      _dbRetrievalSummary = null;
      if (!fetchFromDb) {
        _currentReadingController.clear();
      } else {
        _calculateFromDatabase();
      }
    });
  }

  void _onPeriodChanged(String period) {
    setState(() {
      _selectedPeriod = period;
      _errorMessage = null;
      _unitsConsumed = null;
      _totalBill = null;
      _dbRetrievalSummary = null;
    });
    if (period == 'custom') {
      _selectCustomDateRange();
    } else {
      _calculateFromDatabase();
    }
  }

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryEmerald,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _calculateFromDatabase();
    }
  }

  void _calculateFromDatabase() {
    if (_dailyGenerationMap.isEmpty) {
      setState(() {
        _errorMessage = 'No daily generation data found in database.';
        _unitsConsumed = null;
        _totalBill = null;
        _dbRetrievalSummary = null;
      });
      return;
    }

    final DateTime now = DateTime.now();
    DateTime start;
    DateTime end;

    if (_selectedPeriod == 'yesterday') {
      end = now.subtract(const Duration(days: 1));
      start = end;
    } else if (_selectedPeriod == 'thisMonth') {
      start = DateTime(now.year, now.month, 1);
      end = now;
    } else {
      if (_selectedDateRange == null) {
        setState(() {
          _errorMessage = 'Please select a custom date range.';
          _unitsConsumed = null;
          _totalBill = null;
          _dbRetrievalSummary = null;
        });
        return;
      }
      start = _selectedDateRange!.start;
      end = _selectedDateRange!.end;
    }

    String formatDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    double getReadingOnOrBefore(DateTime target, {int maxDaysBack = 30}) {
      for (int i = 0; i <= maxDaysBack; i++) {
        final d = target.subtract(Duration(days: i));
        final key = formatDate(d);
        if (_dailyGenerationMap.containsKey(key)) {
          return _dailyGenerationMap[key] ?? 0.0;
        }
      }
      final sortedKeys = _dailyGenerationMap.keys.toList()..sort();
      final targetStr = formatDate(target);
      for (int i = sortedKeys.length - 1; i >= 0; i--) {
        if (sortedKeys[i].compareTo(targetStr) <= 0) {
          return _dailyGenerationMap[sortedKeys[i]] ?? 0.0;
        }
      }
      return 0.0;
    }

    final currentReading = getReadingOnOrBefore(end);
    final previousReading = getReadingOnOrBefore(start.subtract(const Duration(days: 1)));

    if (currentReading < previousReading) {
      setState(() {
        _errorMessage = 'Database current reading ($currentReading kWh) is less than previous reading ($previousReading kWh).';
        _unitsConsumed = null;
        _totalBill = null;
        _dbRetrievalSummary = null;
      });
      return;
    }

    final rate = double.tryParse(_tariffRateController.text) ?? 8.0;
    final units = currentReading - previousReading;
    final bill = units * rate;

    _previousReadingController.text = previousReading.toStringAsFixed(2);
    _currentReadingController.text = currentReading.toStringAsFixed(2);

    setState(() {
      _errorMessage = null;
      _unitsConsumed = units;
      _totalBill = bill;
      
      String periodText = '';
      if (_selectedPeriod == 'yesterday') {
        periodText = 'Yesterday';
      } else if (_selectedPeriod == 'thisMonth') {
        periodText = 'This Month';
      } else {
        periodText = 'Custom Range';
      }
      
      _dbRetrievalSummary = 'Fetched data for $periodText:\n'
          '• Previous reading: ${previousReading.toStringAsFixed(2)} kWh\n'
          '• Current reading: ${currentReading.toStringAsFixed(2)} kWh\n'
          '• Calculation: ${currentReading.toStringAsFixed(2)} - ${previousReading.toStringAsFixed(2)} = ${units.toStringAsFixed(2)} kWh';
    });
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
            if (_dbRetrievalSummary != null) _buildRetrievalSummaryCard(),
            if (_errorMessage != null) _buildErrorCard(),
            if (_unitsConsumed != null && _totalBill != null) _buildResultCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _onModeChanged(false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_fetchFromDb ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: !_fetchFromDb
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      size: 18,
                      color: !_fetchFromDb ? AppColors.primaryEmerald : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Manual Input',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: !_fetchFromDb ? FontWeight.bold : FontWeight.w500,
                        color: !_fetchFromDb ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _onModeChanged(true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _fetchFromDb ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: _fetchFromDb
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_download_rounded,
                      size: 18,
                      color: _fetchFromDb ? AppColors.primaryEmerald : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Database Data',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _fetchFromDb ? FontWeight.bold : FontWeight.w500,
                        color: _fetchFromDb ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final periods = [
      {'id': 'yesterday', 'label': 'Yesterday'},
      {'id': 'thisMonth', 'label': 'This Month'},
      {'id': 'custom', 'label': 'Custom Range'},
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Billing Period', style: AppTextStyles.labelMedium),
          const SizedBox(height: 10),
          Row(
            children: periods.map((p) {
              final isSelected = _selectedPeriod == p['id'];
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    showCheckmark: false,
                    avatar: p['id'] == 'custom' && _selectedPeriod == 'custom' && _selectedDateRange != null
                        ? const Icon(Icons.date_range_rounded, size: 14, color: AppColors.primaryEmerald)
                        : null,
                    label: Text(p['label']!),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) _onPeriodChanged(p['id']!);
                    },
                    selectedColor: AppColors.primaryMint.withOpacity(0.15),
                    backgroundColor: Colors.grey.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected ? AppColors.primaryEmerald : AppColors.borderColor,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: isSelected ? AppColors.primaryEmerald : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_selectedPeriod == 'custom' && _selectedDateRange != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _selectCustomDateRange,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryMint.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryMint.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit_calendar_rounded, size: 14, color: AppColors.primaryEmerald),
                    const SizedBox(width: 6),
                    Text(
                      'Selected: ${_formatDateShort(_selectedDateRange!.start)} - ${_formatDateShort(_selectedDateRange!.end)}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primaryEmerald,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateShort(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Widget _buildRetrievalSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.primaryMint.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppColors.primaryMint.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storage_rounded, color: AppColors.primaryEmerald, size: 18),
              const SizedBox(width: 8),
              Text(
                'Database Data Summary',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primaryEmerald,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _dbRetrievalSummary!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary.withOpacity(0.85),
              height: 1.5,
            ),
          ),
        ],
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
          _buildModeSelector(),
          if (_fetchFromDb) _buildPeriodSelector(),
          CommonTextField(
            label: 'Previous Meter Reading (kWh)',
            hint: 'e.g. 12450',
            controller: _previousReadingController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixIcon: const Icon(Icons.history_rounded, color: AppColors.primaryEmerald),
            enabled: !_fetchFromDb,
          ),
          const SizedBox(height: 16),
          CommonTextField(
            label: 'Current Meter Reading (kWh)',
            hint: 'e.g. 12575',
            controller: _currentReadingController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixIcon: const Icon(Icons.today_rounded, color: AppColors.primaryEmerald),
            enabled: !_fetchFromDb,
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
              label: _fetchFromDb ? 'Recalculate Bill' : 'Calculate Bill',
              icon: Icons.calculate_outlined,
              onPressed: _fetchFromDb ? _calculateFromDatabase : _calculate,
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

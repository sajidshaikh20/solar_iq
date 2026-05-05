import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/text_styles.dart';
import '../common_widgets/common_button.dart';

import '../services/firebase_service.dart';
import '../constants.dart';

class CleaningScreen extends StatefulWidget {
  const CleaningScreen({super.key});

  @override
  State<CleaningScreen> createState() => _CleaningScreenState();
}

class _CleaningScreenState extends State<CleaningScreen> {
  final FirebaseService _fbService = FirebaseService();

  bool _isRunning = false;
  int _timerMin = 2;
  int _scheduleDays = 7;

  final Set<String> _selectedDevices = {'Motor'};

  final _devices = ['Motor', 'Water Sprinkler', 'Wiper'];
  final _timerOptions = [1, 2, 3];
  final _scheduleOptions = [7, 15, 30];

  @override
  void initState() {
    super.initState();
    _listenToDatabase();
  }

  void _listenToDatabase() {
    _fbService.getDigitalOutputRef(AppConstants.washPin).onValue.listen((event) {
      if (event.snapshot.value != null) {
        final val = event.snapshot.value as bool;
        // DB value directly reflects UI state
        if (_isRunning != val) {
          setState(() => _isRunning = val);
        }
      }
    });
  }

  void _toggleClean(bool value) {
    setState(() => _isRunning = value);
    // UI value directly sent to DB (Running -> true)
    _fbService.getDigitalOutputRef(AppConstants.washPin).set(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Smart Cleaning & Wiping'),
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
                  _buildManualControl(),
                  const SizedBox(height: 16),
                  _buildTimerSection(),
                  const SizedBox(height: 16),
                  _buildScheduleSection(),
                  const SizedBox(height: 16),
                  _buildDeviceSelection(),
                  const SizedBox(height: 16),
                  _buildStatusCard(),
                ],
              ),
            ),
          ),
          _buildBottomButtons(context),
        ],
      ),
    );
  }

  Widget _buildManualControl() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Manual Control', Icons.touch_app_outlined, const Color(0xFF0277BD)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_isRunning ? 'Running' : 'Idle', style: AppTextStyles.headingSmall.copyWith(color: _isRunning ? const Color(0xFF2E7D32) : AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(_isRunning ? 'Cleaning in progress...' : 'System is standing by', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
                  ],
                ),
              ),
              _IosStyleSwitch(value: _isRunning, onChanged: _toggleClean),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimerSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Timer Auto Shutoff', Icons.timer_outlined, const Color(0xFF6A1B9A)),
          const SizedBox(height: 16),
          Row(
            children: _timerOptions.map((min) {
              final sel = _timerMin == min;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _PillButton(label: '$min min', selected: sel, color: const Color(0xFF6A1B9A), onTap: () => setState(() => _timerMin = min)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Scheduled Cleaning', Icons.event_repeat_rounded, const Color(0xFFE65100)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            children: _scheduleOptions.map((days) {
              final sel = _scheduleDays == days;
              return _PillButton(label: 'Every $days days', selected: sel, color: const Color(0xFFE65100), onTap: () => setState(() => _scheduleDays = days));
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceSelection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Device Selection', Icons.devices_other_rounded, AppColors.primaryEmerald),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: _devices.map((device) {
              final sel = _selectedDevices.contains(device);
              return GestureDetector(
                onTap: () => setState(() {
                  if (sel) {
                    _selectedDevices.remove(device);
                  } else {
                    _selectedDevices.add(device);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primaryEmerald : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? AppColors.primaryEmerald : AppColors.borderColor),
                    boxShadow: sel ? [BoxShadow(color: AppColors.primaryEmerald.withOpacity(0.3), blurRadius: 8)] : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sel) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.check_circle_rounded, size: 14, color: Colors.white)),
                      Text(device, style: AppTextStyles.caption.copyWith(color: sel ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0277BD).withOpacity(0.08), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(color: const Color(0xFF0277BD).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF0277BD), size: 18),
              const SizedBox(width: 8),
              Text('Device Status', style: AppTextStyles.labelLarge.copyWith(color: const Color(0xFF0277BD))),
            ],
          ),
          const SizedBox(height: 16),
          _statusRow('Cleaning State', _isRunning ? 'Running' : 'Idle', _isRunning ? const Color(0xFF2E7D32) : AppColors.textTertiary),
          const Divider(height: 20),
          _statusRow('Auto Timer', '$_timerMin min', AppColors.primaryEmerald),
          const Divider(height: 20),
          _statusRow('Schedule', 'Every $_scheduleDays days', const Color(0xFFE65100)),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: valueColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(value, style: AppTextStyles.caption.copyWith(color: valueColor, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(title, style: AppTextStyles.labelLarge),
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
                onPressed: () => _toggleClean(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge))),
                icon: const Icon(Icons.play_arrow_rounded, color: AppColors.secondaryNavy, size: 20),
                label: Text('Run Now', style: AppTextStyles.labelLarge.copyWith(color: AppColors.secondaryNavy)),
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

class _PillButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _PillButton({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : AppColors.borderColor),
        ),
        child: Text(label, style: AppTextStyles.caption.copyWith(color: selected ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _IosStyleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _IosStyleSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: Colors.white,
      activeTrackColor: const Color(0xFF2E7D32),
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: AppColors.borderColor,
      trackOutlineColor: WidgetStateColor.resolveWith((_) => Colors.transparent),
    );
  }
}

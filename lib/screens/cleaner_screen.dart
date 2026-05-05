import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_strings.dart';
import '../core/constants/app_spacing.dart';
import '../common_widgets/common_text.dart';
import '../common_widgets/common_card.dart';
import '../common_widgets/common_toggle.dart';

import '../services/firebase_service.dart';
import '../constants.dart';

class CleanerPageContent extends StatefulWidget {
  const CleanerPageContent({super.key});

  @override
  State<CleanerPageContent> createState() => _CleanerPageContentState();
}

class _CleanerPageContentState extends State<CleanerPageContent>
    with TickerProviderStateMixin {
  final FirebaseService _fbService = FirebaseService();

  bool _solarWashActive = false;
  bool _solarWiperActive = false;

  late AnimationController _washGlowCtrl;
  late AnimationController _wiperGlowCtrl;
  late Animation<double> _washGlow;
  late Animation<double> _wiperGlow;

  @override
  void initState() {
    super.initState();

    _washGlowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _wiperGlowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _washGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _washGlowCtrl, curve: Curves.easeInOut),
    );
    _wiperGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _wiperGlowCtrl, curve: Curves.easeInOut),
    );

    _listenToDatabase();
  }

  void _listenToDatabase() {
    _fbService.getDigitalOutputRef(AppConstants.washPin).onValue.listen((event) {
      if (event.snapshot.value != null) {
        final val = event.snapshot.value as bool;
        // DB value directly reflects UI state
        if (_solarWashActive != val) _updateWashState(val);
      }
    });

    _fbService.getDigitalOutputRef(AppConstants.wiperPin).onValue.listen((event) {
      if (event.snapshot.value != null) {
        final val = event.snapshot.value as bool;
        // DB value directly reflects UI state
        if (_solarWiperActive != val) _updateWiperState(val);
      }
    });
  }

  void _updateWashState(bool value) {
    setState(() => _solarWashActive = value);
    value ? _washGlowCtrl.forward() : _washGlowCtrl.reverse();
  }

  void _updateWiperState(bool value) {
    setState(() => _solarWiperActive = value);
    value ? _wiperGlowCtrl.forward() : _wiperGlowCtrl.reverse();
  }

  void _toggleWash(bool value) {
    // UI value directly sent to DB (ON -> true)
    _fbService.getDigitalOutputRef(AppConstants.washPin).set(value);
    _updateWashState(value);
  }

  void _toggleWiper(bool value) {
    // UI value directly sent to DB (ON -> true)
    _fbService.getDigitalOutputRef(AppConstants.wiperPin).set(value);
    _updateWiperState(value);
  }

  @override
  void dispose() {
    _washGlowCtrl.dispose();
    _wiperGlowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: _buildStatusBanner(),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _washGlow,
                  builder: (context, _) => _buildControlCard(
                    icon: Icons.water_drop_rounded,
                    title: AppStrings.solarWash,
                    subtitle: _solarWashActive
                        ? AppStrings.solarWashActive
                        : AppStrings.solarWashInactive,
                    isActive: _solarWashActive,
                    activeColor: AppColors.primaryEmerald,
                    glowAnim: _washGlow,
                    onChanged: _toggleWash,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AnimatedBuilder(
                  animation: _wiperGlow,
                  builder: (context, _) => _buildControlCard(
                    icon: Icons.wind_power_rounded,
                    title: AppStrings.solarWiper,
                    subtitle: _solarWiperActive
                        ? AppStrings.solarWiperActive
                        : AppStrings.solarWiperInactive,
                    isActive: _solarWiperActive,
                    activeColor: AppColors.primaryAccent,
                    glowAnim: _wiperGlow,
                    onChanged: _toggleWiper,
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner() {
    final anyActive = _solarWashActive || _solarWiperActive;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        color: anyActive
            ? AppColors.primaryEmerald.withOpacity(0.10)
            : Colors.white,
        border: Border.all(
          color: anyActive
              ? AppColors.primaryEmerald.withOpacity(0.3)
              : AppColors.borderColor,
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: anyActive
                  ? AppColors.primaryEmerald
                  : AppColors.textTertiary.withOpacity(0.3),
              boxShadow: anyActive
                  ? [
                      BoxShadow(
                        color: AppColors.primaryEmerald.withOpacity(0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
          ),
          const SizedBox(width: 10),
          CommonText(
            anyActive ? 'System Active' : 'All Systems Offline',
            variant: TextVariant.labelMedium,
            color: anyActive
                ? AppColors.primaryEmerald
                : AppColors.textSecondary.withOpacity(0.6),
          ),
        ],
      ),
    );
  }

  Widget _buildControlCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required Color activeColor,
    required Animation<double> glowAnim,
    required ValueChanged<bool> onChanged,
  }) {
    return CommonCard(
      isActive: isActive,
      activeColor: activeColor,
      shadows: isActive
          ? [
              BoxShadow(
                color: activeColor.withOpacity(0.15 * glowAnim.value),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ]
          : [],
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: isActive
                  ? activeColor.withOpacity(0.2)
                  : Colors.white,
              border: Border.all(
                color: isActive
                    ? activeColor.withOpacity(0.4)
                    : AppColors.borderColor,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? activeColor : AppColors.textTertiary.withOpacity(0.4),
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CommonText(
                  title,
                  variant: TextVariant.headingSmall,
                  color: isActive ? AppColors.textPrimary : AppColors.textPrimary.withOpacity(0.7),
                ),
                const SizedBox(height: 5),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: isActive
                      ? TextStyle(
                          fontSize: 13,
                          color: activeColor.withOpacity(0.85),
                          fontWeight: FontWeight.w400,
                        )
                      : TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary.withOpacity(0.5),
                          fontWeight: FontWeight.w400,
                        ),
                  child: Text(subtitle),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CommonToggleSwitch(
            value: isActive,
            onChanged: onChanged,
            activeColor: activeColor,
          ),
        ],
      ),
    );
  }
}

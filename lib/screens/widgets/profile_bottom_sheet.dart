import 'package:flutter/material.dart';
import 'package:solar_iq/screens/notification_screen.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_spacing.dart';
import '../../common_widgets/common_text.dart';
import '../../common_widgets/common_button.dart';
import '../../common_widgets/common_textfield.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';
import '../../models/user_model.dart';

class ProfileBottomSheet extends StatefulWidget {
  const ProfileBottomSheet({super.key});

  @override
  State<ProfileBottomSheet> createState() => _ProfileBottomSheetState();
}

class _ProfileBottomSheetState extends State<ProfileBottomSheet> {
  bool _isEditing = false;
  bool _isSaving = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _capacityController = TextEditingController();
  final _roleLabelController = TextEditingController();
  final _authService = AuthService();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _capacityController.dispose();
    _roleLabelController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty) return;
    
    setState(() => _isSaving = true);
    try {
      final result = await _authService.updateUserProfile({
        'name': _nameController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
        'plantCapacity': _capacityController.text,
        'userRoleLabel': _roleLabelController.text,
      });
      if (mounted) {
        if (result.success) {
          setState(() => _isEditing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${result.error}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: _authService.userProfileStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = snapshot.data;
        if (!_isEditing && user != null) {
          _nameController.text = user.name;
          _phoneController.text = user.phone;
          _addressController.text = user.address;
          _capacityController.text = user.plantCapacity;
          _roleLabelController.text = user.userRoleLabel;
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusXXLarge),
                ),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                children: [
                  _buildHandle(),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildAvatar(user?.name ?? 'U'),
                          const SizedBox(height: 20),
                          _buildNameSection(user?.name ?? 'User', user?.userRoleLabel ?? 'Solar Plant Owner'),
                          const SizedBox(height: AppSpacing.xl),
                          _isEditing ? _buildEditForm(user?.email ?? '') : _buildProfileInfo(user),
                          const SizedBox(height: AppSpacing.lg),
                          _buildActionButton(),
                          const SizedBox(height: AppSpacing.xl),
                          _buildSettingsList(),
                          const SizedBox(height: AppSpacing.lg),
                          _buildLogoutButton(),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.textTertiary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildAvatar(String name) {
    final initials = name.isNotEmpty 
      ? name.substring(0, name.contains(' ') ? 2 : 1).toUpperCase()
      : 'U';
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryMint.withOpacity(0.4),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: AppColors.secondaryNavy,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        if (_isEditing)
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.backgroundCard,
              border: Border.all(color: AppColors.primaryMint, width: 1.5),
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              color: AppColors.primaryEmerald,
              size: 14,
            ),
          ),
      ],
    );
  }

  Widget _buildNameSection(String name, String roleLabel) {
    return Column(
      children: [
        CommonText(name, variant: TextVariant.headingMedium),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: AppColors.primaryMint.withOpacity(0.12),
            border: Border.all(color: AppColors.primaryMint.withOpacity(0.3)),
          ),
          child: CommonText(
            roleLabel,
            variant: TextVariant.caption,
            color: AppColors.primaryEmerald,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfo(UserModel? user) {
    return Column(
      children: [
        _buildInfoTile(
          Icons.email_outlined,
          AppStrings.emailLabel,
          user?.email ?? 'Not set',
        ),
        const SizedBox(height: 12),
        _buildInfoTile(
          Icons.phone_outlined,
          AppStrings.phoneLabel,
          user?.phone ?? 'Not set',
        ),
        const SizedBox(height: 12),
        _buildInfoTile(
          Icons.location_on_outlined,
          'Address',
          user?.address.isEmpty ?? true ? 'Not set' : user!.address,
        ),
        const SizedBox(height: 12),
        _buildInfoTile(Icons.solar_power_outlined, 'Plant Capacity', user?.plantCapacity ?? '10 kWp'),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        color: Colors.white,
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.primaryMint.withOpacity(0.12),
            ),
            child: Icon(icon, color: AppColors.primaryEmerald, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CommonText(
                  label,
                  variant: TextVariant.caption,
                  color: AppColors.textSecondary.withOpacity(0.6),
                ),
                const SizedBox(height: 2),
                CommonText(value, variant: TextVariant.labelLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm(String email) {
    return Column(
      children: [
        CommonTextField(
          label: AppStrings.fullNameLabel,
          hint: AppStrings.fullNameHint,
          controller: _nameController,
          prefixIcon: const Icon(
            Icons.person_outline_rounded,
            color: AppColors.primaryEmerald,
            size: 20,
          ),
        ),
        const SizedBox(height: 16),
        CommonTextField(
          label: AppStrings.emailLabel,
          hint: AppStrings.emailHint,
          controller: TextEditingController(text: email),
          enabled: false,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const Icon(
            Icons.email_outlined,
            color: AppColors.primaryEmerald,
            size: 20,
          ),
        ),
        const SizedBox(height: 16),
        CommonTextField(
          label: AppStrings.phoneLabel,
          hint: AppStrings.phoneHint,
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          prefixIcon: const Icon(
            Icons.phone_outlined,
            color: AppColors.primaryEmerald,
            size: 20,
          ),
        ),
        CommonTextField(
          label: 'Address',
          hint: 'Enter your address',
          controller: _addressController,
          prefixIcon: const Icon(
            Icons.location_on_outlined,
            color: AppColors.primaryEmerald,
            size: 20,
          ),
        ),
        const SizedBox(height: 16),
        CommonTextField(
          label: 'Plant Capacity',
          hint: 'e.g. 10 kWp',
          controller: _capacityController,
          prefixIcon: const Icon(
            Icons.solar_power_outlined,
            color: AppColors.primaryEmerald,
            size: 20,
          ),
        ),
        const SizedBox(height: 16),
        CommonTextField(
          label: 'Role Label',
          hint: 'e.g. Solar Plant Owner',
          controller: _roleLabelController,
          prefixIcon: const Icon(
            Icons.label_outline_rounded,
            color: AppColors.primaryEmerald,
            size: 20,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _isEditing = false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  ),
                ),
                child: Text(
                  AppStrings.cancel,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CommonButton(
                label: _isSaving ? 'Saving...' : AppStrings.saveChanges,
                height: 50,
                onPressed: _isSaving ? null : _saveProfile,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    if (_isEditing) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => setState(() => _isEditing = true),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(
            color: AppColors.primaryMint.withOpacity(0.5),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
        ),
        icon: const Icon(
          Icons.edit_rounded,
          color: AppColors.primaryEmerald,
          size: 18,
        ),
        label: Text(
          AppStrings.editProfile,
          style: AppTextStyles.labelLarge.copyWith(
            color: AppColors.primaryEmerald,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsList() {
    final items = [
      _SettingItem(
        Icons.notifications_outlined,
        AppStrings.notificationSettings,
        AppColors.primaryMint,
      ),
      _SettingItem(
        Icons.lock_outline_rounded,
        AppStrings.securitySettings,
        AppColors.primaryEmerald,
      ),
      _SettingItem(
        Icons.help_outline_rounded,
        AppStrings.helpSupport,
        AppColors.textTertiary.withOpacity(0.6),
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        color: Colors.white,
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          return Column(
            children: [
              _buildSettingTile(items[index]),
              if (index < items.length - 1)
                Divider(
                  color: AppColors.borderColor.withOpacity(0.5),
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSettingTile(_SettingItem item) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (item.label == AppStrings.notificationSettings) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationScreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${item.label} coming soon!'), backgroundColor: AppColors.primaryEmerald),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: item.color.withOpacity(0.12),
              ),
              child: Icon(item.icon, color: item.color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: CommonText(item.label, variant: TextVariant.labelLarge),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary.withOpacity(0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _handleLogout,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(
            color: Colors.redAccent.withOpacity(0.4),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
        ),
        icon: Icon(
          Icons.logout_rounded,
          color: Colors.redAccent.withOpacity(0.7),
          size: 18,
        ),
        label: Text(
          AppStrings.logout,
          style: AppTextStyles.labelLarge.copyWith(
            color: Colors.redAccent.withOpacity(0.7),
          ),
        ),
      ),
    );
  }
}

class _SettingItem {
  final IconData icon;
  final String label;
  final Color color;
  const _SettingItem(this.icon, this.label, this.color);
}

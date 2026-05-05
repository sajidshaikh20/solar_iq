import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../core/theme/text_styles.dart';
import '../core/constants/app_strings.dart';
import '../core/constants/app_spacing.dart';
import '../common_widgets/common_text.dart';
import '../common_widgets/common_button.dart';
import '../common_widgets/common_textfield.dart';
import '../common_widgets/common_card.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();
  
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      final result = await _authService.registerUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created successfully! Please login.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Registration failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildRegisterCard(),
                  const SizedBox(height: 28),
                  _buildLoginLink(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryMint.withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -60,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryEmerald.withOpacity(0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white,
              border: Border.all(color: AppColors.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary,
              size: 16,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CommonText(
              AppStrings.registerTitle,
              variant: TextVariant.headingMedium,
              color: AppColors.secondaryNavy,
            ),
            const SizedBox(height: 2),
            CommonText(
              AppStrings.registerSubtitle,
              variant: TextVariant.bodySmall,
              color: AppColors.textSecondary.withOpacity(0.7),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegisterCard() {
    return CommonCard(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            CommonTextField(
              label: AppStrings.fullNameLabel,
              hint: AppStrings.fullNameHint,
              controller: _nameController,
              prefixIcon: Icon(Icons.person_outline_rounded,
                  color: AppColors.textTertiary.withOpacity(0.5), size: 20),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Full name is required';
                if (v.length < 3) return 'Name too short';
                return null;
              },
            ),
            const SizedBox(height: 18),
            CommonTextField(
              label: AppStrings.emailLabel,
              hint: AppStrings.emailHint,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icon(Icons.email_outlined,
                  color: AppColors.textTertiary.withOpacity(0.5), size: 20),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email is required';
                if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                    .hasMatch(v)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            CommonTextField(
              label: AppStrings.phoneLabel,
              hint: AppStrings.phoneHint,
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              prefixIcon: Icon(Icons.phone_outlined,
                  color: AppColors.textTertiary.withOpacity(0.5), size: 20),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Phone is required';
                if (v.length < 10) return 'Enter a valid phone number';
                return null;
              },
            ),
            const SizedBox(height: 18),
            CommonTextField(
              label: AppStrings.passwordLabel,
              hint: AppStrings.passwordHint,
              controller: _passwordController,
              obscureText: _obscurePassword,
              prefixIcon: Icon(Icons.lock_outline_rounded,
                  color: AppColors.textTertiary.withOpacity(0.5), size: 20),
              suffixIcon: GestureDetector(
                onTap: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                child: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textTertiary.withOpacity(0.5),
                  size: 20,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 6) return 'Minimum 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 18),
            CommonTextField(
              label: AppStrings.confirmPasswordLabel,
              hint: AppStrings.confirmPasswordHint,
              controller: _confirmController,
              obscureText: _obscureConfirm,
              prefixIcon: Icon(Icons.lock_outline_rounded,
                  color: AppColors.textTertiary.withOpacity(0.5), size: 20),
              suffixIcon: GestureDetector(
                onTap: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                child: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textTertiary.withOpacity(0.5),
                  size: 20,
                ),
              ),
              validator: (v) {
                if (v != _passwordController.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 28),
            CommonButton(
              label: AppStrings.createAccount,
              onPressed: _handleRegister,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CommonText(
          AppStrings.alreadyHaveAccount,
          variant: TextVariant.bodyMedium,
          color: AppColors.textSecondary.withOpacity(0.7),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Text(
            AppStrings.loginLink,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.primaryAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/text_styles.dart';
import '../common_widgets/common_button.dart';
import '../common_widgets/common_textfield.dart';
import '../services/firebase_service.dart';

class QueryScreen extends StatefulWidget {
  const QueryScreen({super.key});

  @override
  State<QueryScreen> createState() => _QueryScreenState();
}

class _QueryScreenState extends State<QueryScreen> {
  final _fbService = FirebaseService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedCategory = 'Technical';
  bool _submitted = false;
  bool _isLoading = false;

  final _categories = ['Technical', 'Billing', 'Installation', 'Maintenance', 'Other'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in Name and Message.')),
      );
      return;
    }
    
    setState(() => _isLoading = true);

    final result = await _fbService.submitQuery({
      'name': _nameController.text,
      'email': _emailController.text,
      'phone': _phoneController.text,
      'category': _selectedCategory,
      'subject': _subjectController.text,
      'message': _messageController.text,
    });
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (result.success) {
        setState(() => _submitted = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${result.error}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Query Page'),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderColor),
        ),
      ),
      body: _submitted ? _buildSuccessView() : _buildFormView(),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildFormCard(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF6A1B9A).withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(color: const Color(0xFF6A1B9A).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: const Color(0xFF6A1B9A).withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.help_outline_rounded, color: Color(0xFF6A1B9A), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Submit a Query', style: AppTextStyles.headingSmall.copyWith(color: const Color(0xFF6A1B9A))),
                const SizedBox(height: 4),
                Text('We\'ll get back to you within 24 hours', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommonTextField(label: 'Your Name', hint: 'Full name', controller: _nameController),
          const SizedBox(height: 16),
          CommonTextField(label: 'Email Address', hint: 'email@example.com', controller: _emailController, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          CommonTextField(label: 'Phone Number', hint: '+91 XXXXX XXXXX', controller: _phoneController, keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          Text('Category', style: AppTextStyles.labelMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final sel = _selectedCategory == _categories[i];
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = _categories[i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFF6A1B9A) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? const Color(0xFF6A1B9A) : AppColors.borderColor),
                    ),
                    child: Text(_categories[i], style: AppTextStyles.caption.copyWith(color: sel ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          CommonTextField(label: 'Subject', hint: 'Brief subject', controller: _subjectController),
          const SizedBox(height: 16),
          CommonTextField(label: 'Message', hint: 'Describe your issue...', controller: _messageController, maxLines: 4),
          const SizedBox(height: 24),
          CommonButton(
            label: 'Submit Query',
            icon: Icons.send_rounded,
            onPressed: _isLoading ? () {} : _submit,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(color: const Color(0xFF2E7D32).withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF2E7D32), size: 56),
            ),
            const SizedBox(height: 24),
            Text('Query Submitted!', style: AppTextStyles.headingMedium.copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Text("We've received your query and will respond within 24 hours.", textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 32),
            CommonButton(label: 'Submit Another', onPressed: () => setState(() => _submitted = false)),
          ],
        ),
      ),
    );
  }
}

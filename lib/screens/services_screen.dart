import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/text_styles.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  Future<void> _launchWhatsAppService(BuildContext context, String serviceTitle, String serviceSubtitle) async {
    final message = "Hello Solar IQ Team,\n\nI would like to request *${serviceTitle}* (${serviceSubtitle}) for my solar panel installation.\n\nPlease share details and get in touch with me.";
    final encodedMsg = Uri.encodeComponent(message);
    final whatsappUrl = Uri.parse("https://wa.me/?text=$encodedMsg");

    try {
      if (!await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open WhatsApp.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening WhatsApp: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = [
      _ServiceItem(
        icon: Icons.water_drop_outlined,
        title: 'Cleaning',
        subtitle: 'Panel cleaning service',
        color: const Color(0xFF0277BD),
      ),
      _ServiceItem(
        icon: Icons.build_outlined,
        title: 'Maintenance',
        subtitle: 'Preventive maintenance',
        color: const Color(0xFF2E7D32),
      ),
      _ServiceItem(
        icon: Icons.settings_remote_outlined,
        title: 'Install Auto Wiper & Sprinkler',
        subtitle: 'Automation kit installation',
        color: const Color(0xFF6A1B9A),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Services'),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            ...services.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ServiceCard(
                item: s,
                onTap: () => _launchWhatsAppService(context, s.title, s.subtitle),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.build_circle_outlined, color: Color(0xFF2E7D32), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Our Services', style: AppTextStyles.headingSmall.copyWith(color: const Color(0xFF2E7D32))),
                const SizedBox(height: 4),
                Text('Tap any service to request directly via WhatsApp', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _ServiceItem({required this.icon, required this.title, required this.subtitle, required this.color});
}

class _ServiceCard extends StatelessWidget {
  final _ServiceItem item;
  final VoidCallback onTap;
  const _ServiceCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          border: Border.all(color: AppColors.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: item.color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(item.subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 14),
                  SizedBox(width: 4),
                  Text(
                    'WhatsApp',
                    style: TextStyle(
                      color: Color(0xFF25D366),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

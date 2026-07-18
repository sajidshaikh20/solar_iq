import '../../services/firebase_service.dart';
import '../../models/notification_model.dart';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_spacing.dart';
import '../../common_widgets/common_text.dart';
import '../../common_widgets/common_appbar.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseService _fbService = FirebaseService();

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24)
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  void _markAllRead() {
    _fbService.markAllNotificationsAsRead();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: StreamBuilder<List<NotificationModel>>(
              stream: _fbService.getNotificationsStream(),
              builder: (context, snapshot) {
                final notifications = snapshot.data ?? [];
                final unreadCount = notifications
                    .where((n) => !n.isRead)
                    .length;

                return Column(
                  children: [
                    CommonAppBar(
                      title: AppStrings.notificationsTitle,
                      subtitle: AppStrings.notificationSubtitle,
                      showBack: true,
                      actions: [
                        if (unreadCount > 0)
                          GestureDetector(
                            onTap: _markAllRead,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: AppColors.primaryAccent.withOpacity(
                                  0.12,
                                ),
                                border: Border.all(
                                  color: AppColors.primaryAccent.withOpacity(
                                    0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.done_all_rounded,
                                    color: AppColors.primaryAccent,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  CommonText(
                                    AppStrings.markAllRead,
                                    variant: TextVariant.caption,
                                    color: AppColors.primaryAccent,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
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
                            child: Icon(
                              Icons.notifications_outlined,
                              color: AppColors.textPrimary.withOpacity(0.65),
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (unreadCount > 0) _buildUnreadBadge(unreadCount),
                    if (unreadCount > 0) const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: notifications.isEmpty
                          ? _buildEmptyState()
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                              ),
                              itemCount: notifications.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) =>
                                  _buildNotificationCard(notifications[index]),
                            ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.backgroundGradient,
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryAccent.withOpacity(0.09),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnreadBadge(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          color: AppColors.primaryAccent.withOpacity(0.10),
          border: Border.all(color: AppColors.primaryAccent.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryEmerald,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryEmerald.withOpacity(0.6),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            CommonText(
              '$count unread notification${count > 1 ? 's' : ''}',
              variant: TextVariant.labelMedium,
              color: AppColors.primaryEmerald,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel item) {
    return GestureDetector(
      onTap: () => _fbService.markNotificationAsRead(item.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          color: item.isRead ? Colors.white : item.type.color.withOpacity(0.06),
          border: Border.all(
            color: item.isRead
                ? AppColors.borderColor
                : item.type.color.withOpacity(0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: item.isRead
                  ? Colors.black.withOpacity(0.02)
                  : item.type.color.withOpacity(0.08),
              blurRadius: item.isRead ? 6 : 16,
              spreadRadius: item.isRead ? 0 : 1,
              offset: item.isRead ? const Offset(0, 2) : Offset.zero,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: item.type.color.withOpacity(0.15),
                border: Border.all(color: item.type.color.withOpacity(0.3)),
              ),
              child: Icon(item.type.icon, color: item.type.color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CommonText(
                          item.title,
                          variant: TextVariant.labelLarge,
                          color: item.isRead
                              ? AppColors.textPrimary.withOpacity(0.7)
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: item.type.color,
                            boxShadow: [
                              BoxShadow(
                                color: item.type.color.withOpacity(0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  CommonText(
                    item.body,
                    variant: TextVariant.bodySmall,
                    color: AppColors.textSecondary.withOpacity(
                      item.isRead ? 0.45 : 0.7,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  CommonText(
                    _formatTime(item.timestamp),
                    variant: TextVariant.caption,
                    color: item.isRead
                        ? AppColors.textTertiary.withOpacity(0.4)
                        : item.type.color.withOpacity(0.8),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
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
            child: Icon(
              Icons.notifications_off_outlined,
              color: AppColors.textTertiary.withOpacity(0.35),
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          CommonText(
            AppStrings.noNotifications,
            variant: TextVariant.headingSmall,
            color: AppColors.textTertiary.withOpacity(0.6),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../core/theme/colors.dart';

import '../core/theme/app_theme.dart';
import '../core/constants/app_strings.dart';
import '../common_widgets/common_appbar.dart';
import '../common_widgets/common_bottom_nav.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'home_screen.dart';
import 'cleaner_screen.dart';
import 'generation_screen.dart';
import 'notification_screen.dart';
import 'widgets/profile_bottom_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentNav = 0;
  String? _userName;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final result = await _authService.getCurrentUserProfile();
    if (mounted && result.success) {
      setState(() => _userName = result.data?.name);
    }
  }

  final List<String> _titles = [
    'Home',
    AppStrings.generationTracking,
    'System Control',
  ];

  List<String> get _subtitles => [
    _userName != null ? 'Welcome, $_userName 👋' : 'Manage your solar system',
    AppStrings.generationSubtitle,
    AppStrings.controlPanelTitle,
  ];

  void _onNavTap(int index) {
    if (index == 3) {
      _showProfile();
      return;
    }
    setState(() => _currentNav = index);
  }

  void _showProfile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ProfileBottomSheet(),
    );
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          _buildBackground(),
          StreamBuilder<UserModel?>(
            stream: _authService.userProfileStream,
            builder: (context, snapshot) {
              final user = snapshot.data;
              final name = user?.name;
              _userName = name; // Update internal state for HomePageContent

              return SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    CommonAppBar(
                      title: _titles[_currentNav],
                      subtitle: _currentNav == 0 
                        ? (name != null ? 'Welcome, $name 👋' : 'Welcome 👋')
                        : _subtitles[_currentNav],
                      actions: [
                        GestureDetector(
                          onTap: _openNotifications,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusMedium),
                                  color: Colors.white,
                                  border:
                                      Border.all(color: AppColors.borderColor),
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
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primaryEmerald,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            AppColors.primaryEmerald.withOpacity(0.6),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: _currentNav,
                        children: [
                          HomePageContent(userName: name),
                          const GenerationPageContent(),
                          const CleanerPageContent(),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CommonBottomNavBar(
              currentIndex: _currentNav,
              onTap: _onNavTap,
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
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryAccent.withOpacity(0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
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
    );
  }
}


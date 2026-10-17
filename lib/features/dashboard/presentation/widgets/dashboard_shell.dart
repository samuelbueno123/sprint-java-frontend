import 'package:flutter/material.dart';

import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/user_profile_type.dart';
import 'admin_dashboard_view.dart';
import 'dashboard_sidebar.dart';
import 'dashboard_top_bar.dart';
import 'student_dashboard_view.dart';
import 'teacher_dashboard_view.dart';
import 'user_dashboard_view.dart';
import 'learning_features.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({
    super.key,
    required this.data,
    required this.activeSection,
    required this.onSectionSelected,
    required this.onLogout,
    required this.onRefresh,
    required this.onProfileTypeSelected,
  });

  final DashboardData data;
  final String activeSection;
  final ValueChanged<String> onSectionSelected;
  final VoidCallback onLogout;
  final VoidCallback onRefresh;
  final ValueChanged<UserProfileType> onProfileTypeSelected;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSidebarExpanded = true;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasNavigationRail = constraints.maxWidth >= 768;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: DashboardTopBar(
            data: widget.data,
            onLogout: widget.onLogout,
            onOpenSettings: () => widget.onSectionSelected('settings'),
            onProfileTypeChanged: widget.onProfileTypeSelected,
            onOpenNotifications:
                widget.data.availableProfileTypes.contains(
                  UserProfileType.admin,
                )
                ? () {
                    widget.onProfileTypeSelected(UserProfileType.admin);
                    widget.onSectionSelected('notifications');
                  }
                : null,
            onMenuPressed: () {
              if (hasNavigationRail) {
                setState(() => _isSidebarExpanded = !_isSidebarExpanded);
              } else {
                _scaffoldKey.currentState?.openDrawer();
              }
            },
          ),
          drawer: hasNavigationRail
              ? null
              : Drawer(
                  child: SafeArea(
                    child: DashboardSidebar(
                      profileType: widget.data.profileType,
                      activeSection: widget.activeSection,
                      isSuperAdmin: widget.data.user.isSuperAdmin,
                      unreadNotificationsCount:
                          widget.data.unreadNotificationsCount,
                      onSectionSelected: (section) {
                        widget.onSectionSelected(section);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ),
          body: Row(
            children: [
              if (hasNavigationRail)
                DashboardSidebar(
                  profileType: widget.data.profileType,
                  activeSection: widget.activeSection,
                  onSectionSelected: widget.onSectionSelected,
                  isCollapsed: !_isSidebarExpanded,
                  isSuperAdmin: widget.data.user.isSuperAdmin,
                  unreadNotificationsCount:
                      widget.data.unreadNotificationsCount,
                ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: widget.data.profileType == UserProfileType.admin
                          ? 1440
                          : 1200,
                    ),
                    child: _buildMainContent(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent() {
    switch (widget.data.profileType) {
      case UserProfileType.student:
        if (widget.activeSection == 'classes') {
          return StudentClassesView(
            data: widget.data,
            onRefresh: widget.onRefresh,
          );
        }
        if (const {
          'lesson',
          'history',
          'achievements',
          'ranking',
          'groupRanking',
        }.contains(widget.activeSection)) {
          return LearningFeaturePage(
            section: widget.activeSection,
            onBackToProfile: () => widget.onSectionSelected('profile'),
          );
        }
        return StudentDashboardView(
          data: widget.data,
          activeSection: widget.activeSection,
          onSectionSelected: widget.onSectionSelected,
          onLogout: widget.onLogout,
          onRefresh: widget.onRefresh,
        );
      case UserProfileType.teacher:
        if (widget.activeSection == 'classes') {
          return TeacherClassManagementView(
            data: widget.data,
            onRefresh: widget.onRefresh,
          );
        }
        if (const {
          'manageExercises',
          'createExercise',
          'reviewExercises',
          'teacherRanking',
        }.contains(widget.activeSection)) {
          return TeacherLearningPage(
            data: widget.data,
            section: widget.activeSection,
            onSectionSelected: widget.onSectionSelected,
          );
        }
        return TeacherDashboardView(
          data: widget.data,
          activeSection: widget.activeSection,
          onSectionSelected: widget.onSectionSelected,
          onLogout: widget.onLogout,
          onRefresh: widget.onRefresh,
        );
      case UserProfileType.admin:
        return AdminDashboardView(
          data: widget.data,
          activeSection: widget.activeSection,
          onSectionSelected: widget.onSectionSelected,
          onLogout: widget.onLogout,
          onRefresh: widget.onRefresh,
        );
      case UserProfileType.user:
        return UserDashboardView(
          data: widget.data,
          activeSection: widget.activeSection,
          onSectionSelected: widget.onSectionSelected,
          onLogout: widget.onLogout,
          onRefresh: widget.onRefresh,
        );
    }
  }
}

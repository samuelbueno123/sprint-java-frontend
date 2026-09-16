import 'package:flutter/material.dart';

import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/user_profile_type.dart';
import 'dashboard_sidebar.dart';
import 'dashboard_top_bar.dart';
import 'student_dashboard_view.dart';
import 'teacher_dashboard_view.dart';
import 'user_dashboard_view.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({
    super.key,
    required this.data,
    required this.activeSection,
    required this.onSectionSelected,
    required this.onLogout,
  });

  final DashboardData data;
  final String activeSection;
  final ValueChanged<String> onSectionSelected;
  final VoidCallback onLogout;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: const Color(0xFFF7F9FA),
          appBar: DashboardTopBar(
            data: widget.data,
            onLogout: widget.onLogout,
            isDesktop: isDesktop,
            onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          drawer: isDesktop
              ? null
              : Drawer(
                  child: SafeArea(
                    child: DashboardSidebar(
                      profileType: widget.data.profileType,
                      activeSection: widget.activeSection,
                      onSectionSelected: (section) {
                        widget.onSectionSelected(section);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ),
          body: Row(
            children: [
              if (isDesktop)
                DashboardSidebar(
                  profileType: widget.data.profileType,
                  activeSection: widget.activeSection,
                  onSectionSelected: widget.onSectionSelected,
                ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
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
        return StudentDashboardView(
          data: widget.data,
          activeSection: widget.activeSection,
        );
      case UserProfileType.teacher:
        return TeacherDashboardView(
          data: widget.data,
          activeSection: widget.activeSection,
        );
      case UserProfileType.user:
        return UserDashboardView(
          data: widget.data,
          activeSection: widget.activeSection,
        );
    }
  }
}

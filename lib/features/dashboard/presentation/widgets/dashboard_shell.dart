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
import 'advanced_learning/srs_review_view.dart';
import 'advanced_learning/ai_conversation_view.dart';
import 'advanced_learning/pronunciation_practice_view.dart';
import 'advanced_learning/community_peer_review_view.dart';
import 'advanced_learning/personalized_learning_path_view.dart';
import 'advanced_learning/student_mistakes_view.dart';
import 'advanced_learning/student_vocabulary_view.dart';
import 'advanced_learning/teacher_class_analytics_view.dart';
import 'advanced_learning/student_notifications_dialog.dart';

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

  int _calculateMobileNavIndex() {
    if (widget.data.profileType == UserProfileType.student) {
      switch (widget.activeSection) {
        case 'profile':
          return 0;
        case 'classes':
          return 1;
        case 'srsReview':
          return 2;
        case 'vocabulary':
          return 3;
        default:
          return 4; // Menu / Outros
      }
    } else if (widget.data.profileType == UserProfileType.teacher) {
      switch (widget.activeSection) {
        case 'profile':
          return 0;
        case 'classes':
          return 1;
        case 'classAnalytics':
          return 2;
        case 'manageExercises':
          return 3;
        default:
          return 4; // Menu / Outros
      }
    }
    return 0;
  }

  void _onMobileNavTapped(int index) {
    if (widget.data.profileType == UserProfileType.student) {
      switch (index) {
        case 0:
          widget.onSectionSelected('profile');
          break;
        case 1:
          widget.onSectionSelected('classes');
          break;
        case 2:
          widget.onSectionSelected('srsReview');
          break;
        case 3:
          widget.onSectionSelected('vocabulary');
          break;
        case 4:
          _scaffoldKey.currentState?.openDrawer();
          break;
      }
    } else if (widget.data.profileType == UserProfileType.teacher) {
      switch (index) {
        case 0:
          widget.onSectionSelected('profile');
          break;
        case 1:
          widget.onSectionSelected('classes');
          break;
        case 2:
          widget.onSectionSelected('classAnalytics');
          break;
        case 3:
          widget.onSectionSelected('manageExercises');
          break;
        case 4:
          _scaffoldKey.currentState?.openDrawer();
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasNavigationRail = constraints.maxWidth >= 768;
        final isMobile = !hasNavigationRail;
        final mobileIndex = _calculateMobileNavIndex();

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: DashboardTopBar(
            data: widget.data,
            onLogout: widget.onLogout,
            onOpenSettings: () => widget.onSectionSelected('settings'),
            onProfileTypeChanged: widget.onProfileTypeSelected,
            onOpenNotifications: () {
              if (widget.data.profileType == UserProfileType.student) {
                StudentNotificationsDialog.show(context);
              } else if (widget.data.availableProfileTypes.contains(
                UserProfileType.admin,
              )) {
                widget.onProfileTypeSelected(UserProfileType.admin);
                widget.onSectionSelected('notifications');
              }
            },
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
          bottomNavigationBar:
              isMobile &&
                  (widget.data.profileType == UserProfileType.student ||
                      widget.data.profileType == UserProfileType.teacher)
              ? NavigationBar(
                  selectedIndex: mobileIndex.clamp(0, 4),
                  onDestinationSelected: _onMobileNavTapped,
                  elevation: 4,
                  height: 64,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations:
                      widget.data.profileType == UserProfileType.student
                      ? const [
                          NavigationDestination(
                            icon: Icon(Icons.home_outlined),
                            selectedIcon: Icon(Icons.home_rounded),
                            label: 'Início',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.school_outlined),
                            selectedIcon: Icon(Icons.school_rounded),
                            label: 'Turmas',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.psychology_outlined),
                            selectedIcon: Icon(Icons.psychology_rounded),
                            label: 'Prática',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.menu_book_outlined),
                            selectedIcon: Icon(Icons.menu_book_rounded),
                            label: 'Vocabulário',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.widgets_outlined),
                            selectedIcon: Icon(Icons.widgets_rounded),
                            label: 'Mais',
                          ),
                        ]
                      : const [
                          NavigationDestination(
                            icon: Icon(Icons.dashboard_outlined),
                            selectedIcon: Icon(Icons.dashboard_rounded),
                            label: 'Início',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.groups_outlined),
                            selectedIcon: Icon(Icons.groups_rounded),
                            label: 'Turmas',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.insights_outlined),
                            selectedIcon: Icon(Icons.insights_rounded),
                            label: 'Analytics',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.assignment_outlined),
                            selectedIcon: Icon(Icons.assignment_rounded),
                            label: 'Atividades',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.widgets_outlined),
                            selectedIcon: Icon(Icons.widgets_rounded),
                            label: 'Mais',
                          ),
                        ],
                )
              : null,
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
                child: SizedBox.expand(
                  child: reduceMotion
                      ? _buildMainContent()
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.02),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey(
                              '${widget.data.profileType}_${widget.activeSection}',
                            ),
                            child: _buildMainContent(),
                          ),
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
            onSectionSelected: widget.onSectionSelected,
          );
        }
        if (widget.activeSection == 'srsReview') {
          return SrsReviewView(
            onBack: () => widget.onSectionSelected('profile'),
          );
        }
        if (widget.activeSection == 'aiConversation') {
          return AiConversationView(
            onBack: () => widget.onSectionSelected('profile'),
          );
        }
        if (widget.activeSection == 'pronunciation') {
          return PronunciationPracticeView(
            onBack: () => widget.onSectionSelected('profile'),
          );
        }
        if (widget.activeSection == 'communityReview') {
          return CommunityPeerReviewView(
            onBack: () => widget.onSectionSelected('profile'),
          );
        }
        if (widget.activeSection == 'learningPath') {
          return PersonalizedLearningPathView(
            onBack: () => widget.onSectionSelected('profile'),
          );
        }
        if (widget.activeSection == 'mistakes') {
          return StudentMistakesView(
            onBack: () => widget.onSectionSelected('profile'),
          );
        }
        if (widget.activeSection == 'vocabulary') {
          return StudentVocabularyView(
            onBack: () => widget.onSectionSelected('profile'),
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
        if (widget.activeSection == 'classAnalytics') {
          return TeacherClassAnalyticsView(
            data: widget.data,
            onBack: () => widget.onSectionSelected('profile'),
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

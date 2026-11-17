import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/audio/system_sound_service.dart';
import '../../../../core/constants/supported_languages.dart';
import '../../../../core/network/realtime_sync_service.dart';
import '../../../../core/ui/mascot/mascot.dart';
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
    this.canGoBack = false,
    this.onGoBack,
  });

  final DashboardData data;
  final String activeSection;
  final ValueChanged<String> onSectionSelected;
  final VoidCallback onLogout;
  final VoidCallback onRefresh;
  final ValueChanged<UserProfileType> onProfileTypeSelected;
  final bool canGoBack;
  final VoidCallback? onGoBack;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSidebarExpanded = true;
  StreamSubscription<RealtimeSyncEvent>? _realtimeSubscription;
  Timer? _announcementDismissTimer;
  Map<String, dynamic>? _liveAnnouncement;

  @override
  void initState() {
    super.initState();
    _scheduleMascotSync();
    _realtimeSubscription = RealtimeSyncService.instance.events.listen(
      _handleRealtimeEvent,
    );
  }

  @override
  void didUpdateWidget(covariant DashboardShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeSection != widget.activeSection ||
        oldWidget.data.profileType != widget.data.profileType ||
        oldWidget.data.studentProfile != widget.data.studentProfile ||
        oldWidget.data.teacherProfile != widget.data.teacherProfile ||
        oldWidget.data.studentEnrollments != widget.data.studentEnrollments ||
        oldWidget.data.teacherAssignments != widget.data.teacherAssignments) {
      _scheduleMascotSync();
    }
  }

  @override
  void dispose() {
    _announcementDismissTimer?.cancel();
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  String _resolvePreferredLanguage() {
    final studentLangs = widget.data.studentProfile?.languages;
    if (studentLangs != null && studentLangs.isNotEmpty) {
      return SupportedLanguages.normalizeOrDefault(studentLangs.first);
    }
    if (widget.data.studentEnrollments.isNotEmpty) {
      return widget.data.studentEnrollments.first.resolvedLanguage;
    }
    final teacherLangs = widget.data.teacherProfile?.taughtLanguages;
    if (teacherLangs != null && teacherLangs.isNotEmpty) {
      return SupportedLanguages.normalizeOrDefault(teacherLangs.first);
    }
    if (widget.data.teacherAssignments.isNotEmpty) {
      return widget.data.teacherAssignments.first.resolvedLanguage;
    }
    return kDefaultSupportedLanguage;
  }

  void _scheduleMascotSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      MascotController.instance.setSessionActive(true);
      MascotController.instance.updateNavigationContext(
        section: widget.activeSection,
        userRole: widget.data.profileType.name,
        languageCode: _resolvePreferredLanguage(),
      );
    });
  }

  void _handleLogoutPressed() {
    MascotController.instance.setSessionActive(false);
    widget.onLogout();
  }

  void _handleRealtimeEvent(RealtimeSyncEvent event) {
    if (!mounted) return;
    if (event.type == 'CLASS_ANNOUNCEMENT') {
      SystemSoundService.notification();
      final data = event.data;
      _announcementDismissTimer?.cancel();
      setState(() {
        _liveAnnouncement = {
          'title': data['title']?.toString().trim().isNotEmpty == true
              ? data['title'].toString()
              : 'Novo aviso no mural da turma',
          'content': data['content']?.toString() ?? '',
          'className': data['className']?.toString() ?? '',
          'teacherName': data['teacherName']?.toString() ?? 'Professor(a)',
        };
      });
      _announcementDismissTimer = Timer(const Duration(seconds: 8), () {
        if (mounted) {
          setState(() => _liveAnnouncement = null);
        }
      });
    } else if (event.type == 'TEACHER_NOTE_ADDED' ||
        event.type == 'CLASS_INVITED') {
      SystemSoundService.notification();
    }
  }

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
    SystemSoundService.transition();
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
          resizeToAvoidBottomInset: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: DashboardTopBar(
            data: widget.data,
            onLogout: _handleLogoutPressed,
            onOpenSettings: () {
              SystemSoundService.transition();
              widget.onSectionSelected('settings');
            },
            onProfileTypeChanged: widget.onProfileTypeSelected,
            onOpenNotifications: () {
              SystemSoundService.notification();
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
              SystemSoundService.click();
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
                        SystemSoundService.transition();
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
                child: Column(
                  children: [
                    if (widget.canGoBack && widget.onGoBack != null)
                      _SectionBackHeader(
                        sectionLabel: _labelForSection(widget.activeSection),
                        onBack: () {
                          SystemSoundService.click();
                          widget.onGoBack!();
                        },
                      ),
                    if (_liveAnnouncement != null)
                      _TemporaryAnnouncementBanner(
                        title: _liveAnnouncement!['title']?.toString() ?? '',
                        content:
                            _liveAnnouncement!['content']?.toString() ?? '',
                        className:
                            _liveAnnouncement!['className']?.toString() ?? '',
                        teacherName:
                            _liveAnnouncement!['teacherName']?.toString() ?? '',
                        onDismiss: () {
                          _announcementDismissTimer?.cancel();
                          setState(() => _liveAnnouncement = null);
                        },
                        onViewClasses:
                            widget.data.profileType == UserProfileType.student
                            ? () {
                                _announcementDismissTimer?.cancel();
                                setState(() => _liveAnnouncement = null);
                                widget.onSectionSelected('classes');
                              }
                            : null,
                      ),
                    Expanded(
                      child: SizedBox.expand(
                        child: reduceMotion
                            ? _buildMainContent()
                            : AnimatedSwitcher(
                                duration: const Duration(milliseconds: 280),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) {
                                  final curved = CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOutCubic,
                                  );
                                  return FadeTransition(
                                    opacity: curved,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0.015, 0.025),
                                        end: Offset.zero,
                                      ).animate(curved),
                                      child: ScaleTransition(
                                        scale: Tween<double>(
                                          begin: 0.985,
                                          end: 1.0,
                                        ).animate(curved),
                                        child: child,
                                      ),
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
              ),
            ],
          ),
        );
      },
    );
  }

  String _labelForSection(String section) {
    return switch (section) {
      'classes' => 'Turmas',
      'srsReview' => 'Revisão Espaçada (SRS)',
      'aiConversation' => 'Conversação Interativa com IA',
      'pronunciation' => 'Prática de Pronúncia',
      'communityReview' => 'Correção Colaborativa & Comunidade',
      'learningPath' => 'Trilha Personalizada',
      'mistakes' => 'Caderno de Erros',
      'vocabulary' => 'Banco de Vocabulário',
      'lesson' => 'Atividades & Lições',
      'history' => 'Histórico de Desempenho',
      'achievements' => 'Conquistas',
      'ranking' => 'Ranking Geral',
      'groupRanking' => 'Ranking por Turma',
      'classAnalytics' => 'Analytics da Turma',
      'manageExercises' => 'Gerenciar Atividades',
      'createExercise' => 'Criar Atividade',
      'reviewExercises' => 'Corrigir Envios',
      'teacherRanking' => 'Ranking Docente',
      'settings' => 'Configurações',
      'users' => 'Banco de Dados',
      'institutions' => 'Instituições & ADMs',
      'studentAchievements' => 'Conquistas dos Alunos',
      'auditLogs' => 'Logs & Auditoria',
      'performance' => 'Performance',
      'systemHealth' => 'Saúde do Sistema',
      'catalog' => 'Catálogo & Idiomas',
      'teacherDocs' => 'Documentos Docentes',
      'notifications' => 'Notificações',
      _ => 'Painel',
    };
  }

  Widget _buildMainContent() {
    final backCallback =
        widget.onGoBack ?? () => widget.onSectionSelected('profile');
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
          return SrsReviewView(onBack: backCallback);
        }
        if (widget.activeSection == 'aiConversation') {
          return AiConversationView(onBack: backCallback);
        }
        if (widget.activeSection == 'pronunciation') {
          return PronunciationPracticeView(onBack: backCallback);
        }
        if (widget.activeSection == 'communityReview') {
          return CommunityPeerReviewView(onBack: backCallback);
        }
        if (widget.activeSection == 'learningPath') {
          return PersonalizedLearningPathView(onBack: backCallback);
        }
        if (widget.activeSection == 'mistakes') {
          return StudentMistakesView(onBack: backCallback);
        }
        if (widget.activeSection == 'vocabulary') {
          return StudentVocabularyView(onBack: backCallback);
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
            onBackToProfile: backCallback,
          );
        }
        return StudentDashboardView(
          data: widget.data,
          activeSection: widget.activeSection,
          onSectionSelected: widget.onSectionSelected,
          onLogout: _handleLogoutPressed,
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
            onBack: backCallback,
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
          onLogout: _handleLogoutPressed,
          onRefresh: widget.onRefresh,
        );
      case UserProfileType.admin:
        return AdminDashboardView(
          data: widget.data,
          activeSection: widget.activeSection,
          onSectionSelected: widget.onSectionSelected,
          onLogout: _handleLogoutPressed,
          onRefresh: widget.onRefresh,
        );
      case UserProfileType.user:
        return UserDashboardView(
          data: widget.data,
          activeSection: widget.activeSection,
          onSectionSelected: widget.onSectionSelected,
          onLogout: _handleLogoutPressed,
          onRefresh: widget.onRefresh,
        );
    }
  }
}

class _SectionBackHeader extends StatelessWidget {
  const _SectionBackHeader({required this.sectionLabel, required this.onBack});

  final String sectionLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF15192B) : const Color(0xFFF8FAFC),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.25),
            ),
          ),
        ),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text(
                'Voltar',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                sectionLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemporaryAnnouncementBanner extends StatelessWidget {
  const _TemporaryAnnouncementBanner({
    required this.title,
    required this.content,
    required this.className,
    required this.teacherName,
    required this.onDismiss,
    this.onViewClasses,
  });

  final String title;
  final String content;
  final String className;
  final String teacherName;
  final VoidCallback onDismiss;
  final VoidCallback? onViewClasses;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(14),
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.55),
              width: 1.3,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MascotPoseEmblem(state: MascotState.clickBleat, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      className.isNotEmpty
                          ? '$title • $className ($teacherName)'
                          : '$title ($teacherName)',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                      ),
                    ),
                    if (content.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF312E81),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onViewClasses != null)
                TextButton(onPressed: onViewClasses, child: const Text('Ver')),
              IconButton(
                tooltip: 'Fechar aviso',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

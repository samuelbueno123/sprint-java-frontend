import 'dart:async';

import 'package:flutter/material.dart';

import '../../audio/system_sound_service.dart';
import '../motion_kit.dart';
import 'mascot_assets.dart';
import 'mascot_chat_service.dart';
import 'mascot_preference_controller.dart';

@immutable
class MascotActivityContext {
  const MascotActivityContext({
    required this.token,
    this.activityId,
    required this.title,
    this.mascotHelpMessage,
    this.isCompleted = false,
  });

  final Object token;
  final String? activityId;
  final String title;
  final String? mascotHelpMessage;
  final bool isCompleted;

  MascotActivityContext copyWith({
    String? mascotHelpMessage,
    bool clearMascotHelpMessage = false,
    bool? isCompleted,
  }) {
    return MascotActivityContext(
      token: token,
      activityId: activityId,
      title: title,
      mascotHelpMessage: clearMascotHelpMessage
          ? null
          : (mascotHelpMessage ?? this.mascotHelpMessage),
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class MascotController extends ChangeNotifier {
  MascotController._();

  static final MascotController instance = MascotController._();

  static const double mascotDisplaySize = 112.0;
  static const Duration holdThreshold = Duration(milliseconds: 200);
  static const double dragSlopPx = 8.0;

  static const List<MascotState> _clickCycleOrder = [
    MascotState.clickPoke,
    MascotState.clickBleat,
    MascotState.clickShake,
    MascotState.clickSpin,
    MascotState.clickHeart,
  ];

  bool _isSessionActive = false;
  String _currentSection = 'home';
  String _currentUserRole = 'student';
  String _currentLanguage = 'Inglês';

  final List<MascotActivityContext> _activityStack = [];

  Offset _position = Offset.zero;
  bool _hasInitializedPosition = false;
  Offset _velocity = Offset.zero;
  bool _isHeld = false;
  bool _isDragging = false;
  MascotState _activeState = MascotState.idle;
  int? _maxFramesOverride;
  int _clickIndex = 0;

  bool _isChatOpen = false;
  final List<MascotChatMessage> _chatMessages = [];
  bool _isChatSending = false;
  String? _chatError;
  MascotChatService? _chatServiceOverride;

  DateTime? _lastWallSplatAt;
  Timer? _safetyOneShotTimer;

  bool get isSessionActive => _isSessionActive;
  String get currentSection => _currentSection;
  String get currentUserRole => _currentUserRole;
  String get currentLanguage => _currentLanguage;

  MascotActivityContext? get currentActivity =>
      _activityStack.isEmpty ? null : _activityStack.last;
  bool get isInActivity => _activityStack.isNotEmpty;
  bool get isActivityCompleted => currentActivity?.isCompleted == true;

  Offset get position => _position;
  bool get hasInitializedPosition => _hasInitializedPosition;
  Offset get velocity => _velocity;
  bool get isHeld => _isHeld;
  bool get isDragging => _isDragging;
  MascotState get activeState => _activeState;
  int? get maxFramesOverride => _maxFramesOverride;

  bool get isChatOpen => _isChatOpen;
  List<MascotChatMessage> get chatMessages => List.unmodifiable(_chatMessages);
  bool get isChatSending => _isChatSending;
  String? get chatError => _chatError;

  MascotState get restingState {
    if (isActivityCompleted ||
        MascotPreferenceController.variant.value == MascotVariant.fire) {
      return MascotState.fireLoop;
    }
    return MascotState.idle;
  }

  void setSessionActive(bool active) {
    if (_isSessionActive == active) return;
    _isSessionActive = active;
    if (!active) {
      _clearSessionState();
    }
    notifyListeners();
  }

  void updateNavigationContext({
    String? section,
    String? userRole,
    String? languageCode,
  }) {
    var changed = false;
    if (section != null && section.isNotEmpty && section != _currentSection) {
      _currentSection = section;
      changed = true;
    }
    if (userRole != null &&
        userRole.isNotEmpty &&
        userRole != _currentUserRole) {
      _currentUserRole = userRole;
      changed = true;
    }
    if (languageCode != null &&
        languageCode.isNotEmpty &&
        languageCode != _currentLanguage) {
      _currentLanguage = languageCode;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  Object enterActivity({
    String? activityId,
    required String title,
    String? mascotHelpMessage,
    bool isCompleted = false,
  }) {
    final token = Object();
    final trimmedHelp = mascotHelpMessage?.trim();
    _activityStack.add(
      MascotActivityContext(
        token: token,
        activityId: activityId,
        title: title,
        mascotHelpMessage: (trimmedHelp == null || trimmedHelp.isEmpty)
            ? null
            : trimmedHelp,
        isCompleted: isCompleted,
      ),
    );
    _safetyOneShotTimer?.cancel();
    _isChatOpen = false;
    _maxFramesOverride = null;
    if (!_isHeld && !_isDragging) {
      _activeState = restingState;
    }
    notifyListeners();
    return token;
  }

  void updateActivityContext(
    Object token, {
    String? mascotHelpMessage,
    bool clearMascotHelpMessage = false,
    bool? isCompleted,
  }) {
    final idx = _activityStack.indexWhere((e) => identical(e.token, token));
    if (idx == -1) return;
    final cleanHelp = mascotHelpMessage?.trim();
    final shouldClearHelp =
        clearMascotHelpMessage ||
        (mascotHelpMessage != null && (cleanHelp == null || cleanHelp.isEmpty));
    _activityStack[idx] = _activityStack[idx].copyWith(
      mascotHelpMessage: shouldClearHelp ? null : cleanHelp,
      clearMascotHelpMessage: shouldClearHelp,
      isCompleted: isCompleted,
    );
    if (!_isHeld && !_isDragging && isCompleted == false) {
      _safetyOneShotTimer?.cancel();
      _maxFramesOverride = null;
      _activeState = restingState;
    }
    notifyListeners();
  }

  void exitActivity(Object token) {
    final idx = _activityStack.indexWhere((e) => identical(e.token, token));
    if (idx == -1) return;
    _activityStack.removeAt(idx);
    _safetyOneShotTimer?.cancel();
    _isChatOpen = false;
    _maxFramesOverride = null;
    if (!_isHeld && !_isDragging) {
      _activeState = restingState;
    }
    notifyListeners();
  }

  void markActivityCompleted(Object token) {
    final idx = _activityStack.indexWhere((e) => identical(e.token, token));
    if (idx == -1) return;
    if (_activityStack[idx].isCompleted &&
        (_activeState == MascotState.fireLoop ||
            (_activeState == MascotState.intense &&
                _maxFramesOverride == 19))) {
      return;
    }
    _activityStack[idx] = _activityStack[idx].copyWith(isCompleted: true);
    _isHeld = false;
    _isDragging = false;
    _activeState = MascotState.intense;
    _maxFramesOverride = 19;
    SystemSoundService.fire();
    _scheduleSafetyOneShotGuard(frames: 19);
    notifyListeners();
  }

  void reactCorrect() {
    if (_isHeld || _isDragging) return;
    _maxFramesOverride = null;
    _activeState = MascotState.celebrate;
    SystemSoundService.success();
    _scheduleSafetyOneShotGuard(
      frames: MascotAssets.specFor(MascotState.celebrate).frameCount,
    );
    notifyListeners();
  }

  void reactIncorrect() {
    if (_isHeld || _isDragging) return;
    _maxFramesOverride = null;
    _activeState = MascotState.sad;
    SystemSoundService.defeat();
    _scheduleSafetyOneShotGuard(
      frames: MascotAssets.specFor(MascotState.sad).frameCount,
    );
    notifyListeners();
  }

  void triggerClickReaction() {
    if (_isHeld || _isDragging) return;
    final next = _clickCycleOrder[_clickIndex % _clickCycleOrder.length];
    _clickIndex++;
    _maxFramesOverride = null;
    _activeState = next;
    final spec = MascotAssets.specFor(next);
    if (spec.sfx != null) {
      SystemSoundService.play(spec.sfx!);
    }
    _scheduleSafetyOneShotGuard(frames: spec.frameCount);
    notifyListeners();
  }

  void handleShortTap() {
    triggerClickReaction();
    toggleChat();
  }

  void toggleChat() {
    _isChatOpen = !_isChatOpen;
    _chatError = null;
    notifyListeners();
  }

  void closeChat() {
    if (!_isChatOpen) return;
    _isChatOpen = false;
    notifyListeners();
  }

  void onOneShotFinished() {
    _safetyOneShotTimer?.cancel();
    if (_isHeld || _isDragging) return;
    if (_activeState == MascotState.intense && isActivityCompleted) {
      _maxFramesOverride = null;
      _activeState = MascotState.fireLoop;
      notifyListeners();
      return;
    }
    final spec = MascotAssets.specFor(_activeState);
    if (!spec.loop) {
      _maxFramesOverride = null;
      _activeState = restingState;
      notifyListeners();
    }
  }

  void initializePositionIfNeeded(Offset initialOffset) {
    if (_hasInitializedPosition) return;
    _position = initialOffset;
    _hasInitializedPosition = true;
  }

  void setPosition(Offset next, {bool notify = true}) {
    _position = next;
    _hasInitializedPosition = true;
    if (notify) notifyListeners();
  }

  void setVelocity(Offset next, {bool notify = false}) {
    _velocity = next;
    if (notify) notifyListeners();
  }

  void beginHold() {
    _safetyOneShotTimer?.cancel();
    _maxFramesOverride = null;
    _isChatOpen = false;
    _isHeld = true;
    _isDragging = false;
    _velocity = Offset.zero;
    _activeState = MascotState.holdGrab;
    SystemSoundService.pop();
    notifyListeners();
  }

  void setDragState(MascotState dragState) {
    _safetyOneShotTimer?.cancel();
    _maxFramesOverride = null;
    _isChatOpen = false;
    _isHeld = false;
    _isDragging = true;
    if (_activeState != dragState) {
      _activeState = dragState;
      notifyListeners();
    }
  }

  void endHoldOrDrag({bool settleToRest = true}) {
    _isHeld = false;
    _isDragging = false;
    if (settleToRest) {
      _velocity = Offset.zero;
      if (!MascotAssets.wallHitStates.contains(_activeState)) {
        _maxFramesOverride = null;
        _activeState = restingState;
      }
    }
    notifyListeners();
  }

  void triggerWallHit(MascotState wallHitState) {
    final now = DateTime.now();
    final canSplat =
        _lastWallSplatAt == null ||
        now.difference(_lastWallSplatAt!) >= const Duration(milliseconds: 250);
    if (canSplat) {
      _lastWallSplatAt = now;
      SystemSoundService.splat();
    }
    _maxFramesOverride = null;
    _activeState = wallHitState;
    _scheduleSafetyOneShotGuard(
      frames: MascotAssets.specFor(wallHitState).frameCount,
    );
    notifyListeners();
  }

  Future<void> sendChatMessage(
    String rawText, {
    MascotChatService? chatService,
  }) async {
    final clean = rawText.trim();
    if (clean.isEmpty || _isChatSending) return;

    final historyBefore = List<MascotChatMessage>.from(_chatMessages);
    _chatMessages.add(
      MascotChatMessage(
        role: 'user',
        content: clean,
        timestamp: DateTime.now(),
      ),
    );
    _isChatSending = true;
    _chatError = null;
    notifyListeners();

    try {
      final service =
          chatService ?? _chatServiceOverride ?? MascotChatService();
      final reply = await service.sendMessage(
        message: clean,
        activeSection: _currentSection,
        userRole: _currentUserRole,
        currentLanguage: _currentLanguage,
        history: historyBefore,
      );
      _chatMessages.add(
        MascotChatMessage(
          role: 'assistant',
          content: reply.reply.isEmpty
              ? 'Como posso te ajudar a usar o Duolinfo hoje?'
              : reply.reply,
          inScope: reply.inScope,
          suggestedAction: reply.suggestedAction,
          timestamp: DateTime.now(),
        ),
      );
      SystemSoundService.notification();
    } catch (_) {
      _chatError =
          'Não foi possível falar com o Bode IA no momento. Verifique sua conexão e tente novamente.';
      SystemSoundService.defeat();
    } finally {
      _isChatSending = false;
      notifyListeners();
    }
  }

  void _scheduleSafetyOneShotGuard({required int frames}) {
    _safetyOneShotTimer?.cancel();
    if (isWidgetTestEnvironment) return;
    final fps = MascotPreferenceController.targetFps.value.clamp(4, 36);
    final ms = ((frames / fps) * 1000).round() + 260;
    _safetyOneShotTimer = Timer(Duration(milliseconds: ms), onOneShotFinished);
  }

  void _clearSessionState() {
    _safetyOneShotTimer?.cancel();
    _activityStack.clear();
    _isChatOpen = false;
    _chatMessages.clear();
    _isChatSending = false;
    _chatError = null;
    _isHeld = false;
    _isDragging = false;
    _velocity = Offset.zero;
    _hasInitializedPosition = false;
    _maxFramesOverride = null;
    _activeState = restingState;
    _lastWallSplatAt = null;
  }

  @visibleForTesting
  void setChatServiceForTest(MascotChatService? service) {
    _chatServiceOverride = service;
  }

  @visibleForTesting
  void resetForTest() {
    _isSessionActive = false;
    _currentSection = 'home';
    _currentUserRole = 'student';
    _currentLanguage = 'Inglês';
    _clickIndex = 0;
    _chatServiceOverride = null;
    _clearSessionState();
    _activeState = MascotState.idle;
    notifyListeners();
  }
}

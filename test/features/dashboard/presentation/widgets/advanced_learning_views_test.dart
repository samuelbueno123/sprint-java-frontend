import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/dashboard/domain/entities/user_profile_type.dart';
import 'package:frontend/features/dashboard/presentation/widgets/dashboard_sidebar.dart';
import 'package:frontend/features/dashboard/presentation/widgets/advanced_learning/srs_review_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/advanced_learning/ai_conversation_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/advanced_learning/pronunciation_practice_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/advanced_learning/community_peer_review_view.dart';
import 'package:frontend/features/dashboard/presentation/widgets/advanced_learning/personalized_learning_path_view.dart';

void main() {
  testWidgets('DashboardSidebar renders all 5 new advanced learning menu items for students', (tester) async {
    String? selectedSection;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardSidebar(
            profileType: UserProfileType.student,
            activeSection: 'profile',
            onSectionSelected: (s) => selectedSection = s,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Revisão Espaçada'), findsOneWidget);
    expect(find.text('Conversação IA'), findsOneWidget);
    expect(find.text('Prática Oral'), findsOneWidget);
    expect(find.text('Comunidade & Pares'), findsOneWidget);
    expect(find.text('Trilha Personalizada'), findsOneWidget);

    await tester.tap(find.text('Revisão Espaçada'));
    expect(selectedSection, equals('srsReview'));

    await tester.tap(find.text('Conversação IA'));
    expect(selectedSection, equals('aiConversation'));

    await tester.tap(find.text('Prática Oral'));
    expect(selectedSection, equals('pronunciation'));

    await tester.tap(find.text('Comunidade & Pares'));
    expect(selectedSection, equals('communityReview'));

    await tester.tap(find.text('Trilha Personalizada'));
    expect(selectedSection, equals('learningPath'));
  });

  testWidgets('SrsReviewView renders gracefully', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SrsReviewView(onBack: () {}),
          ),
        ),
      );
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.byType(SrsReviewView), findsOneWidget);
    });
  });

  testWidgets('AiConversationView renders gracefully', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiConversationView(onBack: () {}),
          ),
        ),
      );
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.byType(AiConversationView), findsOneWidget);
    });
  });

  testWidgets('PronunciationPracticeView renders gracefully', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PronunciationPracticeView(onBack: () {}),
          ),
        ),
      );
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.byType(PronunciationPracticeView), findsOneWidget);
    });
  });

  testWidgets('CommunityPeerReviewView renders gracefully', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityPeerReviewView(onBack: () {}),
          ),
        ),
      );
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.byType(CommunityPeerReviewView), findsOneWidget);
    });
  });

  testWidgets('PersonalizedLearningPathView renders gracefully', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PersonalizedLearningPathView(onBack: () {}),
          ),
        ),
      );
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.byType(PersonalizedLearningPathView), findsOneWidget);
    });
  });
}

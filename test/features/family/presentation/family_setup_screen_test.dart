import 'package:dongine/features/family/data/family_preferences.dart';
import 'package:dongine/features/family/data/family_repository.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/family/presentation/family_setup_screen.dart';
import 'package:dongine/shared/models/family_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _testSession = FamilySessionUser(
  uid: 'test-uid',
  email: 'test@example.com',
  displayName: 'Test User',
);

class _FakeFamilyRepository extends Fake implements FamilyRepository {
  _FakeFamilyRepository({this.families = const []});

  final List<FamilyModel> families;
  FamilyModel? createdFamily;
  FamilyModel? joinedFamily;

  @override
  Future<List<FamilyModel>> getUserFamilies(String uid) async => families;

  @override
  Future<FamilyModel> createFamily(
    String name,
    String creatorUid,
    String creatorName,
  ) async {
    final f = FamilyModel(
      id: 'new-family-id',
      name: name,
      createdBy: creatorUid,
      memberIds: [creatorUid],
      inviteCode: 'ABC123',
      inviteExpiresAt: DateTime.now().add(const Duration(days: 7)),
      createdAt: DateTime.now(),
    );
    createdFamily = f;
    return f;
  }

  @override
  Future<FamilyModel> joinFamily(
    String inviteCode,
    String uid,
    String nickname,
  ) async {
    final f = FamilyModel(
      id: 'joined-family-id',
      name: '참가한 가족',
      createdBy: 'other-uid',
      memberIds: ['other-uid', uid],
      inviteCode: inviteCode,
      createdAt: DateTime.now(),
    );
    joinedFamily = f;
    return f;
  }
}

class _FakeFamilyPreferences extends Fake implements FamilyPreferences {
  String? _selectedId;

  @override
  Future<String?> getSelectedFamilyId() async => _selectedId;

  @override
  Future<void> setSelectedFamilyId(String familyId) async {
    _selectedId = familyId;
  }

  @override
  Future<void> clearSelectedFamilyId() async {
    _selectedId = null;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

bool _navigatedToHome = false;

Widget _buildTestApp({
  required List<Override> overrides,
}) {
  _navigatedToHome = false;
  final router = GoRouter(
    initialLocation: '/family-setup',
    routes: [
      GoRoute(
        path: '/family-setup',
        builder: (context, state) => const FamilySetupScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          _navigatedToHome = true;
          return const Scaffold(body: Text('home-stub'));
        },
      ),
    ],
  );

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: router),
  );
}

List<Override> _baseOverrides({
  List<FamilyModel> families = const [],
  _FakeFamilyRepository? repo,
  bool loggedIn = true,
}) {
  return [
    familySessionUserProvider.overrideWithValue(
      loggedIn ? _testSession : null,
    ),
    familyRepositoryProvider.overrideWithValue(
      repo ?? _FakeFamilyRepository(families: families),
    ),
    familyPreferencesProvider.overrideWithValue(_FakeFamilyPreferences()),
  ];
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FamilySetupScreen – 초기 UI', () {
    testWidgets('두 버튼("새 가족 만들기", "초대 코드로 참가하기")이 표시된다', (tester) async {
      await tester.pumpWidget(_buildTestApp(overrides: _baseOverrides()));
      await tester.pumpAndSettle();

      expect(find.text('새 가족 만들기'), findsOneWidget);
      expect(find.text('초대 코드로 참가하기'), findsOneWidget);
    });

    testWidgets('헤더 텍스트와 아이콘이 표시된다', (tester) async {
      await tester.pumpWidget(_buildTestApp(overrides: _baseOverrides()));
      await tester.pumpAndSettle();

      expect(find.text('환영합니다!'), findsOneWidget);
      expect(find.text('마지막 단계: 가족 그룹 설정'), findsOneWidget);
      expect(find.byIcon(Icons.family_restroom), findsOneWidget);
    });
  });

  group('FamilySetupScreen – 버튼 탭 다이얼로그', () {
    testWidgets('"새 가족 만들기" 탭 시 생성 다이얼로그가 열린다', (tester) async {
      await tester.pumpWidget(_buildTestApp(overrides: _baseOverrides()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('새 가족 만들기'));
      await tester.pumpAndSettle();

      // 다이얼로그 제목 및 입력 필드 확인
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('새 가족 만들기'),
        ),
        findsOneWidget,
      );
      expect(find.text('가족 이름'), findsOneWidget);
      expect(find.text('만들기'), findsOneWidget);
      expect(find.text('취소'), findsOneWidget);
    });

    testWidgets('"초대 코드로 참가하기" 탭 시 참가 다이얼로그가 열린다', (tester) async {
      await tester.pumpWidget(_buildTestApp(overrides: _baseOverrides()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('초대 코드로 참가하기'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('초대 코드로 참가하기'),
        ),
        findsOneWidget,
      );
      expect(find.text('초대 코드'), findsOneWidget);
      expect(find.text('참가하기'), findsOneWidget);
      expect(find.text('취소'), findsOneWidget);
    });

    testWidgets('생성 다이얼로그에서 취소를 누르면 다이얼로그가 닫힌다', (tester) async {
      await tester.pumpWidget(_buildTestApp(overrides: _baseOverrides()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('새 가족 만들기'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('FamilySetupScreen – 기존 가족 리디렉션', () {
    testWidgets('가족이 없으면 설정 화면이 그대로 유지된다', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(overrides: _baseOverrides()),
      );
      await tester.pumpAndSettle();

      expect(_navigatedToHome, isFalse);
      expect(find.text('환영합니다!'), findsOneWidget);
    });

    testWidgets('이미 가족이 있으면 /home 으로 이동한다', (tester) async {
      final existingFamily = FamilyModel(
        id: 'existing-family',
        name: '기존 가족',
        createdBy: 'test-uid',
        memberIds: ['test-uid'],
        inviteCode: 'XYZ789',
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        _buildTestApp(
          overrides: _baseOverrides(families: [existingFamily]),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(_navigatedToHome, isTrue);
    });
  });
}

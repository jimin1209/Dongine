import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/family/data/family_repository.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/family/presentation/family_settings_screen.dart';
import 'package:dongine/shared/models/family_model.dart';
import 'package:dongine/shared/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 가족 설정 [FamilySettingsScreen]의 나가기 가드·공동 관리자 확인 흐름만 검증한다.
/// (기존 `family_settings_screen_test.dart`와 겹치지 않도록 시나리오를 나눔.)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUpAll(() async {
    await initializeDateFormatting('ko_KR');
  });

  final baseTime = DateTime(2026, 3, 15, 12, 0, 0);

  FamilyModel family({
    required String id,
    required String name,
    List<String>? memberIds,
    String inviteCode = 'CODE123',
    DateTime? inviteExpiresAt,
  }) {
    return FamilyModel(
      id: id,
      name: name,
      createdBy: 'admin-a',
      memberIds: memberIds ?? ['admin-a'],
      inviteCode: inviteCode,
      inviteExpiresAt: inviteExpiresAt ?? baseTime.add(const Duration(days: 30)),
      createdAt: baseTime,
    );
  }

  List<Override> baseOverrides({
    required FamilySessionUser session,
    required List<FamilyModel> families,
    required FamilyModel? current,
    required String? currentFamilyId,
    required List<FamilyMember> members,
    UserModel? userProfile,
  }) {
    final fid = current?.id;
    return [
      familySessionUserProvider.overrideWithValue(session),
      currentUserProfileProvider.overrideWith(
        (ref) => Future<UserModel?>.value(userProfile),
      ),
      userFamiliesProvider.overrideWithValue(AsyncValue.data(families)),
      currentFamilyProvider.overrideWithValue(AsyncValue.data(current)),
      currentFamilyIdProvider.overrideWithValue(AsyncValue.data(currentFamilyId)),
      if (fid != null)
        familyMembersProvider(fid).overrideWith(
          (ref) => Stream<List<FamilyMember>>.value(members),
        ),
    ];
  }

  Widget buildTestApp(List<Override> overrides) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const FamilySettingsScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('나가기 가드 회귀', () {
    testWidgets('마지막 유일 관리자는 차단 다이얼로그 본문 안내가 모두 보인다', (tester) async {
      final fam = family(
        id: 'f-guard',
        name: '가드테스트가족',
        memberIds: ['sole-admin', 'member-x'],
      );

      await tester.pumpWidget(
        buildTestApp(
          baseOverrides(
            session: const FamilySessionUser(uid: 'sole-admin'),
            families: [fam],
            current: fam,
            currentFamilyId: 'f-guard',
            members: [
              FamilyMember(
                uid: 'sole-admin',
                role: 'admin',
                nickname: '나',
                joinedAt: baseTime,
              ),
              FamilyMember(
                uid: 'member-x',
                role: 'member',
                nickname: '일반',
                joinedAt: baseTime,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('가족 나가기'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('가족 나가기'));
      await tester.pumpAndSettle();

      expect(find.text('가족 나가기 불가'), findsOneWidget);
      expect(find.textContaining('현재 유일한 관리자입니다'), findsOneWidget);
      expect(
        find.textContaining('다른 구성원에게 관리자 역할을 넘긴 후 나갈 수 있습니다'),
        findsOneWidget,
      );

      final dialog = find.byType(AlertDialog);
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(FilledButton, '확인'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('다른 관리자가 있으면 확인 다이얼로그 후 나가기로 leaveFamily가 호출된다',
        (tester) async {
      SharedPreferences.setMockInitialValues(
        const {'selected_family_id': 'f-coadmin'},
      );

      final fam = family(
        id: 'f-coadmin',
        name: '공동관리가족',
        memberIds: ['admin-a', 'admin-b'],
      );

      final repo = _RecordingLeaveFamilyRepository();

      await tester.pumpWidget(
        buildTestApp([
          ...baseOverrides(
            session: const FamilySessionUser(
              uid: 'admin-a',
              email: 'a@test.com',
            ),
            families: [fam],
            current: fam,
            currentFamilyId: 'f-coadmin',
            members: [
              FamilyMember(
                uid: 'admin-a',
                role: 'admin',
                nickname: '관리자A',
                joinedAt: baseTime,
              ),
              FamilyMember(
                uid: 'admin-b',
                role: 'admin',
                nickname: '관리자B',
                joinedAt: baseTime,
              ),
            ],
          ),
          familyRepositoryProvider.overrideWithValue(repo),
        ]),
      );
      await tester.pumpAndSettle();

      final leaveBtn = find.widgetWithText(OutlinedButton, '가족 나가기');
      await tester.scrollUntilVisible(
        leaveBtn,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(leaveBtn);
      await tester.pumpAndSettle();

      expect(find.text('가족 나가기 불가'), findsNothing);
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(find.text('가족 나가기'), findsWidgets);
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining('공동관리가족'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining('이 작업은 되돌릴 수 없습니다'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(FilledButton, '나가기'),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.lastLeaveFamilyId, 'f-coadmin');
      expect(repo.lastLeaveUid, 'admin-a');
      expect(find.textContaining('공동관리가족'), findsWidgets);
      expect(find.textContaining('가족에서 나왔습니다'), findsOneWidget);
    });
  });
}

/// [leaveFamily] 호출만 기록한다. 나머지는 미사용.
class _RecordingLeaveFamilyRepository extends Fake implements FamilyRepository {
  String? lastLeaveFamilyId;
  String? lastLeaveUid;

  @override
  Future<void> leaveFamily(String familyId, String uid) async {
    lastLeaveFamilyId = familyId;
    lastLeaveUid = uid;
  }
}

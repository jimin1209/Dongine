import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/family/presentation/family_settings_screen.dart';
import 'package:dongine/shared/models/family_model.dart';
import 'package:dongine/shared/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      createdBy: 'admin-uid',
      memberIds: memberIds ?? ['admin-uid'],
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
  }) {
    final fid = current?.id;
    return [
      familySessionUserProvider.overrideWithValue(session),
      currentUserProfileProvider.overrideWith(
        (ref) => Future<UserModel?>.value(null),
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
        GoRoute(
          path: '/family-setup',
          builder: (context, state) => const Scaffold(
            body: Text('family-setup-stub'),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  group('가족 전환', () {
    testWidgets('userFamilies 목록을 타일로 렌더하고 선택된 가족에 체크 아이콘을 표시한다',
        (tester) async {
      final fAlpha = family(
        id: 'fam-alpha',
        name: '알파 가족',
        memberIds: ['u1'],
      );
      final fBeta = family(
        id: 'fam-beta',
        name: '베타 가족',
        memberIds: ['u1', 'u2'],
      );

      await tester.pumpWidget(
        buildTestApp(
          baseOverrides(
            session: const FamilySessionUser(
              uid: 'u1',
              email: 'u1@test.com',
            ),
            families: [fAlpha, fBeta],
            current: fBeta,
            currentFamilyId: 'fam-beta',
            members: [
              FamilyMember(
                uid: 'u1',
                role: 'admin',
                nickname: '관리자',
                joinedAt: baseTime,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('알파 가족'), findsOneWidget);
      expect(find.text('베타 가족'), findsOneWidget);
      expect(find.text('구성원 1명'), findsOneWidget);
      expect(find.text('구성원 2명'), findsOneWidget);

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      final betaTile = find.ancestor(
        of: find.text('베타 가족'),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(
          of: betaTile,
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOneWidget,
      );
    });

    testWidgets('참여 가족이 없으면 안내 카드와 가족 설정 이동 버튼을 보여준다',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          baseOverrides(
            session: const FamilySessionUser(
              uid: 'u1',
              email: 'u1@test.com',
            ),
            families: const [],
            current: null,
            currentFamilyId: null,
            members: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('참여한 가족이 없습니다'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '가족 설정'), findsOneWidget);
    });
  });

  group('초대 코드 UI', () {
    testWidgets('유효한 초대 코드가 있으면 복사 버튼이 보이고 관리자만 재발급 버튼이 활성화된다',
        (tester) async {
      final fam = family(
        id: 'f1',
        name: '테스트 가족',
        memberIds: ['admin-uid', 'member-uid'],
        inviteCode: 'LIVECODE',
      );

      await tester.pumpWidget(
        buildTestApp(
          baseOverrides(
            session: const FamilySessionUser(
              uid: 'admin-uid',
              email: 'a@test.com',
            ),
            families: [fam],
            current: fam,
            currentFamilyId: 'f1',
            members: [
              FamilyMember(
                uid: 'admin-uid',
                role: 'admin',
                nickname: '관리자',
                joinedAt: baseTime,
              ),
              FamilyMember(
                uid: 'member-uid',
                role: 'member',
                nickname: '멤버',
                joinedAt: baseTime,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LIVECODE'), findsWidgets);
      final refreshLabel = find.text('초대 코드 재발급');
      expect(refreshLabel, findsOneWidget);
      final adminRefresh = tester.widget<FilledButton>(
        find.ancestor(
          of: refreshLabel,
          matching: find.byType(FilledButton),
        ),
      );
      expect(adminRefresh.onPressed, isNotNull);

      await tester.pumpWidget(
        buildTestApp(
          baseOverrides(
            session: const FamilySessionUser(
              uid: 'member-uid',
              email: 'm@test.com',
            ),
            families: [fam],
            current: fam,
            currentFamilyId: 'f1',
            members: [
              FamilyMember(
                uid: 'admin-uid',
                role: 'admin',
                nickname: '관리자',
                joinedAt: baseTime,
              ),
              FamilyMember(
                uid: 'member-uid',
                role: 'member',
                nickname: '멤버',
                joinedAt: baseTime,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LIVECODE'), findsWidgets);
      expect(
        find.text('초대 코드 관리는 가족 관리자만 할 수 있습니다.'),
        findsOneWidget,
      );
      final memberRefreshFinder = find.ancestor(
        of: find.text('초대 코드 재발급'),
        matching: find.byType(FilledButton),
      );
      final memberRefresh = tester.widget<FilledButton>(memberRefreshFinder);
      expect(memberRefresh.onPressed, isNull);
    });

    testWidgets('만료된 초대 코드는 복사 버튼이 숨겨지고 새 발급 라벨이 표시된다', (tester) async {
      final fam = family(
        id: 'f1',
        name: '만료 가족',
        inviteCode: 'OLD',
        inviteExpiresAt: baseTime.subtract(const Duration(days: 1)),
      );

      await tester.pumpWidget(
        buildTestApp(
          baseOverrides(
            session: const FamilySessionUser(uid: 'admin-uid'),
            families: [fam],
            current: fam,
            currentFamilyId: 'f1',
            members: [
              FamilyMember(
                uid: 'admin-uid',
                role: 'admin',
                nickname: '관리자',
                joinedAt: baseTime,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.copy), findsNothing);
      expect(find.text('새 초대 코드 발급'), findsOneWidget);
    });

    testWidgets('초대 코드 문자열이 비어 있으면 복사 버튼이 없고 재발급/발급 버튼만 노출된다', (tester) async {
      final fam = family(
        id: 'f1',
        name: '코드 없음 가족',
        inviteCode: '',
        inviteExpiresAt: DateTime.now().add(const Duration(days: 30)),
      );

      await tester.pumpWidget(
        buildTestApp(
          baseOverrides(
            session: const FamilySessionUser(uid: 'admin-uid'),
            families: [fam],
            current: fam,
            currentFamilyId: 'f1',
            members: [
              FamilyMember(
                uid: 'admin-uid',
                role: 'admin',
                nickname: '관리자',
                joinedAt: baseTime,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.copy), findsNothing);
      expect(find.text('초대 코드 재발급'), findsOneWidget);
    });

    testWidgets('만료 시각이 없으면 복사 버튼이 없고 새 발급 라벨이 표시된다', (tester) async {
      final fam = FamilyModel(
        id: 'f1',
        name: '만료시각 없음',
        createdBy: 'admin-uid',
        memberIds: const ['admin-uid'],
        inviteCode: 'NOEXP',
        inviteExpiresAt: null,
        createdAt: baseTime,
      );

      await tester.pumpWidget(
        buildTestApp(
          baseOverrides(
            session: const FamilySessionUser(uid: 'admin-uid'),
            families: [fam],
            current: fam,
            currentFamilyId: 'f1',
            members: [
              FamilyMember(
                uid: 'admin-uid',
                role: 'admin',
                nickname: '관리자',
                joinedAt: baseTime,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.copy), findsNothing);
      expect(find.text('새 초대 코드 발급'), findsOneWidget);
    });
  });

  group('관리자 이전 / 나가기 가드', () {
    testWidgets('유일한 관리자가 자신의 역할 배지를 누르면 역할 변경 불가 다이얼로그가 뜬다',
        (tester) async {
      final fam = family(id: 'f1', name: '가족');

      await tester.pumpWidget(
        buildTestApp(
          baseOverrides(
            session: const FamilySessionUser(uid: 'admin-uid'),
            families: [fam],
            current: fam,
            currentFamilyId: 'f1',
            members: [
              FamilyMember(
                uid: 'admin-uid',
                role: 'admin',
                nickname: '나',
                joinedAt: baseTime,
              ),
              FamilyMember(
                uid: 'other',
                role: 'member',
                nickname: '다른 사람',
                joinedAt: baseTime,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final soleAdminTile = find.ancestor(
        of: find.text('나'),
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(
          of: soleAdminTile,
          matching: find.byIcon(Icons.edit_outlined),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('역할 변경 불가'), findsOneWidget);
      expect(find.textContaining('마지막 관리자는 해제할 수 없습니다'), findsOneWidget);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text('역할 변경 불가'), findsNothing);
    });

    testWidgets('유일한 관리자가 타인이 있을 때 나가기를 누르면 차단 다이얼로그가 뜬다', (tester) async {
      final fam = family(id: 'f1', name: '우리집');

      await tester.pumpWidget(
        buildTestApp(
          baseOverrides(
            session: const FamilySessionUser(uid: 'admin-uid'),
            families: [fam],
            current: fam,
            currentFamilyId: 'f1',
            members: [
              FamilyMember(
                uid: 'admin-uid',
                role: 'admin',
                nickname: '관리자',
                joinedAt: baseTime,
              ),
              FamilyMember(
                uid: 'other',
                role: 'member',
                nickname: '멤버',
                joinedAt: baseTime,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, '가족 나가기'));
      await tester.pumpAndSettle();

      expect(find.text('가족 나가기 불가'), findsOneWidget);
      expect(
        find.textContaining('유일한 관리자입니다'),
        findsOneWidget,
      );
    });
  });
}

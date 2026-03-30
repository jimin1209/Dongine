import 'package:dongine/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [LoginScreen] with the minimum scaffolding needed for widget tests.
/// No Firebase dependency — [authRepositoryProvider] is not exercised because
/// we only tap the submit button to trigger *client-side* form validation.
Widget _buildTestApp() {
  return const ProviderScope(
    child: MaterialApp(
      home: LoginScreen(),
    ),
  );
}

void main() {
  // ─── Mode toggle ───────────────────────────────────────────────────
  group('로그인 ↔ 회원가입 모드 전환', () {
    testWidgets('초기 상태는 로그인 모드이다', (tester) async {
      await tester.pumpWidget(_buildTestApp());

      // AppBar title + FilledButton 모두 '로그인' 표시
      expect(find.text('로그인'), findsNWidgets(2));
      expect(find.widgetWithText(FilledButton, '로그인'), findsOneWidget);
      // 이름 필드 없음
      expect(find.text('이름'), findsNothing);
      // 이메일·비밀번호 필드만 표시
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('회원가입 전환 시 이름 필드가 추가된다', (tester) async {
      await tester.pumpWidget(_buildTestApp());

      await tester.tap(find.text('계정이 없으신가요? 회원가입'));
      await tester.pumpAndSettle();

      expect(find.text('회원가입'), findsNWidgets(2)); // AppBar + button
      expect(find.byType(TextFormField), findsNWidgets(3)); // 이름+이메일+비밀번호
      expect(find.text('이름'), findsOneWidget);
    });

    testWidgets('회원가입 → 로그인으로 다시 전환할 수 있다', (tester) async {
      await tester.pumpWidget(_buildTestApp());

      // 회원가입으로 전환
      await tester.tap(find.text('계정이 없으신가요? 회원가입'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(3));

      // 로그인으로 복귀
      await tester.tap(find.text('이미 계정이 있으신가요? 로그인'));
      await tester.pumpAndSettle();

      expect(find.text('로그인'), findsNWidgets(2)); // AppBar + button
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('이름'), findsNothing);
    });
  });

  // ─── Login mode validation ────────────────────────────────────────
  group('로그인 모드 - 입력 검증', () {
    testWidgets('빈 폼 제출 시 이메일·비밀번호 검증 메시지가 나온다', (tester) async {
      await tester.pumpWidget(_buildTestApp());

      await tester.tap(find.widgetWithText(FilledButton, '로그인'));
      await tester.pumpAndSettle();

      expect(find.text('올바른 이메일을 입력해주세요'), findsOneWidget);
      expect(find.text('비밀번호는 6자 이상이어야 합니다'), findsOneWidget);
    });

    testWidgets('@가 없는 이메일은 검증 실패한다', (tester) async {
      await tester.pumpWidget(_buildTestApp());

      await tester.enterText(
        find.byType(TextFormField).at(0), // email
        'notanemail',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1), // password
        '123456',
      );
      await tester.tap(find.widgetWithText(FilledButton, '로그인'));
      await tester.pumpAndSettle();

      expect(find.text('올바른 이메일을 입력해주세요'), findsOneWidget);
    });

    testWidgets('6자 미만 비밀번호는 검증 실패한다', (tester) async {
      await tester.pumpWidget(_buildTestApp());

      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.com');
      await tester.enterText(find.byType(TextFormField).at(1), '12345');
      await tester.tap(find.widgetWithText(FilledButton, '로그인'));
      await tester.pumpAndSettle();

      expect(find.text('비밀번호는 6자 이상이어야 합니다'), findsOneWidget);
      // 이메일은 통과
      expect(find.text('올바른 이메일을 입력해주세요'), findsNothing);
    });
  });

  // ─── Signup mode validation ───────────────────────────────────────
  group('회원가입 모드 - 입력 검증', () {
    Future<void> switchToSignup(WidgetTester tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.tap(find.text('계정이 없으신가요? 회원가입'));
      await tester.pumpAndSettle();
    }

    testWidgets('빈 폼 제출 시 이름·이메일·비밀번호 검증 메시지가 나온다',
        (tester) async {
      await switchToSignup(tester);

      await tester.tap(find.widgetWithText(FilledButton, '회원가입'));
      await tester.pumpAndSettle();

      expect(find.text('이름을 입력해주세요'), findsOneWidget);
      expect(find.text('올바른 이메일을 입력해주세요'), findsOneWidget);
      expect(find.text('비밀번호는 6자 이상이어야 합니다'), findsOneWidget);
    });

    testWidgets('이름만 비어 있으면 이름 검증만 실패한다', (tester) async {
      await switchToSignup(tester);

      // 이름(index 0) 비움, 이메일(index 1), 비밀번호(index 2) 입력
      await tester.enterText(find.byType(TextFormField).at(1), 'a@b.com');
      await tester.enterText(find.byType(TextFormField).at(2), '123456');
      await tester.tap(find.widgetWithText(FilledButton, '회원가입'));
      await tester.pumpAndSettle();

      expect(find.text('이름을 입력해주세요'), findsOneWidget);
      expect(find.text('올바른 이메일을 입력해주세요'), findsNothing);
      expect(find.text('비밀번호는 6자 이상이어야 합니다'), findsNothing);
    });

    testWidgets('공백만 있는 이름은 검증 실패한다', (tester) async {
      await switchToSignup(tester);

      await tester.enterText(find.byType(TextFormField).at(0), '   ');
      await tester.enterText(find.byType(TextFormField).at(1), 'a@b.com');
      await tester.enterText(find.byType(TextFormField).at(2), '123456');
      await tester.tap(find.widgetWithText(FilledButton, '회원가입'));
      await tester.pumpAndSettle();

      expect(find.text('이름을 입력해주세요'), findsOneWidget);
    });
  });

  // ─── Password visibility toggle ───────────────────────────────────
  group('비밀번호 표시/숨김 토글', () {
    testWidgets('기본적으로 비밀번호가 가려져 있다', (tester) async {
      await tester.pumpWidget(_buildTestApp());

      // EditableText의 obscureText로 확인
      final editableText = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(TextFormField).at(1),
          matching: find.byType(EditableText),
        ),
      );
      expect(editableText.obscureText, isTrue);
    });

    testWidgets('눈 아이콘 탭 시 비밀번호가 보인다', (tester) async {
      await tester.pumpWidget(_buildTestApp());

      // visibility_off 아이콘이 초기 상태
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();

      // visibility 아이콘으로 변경
      expect(find.byIcon(Icons.visibility), findsOneWidget);

      // obscureText가 false로 변경됐는지 확인
      final editableText = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(TextFormField).at(1),
          matching: find.byType(EditableText),
        ),
      );
      expect(editableText.obscureText, isFalse);
    });
  });

  // ─── Password reset placeholder ───────────────────────────────────
  // 현재 비밀번호 재설정 UI가 구현되어 있지 않음.
  // 비밀번호 재설정 버튼이 추가되면 여기에 테스트를 추가할 것.
  group('비밀번호 재설정 (미구현 확인)', () {
    testWidgets('로그인 화면에 비밀번호 재설정 링크가 없다', (tester) async {
      await tester.pumpWidget(_buildTestApp());

      // 비밀번호 찾기/재설정 관련 텍스트가 없음을 확인
      expect(find.textContaining('비밀번호 찾기'), findsNothing);
      expect(find.textContaining('비밀번호 재설정'), findsNothing);
      expect(find.textContaining('forgot'), findsNothing);
    });
  });
}

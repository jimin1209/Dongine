import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dongine/app/app.dart';
import 'package:dongine/features/auth/domain/auth_provider.dart';

void main() {
  testWidgets('앱은 온보딩 화면으로 시작한다', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(null),
          ),
        ],
        child: const DongineApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('동이네'), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);
  });

  testWidgets('온보딩 시작하기 버튼은 로그인 화면으로 이동한다',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(null),
          ),
        ],
        child: const DongineApp(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('이메일'), findsAtLeastNWidgets(1));
  });
}

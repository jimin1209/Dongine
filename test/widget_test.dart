import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dongine/app/app.dart';

void main() {
  testWidgets('앱 실행 테스트', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: DongineApp()),
    );
    expect(find.text('동이네'), findsOneWidget);
  });
}

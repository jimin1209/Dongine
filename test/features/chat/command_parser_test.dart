import 'package:dongine/features/chat/data/command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── 1. 지원 명령 파싱 성공 ──────────────────────────────────────
  group('supported commands parse successfully', () {
    const commands = [
      'todo',
      'remind',
      'location',
      'calendar',
      'poll',
      'meal',
      'date',
      'cart',
      'expense',
      'members',
    ];

    for (final cmd in commands) {
      test('/$cmd without args', () {
        final result = CommandParser.parse('/$cmd');
        expect(result, isNotNull);
        expect(result!.name, cmd);
        expect(result.args, isEmpty);
        expect(result.rawInput, '/$cmd');
      });

      test('/$cmd with args', () {
        final result = CommandParser.parse('/$cmd some argument');
        expect(result, isNotNull);
        expect(result!.name, cmd);
        expect(result.args, 'some argument');
      });
    }
  });

  // ── 2. 대소문자 & 공백 처리 ─────────────────────────────────────
  group('case and whitespace handling', () {
    test('uppercase command is normalised to lowercase', () {
      final result = CommandParser.parse('/TODO buy milk');
      expect(result, isNotNull);
      expect(result!.name, 'todo');
      expect(result.args, 'buy milk');
    });

    test('mixed-case command is normalised', () {
      final result = CommandParser.parse('/ReMiNd meeting');
      expect(result, isNotNull);
      expect(result!.name, 'remind');
    });

    test('leading/trailing whitespace is trimmed', () {
      final result = CommandParser.parse('  /poll option1  ');
      expect(result, isNotNull);
      expect(result!.name, 'poll');
      expect(result.args, 'option1');
      expect(result.rawInput, '/poll option1');
    });

    test('extra spaces between command and args are trimmed', () {
      final result = CommandParser.parse('/meal   김치찌개');
      expect(result, isNotNull);
      expect(result!.args, '김치찌개');
    });

    test('args preserve internal spaces', () {
      final result = CommandParser.parse('/todo buy milk and eggs');
      expect(result!.args, 'buy milk and eggs');
    });
  });

  // ── 3. 미지원 명령 & 일반 텍스트 실패 ──────────────────────────
  group('unsupported commands and plain text return null', () {
    test('unsupported command returns null', () {
      expect(CommandParser.parse('/unknown'), isNull);
    });

    test('plain text without slash returns null', () {
      expect(CommandParser.parse('hello world'), isNull);
    });

    test('empty string returns null', () {
      expect(CommandParser.parse(''), isNull);
    });

    test('whitespace-only string returns null', () {
      expect(CommandParser.parse('   '), isNull);
    });

    test('bare slash returns null', () {
      expect(CommandParser.parse('/'), isNull);
    });

    test('slash followed only by spaces returns null', () {
      expect(CommandParser.parse('/   '), isNull);
    });

    test('text that contains slash mid-word is not a command', () {
      expect(CommandParser.parse('not/todo'), isNull);
    });
  });
}

class ChatCommand {
  final String name;
  final String args;
  final String rawInput;

  const ChatCommand({
    required this.name,
    required this.args,
    required this.rawInput,
  });
}

class CommandParser {
  static const _supportedCommands = {
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
  };

  static ChatCommand? parse(String input) {
    final trimmed = input.trim();
    if (!trimmed.startsWith('/')) return null;

    final withoutSlash = trimmed.substring(1);
    if (withoutSlash.isEmpty) return null;

    final spaceIndex = withoutSlash.indexOf(' ');
    final String name;
    final String args;

    if (spaceIndex == -1) {
      name = withoutSlash.toLowerCase();
      args = '';
    } else {
      name = withoutSlash.substring(0, spaceIndex).toLowerCase();
      args = withoutSlash.substring(spaceIndex + 1).trim();
    }

    if (!_supportedCommands.contains(name)) return null;

    return ChatCommand(
      name: name,
      args: args,
      rawInput: trimmed,
    );
  }
}

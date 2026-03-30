import 'package:flutter/material.dart';
import 'package:dongine/shared/models/message_model.dart';

// --- TodoCard ---

class TodoCard extends StatelessWidget {
  final MessageModel message;
  final bool isOwn;
  final VoidCallback? onToggle;

  const TodoCard({
    super.key,
    required this.message,
    required this.isOwn,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = message.metadata ?? {};
    final title = metadata['title'] as String? ?? message.content;
    final assignedTo = metadata['assignedTo'] as String? ?? '';
    final isCompleted = metadata['isCompleted'] as bool? ?? false;

    return _CardWrapper(
      isOwn: isOwn,
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Icon(
              isCompleted
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              color: isCompleted ? Colors.green : Colors.grey,
              size: 24,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '할 일',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    decoration:
                        isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted ? Colors.grey : null,
                  ),
                ),
                if (assignedTo.isNotEmpty)
                  Text(
                    '담당: ${message.senderName}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- PollCard ---

class PollCard extends StatelessWidget {
  final MessageModel message;
  final bool isOwn;
  final String? currentUserId;
  final void Function(String option)? onVote;
  final VoidCallback? onClose;

  const PollCard({
    super.key,
    required this.message,
    required this.isOwn,
    this.currentUserId,
    this.onVote,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = message.metadata ?? {};
    final question = metadata['question'] as String? ?? '투표';
    final options = List<String>.from(metadata['options'] ?? []);
    final votes = Map<String, dynamic>.from(metadata['votes'] ?? {});
    final isClosed = metadata['closed'] == true;

    // Count votes per option
    final voteCounts = <String, int>{};
    for (final option in options) {
      voteCounts[option] = 0;
    }
    for (final vote in votes.values) {
      final voteStr = vote.toString();
      voteCounts[voteStr] = (voteCounts[voteStr] ?? 0) + 1;
    }

    final totalVotes = votes.length;
    final myVote =
        currentUserId != null ? votes[currentUserId]?.toString() : null;

    return _CardWrapper(
      isOwn: isOwn,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll, size: 16, color: Colors.blue),
              const SizedBox(width: 4),
              const Text(
                '투표',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
              if (isClosed) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '마감됨',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            question,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...options.map((option) {
            final count = voteCounts[option] ?? 0;
            final isSelected = myVote == option;
            final ratio = totalVotes > 0 ? count / totalVotes : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: GestureDetector(
                onTap: isClosed ? null : () => onVote?.call(option),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 20,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.blue.withValues(alpha: 0.15),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                option,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          Text(
            '총 $totalVotes명 투표',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          if (!isClosed && message.senderId == currentUserId)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onClose,
                child: const Text(
                  '마감하기',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- MealVoteCard ---

class MealVoteCard extends StatelessWidget {
  final MessageModel message;
  final bool isOwn;
  final String? currentUserId;
  final void Function(String option)? onVote;
  final VoidCallback? onClose;

  const MealVoteCard({
    super.key,
    required this.message,
    required this.isOwn,
    this.currentUserId,
    this.onVote,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = message.metadata ?? {};
    final mealType = metadata['mealType'] as String? ?? 'dinner';
    final options = List<String>.from(metadata['options'] ?? []);
    final votes = Map<String, dynamic>.from(metadata['votes'] ?? {});

    final mealLabel = switch (mealType) {
      'breakfast' => '아침',
      'lunch' => '점심',
      'dinner' => '저녁',
      _ => '식사',
    };

    final isClosed = metadata['closed'] == true;
    final decided = metadata['decided']?.toString();

    return _CardWrapper(
      isOwn: isOwn,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant, size: 16, color: Colors.orange),
              const SizedBox(width: 4),
              Text(
                '$mealLabel 투표',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
              if (isClosed) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '마감됨',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ),
              ],
            ],
          ),
          if (isClosed && decided != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.orange.withValues(alpha: 0.15),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.orange),
                  const SizedBox(width: 6),
                  Text(
                    '결정: $decided',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (options.isEmpty)
            Text(
              '메뉴 옵션을 추가해주세요',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            )
          else
            ...options.map((option) {
              final voteCount =
                  votes.values.where((v) => v.toString() == option).length;
              final isSelected = currentUserId != null &&
                  votes[currentUserId]?.toString() == option;
              final isDecided = isClosed && decided == option;

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: GestureDetector(
                  onTap: isClosed ? null : () => onVote?.call(option),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: isDecided
                          ? Colors.orange.withValues(alpha: 0.15)
                          : isSelected
                              ? Colors.orange.withValues(alpha: 0.10)
                              : Colors.grey.withValues(alpha: 0.08),
                      border: Border.all(
                        color: isDecided
                            ? Colors.orange
                            : isSelected
                                ? Colors.orange.shade200
                                : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            option,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  isDecided ? FontWeight.w600 : null,
                            ),
                          ),
                        ),
                        Text(
                          '$voteCount표',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 4),
          if (!isClosed && message.senderId == currentUserId)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onClose,
                child: const Text(
                  '마감하기',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- ReminderCard ---

class ReminderCard extends StatelessWidget {
  final MessageModel message;
  final bool isOwn;

  const ReminderCard({
    super.key,
    required this.message,
    required this.isOwn,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = message.metadata ?? {};
    final time = metadata['time'] as String? ?? '';
    final content = metadata['content'] as String? ?? message.content;

    return _CardWrapper(
      isOwn: isOwn,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.alarm, size: 20, color: Colors.amber),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '리마인더',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber,
                  ),
                ),
                if (time.isNotEmpty)
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (content.isNotEmpty)
                  Text(
                    content,
                    style: const TextStyle(fontSize: 14),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- EventCard ---

class EventCard extends StatelessWidget {
  final MessageModel message;
  final bool isOwn;

  const EventCard({
    super.key,
    required this.message,
    required this.isOwn,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = message.metadata ?? {};
    final title = metadata['title'] as String? ?? message.content;
    final date = metadata['date'] as String? ?? '';
    final eventType = metadata['type'] as String? ?? 'general';

    final IconData icon;
    final Color color;
    final String label;

    if (eventType == 'date') {
      icon = Icons.favorite;
      color = Colors.pink;
      label = '데이트';
    } else {
      icon = Icons.calendar_today;
      color = Colors.teal;
      label = '일정';
    }

    return _CardWrapper(
      isOwn: isOwn,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (date.isNotEmpty)
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- LocationCard ---

class LocationCard extends StatelessWidget {
  final MessageModel message;
  final bool isOwn;

  const LocationCard({
    super.key,
    required this.message,
    required this.isOwn,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = message.metadata ?? {};
    final address = metadata['address'] as String? ?? '위치 정보 없음';

    return _CardWrapper(
      isOwn: isOwn,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(
                Icons.map,
                size: 40,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.red),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  address,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- MembersCard ---

class MembersCard extends StatelessWidget {
  final MessageModel message;
  final bool isOwn;

  const MembersCard({
    super.key,
    required this.message,
    required this.isOwn,
  });

  @override
  Widget build(BuildContext context) {
    return _CardWrapper(
      isOwn: isOwn,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.people, size: 16, color: Colors.indigo),
              SizedBox(width: 4),
              Text(
                '가족 멤버',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.shade300,
                child: const Icon(Icons.person, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                message.senderName,
                style: const TextStyle(fontSize: 14),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '온라인',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Shared Card Wrapper ---

class _CardWrapper extends StatelessWidget {
  final bool isOwn;
  final Widget child;

  const _CardWrapper({
    required this.isOwn,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

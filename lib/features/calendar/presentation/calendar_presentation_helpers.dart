part of 'calendar_screen.dart';

IconData _eventTypeIcon(String type) {
  switch (type) {
    case 'meal':
      return Icons.restaurant;
    case 'date':
      return Icons.favorite;
    case 'anniversary':
      return Icons.cake;
    case 'hospital':
      return Icons.local_hospital;
    default:
      return Icons.event;
  }
}

String _eventTypeLabel(String type) {
  switch (type) {
    case 'meal':
      return '식사';
    case 'date':
      return '데이트';
    case 'anniversary':
      return '기념일';
    case 'hospital':
      return '병원';
    default:
      return '일반';
  }
}

String _eventTypeColor(String type) {
  switch (type) {
    case 'meal':
      return '#FF9800';
    case 'date':
      return '#E91E63';
    case 'anniversary':
      return '#9C27B0';
    case 'hospital':
      return '#4CAF50';
    default:
      return '#4285F4';
  }
}

Color _parseColor(String hex) {
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return const Color(0xFF4285F4);
  }
}

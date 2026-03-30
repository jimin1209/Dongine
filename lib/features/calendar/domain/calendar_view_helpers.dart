import 'package:flutter/material.dart';

/// 캘린더 이벤트 타입에 대응하는 아이콘을 반환한다.
IconData eventTypeIcon(String type) {
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

/// 캘린더 이벤트 타입의 한국어 라벨을 반환한다.
String eventTypeLabel(String type) {
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

/// 캘린더 이벤트 타입의 기본 색상 hex 코드를 반환한다.
String eventTypeColor(String type) {
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

/// hex 문자열을 [Color]로 변환한다. 파싱 실패 시 기본 파란색을 반환한다.
Color parseHexColor(String hex) {
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return const Color(0xFF4285F4);
  }
}

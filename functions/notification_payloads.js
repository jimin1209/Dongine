'use strict';

const CHAT_TYPE_LABELS = {
  todo: '할 일을 추가했어요.',
  poll: '투표를 만들었어요.',
  location: '위치를 공유했어요.',
  event: '일정을 공유했어요.',
  meal_vote: '식사 투표를 시작했어요.',
  members: '가족 상태를 확인했어요.',
  reminder: '리마인더를 등록했어요.',
};

const EVENT_TYPE_LABELS = {
  general: '새 일정이 등록되었어요',
  meal: '새 식사 일정이 등록되었어요',
  date: '새 나들이 일정이 등록되었어요',
  anniversary: '새 기념일 일정이 등록되었어요',
  hospital: '새 병원 일정이 등록되었어요',
};

function truncateText(value, maxLength = 80) {
  if (typeof value !== 'string') return '';

  const normalized = value.replace(/\s+/g, ' ').trim();
  if (normalized.length <= maxLength) {
    return normalized;
  }

  return `${normalized.slice(0, maxLength - 1)}…`;
}

function buildChatPreview({ type = 'text', content = '', metadata = {} }) {
  if (type === 'text') {
    return truncateText(content) || '새 메시지를 보냈어요.';
  }

  if (type === 'todo' && typeof metadata.title === 'string') {
    return `할 일: ${truncateText(metadata.title)}`;
  }

  if (type === 'poll' && typeof metadata.question === 'string') {
    return `투표: ${truncateText(metadata.question)}`;
  }

  if (
    (type === 'event' || type === 'reminder') &&
    typeof metadata.title === 'string'
  ) {
    return `${type === 'reminder' ? '리마인더' : '일정'}: ${truncateText(metadata.title)}`;
  }

  return (
    CHAT_TYPE_LABELS[type] || truncateText(content) || '새 메시지를 보냈어요.'
  );
}

function formatEventSchedule(startAt, isAllDay) {
  if (!(startAt instanceof Date) || Number.isNaN(startAt.getTime())) {
    return '';
  }

  const formatter = new Intl.DateTimeFormat('ko-KR', {
    month: 'numeric',
    day: 'numeric',
    weekday: 'short',
    ...(isAllDay
      ? {}
      : {
          hour: 'numeric',
          minute: '2-digit',
          hour12: false,
        }),
    timeZone: 'Asia/Seoul',
  });

  return formatter.format(startAt);
}

function buildChatNotification(message) {
  if (!message || typeof message.senderName !== 'string') {
    return null;
  }

  return {
    title: `${message.senderName}님의 메시지`,
    body: buildChatPreview(message),
    route: '/chat',
    type: 'chat_message',
  };
}

function buildEventNotification(event) {
  if (!event || typeof event.title !== 'string' || !event.title.trim()) {
    return null;
  }

  const typeLabel = EVENT_TYPE_LABELS[event.type] || EVENT_TYPE_LABELS.general;
  const schedule = formatEventSchedule(event.startAt, Boolean(event.isAllDay));

  return {
    title: typeLabel,
    body: schedule
      ? `${truncateText(event.title)} · ${schedule}`
      : truncateText(event.title),
    route: '/calendar',
    type: 'calendar_event',
  };
}

module.exports = {
  buildChatNotification,
  buildChatPreview,
  buildEventNotification,
  formatEventSchedule,
  truncateText,
};

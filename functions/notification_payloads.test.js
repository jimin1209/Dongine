'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  buildChatNotification,
  buildEventNotification,
  truncateText,
} = require('./notification_payloads');

test('text chat notification uses sender and content preview', () => {
  const payload = buildChatNotification({
    senderName: '지민',
    type: 'text',
    content: '오늘 저녁 뭐 먹을까?',
  });

  assert.deepEqual(payload, {
    title: '지민님의 메시지',
    body: '오늘 저녁 뭐 먹을까?',
    route: '/chat',
    type: 'chat_message',
  });
});

test('structured chat notification uses friendly preview', () => {
  const payload = buildChatNotification({
    senderName: '지민',
    type: 'poll',
    content: '/poll 저녁 메뉴 피자 초밥',
    metadata: { question: '저녁 메뉴' },
  });

  assert.equal(payload.body, '투표: 저녁 메뉴');
  assert.equal(payload.route, '/chat');
});

test('calendar notification includes route and schedule', () => {
  const payload = buildEventNotification({
    title: '가족 외식',
    type: 'general',
    isAllDay: false,
    startAt: new Date('2026-04-05T09:30:00+09:00'),
  });

  assert.equal(payload.title, '새 일정이 등록되었어요');
  assert.equal(payload.route, '/calendar');
  assert.match(payload.body, /가족 외식/);
});

test('truncateText shortens long previews', () => {
  assert.equal(truncateText('a'.repeat(100), 10), 'aaaaaaaaa…');
});

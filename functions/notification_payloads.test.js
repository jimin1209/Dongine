'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  buildCartNotification,
  buildChatNotification,
  buildEventNotification,
  buildExpenseNotification,
  buildTodoNotification,
  truncateText,
  VALID_ROUTES,
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

test('todo notification uses todo route', () => {
  const payload = buildTodoNotification({ title: '우유 사오기' });

  assert.equal(payload.route, '/todo');
  assert.equal(payload.type, 'todo_created');
  assert.equal(payload.body, '우유 사오기');
});

test('cart notification uses cart route and quantity', () => {
  const payload = buildCartNotification({ name: '사과', quantity: 3 });

  assert.equal(payload.route, '/cart');
  assert.equal(payload.body, '사과 3개');
});

test('expense notification formats amount and route', () => {
  const payload = buildExpenseNotification({ title: '외식', amount: 45000 });

  assert.equal(payload.route, '/expense');
  assert.equal(payload.body, '외식 · 45,000원');
});

// ── Route validation ────────────────────────────────────────────────────────

test('VALID_ROUTES contains all routes used by builders', () => {
  const builders = [
    () => buildChatNotification({ senderName: 'a', type: 'text', content: 'b' }),
    () => buildEventNotification({ title: 'e', type: 'general', startAt: new Date() }),
    () => buildTodoNotification({ title: 't' }),
    () => buildCartNotification({ name: 'c' }),
    () => buildExpenseNotification({ title: 'x', amount: 1 }),
  ];

  for (const build of builders) {
    const payload = build();
    assert.ok(VALID_ROUTES.has(payload.route), `route "${payload.route}" not in VALID_ROUTES`);
  }
});

test('every builder route starts with / and is non-empty', () => {
  const payloads = [
    buildChatNotification({ senderName: 'a', type: 'text', content: 'b' }),
    buildEventNotification({ title: 'e', type: 'general', startAt: new Date() }),
    buildTodoNotification({ title: 't' }),
    buildCartNotification({ name: 'c' }),
    buildExpenseNotification({ title: 'x', amount: 1 }),
  ];

  for (const p of payloads) {
    assert.ok(p.route.startsWith('/'), `route "${p.route}" does not start with /`);
    assert.ok(p.route.length > 1, `route "${p.route}" is too short`);
  }
});

test('builders return null for missing or invalid inputs', () => {
  assert.equal(buildChatNotification(null), null);
  assert.equal(buildChatNotification({}), null);
  assert.equal(buildEventNotification(null), null);
  assert.equal(buildEventNotification({ title: '  ' }), null);
  assert.equal(buildTodoNotification(null), null);
  assert.equal(buildTodoNotification({ title: '' }), null);
  assert.equal(buildCartNotification(null), null);
  assert.equal(buildCartNotification({ name: '  ' }), null);
  assert.equal(buildExpenseNotification(null), null);
  assert.equal(buildExpenseNotification({ title: '' }), null);
});

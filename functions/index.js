const admin = require("firebase-admin");
const { logger } = require("firebase-functions");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const {
  buildCartNotification,
  buildChatNotification,
  buildEventNotification,
  buildExpenseNotification,
  buildTodoNotification,
} = require("./notification_payloads");

admin.initializeApp();
setGlobalOptions({
  region: "asia-northeast3",
  maxInstances: 10,
});

const db = admin.firestore();
const messaging = admin.messaging();

const INVALID_TOKEN_ERRORS = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
]);

exports.notifyOnChatMessageCreated = onDocumentCreated(
  "families/{familyId}/messages/{messageId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const familyId = event.params.familyId;
    const messageId = event.params.messageId;
    const message = snapshot.data();
    if (!message || message.isDeleted === true) return;

    const senderId = asString(message.senderId);
    const payload = buildChatNotification({
      senderName: asString(message.senderName) || "가족",
      type: asString(message.type) || "text",
      content: asString(message.content),
      metadata: message.metadata || {},
    });
    if (!payload) return;

    await sendFamilyNotification({
      familyId,
      excludedUserIds: senderId ? [senderId] : [],
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: {
        familyId,
        messageId,
        route: payload.route,
        type: payload.type,
      },
    });
  },
);

exports.notifyOnCalendarEventCreated = onDocumentCreated(
  "families/{familyId}/events/{eventId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const familyId = event.params.familyId;
    const eventId = event.params.eventId;
    const calendarEvent = snapshot.data();
    if (!calendarEvent) return;

    if (asString(calendarEvent.externalSource) === "google_calendar") {
      logger.debug("Skip notification for imported Google Calendar event", {
        familyId,
        eventId,
      });
      return;
    }

    const createdBy = asString(calendarEvent.createdBy);
    const actorName = await resolveActorName(familyId, createdBy);
    const payload = buildEventNotification({
      title: asString(calendarEvent.title),
      type: asString(calendarEvent.type) || "general",
      isAllDay: Boolean(calendarEvent.isAllDay),
      startAt: calendarEvent.startAt?.toDate?.(),
    });
    if (!payload) return;

    await sendFamilyNotification({
      familyId,
      excludedUserIds: createdBy ? [createdBy] : [],
      notification: {
        title: `${actorName}님이 일정을 추가했어요`,
        body: payload.body,
      },
      data: {
        eventId,
        familyId,
        route: payload.route,
        type: payload.type,
      },
    });
  },
);

exports.notifyOnTodoCreated = onDocumentCreated(
  "families/{familyId}/todos/{todoId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const familyId = event.params.familyId;
    const todoId = event.params.todoId;
    const todo = snapshot.data();
    if (!todo) return;

    const createdBy = asString(todo.createdBy);
    const actorName = await resolveActorName(familyId, createdBy);
    const payload = buildTodoNotification({
      title: asString(todo.title),
    });
    if (!payload) return;

    await sendFamilyNotification({
      familyId,
      excludedUserIds: createdBy ? [createdBy] : [],
      notification: {
        title: `${actorName}님이 할 일을 추가했어요`,
        body: payload.body,
      },
      data: {
        familyId,
        todoId,
        route: payload.route,
        type: payload.type,
      },
    });
  },
);

exports.notifyOnCartItemCreated = onDocumentCreated(
  "families/{familyId}/cart/{itemId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const familyId = event.params.familyId;
    const itemId = event.params.itemId;
    const item = snapshot.data();
    if (!item) return;

    const addedBy = asString(item.addedBy);
    const actorName = await resolveActorName(familyId, addedBy);
    const payload = buildCartNotification({
      name: asString(item.name),
      quantity: Number(item.quantity) || 1,
    });
    if (!payload) return;

    await sendFamilyNotification({
      familyId,
      excludedUserIds: addedBy ? [addedBy] : [],
      notification: {
        title: `${actorName}님이 장보기 항목을 추가했어요`,
        body: payload.body,
      },
      data: {
        familyId,
        itemId,
        route: payload.route,
        type: payload.type,
      },
    });
  },
);

exports.notifyOnExpenseCreated = onDocumentCreated(
  "families/{familyId}/expenses/{expenseId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const familyId = event.params.familyId;
    const expenseId = event.params.expenseId;
    const expense = snapshot.data();
    if (!expense) return;

    const createdBy = asString(expense.createdBy);
    const actorName = await resolveActorName(familyId, createdBy);
    const payload = buildExpenseNotification({
      title: asString(expense.title),
      amount: Number(expense.amount) || 0,
    });
    if (!payload) return;

    await sendFamilyNotification({
      familyId,
      excludedUserIds: createdBy ? [createdBy] : [],
      notification: {
        title: `${actorName}님이 지출을 기록했어요`,
        body: payload.body,
      },
      data: {
        expenseId,
        familyId,
        route: payload.route,
        type: payload.type,
      },
    });
  },
);

async function sendFamilyNotification({
  familyId,
  excludedUserIds = [],
  notification,
  data,
}) {
  const recipients = await collectRecipientTokens(familyId, excludedUserIds);
  if (recipients.length === 0) {
    logger.debug("No recipient tokens for family notification", {
      familyId,
      excludedUserIds,
    });
    return;
  }

  const message = {
    notification,
    data: stringifyData(data),
    tokens: recipients.map((recipient) => recipient.token),
    android: {
      priority: "high",
    },
    apns: {
      headers: {
        "apns-priority": "10",
      },
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
  };

  const response = await messaging.sendEachForMulticast(message);
  if (response.failureCount === 0) {
    return;
  }

  const invalidTokensByUser = new Map();
  response.responses.forEach((result, index) => {
    if (result.success) return;

    const errorCode = result.error?.code;
    const failedRecipient = recipients[index];
    logger.warn("Failed to send family notification", {
      familyId,
      token: failedRecipient?.token,
      userId: failedRecipient?.uid,
      errorCode,
      errorMessage: result.error?.message,
    });

    if (!failedRecipient || !INVALID_TOKEN_ERRORS.has(errorCode)) {
      return;
    }

    const existing = invalidTokensByUser.get(failedRecipient.uid) ?? [];
    existing.push(failedRecipient.token);
    invalidTokensByUser.set(failedRecipient.uid, existing);
  });

  await Promise.all(
    Array.from(invalidTokensByUser.entries()).map(([uid, tokens]) =>
      removeTokensFromUser(uid, tokens),
    ),
  );
}

async function collectRecipientTokens(familyId, excludedUserIds) {
  const familySnap = await db.doc(`families/${familyId}`).get();
  if (!familySnap.exists) return [];

  const memberIds = ensureStringList(familySnap.get("memberIds"));
  const targetIds = memberIds.filter((uid) => !excludedUserIds.includes(uid));
  if (targetIds.length === 0) return [];

  const userSnaps = await Promise.all(
    targetIds.map((uid) => db.doc(`users/${uid}`).get()),
  );

  const seenTokens = new Set();
  const recipients = [];

  for (const userSnap of userSnaps) {
    if (!userSnap.exists) continue;

    const tokens = ensureStringList(userSnap.get("fcmTokens"));
    for (const token of tokens) {
      if (seenTokens.has(token)) continue;
      seenTokens.add(token);
      recipients.push({
        uid: userSnap.id,
        token,
      });
    }
  }

  return recipients;
}

async function removeTokensFromUser(uid, tokens) {
  if (!uid || tokens.length === 0) return;

  await db.doc(`users/${uid}`).set(
    {
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokens),
    },
    { merge: true },
  );
}

async function resolveActorName(familyId, uid) {
  if (!uid) return "가족";

  const familyMemberSnap = await db.doc(`families/${familyId}/members/${uid}`).get();
  if (familyMemberSnap.exists) {
    const nickname = asString(familyMemberSnap.get("nickname"));
    if (nickname) return nickname;
  }

  const userSnap = await db.doc(`users/${uid}`).get();
  if (!userSnap.exists) return "가족";

  const displayName = asString(userSnap.get("displayName"));
  if (displayName) return displayName;

  return asString(userSnap.get("email")) || "가족";
}

function stringifyData(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, String(value)]),
  );
}

function ensureStringList(value) {
  if (!Array.isArray(value)) return [];
  return value.filter((item) => typeof item === "string" && item.length > 0);
}

function asString(value) {
  return typeof value === "string" ? value : "";
}

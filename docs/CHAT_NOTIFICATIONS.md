# Chat push notifications

How to send and handle push notifications when someone sends a message in 1:1 or group chat.

---

## Overview

1. **Sender** writes the message to Firestore (as today).
2. **Server** (your backend or a Firebase Cloud Function) must send an FCM message to the **recipient(s)** so they get a push when the app is in background or closed.
3. **App** receives the notification and on **tap** opens the correct chat (1:1 or group).

The app cannot send FCM to another device itself; only a server (with FCM Server Key / service account) can. So you need either:

- **Firebase Cloud Functions**: trigger on Firestore writes to `conversations/{id}/messages` or `groups/{id}/messages`, resolve recipient FCM token(s), and send FCM.
- **Backend API**: when the client sends a message (or after Firestore write), the client or a Cloud Function calls your backend; the backend sends FCM to the recipient(s).

---

## 1. FCM token storage

The app already gets an FCM token and tries to save it via `NotificationRepository.saveFCMToken(userId, token)` (currently to Firestore `users/{userId}`). For chat notifications you need the **recipient’s FCM token** on the server side. Options:

- **Firestore** `users/{userId}` with field `fcmToken` (and optional `fcmTokenUpdatedAt`). Your Cloud Function or backend reads this when sending a chat notification.
- **Backend** store: app sends the token to your API (e.g. `PUT /me/fcm-token`), backend stores it per user and uses it when sending chat notifications.

Use the same `userId` as in your auth (e.g. MongoDB id) so the server can look up the token by recipient id.

---

## 2. Who sends the FCM message?

### Option A: Firebase Cloud Function (recommended)

- **Trigger**: `onCreate` on `conversations/{conversationId}/messages/{messageId}` and `groups/{groupId}/messages/{messageId}`.
- **Logic**:
  - 1:1: from `conversationId` load the conversation doc to get `participantIds`; the recipient is the one who is not the sender.
  - Group: from `groups/{groupId}` (or your backend) get member list; recipients are all members except the sender (or use a dedicated members subcollection).
- Get each recipient’s FCM token (from Firestore `users/{recipientId}.fcmToken` or your backend).
- Send FCM **data** message (and optionally **notification** for heads-up) with payload below.

### Option B: Backend API

- After the client writes the message to Firestore, it calls e.g. `POST /chat/notify` with `conversationId` or `groupId`, `messageId`, `senderId`, `preview`.
- Backend looks up recipient(s) and their FCM tokens, then sends FCM.

---

## 3. FCM payload format (for chat)

Send a **data** message (so the app can open the right screen even when killed). Optional **notification** block for title/body in the system tray.

**1:1 chat**

```json
{
  "data": {
    "type": "chat_1_1",
    "conversationId": "<conversationId>",
    "senderId": "<senderId>",
    "senderName": "Andrea",
    "senderProfilePicture": "https://...",
    "messagePreview": "Hello!",
    "action": "Andrea: Hello!"
  },
  "notification": {
    "title": "Andrea",
    "body": "Hello!"
  }
}
```

**Group chat**

```json
{
  "data": {
    "type": "chat_group",
    "groupId": "<groupId>",
    "groupName": "Mums Group",
    "senderId": "<senderId>",
    "senderName": "Andrea",
    "messagePreview": "Hello everyone!",
    "action": "Andrea in Mums Group: Hello everyone!"
  },
  "notification": {
    "title": "Mums Group",
    "body": "Andrea: Hello everyone!"
  }
}
```

- **type**: `chat_1_1` or `chat_group` so the app can choose 1:1 vs group screen.
- **conversationId** (1:1): required to open the right conversation.
- **groupId** (group): required to open the right group chat.
- **senderName** / **messagePreview** / **action**: for in-app display and notification body.

---

## 4. App-side handling (implemented)

- **Foreground**: `FirebaseMessaging.onMessage` is listened to (can extend to show in-app banner for chat).
- **Tap (background)**: `FirebaseMessaging.onMessageOpenedApp` calls the registered callback; the app parses `data.type`, `data.conversationId` / `data.groupId` and navigates via `rootNavigatorKey.currentContext`.
- **Tap (app was terminated)**: `getInitialMessage()` stores payload in `FCMService.pendingNotificationData`; after the first frame, `KINSApp` calls `FCMService.flushPendingNotificationTap` with the same handler so navigation runs with a valid context.
- **Navigation**:
  - **chat_1_1**: push `chatConversationPath(conversationId)` with `extra: { otherUserId, otherUserName, otherUserAvatarUrl }` (from senderId, senderName, senderProfilePicture).
  - **chat_group**: push `groupConversationPath(groupId)` with `GroupConversationArgs(groupId, name, description, imageUrl)`.

The app uses a **global navigator key** (`rootNavigatorKey` in `app_router.dart`) so the FCM callback can navigate without a widget BuildContext.

---

## 5. Summary checklist

| Step | Responsibility |
|------|----------------|
| Store FCM token per user | App (already) + Firestore or backend |
| Detect new message | Cloud Function (Firestore trigger) or backend (API call) |
| Resolve recipient(s) | Cloud Function or backend |
| Send FCM with payload above | Cloud Function or backend (FCM Admin SDK) |
| On tap, open 1:1 or group screen | App (navigator key + payload parsing) |

Once the server sends FCM with the payload above and the app handles tap (and optional initial message) as described, chat notifications will work end-to-end.

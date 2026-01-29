# Real-Time Chat with Firebase – Developer Guide

This guide explains how chat works in this app (WhatsApp-like: sent / delivered / seen) and **how we keep Firebase costs low**.

---

## 1. Message states (like WhatsApp)

| State      | Meaning |
|-----------|---------|
| **Sending** | Message is being sent (optimistic UI). |
| **Sent**    | Message is stored on Firebase (server received it). |
| **Delivered** | Recipient’s app has “received” the message (e.g. chat opened or message in view). |
| **Seen**     | Recipient has opened the chat and seen the message. |

We do **not** store “delivered” or “seen” on each message. We store **one timestamp per user per chat** and derive status from that (see below). That keeps writes low.

---

## 2. Firestore data model (cost-conscious)

### `chats` collection (one document per 1:1 conversation)

- `participantIds`: `[uid1, uid2]` (sorted so we can find 1:1 chat by two users)
- `lastMessageAt`, `lastMessageText`, `lastMessageSenderId` – for list preview
- `lastDeliveredAtBy`: `{ "uid1": Timestamp, "uid2": Timestamp }` – **last time that user “received” messages** (e.g. when they opened the chat or received in app)
- `lastSeenAtBy`: `{ "uid1": Timestamp, "uid2": Timestamp }` – **last time that user “read” the chat** (e.g. when they opened the chat)
- `createdAt`

### `chats/{chatId}/messages` subcollection (paginated)

- `senderId`, `text`, `createdAt`  
- **No** `delivered` or `seen` field per message.

**How we derive status (no extra writes per message):**

- **Sent:** message exists and has `createdAt`.
- **Delivered:** `message.createdAt <= lastDeliveredAtBy[otherUserId]`.
- **Seen:** `message.createdAt <= lastSeenAtBy[otherUserId]`.

When user A opens the chat we do **one write**: update `lastSeenAtBy[A]` and `lastDeliveredAtBy[A]` (or a single map). So: **1 write per “open chat”**, not per message.

---

## 3. How we keep Firebase cost low

### 3.1 Fewer reads

- **Paginate messages:** Load only the last N messages (e.g. 30), then “load more” on scroll. Don’t listen to the whole history.
- **Chat list:** Use a single query for “chats where I’m a participant”, ordered by `lastMessageAt`, with a limit (e.g. 50). One listener for the list.
- **Unread count:** Derive from `lastMessageAt` and `lastSeenAtBy[myUid]` (no extra collection).

### 3.2 Fewer writes

- **Delivery/seen:** Use `lastDeliveredAtBy` and `lastSeenAtBy` on the **chat document** only. When the user opens the chat, update these once (1 write per open), not per message.
- **Avoid updating every message:** Do not add “delivered”/“seen” fields to each message document.
- **Last message preview:** When sending a message, update the chat doc’s `lastMessageAt`, `lastMessageText`, `lastMessageSenderId` in the **same batch** as the message write, so it’s 1 batch write per send.

### 3.3 Listeners and scaling

- **Only one active chat listener:** When the user is in a conversation, attach a listener to `chats/{chatId}/messages` (with limit + orderBy). When they leave the screen, **detach** the listener so you don’t pay for ongoing reads.
- **Chat list:** One stream for “my chats” is usually acceptable; keep a reasonable limit.
- **Offline:** Firestore cache helps; reads from cache don’t count as billable reads after first load.

### 3.4 Security rules

- Restrict `chats` and `chats/{chatId}/messages` so users can read/write only if they are in `participantIds` (for chats) or participants of that chat.
- Validate `participantIds` and required fields on create/update to prevent abuse and bad data.

### 3.5 Optional: Realtime Database for presence

- For “online” or “typing” indicators, **frequent** updates can be cheaper in **Realtime Database** (billed on bandwidth) than in Firestore (billed per read/write). Consider RTDB only for presence if you need it and want to minimize cost.

---

## 4. What to implement as a developer

1. **Send message:** Write to `chats/{chatId}/messages` and update the chat doc’s last-message fields in one batch.
2. **Listen to messages:** Stream `chats/{chatId}/messages` with `orderBy('createdAt', descending: true).limit(30)`, and detach when leaving the screen.
3. **When user opens a chat:** Update `lastSeenAtBy[myUid]` and `lastDeliveredAtBy[myUid]` on the chat doc (e.g. both to `FieldValue.serverTimestamp()`).
4. **Display status (ticks):** For each message you sent, compare `message.createdAt` with `lastDeliveredAtBy[otherUserId]` and `lastSeenAtBy[otherUserId]` from the chat doc to show sent / delivered / seen.
5. **Chat list:** Stream `chats` where `participantIds` contains `myUid`, ordered by `lastMessageAt` descending, with limit. Show unread using `lastSeenAtBy[myUid]` vs `lastMessageAt`.

---

## 5. Quick reference: cost-saving checklist

- [ ] Message list is **paginated** (limit + load more).
- [ ] **One** listener per screen (list or conversation); remove listener when leaving.
- [ ] Delivery/seen stored only on **chat doc** (`lastDeliveredAtBy`, `lastSeenAtBy`), not per message.
- [ ] **One write** per “open chat” (mark delivered/seen), not per message.
- [ ] Last message updated in the **same batch** as the new message write.
- [ ] Security rules enforce **participants only** and validate input.

This structure gives you real-time chat with WhatsApp-like delivery and seen tracking while keeping Firebase usage (and cost) under control.

---

## 6. Firestore index required

For the chat list query you need a **composite index**:

- Collection: `chats`
- Fields: `participantIds` (Arrays), `lastMessageAt` (Descending)

Create it in Firebase Console → Firestore → Indexes, or add to `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "chats",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "participantIds", "order": "ASCENDING" },
        { "fieldPath": "lastMessageAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

---

## 7. Firestore security rules (chats)

Only participants of a chat should read/write it and its messages:

```javascript
// chats: only participants can read/write
match /chats/{chatId} {
  allow read, write: if request.auth != null
    && request.auth.uid in resource.data.participantIds;
  allow create: if request.auth != null
    && request.auth.uid in request.resource.data.participantIds;
  // messages subcollection
  match /messages/{messageId} {
    allow read, write: if request.auth != null
      && request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participantIds;
    allow create: if request.auth != null
      && request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participantIds;
  }
}
```

---

## 8. Quick “remember as developer” checklist

- **Real-time:** Use `streamMessages(chatId)` and `streamChat(chatId)`; **detach** when leaving the conversation screen to avoid extra reads.
- **Delivery/seen:** Stored only on the **chat doc** (`lastDeliveredAtBy`, `lastSeenAtBy`). When the user **opens the chat**, call `markDeliveredAndSeen(chatId, myUid)` once (one write).
- **Ticks:** For your sent messages, derive status from `messageStatusForSender(..., lastDeliveredAtBy, lastSeenAtBy)`; no per-message fields.
- **Cost:** Paginate messages (e.g. 30), one listener per screen, one write per “open chat” for delivered/seen, batch last-message update with send.
- **New 1:1 chat:** Use `getOrCreate1v1Chat(uid1, uid2)` then navigate to conversation with the returned `chatId`.

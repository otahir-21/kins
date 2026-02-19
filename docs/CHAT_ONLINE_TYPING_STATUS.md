# Chat: Online, Typing, Send/Deliver/Read Status

## Send / Deliver / Read status (implemented)

**How it works**

- The app does **not** store per-message delivery/read state in Firestore (to keep writes low). Instead it uses **conversation-level** timestamps on `conversations/{conversationId}`:
  - **`lastDeliveredAtBy`** – map of `userId → timestamp` (when that user last had the chat open / “delivered”).
  - **`lastSeenAtBy`** – map of `userId → timestamp` (when that user last saw the chat / “read”).
- When **you open** the 1:1 conversation screen, the app calls **`markDeliveredAndSeen(conversationId, myUserId)`**, which sets both `lastDeliveredAtBy` and `lastSeenAtBy` for you. That tells the other side “your messages are delivered and seen.”
- For **your own messages**, status is derived in the UI:
  - **Sent:** message is in Firestore; other user’s `lastDeliveredAtBy` is before message time → single or double grey tick.
  - **Delivered:** other user’s `lastDeliveredAtBy` ≥ message time → double grey tick.
  - **Seen:** other user’s `lastSeenAtBy` ≥ message time → double blue tick.
- Logic lives in **`messageStatusForSender()`** in `lib/models/chat_model.dart`. The 1:1 conversation screen watches the conversation doc (for `lastDeliveredAtBy` / `lastSeenAtBy`) and passes the computed status into the text bubble so ticks update in real time.

**Optional improvement:** Call **`markDelivered`** when the message is first visible on the other device (e.g. when the other app’s conversation screen is open and the message scrolls into view), and **`markSeen`** only when the user has actually read the thread. Right now both are updated when the user opens the chat.

---

## Typing indicator (not implemented)

**Possible approach with Firestore**

1. On the **conversation** doc `conversations/{conversationId}` add a field, e.g. **`typingBy`**: map of `userId → timestamp` (when that user last typed).
2. **When the user types** (with debounce, e.g. 300 ms):  
   `conversationRef.update({ 'typingBy.myUserId': FieldValue.serverTimestamp() })`
3. **When the user stops typing** (e.g. 2–3 s with no input) or leaves the screen:  
   `FirebaseFirestore.instance.runTransaction` or update to remove your key from `typingBy` (e.g. `FieldValue.delete()` for `typingBy.myUserId`).
4. **UI:** Listen to `streamConversation(conversationId)`. If `typingBy[otherUserId]` exists and is recent (e.g. &lt; 5 s), show “Andrea is typing…” under the app bar or above the input.

**Security:** Keep your existing rules; allow update on `conversations/{conversationId}` so each user can write only their own `typingBy.{userId}` if needed (or keep Option A and allow full update when `request.auth != null`).

---

## Online status (not implemented)

**Options**

1. **Firebase Realtime Database presence**  
   Use `.info/connected` and set a path like `presence/{userId}` to `true` when connected and remove it on disconnect. Your app would read `presence/{otherUserId}` to show “online” or “last seen”.
2. **Firestore**  
   A collection like `users_online/{userId}` with a field `lastSeenAt` (updated on a heartbeat or when the app goes to background). Other clients read this to show “last seen 5 min ago” or “online” if `lastSeenAt` is within the last ~1 minute. Requires security rules that allow read of other users’ online docs.
3. **Backend**  
   App sends a heartbeat (e.g. POST /me/presence) every 30 s when in foreground; backend stores last seen. Other clients get “online” or “last seen” via GET /users/:id (or a dedicated presence endpoint). No Firestore changes.

Once you choose one of these, you can show a green dot or “Online” / “Last seen …” in the 1:1 header next to the other user’s name.

# Firebase changes for Chat feature

Do these **in Firebase Console** (and optionally deploy via CLI) so chat works.

---

## 1. Firestore: composite index (required for chat list)

The chat list query uses `participantIds` + `lastMessageAt`, so Firestore needs a composite index.

### Use the link from the error (recommended)

If you see **"The query requires an index"** with a long URL in the logs:

1. Copy the **full URL** from the error (starts with `https://console.firebase.google.com/v1/r/project/.../indexes?create_composite=...`).
2. Paste it into a browser and open it (same Google account as Firebase).
3. Click **Create index**.
4. Wait until the index status is **Enabled** (can take 1–2 minutes).
5. Restart the app and open the Chat tab again.

Firestore sometimes expects a **collection group** index for this query. Creating the index from the error link ensures the correct scope and field order.

### If you created an index manually and it still fails

You may have created a **Collection**-scope index, but the SDK can ask for a **Collection group** index. Fix:

1. Use the **exact link** from the error message (see steps above), **or**
2. Create index manually with **Query scope: Collection group** (not "Collection"):
   - **Collection group ID:** `chats`
   - **Fields:** `participantIds` (Ascending), `lastMessageAt` (Descending)

---

## 2. Firestore: security rules for chat

Add rules so only **participants** of a chat can read/write that chat and its messages.

1. Go to **Firestore Database** → **Rules**.
2. **Add** the following block **inside** `match /databases/{database}/documents { ... }` (e.g. after the `posts` block, before the final `}`):

```javascript
    // Chats (1:1 conversations) – only participants can read/write
    match /chats/{chatId} {
      allow read, update, delete: if request.auth != null
        && request.auth.uid in resource.data.participantIds;
      allow create: if request.auth != null
        && request.auth.uid in request.resource.data.participantIds;
      match /messages/{messageId} {
        allow read, write: if request.auth != null
          && request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participantIds;
      }
    }
```

3. **Publish** the rules.

Your full rules file should still start with `rules_version = '2';` and `service cloud.firestore { ... }` and contain your existing `users`, `posts`, etc. — just add the `chats` block as above.

---

## 3. No other Firebase changes needed

- **Authentication:** Uses your existing Auth (e.g. phone). No change.
- **Realtime Database:** Not used for chat (we use Firestore only).
- **Cloud Functions:** Not required for basic chat.
- **Storage:** Not used for chat messages (text only).

---

## Checklist

| Step | Where | Action |
|------|--------|--------|
| 1 | Firestore → Indexes | Create composite index: `chats` — `participantIds` (Asc), `lastMessageAt` (Desc) |
| 2 | Firestore → Rules | Add the `chats` and `chats/{chatId}/messages` rules and Publish |

After 1 and 2, the chat list and conversation screens should work with Firebase.

---

## If you get "permission to perform specific operation"

1. **Replace the whole rules file** (easiest fix):
   - Open **FIRESTORE_SECURITY_RULES.md** in this project.
   - Copy the **entire** rules block (from `rules_version = '2';` down to the closing `}`).
   - In Firebase Console → **Firestore Database** → **Rules**, select all and paste (replace everything).
   - Click **Publish** and wait a few seconds.

2. **Check the debug console** when you tap "Start chat":
   - If you see **"Chat create error"** → the `chats` create rule is failing. Make sure the rules include the `chats` block and you clicked Publish.
   - If you see **"User details error (using fallback)"** → the app will still open the chat with name "User"; fix the `users` read rule so any authenticated user can read (see FIRESTORE_SECURITY_RULES.md).

3. **Users rule for chat**: The `users` collection must allow **read** for any authenticated user, e.g. `allow read: if isAuthenticated();` (so the app can load the other person’s name/photo for chat).

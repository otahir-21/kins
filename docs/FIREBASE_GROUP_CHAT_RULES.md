# Firebase Security Rules for Group Chat

Configure these in **Firebase Console → Firestore → Rules** and **Storage → Rules**.

---

**Backend:** `GET /api/v1/me/firebase-token` must return a Firebase **custom token** so the app can call `signInWithCustomToken`. With **Option A** rules below, any valid custom token (any `uid`) is enough; the app uses backend user id from `/me` for `participantIds` and sender ids in chat. You do **not** need to use Firebase UID or match backend user id in the token.

### Copy-paste: Group + 1:1 (Option A) – fixes “caller does not have permission”

The app does **not** write a `members` array to `groups/{groupId}` in Firestore, so rules that check `request.auth.uid in resource.data.members` will always deny. Use these rules instead (any signed-in user can read/write; backend controls who can open the app):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ----- Group chat (no members check; app doesn't write members to Firestore) -----
    match /groups/{groupId} {
      allow read, write: if request.auth != null;
      match /messages/{messageId} {
        allow read, write: if request.auth != null;
      }
    }

    // ----- 1:1 / conversations -----
    match /conversations/{conversationId} {
      allow read, write: if request.auth != null;
      match /messages/{messageId} {
        allow read, write: if request.auth != null;
      }
    }
  }
}
```

Paste in **Firebase Console → Firestore → Rules**, then **Publish**.  
Then create the composite index for the Chats list: collection `conversations`, fields `participantIds` (Array-contains), `updatedAt` (Descending).

## Firestore (detailed)

Structure: `groups/{groupId}` (optional doc) and `groups/{groupId}/messages/{messageId}`.

### Option A: Trust backend membership (simplest)

If only group members can open the group chat screen (backend enforces who sees the group list), you can allow any authenticated user to read/write messages for any group id:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /groups/{groupId}/messages/{messageId} {
      allow read, write: if request.auth != null;
    }
    match /groups/{groupId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Option B: Enforce membership in Firestore

If you mirror group membership into a document `groups/{groupId}` with field `members` (array of UIDs), use:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /groups/{groupId} {
      allow read: if request.auth != null && request.auth.uid in resource.data.members;
      allow write: if request.auth != null && request.auth.uid in resource.data.members;
      match /messages/{messageId} {
        allow read, write: if request.auth != null
          && request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.members;
      }
    }
  }
}
```

To use Option B, the app or a Cloud Function must create/update `groups/{groupId}` with:

```json
{
  "members": ["backendUserId1", "backendUserId2"],
  "lastMessage": { "senderId": "...", "content": "...", "createdAt": ... }
}
```

Backend user IDs must match the Firebase UID after custom token sign-in (backend should issue custom tokens with `uid` = backend user id).

---

## Storage

Path: `chat/{groupId}/{filename}`.

Allow authenticated users to upload and read under the chat path (optionally restrict by group membership if you have it in Firestore):

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /chat/{groupId}/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

If you use Option B above and want to restrict Storage by membership, you’d need to read Firestore from Storage rules (not all Firebase projects support that). For most cases, `request.auth != null` is enough if only group members can open the chat screen.

---

# 1:1 (Direct) Chat

Structure: `conversations/{conversationId}` and `conversations/{conversationId}/messages/{messageId}`.  
`conversationId` = sorted join of the two **backend user ids** (from `/me`), e.g. `uid1_uid2` with smaller id first. Same pattern as group chat: use custom token for auth; app uses backend user id for `participantIds` and `senderId`.

## Firestore index

Create a composite index for the Chats list query:

- Collection: `conversations`
- Fields: `participantIds` (Array-contains), `updatedAt` (Descending)

In Firebase Console: Firestore → Indexes → Composite → Add index.

## Firestore security rules (same idea as group chat)

**Option A – trust backend (recommended, same as group chat)**  
If only valid app users can open the chat screen (backend controls who gets a custom token), allow any authenticated user to read/write conversations and messages:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ... group rules (groups/, groups/{groupId}/messages) above ...

    match /conversations/{conversationId} {
      allow read, write: if request.auth != null;
      match /messages/{messageId} {
        allow read, write: if request.auth != null;
      }
    }
  }
}
```

**Option B – enforce participants in rules**  
Only if you want Firestore to enforce that `request.auth.uid` is one of the two participants (requires custom token `uid` = backend user id):

```
match /conversations/{conversationId} {
  allow create: if request.auth != null
    && request.auth.uid in request.resource.data.get('participantIds', []);
  allow read, update, delete: if request.auth != null
    && request.auth.uid in resource.data.get('participantIds', []);
  match /messages/{messageId} {
    allow read, write: if request.auth != null
      && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.get('participantIds', []);
  }
}
```

## Storage (1:1 media)

Path: `chat/conversations/{conversationId}/{filename}`. Restrict to the two participants by checking that `request.auth.uid` is one of the IDs in the path (you cannot split in Storage rules easily; a simple approach is to allow any authenticated user to read/write under `chat/conversations/` if you rely on the app only opening conversations the user is in):

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /chat/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

Tighter Storage rules would require a custom token claim or a separate Firestore lookup; the above matches the group chat approach.

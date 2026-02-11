# Firebase (Firestore) Data Reference for MongoDB Migration

This document describes **what data is stored in Firestore** and **how** (collections, document structure, and usage). Use it to design MongoDB collections and APIs.

---

## 1. Top-level collections

| Collection    | Document ID        | Purpose |
|---------------|--------------------|---------|
| `users`       | Firebase Auth UID  | User profile and embedded/linked data |
| `usernames`   | Normalized username (lowercase, no spaces) | Uniqueness lookup: `{ userId }` |
| `emails`      | Normalized email (lowercase)               | Uniqueness lookup: `{ userId }` |
| `phones`      | Normalized phone (digits only)             | Uniqueness lookup: `{ userId }` |
| `interests`   | Auto ID            | Master list of interest options |
| `posts`       | Auto ID            | Feed posts (text, image, video, poll) |
| `chats`       | `{uid1}_{uid2}` (sorted) | 1:1 chat conversations |

---

## 2. `users` collection

**Document ID:** Firebase Auth UID (string).

**Fields (merge/set over time):**

| Field               | Type     | Description |
|---------------------|----------|-------------|
| `name`              | string   | Full name |
| `email`             | string   | Email (normalized in `emails` for uniqueness) |
| `phoneNumber`       | string   | Phone (normalized in `phones` for uniqueness) |
| `username`          | string?  | Display username (claimed in `usernames`) |
| `dateOfBirth`       | string   | ISO8601 date (e.g. `yyyy-MM-dd`) |
| `updatedAt`         | timestamp| Server timestamp |
| `profilePictureUrl` or `profilePicture` | string? | Avatar URL |
| `bio`               | string?  | User bio (set via `set` merge) |
| `status`             | string?  | Motherhood status (e.g. Expecting Mother, New Mother) |
| `gender`             | string?  | |
| `documentUrl`       | string?  | Link to uploaded document (e.g. from Bunny) |
| `createdAt`         | timestamp? | |
| `interests`         | array    | List of interest document IDs (strings) |
| `interestsUpdatedAt`| timestamp? | |
| `fcmToken`          | string?  | FCM device token for push |
| `fcmTokenUpdatedAt` | timestamp? | |
| `followerCount`     | number   | Denormalized count (updated on follow/unfollow) |
| `followingCount`    | number   | Denormalized count |
| `location`          | map      | See below |

**`location` map (embedded in user doc):**

| Field       | Type     | Description |
|------------|----------|-------------|
| `latitude`  | number   | |
| `longitude` | number  | |
| `updatedAt` | timestamp | |
| `isVisible` | boolean | Whether shown on “nearby” map |

**How it’s used:**

- **Writes:** `set(..., SetOptions(merge: true))` or `update(...)` for profile, status, bio, location, interests, FCM token, follower/following counts.
- **Reads:** By `doc(uid).get()`, or query by `phoneNumber` (for post-auth lookup). Nearby kins: query `users` where `location.isVisible == true`, then filter in app by distance.

---

## 3. User subcollections (under `users/{userId}`)

### 3.1 `users/{userId}/following`

**Document ID:** Target user UID (who I follow).

**Fields:**

| Field    | Type     |
|----------|----------|
| `addedAt`| timestamp|

**How:** One doc per followed user. Used for “who I follow” list and to check `isFollowing`.

---

### 3.2 `users/{userId}/followers`

**Document ID:** Follower’s UID (who follows me).

**Fields:**

| Field    | Type     |
|----------|----------|
| `addedAt`| timestamp|

**How:** One doc per follower. Used for “my followers” list. Counts kept on `users` doc (`followerCount`, `followingCount`).

---

### 3.3 `users/{userId}/notifications`

**Document ID:** Auto ID (or notification ID from FCM/service).

**Fields:**

| Field               | Type     | Description |
|---------------------|----------|-------------|
| `senderId`          | string   | User who triggered the notification |
| `senderName`        | string   | |
| `senderProfilePicture` | string? | |
| `type`              | string   | e.g. `liked_post`, `commented_post`, `followed_you`, `message` |
| `action`            | string   | Human-readable text |
| `timestamp`         | timestamp| |
| `relatedPostId`     | string?  | |
| `postThumbnail`     | string?  | |
| `read`              | boolean  | Default false |

**How:** Queried by `userId`, ordered by `timestamp` desc; unread count by `read == false`.

---

### 3.4 `users/{userId}/documents`

**Document ID:** Auto ID (`add()`).

**Fields:**

| Field       | Type     | Description |
|------------|----------|-------------|
| `url`      | string   | Bunny CDN (or other) file URL |
| `fileName` | string   | e.g. `{userId}_{timestamp}.pdf` |
| `uploadedAt` | timestamp | |
| `size`    | number   | File size in bytes |

**How:** One doc per uploaded document (e.g. PDF). File is stored in Bunny CDN; Firestore holds metadata.

---

## 4. `interests` collection

**Document ID:** Auto ID.

**Fields:**

| Field      | Type     | Description |
|------------|----------|-------------|
| `name`     | string   | Display name |
| `isActive` | boolean  | If false, excluded from app (query `isActive == true`) |
| `createdAt`| timestamp? | |
| `updatedAt`| timestamp? | |

**How:** Read with `where('isActive', isEqualTo: true).orderBy('name')`. User’s selected IDs are stored in `users.interests` (array of interest doc IDs).

---

## 5. `posts` collection

**Document ID:** Auto ID.

**Fields:**

| Field           | Type     | Description |
|-----------------|----------|-------------|
| `authorId`      | string   | User UID |
| `authorName`    | string   | |
| `authorPhotoUrl`| string?  | |
| `type`          | string   | `text`, `image`, `video`, `poll` |
| `text`          | string   | Body text (can be empty) |
| `mediaUrl`      | string?  | URL (e.g. Bunny CDN) for image/video |
| `thumbnailUrl`  | string?  | |
| `topics`        | array    | List of topic strings |
| `likesCount`    | number   | Denormalized |
| `commentsCount` | number   | Denormalized |
| `createdAt`     | timestamp| |
| `updatedAt`     | timestamp| |
| `poll`          | map?     | Present when `type == 'poll'` — see below |

**`poll` map (when type is poll):**

| Field        | Type   | Description |
|--------------|--------|-------------|
| `question`   | string | |
| `options`    | array  | Each: `{ text, index, count }` |
| `totalVotes` | number | |
| `endTime`    | string?| ISO8601 |

**Subcollection:** `posts/{postId}/votes` — one doc per user who voted on a poll. Document ID = `userId`. Fields: `optionIndex` (int), `votedAt` (timestamp).

**How:**

- Feed: `posts` ordered by `createdAt` desc, limit 50.
- Profile: `posts` where `authorId == uid`, limit 50.
- Poll vote: read/write `posts/{postId}/votes/{userId}`; update `posts/{postId}.poll` options and `totalVotes` in a transaction.
- Like: `update` to increment `likesCount` on the post doc.

---

## 6. `chats` collection

**Document ID:** `{uid1}_{uid2}` (both UIDs sorted, e.g. `abc123_def456`).

**Fields:**

| Field              | Type     | Description |
|--------------------|----------|-------------|
| `participantIds`   | array    | [uid1, uid2] (sorted) |
| `lastMessageAt`    | timestamp| For list ordering |
| `lastMessageText`  | string   | Preview |
| `lastMessageSenderId` | string? | |
| `lastDeliveredAtBy`| map      | `{ userId: timestamp }` for delivery ticks |
| `lastSeenAtBy`     | map      | `{ userId: timestamp }` for read ticks |
| `createdAt`        | timestamp| |

**Subcollection:** `chats/{chatId}/messages`

**Document ID:** Auto ID.

**Fields:**

| Field     | Type     |
|----------|----------|
| `senderId` | string |
| `text`     | string |
| `createdAt`| timestamp |

**How:**

- Get-or-create 1:1 chat by deterministic `chatId` from two UIDs.
- Chat list: query `chats` where `participantIds` array-contains current user, then sort by `lastMessageAt` in app.
- Messages: `chats/{chatId}/messages` orderBy `createdAt` desc, limit 30.
- Send message: add message doc + update chat doc `lastMessageAt`, `lastMessageText`, `lastMessageSenderId`.
- Delivery/seen: update `chats/{chatId}` with `lastDeliveredAtBy.{userId}` and/or `lastSeenAtBy.{userId}`.

---

## 7. Summary: Firestore layout

```
users/{uid}                    # Profile, location, counts, interests, FCM
  ├── following/{targetUid}    # I follow them
  ├── followers/{followerUid} # They follow me
  ├── notifications/{notifId}  # Push/in-app notifications
  └── documents/{docId}        # Uploaded file metadata (file on Bunny)

usernames/{normalizedUsername} # { userId } — uniqueness
emails/{normalizedEmail}       # { userId } — uniqueness
phones/{normalizedPhone}       # { userId } — uniqueness

interests/{interestId}         # Master list (name, isActive)

posts/{postId}                 # Feed/post content
  └── votes/{userId}           # Poll vote per user

chats/{uid1_uid2}              # 1:1 chat metadata
  └── messages/{messageId}    # Chat messages
```

---

## 8. MongoDB mapping hints

- **One Firestore collection → one MongoDB collection** (or one per logical entity). Subcollections can stay as separate collections (e.g. `notifications` with `userId`) or embedded where it fits (e.g. `users.following` as array of UIDs + optional metadata).
- **Lookups:** `usernames` / `emails` / `phones` → same idea in MongoDB: one collection per lookup, doc id = normalized value, field `userId`. Or unique indexes on `users.username`, `users.email`, `users.phoneNumber`.
- **Denormalized counts:** Keep `followerCount` / `followingCount` on user; update on follow/unfollow. Same for `likesCount` / `commentsCount` on posts if you use them.
- **Timestamps:** Firestore `FieldValue.serverTimestamp()` → store as MongoDB `Date` (e.g. `new Date()` or server timestamp).
- **Poll votes:** Firestore `posts/{id}/votes/{userId}` → MongoDB collection `post_votes` with `{ postId, userId, optionIndex, votedAt }` or embed in post doc if you prefer.
- **Chat messages:** Either separate `messages` collection with `chatId` + `createdAt`, or embed in chat doc (with size/count limits per chat).

Use this reference to define your MongoDB schemas and migration scripts from existing Firestore exports.

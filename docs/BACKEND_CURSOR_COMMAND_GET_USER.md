# Backend GET /users/:userId and Flutter app

The backend **GET /api/v1/users/:userId** now includes **displayName** (name → username → "User"). The Flutter app uses **user.displayName** when present, otherwise falls back to name → username → "User" for the chat list and conversation header.

---

## Copy-paste this as your Cursor prompt

```
Add or fix the API endpoint so the Flutter app can show the other user’s name in chat instead of "User".

Requirements:

1. Endpoint: GET /api/v1/users/:userId
   - :userId is the MongoDB user id (e.g. 6995d74b3134a59d48265b4b).
   - Require Authorization: Bearer <JWT> (authenticated).

2. Response shape (exactly what the app expects):
   {
     "success": true,
     "user": {
       "id": "<userId>",        // or "_id" – same as :userId
       "name": "Andrea AMA",     // optional but required for display name; can be null
       "username": "andrea_ama", // optional; app uses as fallback if name is empty
       "profilePictureUrl": "https://...",  // optional
       "bio": "...",            // optional
       "followerCount": 0,      // optional, number
       "followingCount": 0,     // optional, number
       "isFollowedByMe": false  // optional, boolean
     }
   }

3. The app uses this for chat: it calls GET /users/:userId and reads res.user.name and res.user.username. If success is not true or res.user is missing, the app shows "User". So return at least one of name or username (prefer name, fallback to username) so the chat list and conversation header show the correct label.

4. Auth: only allow the request if the JWT is valid. Return the public profile of the user identified by :userId (no need to restrict by relationship unless your product requires it).
```

---

## What the Flutter app does

- **URL:** `GET {API_V1_BASE_URL}/users/{userId}` (e.g. `https://kins-crm.vercel.app/api/v1/users/6995d74b3134a59d48265b4b`).
- **Headers:** `Authorization: Bearer <JWT>`, `Content-Type: application/json`.
- **Parsing:** Expects `response.success === true` and `response.user` as an object. Reads `user.id` or `user._id`, `user.name`, `user.username`, `user.profilePictureUrl`. Display name = `name` if present, else `username`, else `"User"`.

If the backend already has a different path (e.g. `/users/profile/:userId` or `/api/users/:id`), either add this exact route or tell the Flutter side the correct path and we can change the app to call that instead.

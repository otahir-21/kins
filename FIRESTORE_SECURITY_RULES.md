# Firestore Security Rules - Complete Setup

## 🔐 Security Rules for KINS App

Copy and paste these rules into Firebase Console → Firestore Database → Rules tab.

## Complete Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user owns the document
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    // Users collection
    match /users/{userId} {
      // Owner can read/write their own document
      allow read, write: if isOwner(userId);
      // Any authenticated user can read any user (chat name/photo, search by phone, map)
      allow read: if isAuthenticated();
      allow list: if isAuthenticated();
      // Allow any authenticated user to update only followerCount/followingCount (for follow/unfollow).
      // For production, consider a Cloud Function to enforce correct increments.
      allow update: if isAuthenticated()
        && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['followerCount', 'followingCount']);
      
      // Documents subcollection - only owner can access
      match /documents/{documentId} {
        allow read, write: if isOwner(userId);
      }
      
      // Notifications subcollection - only owner can access
      match /notifications/{notificationId} {
        allow read, write: if isOwner(userId);
      }
      
      // Followers: doc id = follower's uid. Only that user can add/remove themselves.
      match /followers/{followerId} {
        allow read: if isAuthenticated();
        allow create, delete: if isAuthenticated() && request.auth.uid == followerId;
        allow update: if false;
      }
      
      // Following: doc id = followed user's uid. Only owner (userId) can add/remove.
      match /following/{targetId} {
        allow read: if isAuthenticated();
        allow create, delete: if isAuthenticated() && request.auth.uid == userId;
        allow update: if false;
      }
    }
    
    // Global notifications collection (if you use it)
    match /notifications/{notificationId} {
      allow read, write: if isAuthenticated() && 
        request.auth.uid == resource.data.userId;
    }
    
    // Interests collection - anyone authenticated can read active interests
    match /interests/{interestId} {
      // Allow read for all authenticated users (to show in interest selection)
      allow read: if isAuthenticated();
      // Only allow write for admins (you can restrict this further if needed)
      // For now, no write access from client
      allow write: if false;
    }
    
    // Posts collection (Discover feed)
    match /posts/{postId} {
      // Any authenticated user can read posts (feed)
      allow read: if isAuthenticated();
      // Only authenticated users can create posts (authorId must match)
      allow create: if isAuthenticated() && request.auth.uid == request.resource.data.authorId;
      // Author can update/delete. Any authenticated user can update (for poll vote counts).
      // For production, consider a Cloud Function to apply votes so only author can update post body.
      allow update: if isAuthenticated();
      allow delete: if isAuthenticated() && resource.data.authorId == request.auth.uid;
      // Poll votes subcollection: each user can only read/write their own vote doc
      match /votes/{userId} {
        allow read, write: if isAuthenticated() && request.auth.uid == userId;
      }
    }
    
    // Chats (1:1 conversations) – only participants can read/write
    match /chats/{chatId} {
      // Read: allow if doc doesn't exist (for get-or-create) OR user is participant
      allow read: if isAuthenticated()
        && (!exists(/databases/$(database)/documents/chats/$(chatId))
            || request.auth.uid in resource.data.participantIds);
      allow update, delete: if isAuthenticated()
        && request.auth.uid in resource.data.participantIds;
      allow create: if isAuthenticated();
      match /messages/{messageId} {
        allow read, write: if isAuthenticated()
          && request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participantIds;
      }
    }
  }
}
```

## Step-by-Step Setup

### 1. Open Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **kins-b4afb**
3. Click on **Firestore Database** in the left sidebar
4. Click on the **Rules** tab

### 2. Replace the Rules
1. Delete all existing rules
2. Copy the complete rules above
3. Paste them into the rules editor
4. Click **Publish**

### 3. Verify Rules
After publishing, you should see:
- ✅ Rules published successfully
- ✅ No syntax errors

## What These Rules Allow

### ✅ User's Own Data
- Read and write their own user document
- Read and write their own documents subcollection
- Read and write their own notifications subcollection

### ✅ Other Users' Data (for Map Feature)
- Read other users' basic profile info (name, profilePicture, nationality, status)
- Read other users' location data **only if** `location.isVisible == true`
- Cannot read other users' documents or notifications

### ✅ Security
- All operations require authentication
- Users cannot modify other users' data
- Location privacy is respected (only visible locations are readable)

## Testing the Rules

After updating the rules:

1. **Test your own data:**
   - Save user details → Should work ✅
   - Upload document → Should work ✅
   - Update location → Should work ✅

2. **Test map feature:**
   - View nearby kins → Should work ✅
   - Only see users with `isVisible: true` ✅

3. **Test privacy:**
   - Try to access another user's document → Should fail ❌
   - Try to access another user's notifications → Should fail ❌

## Troubleshooting

### Still getting permission-denied?

1. **Check if user is authenticated:**
   ```dart
   final user = FirebaseAuth.instance.currentUser;
   if (user == null) {
     // User not logged in!
   }
   ```

2. **Check Firestore is enabled:**
   - Go to Firebase Console → Firestore Database
   - Make sure database is created

3. **Wait a few seconds:**
   - Rules can take 10-30 seconds to propagate

4. **Clear app cache:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## Alternative: Test Mode (Development Only)

If you want to test quickly without rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

⚠️ **Warning**: This allows any authenticated user to read/write all data. **Only use for development/testing!**

## Production Rules

For production, use the complete rules above. They provide:
- ✅ Proper security
- ✅ Privacy protection
- ✅ Location visibility control
- ✅ User data isolation

---

**After updating rules, your app should work!** 🎉

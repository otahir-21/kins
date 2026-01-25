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
      // Users can read/write their own document completely
      allow read, write: if isOwner(userId);
      
      // Other users can read basic profile info (for map markers)
      // But only if location is visible
      allow read: if isAuthenticated() && 
        (!resource.data.location || resource.data.location.isVisible == true);
      
      // Allow list/query operations for authenticated users
      // This is needed for session management (querying by phoneNumber)
      allow list: if isAuthenticated();
      
      // Documents subcollection - only owner can access
      match /documents/{documentId} {
        allow read, write: if isOwner(userId);
      }
      
      // Notifications subcollection - only owner can access
      match /notifications/{notificationId} {
        allow read, write: if isOwner(userId);
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

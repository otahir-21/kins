# Firestore Setup Guide

## ✅ Required Setup

You need to enable and configure **Cloud Firestore** in your Firebase project to save user details and document information.

## Step-by-Step Setup

### 1. Enable Cloud Firestore

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **kins-b4afb**
3. In the left sidebar, click on **Firestore Database**
4. Click **Create database**

### 2. Choose Database Mode

You'll be asked to choose a mode:

**For Development/Testing:**
- Select **Start in test mode** (allows read/write for 30 days)
- Click **Next**

**For Production (Recommended):**
- Select **Start in production mode**
- Click **Next**
- You'll need to set up security rules (see Security Rules section below)

### 3. Choose Location

1. Select a location for your database (choose the closest to your users)
   - Example: `us-central`, `europe-west`, `asia-southeast1`
2. Click **Enable**

### 4. Wait for Database Creation

- This takes 1-2 minutes
- You'll see "Cloud Firestore" in your Firebase Console when ready

## Database Structure

Your app will automatically create these collections:

### Main Collection: `users`

```
users/
  {userId}/                    // User's Firebase Auth UID
    name: string               // User's name
    gender: string             // User's gender (male/female/other)
    documentUrl: string?       // URL of uploaded document (optional)
    updatedAt: timestamp      // Last update time
```

### Subcollection: `users/{userId}/documents`

```
users/
  {userId}/
    documents/
      {documentId}/            // Auto-generated document ID
        url: string            // Document URL from Bunny CDN
        fileName: string       // Original file name
        uploadedAt: timestamp // Upload timestamp
        size: number          // File size in bytes
```

## Security Rules (Important!)

### For Development/Testing

If you started in test mode, you have 30 days before you need to set up rules.

### For Production

Update your Firestore Security Rules to secure your data:

1. Go to **Firestore Database** → **Rules** tab
2. Replace the default rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own data
    match /users/{userId} {
      // Allow read/write only if authenticated and it's their own document
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Allow users to add documents to their own documents subcollection
      match /documents/{documentId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

3. Click **Publish**

### What These Rules Do:

- ✅ Users can only read/write their own user document
- ✅ Users can only add documents to their own documents subcollection
- ✅ Requires authentication (user must be logged in)
- ✅ Prevents users from accessing other users' data

## Testing Firestore

After setup, test if it works:

1. Run your app: `flutter run`
2. Complete OTP verification
3. Fill in user details (name, gender, optional document)
4. Submit the form
5. Check Firebase Console → Firestore Database → Data tab
6. You should see:
   - A `users` collection
   - A document with your user ID
   - User details (name, gender, documentUrl if uploaded)
   - A `documents` subcollection if you uploaded a file

## Common Issues

### Error: "Cloud Firestore API has not been used"

**Solution:**
- Make sure you've enabled Firestore (Step 1-3 above)
- Wait a few minutes for the database to be fully created
- Restart your app

### Error: "Missing or insufficient permissions"

**Solution:**
- Check your Firestore Security Rules
- Make sure the user is authenticated
- Verify the rules allow the operation you're trying to perform

### Error: "PERMISSION_DENIED"

**Solution:**
- Your security rules are blocking the operation
- Check that you're using the correct user ID
- Verify the rules match the structure above

## Billing Note

- Firestore has a **free tier** (Spark Plan):
  - 50K reads/day
  - 20K writes/day
  - 20K deletes/day
  - 1 GB storage

- For most apps, this is sufficient for development and small-scale production
- Monitor usage in Firebase Console → Usage and billing

## Next Steps

Once Firestore is enabled:

1. ✅ Your app will automatically save user details
2. ✅ Document metadata will be stored in the documents subcollection
3. ✅ You can view all data in Firebase Console
4. ✅ Data persists even if the app is uninstalled

## Viewing Your Data

To view saved data:

1. Go to Firebase Console
2. Click **Firestore Database**
3. Click **Data** tab
4. Navigate to `users` collection
5. Click on a user document to see their details
6. Click on `documents` subcollection to see uploaded files

That's it! Your Firestore is now ready to use. 🎉

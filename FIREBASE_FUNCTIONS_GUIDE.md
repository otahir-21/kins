# Firebase Functions Guide for CRM Notification Integration

This guide explains how to set up Firebase Functions to send push notifications from your CRM to the KINS app.

## 📋 Prerequisites

1. Firebase project: `kins-b4afb`
2. Service Account JSON (already provided)
3. Node.js installed
4. Firebase CLI installed

## 🚀 Setup Steps

### 1. Install Firebase CLI

```bash
npm install -g firebase-tools
```

### 2. Login to Firebase

```bash
firebase login
```

### 3. Initialize Functions

```bash
cd your-project-root
firebase init functions
```

Select:
- ✅ JavaScript or TypeScript (your choice)
- ✅ Install dependencies

### 4. Install Dependencies

```bash
cd functions
npm install firebase-admin
```

### 5. Create Service Account File

Create `functions/serviceAccountKey.json` and paste your service account JSON:

```json
{
  "type": "service_account",
  "project_id": "kins-b4afb",
  "private_key_id": "50508bc2fd82fb1938ee1b696acd15cba7ba6086",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...",
  "client_email": "firebase-adminsdk-fbsvc@kins-b4afb.iam.gserviceaccount.com",
  ...
}
```

**⚠️ Important**: Add `serviceAccountKey.json` to `.gitignore`!

## 📝 Firebase Function Code

### File: `functions/index.js`

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'kins-b4afb',
});

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Send notification to a user
 * This function can be called from your CRM via HTTP
 */
exports.sendNotification = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  try {
    const {
      userId,
      senderId,
      senderName,
      senderProfilePicture,
      type,
      action,
      relatedPostId,
      postThumbnail,
    } = req.body;

    // Validate required fields
    if (!userId || !senderId || !senderName || !type || !action) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields',
      });
    }

    // Get user's FCM token
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return res.status(404).json({
        success: false,
        error: 'User not found',
      });
    }

    const fcmToken = userDoc.data()?.fcmToken;
    if (!fcmToken) {
      return res.status(400).json({
        success: false,
        error: 'User has no FCM token',
      });
    }

    // Generate notification ID
    const notificationId = `${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    // Create notification data
    const notificationData = {
      notificationId,
      senderId,
      senderName,
      senderProfilePicture: senderProfilePicture || null,
      type,
      action,
      relatedPostId: relatedPostId || null,
      postThumbnail: postThumbnail || null,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Save notification to Firestore
    await db
      .collection('users')
      .doc(userId)
      .collection('notifications')
      .doc(notificationId)
      .set({
        ...notificationData,
        read: false,
      });

    // Prepare FCM message
    const message = {
      token: fcmToken,
      notification: {
        title: senderName,
        body: action,
      },
      data: notificationData,
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    // Send FCM message
    const response = await messaging.send(message);
    console.log('✅ Notification sent:', response);

    return res.status(200).json({
      success: true,
      messageId: response,
      notificationId,
    });
  } catch (error) {
    console.error('❌ Error sending notification:', error);
    return res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

/**
 * Send notification to multiple users
 */
exports.sendBulkNotifications = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  try {
    const {
      userIds,
      senderId,
      senderName,
      senderProfilePicture,
      type,
      action,
      relatedPostId,
      postThumbnail,
    } = req.body;

    if (!userIds || !Array.isArray(userIds) || userIds.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'userIds must be a non-empty array',
      });
    }

    const results = [];
    const errors = [];

    for (const userId of userIds) {
      try {
        // Get user's FCM token
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists || !userDoc.data()?.fcmToken) {
          errors.push({ userId, error: 'User not found or no FCM token' });
          continue;
        }

        const fcmToken = userDoc.data().fcmToken;
        const notificationId = `${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

        // Save notification
        await db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .set({
            senderId,
            senderName,
            senderProfilePicture: senderProfilePicture || null,
            type,
            action,
            relatedPostId: relatedPostId || null,
            postThumbnail: postThumbnail || null,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            read: false,
          });

        // Send FCM
        const message = {
          token: fcmToken,
          notification: {
            title: senderName,
            body: action,
          },
          data: {
            notificationId,
            senderId,
            senderName,
            type,
            action,
          },
        };

        const response = await messaging.send(message);
        results.push({ userId, success: true, messageId: response });
      } catch (error) {
        errors.push({ userId, error: error.message });
      }
    }

    return res.status(200).json({
      success: true,
      results,
      errors,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});
```

## 🔧 Deploy Functions

```bash
firebase deploy --only functions
```

## 📡 Calling from CRM

### Single Notification

```bash
curl -X POST https://YOUR-REGION-kins-b4afb.cloudfunctions.net/sendNotification \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user_id_here",
    "senderId": "sender_user_id",
    "senderName": "Maria Toreen",
    "senderProfilePicture": "https://example.com/profile.jpg",
    "type": "liked_post",
    "action": "Liked your post",
    "relatedPostId": "post_123",
    "postThumbnail": "https://example.com/post.jpg"
  }'
```

### Bulk Notifications

```bash
curl -X POST https://YOUR-REGION-kins-b4afb.cloudfunctions.net/sendBulkNotifications \
  -H "Content-Type: application/json" \
  -d '{
    "userIds": ["user1", "user2", "user3"],
    "senderId": "sender_user_id",
    "senderName": "Maria Toreen",
    "type": "followed_you",
    "action": "Follows you"
  }'
```

## 📊 Notification Types

Supported notification types:
- `liked_post` - User liked a post
- `commented_post` - User commented on a post
- `followed_you` - User followed you
- `message` - New message received
- `post_mention` - Mentioned in a post
- `comment_reply` - Reply to your comment
- `group_invite` - Invited to a group
- `expert_reply` - Expert replied to your question

## 🔐 Security

1. **Add Authentication**: Require API key or Firebase Auth token
2. **Rate Limiting**: Implement rate limiting to prevent abuse
3. **Input Validation**: Validate all inputs
4. **Error Handling**: Proper error handling and logging

## 📝 Example: Enhanced Function with Auth

```javascript
exports.sendNotification = functions.https.onRequest(async (req, res) => {
  // Check API key
  const apiKey = req.headers['x-api-key'];
  if (apiKey !== 'YOUR_SECRET_API_KEY') {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  // ... rest of the code
});
```

## 🧪 Testing

1. Deploy function
2. Get a user's FCM token from Firestore
3. Call the function with test data
4. Check Firestore for saved notification
5. Verify notification appears in app

## 📱 App Integration

The app automatically:
- ✅ Requests notification permissions
- ✅ Gets FCM token on login
- ✅ Saves token to Firestore
- ✅ Receives and displays notifications
- ✅ Shows badge count on bell icon
- ✅ Groups notifications by date

## 🔄 Next Steps

1. Deploy Firebase Functions
2. Test with sample notification
3. Integrate with your CRM backend
4. Monitor function logs in Firebase Console
5. Set up error alerts

---

**Function URLs**: After deployment, you'll get URLs like:
- `https://us-central1-kins-b4afb.cloudfunctions.net/sendNotification`
- `https://us-central1-kins-b4afb.cloudfunctions.net/sendBulkNotifications`

Use these URLs in your CRM to send notifications!

# CRM Integration Guide - Complete Project Overview

## 📋 Table of Contents
1. [Project Overview](#project-overview)
2. [Firebase Configuration](#firebase-configuration)
3. [Data Structure & Collections](#data-structure--collections)
4. [Node.js Firebase Connection](#nodejs-firebase-connection)
5. [Available Data & Endpoints](#available-data--endpoints)
6. [CRM Integration Checklist](#crm-integration-checklist)

---

## 🎯 Project Overview

### App Name: KINS App
A Flutter mobile application with phone authentication, user profile management, and document upload functionality.

### Features Implemented:
1. ✅ **Phone Authentication** (Firebase Auth)
   - Phone number input with international format
   - OTP verification
   - User session management

2. ✅ **User Profile Management**
   - Name collection
   - Gender selection
   - Document upload (Emirates ID/Document ID - PDF)

3. ✅ **Document Storage**
   - Upload to Bunny CDN
   - Metadata stored in Firestore

4. ✅ **Data Persistence**
   - Firestore for user data
   - Local storage for app state

---

## 🔥 Firebase Configuration

### Project Details:
- **Project ID**: `kins-b4afb`
- **Project Number**: `476907563127`
- **Storage Bucket**: `kins-b4afb.firebasestorage.app`

### Firebase Services Used:
1. **Firebase Authentication**
   - Phone number authentication
   - OTP verification

2. **Cloud Firestore**
   - User profiles
   - Document metadata

### Firebase Web API Key:
```
AIzaSyBzpguBTGbg5b1lAR3ep4yNUKKk5N-MGdo
```

---

## 📊 Data Structure & Collections

### Firestore Collections

#### 1. `users` Collection

**Path**: `/users/{userId}`

**Document Structure**:
```javascript
{
  "name": "string",              // User's full name
  "gender": "string",             // "male" | "female" | "other"
  "documentUrl": "string | null", // URL to document on Bunny CDN (optional)
  "updatedAt": "timestamp",       // Server timestamp
  "phoneNumber": "string"         // User's phone number (from Auth)
}
```

**Example Document**:
```json
{
  "name": "John Doe",
  "gender": "male",
  "documentUrl": "https://my-kins-app.b-cdn.net/documents/user123_1234567890.pdf",
  "updatedAt": "2026-01-23T10:30:00Z",
  "phoneNumber": "+971507276823"
}
```

#### 2. `users/{userId}/documents` Subcollection

**Path**: `/users/{userId}/documents/{documentId}`

**Document Structure**:
```javascript
{
  "url": "string",           // Full URL to document on Bunny CDN
  "fileName": "string",       // Original file name
  "uploadedAt": "timestamp", // Server timestamp
  "size": "number"           // File size in bytes
}
```

**Example Document**:
```json
{
  "url": "https://my-kins-app.b-cdn.net/documents/YRl3exYNEARp6v3T8Dscy7WTYMI2_1769180835124.pdf",
  "fileName": "YRl3exYNEARp6v3T8Dscy7WTYMI2_1769180835124.pdf",
  "uploadedAt": "2026-01-23T10:30:00Z",
  "size": 245678
}
```

### Firebase Authentication Data

**User Object** (from Firebase Auth):
```javascript
{
  "uid": "string",                    // Unique user ID
  "phoneNumber": "string",             // Verified phone number
  "email": "string | null",            // Not used in this app
  "displayName": "string | null",     // Not used
  "photoURL": "string | null",        // Not used
  "emailVerified": "boolean",          // false
  "disabled": "boolean",              // false
  "metadata": {
    "creationTime": "timestamp",
    "lastSignInTime": "timestamp"
  },
  "providerData": [
    {
      "uid": "phone_number",
      "providerId": "phone",
      "phoneNumber": "string"
    }
  ]
}
```

---

## 🔌 Node.js Firebase Connection

### 1. Install Dependencies

```bash
npm init -y
npm install firebase-admin
npm install dotenv
```

### 2. Get Firebase Admin SDK Credentials

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **kins-b4afb**
3. Go to **Project Settings** (gear icon)
4. Click **Service Accounts** tab
5. Click **Generate New Private Key**
6. Download the JSON file
7. Save as `serviceAccountKey.json` (keep it secure!)

### 3. Initialize Firebase Admin SDK

**File: `firebase-config.js`**
```javascript
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'kins-b4afb',
  storageBucket: 'kins-b4afb.firebasestorage.app'
});

const db = admin.firestore();
const auth = admin.auth();

module.exports = { db, auth, admin };
```

### 4. Environment Variables (Optional)

**File: `.env`**
```env
FIREBASE_PROJECT_ID=kins-b4afb
FIREBASE_STORAGE_BUCKET=kins-b4afb.firebasestorage.app
```

**File: `firebase-config.js` (with env vars)**
```javascript
const admin = require('firebase-admin');
require('dotenv').config();

// Load service account from environment or file
const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT 
  ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)
  : require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: process.env.FIREBASE_PROJECT_ID || 'kins-b4afb',
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET || 'kins-b4afb.firebasestorage.app'
});

const db = admin.firestore();
const auth = admin.auth();

module.exports = { db, auth, admin };
```

---

## 📡 Available Data & Endpoints

### 1. Get All Users

```javascript
const { db } = require('./firebase-config');

async function getAllUsers() {
  try {
    const usersSnapshot = await db.collection('users').get();
    const users = [];
    
    usersSnapshot.forEach(doc => {
      users.push({
        id: doc.id,
        ...doc.data()
      });
    });
    
    return users;
  } catch (error) {
    console.error('Error getting users:', error);
    throw error;
  }
}
```

### 2. Get User by ID

```javascript
async function getUserById(userId) {
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      return null;
    }
    
    return {
      id: userDoc.id,
      ...userDoc.data()
    };
  } catch (error) {
    console.error('Error getting user:', error);
    throw error;
  }
}
```

### 3. Get User with Authentication Data

```javascript
const { db, auth } = require('./firebase-config');

async function getUserWithAuthData(userId) {
  try {
    // Get Firestore data
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.exists ? userDoc.data() : null;
    
    // Get Auth data
    const userRecord = await auth.getUser(userId);
    
    return {
      id: userId,
      firestore: userData,
      auth: {
        uid: userRecord.uid,
        phoneNumber: userRecord.phoneNumber,
        email: userRecord.email,
        disabled: userRecord.disabled,
        metadata: {
          creationTime: userRecord.metadata.creationTime,
          lastSignInTime: userRecord.metadata.lastSignInTime
        }
      }
    };
  } catch (error) {
    console.error('Error getting user with auth data:', error);
    throw error;
  }
}
```

### 4. Get User Documents

```javascript
async function getUserDocuments(userId) {
  try {
    const documentsSnapshot = await db
      .collection('users')
      .doc(userId)
      .collection('documents')
      .get();
    
    const documents = [];
    documentsSnapshot.forEach(doc => {
      documents.push({
        id: doc.id,
        ...doc.data()
      });
    });
    
    return documents;
  } catch (error) {
    console.error('Error getting documents:', error);
    throw error;
  }
}
```

### 5. Get Complete User Profile

```javascript
async function getCompleteUserProfile(userId) {
  try {
    // Get user data
    const user = await getUserWithAuthData(userId);
    
    // Get documents
    const documents = await getUserDocuments(userId);
    
    return {
      ...user,
      documents: documents
    };
  } catch (error) {
    console.error('Error getting complete profile:', error);
    throw error;
  }
}
```

### 6. Get All Users with Complete Data

```javascript
async function getAllUsersComplete() {
  try {
    const usersSnapshot = await db.collection('users').get();
    const users = [];
    
    for (const doc of usersSnapshot.docs) {
      const userId = doc.id;
      const userData = doc.data();
      const documents = await getUserDocuments(userId);
      
      // Get auth data
      let authData = null;
      try {
        const userRecord = await auth.getUser(userId);
        authData = {
          phoneNumber: userRecord.phoneNumber,
          creationTime: userRecord.metadata.creationTime,
          lastSignInTime: userRecord.metadata.lastSignInTime
        };
      } catch (error) {
        console.warn(`Could not get auth data for user ${userId}:`, error.message);
      }
      
      users.push({
        id: userId,
        ...userData,
        auth: authData,
        documents: documents
      });
    }
    
    return users;
  } catch (error) {
    console.error('Error getting all users:', error);
    throw error;
  }
}
```

### 7. Search Users by Name

```javascript
async function searchUsersByName(searchTerm) {
  try {
    const usersSnapshot = await db.collection('users').get();
    const users = [];
    
    usersSnapshot.forEach(doc => {
      const userData = doc.data();
      const name = (userData.name || '').toLowerCase();
      
      if (name.includes(searchTerm.toLowerCase())) {
        users.push({
          id: doc.id,
          ...userData
        });
      }
    });
    
    return users;
  } catch (error) {
    console.error('Error searching users:', error);
    throw error;
  }
}
```

### 8. Filter Users by Gender

```javascript
async function getUsersByGender(gender) {
  try {
    const usersSnapshot = await db
      .collection('users')
      .where('gender', '==', gender)
      .get();
    
    const users = [];
    usersSnapshot.forEach(doc => {
      users.push({
        id: doc.id,
        ...doc.data()
      });
    });
    
    return users;
  } catch (error) {
    console.error('Error filtering users:', error);
    throw error;
  }
}
```

### 9. Get Users with Documents

```javascript
async function getUsersWithDocuments() {
  try {
    const usersSnapshot = await db
      .collection('users')
      .where('documentUrl', '!=', null)
      .get();
    
    const users = [];
    usersSnapshot.forEach(doc => {
      users.push({
        id: doc.id,
        ...doc.data()
      });
    });
    
    return users;
  } catch (error) {
    console.error('Error getting users with documents:', error);
    throw error;
  }
}
```

### 10. Update User Data (CRM can update)

```javascript
async function updateUser(userId, updateData) {
  try {
    const userRef = db.collection('users').doc(userId);
    
    await userRef.update({
      ...updateData,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    return await getUserById(userId);
  } catch (error) {
    console.error('Error updating user:', error);
    throw error;
  }
}
```

---

## 📝 Complete Example: Express.js API

**File: `server.js`**
```javascript
const express = require('express');
const { db, auth } = require('./firebase-config');
const admin = require('firebase-admin');

const app = express();
app.use(express.json());

// Get all users
app.get('/api/users', async (req, res) => {
  try {
    const usersSnapshot = await db.collection('users').get();
    const users = [];
    
    for (const doc of usersSnapshot.docs) {
      const userId = doc.id;
      const userData = doc.data();
      
      // Get documents
      const docsSnapshot = await db
        .collection('users')
        .doc(userId)
        .collection('documents')
        .get();
      
      const documents = [];
      docsSnapshot.forEach(doc => {
        documents.push({ id: doc.id, ...doc.data() });
      });
      
      // Get auth data
      let authData = null;
      try {
        const userRecord = await auth.getUser(userId);
        authData = {
          phoneNumber: userRecord.phoneNumber,
          creationTime: userRecord.metadata.creationTime,
          lastSignInTime: userRecord.metadata.lastSignInTime
        };
      } catch (error) {
        // User might not exist in Auth
      }
      
      users.push({
        id: userId,
        ...userData,
        auth: authData,
        documents: documents
      });
    }
    
    res.json({ success: true, data: users });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get user by ID
app.get('/api/users/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    
    // Get documents
    const docsSnapshot = await db
      .collection('users')
      .doc(userId)
      .collection('documents')
      .get();
    
    const documents = [];
    docsSnapshot.forEach(doc => {
      documents.push({ id: doc.id, ...doc.data() });
    });
    
    // Get auth data
    let authData = null;
    try {
      const userRecord = await auth.getUser(userId);
      authData = {
        phoneNumber: userRecord.phoneNumber,
        creationTime: userRecord.metadata.creationTime,
        lastSignInTime: userRecord.metadata.lastSignInTime
      };
    } catch (error) {
      // User might not exist in Auth
    }
    
    res.json({
      success: true,
      data: {
        id: userDoc.id,
        ...userDoc.data(),
        auth: authData,
        documents: documents
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Search users
app.get('/api/users/search/:term', async (req, res) => {
  try {
    const { term } = req.params;
    const usersSnapshot = await db.collection('users').get();
    const users = [];
    
    usersSnapshot.forEach(doc => {
      const userData = doc.data();
      const name = (userData.name || '').toLowerCase();
      
      if (name.includes(term.toLowerCase())) {
        users.push({
          id: doc.id,
          ...userData
        });
      }
    });
    
    res.json({ success: true, data: users });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Update user
app.put('/api/users/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const updateData = req.body;
    
    const userRef = db.collection('users').doc(userId);
    await userRef.update({
      ...updateData,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    const updatedUser = await userRef.get();
    res.json({
      success: true,
      data: {
        id: updatedUser.id,
        ...updatedUser.data()
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`CRM API Server running on port ${PORT}`);
});
```

---

## ✅ CRM Integration Checklist

### Setup Tasks:
- [ ] Install Node.js and npm
- [ ] Create Node.js project
- [ ] Install Firebase Admin SDK
- [ ] Download Firebase service account key
- [ ] Initialize Firebase Admin SDK
- [ ] Test connection to Firestore
- [ ] Test connection to Firebase Auth

### Data Access:
- [ ] Implement get all users
- [ ] Implement get user by ID
- [ ] Implement get user documents
- [ ] Implement search functionality
- [ ] Implement filtering (by gender, document status, etc.)

### CRM Features:
- [ ] User list view
- [ ] User detail view
- [ ] Document viewer/download
- [ ] User search
- [ ] User filtering
- [ ] User statistics/dashboard
- [ ] Export user data (CSV/Excel)
- [ ] User update functionality

### Security:
- [ ] Secure service account key
- [ ] Implement API authentication
- [ ] Set up Firestore security rules
- [ ] Add rate limiting
- [ ] Add input validation

---

## 📊 Data Summary

### What Data is Available:

1. **User Profile Data** (Firestore):
   - Name
   - Gender
   - Document URL (if uploaded)
   - Last updated timestamp

2. **Authentication Data** (Firebase Auth):
   - User ID (UID)
   - Phone number
   - Account creation time
   - Last sign-in time
   - Account status (disabled/enabled)

3. **Document Metadata** (Firestore subcollection):
   - Document URL (Bunny CDN)
   - File name
   - Upload timestamp
   - File size

### Statistics You Can Calculate:

- Total number of users
- Users by gender
- Users with documents uploaded
- Users without documents
- New users per day/week/month
- Active users (based on last sign-in)
- Average document size
- Total storage used

---

## 🔐 Security Notes

1. **Service Account Key**: Keep `serviceAccountKey.json` secure, never commit to Git
2. **Environment Variables**: Use `.env` file for sensitive data
3. **Firestore Rules**: Ensure proper security rules are set
4. **API Authentication**: Add authentication to your CRM API endpoints
5. **Rate Limiting**: Implement rate limiting for API endpoints

---

## 📞 Support

For issues or questions:
- Check Firebase Console for data
- Review Firestore security rules
- Check service account permissions
- Verify Firebase project settings

---

**Last Updated**: January 23, 2026
**Project**: KINS App
**Firebase Project**: kins-b4afb

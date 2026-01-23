# Quick Start: Node.js Firebase Connection

## 🚀 Fast Setup (5 minutes)

### Step 1: Create Project
```bash
mkdir kins-crm
cd kins-crm
npm init -y
```

### Step 2: Install Dependencies
```bash
npm install firebase-admin express dotenv
```

### Step 3: Get Firebase Credentials
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Project: **kins-b4afb**
3. Settings (⚙️) → **Service Accounts**
4. Click **Generate New Private Key**
5. Save as `serviceAccountKey.json` in your project root

### Step 4: Create Firebase Config

**File: `firebase-config.js`**
```javascript
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'kins-b4afb'
});

const db = admin.firestore();
const auth = admin.auth();

module.exports = { db, auth };
```

### Step 5: Test Connection

**File: `test.js`**
```javascript
const { db } = require('./firebase-config');

async function test() {
  try {
    const users = await db.collection('users').get();
    console.log(`✅ Connected! Found ${users.size} users`);
    
    users.forEach(doc => {
      console.log(`User: ${doc.id}`, doc.data());
    });
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

test();
```

**Run:**
```bash
node test.js
```

## 📦 Complete Example

**File: `index.js`**
```javascript
const express = require('express');
const { db, auth } = require('./firebase-config');

const app = express();
app.use(express.json());

// Get all users
app.get('/users', async (req, res) => {
  try {
    const snapshot = await db.collection('users').get();
    const users = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    res.json(users);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get user by ID
app.get('/users/:id', async (req, res) => {
  try {
    const doc = await db.collection('users').doc(req.params.id).get();
    if (!doc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json({ id: doc.id, ...doc.data() });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(3000, () => {
  console.log('🚀 CRM API running on http://localhost:3000');
});
```

**Run:**
```bash
node index.js
```

**Test:**
```bash
curl http://localhost:3000/users
```

## 🔑 Key Points

- **Project ID**: `kins-b4afb`
- **Collection**: `users`
- **Subcollection**: `users/{userId}/documents`
- **Service Account**: Required for Admin SDK

See `CRM_INTEGRATION_GUIDE.md` for complete documentation.

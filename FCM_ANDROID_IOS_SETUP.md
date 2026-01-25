# FCM Setup for Android & iOS

This guide covers the setup required for Firebase Cloud Messaging on Android and iOS.

## ✅ Code is Ready

The app code is already configured for Android/iOS. You just need to complete the platform-specific setup below.

---

## 🤖 Android Setup

### 1. Google Services File
- ✅ Already have: `android/app/google-services.json`
- This file contains your Firebase configuration

### 2. Update AndroidManifest.xml

Add these permissions and services to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
  <!-- Add these permissions -->
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
  
  <application>
    <!-- Add this service for background messages -->
    <service
      android:name="com.google.firebase.messaging.FirebaseMessagingService"
      android:exported="false">
      <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
      </intent-filter>
    </service>
    
    <!-- Default notification channel -->
    <meta-data
      android:name="com.google.firebase.messaging.default_notification_channel_id"
      android:value="high_importance_channel" />
  </application>
</manifest>
```

### 3. Create Notification Channel (Optional but Recommended)

Create `android/app/src/main/kotlin/com/metatech/kins_app/MainActivity.kt`:

```kotlin
package com.metatech.kins_app

import io.flutter.embedding.android.FlutterActivity
import android.os.Build
import android.app.NotificationChannel
import android.app.NotificationManager

class MainActivity: FlutterActivity() {
    override fun onCreate() {
        super.onCreate()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "high_importance_channel"
            val channelName = "High Importance Notifications"
            val channelDescription = "This channel is used for important notifications"
            val importance = NotificationManager.IMPORTANCE_HIGH
            
            val channel = NotificationChannel(channelId, channelName, importance)
            channel.description = channelDescription
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
}
```

### 4. Update build.gradle

Ensure `android/app/build.gradle` has:

```gradle
android {
    compileSdkVersion 34  // or higher
    
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}

dependencies {
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
    implementation 'com.google.firebase:firebase-messaging'
}
```

---

## 🍎 iOS Setup

### 1. Google Services File
- ✅ Already have: `ios/Runner/GoogleService-Info.plist`
- This file contains your Firebase configuration

### 2. Enable Push Notifications Capability

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the **Runner** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **Push Notifications**
6. Add **Background Modes** and enable:
   - ✅ Remote notifications

### 3. Update AppDelegate.swift

Update `ios/Runner/AppDelegate.swift`:

```swift
import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    
    // Request notification permissions
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { _, _ in }
      )
    } else {
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }
    
    application.registerForRemoteNotifications()
    
    // Set FCM messaging delegate
    Messaging.messaging().delegate = self
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle APNs token
  override func application(_ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
  }
}

// FCM Messaging Delegate
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("Firebase registration token: \(String(describing: fcmToken))")
  }
}
```

### 4. Update Podfile

Ensure `ios/Podfile` has:

```ruby
platform :ios, '12.0'

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end
```

Then run:
```bash
cd ios
pod install
```

### 5. APNs Certificate Setup

1. Go to [Apple Developer Portal](https://developer.apple.com/)
2. Create an APNs Key or Certificate
3. Upload to Firebase Console:
   - Firebase Console → Project Settings → Cloud Messaging
   - Upload APNs Authentication Key or Certificate

---

## 🧪 Testing

### 1. Build and Run

```bash
# For Android
flutter run -d android

# For iOS
flutter run -d ios
```

### 2. Check Logs

Look for:
- ✅ `Notification permission granted`
- ✅ `FCM Token: [your-token]`
- ✅ `FCM token saved to Firestore`

### 3. Test Notification

Use Firebase Console → Cloud Messaging → Send test message:
- Enter the FCM token from logs
- Send a test notification
- Should appear on device

---

## 🔧 Troubleshooting

### Android: "MissingPluginException"
- Run `flutter clean`
- Run `flutter pub get`
- Rebuild: `flutter run`

### iOS: "No implementation found"
- Run `cd ios && pod install`
- Clean build folder in Xcode
- Rebuild

### Token not generated
- Check notification permissions are granted
- Verify `google-services.json` / `GoogleService-Info.plist` are correct
- Check Firebase project settings

### Notifications not received
- Verify FCM token is saved in Firestore
- Check Firebase Console → Cloud Messaging → APNs setup (iOS)
- Verify notification payload format

---

## 📱 Next Steps

1. Complete Android setup (AndroidManifest.xml)
2. Complete iOS setup (AppDelegate.swift, Capabilities)
3. Test on physical devices (simulators have limitations)
4. Deploy Firebase Functions (see FIREBASE_FUNCTIONS_GUIDE.md)
5. Test end-to-end notification flow

---

**Note**: The app code is ready. You just need to complete the platform-specific configurations above.

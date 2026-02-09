# App Store & Play Store Compliance Checklist – Kins App

Use this as a working list. Chat with your dev or legal advisor to finalize.

---

## 1. Required for BOTH stores

### 1.1 Privacy Policy (mandatory)
- **Apple:** You must have a privacy policy URL. Required in App Store Connect.
- **Google:** You must declare a privacy policy URL in Play Console → App content → Privacy policy.
- **Action:** Publish a privacy policy on a stable URL (e.g. `https://yoursite.com/kins-privacy-policy`).
- **Content to cover (your app collects):**
  - **Phone number** – for Firebase Auth / account creation
  - **Location** – to show nearby kins on the map (and optional visibility toggle)
  - **Profile data** – name, email, DOB, photo, bio, interests, country/city
  - **User-generated content** – posts (text, media), chat messages
  - **Identifiers** – device token for push notifications, user ID
- Say: what you collect, why, how long you keep it, who it’s shared with (e.g. Firebase/Google), and how users can request access/deletion.

### 1.2 Terms of Service / EULA (strongly recommended)
- **Action:** Publish Terms of Service (or EULA) at a stable URL.
- **Content:** Rules of use, account termination, disclaimers, liability, governing law. Especially important for apps with UGC (posts, chat).

### 1.3 In-app access to Privacy & Terms
- **Current state:** Settings has “Privacy Policy” and “Terms of Service” but they show “Coming soon”.
- **Action:** Replace “Coming soon” with opening the real URLs (in-app browser or external browser). Do the same for the Home drawer items “Terms of Service” and “Privacy Policy” so both Settings and drawer open the same URLs.

---

## 2. Apple App Store specifics

### 2.1 App Privacy (“Privacy Nutrition Labels”)
- **Where:** App Store Connect → Your App → App Privacy.
- **Action:** Declare all data types your app (or SDKs) collect:
  - **Contact Info** – e.g. phone number (for account)
  - **Location** – precise location (map feature)
  - **User Content** – posts, chat messages
  - **Identifiers** – user ID, device ID (for push)
- For each type, state: “Used for X” / “Linked to identity” / “Used for tracking” (if any). Be accurate; Apple can reject for mismatches.

### 2.2 Permission usage strings (Info.plist)
- **Current:** You have location and local network usage descriptions. Good.
- **If you add:** Camera or Photo Library for posts, add:
  - `NSCameraUsageDescription`
  - `NSPhotoLibraryUsageDescription`
- **Tracking:** If you don’t use IDFA/ads, you don’t need `NSUserTrackingUsageDescription` or App Tracking Transparency.

### 2.3 Sign in with Apple
- **Rule:** If you offer third-party sign-in (Google, Facebook, etc.), you must also offer Sign in with Apple.
- **Your app:** Phone-only auth → Sign in with Apple is **not** required unless you add another social login.

### 2.4 Age rating
- **Where:** App Store Connect → Age Rating questionnaire.
- **Your app:** User-generated content (posts, chat) and social features → likely **12+** or **17+** depending on moderation and content. Answer the questionnaire honestly.

### 2.5 App Store Connect metadata
- **Privacy Policy URL** – required; use the same URL as in your app.
- **Support URL** – recommended (e.g. contact or help page).
- **Category** – e.g. Social Networking or Lifestyle; choose what fits.

---

## 3. Google Play Store specifics

### 3.1 Data safety form
- **Where:** Play Console → Your App → App content → Data safety.
- **Action:** Declare:
  - **Data collected:** e.g. phone number, location, name, email, photos/videos (if posts have media), messages (chat), device ID (push).
  - **Purpose:** e.g. account management, map feature, social features, push notifications.
  - **Optional vs required:** e.g. location can be “optional” if you allow use without it.
  - **Shared with third parties:** e.g. Firebase/Google (infrastructure). No “selling” unless you actually sell data.
  - **Data handling:** e.g. encrypted in transit; whether users can request deletion (and how).

### 3.2 Privacy policy URL
- **Where:** Play Console → App content → Privacy policy.
- **Action:** Same URL as for Apple and as linked in your app.

### 3.3 Permissions
- **Current:** INTERNET, POST_NOTIFICATIONS, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION – all justified by your features.
- **Action:** In Store listing / Data safety, be ready to explain why each permission is needed (you already have location usage in iOS; Android doesn’t show strings in manifest but you explain in Data safety).

### 3.4 Content rating
- **Where:** Play Console → App content → Content rating (questionnaire).
- **Action:** Complete the form; with UGC and chat, you’ll likely get “Teen” or “Mature” depending on content and moderation.

### 3.5 App identity
- **Current:** `android:label="kins_app"` in AndroidManifest.
- **Recommendation:** Use a user-facing name, e.g. `"Kins"` or `"Kins App"`, to match iOS `CFBundleDisplayName` and store listing.

---

## 4. Quick code/config checklist

| Item | Status / action |
|------|-----------------|
| Privacy Policy URL | ❌ Create and publish; add URL to app and store listings |
| Terms of Service URL | ❌ Create and publish; add URL to app and store listings |
| Settings → Privacy Policy opens URL | ❌ Replace “Coming soon” with URL open |
| Settings → Terms of Service opens URL | ❌ Replace “Coming soon” with URL open |
| Home drawer → Terms / Privacy open URL | ❌ Replace TODO with URL open |
| iOS location usage strings | ✅ Present in Info.plist |
| iOS local network (Firebase) | ✅ Present |
| Android permissions | ✅ INTERNET, NOTIFICATIONS, LOCATION declared |
| Android app label | ⚠️ Consider changing to "Kins" or "Kins App" |
| Google Maps API key (release) | ⚠️ Replace placeholder in AndroidManifest if still "YOUR_GOOGLE_MAPS_API_KEY" |
| App Store Privacy labels | ❌ Fill in App Store Connect |
| Play Store Data safety | ❌ Fill in Play Console |
| Age / Content rating | ❌ Complete in both consoles |

---

## 5. Suggested order of work

1. **Legal / content:** Draft (or get) Privacy Policy and Terms of Service; host at stable URLs.
2. **In-app:** Add constants for those URLs; open them from Settings and Home drawer (Terms & Privacy).
3. **Stores:** In App Store Connect and Play Console, add Privacy Policy (and optionally Terms) URL, complete App Privacy / Data safety, and content rating.
4. **Polish:** Set Android `android:label`, replace Maps API key for release, then submit.

If you tell me your Privacy Policy and Terms URLs (or that you’ll use placeholders), I can suggest exact code changes for the in-app links.

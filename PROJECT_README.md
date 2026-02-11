# KINS App – Developer Guide

Concise reference for auth flow, navigation, About You behavior, shared UI, and file layout.

---

## 1. Unified authentication flow

- **Phone (OTP)**  
  Enter phone → send OTP → enter OTP → verify → then [post-auth navigation](#2-post-auth-navigation).

- **Google**  
  Tap “Sign in with Google” → Firebase Google Auth → then same [post-auth navigation](#2-post-auth-navigation).  
  Google is only used when **Firebase Auth** is enabled (`USE_FIREBASE_AUTH=true`). With Twilio backend, the Google button shows a “not available” message.

**Where:**  
- Phone: `lib/screens/auth/phone_auth_screen.dart`, `lib/screens/auth/otp_verification_screen.dart`  
- Google: same phone screen (Google button) + `lib/repositories/firebase_auth_repository.dart` (`signInWithGoogle`)

---

## 2. Post-auth navigation

After **successful** phone OTP or Google sign-in:

| Condition | Destination |
|-----------|-------------|
| New user or profile incomplete (missing name/email/DOB) | **About You** (`/user-details`) |
| Profile complete but no interests | **Interests** (`/interests`) |
| Profile complete and has interests | **Feed** (`/discover`, bottom nav Feed tab) |

Feed = Discover screen; bottom nav Feed index = **0**.

**Single place for this logic:**  
`lib/services/auth_flow_service.dart` → `AuthFlowService.navigateAfterAuth(context, profileStatus: …, googleProfile: …)`  
Used by OTP screen (after verify) and phone screen (after Google sign-in).

**Profile checks:**  
- By phone: `UserDetailsRepository.checkUserByPhoneNumber(phoneNumber)`  
- By Firebase UID (e.g. Google): `UserDetailsRepository.checkUserByUid(uid)`  
Both return `UserProfileStatus` (exists, hasProfile, hasInterests).

---

## 3. About You screen

- **Route:** `/user-details`  
- **File:** `lib/screens/user_details/user_details_screen.dart`

**When opened after Google Sign-In** (route `extra` = `GoogleProfileData`):

- **Pre-filled and read-only** (visible but disabled):  
  Full Name, Email, Phone, Date of birth — when provided by Google.
- **User must fill:**  
  Username (and any other required field that is still empty).
- **Validation:**  
  Required fields must be non-empty; Google-provided fields stay locked and are not editable.

**When opened after Phone OTP only:**  
No `GoogleProfileData`; all fields editable as before.

**Model for Google pre-fill:**  
`lib/models/google_profile_data.dart` (name, email, phoneNumber, dateOfBirth).

---

## 4. Reusable components & design tokens

**Design tokens (same numeric values as current UI):**  
`lib/core/theme/app_design_tokens.dart`  
- Card: radius 40, shadows (standard vs sign-in).  
- Primary button: height 52, radius 26, loader size 24.

**Shared widgets:**

| Widget | Purpose | File |
|--------|---------|------|
| **AppCard** | White card container (optional padding, border, shadow, constraints) | `lib/widgets/app_card.dart` |
| **PrimaryButton** | Black “Continue” style: height 52, loading state, optional `loadingColor` | `lib/widgets/primary_button.dart` |
| **AuthFlowLayout** | SafeArea + logo + column of children (used on auth/profile screens) | `lib/widgets/auth_flow_layout.dart` |

Used on: Phone auth (card, layout), OTP (card, layout, primary button), User details (card, layout, primary button), Interests (card, layout).

---

## 5. File structure (where to find things)

```
lib/
├── core/
│   ├── constants/app_constants.dart   # Routes, keys, useFirebaseAuth
│   └── theme/
│       ├── app_theme.dart
│       └── app_design_tokens.dart     # Card/button/spacing tokens
├── models/
│   ├── user_model.dart
│   ├── user_profile_status.dart       # exists, hasProfile, hasInterests
│   ├── google_profile_data.dart       # Google pre-fill for About You
│   └── auth_result.dart               # GoogleSignInResult (user + googleProfile)
├── providers/
│   ├── auth_provider.dart             # sendOTP, verifyOTP, signInWithGoogle
│   └── user_details_provider.dart
├── repositories/
│   ├── auth_repository_interface.dart # + signInWithGoogle
│   ├── firebase_auth_repository.dart  # Phone + Google
│   ├── twilio_auth_repository.dart    # Phone only; signInWithGoogle => null
│   └── user_details_repository.dart   # checkUserByPhoneNumber, checkUserByUid, saveUserDetails
├── routes/
│   └── app_router.dart                # User-details route passes state.extra (GoogleProfileData)
├── screens/
│   ├── auth/
│   │   ├── phone_auth_screen.dart     # Phone form + Google button
│   │   └── otp_verification_screen.dart
│   └── user_details/
│       └── user_details_screen.dart   # About You; optional googleProfile
├── services/
│   └── auth_flow_service.dart         # navigateAfterAuth
└── widgets/
    ├── app_card.dart
    ├── primary_button.dart
    ├── auth_flow_layout.dart
    ├── kins_logo.dart
    ├── main_bottom_nav.dart          # Feed index = 0
    └── floating_nav_overlay.dart
```

---

## 6. Quick reference

- **Add a new auth method:** Implement `signInWith*` in repository, update interface, then call `checkUserByUid` (or phone) and `AuthFlowService.navigateAfterAuth`.
- **Change post-auth rules:** Edit `AuthFlowService.navigateAfterAuth` and/or `UserProfileStatus` / repository checks.
- **Change “About You” required/locked behavior:** `UserDetailsScreen` + `GoogleProfileData` + route `extra`.
- **Change shared card/button look:** `AppCard` / `PrimaryButton` and `app_design_tokens.dart` (keep values identical if you want no visual change).

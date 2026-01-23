# Firebase Phone Auth - Test Phone Numbers Setup

## Issue
When testing with new phone numbers, you may get an "internal-error" from Firebase. This happens because Firebase Phone Authentication requires test phone numbers to be configured in the Firebase Console for development/testing.

## Solution: Add Test Phone Numbers in Firebase Console

### Steps to Add Test Phone Numbers:

1. **Go to Firebase Console**
   - Visit: https://console.firebase.google.com/
   - Select your project: `kins-b4afb`

2. **Navigate to Authentication Settings**
   - Click on **Authentication** in the left sidebar
   - Click on **Sign-in method** tab
   - Find **Phone** provider and click on it

3. **Add Test Phone Numbers**
   - Scroll down to **Phone numbers for testing** section
   - Click **Add phone number**
   - Enter:
     - **Phone number**: `+971507276822` (or any number you want to test)
     - **Verification code**: `123456` (or any 6-digit code you want to use)
   - Click **Save**

4. **Add Multiple Test Numbers** (Optional)
   - You can add multiple test phone numbers
   - Each test number needs a verification code
   - Example:
     - `+971507276822` → Code: `123456`
     - `+1234567890` → Code: `654321`

### Using Test Phone Numbers

Once configured:
1. Enter the test phone number in the app
2. Complete reCAPTCHA (if shown)
3. Enter the verification code you set in Firebase Console (e.g., `123456`)
4. The app will authenticate successfully

### Important Notes:

- **Test numbers only work in development**: Test phone numbers only work when your app is in development mode or when using Firebase emulator
- **Production numbers**: In production, real phone numbers will receive real SMS codes
- **No SMS sent**: When using test numbers, Firebase doesn't send actual SMS - you use the code you configured
- **Unlimited testing**: You can test as many times as you want with test numbers without SMS costs

### Firebase Built-in Test Numbers

Firebase also provides some built-in test numbers that work without configuration:
- These are documented in Firebase documentation
- However, it's better to configure your own test numbers for consistency

### Troubleshooting

If you still get errors after adding test numbers:
1. Make sure the phone number format is correct (include country code with `+`)
2. Ensure the number is saved in Firebase Console
3. Wait a few seconds after adding before testing
4. Check that Phone Authentication is enabled in Firebase Console
5. Verify your app's bundle ID matches Firebase configuration

### Current Error Handling

The app now provides better error messages:
- **internal-error**: "Phone number not registered for testing. Please add test phone numbers in Firebase Console."
- **invalid-phone-number**: "Invalid phone number format. Please check and try again."
- **too-many-requests**: "Too many requests. Please try again later."
- **quota-exceeded**: "SMS quota exceeded. Please try again later or add test numbers in Firebase Console."

All errors are logged to the console with detailed information for debugging.

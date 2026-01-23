# Bunny CDN Setup Guide

This guide will help you configure Bunny CDN for document uploads in the KINS app.

## Required Information

To configure Bunny CDN, you need the following information from your Bunny CDN account:

1. **Storage Zone Name** - The name of your storage zone
2. **API Key (Storage Zone Password)** - The password/API key for your storage zone
3. **CDN Hostname** - Your CDN hostname (e.g., `your-zone.b-cdn.net`)

## How to Get These Values

### Step 1: Log in to Bunny CDN
1. Go to [Bunny CDN Dashboard](https://bunny.net/)
2. Log in to your account

### Step 2: Create or Select a Storage Zone
1. Navigate to **Storage** → **Storage Zones**
2. Either create a new storage zone or select an existing one
3. Note down the **Storage Zone Name** (this is the name you see in the list)

### Step 3: Get the API Key
1. Click on your storage zone
2. Go to the **FTP & HTTP API** tab
3. Copy the **Storage Zone Password** (this is your API key)
   - ⚠️ **Important**: This is sensitive information. Keep it secure!

### Step 4: Get the CDN Hostname
1. In the storage zone settings, go to **Pull Zone** tab (if you have one)
2. Or check the **Hostname** section
3. Your CDN hostname will be something like: `your-zone.b-cdn.net` or `your-zone.bunnycdn.com`

## Configuration Options

### Option 1: Environment Variables (Recommended for Production)

Set these environment variables when running the app:

```bash
flutter run --dart-define=BUNNY_STORAGE_ZONE=your-storage-zone-name \
           --dart-define=BUNNY_API_KEY=your-api-key \
           --dart-define=BUNNY_CDN_HOSTNAME=your-zone.b-cdn.net
```

### Option 2: Direct Configuration (For Development)

Update `lib/providers/user_details_provider.dart` and replace the environment variable reads with your actual values:

```dart
final bunnyCDNServiceProvider = Provider<BunnyCDNService?>((ref) {
  return BunnyCDNService(
    storageZoneName: 'your-storage-zone-name',  // Replace with your storage zone name
    apiKey: 'your-api-key',                       // Replace with your API key
    cdnHostname: 'your-zone.b-cdn.net',          // Replace with your CDN hostname
  );
});
```

### Option 3: Configuration File (For Development)

Create a `lib/config/bunny_cdn_config.dart` file:

```dart
class BunnyCDNConfig {
  static const String storageZoneName = 'your-storage-zone-name';
  static const String apiKey = 'your-api-key';
  static const String cdnHostname = 'your-zone.b-cdn.net';
}
```

Then update `lib/providers/user_details_provider.dart`:

```dart
import 'package:kins_app/config/bunny_cdn_config.dart';

final bunnyCDNServiceProvider = Provider<BunnyCDNService?>((ref) {
  return BunnyCDNService(
    storageZoneName: BunnyCDNConfig.storageZoneName,
    apiKey: BunnyCDNConfig.apiKey,
    cdnHostname: BunnyCDNConfig.cdnHostname,
  );
});
```

**⚠️ Important**: Never commit your API key to version control! Add `lib/config/bunny_cdn_config.dart` to `.gitignore`.

## Testing the Configuration

1. Run the app
2. Complete OTP verification
3. Fill in the user details form
4. Try uploading a PDF document
5. Check the console logs for upload status

If you see `⚠️ Bunny CDN not configured`, the service is not set up correctly.

## Troubleshooting

### Error: "Bunny CDN service not configured"
- Make sure you've set all three required values (storage zone name, API key, CDN hostname)
- Check that the values are correct and not empty

### Error: "Failed to upload file: 401"
- Your API key is incorrect
- Double-check the Storage Zone Password in Bunny CDN dashboard

### Error: "Failed to upload file: 404"
- Your storage zone name is incorrect
- Make sure the storage zone exists and is active

### Error: "Failed to upload file: 403"
- Your API key doesn't have the correct permissions
- Check the storage zone settings in Bunny CDN

## Security Best Practices

1. **Never commit API keys to Git** - Use environment variables or a secure config file
2. **Use different storage zones for development and production**
3. **Rotate API keys regularly**
4. **Restrict API key permissions** if possible in Bunny CDN settings
5. **Monitor upload activity** in Bunny CDN dashboard

## File Storage Structure

Files are uploaded to: `documents/{userId}_{timestamp}.pdf`

Example: `documents/user123_1234567890.pdf`

The public URL will be: `https://{cdnHostname}/documents/{userId}_{timestamp}.pdf`

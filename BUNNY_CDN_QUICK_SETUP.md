# Bunny CDN Quick Setup

## ✅ Already Configured

- **API Key**: `7182415e-11f7-405a-a6ef94c73651-0193-47bd` ✓
- **Storage Hostname**: `syd.storage.bunnycdn.com` ✓

## ⚠️ Action Required

You need to provide your **Storage Zone Name**.

### How to Find Your Storage Zone Name:

1. Go to [Bunny CDN Dashboard](https://bunny.net/)
2. Log in to your account
3. Navigate to **Storage** → **Storage Zones**
4. You'll see a list of your storage zones
5. Copy the **name** of your storage zone (it's the name shown in the list, not the hostname)

### Example Storage Zone Names:
- `my-documents`
- `kins-storage`
- `user-files`
- etc.

### Update the Config File:

1. Open `lib/config/bunny_cdn_config.dart`
2. Find this line:
   ```dart
   static const String storageZoneName = 'YOUR_STORAGE_ZONE_NAME';
   ```
3. Replace `'YOUR_STORAGE_ZONE_NAME'` with your actual storage zone name
4. Example:
   ```dart
   static const String storageZoneName = 'my-documents';
   ```

## Testing

After updating the storage zone name:

1. Run the app: `flutter run`
2. Complete OTP verification
3. Fill in the user details form
4. Try uploading a PDF document
5. Check the console for upload status

If you see `⚠️ Bunny CDN not configured`, make sure you've updated the storage zone name in the config file.

## Need Help?

If you're not sure what your storage zone name is:
- Check your Bunny CDN dashboard
- Look at the storage zone list - the name is usually the first column
- It's NOT the hostname or endpoint, it's the actual name you see in the dashboard

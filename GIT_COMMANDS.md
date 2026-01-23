# Git Commands to Upload Code to GitHub

Due to permission restrictions, please run these commands manually in your terminal.

## Quick Setup

Open terminal in the project directory and run:

```bash
cd /Users/alihusnain/Documents/GitHub/kins_app

# Initialize git repository
git init

# Add remote repository
git remote add origin https://github.com/otahir-21/kins.git

# Set branch to main
git branch -M main

# Add all files
git add .

# Commit changes
git commit -m "Initial commit: KINS App with Firebase Auth, Firestore, and Bunny CDN integration"

# Push to GitHub
git push -u origin main
```

## Or Use the Setup Script

```bash
cd /Users/alihusnain/Documents/GitHub/kins_app
./GIT_SETUP.sh
```

## What's Included

✅ All source code  
✅ Configuration files  
✅ Documentation  
✅ README  
✅ .gitignore (excludes sensitive files)

## What's Excluded (for security)

❌ `lib/config/bunny_cdn_config.dart` - Contains API keys  
❌ `android/app/google-services.json` - Firebase config  
❌ `ios/Runner/GoogleService-Info.plist` - Firebase config  
❌ `firebase_options.dart` - Firebase config  
❌ Build files  
❌ IDE files

## After Pushing

1. Go to: https://github.com/otahir-21/kins
2. Verify all files are uploaded
3. Share the repository URL with your team

## Important Notes

- The `bunny_cdn_config.dart` file is excluded from git
- A template file `bunny_cdn_config.dart.example` is included
- Team members need to create their own `bunny_cdn_config.dart` from the example
- Firebase config files should be added separately by each developer

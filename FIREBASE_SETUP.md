# Firebase Setup Guide for FCM Token Printing

This guide will help you set up Firebase Cloud Messaging (FCM) to print the notification token every time the app opens.

## Prerequisites

1. A Firebase project (create one at https://console.firebase.google.com/)
2. Flutter SDK installed
3. Android Studio / Xcode for platform-specific setup

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or select an existing project
3. Follow the setup wizard

## Step 2: Add Android App to Firebase

1. In Firebase Console, click the Android icon to add an Android app
2. Use package name: `com.example.zads`
3. Download the `google-services.json` file
4. Replace the placeholder file in `android/app/google-services.json` with the downloaded file

## Step 3: Add iOS App to Firebase

1. In Firebase Console, click the iOS icon to add an iOS app
2. Use bundle ID: `com.example.zads`
3. Download the `GoogleService-Info.plist` file
4. Replace the placeholder file in `ios/Runner/GoogleService-Info.plist` with the downloaded file

## Step 4: Install Dependencies

Run the following command to install the Firebase dependencies:

```bash
flutter pub get
```

## Step 5: Platform-Specific Setup

### Android
The Android setup is already configured in the build files.

### iOS
1. Open `ios/Runner.xcworkspace` in Xcode
2. Add the `GoogleService-Info.plist` file to the Runner target if not already added
3. Ensure the file is included in the bundle

## Step 6: Test the Implementation

1. Run the app: `flutter run`
2. Check the console output - you should see:
   - "User granted permission for notifications" (if permission granted)
   - "FCM Token: [your-token]" (the actual FCM token)
   - "Token length: [number]" (length of the token)

## How It Works

The implementation:

1. **Initializes Firebase** when the app starts
2. **Requests notification permissions** from the user
3. **Gets the FCM token** using `FirebaseMessaging.instance.getToken()`
4. **Prints the token** to the console every time the app opens

## Code Location

The main implementation is in `lib/main.dart`:

- `main()` function: Initializes Firebase and calls token retrieval
- `_getAndPrintFCMToken()` function: Handles permission request and token retrieval

## Troubleshooting

### Common Issues:

1. **"Firebase not initialized" error**: Make sure you've replaced the placeholder configuration files with real ones from Firebase Console

2. **Permission denied**: The app will print "User declined or has not accepted permission for notifications" if the user denies notification permissions

3. **Token is null**: This can happen if:
   - Firebase is not properly configured
   - Device doesn't support FCM
   - Network issues

### Debug Steps:

1. Check that `google-services.json` and `GoogleService-Info.plist` are properly configured
2. Verify that the package name/bundle ID matches your Firebase project
3. Check the console output for any error messages
4. Ensure you have an internet connection

## Next Steps

Once the token is being printed successfully, you can:

1. Store the token in your backend for sending notifications
2. Implement token refresh handling
3. Add notification handling for when the app is in foreground/background
4. Set up server-side notification sending

## Security Note

The FCM token is sensitive information. In a production app, you should:
- Store it securely
- Send it to your backend over HTTPS
- Not log it in production builds 
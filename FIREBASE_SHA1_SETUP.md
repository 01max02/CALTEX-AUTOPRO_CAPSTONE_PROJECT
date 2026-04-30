# Firebase SHA-1 Setup for Google Sign-In

## Your App's SHA-1 Fingerprint

```
B3:DD:DE:A5:B5:D4:13:30:88:64:29:ED:D7:94:16:B5:FA:9B:D8:8A
```

## Steps to Complete Firebase Configuration

### Step 1: Add SHA-1 to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **caltex-autopro-1e664**
3. Click **Project Settings** (gear icon in top left)
4. Go to **Apps** tab
5. Click on the **Android app** (com.example.automotive_mobile)
6. Scroll down to **SHA certificate fingerprints**
7. Click **Add fingerprint**
8. Paste this SHA-1:
   ```
   B3:DD:DE:A5:B5:D4:13:30:88:64:29:ED:D7:94:16:B5:FA:9B:D8:8A
   ```
9. Click **Save**

### Step 2: Download Updated google-services.json

1. Still in the Android app settings
2. Scroll to the top
3. Click **Download google-services.json** button
4. Replace the file at: `automotive_mobile/android/app/google-services.json`

### Step 3: Clean and Rebuild

```bash
cd automotive_mobile
flutter clean
flutter pub get
flutter run
```

## What This Does

- **SHA-1 fingerprint**: Proves your app is legitimate to Google
- **OAuth client**: Allows your app to authenticate with Google Sign-In
- **google-services.json**: Contains the OAuth client configuration

## Testing

After completing these steps:

1. Open the app
2. Click "Continue with Google"
3. Select your Google account
4. You should see console logs showing the authentication flow
5. App should redirect to the appropriate dashboard

## Troubleshooting

### Still getting "Sign-in failed"?

1. **Verify SHA-1 was added:**
   - Go back to Firebase Console
   - Check that your SHA-1 appears in the fingerprints list

2. **Verify google-services.json was updated:**
   - Check that `oauth_client` array is NOT empty
   - Should contain a `client_id` and `client_type: 3`

3. **Clear app cache:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

4. **Check console logs:**
   - Look for detailed error messages in Flutter console
   - Search for "Google Sign-In error" or "DEVELOPER_ERROR"

### Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| DEVELOPER_ERROR | SHA-1 not registered | Add SHA-1 to Firebase Console |
| NETWORK_ERROR | No internet | Check device connection |
| INVALID_ACCOUNT | User not in Firestore | Auto-registers as customer |
| Account is inactive | User status is inactive | Change status to active in Firestore |

## Files Modified

- `automotive_mobile/android/app/google-services.json` - Updated with OAuth client structure

## Next Steps

1. Complete the Firebase Console steps above
2. Download the updated google-services.json
3. Run `flutter clean && flutter pub get && flutter run`
4. Test Google Sign-In

## Support

If you need help:
1. Check the console logs for specific error codes
2. Verify the SHA-1 fingerprint matches exactly
3. Ensure google-services.json has the oauth_client section populated
4. Check Firebase security rules allow authenticated reads

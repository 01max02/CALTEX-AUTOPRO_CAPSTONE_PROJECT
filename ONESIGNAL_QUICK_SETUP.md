# OneSignal Quick Setup - Step by Step

## Step 1: Click "Push notifications"
1. Sa OneSignal Dashboard, click ang **"Push notifications"** card
2. Ito ang gagamitin natin para sa mobile app notifications

---

## Step 2: Configure Android

1. Go to **Settings** → **Keys & IDs**
2. Copy ang **App ID** (makikita mo sa top)
3. Para sa Android, kailangan mo ng Google Server API Key:
   - Go to Firebase Console
   - Project Settings → Cloud Messaging
   - Copy ang **Server API Key**
   - Paste sa OneSignal Android settings

---

## Step 3: Configure iOS (Optional)

1. Get Apple Push Certificate from Apple Developer
2. Upload sa OneSignal iOS settings

---

## Step 4: Get Your Credentials

**Important - Save these:**
- **App ID:** (visible sa OneSignal dashboard)
- **REST API Key:** Settings → Keys & IDs → REST API Key

---

## Step 5: Update Flutter App

Add sa `pubspec.yaml`:
```yaml
dependencies:
  onesignal_flutter: ^5.0.0
```

---

## Step 6: Test Push Notification

1. Click **"Messages"** sa left sidebar
2. Click **"Push"**
3. Click **"Create"**
4. Enter:
   - **Title:** "Test Notification"
   - **Message:** "This is a test"
5. Click **"Next"**
6. Select **"Specific Users"**
7. Enter your user ID
8. Click **"Send"**

---

## Next: Update Flutter Code

Once configured, update `notifications.dart` with OneSignal SDK


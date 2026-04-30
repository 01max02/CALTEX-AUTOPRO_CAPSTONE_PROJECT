const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Cloud Function: Triggered when a notification is created in Firestore
 * Sends push notifications to users based on targetRole or targetUid
 */
exports.sendPushNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    const { title, message, type, targetRole, targetUid } = notification;

    try {
      let userIds = [];

      // If targetUid is set, send to specific user
      if (targetUid) {
        userIds = [targetUid];
      } 
      // If targetRole is set, send to all users with that role
      else if (targetRole) {
        const usersSnap = await admin.firestore()
          .collection('users')
          .where('role', '==', targetRole)
          .get();
        
        userIds = usersSnap.docs.map(doc => doc.id);
      }

      if (userIds.length === 0) {
        console.log('No users to notify');
        return;
      }

      // Get FCM tokens for all target users
      const fcmTokens = [];
      for (const userId of userIds) {
        const userDoc = await admin.firestore()
          .collection('users')
          .doc(userId)
          .get();
        
        const fcmToken = userDoc.data()?.fcmToken;
        if (fcmToken) {
          fcmTokens.push(fcmToken);
        }
      }

      if (fcmTokens.length === 0) {
        console.log('No FCM tokens found for users');
        return;
      }

      // Send multicast message
      const payload = {
        notification: {
          title: title || 'AutoPro Notification',
          body: message || '',
        },
        data: {
          type: type || 'info',
          notificationId: snap.id,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
      };

      const response = await admin.messaging().sendMulticast({
        tokens: fcmTokens,
        notification: payload.notification,
        data: payload.data,
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'default',
          },
        },
        apns: {
          headers: {
            'apns-priority': '10',
          },
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      });

      console.log(`Successfully sent ${response.successCount} notifications`);
      console.log(`Failed to send ${response.failureCount} notifications`);

      // Log failed tokens for cleanup
      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.log(`Failed to send to token ${fcmTokens[idx]}: ${resp.error}`);
          }
        });
      }

      return { success: true, sent: response.successCount };
    } catch (error) {
      console.error('Error sending notifications:', error);
      throw error;
    }
  });

/**
 * Cloud Function: Clean up invalid FCM tokens
 * Called when a message fails to send
 */
exports.cleanupInvalidTokens = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { userId, invalidTokens } = data;

  if (!invalidTokens || invalidTokens.length === 0) {
    return { success: false, message: 'No tokens to clean up' };
  }

  try {
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .update({
        fcmToken: admin.firestore.FieldValue.delete(),
      });

    console.log(`Cleaned up invalid tokens for user ${userId}`);
    return { success: true, message: 'Tokens cleaned up' };
  } catch (error) {
    console.error('Error cleaning up tokens:', error);
    throw new functions.https.HttpsError('internal', 'Error cleaning up tokens');
  }
});

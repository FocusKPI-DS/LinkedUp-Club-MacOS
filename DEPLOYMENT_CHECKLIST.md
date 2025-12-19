# Gmail Watch API - Deployment Checklist

## ✅ Completed
- [x] Pub/Sub topic `gmail-notifications` created

## 🔲 Remaining Steps

### 1. Deploy Cloud Functions
```bash
cd firebase/functions
firebase deploy --only functions:gmailSetupWatch,functions:gmailRenewWatch,functions:gmailNotificationHandler,functions:gmailAutoRenewWatches
```

Or deploy all functions:
```bash
firebase deploy --only functions
```

### 2. Verify Deployment
After deployment, check:
- Functions appear in Firebase Console > Functions
- `gmailNotificationHandler` shows as "Pub/Sub triggered"
- `gmailAutoRenewWatches` shows as "Scheduled"

### 3. Test the Integration
1. Open your app
2. Connect Gmail (if not already connected)
3. Check Firestore: `users/{yourUserId}/gmail_watch/current` should exist
4. Send yourself a test email
5. Check Cloud Functions logs for `gmailNotificationHandler` activity
6. Verify email appears in app within seconds

### 4. Monitor (Optional)
- Check Pub/Sub topic metrics in Google Cloud Console
- Monitor Cloud Functions logs for any errors
- Verify watch auto-renewal is working (check logs every 6 days)

## 🎉 That's It!

Once deployed, the system will:
- ✅ Automatically set up watch when users connect Gmail
- ✅ Receive real-time push notifications
- ✅ Auto-renew watches every 6 days
- ✅ Update email cache instantly

No further action needed - everything runs automatically!


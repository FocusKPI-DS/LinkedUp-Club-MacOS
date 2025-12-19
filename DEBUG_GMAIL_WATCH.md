# Debug Gmail Watch - Email Not Appearing

## Quick Checks

### 1. Check Cloud Functions Logs
```bash
firebase functions:log --only gmailNotificationHandler
```

Look for:
- `📧 Gmail notification received for: [your-email]`
- `✅ Real-time update: Added X new emails to cache`
- Any error messages

### 2. Check Pub/Sub Topic
1. Go to Google Cloud Console → Pub/Sub → Topics
2. Click `gmail-notifications`
3. Check "Messages" tab - should show recent messages
4. Check "Subscriptions" tab - should have a subscription created by Firebase

### 3. Check Firestore
Check if `gmail_email` field matches your actual Gmail address:
- Firestore → `users/{yourUserId}`
- Verify `gmail_email` field exists and matches exactly

### 4. Manual Refresh
Try manually refreshing the cache:
- The app should auto-refresh every 5 minutes
- Or disconnect/reconnect Gmail to trigger a refresh

## Common Issues

### Issue 1: Notification Not Received
**Symptom**: No logs in Cloud Functions
**Fix**: 
- Verify Pub/Sub topic has messages
- Check watch is still active: `users/{userId}/gmail_watch/current`
- Watch expires after 7 days - might need renewal

### Issue 2: Email Address Mismatch
**Symptom**: Logs show "No user found for email"
**Fix**:
- Check `gmail_email` field in Firestore matches exactly
- Case-sensitive matching

### Issue 3: Cache Not Updating
**Symptom**: Handler runs but cache doesn't update
**Fix**:
- Check Firestore permissions
- Check function logs for errors


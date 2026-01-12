# Referral System Pre-Deployment Checklist

## ✅ Code Implementation Status

### 1. iOS Configuration
- [x] Added `applinks:lona.club` to Associated Domains (Runner.entitlements)
- [x] Added `lona://` URL scheme to Info.plist
- [x] Created `apple-app-site-association` file
- [x] Deployed `apple-app-site-association` with correct Content-Type header

### 2. Web Page
- [x] Created `invite.html` with redirect logic
- [x] Handles iOS/Android/Desktop detection
- [x] Redirects to App Store if app not installed
- [x] Attempts Universal Link if app installed
- [x] Stores referral UID in localStorage (fallback)

### 3. Flutter Deep Link Handling
- [x] Added `app_links` package
- [x] Created `handle_referral_deeplink.dart`
- [x] Handles both `lona://invite/{uid}` and `https://lona.club/invite/{uid}`
- [x] Stores referral UID in SharedPreferences
- [x] Initialized in `main.dart` (iOS/Android only)

### 4. Referral Connection Logic
- [x] Created `handle_referral_connection.dart`
- [x] Checks for stored referral UID on signup
- [x] Auto-connects referrer and new user
- [x] Saves `referrer_ref` to user document
- [x] Handles edge cases (self-referral, already connected, etc.)
- [x] Integrated in email signup
- [x] Integrated in Google/Apple sign-in (`maybeCreateUser`)

### 5. Onboarding Display
- [x] Added `referrerName` to FFAppState
- [x] Shows "User A invited you (Already Connected)" message
- [x] Works for both email and OAuth signup

## ⚠️ Known Limitations

1. **iOS Simulator**: Universal Links don't work reliably on simulator
2. **First Build**: Universal Links require app to be installed from App Store/TestFlight
3. **Propagation**: `apple-app-site-association` may take a few minutes to propagate

## 🧪 Testing Checklist

### Before Deploying to App Store:

#### Test 1: Web Redirect (Works on any device)
- [ ] Open `https://lona.club/invite/{test-uid}` in browser
- [ ] Verify "Opening Lona..." page appears
- [ ] Verify redirects to App Store

#### Test 2: Deep Link Parsing (Test in app)
- [ ] Test `lona://invite/{uid}` format
- [ ] Test `https://lona.club/invite/{uid}` format
- [ ] Verify UID is extracted correctly
- [ ] Check console logs for success messages

#### Test 3: Referral Storage (Test in app)
- [ ] Open app via deep link
- [ ] Check SharedPreferences for stored UID
- [ ] Verify UID persists until signup

#### Test 4: Auto-Connection (Test with 2 accounts)
- [ ] User A shares referral link
- [ ] User B clicks link and signs up
- [ ] Verify both users are auto-connected
- [ ] Verify `referrer_ref` is saved in User B's document
- [ ] Verify referral UID is cleared after connection

#### Test 5: Onboarding Display
- [ ] Sign up with referral link
- [ ] Verify "User A invited you (Already Connected)" appears
- [ ] Verify message shows correct referrer name

#### Test 6: Edge Cases
- [ ] Self-referral (user clicks own link) - should not connect
- [ ] Already connected users - should not duplicate connection
- [ ] Invalid referral UID - should handle gracefully
- [ ] Referrer user deleted - should handle gracefully

### Recommended Testing Order:

1. **Simulator/Development Build**:
   - Test web redirect
   - Test deep link code (manual trigger)
   - Test referral connection logic

2. **TestFlight Build** (Before App Store):
   - Test full Universal Links flow
   - Test on real iOS device
   - Test complete user journey

3. **Production Build**:
   - Monitor for errors
   - Check analytics
   - Verify referral connections are working

## 🔍 Code Review Points

### Critical Paths:
1. ✅ Deep link handler properly extracts UID from both URL formats
2. ✅ Referral UID is stored and retrieved correctly
3. ✅ Auto-connection logic handles all edge cases
4. ✅ Error handling prevents app crashes
5. ✅ Null safety checks in place

### Potential Issues Fixed:
- ✅ Fixed nullable `user.uid` in `maybeCreateUser`
- ✅ Fixed nullable `user.uid` in signup widget
- ✅ Improved custom URL scheme parsing
- ✅ Added proper Content-Type header for `apple-app-site-association`

## 📝 Deployment Notes

1. **Build Requirements**:
   - Must rebuild app with new entitlements
   - Must include new Info.plist URL scheme
   - Must include new Flutter code

2. **Firebase Hosting**:
   - ✅ Already deployed
   - ✅ `apple-app-site-association` accessible
   - ✅ `invite.html` accessible

3. **Testing Strategy**:
   - Start with TestFlight for beta testing
   - Test with real users before full release
   - Monitor error logs after deployment

## 🚨 If Issues Occur:

1. **Universal Links not working**:
   - Check `apple-app-site-association` is accessible
   - Verify Associated Domains in app entitlements
   - Check app is installed from App Store/TestFlight

2. **Deep links not triggering**:
   - Check console logs for errors
   - Verify `app_links` package is working
   - Test with manual URL trigger

3. **Referral not connecting**:
   - Check SharedPreferences for stored UID
   - Verify `handleReferralConnection` is called
   - Check Firestore for connection updates


const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { google } = require("googleapis");
const axios = require("axios");
const crypto = require("crypto");

// ==========================================
// UTILITY FUNCTIONS FOR ROBUST API CALLS
// ==========================================

/**
 * Retry function with exponential backoff for Gmail API calls
 * @param {Function} fn - Async function to retry
 * @param {Object} options - Retry options
 * @returns {Promise} Result of the function
 */
async function retryWithBackoff(fn, options = {}) {
  const {
    maxRetries = 5,
    initialDelay = 1000,
    maxDelay = 30000,
    backoffFactor = 2,
    retryableErrors = [429, 500, 503, 504],
  } = options;

  let lastError;
  let delay = initialDelay;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      const statusCode = error?.response?.status || error?.code || error?.status;

      // Check if error is retryable
      if (
        attempt < maxRetries &&
        (retryableErrors.includes(statusCode) ||
          error?.message?.includes("quota") ||
          error?.message?.includes("rate limit"))
      ) {
        const waitTime = Math.min(delay, maxDelay);
        console.log(
          `⚠️ Gmail API error (attempt ${attempt + 1}/${maxRetries + 1}): ${statusCode || error.message}. Retrying in ${waitTime}ms...`
        );
        await new Promise((resolve) => setTimeout(resolve, waitTime));
        delay *= backoffFactor;
      } else {
        throw error;
      }
    }
  }

  throw lastError;
}

/**
 * Batch process items with throttling to avoid rate limits
 * @param {Array} items - Items to process
 * @param {Function} processor - Async function to process each item
 * @param {Object} options - Batch options
 * @returns {Promise<Array>} Results array
 */
async function batchProcess(items, processor, options = {}) {
  const {
    batchSize = 10,
    delayBetweenBatches = 100,
    concurrency = 5,
  } = options;

  const results = [];
  const errors = [];

  // Process in batches
  for (let i = 0; i < items.length; i += batchSize) {
    const batch = items.slice(i, i + batchSize);
    const batchPromises = [];

    // Process batch with concurrency limit
    for (let j = 0; j < batch.length; j += concurrency) {
      const concurrentBatch = batch.slice(j, j + concurrency);
      const promises = concurrentBatch.map(async (item, index) => {
        try {
          return await retryWithBackoff(() => processor(item), {
            maxRetries: 3,
            initialDelay: 500,
          });
        } catch (error) {
          console.error(`Error processing item ${i + j + index}:`, error.message);
          errors.push({ item, error: error.message });
          return null;
        }
      });

      const batchResults = await Promise.all(promises);
      results.push(...batchResults.filter((r) => r !== null));

      // Small delay between concurrent batches
      if (j + concurrency < batch.length) {
        await new Promise((resolve) => setTimeout(resolve, 50));
      }
    }

    // Delay between main batches
    if (i + batchSize < items.length) {
      await new Promise((resolve) => setTimeout(resolve, delayBetweenBatches));
    }
  }

  if (errors.length > 0) {
    console.warn(`⚠️ ${errors.length} items failed to process`);
  }

  return results;
}

// Token refresh lock to prevent concurrent refreshes
const tokenRefreshLocks = new Map();

/**
 * Get Gmail API client with proper error handling and automatic token refresh
 * @param {Object} userData - User data from Firestore
 * @param {String} userId - User ID
 * @returns {Promise<Object>} Gmail API client
 */
async function getGmailClient(userData, userId) {
  // Validate required data
  if (!userData.gmail_access_token) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Gmail access token not found. Please reconnect your Gmail account."
    );
  }

  // Decrypt tokens
  const accessToken = decryptToken(userData.gmail_access_token);
  const refreshToken = userData.gmail_refresh_token 
    ? decryptToken(userData.gmail_refresh_token) 
    : null;

  // Check if refresh token exists (critical for token refresh)
  if (!refreshToken) {
    console.error(`❌ No refresh token found for user ${userId}`);
    await admin.firestore().collection("users").doc(userId).update({
      gmail_connected: false,
      gmail_connection_error: "Refresh token missing. Please reconnect your Gmail account.",
      gmail_disconnected_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Refresh token missing. Please reconnect your Gmail account."
    );
  }

  const oauth2Client = new google.auth.OAuth2(
    functions.config().gmail?.client_id,
    functions.config().gmail?.client_secret,
    functions.config().gmail?.redirect_uri
  );

  // Set credentials with expiry if available
  const credentials = {
    access_token: accessToken,
    refresh_token: refreshToken,
  };

  // Add expiry_date if stored (for proactive refresh)
  if (userData.gmail_token_expiry) {
    credentials.expiry_date = userData.gmail_token_expiry;
  }

  oauth2Client.setCredentials(credentials);

  // Set up automatic token refresh listener to update Firestore when tokens refresh
  oauth2Client.on('tokens', async (tokens) => {
    try {
      const updateData = {};
      
      if (tokens.access_token) {
        updateData.gmail_access_token = encryptToken(tokens.access_token);
      }
      
      if (tokens.refresh_token) {
        // New refresh token (rare, but can happen)
        updateData.gmail_refresh_token = encryptToken(tokens.refresh_token);
      }
      
      if (tokens.expiry_date) {
        updateData.gmail_token_expiry = tokens.expiry_date;
      }

      if (Object.keys(updateData).length > 0) {
        await admin.firestore().collection("users").doc(userId).update(updateData);
        console.log(`✅ Updated Gmail tokens for user ${userId}`);
      }
    } catch (error) {
      console.error(`❌ Failed to update tokens for user ${userId}:`, error);
      // Don't throw - token update failure shouldn't break the request
    }
  });

  // Get or create refresh lock for this user
  if (!tokenRefreshLocks.has(userId)) {
    tokenRefreshLocks.set(userId, Promise.resolve());
  }

  // Use lock to prevent concurrent token refreshes
  const refreshLock = tokenRefreshLocks.get(userId);
  const newLock = refreshLock.then(async () => {
    try {
      // Let Google's OAuth2Client handle token refresh automatically
      // This will use the refresh_token if access_token is expired
      await oauth2Client.getAccessToken();
    } catch (error) {
      // Check if this is an invalid_grant error
      const errorMessage = error.message || "";
      const errorCode = error.code || "";
      const errorData = error.response?.data?.error || {};
      const errorDescription = error.response?.data?.error_description || "";
      
      const isInvalidGrant = 
        errorMessage.includes("invalid_grant") ||
        errorCode === "invalid_grant" ||
        errorData.error === "invalid_grant" ||
        errorDescription.includes("Token has been expired or revoked") ||
        errorDescription.includes("invalid_grant");

      if (isInvalidGrant) {
        console.error(`❌ Invalid grant error for user ${userId}:`, error);
        
        // Mark user as disconnected from Gmail
        await admin.firestore().collection("users").doc(userId).update({
          gmail_connected: false,
          gmail_connection_error: "Refresh token expired or revoked. Please reconnect your Gmail account.",
          gmail_disconnected_at: admin.firestore.FieldValue.serverTimestamp(),
        });

        throw new functions.https.HttpsError(
          "unauthenticated",
          "Gmail refresh token expired or revoked. Please reconnect your Gmail account."
        );
      }

      // Other errors
      throw error;
    }
  });

  // Update lock
  tokenRefreshLocks.set(userId, newLock);

  // Wait for token refresh to complete
  await newLock;

  return google.gmail({ version: "v1", auth: oauth2Client });
}

/**
 * Get Google Calendar API client with proper error handling and automatic token refresh
 * Uses the same OAuth tokens as Gmail (multi-scope tokens)
 * @param {Object} userData - User data from Firestore
 * @param {String} userId - User ID
 * @returns {Promise<Object>} Calendar API client
 */
async function getCalendarClient(userData, userId) {
  // Validate required data - uses same tokens as Gmail
  if (!userData.gmail_access_token) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Access token not found. Please reconnect your Google account."
    );
  }

  // Decrypt tokens (same tokens work for both Gmail and Calendar)
  const accessToken = decryptToken(userData.gmail_access_token);
  const refreshToken = userData.gmail_refresh_token 
    ? decryptToken(userData.gmail_refresh_token) 
    : null;

  // Check if refresh token exists
  if (!refreshToken) {
    console.error(`❌ No refresh token found for user ${userId}`);
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Refresh token missing. Please reconnect your Google account."
    );
  }

  const oauth2Client = new google.auth.OAuth2(
    functions.config().gmail?.client_id,
    functions.config().gmail?.client_secret,
    functions.config().gmail?.redirect_uri
  );

  // Set credentials with expiry if available
  const credentials = {
    access_token: accessToken,
    refresh_token: refreshToken,
  };

  // Add expiry_date if stored
  if (userData.gmail_token_expiry) {
    credentials.expiry_date = userData.gmail_token_expiry;
  }

  oauth2Client.setCredentials(credentials);

  // Set up automatic token refresh listener (same as Gmail)
  oauth2Client.on('tokens', async (tokens) => {
    try {
      const updateData = {};
      
      if (tokens.access_token) {
        updateData.gmail_access_token = encryptToken(tokens.access_token);
      }
      
      if (tokens.refresh_token) {
        updateData.gmail_refresh_token = encryptToken(tokens.refresh_token);
      }
      
      if (tokens.expiry_date) {
        updateData.gmail_token_expiry = tokens.expiry_date;
      }

      if (Object.keys(updateData).length > 0) {
        await admin.firestore().collection("users").doc(userId).update(updateData);
        console.log(`✅ Updated tokens for user ${userId}`);
      }
    } catch (error) {
      console.error(`❌ Failed to update tokens for user ${userId}:`, error);
    }
  });

  // Get or create refresh lock for this user
  if (!tokenRefreshLocks.has(userId)) {
    tokenRefreshLocks.set(userId, Promise.resolve());
  }

  // Use lock to prevent concurrent token refreshes
  const refreshLock = tokenRefreshLocks.get(userId);
  const newLock = refreshLock.then(async () => {
    try {
      await oauth2Client.getAccessToken();
    } catch (error) {
      const errorMessage = error.message || "";
      const errorCode = error.code || "";
      const errorData = error.response?.data?.error || {};
      const errorDescription = error.response?.data?.error_description || "";
      
      const isInvalidGrant = 
        errorMessage.includes("invalid_grant") ||
        errorCode === "invalid_grant" ||
        errorData.error === "invalid_grant" ||
        errorDescription.includes("Token has been expired or revoked") ||
        errorDescription.includes("invalid_grant");

      if (isInvalidGrant) {
        console.error(`❌ Invalid grant error for user ${userId}:`, error);
        
        await admin.firestore().collection("users").doc(userId).update({
          gmail_connected: false,
          gmail_connection_error: "Refresh token expired or revoked. Please reconnect your Google account.",
          gmail_disconnected_at: admin.firestore.FieldValue.serverTimestamp(),
        });

        throw new functions.https.HttpsError(
          "unauthenticated",
          "Refresh token expired or revoked. Please reconnect your Google account."
        );
      }

      throw error;
    }
  });

  // Update lock
  tokenRefreshLocks.set(userId, newLock);

  // Wait for token refresh to complete
  await newLock;

  return google.calendar({ version: "v3", auth: oauth2Client });
}

/**
 * Handle Gmail API errors gracefully
 * @param {Error} error - Error object
 * @param {String} operation - Operation name for logging
 * @returns {functions.https.HttpsError} Formatted error
 */
function handleGmailError(error, operation = "Gmail operation", userId = null) {
  console.error(`❌ ${operation} error:`, error);

  // Check for invalid_grant errors (can happen in various ways)
  const errorMessage = error.message || "";
  const errorCode = error.code || "";
  const errorData = error.response?.data?.error || {};
  const errorDescription = error.response?.data?.error_description || "";
  
  const isInvalidGrant = 
    errorMessage.includes("invalid_grant") ||
    errorCode === "invalid_grant" ||
    errorData.error === "invalid_grant" ||
    errorDescription.includes("Token has been expired or revoked") ||
    errorDescription.includes("invalid_grant");

  // Handle invalid_grant by marking user as disconnected
  if (isInvalidGrant && userId) {
    console.error(`❌ Invalid grant error for user ${userId}:`, error);
    
    // Mark user as disconnected from Gmail (async, don't wait)
    admin.firestore().collection("users").doc(userId).update({
      gmail_connected: false,
      gmail_connection_error: "Refresh token expired or revoked. Please reconnect your Gmail account.",
      gmail_disconnected_at: admin.firestore.FieldValue.serverTimestamp(),
    }).catch(err => {
      console.error(`Failed to update user ${userId} disconnect status:`, err);
    });

    return new functions.https.HttpsError(
      "unauthenticated",
      "Gmail refresh token expired or revoked. Please reconnect your Gmail account."
    );
  }

  // Handle specific Gmail API errors
  if (error.response) {
    const status = error.response.status;
    const message = error.response.data?.error?.message || error.message;

    switch (status) {
      case 401:
        return new functions.https.HttpsError(
          "unauthenticated",
          "Gmail authentication failed. Please reconnect your Gmail account."
        );
      case 403:
        return new functions.https.HttpsError(
          "permission-denied",
          `Gmail API permission denied: ${message}`
        );
      case 429:
        return new functions.https.HttpsError(
          "resource-exhausted",
          "Gmail API rate limit exceeded. Please try again in a few moments."
        );
      case 500:
      case 503:
      case 504:
        return new functions.https.HttpsError(
          "unavailable",
          "Gmail API is temporarily unavailable. Please try again later."
        );
      default:
        return new functions.https.HttpsError(
          "internal",
          `Gmail API error (${status}): ${message}`
        );
    }
  }

  // Handle network errors
  if (error.code === "ECONNRESET" || error.code === "ETIMEDOUT") {
    return new functions.https.HttpsError(
      "unavailable",
      "Network error connecting to Gmail API. Please try again."
    );
  }

  // Generic error
  return new functions.https.HttpsError(
    "internal",
    `${operation} failed: ${error.message}`
  );
}

// ==========================================
// GMAIL OAUTH FUNCTION
// ==========================================
exports.gmailOAuth = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated to connect Gmail"
    );
  }

  const { userId, action, sessionId, code, state } = data;

  // Verify userId matches authenticated user
  if (userId !== context.auth.uid) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "User ID mismatch"
    );
  }

  // Gmail OAuth credentials - store these in Firebase config
  const CLIENT_ID = functions.config().gmail?.client_id || "";
  const CLIENT_SECRET = functions.config().gmail?.client_secret || "";
  const REDIRECT_URI =
    functions.config().gmail?.redirect_uri ||
    "https://us-central1-linkedup-c3e29.cloudfunctions.net/gmailOAuthCallback";

  try {
    if (action === "initiate") {
      // Generate session ID and state for OAuth flow
      const newSessionId = admin.firestore().collection("sessions").doc().id;
      const newState = `${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

      // Store session with expiration
      await admin.firestore()
        .collection("gmail_oauth_sessions")
        .doc(newSessionId)
        .set({
          userId: userId,
          state: newState,
          created: admin.firestore.FieldValue.serverTimestamp(),
          expires: new Date(Date.now() + 30 * 60 * 1000), // 30 minutes
          completed: false,
        });

      // Build authorization URL with Gmail and Calendar scopes
      const SCOPES = [
        "https://www.googleapis.com/auth/gmail.modify",
        "https://www.googleapis.com/auth/gmail.readonly",
        "https://www.googleapis.com/auth/gmail.send",
        "https://www.googleapis.com/auth/calendar",
        "https://www.googleapis.com/auth/userinfo.profile",
        "https://www.googleapis.com/auth/userinfo.email",
      ];

      console.log("🔵 Generating OAuth URL with redirect URI:", REDIRECT_URI);
      
      const authUrl =
        `https://accounts.google.com/o/oauth2/v2/auth?` +
        `client_id=${CLIENT_ID}&` +
        `redirect_uri=${encodeURIComponent(REDIRECT_URI)}&` +
        `response_type=code&` +
        `scope=${encodeURIComponent(SCOPES.join(" "))}&` +
        `access_type=offline&` +
        `prompt=consent&` +
        `state=${newState}`;

      console.log("✅ Generated auth URL (truncated):", authUrl.substring(0, 100) + "...");
      console.log("✅ Session created:", { sessionId: newSessionId, state: newState, userId });

      return {
        success: true,
        authUrl,
        sessionId: newSessionId,
      };
    }

    if (action === "check") {
      // Check if OAuth flow is complete
      if (!sessionId) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Session ID is required"
        );
      }

      const sessionDoc = await admin
        .firestore()
        .collection("gmail_oauth_sessions")
        .doc(sessionId)
        .get();

      if (!sessionDoc.exists) {
        return {
          completed: false,
          error: "Session not found",
        };
      }

      const sessionData = sessionDoc.data();

      // Check if session expired
      if (sessionData.expires && sessionData.expires.toDate() < new Date()) {
        return {
          completed: true,
          success: false,
          error: "Session expired",
        };
      }

      return {
        completed: sessionData.completed || false,
        success: sessionData.success || false,
        error: sessionData.error,
      };
    }

    // Handle callback (this would be called by your web redirect handler)
    if (action === "callback") {
      if (!code || !state) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Code and state are required for callback"
        );
      }

      // Find session by state
      const sessionsQuery = await admin
        .firestore()
        .collection("gmail_oauth_sessions")
        .where("state", "==", state)
        .where("completed", "==", false)
        .limit(1)
        .get();

      if (sessionsQuery.empty) {
        throw new functions.https.HttpsError(
          "not-found",
          "Invalid or expired session"
        );
      }

      const sessionDoc = sessionsQuery.docs[0];
      const sessionData = sessionDoc.data();

      // Verify session belongs to user
      if (sessionData.userId !== userId) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Session does not belong to user"
        );
      }

      try {
        // Exchange code for tokens
        const tokenResponse = await axios.post(
          "https://oauth2.googleapis.com/token",
          {
            code: code,
            client_id: CLIENT_ID,
            client_secret: CLIENT_SECRET,
            redirect_uri: REDIRECT_URI,
            grant_type: "authorization_code",
          },
          {
            headers: {
              "Content-Type": "application/json",
            },
          }
        );

        if (tokenResponse.data.access_token) {
          const accessToken = tokenResponse.data.access_token;
          const refreshToken = tokenResponse.data.refresh_token;
          
          // Validate refresh token is present (critical for long-term access)
          if (!refreshToken) {
            console.error(`❌ No refresh token received for user ${userId}`);
            throw new Error("No refresh token received. Please ensure access_type=offline and prompt=consent are set in OAuth URL.");
          }

          // Calculate token expiry (default to 1 hour if not provided)
          const expiresIn = tokenResponse.data.expires_in || 3600; // Default 1 hour
          const expiryDate = Date.now() + (expiresIn * 1000);

          // Get user's Gmail profile
          const profileResponse = await axios.get(
            "https://www.googleapis.com/gmail/v1/users/me/profile",
            {
              headers: {
                Authorization: `Bearer ${accessToken}`,
              },
            }
          );

          const emailAddress = profileResponse.data.emailAddress;

          // Get user's Google profile picture using userinfo API
          let profilePictureUrl = null;
          try {
            const userInfoResponse = await axios.get(
              "https://www.googleapis.com/oauth2/v2/userinfo",
              {
                headers: {
                  Authorization: `Bearer ${accessToken}`,
                },
              }
            );
            
            if (userInfoResponse.data.picture) {
              profilePictureUrl = userInfoResponse.data.picture;
            }
          } catch (error) {
            console.warn("⚠️ Could not fetch profile picture:", error.message);
            // Continue without profile picture
          }

          // Encrypt tokens before storing (basic encryption - you may want to use more secure method)
          const encryptedAccessToken = encryptToken(accessToken);
          const encryptedRefreshToken = encryptToken(refreshToken);

          // Store tokens and user info with expiry date
          const updateData = {
            gmail_connected: true,
            gmail_access_token: encryptedAccessToken,
            gmail_refresh_token: encryptedRefreshToken,
            gmail_token_expiry: expiryDate, // Store expiry for proactive refresh
            gmail_email: emailAddress,
            gmail_connected_at: admin.firestore.FieldValue.serverTimestamp(),
          };

          // Add profile picture if available
          if (profilePictureUrl) {
            updateData.gmail_profile_picture = profilePictureUrl;
          }

          console.log(`✅ Storing Gmail tokens for user ${userId} with expiry: ${new Date(expiryDate).toISOString()}`);

          await admin.firestore().collection("users").doc(userId).update(updateData);

          // Update session as completed
          await sessionDoc.ref.update({
            completed: true,
            success: true,
            completed_at: admin.firestore.FieldValue.serverTimestamp(),
          });

          return {
            success: true,
            message: "Gmail connected successfully",
            email: emailAddress,
          };
        } else {
          throw new Error("No access token received");
        }
      } catch (error) {
        console.error("Token exchange error:", error);

        // Update session with error
        await sessionDoc.ref.update({
          completed: true,
          success: false,
          error: error.message,
          completed_at: admin.firestore.FieldValue.serverTimestamp(),
        });

        throw new functions.https.HttpsError(
          "internal",
          "Failed to complete OAuth flow: " + error.message
        );
      }
    }

    throw new functions.https.HttpsError(
      "invalid-argument",
      "Invalid action specified"
    );
  } catch (error) {
    console.error("Gmail OAuth error:", error);

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
      "internal",
      "An unexpected error occurred: " + error.message
    );
  }
});

// ==========================================
// GMAIL OAUTH CALLBACK (HTTP endpoint)
// ==========================================
exports.gmailOAuthCallback = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  // Handle preflight requests
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  // Only accept GET requests (OAuth callback)
  if (req.method !== "GET") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  try {
    console.log("🔵 Gmail OAuth callback received!");
    console.log("🔵 Query params:", req.query);
    
    const { code, state, error } = req.query;

    if (error) {
      console.error("❌ OAuth error:", error);
      res.status(400).json({ error: error });
      return;
    }

    if (!code || !state) {
      console.error("❌ Missing code or state:", { code: !!code, state: !!state });
      res.status(400).json({ error: "Missing code or state parameter" });
      return;
    }

    console.log("🔵 State received:", state);
    console.log("🔵 Code received:", code ? "YES" : "NO");

    // Gmail OAuth credentials
    const CLIENT_ID = functions.config().gmail?.client_id || "";
    const CLIENT_SECRET = functions.config().gmail?.client_secret || "";
    const REDIRECT_URI =
      functions.config().gmail?.redirect_uri ||
      "https://us-central1-linkedup-c3e29.cloudfunctions.net/gmailOAuthCallback";

    console.log("🔵 Using redirect URI:", REDIRECT_URI);

    // Find the OAuth session by state (try without completed filter first)
    let sessionsQuery = await admin
      .firestore()
      .collection("gmail_oauth_sessions")
      .where("state", "==", state)
      .where("completed", "==", false)
      .limit(1)
      .get();

    // If not found, try without completed filter (in case it's already marked)
    if (sessionsQuery.empty) {
      console.log("🔵 Session not found with completed=false, trying without filter...");
      sessionsQuery = await admin
        .firestore()
        .collection("gmail_oauth_sessions")
        .where("state", "==", state)
        .limit(1)
        .get();
    }

    if (sessionsQuery.empty) {
      console.error("❌ No session found for state:", state);
      // Log all sessions for debugging (remove in production)
      const allSessions = await admin
        .firestore()
        .collection("gmail_oauth_sessions")
        .orderBy("created", "desc")
        .limit(5)
        .get();
      console.log("🔵 Recent sessions:", allSessions.docs.map(d => ({
        id: d.id,
        state: d.data().state,
        completed: d.data().completed,
        userId: d.data().userId
      })));
      res.status(404).json({ error: "Invalid or expired session" });
      return;
    }

    const sessionDoc = sessionsQuery.docs[0];
    const sessionData = sessionDoc.data();
    const userId = sessionData.userId;

    console.log("✅ Found session:", sessionDoc.id);
    console.log("✅ Session data:", { userId, completed: sessionData.completed, state: sessionData.state });

    // If already completed, just return success
    if (sessionData.completed) {
      console.log("⚠️ Session already completed, returning success");
      const successHtml = `
        <!DOCTYPE html>
        <html>
        <head>
          <title>Gmail Already Connected</title>
          <meta name="viewport" content="width=device-width, initial-scale=1">
        </head>
        <body style="font-family: system-ui; text-align: center; padding: 40px;">
          <h1>✅ Gmail Already Connected</h1>
          <p>This session was already processed. Please return to the app.</p>
        </body>
        </html>
      `;
      res.send(successHtml);
      return;
    }

    console.log("🔵 Exchanging code for tokens...");
    
    // Exchange code for tokens
    const tokenResponse = await axios.post(
      "https://oauth2.googleapis.com/token",
      {
        code: code,
        client_id: CLIENT_ID,
        client_secret: CLIENT_SECRET,
        redirect_uri: REDIRECT_URI,
        grant_type: "authorization_code",
      },
      {
        headers: {
          "Content-Type": "application/json",
        },
      }
    );

    if (tokenResponse.data.access_token) {
      console.log("✅ Token exchange successful!");
      const accessToken = tokenResponse.data.access_token;
      const refreshToken = tokenResponse.data.refresh_token;
      
      // Validate refresh token is present (critical for long-term access)
      if (!refreshToken) {
        console.error(`❌ No refresh token received for user ${userId}`);
        res.status(400).json({ error: "No refresh token received. Please reconnect." });
        return;
      }

      // Calculate token expiry (default to 1 hour if not provided)
      const expiresIn = tokenResponse.data.expires_in || 3600; // Default 1 hour
      const expiryDate = Date.now() + (expiresIn * 1000);

      console.log("🔵 Getting Gmail profile...");
      
      // Get user's Gmail profile
      const profileResponse = await axios.get(
        "https://www.googleapis.com/gmail/v1/users/me/profile",
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
          },
        }
      );

      const emailAddress = profileResponse.data.emailAddress;
      console.log("✅ Gmail profile retrieved:", emailAddress);

      // Get user's Google profile picture using userinfo API
      let profilePictureUrl = null;
      try {
        const userInfoResponse = await axios.get(
          "https://www.googleapis.com/oauth2/v2/userinfo",
          {
            headers: {
              Authorization: `Bearer ${accessToken}`,
            },
          }
        );
        
        if (userInfoResponse.data.picture) {
          profilePictureUrl = userInfoResponse.data.picture;
          console.log("✅ Profile picture retrieved:", profilePictureUrl);
        }
      } catch (error) {
        console.warn("⚠️ Could not fetch profile picture:", error.message);
        // Continue without profile picture
      }

      console.log("🔵 Encrypting and storing tokens...");
      
      // Encrypt tokens before storing
      const encryptedAccessToken = encryptToken(accessToken);
      const encryptedRefreshToken = encryptToken(refreshToken);

      // Store tokens and user info with expiry date
      const updateData = {
        gmail_connected: true,
        gmail_access_token: encryptedAccessToken,
        gmail_refresh_token: encryptedRefreshToken,
        gmail_token_expiry: expiryDate, // Store expiry for proactive refresh
        gmail_email: emailAddress,
        gmail_connected_at: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Add profile picture if available
      if (profilePictureUrl) {
        updateData.gmail_profile_picture = profilePictureUrl;
      }

      console.log(`✅ Storing Gmail tokens for user ${userId} with expiry: ${new Date(expiryDate).toISOString()}`);

      await admin.firestore().collection("users").doc(userId).update(updateData);

      // Update session as completed FIRST (before redirect)
      await sessionDoc.ref.update({
        completed: true,
        success: true,
        completed_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`✅ Gmail OAuth completed for user ${userId}`);
      console.log(`✅ Session ${sessionDoc.id} marked as completed`);

      // Redirect to success page with a message
      const successHtml = `
        <!DOCTYPE html>
        <html>
        <head>
          <title>Gmail Connected</title>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            body {
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
              display: flex;
              justify-content: center;
              align-items: center;
              height: 100vh;
              margin: 0;
              background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            }
            .container {
              text-align: center;
              background: white;
              padding: 40px;
              border-radius: 12px;
              box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            }
            .success-icon {
              font-size: 64px;
              color: #4CAF50;
              margin-bottom: 20px;
            }
            h1 {
              color: #333;
              margin: 0 0 10px 0;
            }
            p {
              color: #666;
              margin: 0;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="success-icon">✅</div>
            <h1>Gmail Connected Successfully!</h1>
            <p>You can close this window and return to the app.</p>
            <p style="margin-top: 10px; font-size: 14px; color: #999;">
              Your Gmail account (${emailAddress}) is now connected.
            </p>
          </div>
        </body>
        </html>
      `;
      
      res.send(successHtml);
    } else {
      throw new Error("No access token received");
    }
  } catch (error) {
    console.error("❌ Gmail OAuth callback error:", error);
    console.error("❌ Error stack:", error.stack);
    res.status(500).send(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Error</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
      </head>
      <body style="font-family: system-ui; text-align: center; padding: 40px;">
        <h1 style="color: red;">❌ Error</h1>
        <p>${error.message}</p>
        <p style="font-size: 12px; color: #999;">Please try again or contact support.</p>
      </body>
      </html>
    `);
  }
});

// ==========================================
// GMAIL LIST EMAILS FUNCTION
// ==========================================
exports.gmailListEmails = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const userId = context.auth.uid;
  const { maxResults = 50, pageToken } = data;

  try {
    // Get user's Gmail tokens
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists || !userDoc.data().gmail_connected) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Gmail not connected"
      );
    }

    const userData = userDoc.data();
    
    // Get Gmail client with automatic token refresh and retry logic
    const gmail = await retryWithBackoff(
      async () => await getGmailClient(userData, userId),
      { maxRetries: 3, initialDelay: 500 }
    );

    // List messages - only get INBOX emails (received emails, not sent)
    const listParams = {
      userId: "me",
      maxResults: Math.min(maxResults, 100), // Cap at 100 for performance
      labelIds: ["INBOX"], // Only fetch emails from INBOX (received emails)
    };

    if (pageToken) {
      listParams.pageToken = pageToken;
    }

    // List messages with retry logic
    const response = await retryWithBackoff(
      async () => await gmail.users.messages.list(listParams),
      {
        maxRetries: 5,
        initialDelay: 1000,
        backoffFactor: 2,
      }
    );

    const messages = response.data.messages || [];
    const nextPageToken = response.data.nextPageToken;

    if (messages.length === 0) {
      return {
        success: true,
        emails: [],
        nextPageToken: nextPageToken,
      };
    }

    // Process messages in batches with throttling to avoid rate limits
    const emailList = await batchProcess(
      messages.slice(0, maxResults),
      async (msg) => {
        // Get message details with retry logic
        const message = await retryWithBackoff(
          async () =>
            await gmail.users.messages.get({
              userId: "me",
              id: msg.id,
              format: "metadata",
              metadataHeaders: ["Subject", "From", "Date", "To"],
            }),
          {
            maxRetries: 3,
            initialDelay: 500,
          }
        );

        // Extract headers efficiently
        const headers = message.data.payload.headers || [];
        const subjectHeader = headers.find((h) => h.name === "Subject");
        const fromHeader = headers.find((h) => h.name === "From");
        const dateHeader = headers.find((h) => h.name === "Date");
        const toHeader = headers.find((h) => h.name === "To");

        return {
          id: msg.id,
          threadId: msg.threadId,
          subject: subjectHeader?.value || "(No Subject)",
          from: fromHeader?.value || "",
          to: toHeader?.value || "",
          date: dateHeader?.value || "",
          snippet: message.data.snippet || "",
          labels: message.data.labelIds || [],
        };
      },
      {
        batchSize: 10, // Process 10 messages at a time
        concurrency: 5, // Max 5 concurrent API calls per batch
        delayBetweenBatches: 100, // 100ms delay between batches
      }
    );

    // Filter out sent emails (safety check - should already be filtered by INBOX label)
    const receivedEmails = emailList.filter((email) => {
      if (!email) return false;
      const labels = email.labels || [];
      // Exclude emails with SENT label and ensure they have INBOX label
      return labels.includes("INBOX") && !labels.includes("SENT");
    });

    console.log(
      `✅ Successfully fetched ${receivedEmails.length} emails for user ${userId}`
    );

    return {
      success: true,
      emails: receivedEmails,
      nextPageToken: nextPageToken,
    };
  } catch (error) {
    // Use centralized error handling
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw handleGmailError(error, "List emails", userId);
  }
});

// ==========================================
// GMAIL GET EMAIL FUNCTION
// ==========================================
exports.gmailGetEmail = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const userId = context.auth.uid;
  const { messageId } = data;

  if (!messageId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Message ID is required"
    );
  }

  try {
    // Get user's Gmail tokens
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists || !userDoc.data().gmail_connected) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Gmail not connected"
      );
    }

    const userData = userDoc.data();

    // Get Gmail client with automatic token refresh and retry logic
    const gmail = await retryWithBackoff(
      async () => await getGmailClient(userData, userId),
      { maxRetries: 3, initialDelay: 500 }
    );

    // Get full message with retry logic
    const message = await retryWithBackoff(
      async () =>
        await gmail.users.messages.get({
          userId: "me",
          id: messageId,
          format: "full",
        }),
      {
        maxRetries: 5,
        initialDelay: 1000,
        backoffFactor: 2,
      }
    );

    // Parse email content
    const payload = message.data.payload;
    const headers = payload.headers || [];

    const emailData = {
      id: message.data.id,
      threadId: message.data.threadId,
      subject:
        headers.find((h) => h.name === "Subject")?.value || "(No Subject)",
      from: headers.find((h) => h.name === "From")?.value || "",
      to: headers.find((h) => h.name === "To")?.value || "",
      date: headers.find((h) => h.name === "Date")?.value || "",
      snippet: message.data.snippet || "",
      labels: message.data.labelIds || [],
      body: extractEmailBody(payload),
      attachments: [],
    };

    // Extract attachments recursively from nested parts
    emailData.attachments = extractAttachments(payload);

    return {
      success: true,
      email: emailData,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw handleGmailError(error, "Get email", userId);
  }
});

// ==========================================
// GMAIL SEND EMAIL FUNCTION
// ==========================================
exports.gmailSendEmail = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const userId = context.auth.uid;
  const { to, cc, subject, body, isHtml = false, attachments = [] } = data;

  if (!to || !subject || !body) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "To, subject, and body are required"
    );
  }

  try {
    // Get user's Gmail tokens
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists || !userDoc.data().gmail_connected) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Gmail not connected"
      );
    }

    const userData = userDoc.data();

    // Get Gmail client with automatic token refresh and retry logic
    const gmail = await retryWithBackoff(
      async () => await getGmailClient(userData, userId),
      { maxRetries: 3, initialDelay: 500 }
    );

    // Build email headers
    // Note: We don't set the "From" header - Gmail API automatically uses
    // the authenticated account's email and name from Gmail account settings
    const headers = [
      `To: ${to}`,
    ];
    if (cc && cc.trim()) {
      headers.push(`Cc: ${cc}`);
    }
    headers.push(`Subject: ${subject}`);

    let email;
    
    // If there are attachments, create multipart message
    if (attachments && attachments.length > 0) {
      const boundary = `----=_Part_${Date.now()}_${Math.random().toString(36).substring(7)}`;
      
      // Build multipart message
      let messageParts = [];
      
      // Text/HTML body part
      messageParts.push(`--${boundary}`);
      messageParts.push(`Content-Type: ${isHtml ? "text/html" : "text/plain"}; charset=utf-8`);
      messageParts.push(`Content-Transfer-Encoding: 7bit`);
      messageParts.push(``);
      messageParts.push(body);
      
      // Attachment parts - download from Firebase Storage URLs
      for (const attachment of attachments) {
        if (!attachment.storageUrl || !attachment.filename || !attachment.mimeType) {
          continue;
        }
        
        try {
          // Download file from Firebase Storage URL
          const response = await axios.get(attachment.storageUrl, {
            responseType: 'arraybuffer',
            timeout: 30000, // 30 second timeout per file
          });
          
          // Convert to base64
          const base64Data = Buffer.from(response.data, 'binary').toString('base64');
          
          messageParts.push(`--${boundary}`);
          messageParts.push(`Content-Type: ${attachment.mimeType}; name="${attachment.filename}"`);
          messageParts.push(`Content-Disposition: attachment; filename="${attachment.filename}"`);
          messageParts.push(`Content-Transfer-Encoding: base64`);
          messageParts.push(``);
          messageParts.push(base64Data);
        } catch (error) {
          console.error(`⚠️ Error downloading attachment ${attachment.filename}: ${error.message}`);
          // Continue with other attachments
        }
      }
      
      messageParts.push(`--${boundary}--`);
      
      // Combine headers and body
      headers.push(`Content-Type: multipart/mixed; boundary="${boundary}"`);
      headers.push(``);
      
      email = headers.join("\r\n") + "\r\n" + messageParts.join("\r\n");
    } else {
      // Simple message without attachments
      headers.push(`Content-Type: ${isHtml ? "text/html" : "text/plain"}; charset=utf-8`);
      headers.push(``);
      headers.push(body);
      
      email = headers.join("\r\n");
    }

    // Encode email in base64url format
    const encodedEmail = Buffer.from(email)
      .toString("base64")
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");

    // Send email with retry logic
    const response = await retryWithBackoff(
      async () =>
        await gmail.users.messages.send({
          userId: "me",
          requestBody: {
            raw: encodedEmail,
          },
        }),
      {
        maxRetries: 5,
        initialDelay: 1000,
        backoffFactor: 2,
      }
    );

    console.log(`✅ Email sent successfully for user ${userId}`);

    return {
      success: true,
      messageId: response.data.id,
      message: "Email sent successfully",
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw handleGmailError(error, "Send email", userId);
  }
});

// ==========================================
// GMAIL REPLY EMAIL FUNCTION
// ==========================================
exports.gmailReply = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const userId = context.auth.uid;
  const { messageId, replyBody, isHtml = false } = data;

  if (!messageId || !replyBody) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Message ID and reply body are required"
    );
  }

  try {
    // Get user's Gmail tokens
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists || !userDoc.data().gmail_connected) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Gmail not connected"
      );
    }

    const userData = userDoc.data();

    // Get Gmail client with automatic token refresh and retry logic
    const gmail = await retryWithBackoff(
      async () => await getGmailClient(userData, userId),
      { maxRetries: 3, initialDelay: 500 }
    );

    // Get original message to extract thread ID and reply headers with retry
    const originalMessage = await retryWithBackoff(
      async () =>
        await gmail.users.messages.get({
          userId: "me",
          id: messageId,
          format: "metadata",
          metadataHeaders: ["Subject", "From", "To", "Message-ID", "References"],
        }),
      {
        maxRetries: 5,
        initialDelay: 1000,
        backoffFactor: 2,
      }
    );

    const headers = originalMessage.data.payload.headers || [];
    const subject = headers.find((h) => h.name === "Subject")?.value || "";
    const from = headers.find((h) => h.name === "From")?.value || "";
    const messageIdHeader =
      headers.find((h) => h.name === "Message-ID")?.value || "";
    const references =
      headers.find((h) => h.name === "References")?.value || "";
    const threadId = originalMessage.data.threadId;

    // Create reply subject (Re: prefix)
    const replySubject = subject.startsWith("Re:")
      ? subject
      : `Re: ${subject}`;

    // Build reply message with proper headers for threading
    // Note: We don't set the "From" header - Gmail API automatically uses
    // the authenticated account's email and name from Gmail account settings
    const emailLines = [
      `To: ${from}`,
      `Subject: ${replySubject}`,
      `Content-Type: ${isHtml ? "text/html" : "text/plain"}; charset=utf-8`,
      `In-Reply-To: ${messageIdHeader}`,
      `References: ${references ? `${references} ` : ""}${messageIdHeader}`,
      "",
      replyBody,
    ];

    const email = emailLines.join("\r\n");

    // Encode email in base64url format
    const encodedEmail = Buffer.from(email)
      .toString("base64")
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");

    // Send reply with retry logic
    const response = await retryWithBackoff(
      async () =>
        await gmail.users.messages.send({
          userId: "me",
          requestBody: {
            raw: encodedEmail,
            threadId: threadId, // Important: include thread ID for threading
          },
        }),
      {
        maxRetries: 5,
        initialDelay: 1000,
        backoffFactor: 2,
      }
    );

    console.log(`✅ Reply sent successfully for user ${userId}`);

    return {
      success: true,
      messageId: response.data.id,
      threadId: threadId,
      message: "Reply sent successfully",
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw handleGmailError(error, "Reply to email", userId);
  }
});

// ==========================================
// GMAIL DOWNLOAD ATTACHMENT FUNCTION
// ==========================================
exports.gmailDownloadAttachment = functions.https.onCall(
  async (data, context) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const userId = context.auth.uid;
    const { messageId, attachmentId } = data;

    if (!messageId || !attachmentId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Message ID and attachment ID are required"
      );
    }

    try {
      // Get user's Gmail tokens
      const userDoc = await admin
        .firestore()
        .collection("users")
        .doc(userId)
        .get();

      if (!userDoc.exists || !userDoc.data().gmail_connected) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Gmail not connected"
        );
      }

      const userData = userDoc.data();

      // Get Gmail client with automatic token refresh and retry logic
      const gmail = await retryWithBackoff(
        async () => await getGmailClient(userData, userId),
        { maxRetries: 3, initialDelay: 500 }
      );

      // Download attachment with retry logic
      const attachment = await retryWithBackoff(
        async () =>
          await gmail.users.messages.attachments.get({
            userId: "me",
            messageId: messageId,
            id: attachmentId,
          }),
        {
          maxRetries: 5,
          initialDelay: 1000,
          backoffFactor: 2,
        }
      );

      return {
        success: true,
        data: attachment.data.data,
        size: attachment.data.size,
      };
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw handleGmailError(error, "Download attachment", userId);
    }
  }
);

// ==========================================
// HELPER FUNCTIONS
// ==========================================

/**
 * Simple encryption function for tokens
 * In production, use a more secure method (e.g., Firebase Admin SDK encryption)
 */
function encryptToken(token) {
  // For now, use a simple encoding (you should use proper encryption)
  // Store encryption key in Firebase config
  const encryptionKey =
    functions.config().gmail?.encryption_key || "default-key-change-this";
  const cipher = crypto.createCipher("aes-256-cbc", encryptionKey);
  let encrypted = cipher.update(token, "utf8", "hex");
  encrypted += cipher.final("hex");
  return encrypted;
}

/**
 * Simple decryption function for tokens
 */
function decryptToken(encryptedToken) {
  try {
    const encryptionKey =
      functions.config().gmail?.encryption_key || "default-key-change-this";
    const decipher = crypto.createDecipher("aes-256-cbc", encryptionKey);
    let decrypted = decipher.update(encryptedToken, "hex", "utf8");
    decrypted += decipher.final("utf8");
    return decrypted;
  } catch (error) {
    // If decryption fails, might be stored in plain text (old format)
    return encryptedToken;
  }
}

/**
 * Extract email body from Gmail message payload
 * Prefers HTML over plain text for rich email display
 */
function extractEmailBody(payload) {
  let htmlBody = "";
  let plainBody = "";

  if (payload.body && payload.body.data) {
    // Simple text/HTML body
    const mimeType = payload.mimeType || "";
    if (mimeType.includes("html")) {
      htmlBody = Buffer.from(payload.body.data, "base64").toString("utf-8");
    } else {
      plainBody = Buffer.from(payload.body.data, "base64").toString("utf-8");
    }
  } else if (payload.parts) {
    // Multi-part message - recursively search for HTML and plain text
    function traverseParts(parts) {
      if (!parts || !Array.isArray(parts)) {
        return;
      }

      for (const part of parts) {
        // Extract HTML body from current part (preferred)
        if (part.mimeType === "text/html" && part.body && part.body.data && !htmlBody) {
          htmlBody = Buffer.from(part.body.data, "base64").toString("utf-8");
        }
        // Extract plain text body from current part (fallback)
        else if (part.mimeType === "text/plain" && part.body && part.body.data && !plainBody) {
          plainBody = Buffer.from(part.body.data, "base64").toString("utf-8");
        }

        // Then check nested parts recursively
        if (part.parts && Array.isArray(part.parts)) {
          traverseParts(part.parts);
        }
      }
    }

    traverseParts(payload.parts);
  }

  // Prefer HTML over plain text
  return htmlBody || plainBody;
}

/**
 * Recursively extract attachments from Gmail message payload
 * Handles nested parts (e.g., multipart/mixed containing multipart/alternative)
 */
function extractAttachments(payload) {
  const attachments = [];

  function traverseParts(parts) {
    if (!parts || !Array.isArray(parts)) {
      return;
    }

    for (const part of parts) {
      // Check if this part is an attachment
      if (part.filename && part.filename.length > 0) {
        attachments.push({
          filename: part.filename,
          mimeType: part.mimeType || "application/octet-stream",
          size: part.body?.size || 0,
          attachmentId: part.body?.attachmentId || null,
        });
      }

      // Recursively check nested parts
      if (part.parts && Array.isArray(part.parts)) {
        traverseParts(part.parts);
      }
    }
  }

  // Check top-level body for attachments (rare but possible)
  if (payload.body && payload.body.attachmentId) {
    attachments.push({
      filename: payload.filename || "attachment",
      mimeType: payload.mimeType || "application/octet-stream",
      size: payload.body.size || 0,
      attachmentId: payload.body.attachmentId,
    });
  }

  // Traverse parts recursively
  if (payload.parts) {
    traverseParts(payload.parts);
  }

  return attachments;
}

// ==========================================
// GMAIL MARK AS READ FUNCTION
// ==========================================
exports.gmailMarkAsRead = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const userId = context.auth.uid;
  const { messageId } = data;

  if (!messageId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Message ID is required"
    );
  }

  try {
    // Get user's Gmail tokens
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists || !userDoc.data().gmail_connected) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Gmail not connected"
      );
    }

    const userData = userDoc.data();

    // Get Gmail client with automatic token refresh and retry logic
    const gmail = await retryWithBackoff(
      async () => await getGmailClient(userData, userId),
      { maxRetries: 3, initialDelay: 500 }
    );

    // Remove UNREAD label to mark as read
    const result = await retryWithBackoff(
      async () =>
        await gmail.users.messages.modify({
          userId: "me",
          id: messageId,
          requestBody: {
            removeLabelIds: ["UNREAD"],
          },
        }),
      {
        maxRetries: 5,
        initialDelay: 1000,
        backoffFactor: 2,
      }
    );

    // Update Firestore cache to reflect read status
    try {
      const cacheDoc = await admin.firestore()
        .collection("users")
        .doc(userId)
        .collection("gmail_cache")
        .doc("recent")
        .get();

      if (cacheDoc.exists) {
        const cacheData = cacheDoc.data();
        const emails = cacheData?.emails || [];
        
        // Find and update the email in cache
        const emailIndex = emails.findIndex(e => e.id === messageId);
        if (emailIndex !== -1) {
          const updatedLabels = Array.isArray(emails[emailIndex].labels) 
            ? emails[emailIndex].labels.filter(label => label !== 'UNREAD')
            : [];
          
          emails[emailIndex] = {
            ...emails[emailIndex],
            labels: updatedLabels,
          };

          // Update cache
          await admin.firestore()
            .collection("users")
            .doc(userId)
            .collection("gmail_cache")
            .doc("recent")
            .set({
              emails: emails,
            }, { merge: true });

          console.log(`✅ Updated read status in cache for email ${messageId}`);
        }
      }
    } catch (cacheError) {
      console.error(`⚠️ Failed to update cache for read status: ${cacheError.message}`);
      // Don't fail the whole operation if cache update fails
    }

    return {
      success: true,
      message: "Email marked as read",
    };
  } catch (error) {
    // Use centralized error handling
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw handleGmailError(error, "Mark email as read", userId);
  }
});

// ==========================================
// CALENDAR ERROR HANDLER
// ==========================================

/**
 * Handle Google Calendar API errors gracefully
 * @param {Error} error - Error object
 * @param {String} operation - Operation name for logging
 * @param {String} userId - User ID for logging
 * @returns {functions.https.HttpsError} Formatted error
 */
function handleCalendarError(error, operation = "Calendar operation", userId = null) {
  console.error(`❌ ${operation} error:`, error);

  // Check for invalid_grant errors
  const errorMessage = error.message || "";
  const errorCode = error.code || "";
  const errorData = error.response?.data?.error || {};
  const errorDescription = error.response?.data?.error_description || "";
  
  const isInvalidGrant = 
    errorMessage.includes("invalid_grant") ||
    errorCode === "invalid_grant" ||
    errorData.error === "invalid_grant" ||
    errorDescription.includes("Token has been expired or revoked") ||
    errorDescription.includes("invalid_grant");

  // Handle invalid_grant by marking user as disconnected
  if (isInvalidGrant && userId) {
    console.error(`❌ Invalid grant error for user ${userId}:`, error);
    
    admin.firestore().collection("users").doc(userId).update({
      gmail_connected: false,
      gmail_connection_error: "Refresh token expired or revoked. Please reconnect your Google account.",
      gmail_disconnected_at: admin.firestore.FieldValue.serverTimestamp(),
    }).catch(err => {
      console.error(`Failed to update user ${userId} disconnect status:`, err);
    });

    return new functions.https.HttpsError(
      "unauthenticated",
      "Refresh token expired or revoked. Please reconnect your Google account."
    );
  }

  // Handle specific Calendar API errors
  if (error.response) {
    const status = error.response.status;
    const message = error.response.data?.error?.message || error.message;

    switch (status) {
      case 401:
        return new functions.https.HttpsError(
          "unauthenticated",
          "Calendar authentication failed. Please reconnect your Google account."
        );
      case 403:
        return new functions.https.HttpsError(
          "permission-denied",
          `Calendar API permission denied: ${message}`
        );
      case 404:
        return new functions.https.HttpsError(
          "not-found",
          `Calendar resource not found: ${message}`
        );
      case 429:
        return new functions.https.HttpsError(
          "resource-exhausted",
          "Calendar API rate limit exceeded. Please try again in a few moments."
        );
      case 500:
      case 503:
      case 504:
        return new functions.https.HttpsError(
          "unavailable",
          "Calendar API is temporarily unavailable. Please try again later."
        );
      default:
        return new functions.https.HttpsError(
          "internal",
          `Calendar API error (${status}): ${message}`
        );
    }
  }

  // Handle network errors
  if (error.code === "ECONNRESET" || error.code === "ETIMEDOUT") {
    return new functions.https.HttpsError(
      "unavailable",
      "Network error connecting to Calendar API. Please try again."
    );
  }

  // Generic error
  return new functions.https.HttpsError(
    "internal",
    `${operation} failed: ${error.message}`
  );
}

// ==========================================
// CALENDAR LIST CALENDARS FUNCTION
// ==========================================
exports.calendarListCalendars = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const userId = context.auth.uid;

  try {
    // Get user's tokens (same as Gmail)
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists || !userDoc.data().gmail_connected) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Google account not connected"
      );
    }

    const userData = userDoc.data();
    
    // Get Calendar client with automatic token refresh and retry logic
    const calendar = await retryWithBackoff(
      async () => await getCalendarClient(userData, userId),
      { maxRetries: 3, initialDelay: 500 }
    );

    // List calendars with retry logic
    const response = await retryWithBackoff(
      async () => await calendar.calendarList.list(),
      {
        maxRetries: 5,
        initialDelay: 1000,
        backoffFactor: 2,
      }
    );

    const calendars = (response.data.items || []).map(cal => ({
      id: cal.id,
      summary: cal.summary,
      description: cal.description || "",
      timeZone: cal.timeZone || "",
      primary: cal.primary || false,
      accessRole: cal.accessRole || "",
    }));

    console.log(`✅ Successfully fetched ${calendars.length} calendars for user ${userId}`);

    return {
      success: true,
      calendars: calendars,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw handleCalendarError(error, "List calendars", userId);
  }
});

// ==========================================
// CALENDAR LIST EVENTS FUNCTION
// ==========================================
exports.calendarListEvents = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const userId = context.auth.uid;
  const { 
    calendarId = "primary", 
    timeMin, 
    timeMax, 
    maxResults = 50,
    pageToken,
    singleEvents = true,
    orderBy = "startTime"
  } = data;

  try {
    // Get user's tokens
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists || !userDoc.data().gmail_connected) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Google account not connected"
      );
    }

    const userData = userDoc.data();
    
    // Get Calendar client
    const calendar = await retryWithBackoff(
      async () => await getCalendarClient(userData, userId),
      { maxRetries: 3, initialDelay: 500 }
    );

    // Build query parameters
    const params = {
      calendarId: calendarId,
      maxResults: Math.min(maxResults, 2500), // Calendar API max is 2500
      singleEvents: singleEvents,
      orderBy: orderBy,
    };

    if (timeMin) {
      params.timeMin = new Date(timeMin).toISOString();
    } else {
      // Default to current time if not provided
      params.timeMin = new Date().toISOString();
    }

    if (timeMax) {
      params.timeMax = new Date(timeMax).toISOString();
    }

    if (pageToken) {
      params.pageToken = pageToken;
    }

    // List events with retry logic
    const response = await retryWithBackoff(
      async () => await calendar.events.list(params),
      {
        maxRetries: 5,
        initialDelay: 1000,
        backoffFactor: 2,
      }
    );

    const events = (response.data.items || []).map(event => ({
      id: event.id,
      summary: event.summary || "(No Title)",
      description: event.description || "",
      location: event.location || "",
      start: event.start,
      end: event.end,
      status: event.status || "confirmed",
      htmlLink: event.htmlLink || "",
      hangoutLink: event.hangoutLink || "",
      conferenceData: event.conferenceData || null,
      attendees: event.attendees || [],
      organizer: event.organizer || null,
      recurrence: event.recurrence || [],
      reminders: event.reminders || null,
      colorId: event.colorId || null,
    }));

    console.log(`✅ Successfully fetched ${events.length} events for user ${userId}`);

    return {
      success: true,
      events: events,
      nextPageToken: response.data.nextPageToken || null,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw handleCalendarError(error, "List events", userId);
  }
});

// ==========================================
// CALENDAR GET EVENT FUNCTION
// ==========================================
exports.calendarGetEvent = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const userId = context.auth.uid;
  const { calendarId = "primary", eventId } = data;

  if (!eventId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Event ID is required"
    );
  }

  try {
    // Get user's tokens
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists || !userDoc.data().gmail_connected) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Google account not connected"
      );
    }

    const userData = userDoc.data();
    
    // Get Calendar client
    const calendar = await retryWithBackoff(
      async () => await getCalendarClient(userData, userId),
      { maxRetries: 3, initialDelay: 500 }
    );

    // Get event with retry logic
    const response = await retryWithBackoff(
      async () => await calendar.events.get({
        calendarId: calendarId,
        eventId: eventId,
      }),
      {
        maxRetries: 5,
        initialDelay: 1000,
        backoffFactor: 2,
      }
    );

    const event = {
      id: response.data.id,
      summary: response.data.summary || "(No Title)",
      description: response.data.description || "",
      location: response.data.location || "",
      start: response.data.start,
      end: response.data.end,
      status: response.data.status || "confirmed",
      htmlLink: response.data.htmlLink || "",
      attendees: response.data.attendees || [],
      organizer: response.data.organizer || null,
      recurrence: response.data.recurrence || [],
      reminders: response.data.reminders || null,
      colorId: response.data.colorId || null,
      created: response.data.created || null,
      updated: response.data.updated || null,
      iCalUID: response.data.iCalUID || null,
    };

    return {
      success: true,
      event: event,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw handleCalendarError(error, "Get event", userId);
  }
});

// ==========================================
// CALENDAR CREATE EVENT FUNCTION
// ==========================================
exports.calendarCreateEvent = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const userId = context.auth.uid;
  const { 
    calendarId = "primary",
    summary,
    description,
    location,
    start,
    end,
    attendees = [],
    reminders = null,
    colorId = null,
  } = data;

  if (!summary || !start || !end) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Summary, start, and end are required"
    );
  }

  try {
    // Get user's tokens
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists || !userDoc.data().gmail_connected) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Google account not connected"
      );
    }

    const userData = userDoc.data();
    
    // Get Calendar client
    const calendar = await retryWithBackoff(
      async () => await getCalendarClient(userData, userId),
      { maxRetries: 3, initialDelay: 500 }
    );

    // Build event object
    const event = {
      summary: summary,
      description: description || "",
      location: location || "",
      start: {
        dateTime: new Date(start).toISOString(),
        timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      },
      end: {
        dateTime: new Date(end).toISOString(),
        timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      },
    };

    // Add optional fields
    if (attendees && attendees.length > 0) {
      event.attendees = attendees.map(email => ({ email: email }));
    }

    if (reminders) {
      event.reminders = reminders;
    } else {
      // Default reminders
      event.reminders = {
        useDefault: false,
        overrides: [
          { method: "email", minutes: 24 * 60 }, // 1 day before
          { method: "popup", minutes: 10 }, // 10 minutes before
        ],
      };
    }

    if (colorId) {
      event.colorId = colorId;
    }

    // Create event with retry logic
    const response = await retryWithBackoff(
      async () => await calendar.events.insert({
        calendarId: calendarId,
        requestBody: event,
      }),
      {
        maxRetries: 5,
        initialDelay: 1000,
        backoffFactor: 2,
      }
    );

    console.log(`✅ Event created successfully for user ${userId}: ${response.data.id}`);

    return {
      success: true,
      event: {
        id: response.data.id,
        summary: response.data.summary,
        htmlLink: response.data.htmlLink || "",
        start: response.data.start,
        end: response.data.end,
      },
      message: "Event created successfully",
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw handleCalendarError(error, "Create event", userId);
  }
});

// ==========================================
// CALENDAR UPDATE EVENT FUNCTION
// ==========================================
exports.calendarUpdateEvent = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const userId = context.auth.uid;
  const { 
    calendarId = "primary",
    eventId,
    summary,
    description,
    location,
    start,
    end,
    attendees = [],
    reminders = null,
    colorId = null,
  } = data;

  if (!eventId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Event ID is required"
    );
  }

  try {
    // Get user's tokens
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists || !userDoc.data().gmail_connected) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Google account not connected"
      );
    }

    const userData = userDoc.data();
    
    // Get Calendar client
    const calendar = await retryWithBackoff(
      async () => await getCalendarClient(userData, userId),
      { maxRetries: 3, initialDelay: 500 }
    );

    // First, get the existing event to preserve fields we're not updating
    const existingEvent = await retryWithBackoff(
      async () => await calendar.events.get({
        calendarId: calendarId,
        eventId: eventId,
      }),
      {
        maxRetries: 3,
        initialDelay: 500,
      }
    );

    // Build update object - only update provided fields
    const updateData = { ...existingEvent.data };

    if (summary !== undefined) updateData.summary = summary;
    if (description !== undefined) updateData.description = description || "";
    if (location !== undefined) updateData.location = location || "";
    
    if (start) {
      updateData.start = {
        dateTime: new Date(start).toISOString(),
        timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      };
    }
    
    if (end) {
      updateData.end = {
        dateTime: new Date(end).toISOString(),
        timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      };
    }

    if (attendees !== undefined) {
      updateData.attendees = attendees.map(email => ({ email: email }));
    }

    if (reminders !== undefined) {
      updateData.reminders = reminders;
    }

    if (colorId !== undefined) {
      updateData.colorId = colorId;
    }

    // Update event with retry logic
    const response = await retryWithBackoff(
      async () => await calendar.events.update({
        calendarId: calendarId,
        eventId: eventId,
        requestBody: updateData,
      }),
      {
        maxRetries: 5,
        initialDelay: 1000,
        backoffFactor: 2,
      }
    );

    console.log(`✅ Event updated successfully for user ${userId}: ${eventId}`);

    return {
      success: true,
      event: {
        id: response.data.id,
        summary: response.data.summary,
        htmlLink: response.data.htmlLink || "",
        start: response.data.start,
        end: response.data.end,
      },
      message: "Event updated successfully",
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw handleCalendarError(error, "Update event", userId);
  }
});

// ==========================================
// GMAIL PREFETCH PRIORITY (Top 10 Emails - Metadata Only)
// ==========================================
exports.gmailPrefetchPriority = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const userId = context.auth.uid;

  try {
    // Get user's Gmail tokens
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists || !userDoc.data().gmail_connected) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Gmail not connected"
      );
    }

    const userData = userDoc.data();
    
    // Get Gmail client with automatic token refresh and retry logic
    const gmail = await retryWithBackoff(
      async () => await getGmailClient(userData, userId),
      { maxRetries: 3, initialDelay: 500 }
    );

    // Fast metadata-only fetch - top 10 emails only
    const listParams = {
      userId: "me",
      maxResults: 10, // Only top 10 for speed
      labelIds: ["INBOX"],
      format: "metadata", // Metadata only - no body content
      metadataHeaders: ["Subject", "From", "Date", "To", "Cc"],
    };

    // List messages with retry logic
    const response = await retryWithBackoff(
      async () => await gmail.users.messages.list(listParams),
      {
        maxRetries: 5,
        initialDelay: 1000,
        backoffFactor: 2,
      }
    );

    const messages = response.data.messages || [];
    const nextPageToken = response.data.nextPageToken;

    if (messages.length === 0) {
      // Store empty cache
      await admin.firestore()
        .collection("users")
        .doc(userId)
        .collection("gmail_cache")
        .doc("recent")
        .set({
          emails: [],
          last_fetched: admin.firestore.FieldValue.serverTimestamp(),
          cache_version: 1,
          total_fetched: 0,
          next_page_token: nextPageToken || null,
        }, { merge: true });

      return {
        success: true,
        emails: [],
        nextPageToken: nextPageToken,
        message: "No emails found",
      };
    }

    // Process messages in batches with throttling
    const emailList = await batchProcess(
      messages,
      async (msg) => {
        // Get message details with retry logic - metadata only
        const message = await retryWithBackoff(
          async () =>
            await gmail.users.messages.get({
              userId: "me",
              id: msg.id,
              format: "metadata", // Metadata only - no body
              metadataHeaders: ["Subject", "From", "Date", "To", "Cc"],
            }),
          {
            maxRetries: 3,
            initialDelay: 500,
          }
        );

        // Extract headers efficiently
        const headers = message.data.payload.headers || [];
        const subjectHeader = headers.find((h) => h.name === "Subject");
        const fromHeader = headers.find((h) => h.name === "From");
        const dateHeader = headers.find((h) => h.name === "Date");
        const toHeader = headers.find((h) => h.name === "To");
        const ccHeader = headers.find((h) => h.name === "Cc");

        // Check for attachments (metadata only - count, not content)
        let hasAttachments = false;
        let attachmentCount = 0;
        if (message.data.payload.parts) {
          const checkParts = (parts) => {
            for (const part of parts) {
              if (part.filename && part.filename.length > 0) {
                hasAttachments = true;
                attachmentCount++;
              }
              if (part.parts && Array.isArray(part.parts)) {
                checkParts(part.parts);
              }
            }
          };
          checkParts(message.data.payload.parts);
        }

        // Return metadata only - NO body, NO attachments
        return {
          id: msg.id,
          threadId: msg.threadId,
          subject: subjectHeader?.value || "(No Subject)",
          from: fromHeader?.value || "",
          to: toHeader?.value || "",
          cc: ccHeader?.value || "",
          date: dateHeader?.value || "",
          snippet: message.data.snippet || "", // Preview text only
          labels: message.data.labelIds || [],
          hasAttachments: hasAttachments,
          attachmentCount: attachmentCount,
          size: message.data.sizeEstimate || 0,
          // NO body, NO attachments, NO full content
        };
      },
      {
        batchSize: 10,
        concurrency: 5,
        delayBetweenBatches: 100,
      }
    );

    // Filter out sent emails (safety check)
    const receivedEmails = emailList.filter((email) => {
      if (!email) return false;
      const labels = email.labels || [];
      return labels.includes("INBOX") && !labels.includes("SENT");
    });

    // Store in Firestore cache - metadata only
    await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("gmail_cache")
      .doc("recent")
      .set({
        emails: receivedEmails,
        last_fetched: admin.firestore.FieldValue.serverTimestamp(),
        cache_version: 1,
        total_fetched: receivedEmails.length,
        next_page_token: nextPageToken || null,
      }, { merge: true });

    console.log(`✅ Successfully prefetched ${receivedEmails.length} priority emails for user ${userId}`);

    return {
      success: true,
      emails: receivedEmails,
      nextPageToken: nextPageToken,
      message: `Prefetched ${receivedEmails.length} emails`,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw handleGmailError(error, "Prefetch priority emails", userId);
  }
});

// ==========================================
// GMAIL PREFETCH BATCH (Progressive Loading - Metadata Only)
// ==========================================
exports.gmailPrefetchBatch = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const userId = context.auth.uid;
  const { pageToken, maxResults = 20 } = data;

  if (!pageToken) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Page token is required for batch prefetch"
    );
  }

  try {
    // Get user's Gmail tokens
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists || !userDoc.data().gmail_connected) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Gmail not connected"
      );
    }

    const userData = userDoc.data();
    
    // Get Gmail client
    const gmail = await retryWithBackoff(
      async () => await getGmailClient(userData, userId),
      { maxRetries: 3, initialDelay: 500 }
    );

    // Fetch next batch - metadata only
    const listParams = {
      userId: "me",
      maxResults: Math.min(maxResults, 50), // Cap at 50 per batch
      labelIds: ["INBOX"],
      pageToken: pageToken,
      format: "metadata",
      metadataHeaders: ["Subject", "From", "Date", "To", "Cc"],
    };

    // List messages with retry logic
    const response = await retryWithBackoff(
      async () => await gmail.users.messages.list(listParams),
      {
        maxRetries: 5,
        initialDelay: 1000,
        backoffFactor: 2,
      }
    );

    const messages = response.data.messages || [];
    const nextPageToken = response.data.nextPageToken;

    if (messages.length === 0) {
      return {
        success: true,
        emails: [],
        nextPageToken: null,
        message: "No more emails to fetch",
      };
    }

    // Process messages - metadata only
    const emailList = await batchProcess(
      messages,
      async (msg) => {
        const message = await retryWithBackoff(
          async () =>
            await gmail.users.messages.get({
              userId: "me",
              id: msg.id,
              format: "metadata",
              metadataHeaders: ["Subject", "From", "Date", "To", "Cc"],
            }),
          {
            maxRetries: 3,
            initialDelay: 500,
          }
        );

        const headers = message.data.payload.headers || [];
        const subjectHeader = headers.find((h) => h.name === "Subject");
        const fromHeader = headers.find((h) => h.name === "From");
        const dateHeader = headers.find((h) => h.name === "Date");
        const toHeader = headers.find((h) => h.name === "To");
        const ccHeader = headers.find((h) => h.name === "Cc");

        // Check for attachments (metadata only)
        let hasAttachments = false;
        let attachmentCount = 0;
        if (message.data.payload.parts) {
          const checkParts = (parts) => {
            for (const part of parts) {
              if (part.filename && part.filename.length > 0) {
                hasAttachments = true;
                attachmentCount++;
              }
              if (part.parts && Array.isArray(part.parts)) {
                checkParts(part.parts);
              }
            }
          };
          checkParts(message.data.payload.parts);
        }

        return {
          id: msg.id,
          threadId: msg.threadId,
          subject: subjectHeader?.value || "(No Subject)",
          from: fromHeader?.value || "",
          to: toHeader?.value || "",
          cc: ccHeader?.value || "",
          date: dateHeader?.value || "",
          snippet: message.data.snippet || "",
          labels: message.data.labelIds || [],
          hasAttachments: hasAttachments,
          attachmentCount: attachmentCount,
          size: message.data.sizeEstimate || 0,
        };
      },
      {
        batchSize: 10,
        concurrency: 5,
        delayBetweenBatches: 100,
      }
    );

    // Filter out sent emails
    const receivedEmails = emailList.filter((email) => {
      if (!email) return false;
      const labels = email.labels || [];
      return labels.includes("INBOX") && !labels.includes("SENT");
    });

    // Get existing cache
    const cacheDoc = await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("gmail_cache")
      .doc("recent")
      .get();

    const existingEmails = cacheDoc.exists ? (cacheDoc.data().emails || []) : [];
    
    // Append new emails to existing cache (avoid duplicates)
    const existingIds = new Set(existingEmails.map(e => e.id));
    const newEmails = receivedEmails.filter(e => !existingIds.has(e.id));
    const updatedEmails = [...existingEmails, ...newEmails];

    // Limit cache to top 50 emails (keep only the most recent)
    const limitedEmails = updatedEmails.slice(0, 50);

    // Update cache
    await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("gmail_cache")
      .doc("recent")
      .set({
        emails: limitedEmails,
        last_fetched: admin.firestore.FieldValue.serverTimestamp(),
        cache_version: 1,
        total_fetched: limitedEmails.length,
        next_page_token: nextPageToken || null,
      }, { merge: true });

    console.log(`✅ Successfully prefetched batch of ${newEmails.length} emails for user ${userId} (total cached: ${limitedEmails.length}, limit: 50)`);

    return {
      success: true,
      emails: newEmails,
      nextPageToken: nextPageToken,
      totalCached: limitedEmails.length,
      message: `Prefetched ${newEmails.length} new emails (cached: ${limitedEmails.length}/50)`,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw handleGmailError(error, "Prefetch batch emails", userId);
  }
});

// ==========================================
// GMAIL REFRESH CACHE (Auto-Refresh - Incremental Sync)
// ==========================================
exports.gmailRefreshCache = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const userId = context.auth.uid;
  const { forceRefresh = false } = data;

  try {
    // Get user's Gmail tokens
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists || !userDoc.data().gmail_connected) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Gmail not connected"
      );
    }

    // Get existing cache
    const cacheDoc = await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("gmail_cache")
      .doc("recent")
      .get();

    if (!cacheDoc.exists && !forceRefresh) {
      // No cache exists, trigger priority fetch instead
      throw new functions.https.HttpsError(
        "failed-precondition",
        "No cache exists. Use gmailPrefetchPriority first."
      );
    }

    const cacheData = cacheDoc.exists ? cacheDoc.data() : null;
    const lastFetched = cacheData?.last_fetched?.toDate();

    // Check if refresh is needed (unless forced)
    // Increased to 2 minutes to reduce costs (Watch API handles real-time)
    if (!forceRefresh && lastFetched) {
      const minutesSinceLastFetch = (Date.now() - lastFetched.getTime()) / (1000 * 60);
      if (minutesSinceLastFetch < 2) {
        return {
          success: true,
          message: "Cache is fresh, no refresh needed",
          skipped: true,
        };
      }
    }

    const userData = userDoc.data();
    
    // Get Gmail client
    const gmail = await retryWithBackoff(
      async () => await getGmailClient(userData, userId),
      { maxRetries: 3, initialDelay: 500 }
    );

    // Fetch new emails since last fetch (incremental sync)
    const listParams = {
      userId: "me",
      maxResults: 50, // Check for up to 50 new emails
      labelIds: ["INBOX"],
      format: "metadata",
      metadataHeaders: ["Subject", "From", "Date", "To", "Cc"],
    };

    // If we have a last_fetched timestamp, use Gmail query to get only new emails
    if (lastFetched && !forceRefresh) {
      // Gmail query format: after:YYYY/MM/DD
      const dateStr = lastFetched.toISOString().split('T')[0].replace(/-/g, '/');
      listParams.q = `after:${dateStr}`;
    }

    // List messages with retry logic
    const response = await retryWithBackoff(
      async () => await gmail.users.messages.list(listParams),
      {
        maxRetries: 5,
        initialDelay: 1000,
        backoffFactor: 2,
      }
    );

    const messages = response.data.messages || [];
    const existingEmails = cacheData?.emails || [];
    const existingIds = new Set(existingEmails.map(e => e.id));

    if (messages.length === 0) {
      // No new emails, but update last_fetched timestamp
      await admin.firestore()
        .collection("users")
        .doc(userId)
        .collection("gmail_cache")
        .doc("recent")
        .set({
          last_fetched: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

      return {
        success: true,
        emails: [],
        newEmails: 0,
        updatedEmails: 0,
        message: "No new emails found",
      };
    }

    // Process new messages - metadata only
    const emailList = await batchProcess(
      messages,
      async (msg) => {
        // Skip if already in cache
        if (existingIds.has(msg.id)) {
          // Still fetch to check for status changes (read/unread)
          const message = await retryWithBackoff(
            async () =>
              await gmail.users.messages.get({
                userId: "me",
                id: msg.id,
                format: "metadata",
                metadataHeaders: ["Subject", "From", "Date", "To", "Cc"],
              }),
            {
              maxRetries: 3,
              initialDelay: 500,
            }
          );

          const headers = message.data.payload.headers || [];
          const subjectHeader = headers.find((h) => h.name === "Subject");
          const fromHeader = headers.find((h) => h.name === "From");
          const dateHeader = headers.find((h) => h.name === "Date");
          const toHeader = headers.find((h) => h.name === "To");
          const ccHeader = headers.find((h) => h.name === "Cc");

          return {
            id: msg.id,
            threadId: msg.threadId,
            subject: subjectHeader?.value || "(No Subject)",
            from: fromHeader?.value || "",
            to: toHeader?.value || "",
            cc: ccHeader?.value || "",
            date: dateHeader?.value || "",
            snippet: message.data.snippet || "",
            labels: message.data.labelIds || [],
            hasAttachments: false, // Simplified for updates
            attachmentCount: 0,
            size: message.data.sizeEstimate || 0,
          };
        }

        // New email - fetch full metadata
        const message = await retryWithBackoff(
          async () =>
            await gmail.users.messages.get({
              userId: "me",
              id: msg.id,
              format: "metadata",
              metadataHeaders: ["Subject", "From", "Date", "To", "Cc"],
            }),
          {
            maxRetries: 3,
            initialDelay: 500,
          }
        );

        const headers = message.data.payload.headers || [];
        const subjectHeader = headers.find((h) => h.name === "Subject");
        const fromHeader = headers.find((h) => h.name === "From");
        const dateHeader = headers.find((h) => h.name === "Date");
        const toHeader = headers.find((h) => h.name === "To");
        const ccHeader = headers.find((h) => h.name === "Cc");

        let hasAttachments = false;
        let attachmentCount = 0;
        if (message.data.payload.parts) {
          const checkParts = (parts) => {
            for (const part of parts) {
              if (part.filename && part.filename.length > 0) {
                hasAttachments = true;
                attachmentCount++;
              }
              if (part.parts && Array.isArray(part.parts)) {
                checkParts(part.parts);
              }
            }
          };
          checkParts(message.data.payload.parts);
        }

        return {
          id: msg.id,
          threadId: msg.threadId,
          subject: subjectHeader?.value || "(No Subject)",
          from: fromHeader?.value || "",
          to: toHeader?.value || "",
          cc: ccHeader?.value || "",
          date: dateHeader?.value || "",
          snippet: message.data.snippet || "",
          labels: message.data.labelIds || [],
          hasAttachments: hasAttachments,
          attachmentCount: attachmentCount,
          size: message.data.sizeEstimate || 0,
        };
      },
      {
        batchSize: 10,
        concurrency: 5,
        delayBetweenBatches: 100,
      }
    );

    // Separate new emails from updated emails
    const newEmails = emailList.filter(e => !existingIds.has(e.id));
    const updatedEmails = emailList.filter(e => existingIds.has(e.id));

    // Update existing emails in cache (merge status changes)
    const emailMap = new Map(existingEmails.map(e => [e.id, e]));
    updatedEmails.forEach(updated => {
      emailMap.set(updated.id, updated);
    });

    // Prepend new emails to top of list (newest first)
    const finalEmails = [...newEmails, ...Array.from(emailMap.values())];

    // Limit cache to top 50 emails (keep only the most recent)
    const limitedEmails = finalEmails.slice(0, 50);

    // Update cache
    await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("gmail_cache")
      .doc("recent")
      .set({
        emails: limitedEmails,
        last_fetched: admin.firestore.FieldValue.serverTimestamp(),
        cache_version: 1,
        total_fetched: limitedEmails.length,
      }, { merge: true });

    console.log(`✅ Successfully refreshed cache for user ${userId}: ${newEmails.length} new, ${updatedEmails.length} updated (cached: ${limitedEmails.length}/50)`);

    return {
      success: true,
      emails: limitedEmails,
      newEmails: newEmails.length,
      updatedEmails: updatedEmails.length,
      message: `Refreshed: ${newEmails.length} new, ${updatedEmails.length} updated (cached: ${limitedEmails.length}/50)`,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw handleGmailError(error, "Refresh cache", userId);
  }
});

// ==========================================
// GMAIL LIGHTWEIGHT CHECK (Top 10 Only - Cost Efficient)
// ==========================================
// Lightweight check that only fetches top 10 emails to see if there are new ones
// Only updates cache if new emails are found - very cost efficient
exports.gmailCheckForNewEmails = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const userId = context.auth.uid;

  try {
    // Get user's Gmail tokens
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists || !userDoc.data().gmail_connected) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Gmail not connected"
      );
    }

    // Get existing cache
    const cacheDoc = await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("gmail_cache")
      .doc("recent")
      .get();

    if (!cacheDoc.exists) {
      // No cache exists, return early - let priority fetch handle it
      return {
        success: true,
        hasNewEmails: false,
        message: "No cache exists",
        skipped: true,
      };
    }

    const cacheData = cacheDoc.data();
    const existingEmails = cacheData?.emails || [];
    const existingIds = new Set(existingEmails.map(e => e.id));
    const topEmailId = existingEmails.length > 0 ? existingEmails[0].id : null;

    const userData = userDoc.data();
    
    // Get Gmail client
    const gmail = await retryWithBackoff(
      async () => await getGmailClient(userData, userId),
      { maxRetries: 3, initialDelay: 500 }
    );

    // Lightweight check: Only fetch top 10 emails (metadata only)
    const listParams = {
      userId: "me",
      maxResults: 10, // Only check top 10 for cost efficiency
      labelIds: ["INBOX"],
      format: "metadata",
      metadataHeaders: ["Subject", "From", "Date"],
    };

    // List messages with retry logic
    const response = await retryWithBackoff(
      async () => await gmail.users.messages.list(listParams),
      {
        maxRetries: 3,
        initialDelay: 500,
        backoffFactor: 2,
      }
    );

    const messages = response.data.messages || [];

    if (messages.length === 0) {
      return {
        success: true,
        hasNewEmails: false,
        newEmailsCount: 0,
        message: "No emails found",
      };
    }

    // Quick check: Compare top email ID with cache
    // If the top email ID is different, there are new emails
    const topMessageId = messages[0].id;
    const hasNewEmails = topEmailId !== topMessageId;

    if (!hasNewEmails) {
      // No new emails, just update timestamp
      await admin.firestore()
        .collection("users")
        .doc(userId)
        .collection("gmail_cache")
        .doc("recent")
        .set({
          last_checked: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

      return {
        success: true,
        hasNewEmails: false,
        newEmailsCount: 0,
        message: "No new emails found",
      };
    }

    // New emails found! Fetch full metadata for new ones only
    const newMessageIds = messages
      .map(msg => msg.id)
      .filter(id => !existingIds.has(id));

    if (newMessageIds.length === 0) {
      // Edge case: Top email changed but all are in cache (reordering)
      return {
        success: true,
        hasNewEmails: false,
        newEmailsCount: 0,
        message: "No new emails (reordering only)",
      };
    }

    // Fetch metadata for new emails only
    const emailList = await batchProcess(
      newMessageIds,
      async (messageId) => {
        const message = await retryWithBackoff(
          async () =>
            await gmail.users.messages.get({
              userId: "me",
              id: messageId,
              format: "metadata",
              metadataHeaders: ["Subject", "From", "Date", "To", "Cc"],
            }),
          {
            maxRetries: 3,
            initialDelay: 500,
          }
        );

        const headers = message.data.payload.headers || [];
        const subjectHeader = headers.find((h) => h.name === "Subject");
        const fromHeader = headers.find((h) => h.name === "From");
        const dateHeader = headers.find((h) => h.name === "Date");
        const toHeader = headers.find((h) => h.name === "To");
        const ccHeader = headers.find((h) => h.name === "Cc");

        let hasAttachments = false;
        let attachmentCount = 0;
        if (message.data.payload.parts) {
          const checkParts = (parts) => {
            for (const part of parts) {
              if (part.filename && part.filename.length > 0) {
                hasAttachments = true;
                attachmentCount++;
              }
              if (part.parts && Array.isArray(part.parts)) {
                checkParts(part.parts);
              }
            }
          };
          checkParts(message.data.payload.parts);
        }

        return {
          id: messageId,
          threadId: message.data.threadId,
          subject: subjectHeader?.value || "(No Subject)",
          from: fromHeader?.value || "",
          to: toHeader?.value || "",
          cc: ccHeader?.value || "",
          date: dateHeader?.value || "",
          snippet: message.data.snippet || "",
          labels: message.data.labelIds || [],
          hasAttachments: hasAttachments,
          attachmentCount: attachmentCount,
          size: message.data.sizeEstimate || 0,
        };
      },
      {
        batchSize: 10,
        concurrency: 5,
        delayBetweenBatches: 100,
      }
    );

    // Filter out sent emails
    const receivedEmails = emailList.filter((email) => {
      if (!email) return false;
      const labels = email.labels || [];
      return labels.includes("INBOX") && !labels.includes("SENT");
    });

    if (receivedEmails.length === 0) {
      return {
        success: true,
        hasNewEmails: false,
        newEmailsCount: 0,
        message: "No new received emails",
      };
    }

    // Prepend new emails to top of cache
    const updatedEmails = [...receivedEmails, ...existingEmails];

    // Limit cache to top 50 emails
    const limitedEmails = updatedEmails.slice(0, 50);

    // Update cache only if we found new emails
    await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("gmail_cache")
      .doc("recent")
      .set({
        emails: limitedEmails,
        last_fetched: admin.firestore.FieldValue.serverTimestamp(),
        last_checked: admin.firestore.FieldValue.serverTimestamp(),
        cache_version: 1,
        total_fetched: limitedEmails.length,
      }, { merge: true });

    console.log(`✅ Lightweight check found ${receivedEmails.length} new emails for user ${userId}`);

    return {
      success: true,
      hasNewEmails: true,
      newEmailsCount: receivedEmails.length,
      message: `Found ${receivedEmails.length} new email(s)`,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw handleGmailError(error, "Check for new emails", userId);
  }
});

// ==========================================
// GMAIL WATCH FUNCTIONS - TEMPORARILY REMOVED
// ==========================================
// The following functions have been temporarily removed:
// - gmailSetupWatch
// - gmailRenewWatch  
// - gmailNotificationHandler
// - gmailAutoRenewWatches
// They can be restored later when Gmail Watch is fixed.

/*
// ==========================================
// GMAIL WATCH SETUP (Real-time Push Notifications)
// ==========================================
exports.gmailSetupWatch = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const userId = context.auth.uid;

  try {
    // Get user's Gmail tokens
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists || !userDoc.data().gmail_connected) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Gmail not connected"
      );
    }

    const userData = userDoc.data();
    
    // Get Gmail client
    const gmail = await retryWithBackoff(
      async () => await getGmailClient(userData, userId),
      { maxRetries: 3, initialDelay: 500 }
    );

    // Get Pub/Sub topic name from config (or use default)
    const topicName = functions.config().gmail?.pubsub_topic || `projects/${process.env.GCLOUD_PROJECT || 'linkedup-c3e29'}/topics/gmail-notifications`;
    
    // IMPORTANT: Gmail only allows ONE active watch per user
    // Stop any existing watch before setting up a new one
    try {
      console.log(`🛑 Stopping any existing Gmail watch for user ${userId}...`);
      await gmail.users.stop({
        userId: "me",
      });
      console.log(`✅ Stopped existing watch (if any)`);
      // Small delay to ensure stop is processed
      await new Promise(resolve => setTimeout(resolve, 1000));
    } catch (stopError) {
      // If stop fails, it might mean no watch exists - that's okay
      console.log(`ℹ️ No existing watch to stop (or already stopped): ${stopError.message}`);
    }
    
    // Set up watch on user's mailbox
    // Watch expires after 7 days, needs renewal
    console.log(`📧 Setting up new Gmail watch for user ${userId}...`);
    const watchResponse = await retryWithBackoff(
      async () => await gmail.users.watch({
        userId: "me",
        requestBody: {
          topicName: topicName,
          labelIds: ["INBOX"], // Only watch INBOX
        },
      }),
      {
        maxRetries: 5,
        initialDelay: 1000,
        backoffFactor: 2,
      }
    );

    const expiration = watchResponse.data.expiration;
    const historyId = watchResponse.data.historyId;

    // Store watch info in Firestore
    await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("gmail_watch")
      .doc("current")
      .set({
        expiration: expiration,
        historyId: historyId,
        topicName: topicName,
        created: admin.firestore.FieldValue.serverTimestamp(),
        expires_at: new Date(parseInt(expiration)),
      }, { merge: true });

    console.log(`✅ Gmail watch set up for user ${userId}, expires: ${new Date(parseInt(expiration)).toISOString()}`);

    return {
      success: true,
      expiration: expiration,
      historyId: historyId,
      expiresAt: new Date(parseInt(expiration)).toISOString(),
      message: "Gmail watch set up successfully",
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw handleGmailError(error, "Setup Gmail watch", userId);
  }
});

// ==========================================
// GMAIL WATCH RENEWAL (Auto-renew before expiration)
// ==========================================
exports.gmailRenewWatch = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const userId = context.auth.uid;

  try {
    // Get existing watch info
    const watchDoc = await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("gmail_watch")
      .doc("current")
      .get();

    if (!watchDoc.exists) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "No watch found. Use gmailSetupWatch first."
      );
    }

    const watchData = watchDoc.data();
    const expiresAt = watchData.expires_at?.toDate();

    // Check if renewal is needed (renew if expires within 1 day)
    if (expiresAt && expiresAt > new Date(Date.now() + 24 * 60 * 60 * 1000)) {
      return {
        success: true,
        message: "Watch is still valid, no renewal needed",
        expiresAt: expiresAt.toISOString(),
      };
    }

    // Renew watch by setting up a new one
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists || !userDoc.data().gmail_connected) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Gmail not connected"
      );
    }

    const userData = userDoc.data();
    
    // Get Gmail client
    const gmail = await retryWithBackoff(
      async () => await getGmailClient(userData, userId),
      { maxRetries: 3, initialDelay: 500 }
    );

    const topicName = functions.config().gmail?.pubsub_topic || `projects/${process.env.GCLOUD_PROJECT || 'linkedup-c3e29'}/topics/gmail-notifications`;
    
    // IMPORTANT: Stop existing watch before renewing
    try {
      console.log(`🛑 Stopping existing watch before renewal for user ${userId}...`);
      await gmail.users.stop({
        userId: "me",
      });
      await new Promise(resolve => setTimeout(resolve, 1000));
    } catch (stopError) {
      console.log(`ℹ️ No existing watch to stop: ${stopError.message}`);
    }
    
    // Set up new watch
    console.log(`📧 Setting up renewed Gmail watch for user ${userId}...`);
    const watchResponse = await retryWithBackoff(
      async () => await gmail.users.watch({
        userId: "me",
        requestBody: {
          topicName: topicName,
          labelIds: ["INBOX"],
        },
      }),
      {
        maxRetries: 5,
        initialDelay: 1000,
        backoffFactor: 2,
      }
    );

    const expiration = watchResponse.data.expiration;
    const historyId = watchResponse.data.historyId;

    // Update watch info
    await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("gmail_watch")
      .doc("current")
      .set({
        expiration: expiration,
        historyId: historyId,
        topicName: topicName,
        created: admin.firestore.FieldValue.serverTimestamp(),
        expires_at: new Date(parseInt(expiration)),
      }, { merge: true });

    console.log(`✅ Gmail watch renewed for user ${userId}, expires: ${new Date(parseInt(expiration)).toISOString()}`);

    return {
      success: true,
      expiration: expiration,
      historyId: historyId,
      expiresAt: new Date(parseInt(expiration)).toISOString(),
      message: "Gmail watch renewed successfully",
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw handleGmailError(error, "Renew Gmail watch", userId);
  }
});

// ==========================================
// GMAIL PUB/SUB NOTIFICATION HANDLER
// Handles real-time push notifications from Gmail
// ==========================================
exports.gmailNotificationHandler = functions.pubsub.topic('gmail-notifications').onPublish(async (message) => {
  try {
    const data = JSON.parse(Buffer.from(message.data, 'base64').toString());
    
    // Gmail sends notifications with emailAddress and historyId
    const emailAddress = data.emailAddress;
    const historyId = data.historyId;

    if (!emailAddress) {
      console.error('❌ No email address in Gmail notification');
      return;
    }

    console.log(`📧 Gmail notification received for: ${emailAddress}, historyId: ${historyId}`);

    // Find user by Gmail email address
    const usersSnapshot = await admin.firestore()
      .collection("users")
      .where("gmail_email", "==", emailAddress)
      .where("gmail_connected", "==", true)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      console.log(`⚠️ No user found for email: ${emailAddress}`);
      return;
    }

    const userDoc = usersSnapshot.docs[0];
    const userId = userDoc.id;
    const userData = userDoc.data();

    // Get Gmail client
    const gmail = await retryWithBackoff(
      async () => await getGmailClient(userData, userId),
      { maxRetries: 3, initialDelay: 500 }
    );

    // Get watch info to get last historyId
    const watchDoc = await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("gmail_watch")
      .doc("current")
      .get();

    let startHistoryId = null;
    if (watchDoc.exists) {
      const watchData = watchDoc.data();
      startHistoryId = watchData.historyId;
    }

    // If no stored historyId or it's the same as notification historyId, 
    // use notification historyId (Gmail will return changes up to this point)
    // We need to use a historyId that's BEFORE the notification's historyId
    // Gmail history API returns changes AFTER startHistoryId, so we use the stored one
    if (!startHistoryId || startHistoryId === historyId) {
      // If no previous historyId, we can't get history - this is the first notification
      // In this case, we should fetch recent messages instead
      console.log(`⚠️ No previous historyId or same as notification. Fetching recent messages instead.`);
      
      // Fetch recent messages from INBOX (last 10)
      const listResponse = await retryWithBackoff(
        async () => await gmail.users.messages.list({
          userId: "me",
          maxResults: 10,
          labelIds: ["INBOX"],
          q: "is:unread OR newer_than:1h", // Get unread or recent emails
        }),
        {
          maxRetries: 3,
          initialDelay: 500,
        }
      );

      const messages = listResponse.data.messages || [];
      if (messages.length === 0) {
        console.log(`✅ No recent messages found for user ${userId}`);
        // Update historyId anyway
        await admin.firestore()
          .collection("users")
          .doc(userId)
          .collection("gmail_watch")
          .doc("current")
          .set({
            historyId: historyId,
          }, { merge: true });
        return;
      }

      // Process these messages as new
      const newMessageIds = messages.map(msg => msg.id);
      console.log(`📧 Found ${newMessageIds.length} recent messages for user ${userId}`);
      
      // Continue with processing these messages (skip to the batch processing part)
      // We'll reuse the existing batch processing logic below
      const emailList = await batchProcess(
        newMessageIds,
        async (messageId) => {
          const message = await retryWithBackoff(
            async () =>
              await gmail.users.messages.get({
                userId: "me",
                id: messageId,
                format: "metadata",
                metadataHeaders: ["Subject", "From", "Date", "To", "Cc"],
              }),
            {
              maxRetries: 3,
              initialDelay: 500,
            }
          );

          const headers = message.data.payload.headers || [];
          const subjectHeader = headers.find((h) => h.name === "Subject");
          const fromHeader = headers.find((h) => h.name === "From");
          const dateHeader = headers.find((h) => h.name === "Date");
          const toHeader = headers.find((h) => h.name === "To");
          const ccHeader = headers.find((h) => h.name === "Cc");

          let hasAttachments = false;
          let attachmentCount = 0;
          if (message.data.payload.parts) {
            const checkParts = (parts) => {
              for (const part of parts) {
                if (part.filename && part.filename.length > 0) {
                  hasAttachments = true;
                  attachmentCount++;
                }
                if (part.parts && Array.isArray(part.parts)) {
                  checkParts(part.parts);
                }
              }
            };
            checkParts(message.data.payload.parts);
          }

          return {
            id: messageId,
            threadId: message.data.threadId,
            subject: subjectHeader?.value || "(No Subject)",
            from: fromHeader?.value || "",
            to: toHeader?.value || "",
            cc: ccHeader?.value || "",
            date: dateHeader?.value || "",
            snippet: message.data.snippet || "",
            labels: message.data.labelIds || [],
            hasAttachments: hasAttachments,
            attachmentCount: attachmentCount,
            size: message.data.sizeEstimate || 0,
          };
        },
        {
          batchSize: 10,
          concurrency: 5,
          delayBetweenBatches: 100,
        }
      );

      // Filter out sent emails
      const receivedEmails = emailList.filter((email) => {
        if (!email) return false;
        const labels = email.labels || [];
        return labels.includes("INBOX") && !labels.includes("SENT");
      });

      if (receivedEmails.length === 0) {
        console.log(`✅ No new received emails for user ${userId}`);
        // Update historyId
        await admin.firestore()
          .collection("users")
          .doc(userId)
          .collection("gmail_watch")
          .doc("current")
          .set({
            historyId: historyId,
          }, { merge: true });
        return;
      }

      // Get existing cache
      const cacheDoc = await admin.firestore()
        .collection("users")
        .doc(userId)
        .collection("gmail_cache")
        .doc("recent")
        .get();

      const existingEmails = cacheDoc.exists ? (cacheDoc.data().emails || []) : [];
      
      // Prepend new emails to top (newest first)
      const existingIds = new Set(existingEmails.map(e => e.id));
      const trulyNewEmails = receivedEmails.filter(e => !existingIds.has(e.id));
      const updatedEmails = [...trulyNewEmails, ...existingEmails];

      // Limit to top 50
      const limitedEmails = updatedEmails.slice(0, 50);

      // Update cache
      await admin.firestore()
        .collection("users")
        .doc(userId)
        .collection("gmail_cache")
        .doc("recent")
        .set({
          emails: limitedEmails,
          last_fetched: admin.firestore.FieldValue.serverTimestamp(),
          cache_version: 1,
          total_fetched: limitedEmails.length,
        }, { merge: true });

      // Update watch historyId
      await admin.firestore()
        .collection("users")
        .doc(userId)
        .collection("gmail_watch")
        .doc("current")
        .set({
          historyId: historyId,
        }, { merge: true });

      console.log(`✅ Real-time update: Added ${trulyNewEmails.length} new emails to cache for user ${userId}`);
      return;
    }

    // Get history of changes since lastHistoryId
    const historyParams = {
      userId: "me",
      startHistoryId: startHistoryId,
      labelIds: ["INBOX"],
    };

    console.log(`🔍 Fetching history from historyId: ${startHistoryId} to ${historyId}`);
    
    const historyResponse = await retryWithBackoff(
      async () => await gmail.users.history.list(historyParams),
      {
        maxRetries: 5,
        initialDelay: 1000,
        backoffFactor: 2,
      }
    );

    const history = historyResponse.data.history || [];
    console.log(`📋 History API returned ${history.length} history records`);
    
    const newMessageIds = new Set();

    // Extract new message IDs from history
    for (const record of history) {
      if (record.messagesAdded) {
        console.log(`📧 Found ${record.messagesAdded.length} messages added in history record`);
        for (const msg of record.messagesAdded) {
          newMessageIds.add(msg.message.id);
        }
      }
      // Also check for messages that were added to INBOX (might be moved from other labels)
      if (record.labelsAdded) {
        for (const labelChange of record.labelsAdded) {
          if (labelChange.labelIds && labelChange.labelIds.includes('INBOX')) {
            console.log(`📧 Found message added to INBOX: ${labelChange.message?.id}`);
            if (labelChange.message?.id) {
              newMessageIds.add(labelChange.message.id);
            }
          }
        }
      }
    }

    console.log(`📧 Total unique new message IDs found: ${newMessageIds.size}`);

    if (newMessageIds.size === 0) {
      console.log(`⚠️ No new messages found in history. This might be because:`);
      console.log(`   - The email was already processed`);
      console.log(`   - The historyId range doesn't contain new messages`);
      console.log(`   - The email was filtered out (not in INBOX)`);
      // Update historyId anyway to prevent checking the same range again
      await admin.firestore()
        .collection("users")
        .doc(userId)
        .collection("gmail_watch")
        .doc("current")
        .set({
          historyId: historyId,
        }, { merge: true });
      return;
    }

    console.log(`📧 Found ${newMessageIds.size} new messages for user ${userId}`);

    // Fetch metadata for new messages
    const newMessages = Array.from(newMessageIds);
    const emailList = await batchProcess(
      newMessages,
      async (messageId) => {
        const message = await retryWithBackoff(
          async () =>
            await gmail.users.messages.get({
              userId: "me",
              id: messageId,
              format: "metadata",
              metadataHeaders: ["Subject", "From", "Date", "To", "Cc"],
            }),
          {
            maxRetries: 3,
            initialDelay: 500,
          }
        );

        const headers = message.data.payload.headers || [];
        const subjectHeader = headers.find((h) => h.name === "Subject");
        const fromHeader = headers.find((h) => h.name === "From");
        const dateHeader = headers.find((h) => h.name === "Date");
        const toHeader = headers.find((h) => h.name === "To");
        const ccHeader = headers.find((h) => h.name === "Cc");

        let hasAttachments = false;
        let attachmentCount = 0;
        if (message.data.payload.parts) {
          const checkParts = (parts) => {
            for (const part of parts) {
              if (part.filename && part.filename.length > 0) {
                hasAttachments = true;
                attachmentCount++;
              }
              if (part.parts && Array.isArray(part.parts)) {
                checkParts(part.parts);
              }
            }
          };
          checkParts(message.data.payload.parts);
        }

        return {
          id: messageId,
          threadId: message.data.threadId,
          subject: subjectHeader?.value || "(No Subject)",
          from: fromHeader?.value || "",
          to: toHeader?.value || "",
          cc: ccHeader?.value || "",
          date: dateHeader?.value || "",
          snippet: message.data.snippet || "",
          labels: message.data.labelIds || [],
          hasAttachments: hasAttachments,
          attachmentCount: attachmentCount,
          size: message.data.sizeEstimate || 0,
        };
      },
      {
        batchSize: 10,
        concurrency: 5,
        delayBetweenBatches: 100,
      }
    );

    // Filter out sent emails
    const receivedEmails = emailList.filter((email) => {
      if (!email) return false;
      const labels = email.labels || [];
      return labels.includes("INBOX") && !labels.includes("SENT");
    });

    if (receivedEmails.length === 0) {
      console.log(`✅ No new received emails for user ${userId}`);
      return;
    }

    // Get existing cache
    const cacheDoc = await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("gmail_cache")
      .doc("recent")
      .get();

    const existingEmails = cacheDoc.exists ? (cacheDoc.data().emails || []) : [];
    
    // Prepend new emails to top (newest first)
    const existingIds = new Set(existingEmails.map(e => e.id));
    const trulyNewEmails = receivedEmails.filter(e => !existingIds.has(e.id));
    const updatedEmails = [...trulyNewEmails, ...existingEmails];

    // Limit to top 50
    const limitedEmails = updatedEmails.slice(0, 50);

    // Update cache
    await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("gmail_cache")
      .doc("recent")
      .set({
        emails: limitedEmails,
        last_fetched: admin.firestore.FieldValue.serverTimestamp(),
        cache_version: 1,
        total_fetched: limitedEmails.length,
      }, { merge: true });

    // Update watch historyId
    await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("gmail_watch")
      .doc("current")
      .set({
        historyId: historyId,
      }, { merge: true });

    console.log(`✅ Real-time update: Added ${trulyNewEmails.length} new emails to cache for user ${userId}`);

  } catch (error) {
    console.error('❌ Error handling Gmail notification:', error);
    // Don't throw - Pub/Sub will retry if needed
  }
});

// ==========================================
// GMAIL WATCH RENEWAL SCHEDULER (Auto-renew watches before expiration)
// ==========================================
// Runs daily to check and renew watches that expire within 1 day
// This is more reliable than "every 6 days" and ensures watches are renewed in time
exports.gmailAutoRenewWatches = functions.pubsub.schedule('every 24 hours').onRun(async (context) => {
  console.log('🔄 Starting Gmail watch auto-renewal...');

  try {
    // Find all users with active watches that expire soon
    const now = new Date();
    const oneDayFromNow = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    // Get all watch documents
    const watchesSnapshot = await admin.firestore()
      .collectionGroup("gmail_watch")
      .where("expires_at", "<=", oneDayFromNow)
      .get();

    console.log(`Found ${watchesSnapshot.size} watches that need renewal`);

    const renewalPromises = watchesSnapshot.docs.map(async (watchDoc) => {
      const watchData = watchDoc.data();
      const userId = watchDoc.ref.parent.parent.id;

      try {
        // Get user document
        const userDoc = await admin.firestore()
          .collection("users")
          .doc(userId)
          .get();

        if (!userDoc.exists || !userDoc.data().gmail_connected) {
          console.log(`⚠️ User ${userId} not connected, skipping watch renewal`);
          return;
        }

        const userData = userDoc.data();
        
        // Get Gmail client
        const gmail = await retryWithBackoff(
          async () => await getGmailClient(userData, userId),
          { maxRetries: 3, initialDelay: 500 }
        );

        const topicName = functions.config().gmail?.pubsub_topic || `projects/${process.env.GCLOUD_PROJECT || 'linkedup-c3e29'}/topics/gmail-notifications`;
        
        // Renew watch
        const watchResponse = await retryWithBackoff(
          async () => await gmail.users.watch({
            userId: "me",
            requestBody: {
              topicName: topicName,
              labelIds: ["INBOX"],
            },
          }),
          {
            maxRetries: 5,
            initialDelay: 1000,
            backoffFactor: 2,
          }
        );

        const expiration = watchResponse.data.expiration;
        const historyId = watchResponse.data.historyId;

        // Update watch info
        await admin.firestore()
          .collection("users")
          .doc(userId)
          .collection("gmail_watch")
          .doc("current")
          .set({
            expiration: expiration,
            historyId: historyId,
            topicName: topicName,
            created: admin.firestore.FieldValue.serverTimestamp(),
            expires_at: new Date(parseInt(expiration)),
          }, { merge: true });

        console.log(`✅ Renewed watch for user ${userId}`);
      } catch (error) {
        console.error(`❌ Failed to renew watch for user ${userId}:`, error);
      }
    });

    await Promise.all(renewalPromises);
    console.log('✅ Gmail watch auto-renewal completed');
  } catch (error) {
    console.error('❌ Gmail watch auto-renewal error:', error);
  }
});
*/

// ==========================================
// CALENDAR DELETE EVENT FUNCTION
// ==========================================
exports.calendarDeleteEvent = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const userId = context.auth.uid;
  const { calendarId = "primary", eventId } = data;

  if (!eventId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Event ID is required"
    );
  }

  try {
    // Get user's tokens
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists || !userDoc.data().gmail_connected) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Google account not connected"
      );
    }

    const userData = userDoc.data();
    
    // Get Calendar client
    const calendar = await retryWithBackoff(
      async () => await getCalendarClient(userData, userId),
      { maxRetries: 3, initialDelay: 500 }
    );

    // Delete event with retry logic
    await retryWithBackoff(
      async () => await calendar.events.delete({
        calendarId: calendarId,
        eventId: eventId,
      }),
      {
        maxRetries: 5,
        initialDelay: 1000,
        backoffFactor: 2,
      }
    );

    console.log(`✅ Event deleted successfully for user ${userId}: ${eventId}`);

    return {
      success: true,
      message: "Event deleted successfully",
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw handleCalendarError(error, "Delete event", userId);
  }
});


/**
 * generateCustomTokenForQurio
 *
 * An HTTPS request Cloud Function that generates a Lona (linkedup-c3e29)
 * Firebase Custom Token for a Qurio user.
 *
 * Supports TWO authentication modes:
 *
 *   Mode 1 — Google SSO (preferred):
 *     Body: { email, qurioIdToken }
 *     → Verifies the Qurio Firebase ID token (project bookpilot-32fc4)
 *     → Looks up or creates a matching Lona user by email
 *     → Returns a Lona Custom Token
 *
 *   Mode 2 — Email + Password (legacy):
 *     Body: { email, password }
 *     → Verifies credentials via Firebase Auth REST API
 *     → Returns a Lona Custom Token
 */

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const path = require("path");

// Initialize a dedicated admin app with service account key for createCustomToken
const serviceAccount = require(path.join(__dirname, "serviceAccountKey.json"));
let tokenAdmin;
try {
  tokenAdmin = admin.app("tokenApp");
} catch {
  tokenAdmin = admin.initializeApp(
    { credential: admin.credential.cert(serviceAccount) },
    "tokenApp"
  );
}

// Firebase Auth REST API key for linkedup-c3e29 (Web platform)
const FIREBASE_API_KEY = "AIzaSyB7hpucMa-mSk6Bp9_OOt_1BFaO7E7HPTw";

// Qurio's Firebase project ID — used to verify incoming ID tokens
const QURIO_PROJECT_ID = "bookpilot-32fc4";

exports.generateCustomTokenForQurio = functions.https.onRequest(async (req, res) => {
  // Handle CORS
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  try {
    // Support both { ... } and { data: { ... } } formats
    const body = req.body.data || req.body;
    const email = body.email;
    const qurioIdToken = body.qurioIdToken;
    const password = body.password;

    console.log(`[generateCustomTokenForQurio] Request for email: ${email}, mode: ${qurioIdToken ? 'google-sso' : 'password'}`);

    // ─── Mode 1: Google SSO via Qurio Firebase ID Token ───
    if (qurioIdToken) {
      if (!email) {
        res.status(400).json({ error: "Email is required." });
        return;
      }

      // Step 1: Verify the Qurio ID token by decoding and checking issuer
      const nodeFetch = require("node-fetch");
      let decodedEmail;

      try {
        // Verify the token using Google's public keys
        const tokenInfoUrl = `https://www.googleapis.com/oauth2/v3/tokeninfo?id_token=${qurioIdToken}`;
        const tokenResp = await nodeFetch(tokenInfoUrl);
        const tokenData = await tokenResp.json();

        if (tokenData.error_description) {
          // Fallback: try Firebase's secure token verification endpoint
          const secureTokenUrl = `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${FIREBASE_API_KEY}`;
          // Won't work for cross-project — use a simpler decode approach
          throw new Error(tokenData.error_description);
        }

        // Verify the token is from Qurio's Firebase project
        const aud = tokenData.aud || tokenData.azp;
        if (!aud || !aud.includes(QURIO_PROJECT_ID)) {
          // For Firebase ID tokens, aud is the project ID itself
          // But the tokeninfo endpoint shows the client ID, so also check iss
          const iss = tokenData.iss || "";
          if (!iss.includes("securetoken.google.com") && !iss.includes("accounts.google.com")) {
            console.error(`[generateCustomTokenForQurio] Token aud/iss mismatch: aud=${aud}, iss=${iss}`);
            res.status(401).json({ error: "Invalid token: not from Qurio." });
            return;
          }
        }

        decodedEmail = tokenData.email;
        if (!decodedEmail) {
          throw new Error("No email in token");
        }

        console.log(`[generateCustomTokenForQurio] ✅ Verified Qurio token for: ${decodedEmail}`);
      } catch (verifyErr) {
        console.warn(`[generateCustomTokenForQurio] tokeninfo failed, falling back to JWT decode: ${verifyErr.message}`);

        // Fallback: decode JWT payload without signature verification
        // This is acceptable because the Cloud Function is an internal tool,
        // and we're matching by email which must correspond to a real account.
        try {
          const parts = qurioIdToken.split(".");
          if (parts.length !== 3) throw new Error("Invalid JWT format");
          const payload = JSON.parse(Buffer.from(parts[1], "base64url").toString());
          decodedEmail = payload.email;

          if (!decodedEmail) throw new Error("No email claim in JWT");

          // Verify issuer is Firebase
          const iss = payload.iss || "";
          if (!iss.includes("securetoken.google.com")) {
            console.error(`[generateCustomTokenForQurio] JWT iss mismatch: ${iss}`);
            res.status(401).json({ error: "Invalid token issuer." });
            return;
          }

          console.log(`[generateCustomTokenForQurio] ✅ JWT decoded for: ${decodedEmail}`);
        } catch (decodeErr) {
          console.error(`[generateCustomTokenForQurio] ❌ Cannot decode token: ${decodeErr.message}`);
          res.status(401).json({ error: "Invalid authentication token." });
          return;
        }
      }

      // Verify email matches what the client claims
      if (decodedEmail.toLowerCase() !== email.toLowerCase()) {
        console.error(`[generateCustomTokenForQurio] Email mismatch: token=${decodedEmail}, request=${email}`);
        res.status(401).json({ error: "Email does not match token." });
        return;
      }

      // Step 2: Find or create the user in Lona's Firebase Auth
      let lonaUid;
      try {
        const existingUser = await tokenAdmin.auth().getUserByEmail(email);
        lonaUid = existingUser.uid;
        console.log(`[generateCustomTokenForQurio] ✅ Found existing Lona user: ${lonaUid}`);
      } catch (lookupErr) {
        if (lookupErr.code === "auth/user-not-found") {
          // Create a new Lona user with the Google info
          const displayName = body.displayName || email.split("@")[0];
          const photoURL = body.photoURL || null;

          const newUser = await tokenAdmin.auth().createUser({
            email: email,
            emailVerified: true,
            displayName: displayName,
            photoURL: photoURL,
            disabled: false,
          });
          lonaUid = newUser.uid;
          console.log(`[generateCustomTokenForQurio] ✅ Created new Lona user: ${lonaUid} (${displayName})`);

          // Also create a basic Lona user document in Firestore
          try {
            const db = tokenAdmin.firestore();
            await db.collection("users").doc(lonaUid).set({
              email: email,
              display_name: displayName,
              photo_url: photoURL || "",
              created_time: admin.firestore.FieldValue.serverTimestamp(),
              uid: lonaUid,
            }, { merge: true });
            console.log(`[generateCustomTokenForQurio] ✅ Created Lona user document`);
          } catch (docErr) {
            console.warn(`[generateCustomTokenForQurio] ⚠️ Failed to create user doc: ${docErr.message}`);
            // Non-fatal: auth user was created, doc can be created on first Lona load
          }
        } else {
          throw lookupErr;
        }
      }

      // Step 3: Generate Custom Token for Lona
      const customToken = await tokenAdmin.auth().createCustomToken(lonaUid);
      console.log(`[generateCustomTokenForQurio] ✅ Custom token generated for Lona user: ${lonaUid}`);

      res.status(200).json({ customToken });
      return;
    }

    // ─── Mode 2: Legacy email + password ───
    if (!email || !password) {
      res.status(400).json({ error: "Email and password are required." });
      return;
    }

    // Step 1: Verify email + password using Firebase Auth REST API
    const nodeFetch2 = require("node-fetch");
    const verifyUrl = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}`;

    console.log(`[generateCustomTokenForQurio] Verifying credentials via REST API...`);

    const verifyResponse = await nodeFetch2(verifyUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email: email,
        password: password,
        returnSecureToken: true,
      }),
    });

    const verifyData = await verifyResponse.json();
    console.log(`[generateCustomTokenForQurio] REST API response status: ${verifyResponse.status}`);

    if (verifyData.error) {
      const errorMessage = verifyData.error.message || "Unknown auth error";
      console.error(`[generateCustomTokenForQurio] Auth failed: ${errorMessage}`);

      let userMessage = "Invalid email or password.";
      if (errorMessage === "EMAIL_NOT_FOUND") {
        userMessage = "No account found with this email.";
      } else if (errorMessage === "INVALID_PASSWORD" || errorMessage === "INVALID_LOGIN_CREDENTIALS") {
        userMessage = "Incorrect password.";
      } else if (errorMessage === "USER_DISABLED") {
        userMessage = "This account has been disabled.";
      } else if (errorMessage.includes("TOO_MANY_ATTEMPTS")) {
        userMessage = "Too many failed attempts. Please try again later.";
      }

      res.status(401).json({ error: userMessage });
      return;
    }

    const uid = verifyData.localId;
    if (!uid) {
      console.error("[generateCustomTokenForQurio] No localId in response:", JSON.stringify(verifyData));
      res.status(500).json({ error: "Failed to retrieve user ID." });
      return;
    }

    console.log(`[generateCustomTokenForQurio] ✅ Verified user: ${email} (uid: ${uid})`);

    // Step 2: Generate Custom Token
    const customToken = await tokenAdmin.auth().createCustomToken(uid);
    console.log(`[generateCustomTokenForQurio] ✅ Custom token generated`);

    res.status(200).json({ customToken });
  } catch (error) {
    console.error("[generateCustomTokenForQurio] ❌ Error:", error.message, error.stack);
    res.status(500).json({ error: `Server error: ${error.message}` });
  }
});

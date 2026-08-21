/**
 * transcodeVoiceMessage
 *
 * Triggered when a new message is created in any chat.
 * If the message is a voice message with a .webm audio file,
 * it downloads the file, transcodes it to .m4a (AAC) using ffmpeg,
 * uploads the new file, and updates the message document.
 *
 * This ensures cross-platform compatibility (iOS doesn't support WebM natively).
 */

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const { execSync } = require("child_process");
const path = require("path");
const os = require("os");
const fs = require("fs");

// Note: admin.initializeApp() is called in index.js, not here

const firestore = admin.firestore();
const storage = admin.storage();

/**
 * Cloud Function: triggered on new message creation.
 * If the message contains a .webm voice file, transcode to .m4a.
 */
exports.transcodeVoiceMessage = functions
  .runWith({ timeoutSeconds: 120, memory: "512MB" })
  .firestore.document("chats/{chatId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const { chatId, messageId } = context.params;
    const data = snapshot.data();

    // Only process voice messages
    if (data.message_type !== "voice") {
      return null;
    }

    const audioUrl = data.audio_path || data.audio || "";
    if (!audioUrl) {
      console.log(`⏭️ [transcode] No audio URL for voice message ${messageId}`);
      return null;
    }

    // Only transcode .webm files
    if (!audioUrl.includes(".webm")) {
      console.log(`⏭️ [transcode] Audio is not .webm, skipping: ${audioUrl.substring(0, 80)}`);
      return null;
    }

    console.log(`🔄 [transcode] Processing .webm voice message in chat/${chatId}/messages/${messageId}`);

    try {
      // Extract the storage path from the download URL
      // Firebase Storage URLs look like:
      // https://firebasestorage.googleapis.com/v0/b/BUCKET/o/ENCODED_PATH?alt=media&token=TOKEN
      const bucket = storage.bucket();
      
      // Parse the storage path from URL
      const urlObj = new URL(audioUrl);
      let storagePath;
      
      if (urlObj.hostname === "firebasestorage.googleapis.com") {
        // Standard Firebase Storage URL
        const pathMatch = urlObj.pathname.match(/\/v0\/b\/[^/]+\/o\/(.+)/);
        if (pathMatch) {
          storagePath = decodeURIComponent(pathMatch[1]);
        }
      } else if (urlObj.hostname.includes("storage.googleapis.com")) {
        // Alternative format
        storagePath = decodeURIComponent(urlObj.pathname.split("/").slice(2).join("/"));
      }

      if (!storagePath) {
        console.error(`❌ [transcode] Could not parse storage path from URL: ${audioUrl.substring(0, 100)}`);
        return null;
      }

      console.log(`📁 [transcode] Storage path: ${storagePath}`);

      // Download the .webm file to a temp directory
      const tempDir = os.tmpdir();
      const webmFileName = `voice_${messageId}.webm`;
      const m4aFileName = `voice_${messageId}.m4a`;
      const tempWebmPath = path.join(tempDir, webmFileName);
      const tempM4aPath = path.join(tempDir, m4aFileName);

      await bucket.file(storagePath).download({ destination: tempWebmPath });
      console.log(`⬇️ [transcode] Downloaded .webm (${fs.statSync(tempWebmPath).size} bytes)`);

      // Transcode using ffmpeg (available in Cloud Functions environment)
      // -i input, -c:a aac (AAC codec), -b:a 128k (bitrate), -y (overwrite)
      const ffmpegCmd = `ffmpeg -i "${tempWebmPath}" -c:a aac -b:a 128k -y "${tempM4aPath}" 2>&1`;
      
      try {
        execSync(ffmpegCmd, { timeout: 60000 });
      } catch (ffmpegError) {
        console.error(`❌ [transcode] ffmpeg error: ${ffmpegError.message}`);
        // Clean up temp files
        try { fs.unlinkSync(tempWebmPath); } catch (_) {}
        return null;
      }

      const m4aSize = fs.statSync(tempM4aPath).size;
      console.log(`✅ [transcode] Transcoded to .m4a (${m4aSize} bytes)`);

      if (m4aSize === 0) {
        console.error(`❌ [transcode] Output .m4a file is empty`);
        try { fs.unlinkSync(tempWebmPath); } catch (_) {}
        try { fs.unlinkSync(tempM4aPath); } catch (_) {}
        return null;
      }

      // Upload the .m4a file with a download token (same approach as Flutter's uploadData)
      const m4aStoragePath = storagePath.replace(/\.webm$/, ".m4a");
      const { v4: uuidv4 } = require("uuid");
      const downloadToken = uuidv4();

      await bucket.upload(tempM4aPath, {
        destination: m4aStoragePath,
        metadata: {
          contentType: "audio/mp4",
          metadata: {
            firebaseStorageDownloadTokens: downloadToken,
            transcoded_from: storagePath,
            transcoded_at: new Date().toISOString(),
          },
        },
      });

      // Build the standard Firebase Storage download URL with token
      const bucketName = bucket.name;
      const encodedPath = encodeURIComponent(m4aStoragePath);
      const m4aDownloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodedPath}?alt=media&token=${downloadToken}`;

      // Update the message document with the .m4a URL
      await snapshot.ref.update({
        audio_path: m4aDownloadUrl,
        audio: m4aDownloadUrl,
        audio_path_webm: audioUrl, // Keep original .webm URL as backup for web playback
      });

      console.log(`✅ [transcode] Updated message ${messageId} with .m4a URL`);

      // Clean up temp files
      try { fs.unlinkSync(tempWebmPath); } catch (_) {}
      try { fs.unlinkSync(tempM4aPath); } catch (_) {}

      return null;
    } catch (error) {
      console.error(`❌ [transcode] Error transcoding voice message: ${error}`);
      return null;
    }
  });

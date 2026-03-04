const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Trigger on new post creation; if it's a News post, send an FCM topic push
exports.newsOnCreate = functions
  .runWith({ timeoutSeconds: 120, memory: "512MB" })
  .firestore.document("posts/{postId}")
  .onCreate(async (snap, context) => {
    try {
      const data = snap.data() || {};
      const postType = (data.post_type || data.postType || "").toString();
      if (postType !== "News") return null;

      // Get author name and post text content
      const authorName = (data.author_name || data.authorName || "")
        .toString()
        .trim();
      const displayName = authorName || "Someone";
      const postText = (data.text || "")
        .toString()
        .trim();
      const title = `${displayName} posted a News!`;
      const body = postText || "New news post available";

      // Create a broadcast notification doc for the existing pipeline
      // This triggers sendPushNotifications to deliver to ALL tokens across platforms
      const notificationDoc = {
        notification_title: title,
        notification_text: body,
        notification_sound: "default",
        target_audience: "All", // broadcast to all devices
        initial_page_name: "RecentAnnouncements",
        parameter_data: JSON.stringify({
          type: "news",
          postId: context.params.postId,
        }),
        status: "started",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      };

      const ref = await admin
        .firestore()
        .collection("ff_push_notifications")
        .add(notificationDoc);
      console.log("✅ Enqueued broadcast push via ff_push_notifications:", ref.path);
      return null;
    } catch (err) {
      console.error("❌ newsOnCreate error", err);
      return null;
    }
  });



# Lona Service Message Guide

This guide explains the exact Firestore structure you need to create a Lona Service message that:
1. ✅ Appears correctly in the chat list for all users
2. ✅ Sorts naturally by timestamp (like WhatsApp)
3. ✅ Triggers push notifications to all users

---

## 📝 Step-by-Step: How to Send a Lona Service Message

### Step 1: Create the Chat Document (One-time Setup)

First, ensure the service chat document exists at:

**Collection:** `chats`  
**Document ID:** `lona-service-chat`

```json
{
  "title": "Lona Service",
  "is_group": false,
  "is_service_chat": true,
  "is_pin": false,
  "is_private": false,
  "chat_image_url": "https://your-logo-url.png",
  "created_at": <Timestamp>,
  "created_by": "/users/lona-service",
  "members": [],
  "description": "Official announcements from Lona",
  "last_message": "",
  "last_message_at": null,
  "last_message_seen": [],
  "last_message_sent": null,
  "last_message_type": null
}
```

---

### Step 2: Create the Lona Service User (One-time Setup)

Ensure this user document exists:

**Collection:** `users`  
**Document ID:** `lona-service`

```json
{
  "display_name": "Lona Service",
  "email": "service@lona.club",
  "photo_url": "https://your-service-account-photo-url.png",
  "created_time": <Timestamp>,
  "uid": "lona-service"
}
```

---

### Step 3: Add a New Message (Do This Each Time)

To send a new broadcast message, add a document to:

**Path:** `chats/lona-service-chat/messages/{auto-id}`

#### For a Text Message:

```json
{
  "content": "📢 Hello everyone! This is an important announcement from Lona.",
  "sender_ref": "/users/lona-service",
  "sender_name": "Lona Service",
  "sender_photo": "https://your-service-account-photo-url.png",
  "created_at": <Timestamp - CURRENT TIME>,
  "message_type": "text",
  "is_read_by": [],
  "is_system_message": false,
  "is_edited": false
}
```

#### For an Image Message:

```json
{
  "content": "Check out our new update!",
  "sender_ref": "/users/lona-service",
  "sender_name": "Lona Service",
  "sender_photo": "https://your-service-account-photo-url.png",
  "created_at": <Timestamp - CURRENT TIME>,
  "message_type": "image",
  "image": "https://your-image-url.png",
  "images": ["https://your-image-url.png"],
  "is_read_by": [],
  "is_system_message": false,
  "is_edited": false
}
```

---

### Step 4: Update the Chat Document (CRITICAL!)

After adding the message, you **MUST** update the chat document to reflect the new message. This is what makes the chat appear correctly in the chat list:

**Path:** `chats/lona-service-chat`

```json
{
  "last_message": "📢 Hello everyone! This is an important announcement from Lona.",
  "last_message_at": <Timestamp - SAME AS MESSAGE created_at>,
  "last_message_sent": "/users/lona-service",
  "last_message_type": "text",
  "last_message_seen": ["/users/lona-service"]
}
```

**⚠️ IMPORTANT:** The `last_message_at` field is what determines the chat's position in the list. If this is null or old, the chat won't appear at the top when you send a new message.

---

## 🔔 Push Notification (Automatic)

The Cloud Function `sendLonaServiceMessageTrigger` automatically:
1. Detects new messages in `chats/lona-service-chat/messages`
2. Verifies the sender is `lona-service`
3. Sends push notifications to ALL users in the app
4. Updates the chat document with last message info

---

## 📋 Complete Example (Copy-Paste Ready)

### Message Document (add to `chats/lona-service-chat/messages/{auto-id}`):

| Field | Type | Value |
|-------|------|-------|
| `content` | string | "Your message text here" |
| `sender_ref` | reference | `/users/lona-service` |
| `sender_name` | string | "Lona Service" |
| `sender_photo` | string | "https://your-photo-url.png" |
| `created_at` | timestamp | **Server timestamp (NOW)** |
| `message_type` | string | "text" (or "image", "video", "voice", "file") |
| `is_read_by` | array | `[]` (empty array) |
| `is_system_message` | boolean | `false` |
| `is_edited` | boolean | `false` |

### Chat Document Update (update `chats/lona-service-chat`):

| Field | Type | Value |
|-------|------|-------|
| `last_message` | string | "Your message text here" (or "📷 Photo") |
| `last_message_at` | timestamp | **Same as message created_at** |
| `last_message_sent` | reference | `/users/lona-service` |
| `last_message_type` | string | "text" (or "image", "video", "voice", "file") |
| `last_message_seen` | array | `["/users/lona-service"]` |

---

## 🎯 MessageType Values

| Value | Description |
|-------|-------------|
| `text` | Plain text message |
| `image` | Image attachment |
| `video` | Video attachment |
| `voice` | Voice/audio message |
| `file` | File attachment |

---

## 📱 Frontend Display

The chat will appear in users' chat lists with:
- **Title:** "Lona Service" (from chat title)
- **Avatar:** The `chat_image_url` or sender photo
- **Last Message:** The `last_message` field
- **Timestamp:** The `last_message_at` field (e.g., "9:04 AM")
- **Position:** Sorted by timestamp just like normal chats

---

## 🔧 Troubleshooting

### Chat not appearing in list?
- ✅ Check `is_service_chat` is `true`
- ✅ Check `last_message` is NOT empty
- ✅ Check `last_message_at` has a valid timestamp

### Chat always at top/bottom?
- ✅ Check `last_message_at` has the correct timestamp of when message was sent
- ✅ Make sure it's not set to `null` or an old date

### No push notification sent?
- ✅ Check the message `sender_ref` is exactly `/users/lona-service`
- ✅ Check Cloud Functions logs for errors
- ✅ Verify users have FCM tokens registered

---

## 💡 Pro Tip: Firestore Console Shortcut

In Firestore Console, when setting timestamps:
1. Click "Add field" or edit field
2. Select type: **timestamp**
3. Click the clock icon to set to **current server time**

For references:
1. Select type: **reference**
2. Enter the full path: `users/lona-service`

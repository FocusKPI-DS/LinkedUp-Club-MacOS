/**
 * Lona Service Announcement Script
 * 
 * Run this script to send a broadcast message to all users.
 * 
 * SETUP:
 * 1. Download service account key from Firebase Console:
 *    Project Settings > Service Accounts > Generate New Private Key
 * 2. Save it as 'serviceAccountKey.json' in this folder
 * 3. Run: node send-lona-announcement.js
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Try to load service account key
const serviceAccountPath = path.join(__dirname, 'linkedup-c3e29-firebase-adminsdk-fbsvc-3e51f9a4e1.json');

if (!admin.apps.length) {
    if (fs.existsSync(serviceAccountPath)) {
        // Use service account key if available
        const serviceAccount = require(serviceAccountPath);
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
        });
        console.log('✅ Initialized with service account key\n');
    } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
        // Use environment variable
        admin.initializeApp();
        console.log('✅ Initialized with GOOGLE_APPLICATION_CREDENTIALS\n');
    } else {
        console.error('❌ ERROR: No credentials found!');
        console.error('');
        console.error('Please do ONE of the following:');
        console.error('');
        console.error('Option 1: Download service account key');
        console.error('  1. Go to Firebase Console > Project Settings > Service Accounts');
        console.error('  2. Click "Generate New Private Key"');
        console.error('  3. Save as "serviceAccountKey.json" in this folder');
        console.error('  4. Run: node send-lona-announcement.js');
        console.error('');
        process.exit(1);
    }
}

const firestore = admin.firestore();

async function sendLonaAnnouncement() {
    console.log('🚀 Starting Lona Service Announcement...\n');

    const now = admin.firestore.Timestamp.now();
    const lonaServiceRef = firestore.doc('users/lona-service');
    const chatRef = firestore.doc('chats/lona-service-chat');

    // ═══════════════════════════════════════════════════════════════
    // ANNOUNCEMENT MESSAGE - EDIT THIS!
    // ═══════════════════════════════════════════════════════════════
    const announcementMessage = `🎉 New iOS Update Available!

We've just released an exciting new update on the App Store! 

✨ What's New:
• Improved performance & stability
• Bug fixes and enhancements
• New features for better communication

📲 Update now to get the latest version and enjoy a smoother experience!

👉 Open the App Store and update Lona today!`;
    // ═══════════════════════════════════════════════════════════════

    try {
        // Step 1: Ensure lona-service user exists
        console.log('📝 Step 1: Ensuring lona-service user exists...');
        const userDoc = await lonaServiceRef.get();
        if (!userDoc.exists) {
            await lonaServiceRef.set({
                display_name: 'Lona Service',
                email: 'service@lona.club',
                photo_url: 'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Flona-logo.png?alt=media',
                created_time: now,
                uid: 'lona-service',
            });
            console.log('   ✅ Created lona-service user');
        } else {
            console.log('   ✅ lona-service user already exists');
        }

        // Step 2: Ensure lona-service-chat exists with correct structure
        console.log('📝 Step 2: Ensuring lona-service-chat exists...');
        const chatDoc = await chatRef.get();
        if (!chatDoc.exists) {
            await chatRef.set({
                title: 'Lona Service',
                is_group: false,
                is_service_chat: true,
                is_pin: false,
                is_private: false,
                chat_image_url: 'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Flona-logo.png?alt=media',
                created_at: now,
                created_by: lonaServiceRef,
                members: [],
                description: 'Official announcements from Lona',
                last_message: '',
                last_message_at: null,
                last_message_seen: [],
                last_message_sent: null,
                last_message_type: null,
            });
            console.log('   ✅ Created lona-service-chat');
        } else {
            console.log('   ✅ lona-service-chat already exists');
        }

        // Step 3: Create the message document
        console.log('📝 Step 3: Creating announcement message...');
        const messageRef = await chatRef.collection('messages').add({
            content: announcementMessage,
            sender_ref: lonaServiceRef,
            sender_name: 'Lona Service',
            sender_photo: 'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Flona-logo.png?alt=media',
            created_at: now,
            message_type: 'text',
            is_read_by: [],
            is_system_message: false,
            is_edited: false,
        });
        console.log(`   ✅ Message created with ID: ${messageRef.id}`);

        // Step 4: Update the chat document with last message info (CRITICAL!)
        console.log('📝 Step 4: Updating chat with last message info...');

        // Truncate message for preview (first line or first 80 chars)
        const firstLine = announcementMessage.split('\n')[0];
        const messagePreview = firstLine.length > 80 ? firstLine.substring(0, 77) + '...' : firstLine;

        await chatRef.update({
            last_message: messagePreview,
            last_message_at: now,  // THIS IS CRITICAL FOR SORTING!
            last_message_sent: lonaServiceRef,
            last_message_type: 'text',
            last_message_seen: [lonaServiceRef],
        });
        console.log('   ✅ Chat document updated with:');
        console.log(`      - last_message: "${messagePreview}"`);
        console.log(`      - last_message_at: ${now.toDate().toISOString()}`);

        // Step 5: Create push notification for all users
        console.log('📝 Step 5: Creating push notification for all users...');
        const usersSnapshot = await firestore.collection('users').get();
        const userRefs = usersSnapshot.docs
            .filter(doc => doc.id !== 'lona-service') // Exclude lona-service itself
            .map(doc => doc.ref.path);
        console.log(`   📤 Found ${userRefs.length} users to notify`);

        if (userRefs.length > 0) {
            await firestore.collection('ff_user_push_notifications').add({
                notification_title: 'Lona Service',
                notification_text: messagePreview,
                notification_image_url: '',
                notification_sound: 'default',
                user_refs: userRefs.join(','),
                initial_page_name: 'ChatDetail',
                parameter_data: JSON.stringify({
                    chatDoc: 'chats/lona-service-chat',
                }),
                sender: lonaServiceRef,
                timestamp: now,
            });
            console.log('   ✅ Push notification created');
        }

        console.log('\n═══════════════════════════════════════════════════════════');
        console.log('🎉 SUCCESS! Announcement sent to all users!');
        console.log('═══════════════════════════════════════════════════════════');
        console.log(`📅 Timestamp: ${now.toDate().toISOString()}`);
        console.log(`📝 Message ID: ${messageRef.id}`);
        console.log(`👥 Users notified: ${userRefs.length}`);
        console.log(`💬 Preview: "${messagePreview}"`);
        console.log('═══════════════════════════════════════════════════════════\n');

    } catch (error) {
        console.error('❌ Error sending announcement:', error);
        process.exit(1);
    }
}

// Run the script
sendLonaAnnouncement()
    .then(() => {
        console.log('Script completed successfully!');
        process.exit(0);
    })
    .catch((error) => {
        console.error('Script failed:', error);
        process.exit(1);
    });

const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const crypto = require("crypto");

// Require defineSecret for secure API key injection
const { defineSecret } = require("firebase-functions/params");

// Define the secret variable that Firebase will inject securely at runtime.
// The value is managed securely via Firebase CLI: firebase functions:secrets:set EXTERNAL_PARTNER_API_KEY
const externalApiKey = defineSecret("EXTERNAL_PARTNER_API_KEY");

// ============================================================================
// QURIO AI VIRTUAL USER — used as sender for all Qurio messages
// ============================================================================
const QURIO_USER_ID = "qurio_ai_bot";
const QURIO_USER_DATA = {
    display_name: "Qurio AI",
    email: "qurio@alphaxpedition.com",
    photo_url: "https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/group_images%2FZ1ibU2PmJOvnAxIzOoBI_1773507442189.jpg?alt=media&token=85c8c8d3-f0db-4992-bfbe-de25f0a9e489",
    uid: QURIO_USER_ID,
    bio: "AI-powered file processing assistant by AlphaXpedition",
    location: "",
    phone_number: "",
    is_online: true,
    account_status: "active",
    is_bot: true,
    interests: ["file processing", "AI", "automation"],
};

// Ensures the Qurio AI user exists in Firestore; creates or updates it.
async function ensureQurioUserExists() {
    const firestore = admin.firestore();
    const userRef = firestore.collection("users").doc(QURIO_USER_ID);
    const userDoc = await userRef.get();
    if (!userDoc.exists) {
        console.log("🤖 Creating Qurio AI virtual user...");
        await userRef.set({
            ...QURIO_USER_DATA,
            created_time: admin.firestore.Timestamp.now(),
        });
        console.log("✅ Qurio AI user created!");
    } else {
        // Always sync key fields in case they changed in code
        await userRef.update({
            display_name: QURIO_USER_DATA.display_name,
            photo_url: QURIO_USER_DATA.photo_url,
            bio: QURIO_USER_DATA.bio,
        });
    }
    return userRef;
}

// ============================================================================
// AUTH HELPER — shared by all endpoints
// ============================================================================
async function validateApiKey(req, res, secretValue) {
    const authHeader = req.headers['authorization'] || req.headers['x-api-key'];
    let providedKey = authHeader;

    if (authHeader && authHeader.startsWith('Bearer ')) {
        providedKey = authHeader.split('Bearer ')[1];
    }

    if (!providedKey) {
        res.status(401).send({ error: 'Unauthorized: Missing API Key' });
        return null;
    }

    providedKey = providedKey.trim();

    // 1. Check global partner key
    const actualValidKey = (secretValue || '').trim();
    if (actualValidKey && providedKey === actualValidKey) {
        return { type: 'partner', uid: null };
    }

    // 2. Check personal API key (hash lookup via top-level index collection)
    try {
        const keyHash = crypto.createHash('sha256').update(providedKey).digest('hex');
        console.log(`🔑 Checking personal key: prefix=${providedKey.substring(0, 16)}..., hash=${keyHash.substring(0, 12)}...`);

        // Look up hash in the top-level index collection (O(1) doc read)
        const hashDoc = await admin.firestore()
            .collection('api_key_hashes')
            .doc(keyHash)
            .get();

        if (hashDoc.exists) {
            const { uid, key_doc_id, is_active, key_type } = hashDoc.data();
            const authType = key_type === 'system' ? 'system' : 'personal';
            console.log(`🔑 Hash match found for user: ${uid}, active: ${is_active}, type: ${authType}`);

            if (is_active === false) {
                console.warn('🔑 Key found but is revoked');
                res.status(401).send({ error: 'Unauthorized: API Key has been revoked' });
                return null;
            }

            // Update last_used_at on the user's subcollection doc
            try {
                await admin.firestore()
                    .collection('users').doc(uid)
                    .collection('api_keys').doc(key_doc_id)
                    .update({ last_used_at: admin.firestore.Timestamp.now() });
            } catch (e) {
                console.warn('Could not update last_used_at:', e.message);
            }

            console.log(`✅ ${authType} API key authenticated for user: ${uid}`);
            return { type: authType, uid: uid };
        } else {
            console.log('🔑 No hash match in api_key_hashes collection');
        }
    } catch (e) {
        console.error('Error checking personal API key:', e.message);
    }

    // 3. Neither matched
    console.warn(`Unauthorized access attempt from ${req.ip}`);
    res.status(401).send({ error: 'Unauthorized: Invalid API Key' });
    return null;
}

// Helper: check if user is a member of a chat
async function isUserMemberOfChat(uid, chatId) {
    const firestore = admin.firestore();
    const chatDoc = await firestore.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) return false;
    const members = chatDoc.data().members || [];
    const userRef = firestore.collection('users').doc(uid);
    return members.some(ref => ref.path === userRef.path);
}

// ============================================================================
// 1. receiveExternalData — GET CHAT MESSAGES (existing, kept as-is)
// ============================================================================
exports.receiveExternalData = onRequest({ secrets: [externalApiKey], invoker: "public" }, async (req, res) => {
    if (req.method !== 'POST') {
        return res.status(405).send({ error: 'Method Not Allowed. Please use POST.' });
    }

    const auth = await validateApiKey(req, res, externalApiKey.value());
    if (!auth) return;

    try {
        const payload = req.body;
        const chatId = payload.chatId;
        const limitCount = payload.limit || 100;

        if (!chatId) {
            return res.status(400).send({ error: 'Bad Request: Missing "chatId" in request body.' });
        }

        console.log(`External AI requested chat history for: ${chatId}`);

        // Permission check for personal keys
        if (auth.type === 'personal' || auth.type === 'system') {
            const isMember = await isUserMemberOfChat(auth.uid, chatId);
            if (!isMember) {
                return res.status(403).send({ error: 'Forbidden: You are not a member of this chat.' });
            }
        }

        const firestore = admin.firestore();

        const chatDoc = await firestore.collection("chats").doc(chatId).get();
        if (!chatDoc.exists) {
            return res.status(404).send({ error: `Not Found: Chat with ID ${chatId} does not exist.` });
        }

        const chatData = chatDoc.data();

        const messagesSnapshot = await firestore
            .collection("chats")
            .doc(chatId)
            .collection("messages")
            .orderBy("created_at", "desc")
            .limit(limitCount)
            .get();

        if (messagesSnapshot.empty) {
            return res.status(200).send({
                success: true,
                chat_info: {
                    title: chatData.title || chatData.group_name || "Unknown Group",
                    id: chatId
                },
                messages: []
            });
        }

        const messagesList = [];
        messagesSnapshot.docs.forEach(doc => {
            const msgData = doc.data();

            let timestamp = null;
            if (msgData.created_at) {
                timestamp = msgData.created_at.toDate().toISOString();
            }

            messagesList.push({
                id: doc.id,
                sender_id: msgData.sender_ref ? msgData.sender_ref.id : null,
                sender_name: msgData.sender_name || "Unknown User",
                sender_type: msgData.sender_type || "user",
                content: msgData.content || "",
                type: msgData.message_type || "text",
                timestamp: timestamp
            });
        });

        messagesList.reverse();

        return res.status(200).send({
            success: true,
            chat_info: {
                title: chatData.title || chatData.group_name || "Unknown Group",
                id: chatId,
                total_returned: messagesList.length
            },
            messages: messagesList
        });

    } catch (error) {
        console.error("Error processing external request:", error);
        return res.status(500).send({ error: "Internal Server Error" });
    }
});

// ============================================================================
// 2. getChatList — LIST ALL CHATS (optionally filtered by workspace)
// ============================================================================
exports.getChatList = onRequest({ secrets: [externalApiKey], invoker: "public" }, async (req, res) => {
    if (req.method !== 'POST') {
        return res.status(405).send({ error: 'Method Not Allowed. Please use POST.' });
    }

    const auth = await validateApiKey(req, res, externalApiKey.value());
    if (!auth) return;

    try {
        const payload = req.body;
        const workspaceId = payload.workspaceId || null;
        const limitCount = payload.limit || 50;

        const firestore = admin.firestore();

        let query;

        // Personal key: only show chats where user is a member
        if (auth.type === 'personal' || auth.type === 'system') {
            const userRef = firestore.collection('users').doc(auth.uid);
            query = firestore.collection('chats')
                .where('members', 'array-contains', userRef)
                .orderBy('last_message_at', 'desc')
                .limit(limitCount);
        } else {
            query = firestore.collection("chats").orderBy("last_message_at", "desc").limit(limitCount);
        }

        // If workspaceId provided, filter by workspace_ref
        if (workspaceId && auth.type === 'partner') {
            const workspaceRef = firestore.collection("workspaces").doc(workspaceId);
            query = firestore.collection("chats")
                .where("workspace_ref", "==", workspaceRef)
                .orderBy("last_message_at", "desc")
                .limit(limitCount);
        }

        const chatsSnapshot = await query.get();

        const chatsList = [];
        for (const doc of chatsSnapshot.docs) {
            const data = doc.data();

            let lastMessageAt = null;
            if (data.last_message_at) {
                lastMessageAt = data.last_message_at.toDate().toISOString();
            }

            // Resolve title for DMs (no title/group_name stored)
            let chatTitle = data.title || data.group_name || '';
            if (!chatTitle && data.members && data.members.length > 0) {
                try {
                    const memberNames = [];
                    for (const memberRef of data.members) {
                        // Skip the requesting user for personal keys
                        if ((auth.type === 'personal' || auth.type === 'system') && memberRef.id === auth.uid) continue;
                        const memberDoc = await memberRef.get();
                        if (memberDoc.exists) {
                            memberNames.push(memberDoc.data().display_name || 'Unknown');
                        }
                    }
                    chatTitle = memberNames.join(', ') || 'Chat';
                } catch (e) {
                    chatTitle = 'Chat';
                }
            }
            if (!chatTitle) chatTitle = 'Untitled Chat';

            chatsList.push({
                id: doc.id,
                title: chatTitle,
                is_group: data.is_group || false,
                member_count: data.members ? data.members.length : 0,
                last_message: data.last_message || "",
                last_message_at: lastMessageAt,
                description: data.description || "",
                is_private: data.is_private || false,
                chat_image_url: data.chat_image_url || "",
            });
        }

        return res.status(200).send({
            success: true,
            total_returned: chatsList.length,
            chats: chatsList
        });

    } catch (error) {
        console.error("Error in getChatList:", error);
        return res.status(500).send({ error: "Internal Server Error" });
    }
});

// ============================================================================
// 3. getChatFiles — GET ONLY FILE/MEDIA MESSAGES FROM A CHAT
// ============================================================================
exports.getChatFiles = onRequest({ secrets: [externalApiKey], invoker: "public" }, async (req, res) => {
    if (req.method !== 'POST') {
        return res.status(405).send({ error: 'Method Not Allowed. Please use POST.' });
    }

    const auth = await validateApiKey(req, res, externalApiKey.value());
    if (!auth) return;

    try {
        const payload = req.body;
        const chatId = payload.chatId;
        const limitCount = payload.limit || 50;

        if (!chatId) {
            return res.status(400).send({ error: 'Bad Request: Missing "chatId".' });
        }

        const firestore = admin.firestore();

        // Check chat exists
        const chatDoc = await firestore.collection("chats").doc(chatId).get();
        if (!chatDoc.exists) {
            return res.status(404).send({ error: `Chat ${chatId} not found.` });
        }

        if (auth.type === 'personal' || auth.type === 'system') {
            const isMember = await isUserMemberOfChat(auth.uid, chatId);
            if (!isMember) {
                return res.status(403).send({ error: 'Forbidden: You are not a member of this chat.' });
            }
        }

        // Get all recent messages, then filter for files on server side
        // (Firestore doesn't support OR queries on multiple fields easily)
        const messagesSnapshot = await firestore
            .collection("chats")
            .doc(chatId)
            .collection("messages")
            .orderBy("created_at", "desc")
            .limit(limitCount * 3) // fetch more to account for filtering
            .get();

        const filesList = [];
        messagesSnapshot.docs.forEach(doc => {
            const msgData = doc.data();

            const hasAttachment = msgData.attachment_url && msgData.attachment_url.length > 0;
            const hasImage = msgData.image && msgData.image.length > 0;
            const hasImages = msgData.images && msgData.images.length > 0;
            const hasVideo = msgData.video && msgData.video.length > 0;
            const hasAudio = msgData.audio && msgData.audio.length > 0;

            if (!hasAttachment && !hasImage && !hasImages && !hasVideo && !hasAudio) {
                return; // skip non-file messages
            }

            let timestamp = null;
            if (msgData.created_at) {
                timestamp = msgData.created_at.toDate().toISOString();
            }

            filesList.push({
                message_id: doc.id,
                sender_name: msgData.sender_name || "Unknown",
                sender_id: msgData.sender_ref ? msgData.sender_ref.id : null,
                content: msgData.content || "",
                timestamp: timestamp,
                attachment_url: msgData.attachment_url || null,
                image: msgData.image || null,
                images: msgData.images || [],
                video: msgData.video || null,
                audio: msgData.audio || null,
            });

            // Stop once we have enough
            if (filesList.length >= limitCount) return;
        });

        return res.status(200).send({
            success: true,
            chat_id: chatId,
            total_returned: filesList.length,
            files: filesList
        });

    } catch (error) {
        console.error("Error in getChatFiles:", error);
        return res.status(500).send({ error: "Internal Server Error" });
    }
});

// ============================================================================
// 4. getChatMembers — GET MEMBER LIST FOR A CHAT
// ============================================================================
exports.getChatMembers = onRequest({ secrets: [externalApiKey], invoker: "public" }, async (req, res) => {
    if (req.method !== 'POST') {
        return res.status(405).send({ error: 'Method Not Allowed. Please use POST.' });
    }

    const auth = await validateApiKey(req, res, externalApiKey.value());
    if (!auth) return;

    try {
        const payload = req.body;
        const chatId = payload.chatId;

        if (!chatId) {
            return res.status(400).send({ error: 'Bad Request: Missing "chatId".' });
        }

        const firestore = admin.firestore();

        const chatDoc = await firestore.collection("chats").doc(chatId).get();
        if (!chatDoc.exists) {
            return res.status(404).send({ error: `Chat ${chatId} not found.` });
        }

        if (auth.type === 'personal' || auth.type === 'system') {
            const isMember = await isUserMemberOfChat(auth.uid, chatId);
            if (!isMember) {
                return res.status(403).send({ error: 'Forbidden: You are not a member of this chat.' });
            }
        }

        const chatData = chatDoc.data();
        const memberRefs = chatData.members || [];

        const membersList = [];
        for (const memberRef of memberRefs) {
            try {
                const memberDoc = await memberRef.get();
                if (memberDoc.exists) {
                    const userData = memberDoc.data();
                    membersList.push({
                        user_id: memberDoc.id,
                        display_name: userData.display_name || userData.name || "Unknown",
                        email: userData.email || "",
                        photo_url: userData.photo_url || "",
                        bio: userData.bio || "",
                        location: userData.location || "",
                        is_online: userData.is_online || false,
                    });
                }
            } catch (e) {
                console.log(`Error fetching member ${memberRef.path}:`, e);
            }
        }

        return res.status(200).send({
            success: true,
            chat_id: chatId,
            chat_title: chatData.title || chatData.group_name || "Unknown",
            total_members: membersList.length,
            members: membersList
        });

    } catch (error) {
        console.error("Error in getChatMembers:", error);
        return res.status(500).send({ error: "Internal Server Error" });
    }
});

// ============================================================================
// 5. getUserInfo — GET A SINGLE USER'S PROFILE
// ============================================================================
exports.getUserInfo = onRequest({ secrets: [externalApiKey], invoker: "public" }, async (req, res) => {
    if (req.method !== 'POST') {
        return res.status(405).send({ error: 'Method Not Allowed. Please use POST.' });
    }

    const auth = await validateApiKey(req, res, externalApiKey.value());
    if (!auth) return;

    try {
        const payload = req.body;
        const userId = payload.userId;

        if (!userId) {
            return res.status(400).send({ error: 'Bad Request: Missing "userId".' });
        }

        const firestore = admin.firestore();

        const userDoc = await firestore.collection("users").doc(userId).get();
        if (!userDoc.exists) {
            return res.status(404).send({ error: `User ${userId} not found.` });
        }

        const userData = userDoc.data();

        return res.status(200).send({
            success: true,
            user: {
                user_id: userDoc.id,
                display_name: userData.display_name || "",
                email: userData.email || "",
                photo_url: userData.photo_url || "",
                bio: userData.bio || "",
                phone_number: userData.phone_number || "",
                location: userData.location || "",
                interests: userData.interests || [],
                is_online: userData.is_online || false,
                account_status: userData.account_status || "",
            }
        });

    } catch (error) {
        console.error("Error in getUserInfo:", error);
        return res.status(500).send({ error: "Internal Server Error" });
    }
});

// ============================================================================
// 6. pollQurioCalls — GET MESSAGES CONTAINING @Qurio ACROSS ALL CHATS
// ============================================================================
exports.pollQurioCalls = onRequest({ secrets: [externalApiKey], invoker: "public" }, async (req, res) => {
    if (req.method !== 'POST') {
        return res.status(405).send({ error: 'Method Not Allowed. Please use POST.' });
    }

    const auth = await validateApiKey(req, res, externalApiKey.value());
    if (!auth) return;

    try {
        const payload = req.body;
        // "since" is an ISO timestamp string; only return messages after this time
        const sinceStr = payload.since || null;
        const limitCount = payload.limit || 50;
        // Optionally only search specific chatIds
        const chatIds = payload.chatIds || null;

        const firestore = admin.firestore();

        // Strategy: get recent active chats, then query each chat's messages
        let chatsToSearch = [];

        if (chatIds && Array.isArray(chatIds) && chatIds.length > 0) {
            // If specific chatIds provided, use those
            // For personal keys, verify membership for each chat
            if (auth.type === 'personal' || auth.type === 'system') {
                for (const cid of chatIds) {
                    const isMember = await isUserMemberOfChat(auth.uid, cid);
                    if (isMember) chatsToSearch.push(cid);
                }
            } else {
                chatsToSearch = chatIds;
            }
        } else if (auth.type === 'personal' || auth.type === 'system') {
            // Personal key: only search chats where user is a member
            const userRef = firestore.collection('users').doc(auth.uid);
            const userChatsSnapshot = await firestore.collection('chats')
                .where('members', 'array-contains', userRef)
                .orderBy('last_message_at', 'desc')
                .limit(20)
                .get();
            userChatsSnapshot.docs.forEach(doc => {
                chatsToSearch.push(doc.id);
            });
        } else {
            // Partner key: search the 20 most recently active chats globally
            const chatsSnapshot = await firestore.collection("chats")
                .orderBy("last_message_at", "desc")
                .limit(20)
                .get();
            chatsSnapshot.docs.forEach(doc => {
                chatsToSearch.push(doc.id);
            });
        }

        const qurioCalls = [];

        // Search each chat for @Qurio mentions
        for (const chatId of chatsToSearch) {
            let msgQuery = firestore
                .collection("chats").doc(chatId)
                .collection("messages")
                .orderBy("created_at", "desc")
                .limit(100);

            // If "since" provided, only get messages after that time
            if (sinceStr) {
                const sinceDate = new Date(sinceStr);
                const sinceTimestamp = admin.firestore.Timestamp.fromDate(sinceDate);
                msgQuery = firestore
                    .collection("chats").doc(chatId)
                    .collection("messages")
                    .where("created_at", ">", sinceTimestamp)
                    .orderBy("created_at", "desc")
                    .limit(100);
            }

            const snapshot = await msgQuery.get();

            snapshot.docs.forEach(doc => {
                const msgData = doc.data();
                const content = (msgData.content || "").toLowerCase();

                // Check if message mentions @qurio (case insensitive)
                if (!content.includes("@qurio")) {
                    return;
                }

                let timestamp = null;
                if (msgData.created_at) {
                    timestamp = msgData.created_at.toDate().toISOString();
                }

                qurioCalls.push({
                    message_id: doc.id,
                    chat_id: chatId,
                    sender_name: msgData.sender_name || "Unknown",
                    sender_id: msgData.sender_ref ? msgData.sender_ref.id : null,
                    content: msgData.content || "",
                    timestamp: timestamp,
                    attachment_url: msgData.attachment_url || null,
                    image: msgData.image || null,
                    images: msgData.images || [],
                    video: msgData.video || null,
                    audio: msgData.audio || null,
                });
            });
        }

        // Sort chronologically (oldest first)
        qurioCalls.sort((a, b) => {
            if (!a.timestamp || !b.timestamp) return 0;
            return new Date(a.timestamp) - new Date(b.timestamp);
        });

        // Trim to limit
        const trimmed = qurioCalls.slice(0, limitCount);

        return res.status(200).send({
            success: true,
            total_returned: trimmed.length,
            chats_searched: chatsToSearch.length,
            qurio_calls: trimmed,
            polled_at: new Date().toISOString(),
        });

    } catch (error) {
        console.error("Error in pollQurioCalls:", error);
        return res.status(500).send({ error: "Internal Server Error" });
    }
});

// ============================================================================
// 7. sendQurioMessage — QURIO SENDS A MESSAGE INTO A LONA CHAT
// ============================================================================
exports.sendQurioMessage = onRequest({ secrets: [externalApiKey], invoker: "public" }, async (req, res) => {
    if (req.method !== 'POST') {
        return res.status(405).send({ error: 'Method Not Allowed. Please use POST.' });
    }

    const auth = await validateApiKey(req, res, externalApiKey.value());
    if (!auth) return;

    try {
        const payload = req.body;
        const chatId = payload.chatId;
        const content = payload.content;
        const attachmentUrl = payload.attachmentUrl || null;
        const replyToMessageId = payload.replyToMessageId || null;
        // type: 'text' = regular message (with via Qurio AI tag), 'digest' = Urgent Digest card (default)
        const messageFormat = payload.type || 'text';

        if (!chatId) {
            return res.status(400).send({ error: 'Bad Request: Missing "chatId".' });
        }
        if (!content && !attachmentUrl) {
            return res.status(400).send({ error: 'Bad Request: Must provide "content" or "attachmentUrl".' });
        }

        const firestore = admin.firestore();

        // Check chat exists
        const chatDoc = await firestore.collection("chats").doc(chatId).get();
        if (!chatDoc.exists) {
            return res.status(404).send({ error: `Chat ${chatId} not found.` });
        }

        // Permission check for personal and system keys (both are user-scoped)
        if (auth.type === 'personal' || auth.type === 'system') {
            const isMember = await isUserMemberOfChat(auth.uid, chatId);
            if (!isMember) {
                return res.status(403).send({ error: 'Forbidden: You are not a member of this chat.' });
            }
        }

        // Determine sender based on auth type
        // - personal: messages sent as the user themselves (tagged "via Qurio AI")
        // - system: messages sent as Qurio AI bot account (not as the user)
        // - partner: messages sent as Qurio AI bot account
        let senderRef, senderName, senderPhoto, senderType;
        if (auth.type === 'personal') {
            const userDoc = await firestore.collection('users').doc(auth.uid).get();
            const userData = userDoc.exists ? userDoc.data() : {};
            senderRef = firestore.collection('users').doc(auth.uid);
            senderName = userData.display_name || 'Unknown';
            senderPhoto = userData.photo_url || '';
            senderType = 'personal_api';
        } else {
            // Both 'system' and 'partner' keys send as Qurio AI
            const qurioUserRef = await ensureQurioUserExists();
            senderRef = qurioUserRef;
            senderName = 'Qurio AI';
            senderPhoto = QURIO_USER_DATA.photo_url;
            senderType = 'qurio_ai';
        }

        // Build the message document
        const now = admin.firestore.Timestamp.now();
        const messageData = {
            content: content || '',
            created_at: now,
            sender_name: senderName,
            sender_photo: senderPhoto,
            sender_ref: senderRef,
            sender_type: senderType,
            sent_via: auth.type === 'personal' ? 'qurio_ai' : null,
            message_type: attachmentUrl ? "file" : "text",
            is_system_message: false,
            is_edited: false,
            is_pinned: false,
            message_format: messageFormat, // 'text' = regular message, 'digest' = Urgent Digest card
        };

        // Add optional fields
        if (attachmentUrl) {
            messageData.attachment_url = attachmentUrl;
        }

        if (replyToMessageId) {
            // Fetch the original message to populate reply fields
            const originalMsgDoc = await firestore
                .collection("chats").doc(chatId)
                .collection("messages").doc(replyToMessageId)
                .get();

            if (originalMsgDoc.exists) {
                const originalData = originalMsgDoc.data();
                messageData.reply_to = replyToMessageId;
                messageData.reply_to_content = (originalData.content || "").substring(0, 200);
                messageData.reply_to_sender = originalData.sender_name || "Unknown";
            }
        }

        // Create the message
        const newMsgRef = await firestore
            .collection("chats").doc(chatId)
            .collection("messages")
            .add(messageData);

        // Update chat's last_message fields
        await firestore.collection("chats").doc(chatId).update({
            last_message: content ? content.substring(0, 100) : "📎 File",
            last_message_at: now,
            last_message_sent: senderRef,
            last_message_type: messageData.message_type,
        });

        console.log(`✅ Qurio AI sent message ${newMsgRef.id} to chat ${chatId}`);

        return res.status(200).send({
            success: true,
            message_id: newMsgRef.id,
            chat_id: chatId,
            sent_at: now.toDate().toISOString(),
        });

    } catch (error) {
        console.error("Error in sendQurioMessage:", error);
        return res.status(500).send({ error: "Internal Server Error" });
    }
});

// ============================================================================
// 7b. sendPersonalMessage — SEND A REGULAR MESSAGE AS THE AUTHENTICATED USER
//     Unlike sendQurioMessage, this sends a clean message with NO Qurio/Digest
//     branding. The message appears exactly as if the user sent it from the app.
//     Requires a personal API key (not a partner key).
// ============================================================================
exports.sendPersonalMessage = onRequest({ secrets: [externalApiKey], invoker: "public" }, async (req, res) => {
    if (req.method !== 'POST') {
        return res.status(405).send({ error: 'Method Not Allowed. Please use POST.' });
    }

    const auth = await validateApiKey(req, res, externalApiKey.value());
    if (!auth) return;

    // This endpoint is personal-key only
    if (auth.type !== 'personal') {
        return res.status(403).send({ error: 'Forbidden: sendPersonalMessage requires a personal API key.' });
    }

    try {
        const payload = req.body;
        const chatId = payload.chatId;
        const content = payload.content;
        const attachmentUrl = payload.attachmentUrl || null;
        const replyToMessageId = payload.replyToMessageId || null;

        if (!chatId) {
            return res.status(400).send({ error: 'Bad Request: Missing "chatId".' });
        }
        if (!content && !attachmentUrl) {
            return res.status(400).send({ error: 'Bad Request: Must provide "content" or "attachmentUrl".' });
        }

        const firestore = admin.firestore();

        // Check chat exists
        const chatDoc = await firestore.collection("chats").doc(chatId).get();
        if (!chatDoc.exists) {
            return res.status(404).send({ error: `Chat ${chatId} not found.` });
        }

        // Permission check: user must be a member of the chat
        const isMember = await isUserMemberOfChat(auth.uid, chatId);
        if (!isMember) {
            return res.status(403).send({ error: 'Forbidden: You are not a member of this chat.' });
        }

        // Get user info for sender fields
        const userDoc = await firestore.collection('users').doc(auth.uid).get();
        const userData = userDoc.exists ? userDoc.data() : {};
        const senderRef = firestore.collection('users').doc(auth.uid);
        const senderName = userData.display_name || 'Unknown';
        const senderPhoto = userData.photo_url || '';

        // Build the message document — regular message, no Qurio branding
        const now = admin.firestore.Timestamp.now();
        const messageData = {
            content: content || '',
            created_at: now,
            sender_name: senderName,
            sender_photo: senderPhoto,
            sender_ref: senderRef,
            sender_type: 'user',
            message_type: attachmentUrl ? "file" : "text",
            is_system_message: false,
            is_edited: false,
            is_pinned: false,
        };

        // Add optional fields
        if (attachmentUrl) {
            messageData.attachment_url = attachmentUrl;
        }

        if (replyToMessageId) {
            const originalMsgDoc = await firestore
                .collection("chats").doc(chatId)
                .collection("messages").doc(replyToMessageId)
                .get();

            if (originalMsgDoc.exists) {
                const originalData = originalMsgDoc.data();
                messageData.reply_to = replyToMessageId;
                messageData.reply_to_content = (originalData.content || "").substring(0, 200);
                messageData.reply_to_sender = originalData.sender_name || "Unknown";
            }
        }

        // Create the message
        const newMsgRef = await firestore
            .collection("chats").doc(chatId)
            .collection("messages")
            .add(messageData);

        // Update chat's last_message fields and clear last_message_seen for unread notifications
        await firestore.collection("chats").doc(chatId).update({
            last_message: content ? content.substring(0, 100) : "📎 File",
            last_message_at: now,
            last_message_sent: senderRef,
            last_message_type: messageData.message_type,
            last_message_seen: [senderRef], // Only the sender has "seen" this message
        });

        console.log(`✅ Personal API message ${newMsgRef.id} sent by ${auth.uid} to chat ${chatId}`);

        return res.status(200).send({
            success: true,
            message_id: newMsgRef.id,
            chat_id: chatId,
            sender: senderName,
            sent_at: now.toDate().toISOString(),
        });

    } catch (error) {
        console.error("Error in sendPersonalMessage:", error);
        return res.status(500).send({ error: "Internal Server Error" });
    }
});

// ============================================================================
// 8. uploadQurioFile — QURIO UPLOADS A FILE AND SENDS IT AS A MESSAGE
//    Accepts base64-encoded file content, uploads to Firebase Storage,
//    then creates a message with the file URL in the specified chat.
// ============================================================================
exports.uploadQurioFile = onRequest(
    { secrets: [externalApiKey], timeoutSeconds: 120, invoker: "public" },
    async (req, res) => {
        if (req.method !== 'POST') {
            return res.status(405).send({ error: 'Method Not Allowed. Please use POST.' });
        }

        const auth = await validateApiKey(req, res, externalApiKey.value());
        if (!auth) return;

        try {
            const payload = req.body;
            const chatId = payload.chatId;
            const fileName = payload.fileName;
            const fileBase64 = payload.fileBase64;
            const contentType = payload.contentType || "application/octet-stream";
            const messageText = payload.content || "";

            if (!chatId) {
                return res.status(400).send({ error: 'Missing "chatId".' });
            }
            if (!fileName) {
                return res.status(400).send({ error: 'Missing "fileName".' });
            }
            if (!fileBase64) {
                return res.status(400).send({ error: 'Missing "fileBase64" (base64-encoded file content).' });
            }

            const firestore = admin.firestore();

            // Check chat exists
            const chatDoc = await firestore.collection("chats").doc(chatId).get();
            if (!chatDoc.exists) {
                return res.status(404).send({ error: `Chat ${chatId} not found.` });
            }

            // Permission check for personal and system keys
            if (auth.type === 'personal' || auth.type === 'system') {
                const isMember = await isUserMemberOfChat(auth.uid, chatId);
                if (!isMember) {
                    return res.status(403).send({ error: 'Forbidden: You are not a member of this chat.' });
                }
            }

            // Decode base64 to buffer
            const fileBuffer = Buffer.from(fileBase64, 'base64');
            console.log(`📁 Uploading file: ${fileName} (${fileBuffer.length} bytes, ${contentType})`);

            // Upload to Firebase Storage
            const bucket = admin.storage().bucket();
            const storagePath = `qurio_uploads/${chatId}/${Date.now()}_${fileName}`;
            const file = bucket.file(storagePath);

            await file.save(fileBuffer, {
                metadata: {
                    contentType: contentType,
                    metadata: {
                        uploadedBy: (auth.type === 'personal') ? auth.uid : 'qurio_ai',
                        chatId: chatId,
                    }
                }
            });

            await file.makePublic();
            const publicUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
            console.log(`📁 File uploaded: ${publicUrl}`);

            // Determine message type
            let messageType = "file";
            if (contentType.startsWith("image/")) messageType = "image";
            else if (contentType.startsWith("video/")) messageType = "video";
            else if (contentType.startsWith("audio/")) messageType = "audio";

            // Determine sender
            let senderRef, senderName, senderPhoto, senderType;
            if (auth.type === 'personal') {
                const userDoc = await firestore.collection('users').doc(auth.uid).get();
                const userData = userDoc.exists ? userDoc.data() : {};
                senderRef = firestore.collection('users').doc(auth.uid);
                senderName = userData.display_name || 'Unknown';
                senderPhoto = userData.photo_url || '';
                senderType = 'personal_api';
            } else {
                const qurioUserRef = await ensureQurioUserExists();
                senderRef = qurioUserRef;
                senderName = 'Qurio AI';
                senderPhoto = QURIO_USER_DATA.photo_url;
                senderType = 'qurio_ai';
            }

            const now = admin.firestore.Timestamp.now();
            const finalText = auth.type === 'personal'
                ? (messageText || `📎 ${fileName}`) + ' — via Qurio AI'
                : (messageText || `📎 ${fileName}`);
            const messageData = {
                content: finalText,
                created_at: now,
                sender_name: senderName,
                sender_photo: senderPhoto,
                sender_ref: senderRef,
                sender_type: senderType,
                message_type: messageType,
                attachment_url: publicUrl,
                is_system_message: false,
                is_edited: false,
                is_pinned: false,
            };

            // For image types, also set the image field
            if (messageType === "image") {
                messageData.images = [publicUrl];
            } else if (messageType === "video") {
                messageData.video = publicUrl;
            } else if (messageType === "audio") {
                messageData.audio = publicUrl;
            }

            const newMsgRef = await firestore
                .collection("chats").doc(chatId)
                .collection("messages")
                .add(messageData);

            // Update chat's last_message
            await firestore.collection("chats").doc(chatId).update({
                last_message: messageText || `📎 ${fileName}`,
                last_message_at: now,
                last_message_sent: qurioUserRef,
                last_message_type: messageType,
            });

            console.log(`✅ Qurio AI sent file ${fileName} as message ${newMsgRef.id} to chat ${chatId}`);

            return res.status(200).send({
                success: true,
                message_id: newMsgRef.id,
                chat_id: chatId,
                file_url: publicUrl,
                file_name: fileName,
                sent_at: now.toDate().toISOString(),
            });

        } catch (error) {
            console.error("Error in uploadQurioFile:", error);
            return res.status(500).send({ error: "Internal Server Error", details: error.message });
        }
    }
);

// ============================================================================
// 9. adminQurio — ADMIN ACTIONS: add Qurio to chat, fix old messages, etc.
// ============================================================================
exports.fixQurioMessages = onRequest(
    { secrets: [externalApiKey], invoker: "public" },
    async (req, res) => {
        if (req.method !== 'POST') {
            return res.status(405).send({ error: 'Method Not Allowed.' });
        }
        const auth = await validateApiKey(req, res, externalApiKey.value());
        if (!auth) return;
        // fixQurioMessages is admin-only: require partner key
        if (auth.type !== 'partner') {
            return res.status(403).send({ error: 'Forbidden: Admin operations require partner key.' });
        }

        try {
            const payload = req.body;
            const action = payload.action || "fixMessages";
            const chatId = payload.chatId;

            if (!chatId) {
                return res.status(400).send({ error: 'Missing chatId' });
            }

            const firestore = admin.firestore();
            const qurioUserRef = await ensureQurioUserExists();

            // ---- ACTION: addToChat ----
            if (action === "addToChat") {
                const chatDoc = await firestore.collection("chats").doc(chatId).get();
                if (!chatDoc.exists) {
                    return res.status(404).send({ error: `Chat ${chatId} not found.` });
                }

                // Add Qurio user ref to the members array (if not already there)
                await firestore.collection("chats").doc(chatId).update({
                    members: admin.firestore.FieldValue.arrayUnion(qurioUserRef),
                });

                console.log(`✅ Qurio AI added to chat ${chatId}`);
                return res.status(200).send({
                    success: true,
                    action: "addToChat",
                    chat_id: chatId,
                    qurio_user_id: QURIO_USER_ID,
                });
            }

            // ---- ACTION: removeFromChat ----
            if (action === "removeFromChat") {
                await firestore.collection("chats").doc(chatId).update({
                    members: admin.firestore.FieldValue.arrayRemove(qurioUserRef),
                });
                return res.status(200).send({
                    success: true,
                    action: "removeFromChat",
                    chat_id: chatId,
                });
            }

            // ---- ACTION: fixMessages (default) ----
            const messageIds = payload.messageIds || [];
            const fixed = [];
            for (const msgId of messageIds) {
                try {
                    const msgRef = firestore
                        .collection("chats").doc(chatId)
                        .collection("messages").doc(msgId);
                    await msgRef.update({
                        sender_ref: qurioUserRef,
                        sender_photo: QURIO_USER_DATA.photo_url,
                    });
                    fixed.push(msgId);
                } catch (e) {
                    console.log(`Failed to fix message ${msgId}:`, e.message);
                }
            }

            return res.status(200).send({
                success: true,
                action: "fixMessages",
                fixed_count: fixed.length,
                fixed_message_ids: fixed,
            });
        } catch (error) {
            console.error("Error in adminQurio:", error);
            return res.status(500).send({ error: "Internal Server Error" });
        }
    }
);

// ============================================================================
// 10. deleteMessage — DELETE A MESSAGE FROM A CHAT
//     Personal key: can only delete messages sent by the authenticated user.
//     Partner key: can delete any message.
// ============================================================================
exports.deleteMessage = onRequest({ secrets: [externalApiKey], invoker: "public" }, async (req, res) => {
    if (req.method !== 'POST') {
        return res.status(405).send({ error: 'Method Not Allowed. Please use POST.' });
    }

    const auth = await validateApiKey(req, res, externalApiKey.value());
    if (!auth) return;

    try {
        const payload = req.body;
        const chatId = payload.chatId;
        const messageId = payload.messageId;

        if (!chatId) {
            return res.status(400).send({ error: 'Bad Request: Missing "chatId".' });
        }
        if (!messageId) {
            return res.status(400).send({ error: 'Bad Request: Missing "messageId".' });
        }

        const firestore = admin.firestore();

        // Check chat exists
        const chatDoc = await firestore.collection('chats').doc(chatId).get();
        if (!chatDoc.exists) {
            return res.status(404).send({ error: `Chat ${chatId} not found.` });
        }

        // Permission check for personal and system keys
        if (auth.type === 'personal' || auth.type === 'system') {
            const isMember = await isUserMemberOfChat(auth.uid, chatId);
            if (!isMember) {
                return res.status(403).send({ error: 'Forbidden: You are not a member of this chat.' });
            }
        }

        // Get the message
        const msgRef = firestore
            .collection('chats').doc(chatId)
            .collection('messages').doc(messageId);
        const msgDoc = await msgRef.get();

        if (!msgDoc.exists) {
            return res.status(404).send({ error: `Message ${messageId} not found in chat ${chatId}.` });
        }

        const msgData = msgDoc.data();

        // Personal key: can only delete own messages; system key: can delete Qurio AI messages
        if (auth.type === 'personal') {
            const senderId = msgData.sender_ref ? msgData.sender_ref.id : null;
            if (senderId !== auth.uid) {
                return res.status(403).send({ error: 'Forbidden: You can only delete your own messages.' });
            }
        } else if (auth.type === 'system') {
            const senderId = msgData.sender_ref ? msgData.sender_ref.id : null;
            if (senderId !== QURIO_USER_ID) {
                return res.status(403).send({ error: 'Forbidden: System key can only delete Qurio AI messages.' });
            }
        }

        // Delete the message
        await msgRef.delete();
        console.log(`✅ Message ${messageId} deleted from chat ${chatId} by ${auth.type === 'partner' ? 'partner' : auth.uid}`);

        // If this was the last message, update chat's last_message to the previous one
        try {
            const latestMsgSnapshot = await firestore
                .collection('chats').doc(chatId)
                .collection('messages')
                .orderBy('created_at', 'desc')
                .limit(1)
                .get();

            if (!latestMsgSnapshot.empty) {
                const latestMsg = latestMsgSnapshot.docs[0].data();
                await firestore.collection('chats').doc(chatId).update({
                    last_message: (latestMsg.content || '').substring(0, 100) || '📎 File',
                    last_message_at: latestMsg.created_at,
                    last_message_sent: latestMsg.sender_ref || null,
                    last_message_type: latestMsg.message_type || 'text',
                });
            } else {
                // No messages left
                await firestore.collection('chats').doc(chatId).update({
                    last_message: '',
                    last_message_at: null,
                });
            }
        } catch (e) {
            console.log('Could not update last_message after delete:', e.message);
        }

        return res.status(200).send({
            success: true,
            deleted_message_id: messageId,
            chat_id: chatId,
        });

    } catch (error) {
        console.error('Error in deleteMessage:', error);
        return res.status(500).send({ error: 'Internal Server Error' });
    }
});

// ============================================================================
// HELPER: check if user is admin or creator of a group chat
// ============================================================================
async function isUserAdminOfChat(uid, chatData) {
    const firestore = admin.firestore();
    const userRef = firestore.collection('users').doc(uid);
    const isAdmin = chatData.admin && chatData.admin.path === userRef.path;
    const isCreator = chatData.created_by && chatData.created_by.path === userRef.path;
    return isAdmin || isCreator;
}

// ============================================================================
// 12. createGroup — CREATE A NEW GROUP CHAT
// ============================================================================
exports.createGroup = onRequest({ secrets: [externalApiKey], invoker: "public" }, async (req, res) => {
    if (req.method !== 'POST') {
        return res.status(405).send({ error: 'Method Not Allowed. Please use POST.' });
    }

    const auth = await validateApiKey(req, res, externalApiKey.value());
    if (!auth) return;

    // Must have a user identity (personal or system key)
    if (auth.type !== 'personal' && auth.type !== 'system' && auth.type !== 'partner') {
        return res.status(403).send({ error: 'Forbidden: Invalid key type.' });
    }

    try {
        const payload = req.body;
        const title = payload.title;
        const description = payload.description || '';
        const memberIds = payload.memberIds || [];
        const chatImageUrl = payload.chatImageUrl || '';
        const isPrivate = payload.isPrivate || false;
        const workspaceId = payload.workspaceId || null;

        if (!title) {
            return res.status(400).send({ error: 'Bad Request: Missing "title".' });
        }

        const firestore = admin.firestore();

        // Determine who creates the group
        let creatorUid;
        if (auth.type === 'personal' || auth.type === 'system') {
            creatorUid = auth.uid;
        } else {
            // Partner key: must specify a creatorId
            creatorUid = payload.creatorId;
            if (!creatorUid) {
                return res.status(400).send({ error: 'Bad Request: Partner key must specify "creatorId".' });
            }
        }

        const creatorRef = firestore.collection('users').doc(creatorUid);

        // Build members list (always include creator)
        const memberRefs = [creatorRef];
        const addedIds = new Set([creatorUid]);
        for (const uid of memberIds) {
            if (addedIds.has(uid)) continue;
            // Verify user exists
            const userDoc = await firestore.collection('users').doc(uid).get();
            if (userDoc.exists) {
                memberRefs.push(firestore.collection('users').doc(uid));
                addedIds.add(uid);
            }
        }

        // If system key, also add Qurio AI as a member
        if (auth.type === 'system' || auth.type === 'partner') {
            if (!addedIds.has(QURIO_USER_ID)) {
                await ensureQurioUserExists();
                memberRefs.push(firestore.collection('users').doc(QURIO_USER_ID));
                addedIds.add(QURIO_USER_ID);
            }
        }

        // Build search_names for the group
        const searchNames = [];
        const titleLower = title.toLowerCase();
        for (let i = 0; i < titleLower.length; i++) {
            searchNames.push(titleLower.substring(0, i + 1));
        }

        const now = admin.firestore.Timestamp.now();
        const chatData = {
            title: title,
            description: description,
            is_group: true,
            is_private: isPrivate,
            created_by: creatorRef,
            created_at: now,
            admin: creatorRef,
            members: memberRefs,
            chat_image_url: chatImageUrl,
            last_message: '',
            last_message_at: now,
            search_names: searchNames,
        };

        if (workspaceId) {
            chatData.workspace_ref = firestore.collection('workspaces').doc(workspaceId);
        }

        const newChatRef = await firestore.collection('chats').add(chatData);
        console.log(`✅ Group "${title}" created by ${creatorUid}, ID: ${newChatRef.id}`);

        return res.status(200).send({
            success: true,
            chat_id: newChatRef.id,
            title: title,
            member_count: memberRefs.length,
            created_by: creatorUid,
        });

    } catch (error) {
        console.error('Error in createGroup:', error);
        return res.status(500).send({ error: 'Internal Server Error' });
    }
});

// ============================================================================
// 13. updateGroup — UPDATE GROUP INFO (title, description, image)
// ============================================================================
exports.updateGroup = onRequest({ secrets: [externalApiKey], invoker: "public" }, async (req, res) => {
    if (req.method !== 'POST') {
        return res.status(405).send({ error: 'Method Not Allowed. Please use POST.' });
    }

    const auth = await validateApiKey(req, res, externalApiKey.value());
    if (!auth) return;

    try {
        const payload = req.body;
        const chatId = payload.chatId;

        if (!chatId) {
            return res.status(400).send({ error: 'Bad Request: Missing "chatId".' });
        }

        const firestore = admin.firestore();
        const chatDoc = await firestore.collection('chats').doc(chatId).get();

        if (!chatDoc.exists) {
            return res.status(404).send({ error: `Chat ${chatId} not found.` });
        }

        const chatData = chatDoc.data();

        if (!chatData.is_group) {
            return res.status(400).send({ error: 'Bad Request: This is not a group chat.' });
        }

        // Permission check: personal/system keys must be admin or creator
        if (auth.type === 'personal' || auth.type === 'system') {
            const isMember = await isUserMemberOfChat(auth.uid, chatId);
            if (!isMember) {
                return res.status(403).send({ error: 'Forbidden: You are not a member of this chat.' });
            }
            const isAdmin = await isUserAdminOfChat(auth.uid, chatData);
            if (!isAdmin) {
                return res.status(403).send({ error: 'Forbidden: Only the group admin or creator can update group info.' });
            }
        }

        // Build update object
        const updateData = {};
        if (payload.title !== undefined) {
            updateData.title = payload.title;
            // Also update search_names
            const titleLower = payload.title.toLowerCase();
            const searchNames = [];
            for (let i = 0; i < titleLower.length; i++) {
                searchNames.push(titleLower.substring(0, i + 1));
            }
            updateData.search_names = searchNames;
        }
        if (payload.description !== undefined) updateData.description = payload.description;
        if (payload.chatImageUrl !== undefined) updateData.chat_image_url = payload.chatImageUrl;
        if (payload.isPrivate !== undefined) updateData.is_private = payload.isPrivate;

        if (Object.keys(updateData).length === 0) {
            return res.status(400).send({ error: 'Bad Request: No update fields provided. Supported: title, description, chatImageUrl, isPrivate.' });
        }

        await firestore.collection('chats').doc(chatId).update(updateData);
        console.log(`✅ Group ${chatId} updated by ${auth.uid || 'partner'}: ${Object.keys(updateData).join(', ')}`);

        return res.status(200).send({
            success: true,
            chat_id: chatId,
            updated_fields: Object.keys(updateData),
        });

    } catch (error) {
        console.error('Error in updateGroup:', error);
        return res.status(500).send({ error: 'Internal Server Error' });
    }
});

// ============================================================================
// 14. addMembers — ADD MEMBERS TO A GROUP CHAT
// ============================================================================
exports.addMembers = onRequest({ secrets: [externalApiKey], invoker: "public" }, async (req, res) => {
    if (req.method !== 'POST') {
        return res.status(405).send({ error: 'Method Not Allowed. Please use POST.' });
    }

    const auth = await validateApiKey(req, res, externalApiKey.value());
    if (!auth) return;

    try {
        const payload = req.body;
        const chatId = payload.chatId;
        const memberIds = payload.memberIds;

        if (!chatId) {
            return res.status(400).send({ error: 'Bad Request: Missing "chatId".' });
        }
        if (!memberIds || !Array.isArray(memberIds) || memberIds.length === 0) {
            return res.status(400).send({ error: 'Bad Request: Missing or empty "memberIds" array.' });
        }

        const firestore = admin.firestore();
        const chatDoc = await firestore.collection('chats').doc(chatId).get();

        if (!chatDoc.exists) {
            return res.status(404).send({ error: `Chat ${chatId} not found.` });
        }

        const chatData = chatDoc.data();

        if (!chatData.is_group) {
            return res.status(400).send({ error: 'Bad Request: Cannot add members to a DM chat.' });
        }

        // Permission check
        if (auth.type === 'personal' || auth.type === 'system') {
            const isMember = await isUserMemberOfChat(auth.uid, chatId);
            if (!isMember) {
                return res.status(403).send({ error: 'Forbidden: You are not a member of this chat.' });
            }
            const isAdmin = await isUserAdminOfChat(auth.uid, chatData);
            if (!isAdmin) {
                return res.status(403).send({ error: 'Forbidden: Only the group admin or creator can add members.' });
            }
        }

        // Get current member paths for dedup
        const existingPaths = new Set((chatData.members || []).map(ref => ref.path));

        const addedMembers = [];
        const skippedMembers = [];
        const newMemberRefs = [];

        for (const uid of memberIds) {
            const userRef = firestore.collection('users').doc(uid);
            if (existingPaths.has(userRef.path)) {
                skippedMembers.push(uid);
                continue;
            }
            // Verify user exists
            const userDoc = await firestore.collection('users').doc(uid).get();
            if (!userDoc.exists) {
                skippedMembers.push(uid);
                continue;
            }
            newMemberRefs.push(userRef);
            addedMembers.push(uid);
        }

        if (newMemberRefs.length > 0) {
            await firestore.collection('chats').doc(chatId).update({
                members: admin.firestore.FieldValue.arrayUnion(...newMemberRefs),
            });
        }

        console.log(`✅ Added ${addedMembers.length} members to group ${chatId}`);

        return res.status(200).send({
            success: true,
            chat_id: chatId,
            added: addedMembers,
            skipped: skippedMembers,
        });

    } catch (error) {
        console.error('Error in addMembers:', error);
        return res.status(500).send({ error: 'Internal Server Error' });
    }
});

// ============================================================================
// 15. removeMembers — REMOVE MEMBERS FROM A GROUP CHAT
// ============================================================================
exports.removeMembers = onRequest({ secrets: [externalApiKey], invoker: "public" }, async (req, res) => {
    if (req.method !== 'POST') {
        return res.status(405).send({ error: 'Method Not Allowed. Please use POST.' });
    }

    const auth = await validateApiKey(req, res, externalApiKey.value());
    if (!auth) return;

    try {
        const payload = req.body;
        const chatId = payload.chatId;
        const memberIds = payload.memberIds;

        if (!chatId) {
            return res.status(400).send({ error: 'Bad Request: Missing "chatId".' });
        }
        if (!memberIds || !Array.isArray(memberIds) || memberIds.length === 0) {
            return res.status(400).send({ error: 'Bad Request: Missing or empty "memberIds" array.' });
        }

        const firestore = admin.firestore();
        const chatDoc = await firestore.collection('chats').doc(chatId).get();

        if (!chatDoc.exists) {
            return res.status(404).send({ error: `Chat ${chatId} not found.` });
        }

        const chatData = chatDoc.data();

        if (!chatData.is_group) {
            return res.status(400).send({ error: 'Bad Request: Cannot remove members from a DM chat.' });
        }

        // Permission check
        if (auth.type === 'personal' || auth.type === 'system') {
            const isMember = await isUserMemberOfChat(auth.uid, chatId);
            if (!isMember) {
                return res.status(403).send({ error: 'Forbidden: You are not a member of this chat.' });
            }
            const isAdmin = await isUserAdminOfChat(auth.uid, chatData);
            if (!isAdmin) {
                return res.status(403).send({ error: 'Forbidden: Only the group admin or creator can remove members.' });
            }
        }

        // Prevent removing the admin/creator
        const adminPath = chatData.admin ? chatData.admin.path : null;
        const creatorPath = chatData.created_by ? chatData.created_by.path : null;

        const removedMembers = [];
        const skippedMembers = [];
        const refsToRemove = [];

        for (const uid of memberIds) {
            const userRef = firestore.collection('users').doc(uid);
            // Cannot remove admin or creator
            if (userRef.path === adminPath || userRef.path === creatorPath) {
                skippedMembers.push({ uid, reason: 'Cannot remove admin/creator' });
                continue;
            }
            refsToRemove.push(userRef);
            removedMembers.push(uid);
        }

        if (refsToRemove.length > 0) {
            await firestore.collection('chats').doc(chatId).update({
                members: admin.firestore.FieldValue.arrayRemove(...refsToRemove),
            });
        }

        console.log(`✅ Removed ${removedMembers.length} members from group ${chatId}`);

        return res.status(200).send({
            success: true,
            chat_id: chatId,
            removed: removedMembers,
            skipped: skippedMembers,
        });

    } catch (error) {
        console.error('Error in removeMembers:', error);
        return res.status(500).send({ error: 'Internal Server Error' });
    }
});

// ============================================================================
// 16. deleteGroup — DELETE A GROUP CHAT (and all its messages)
// ============================================================================
exports.deleteGroup = onRequest({ secrets: [externalApiKey], invoker: "public" }, async (req, res) => {
    if (req.method !== 'POST') {
        return res.status(405).send({ error: 'Method Not Allowed. Please use POST.' });
    }

    const auth = await validateApiKey(req, res, externalApiKey.value());
    if (!auth) return;

    try {
        const payload = req.body;
        const chatId = payload.chatId;

        if (!chatId) {
            return res.status(400).send({ error: 'Bad Request: Missing "chatId".' });
        }

        const firestore = admin.firestore();
        const chatDoc = await firestore.collection('chats').doc(chatId).get();

        if (!chatDoc.exists) {
            return res.status(404).send({ error: `Chat ${chatId} not found.` });
        }

        const chatData = chatDoc.data();

        if (!chatData.is_group) {
            return res.status(400).send({ error: 'Bad Request: Cannot delete a DM chat via this endpoint.' });
        }

        // Permission check: only admin/creator can delete
        if (auth.type === 'personal' || auth.type === 'system') {
            const isMember = await isUserMemberOfChat(auth.uid, chatId);
            if (!isMember) {
                return res.status(403).send({ error: 'Forbidden: You are not a member of this chat.' });
            }
            const isAdmin = await isUserAdminOfChat(auth.uid, chatData);
            if (!isAdmin) {
                return res.status(403).send({ error: 'Forbidden: Only the group admin or creator can delete a group.' });
            }
        }

        // Delete all messages in the chat (batch delete)
        const messagesRef = firestore.collection('chats').doc(chatId).collection('messages');
        let deletedCount = 0;

        while (true) {
            const batch = firestore.batch();
            const snapshot = await messagesRef.limit(500).get();
            if (snapshot.empty) break;
            snapshot.docs.forEach(doc => batch.delete(doc.ref));
            await batch.commit();
            deletedCount += snapshot.size;
        }

        // Delete the chat document itself
        await firestore.collection('chats').doc(chatId).delete();

        console.log(`✅ Group ${chatId} deleted by ${auth.uid || 'partner'}, ${deletedCount} messages removed`);

        return res.status(200).send({
            success: true,
            chat_id: chatId,
            messages_deleted: deletedCount,
        });

    } catch (error) {
        console.error('Error in deleteGroup:', error);
        return res.status(500).send({ error: 'Internal Server Error' });
    }
});

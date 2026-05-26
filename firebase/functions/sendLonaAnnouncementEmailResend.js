/**
 * Lona Service Announcement Email Script (Resend API)
 * 
 * This script sends announcement emails to all users via Resend API.
 * 
 * SETUP:
 * 1. Make sure Resend API key is configured:
 *    firebase functions:config:set resend.key="re_your_api_key"
 * 2. Download service account key from Firebase Console:
 *    Project Settings > Service Accounts > Generate New Private Key
 * 3. Save it as 'linkedup-c3e29-firebase-adminsdk-fbsvc-3e51f9a4e1.json' in this folder
 * 4. Run: node sendLonaAnnouncementEmailResend.js
 * 
 * The script uses Resend API to send emails directly (no extension needed).
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');
const { Resend } = require('resend');

// Bypassed service account check since recipients are loaded from JSON
if (!admin.apps.length) {
    admin.initializeApp(); // Basic init
}

const firestore = {
    Timestamp: {
        now: () => {
            const date = new Date();
            return {
                toDate: () => date,
                toMillis: () => date.getTime()
            };
        }
    }
};

// Resend API configuration
// Hardcoded API key from Firebase Functions config
const RESEND_API_KEY = 're_2ihMzqcR_7Z7Yn7U3uCqJbNRpjAQ1Dvv5';

const RESEND_FROM_EMAIL = 'service@lona.club'; // Use lona.club (verified domain) instead of lona.com
const RESEND_FROM_NAME = 'Lona Service';

/**
 * Converts plain text announcement message to HTML
 */
function convertMessageToHtml(message) {
    const lines = message.split('\n');
    let emailHtml = '';
    let inList = false;

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const trimmed = line.trim();

        if (trimmed.length === 0) {
            if (inList) {
                emailHtml += '</ul>';
                inList = false;
            }
            emailHtml += '<br>';
        } else if (trimmed.startsWith('•')) {
            if (!inList) {
                emailHtml += '<ul style="margin: 10px 0; padding-left: 20px;">';
                inList = true;
            }
            emailHtml += `<li style="margin: 5px 0;">${trimmed.substring(1).trim()}</li>`;
        } else {
            if (inList) {
                emailHtml += '</ul>';
                inList = false;
            }
            if (trimmed.includes('Appstore Link:') || trimmed.includes('http')) {
                const linkMatch = trimmed.match(/https?:\/\/[^\s]+/);
                if (linkMatch) {
                    emailHtml += `<p style="margin: 10px 0;">${trimmed.replace(linkMatch[0], `<a href="${linkMatch[0]}" style="color: #007AFF; text-decoration: none;">${linkMatch[0]}</a>`)}</p>`;
                } else {
                    emailHtml += `<p style="margin: 10px 0;">${trimmed}</p>`;
                }
            } else {
                emailHtml += `<p style="margin: 10px 0;">${trimmed}</p>`;
            }
        }
    }

    if (inList) {
        emailHtml += '</ul>';
    }

    return emailHtml;
}

async function sendLonaAnnouncementEmailResend() {
    console.log('🚀 Starting Lona Service Announcement Email (Resend)...\n');

    // Check Resend API key
    if (!RESEND_API_KEY) {
        console.error('❌ ERROR: Resend API key not found!');
        console.error('');
        console.error('Please set the Resend API key using ONE of the following:');
        console.error('');
        console.error('Option 1: Environment variable');
        console.error('  export RESEND_API_KEY="re_your_api_key"');
        console.error('  node sendLonaAnnouncementEmailResend.js');
        console.error('');
        console.error('Option 2: Firebase Functions config (for production)');
        console.error('  firebase functions:config:set resend.key="re_your_api_key"');
        console.error('');
        process.exit(1);
    }

    const now = admin.firestore.Timestamp.now();

    // ═══════════════════════════════════════════════════════════════
    // ANNOUNCEMENT MESSAGE - EDIT THIS!
    // ═══════════════════════════════════════════════════════════════
    const announcementMessage = `macOS Update: UI Overhaul & Performance Enhancements

This update brings a significant redesign and refined interaction logic to the macOS platform, providing a more efficient and cleaner workspace for your daily communications:

1. Integrated Schedule Send: Use the redesigned send button to schedule messages for later.
2. Live Upload Feedback: Track file upload progress in real-time with the new Uploading indicator.
3. Adjustable Font Size: Change chat font size in settings for better comfort.
4. Optimized Chat Bubbles: Read more information at a glance with the improved bubble layout.
5. Clean & Modern Navigation: Right-click or two-finger tap to access all features.

Bug Fixes:
- Fixed the "x" button issue when removing people during group creation.
- General stability and performance improvements.

Get it on the App Store:
https://apps.apple.com/us/app/lona-club/id6747595642`;
    // ═══════════════════════════════════════════════════════════════

    try {
        // Step 1: Load users from JSON file
        console.log('📝 Step 1: Loading users from JSON file...');
        const jsonFilePath = path.join(__dirname, 'user-emails.json');

        if (!fs.existsSync(jsonFilePath)) {
            console.error(`❌ ERROR: File not found: ${jsonFilePath}`);
            console.error('');
            console.error('Please run exportUserEmails.js first to generate the email list.');
            console.error('');
            process.exit(1);
        }

        const jsonData = fs.readFileSync(jsonFilePath, 'utf8');
        const allUsers = JSON.parse(jsonData);

        // Filter out any invalid entries and format for Resend
        const usersWithEmails = allUsers
            .filter(user => user.email && user.email.trim().length > 0)
            .map(user => ({
                email: user.email.trim(),
                name: user.name || 'User'
            }));

        console.log(`   📧 Loaded ${usersWithEmails.length} users from JSON file`);

        if (usersWithEmails.length === 0) {
            console.log('   ⚠️  No users with email addresses found. Exiting.');
            return;
        }

        // Step 2: Convert message to HTML
        console.log('📝 Step 2: Converting message to HTML...');
        const emailHtml = convertMessageToHtml(announcementMessage);

        const emailBody = `
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <style>
                    body { 
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; 
                        line-height: 1.6; 
                        color: #333; 
                        margin: 0; 
                        padding: 0; 
                        background-color: #f5f5f5;
                    }
                    .container { 
                        max-width: 600px; 
                        margin: 20px auto; 
                        padding: 30px; 
                        background-color: #ffffff;
                        border-radius: 8px;
                        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                    }
                    h1 { 
                        color: #333; 
                        margin-top: 0;
                    }
                    ul { 
                        margin: 15px 0; 
                        padding-left: 25px; 
                    }
                    li { 
                        margin: 8px 0; 
                    }
                    a { 
                        color: #007AFF; 
                        text-decoration: none; 
                    }
                    a:hover { 
                        text-decoration: underline; 
                    }
                    p { 
                        margin: 10px 0; 
                    }
                </style>
            </head>
            <body>
                <div class="container">
                    ${emailHtml}
                </div>
            </body>
            </html>
        `;

        // Step 3: Initialize Resend
        console.log('📝 Step 3: Initializing Resend API...');
        const resend = new Resend(RESEND_API_KEY);
        console.log(`   📧 From: ${RESEND_FROM_NAME} <${RESEND_FROM_EMAIL}>`);

        // Step 4: Send emails sequentially (Resend allows only 2 requests per second)
        console.log('📝 Step 4: Sending emails via Resend API...');
        console.log(`   ⚠️  Resend rate limit: 2 requests/second - sending sequentially with delays`);

        let successCount = 0;
        let errorCount = 0;
        const errors = [];

        // Send emails one at a time with 600ms delay (stays under 2/second limit)
        for (let i = 0; i < usersWithEmails.length; i++) {
            const user = usersWithEmails[i];
            const progress = `[${i + 1}/${usersWithEmails.length}]`;

            try {
                const { data, error } = await resend.emails.send({
                    from: `${RESEND_FROM_NAME} <${RESEND_FROM_EMAIL}>`,
                    to: user.email,
                    subject: '🎉 New macOS Update: UI Overhaul & Improvements',
                    html: emailBody,
                    text: announcementMessage,
                });

                if (error) {
                    errorCount++;
                    errors.push({ email: user.email, error: error.message });
                    console.log(`   ${progress} ❌ ${user.email} - ${error.message}`);
                } else {
                    successCount++;
                    console.log(`   ${progress} ✅ ${user.email}`);
                }
            } catch (err) {
                errorCount++;
                errors.push({ email: user.email, error: err.message });
                console.log(`   ${progress} ❌ ${user.email} - ${err.message}`);
            }

            // Wait 600ms between emails to respect rate limit (2 requests/second = 500ms minimum, using 600ms for safety)
            if (i < usersWithEmails.length - 1) {
                await new Promise(resolve => setTimeout(resolve, 600));
            }
        }

        console.log('\n═══════════════════════════════════════════════════════════');
        console.log('🎉 Email sending completed!');
        console.log('═══════════════════════════════════════════════════════════');
        console.log(`📅 Timestamp: ${now.toDate().toISOString()}`);
        console.log(`✅ Successfully sent: ${successCount}`);
        console.log(`❌ Failed: ${errorCount}`);
        console.log(`📧 Total recipients: ${usersWithEmails.length}`);

        if (errors.length > 0) {
            console.log('\n⚠️  Errors:');
            errors.slice(0, 10).forEach(err => {
                console.log(`   - ${err.email}: ${err.error}`);
            });
            if (errors.length > 10) {
                console.log(`   ... and ${errors.length - 10} more errors`);
            }
        }

        console.log('═══════════════════════════════════════════════════════════\n');

    } catch (error) {
        console.error('❌ Error sending announcement email:', error);
        process.exit(1);
    }
}

// Run the script
sendLonaAnnouncementEmailResend()
    .then(() => {
        console.log('Script completed successfully!');
        process.exit(0);
    })
    .catch((error) => {
        console.error('Script failed:', error);
        process.exit(1);
    });

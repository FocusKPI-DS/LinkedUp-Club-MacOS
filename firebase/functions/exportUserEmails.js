/**
 * Export User Emails Script
 * 
 * This script extracts all user emails from Firestore and saves them to a file.
 * 
 * SETUP:
 * 1. Download service account key from Firebase Console:
 *    Project Settings > Service Accounts > Generate New Private Key
 * 2. Save it as 'linkedup-c3e29-firebase-adminsdk-fbsvc-3e51f9a4e1.json' in this folder
 * 3. Run: node exportUserEmails.js
 * 
 * Output:
 * - user-emails.json: JSON array of all user emails with names
 * - user-emails.txt: Simple text file with one email per line
 * - user-emails.csv: CSV file with email and name columns
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Try to load service account key
const serviceAccountPath = path.join(__dirname, 'linkedup-c3e29-firebase-adminsdk-fbsvc-3e51f9a4e1.json');

if (!admin.apps.length) {
    if (fs.existsSync(serviceAccountPath)) {
        const serviceAccount = require(serviceAccountPath);
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
        });
        console.log('✅ Initialized with service account key\n');
    } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
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
        console.error('  3. Save as "linkedup-c3e29-firebase-adminsdk-fbsvc-3e51f9a4e1.json" in this folder');
        console.error('  4. Run: node exportUserEmails.js');
        console.error('');
        process.exit(1);
    }
}

const firestore = admin.firestore();

async function exportUserEmails() {
    console.log('🚀 Starting User Email Export...\n');

    try {
        // Step 1: Fetch all users with email addresses
        console.log('📝 Step 1: Fetching users with email addresses...');
        const usersSnapshot = await firestore.collection('users').get();
        
        const usersWithEmails = usersSnapshot.docs
            .filter(doc => {
                const data = doc.data();
                return doc.id !== 'lona-service' && data.email && data.email.trim().length > 0;
            })
            .map(doc => {
                const data = doc.data();
                return {
                    uid: doc.id,
                    email: data.email.trim(),
                    name: data.display_name || data.name || 'User',
                    created_time: data.created_time ? data.created_time.toDate().toISOString() : null
                };
            })
            .sort((a, b) => a.email.localeCompare(b.email)); // Sort alphabetically by email
        
        console.log(`   📧 Found ${usersWithEmails.length} users with email addresses`);

        if (usersWithEmails.length === 0) {
            console.log('   ⚠️  No users with email addresses found. Exiting.');
            return;
        }

        // Step 2: Save to JSON file
        console.log('📝 Step 2: Saving to JSON file...');
        const jsonPath = path.join(__dirname, 'user-emails.json');
        fs.writeFileSync(jsonPath, JSON.stringify(usersWithEmails, null, 2), 'utf8');
        console.log(`   ✅ Saved to: user-emails.json`);

        // Step 3: Save to TXT file (one email per line)
        console.log('📝 Step 3: Saving to TXT file...');
        const txtPath = path.join(__dirname, 'user-emails.txt');
        const emailList = usersWithEmails.map(u => u.email).join('\n');
        fs.writeFileSync(txtPath, emailList, 'utf8');
        console.log(`   ✅ Saved to: user-emails.txt`);

        // Step 4: Save to CSV file
        console.log('📝 Step 4: Saving to CSV file...');
        const csvPath = path.join(__dirname, 'user-emails.csv');
        const csvHeader = 'Email,Name,UID,Created Time\n';
        const csvRows = usersWithEmails.map(u => 
            `"${u.email}","${u.name.replace(/"/g, '""')}","${u.uid}","${u.created_time || ''}"`
        ).join('\n');
        fs.writeFileSync(csvPath, csvHeader + csvRows, 'utf8');
        console.log(`   ✅ Saved to: user-emails.csv`);

        // Step 5: Create email list for Resend (array format)
        console.log('📝 Step 5: Creating Resend-compatible format...');
        const resendFormat = usersWithEmails.map(u => ({
            email: u.email,
            name: u.name
        }));
        const resendPath = path.join(__dirname, 'user-emails-resend.json');
        fs.writeFileSync(resendPath, JSON.stringify(resendFormat, null, 2), 'utf8');
        console.log(`   ✅ Saved to: user-emails-resend.json`);

        console.log('\n═══════════════════════════════════════════════════════════');
        console.log('🎉 SUCCESS! User emails exported!');
        console.log('═══════════════════════════════════════════════════════════');
        console.log(`📧 Total users: ${usersWithEmails.length}`);
        console.log(`📄 Files created:`);
        console.log(`   - user-emails.json (full data)`);
        console.log(`   - user-emails.txt (email list)`);
        console.log(`   - user-emails.csv (spreadsheet format)`);
        console.log(`   - user-emails-resend.json (Resend format)`);
        console.log('═══════════════════════════════════════════════════════════\n');

    } catch (error) {
        console.error('❌ Error exporting user emails:', error);
        process.exit(1);
    }
}

// Run the script
exportUserEmails()
    .then(() => {
        console.log('Script completed successfully!');
        process.exit(0);
    })
    .catch((error) => {
        console.error('Script failed:', error);
        process.exit(1);
    });

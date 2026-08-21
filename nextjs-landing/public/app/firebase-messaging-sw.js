// Import Firebase scripts
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Initialize Firebase in the service worker
firebase.initializeApp({
  apiKey: "AIzaSyB7hpucMa-mSk6Bp9_OOt_1BFaO7E7HPTw",
  authDomain: "linkedup-c3e29.firebaseapp.com",
  projectId: "linkedup-c3e29",
  storageBucket: "linkedup-c3e29.firebasestorage.app",
  messagingSenderId: "548534727055",
  appId: "1:548534727055:web:d770e39d4c066094bb5bfa",
  measurementId: "G-LRGXVB1ZKH"
});

// Retrieve an instance of Firebase Messaging so that it can handle background messages
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('🔔 [Service Worker] Received background message:', payload);
  
  const notificationTitle = payload.notification?.title || 'Lona';
  const notificationOptions = {
    body: payload.notification?.body || 'You have a new notification',
    icon: '/app_launcher_icon.png', // Use your app logo
    badge: '/app_launcher_icon.png', // Use your app logo for badge too
    tag: 'linkedup-notification',
    requireInteraction: false,
    data: payload.data || {}
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification clicks
self.addEventListener('notificationclick', (event) => {
  console.log('🔔 [Service Worker] Notification clicked:', event);
  event.notification.close();

  // Open/focus the app
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // Try to focus an existing window
      for (const client of clientList) {
        if (client.url === '/' && 'focus' in client) {
          return client.focus();
        }
      }
      // If no existing window, open a new one
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});


importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

const ICON_PATH = '/icons/Icon-192.png';

function text(value) {
  return String(value || '').trim();
}

async function loadFirebaseConfig() {
  const response = await fetch('/api/notifications/config', { cache: 'no-store' });
  if (!response.ok) {
    throw new Error(`Push config request failed: ${response.status}`);
  }

  const payload = await response.json();
  const fcm = payload?.config?.fcm || {};
  const firebaseConfig = {
    apiKey: text(fcm.apiKey),
    appId: text(fcm.appId),
    messagingSenderId: text(fcm.messagingSenderId),
    projectId: text(fcm.projectId),
  };

  if (text(fcm.authDomain)) firebaseConfig.authDomain = text(fcm.authDomain);
  if (text(fcm.storageBucket)) firebaseConfig.storageBucket = text(fcm.storageBucket);
  if (text(fcm.measurementId)) firebaseConfig.measurementId = text(fcm.measurementId);

  if (
    !firebaseConfig.apiKey ||
    !firebaseConfig.appId ||
    !firebaseConfig.messagingSenderId ||
    !firebaseConfig.projectId
  ) {
    throw new Error('Firebase push config is incomplete.');
  }

  return firebaseConfig;
}

const messagingReady = loadFirebaseConfig()
  .then((firebaseConfig) => {
    firebase.initializeApp(firebaseConfig);
    const messaging = firebase.messaging();

    messaging.onBackgroundMessage((payload) => {
      const data = payload?.data || {};
      const notification = payload?.notification || {};
      const conversationUserId = text(data.conversationUserId || data.senderId);
      const title = text(notification.title) || 'Taiwan Brawl';
      const body = text(notification.body) || 'New message';
      const url =
        text(data.url) ||
        (conversationUserId
          ? `/?conversationUserId=${encodeURIComponent(conversationUserId)}`
          : '/');

      self.registration.showNotification(title, {
        body,
        icon: ICON_PATH,
        badge: ICON_PATH,
        tag: text(data.notificationId) || text(data.type) || 'taiwan-brawl-fcm',
        data: {
          ...data,
          url,
        },
      });
    });

    return messaging;
  })
  .catch((error) => {
    console.error('Firebase messaging service worker setup failed:', error);
    return null;
  });

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const rawUrl = text(event.notification?.data?.url) || self.location.origin;
  const targetUrl = new URL(rawUrl, self.location.origin).toString();

  event.waitUntil(
    clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        for (const client of clientList) {
          if ('focus' in client) {
            client.navigate(targetUrl);
            return client.focus();
          }
        }

        if (clients.openWindow) {
          return clients.openWindow(targetUrl);
        }
        return null;
      })
  );
});

self.addEventListener('install', (event) => {
  event.waitUntil(messagingReady);
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

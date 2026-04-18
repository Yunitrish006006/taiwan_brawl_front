self.addEventListener('push', (event) => {
  const payload = event.data ? event.data.json() : {};
  const title = payload?.title || '鬼島亂鬥';
  const options = {
    body: payload?.body || '',
    icon: payload?.icon || '/icons/Icon-192.png',
    badge: payload?.badge || '/icons/Icon-192.png',
    tag: payload?.tag || 'taiwan-brawl-notification',
    data: payload?.data || {},
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const rawUrl = event.notification?.data?.url || self.location.origin;
  const targetUrl = String(rawUrl || self.location.origin);

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clients) => {
      if (clients.length > 0) {
        return clients[0].navigate(targetUrl).then(() => clients[0].focus());
      }
      return self.clients.openWindow(targetUrl);
    })
  );
});

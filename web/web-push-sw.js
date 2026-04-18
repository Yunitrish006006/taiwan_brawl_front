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
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // 找到任何已開啟的 app 視窗，導航後 focus
      for (const client of clientList) {
        if ('navigate' in client) {
          return client.navigate(targetUrl).then(() => client.focus());
        }
        if ('focus' in client) {
          return client.focus();
        }
      }
      // 沒有視窗，開新的
      return self.clients.openWindow(targetUrl);
    })
  );
});

(function () {
  function urlBase64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
    const normalized = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
    const raw = window.atob(normalized);
    const output = new Uint8Array(raw.length);
    for (let index = 0; index < raw.length; index += 1) {
      output[index] = raw.charCodeAt(index);
    }
    return output;
  }

  async function getPushServiceWorkerRegistration(scopePath) {
    const registrations = await navigator.serviceWorker.getRegistrations();
    return (
      registrations.find((registration) => {
        try {
          return new URL(registration.scope).pathname === scopePath;
        } catch (_) {
          return false;
        }
      }) || null
    );
  }

  async function register(options) {
    if (
      !('serviceWorker' in navigator) ||
      !('PushManager' in window) ||
      !('Notification' in window)
    ) {
      return null;
    }

    const permission =
      Notification.permission === 'granted'
        ? 'granted'
        : await Notification.requestPermission();
    if (permission !== 'granted') {
      return null;
    }

    const serviceWorkerPath = options?.serviceWorkerPath || '/web-push-sw.js';
    const serviceWorkerScope = options?.serviceWorkerScope || '/push-notifications/';
    const publicKey = String(options?.publicKey || '').trim();
    if (!publicKey) {
      return null;
    }

    const registration = await navigator.serviceWorker.register(serviceWorkerPath, {
      scope: serviceWorkerScope,
    });
    let subscription = await registration.pushManager.getSubscription();
    if (!subscription) {
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(publicKey),
      });
    }

    return subscription.toJSON();
  }

  async function unregister() {
    if (!('serviceWorker' in navigator)) {
      return;
    }

    const registration = await getPushServiceWorkerRegistration('/push-notifications/');
    if (!registration) {
      return;
    }

    const subscription = await registration.pushManager.getSubscription();
    if (subscription) {
      await subscription.unsubscribe();
    }
  }

  function consumePendingConversationUserId() {
    const url = new URL(window.location.href);
    const rawValue = url.searchParams.get('conversationUserId');
    if (!rawValue) {
      return null;
    }

    url.searchParams.delete('conversationUserId');
    window.history.replaceState({}, document.title, url.toString());

    const parsed = Number.parseInt(rawValue, 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
  }

  function getPermissionState() {
    if (!('Notification' in window)) {
      return 'unsupported';
    }
    return Notification.permission;
  }

  window.taiwanBrawlPush = {
    register,
    unregister,
    consumePendingConversationUserId,
    getPermissionState,
  };
})();

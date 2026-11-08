(() => {
  const releaseByOwner = new Map();

  window.taiwanBrawlStreetScrapLock = {
    acquire(name, owner) {
      const lockManager = window.navigator?.locks;
      if (!lockManager || typeof lockManager.request !== 'function') {
        return Promise.resolve(false);
      }

      let signalReady;
      const ready = new Promise((resolve) => {
        signalReady = resolve;
      });
      let releaseHold;
      const hold = new Promise((resolve) => {
        releaseHold = resolve;
      });
      releaseByOwner.set(owner, releaseHold);

      try {
        lockManager.request(
          name,
          { mode: 'exclusive', ifAvailable: true },
          (lock) => {
            if (!lock) {
              releaseByOwner.delete(owner);
              signalReady(false);
              return false;
            }
            signalReady(true);
            return hold;
          },
        ).catch(() => {
          releaseByOwner.delete(owner);
          signalReady(false);
        });
      } catch (_) {
        releaseByOwner.delete(owner);
        signalReady(false);
      }
      return ready;
    },

    release(owner) {
      const release = releaseByOwner.get(owner);
      if (!release) return;
      releaseByOwner.delete(owner);
      release();
    },
  };
})();

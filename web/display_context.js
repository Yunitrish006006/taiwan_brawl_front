(function () {
  function getDisplayContext() {
    const isStandalone =
      window.matchMedia('(display-mode: standalone)').matches ||
      Boolean(window.navigator.standalone);
    const isMobile = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);
    return { isStandalone, isMobile };
  }

  window.taiwanBrawlDisplay = { getDisplayContext };
})();

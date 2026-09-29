/*
 * Force-refresh support for the installed web app (PWA).
 *
 * ── Why ─────────────────────────────────────────────────────────────────────
 * Once a web app is added to the home screen it is served by a service worker.
 * When a new build is deployed, the old worker can keep answering with the
 * bundle it cached, so the app appears frozen on a stale version. Reloading
 * does not help while the worker is still registered and controlling the page.
 *
 * `naavisClearServiceWorkerCaches()` unregisters every service worker and
 * deletes the whole Cache Storage, so the next navigation is forced onto the
 * network. `naavisHardReload()` then re-navigates with a cache-busting query
 * parameter, which also defeats the plain HTTP cache for the entry document.
 *
 * Everything resolves its dependencies at call time (navigator / caches /
 * window) rather than capturing them at load, which keeps it testable.
 */
(function () {
  'use strict';

  function isSupported() {
    return (
      typeof navigator !== 'undefined' &&
      'serviceWorker' in navigator &&
      typeof caches !== 'undefined' &&
      typeof Promise !== 'undefined'
    );
  }

  /* Resolves to a JSON summary string: {unregistered, deleted, error}. */
  function clearServiceWorkerCaches() {
    var summary = { unregistered: 0, deleted: 0, error: null };

    if (!isSupported()) {
      summary.error = 'unsupported';
      return Promise.resolve(JSON.stringify(summary));
    }

    /* Unregister FIRST: while a worker still controls the page, deleting the
       Cache Storage is useless because the worker can repopulate it. */
    return Promise.resolve(navigator.serviceWorker.getRegistrations())
      .then(
        function (registrations) {
          summary.unregistered = registrations.length;
          return Promise.all(
            registrations.map(function (registration) {
              // `.then(null, onErr)` instead of `.catch(onErr)`: same semantics,
              // but parseable by older engines (and this file is unit-tested
              // with an ES3 host, which has no `catch` property).
              return Promise.resolve(registration.unregister()).then(null, function () {
                /* one stubborn worker must not abort the rest */
              });
            })
          );
        },
        function (e) { summary.error = String(e); }
      )
      .then(function () {
        if (typeof caches.keys !== 'function') return null;
        return Promise.resolve(caches.keys()).then(
          function (keys) {
            summary.deleted = keys.length;
            return Promise.all(
              keys.map(function (key) {
                return Promise.resolve(caches.delete(key)).then(null, function () {
                  /* ignore: a locked cache is not fatal */
                });
              })
            );
          },
          function (e) { summary.error = summary.error || String(e); }
        );
      })
      .then(function () { return JSON.stringify(summary); });
  }

  /* Re-navigates to the same URL with a fresh `v` parameter so neither the
     service worker nor the HTTP cache can serve the old entry document. */
  function hardReload() {
    var url = new URL(window.location.href);
    url.searchParams.set('v', String(Date.now()));
    window.location.replace(url.toString());
  }

  window.naavisIsWebUpdateSupported = isSupported;
  window.naavisClearServiceWorkerCaches = clearServiceWorkerCaches;
  window.naavisHardReload = hardReload;
})();

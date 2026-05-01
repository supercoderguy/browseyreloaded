(function () {
  try {
    if (document.getElementById('browsey-packaged-badge')) return;
    var badge = document.createElement('div');
    badge.id = 'browsey-packaged-badge';
    badge.className = 'browsey-packaged-badge';
    badge.textContent = 'Packaged: Browsey';
    (document.body || document.documentElement).appendChild(badge);
  } catch (e) { /* swallow */ }

  try {
    if (typeof browser === 'undefined' || !browser.runtime || !browser.runtime.sendNativeMessage) return;
    browser.runtime.sendNativeMessage("00000000-0000-0000-0000-000000000001", {
      kind: "packagedExample",
      title: document.title,
      href: location.href
    });
  } catch (e) { /* ignore */ }
})();

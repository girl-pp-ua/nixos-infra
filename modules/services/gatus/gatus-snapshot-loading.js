(() => {
  const root = document.documentElement;
  root.classList.add("gatus-snapshot-loading");

  const snapshot = document.getElementById("gatus-snapshot");
  const loader = document.getElementById("gatus-snapshot-loader");
  const app = document.getElementById("app");
  if (!snapshot?.querySelector("#global") || !loader || !app) {
    snapshot?.remove();
    root.classList.remove("gatus-snapshot-loading");
    return;
  }

  let timeout;
  const finish = () => {
    observer.disconnect();
    clearTimeout(timeout);
    snapshot.remove();
    root.classList.remove("gatus-snapshot-loading");
  };
  const loaded = () => {
    const main = app.querySelector("main");
    return main && !main.querySelector("img.animate-spin") &&
      (location.pathname === "/" ? main.querySelector(".endpoint-group-content") : main.querySelector("h1"));
  };
  const observer = new MutationObserver(() => {
    if (loaded()) finish();
  });
  observer.observe(app, { childList: true, subtree: true });
  timeout = setTimeout(finish, 15000);
  if (loaded()) finish();
})();

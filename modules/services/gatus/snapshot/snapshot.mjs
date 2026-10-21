import { createRequire } from "node:module";
import { mkdir, writeFile, rename } from "node:fs/promises";
const requireDep = createRequire(process.env.JSDOM_PATH + "/");
const { JSDOM, ResourceLoader, VirtualConsole } = requireDep("jsdom");
const { Context: SvgContext } = requireDep("svgcanvas");

// Node doesn't provide these browser APIs used by svgcanvas.
globalThis.DOMMatrix ??= class DOMMatrix {
  constructor([a, b, c, d, e, f] = [1, 0, 0, 1, 0, 0]) {
    Object.assign(this, { a, b, c, d, e, f });
  }
  multiply(m) {
    const { a, b, c, d, e, f } = this;
    return new DOMMatrix([
      a * m.a + c * m.b,
      b * m.a + d * m.b,
      a * m.c + c * m.d,
      b * m.c + d * m.d,
      a * m.e + c * m.f + e,
      b * m.e + d * m.f + f,
    ]);
  }
  translate(x = 0, y = 0) {
    return this.multiply(new DOMMatrix([1, 0, 0, 1, x, y]));
  }
  scale(x = 1, y = x) {
    return this.multiply(new DOMMatrix([x, 0, 0, y, 0, 0]));
  }
};
globalThis.DOMPoint ??= class DOMPoint {
  constructor(x = 0, y = 0) {
    Object.assign(this, { x, y });
  }
  matrixTransform({ a, b, c, d, e, f }) {
    return new DOMPoint(a * this.x + c * this.y + e, b * this.x + d * this.y + f);
  }
};

// usage: snapshot.mjs <gatus url> <output dir>
const [base, out] = process.argv.slice(2);
const chartWidth = 1100;
const chartHeight = 300;
const { origin } = new URL(base);
const allowed = (url, prefixes) => {
  const u = new URL(url, base);
  return u.origin === origin && prefixes.some((p) => u.pathname.startsWith(p));
};

const endpoints = await (await fetch(new URL("/api/v1/endpoints/statuses", base))).json();
const groups = JSON.stringify([...new Set(endpoints.map((e) => e.group).filter(Boolean))]);

class LocalOnly extends ResourceLoader {
  fetch(url, options) {
    return allowed(url, ["/js/", "/css/"]) ? super.fetch(url, options) : null;
  }
}

const dom = new JSDOM(await (await fetch(base)).text(), {
  url: base,
  runScripts: "dangerously",
  resources: new LocalOnly(),
  pretendToBeVisual: true,
  virtualConsole: new VirtualConsole(),
  beforeParse(window) {
    window.localStorage.setItem("gatus:uncollapsed-groups", groups);
    window.document.cookie = "theme=dark; path=/";
    window.fetch = (url, opts) =>
      allowed(url, ["/api/"])
        ? fetch(new URL(url, base), opts)
        : Promise.reject(new window.TypeError(`blocked: ${url}`));
    window.matchMedia = (query) => ({
      matches: query === "(prefers-color-scheme: dark)",
      addEventListener() {},
      removeEventListener() {},
    });
    window.ResizeObserver = class { observe() {} unobserve() {} disconnect() {} };

    // fast-forward time inside animation frames
    const requestAnimationFrame = window.requestAnimationFrame.bind(window);
    window.requestAnimationFrame = (callback) => requestAnimationFrame((timestamp) => {
      const now = window.Date.now;
      window.Date.now = () => now() + 1000;
      try {
        callback(timestamp + 1000);
      } finally {
        window.Date.now = now;
      }
    });

    const measure = {
      font: "",
      measureText(text) {
        const px = parseFloat(/([\d.]+)px/.exec(this.font)?.[1] ?? "12");
        return {
          width: text.length * px * 0.55,
          actualBoundingBoxAscent: px * 0.8,
          actualBoundingBoxDescent: px * 0.2,
        };
      },
    };
    globalThis.document = window.document;
    window.HTMLCanvasElement.prototype.getContext = function (type) {
      if (type !== "2d") return null;
      if (!this.__svg) {
        this.__svg = new SvgContext({ document: window.document, width: this.width, height: this.height, ctx: measure });
        this.__svg.canvas = this;
      }
      return this.__svg;
    };
    const rect = window.Element.prototype.getBoundingClientRect;
    window.Element.prototype.getBoundingClientRect = function () {
      if (!this.querySelector(":scope > canvas")) return rect.call(this);
      const [width, height] = [chartWidth, chartHeight];
      return { x: 0, y: 0, top: 0, left: 0, width, height, right: width, bottom: height, toJSON() {} };
    };
  },
});
const { window } = dom;
const { document } = window;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const waitFor = async (check, what, timeout = 20000) => {
  const deadline = Date.now() + timeout;
  while (!check()) {
    if (Date.now() > deadline) throw new Error(`timed out waiting for ${what}`);
    await sleep(100);
  }
  await sleep(300);
};
const navigate = (path) => document.querySelector("#app").__vue_app__.config.globalProperties.$router.push(path);

// swap an element for a plain link
const toLink = (el, href) => {
  const a = el.ownerDocument.createElement("a");
  for (const { name, value } of el.attributes) if (name !== "role" && name !== "tabindex") a.setAttribute(name, value);
  a.setAttribute("href", href);
  a.innerHTML = el.innerHTML;
  el.replaceWith(a);
};

const capture = (fix) => {
  const app = document.querySelector("#app").cloneNode(true);
  fix(app);
  const canvases = [...document.querySelectorAll("#app canvas")];
  [...app.querySelectorAll("canvas")].forEach((copy, i) => {
    const { __svg: svg, width, height } = canvases[i] ?? {};
    if (!svg) return copy.remove();
    const el = svg.getSvg().cloneNode(true);
    el.setAttribute("viewBox", `0 0 ${width} ${height}`);
    el.removeAttribute("width");
    el.removeAttribute("height");
    el.setAttribute("style", "width: 100%; height: 100%");
    for (const rect of el.querySelectorAll("rect")) {
      if (rect.getAttribute("fill")?.toLowerCase() === "#ffffff") rect.remove();
    }
    copy.replaceWith(el);
  });

  // "refresh data" just reloads the page :p
  for (const button of app.querySelectorAll('button[title="Refresh data"]')) {
    button.removeAttribute("disabled");
    toLink(button, window.location.pathname);
  }

  // ensure the snapshot is entirely static
  app.querySelectorAll("script, noscript, iframe, object, embed, template, foreignObject").forEach((e) => e.remove());
  for (const el of app.querySelectorAll("*")) {
    for (const { name, value } of [...el.attributes]) {
      if (name.startsWith("on") || /^\s*javascript:/i.test(value)) el.removeAttribute(name);
    }
  }

  return app.innerHTML.replaceAll("{", "&#123;");
};

await mkdir(`${out}/endpoints`, { recursive: true });
const save = async (file, html) => {
  await writeFile(`${out}/${file}.tmp`, html);
  await rename(`${out}/${file}.tmp`, `${out}/${file}`);
};

await waitFor(() => document.querySelector(".endpoint-group-content"), "the dashboard");
const keys = new Map(endpoints.map((e) => [`${e.group ?? ""}\n${e.name}`, e.key]));
const linkEndpoints = (app) => {
  for (const span of app.querySelectorAll('span[role="link"][aria-label^="View details for "]')) {
    const group = span.closest(".endpoint-group")?.querySelector("h2")?.textContent.trim() ?? "";
    const key = keys.get(`${group}\n${span.textContent.trim()}`);
    if (key) toLink(span, `/endpoints/${encodeURIComponent(key)}`);
  }
};
await save("index.html", capture(linkEndpoints));

for (const { key, name } of endpoints) {
  try {
    await navigate("/suites/-");
    await navigate(`/endpoints/${encodeURIComponent(key)}`);
    await waitFor(() => [...document.querySelectorAll("h1")].some((h) => h.textContent.trim() === name), `endpoint ${key}`);
    await waitFor(() => {
      const svg = document.querySelector("#app canvas")?.__svg?.getSvg();
      return svg?.querySelector("path") && svg.querySelector("text");
    }, `chart for ${key}`, 5000).catch(() => {});
  } catch (e) {
    console.error(e.message);
    continue;
  }
  const linkBack = (app) => {
    const back = app.querySelector(".dashboard-container button");
    if (back) toLink(back, "/");
  };
  await save(`endpoints/${key}.html`, capture(linkBack));
}
window.close();

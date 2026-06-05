/* ============================================================
   The Agora Road — main.js
   Everything you'll want to change lives in CONFIG below.
   ============================================================ */

/* ---- 1) YOUR THREE BUILDINGS -------------------------------
   Swap `img` for your own icon files (drop them in /assets).
   x       = horizontal position on the road  (0%=left, 100%=right)
   topPct  = where the building's BASE rests on the road band
   width   = on-screen size (any CSS length / clamp())
   href    = where a click goes ("" = no navigation, fires an event instead)
------------------------------------------------------------- */
const CONFIG = {
  buildings: [
    {
      id: "agora",
      img: "assets/building_1.png",
      title: "The Agora",
      tagline: "marketplace & forum",
      x: "19%", topPct: "58%",
      width: "clamp(92px, 23vw, 280px)",
      href: ""
    },
    {
      id: "temple",
      img: "assets/building_2.png",      // ← replace with your 2nd icon
      title: "The Temple",
      tagline: "sanctuary",
      x: "50%", topPct: "57%",
      width: "clamp(86px, 20vw, 250px)",
      href: ""
    },
    {
      id: "stoa",
      img: "assets/building_3.png",      // ← replace with your 3rd icon
      title: "The Stoa",
      tagline: "the long colonnade",
      x: "81%", topPct: "59%",
      width: "clamp(92px, 22vw, 270px)",
      href: ""
    }
  ],

  /* ---- 2) DECORATIVE SCENERY ----
     layer: "back" (behind buildings) or "front" (in front).
     hideOnMobile thins the scene on phones.                     */
  scenery: [
    { img:"assets/cypress.png",        x:"7%",  top:"50%", w:"clamp(46px,7vw,92px)",  layer:"back" },
    { img:"assets/statue.png",         x:"33%", top:"50%", w:"clamp(40px,6vw,78px)",  layer:"back", hideOnMobile:true },
    { img:"assets/broken_column.png",  x:"66%", top:"51%", w:"clamp(34px,5vw,66px)",  layer:"back", hideOnMobile:true },
    { img:"assets/cypress.png",        x:"93%", top:"49%", w:"clamp(46px,7vw,96px)",  layer:"back" },
    { img:"assets/olive_bush.png",     x:"42%", top:"52%", w:"clamp(34px,5vw,66px)",  layer:"back", hideOnMobile:true },

    { img:"assets/amphora.png",        x:"11%", top:"78%", w:"clamp(30px,4.5vw,58px)", layer:"front" },
    { img:"assets/olive_bush.png",     x:"27%", top:"82%", w:"clamp(44px,7vw,86px)",   layer:"front" },
    { img:"assets/brazier.png",        x:"50%", top:"74%", w:"clamp(26px,4vw,52px)",   layer:"front", hideOnMobile:true },
    { img:"assets/olive_bush.png",     x:"73%", top:"83%", w:"clamp(48px,7vw,90px)",   layer:"front" },
    { img:"assets/amphora.png",        x:"90%", top:"79%", w:"clamp(30px,4.5vw,56px)", layer:"front", hideOnMobile:true }
  ],

  parallax: true   // subtle depth on mouse / device tilt
};

/* ---- build the buildings ---- */
const stopsEl = document.getElementById("stops");
CONFIG.buildings.forEach((b, i) => {
  const stop = document.createElement(b.href ? "a" : "button");
  stop.className = "stop";
  stop.style.left = b.x;
  stop.style.top = b.topPct;
  stop.style.setProperty("--i", i);
  if (b.href) { stop.href = b.href; }
  stop.setAttribute("aria-label", `${b.title} — ${b.tagline}`);
  stop.dataset.id = b.id;

  const img = document.createElement("img");
  img.className = "art";
  img.src = b.img;
  img.alt = b.title;
  img.style.width = b.width;
  img.draggable = false;

  const plaque = document.createElement("span");
  plaque.className = "plaque";
  plaque.innerHTML = `${b.title}<small>${b.tagline}</small>`;

  stop.append(img, plaque);
  if (!b.href) {
    stop.addEventListener("click", () => {
      // no link set → emit an event you can hook into
      document.dispatchEvent(new CustomEvent("agora:enter", { detail: b }));
      console.log("entered:", b.id);
    });
  }
  stopsEl.appendChild(stop);
});

/* ---- build the scenery ---- */
const backEl = document.getElementById("scenery-back");
const frontEl = document.getElementById("scenery-front");
CONFIG.scenery.forEach(s => {
  const img = document.createElement("img");
  img.src = s.img; img.alt = "";
  img.style.left = s.x; img.style.top = s.top; img.style.width = s.w;
  if (s.hideOnMobile) img.dataset.mobile = "hide";
  (s.layer === "front" ? frontEl : backEl).appendChild(img);
});

/* ---- subtle parallax depth ---- */
if (CONFIG.parallax && !matchMedia("(prefers-reduced-motion: reduce)").matches) {
  const road = document.querySelector(".road");
  const apply = (px, py) => {
    backEl.style.transform  = `translate(${px * 6}px,  ${py * 4}px)`;
    frontEl.style.transform = `translate(${px * -14}px, ${py * -8}px)`;
    if (road) road.style.transform =
      `translateY(-50%) rotate(-1.2deg) translate(${px * -4}px, ${py * 3}px)`;
  };
  window.addEventListener("mousemove", e => {
    apply((e.clientX / innerWidth - .5) * 2, (e.clientY / innerHeight - .5) * 2);
  }, { passive: true });
  window.addEventListener("deviceorientation", e => {
    if (e.gamma == null) return;
    apply(Math.max(-1, Math.min(1, e.gamma / 30)), Math.max(-1, Math.min(1, (e.beta - 45) / 30)));
  }, { passive: true });
}

/* ---- example hook: do something when a building is chosen ----
document.addEventListener("agora:enter", e => {
  console.log("go to", e.detail.title);
});
*/

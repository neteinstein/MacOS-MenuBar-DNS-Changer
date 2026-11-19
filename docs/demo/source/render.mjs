// Captures scene.html frame by frame. Usage:
//   node render.mjs <outDir> [fps=30] [duration=22]          all frames, as PNG
//   node render.mjs <outDir> stills <t1> <t2> ...            single frames at those times
import { createRequire } from "node:module";
import { mkdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

// Playwright is resolved with require so a global install works (NODE_PATH="$(npm root -g)").
const { chromium } = createRequire(import.meta.url)("playwright");

const [outDir, a, ...rest] = process.argv.slice(2);
mkdirSync(outDir, { recursive: true });
const here = path.dirname(fileURLToPath(import.meta.url));
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
await page.goto("file://" + path.join(here, "scene.html"));
await page.evaluate(() => window.ready);

const shoot = async (t, file) => {
  await page.evaluate((t) => window.render(t), t);
  await page.screenshot({ path: path.join(outDir, file), type: "png" });
};

if (a === "stills") {
  for (const t of rest) await shoot(Number(t), `still-${Number(t).toFixed(2)}.png`);
} else {
  const fps = Number(a || 30), duration = Number(rest[0] || 22);
  const frames = Math.round(fps * duration);
  for (let i = 0; i < frames; i++) await shoot(i / fps, `f${String(i).padStart(4, "0")}.png`);
}
await browser.close();

# quantmechanica.com — Design Refresh "Apple language" (concept + build brief)

**Authority:** OWNER 2026-09-02 ("Geh die Designsprache an und unterzieh alles einem ordentlichen
Refresh. Chartdesign so realistisch wie möglich."), vault ToDo `QM-TODO-20260824-201`
(Typografie, Weißraum, reduzierte Farbigkeit, großzügige Produkt-/Zahlenflächen; public-data
JSON-Verträge unverändert). Concept = Claude lane; implementation by Claude subagents in a
git worktree of the deploy repo; **local preview only, no push, no Netlify deploy** until the
OWNER has reviewed at `http://127.0.0.1:8090/`.

**Baseline audited 2026-09-02 16:4xZ** (four scouts + critic, journal `wf_1999c139-a27`):
one tokenised dark stylesheet (`style.css`, slate-950 + emerald) overridden by a page-specific
inline `<style>` on every page; nine accent hues; glows/holographic effects; three nav variants
and two footers; eight hero variants; 402 orphaned strategy pages sharing a byte-identical inline
CSS block (1.1 MB duplicated); 27 raw German-locale MT5 reports (up to 1.3 MB each) and build
scripts (`create_slides.py`, `_faq_update.py`, `scripts/parse_comm_reports.py`, `comm_data*`)
published in the web root; eight empty blog stubs in the sitemap; charts are bespoke canvas with
hard-coded OHLC arrays (index) and static SVG (strategy pages); no chart library.

## 1. Design principles (what "Apple language" means here)

1. **Typography carries the design.** Large, tight display type; calm body text; no decorative
   effects. One sans family, tabular numerals for every number.
2. **Whitespace is the layout.** 8-pt grid, wide vertical rhythm, narrow reading measure.
3. **Reduced colour.** Neutrals plus **one** accent. Semantic pass/fail colour only inside data
   tables and badges, desaturated.
4. **Number surfaces.** Key figures are shown as large numerals with a short caption, on their
   own quiet panel — never inside a busy card.
5. **Dark panels for evidence.** Charts and live data sit on black panels (Apple product-panel
   alternation); everything else is light. This keeps the OWNER's "charts dark" preference.
6. **Nothing glows, nothing floats, nothing pulses.** Motion is limited to opacity/translate on
   scroll-in and the chart's own data animation, honouring `prefers-reduced-motion`.
7. **Honesty of numbers.** Every number on the site is either injected from `public-data`
   (`data-stat`) or is a measured value with a date in a caption. No decorative statistics.

## 2. Tokens (new `style.css` v3 — single source, no inline page CSS)

```
/* colour */
--c-bg:            #ffffff;   --c-bg-alt: #f5f5f7;   --c-panel-dark: #000000; --c-panel-dark-2: #111114;
--c-text:          #1d1d1f;   --c-text-2: #6e6e73;   --c-text-3: #86868b;     --c-text-on-dark: #f5f5f7;
--c-line:          rgba(0,0,0,.08);  --c-line-on-dark: rgba(255,255,255,.12);
--c-accent:        #0a7d4f;   /* single brand accent: deep emerald, AA on white */
--c-accent-hover:  #086a43;   --c-accent-on-dark: #34d399;
--c-pass: #2f9e5f; --c-fail: #c8412d; --c-warn: #b7791f;   /* tables/badges only, muted */
/* type */
--font-sans: "Inter", -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Helvetica, Arial, sans-serif;
--fs-display-1: clamp(48px, 7vw, 96px);  /* lh 1.05, ls -0.02em, w 600 */
--fs-display-2: clamp(40px, 5vw, 64px);  /* lh 1.08, ls -0.015em, w 600 */
--fs-h2: clamp(32px, 3.5vw, 48px);       /* lh 1.1,  ls -0.01em, w 600 */
--fs-h3: 28px; --fs-lead: 21px; --fs-body: 17px; --fs-small: 14px; --fs-caption: 12px;
--num: font-variant-numeric: tabular-nums;  /* every numeral */
/* space (8-pt) */
--s-1: 8px; --s-2: 16px; --s-3: 24px; --s-4: 32px; --s-6: 48px; --s-8: 64px; --s-12: 96px; --s-16: 128px; --s-20: 160px;
--measure: 680px;  --content: 980px;  --wide: 1200px;
/* shape */
--r-sm: 12px; --r-md: 18px; --r-lg: 28px;  --shadow: 0 4px 24px rgba(0,0,0,.06);  /* no glow tokens */
--ease: cubic-bezier(.4,0,.2,1); --dur: 320ms;
```

Legacy token names (`--qm-*`, `--em`, `--g1..3`, `--white`, `--card`, `--border`, `--space-*`,
`--fs-*`, `--r-*`, `--sh-*`) **stay defined as aliases** mapped onto the new values so the 402
templated strategy pages and blog posts degrade gracefully before they are regenerated.
Google Fonts: Inter 400/500/600/700 only (one `<link>`), **Source Code Pro removed** — numerals
use the sans with `tabular-nums`.

## 3. Components (one implementation each, in `style.css`)

- **Nav** (one variant for all pages): 48 px, translucent white with `backdrop-filter`, wordmark
  left, links right: Pipeline · Strategies · Performance · Blog · About · FAQ; "Shop" as a small
  secondary link; hamburger below 900 px. Same markup on every page, clean URLs
  (`/pipeline`, `/strategies`, …; Netlify pretty-URL serves `pipeline.html`).
- **Footer** (one variant): 4 columns (Brand · Site · Legal · Contact) + the risk notice block
  on every page.
- **Hero**: display type on white, one-line lead, one primary button; the evidence chart lives
  in the *next* section (a dark panel), not behind the headline.
- **Number surface** (`.figure`): numeral `--fs-display-2` with `tabular-nums`, caption
  `--fs-small` in `--c-text-2`, optional date in `--fs-caption`. Grid of 2–4 per row, no borders,
  hairline dividers between columns on desktop.
- **Panel** (`.panel`, `.panel--dark`): `--r-lg`, `--c-bg-alt` or black, padding `--s-8`;
  the only "card" on the site. No hover lift, no gradients.
- **Gate card** (pipeline): number + name + one sentence; stage headers as small caps labels.
- **Table** (`.table`): hairline rows, 17 px, right-aligned numerals, sticky header on desktop,
  status badge (pass/fail/pending) as text-weight badges with muted semantic colour.
- **Accordion** (FAQ): native `<details>`, plus-to-minus indicator, hairline dividers.
- **Buttons**: primary (accent fill, pill), secondary (text with chevron). Nothing else.
- **Prose** (`.prose`): 17/1.6, measure 680 px, h2 32 px, links accent, code inline muted.

## 4. Charts — "so realistisch wie möglich"

**Engine:** one shared module `scripts/qm-charts.js` (hand-rolled canvas 2D, no third-party
library, no attribution obligations), HiDPI aware, ResizeObserver, `prefers-reduced-motion`.
Two renderers:

1. **Equity renderer** — real data. Source: the Q10-passed sleeve set's daily return series
   (`D:/QM/reports/portfolio/invvol_stage1_20260804/daily/*.csv`, 24 sleeves, weekdays
   2017-01-02…2025-12-31, EUR at RISK_FIXED 1000). A generator (`tools/build_public_charts.py`
   in the deploy repo) sums the sleeves into **one aggregate curve**, rebases to index 100,
   emits `Website/public-data/hero-equity.json` = `{schema_version:1, generated_at, basis:
   "illustrative combined backtest, RISK_FIXED-normalised, not live", series:[[date,index]…]
   weekly-sampled}` — **no per-EA identification, no per-strategy metrics** (keeps the public
   archive disclosure level `terminal_pass_fail_without_metrics`; the OWNER decides at review
   whether even the aggregate curve is published; a synthetic fallback is one flag away).
   Rendering: thin line, area fill 8 % white on black, drawdown shading under the running high,
   y-axis on the right with index values, x-axis years, caption with basis + date. Nothing
   smoothed — real curves are jagged.
2. **Price-action renderer** — calibrated synthetic OHLC (licensed market data is not
   redistributed: the Dukascopy CSV and the Darwinex feed on this machine are not publishable).
   Per instrument a parameter set fitted offline from real daily statistics (daily vol, GARCH-like
   persistence, return skew/kurtosis, wick/body ratio distribution, gap frequency, session
   volume profile) and a fixed seed, so every visitor sees the same chart. Realism checklist the
   reviewer must tick: volatility clustering visible; bodies and wicks vary (no uniform candles);
   occasional gaps; realistic price scale and tick size per instrument (EURUSD 5 decimals,
   XAUUSD 2, US100 1); volume bars correlated with range; MA/BB overlays computed from the
   series, not painted; right-axis price labels; time axis with dates; candle width/gap
   proportion like a trading terminal (body 70 % of slot, 1 px wick); up/down colours muted
   (green `#34d399` / red `#f87171` on black), grid hairlines at 6 % white. Captioned
   "illustrative price action (synthetic, calibrated)". The three index feature widgets
   (EUR/USD session model, XAU/USD PO3, US100 indicators) keep their concepts, drawn by this
   renderer with annotation layers (session boxes, swing markers) in `--c-text-3`.

Static SVG on strategy pages is replaced by a **gate-journey strip** (18 dots Q00–Q17,
pass/fail/pending) — no equity, no metrics (disclosure level unchanged).

## 5. Page treatments

| Page | Treatment |
|---|---|
| index | Hero (headline, lead, CTA) → dark panel with the equity chart + 4 number surfaces (`eas_compiled`, `backtests_total`, `strategy_cards`, `phases`) → "How it works" 3 columns → pipeline teaser (18 gates as one row of numbered dots + link) → three price-action widgets (dark panel) → transparency section (archive link) → newsletter CTA (still disabled, honest copy) |
| pipeline | Hero → funnel as four number surfaces (values from `public-data` where a key exists, otherwise static with a date caption) → 18 gate cards in three stage groups |
| strategies | Hero + KPI number surfaces → data-driven table from `public-data/strategy-archive.json` (public_id, family/mechanism if present, terminal gate, pass/fail per stage) with filter chips that work (JS) → no links to the orphaned 402 pages unless the id matches |
| performance | Hero → dark panel with Myfxbook iframe → number surfaces → governance copy |
| about | Hero → prose columns → agent roster as a simple table |
| faq | Hero → accordion (native details) |
| blog | Index lists all real posts (21) from a generated list; the 8 empty stubs are removed from sitemap and deleted; posts use `.prose` |
| legal ×3, 404 | `.prose` on white, unminified, one shared structure |
| strategies/SM_*.html (402) | Regenerated from the updated template: inline CSS removed, shared classes, gate-journey strip; still unlinked from nav (OWNER decides on exposure) |
| reports/COMM_* (27) | Left untouched and unlinked (raw evidence exports); flagged for OWNER |

Web-root build tooling (`create_slides.py`, `_faq_update.py`, `scripts/parse_comm_reports.py`,
`scripts/comm_data*`) moves to `tools/site-build/` in the deploy repo (outside the publish dir).
Unused assets (`assets/logo.png`, `assets/test.png`, `equity/*.png`, social templates) are
listed for the OWNER, not deleted.

## 6. Numbers and data contracts

- `public-data/*.json` contracts unchanged (OWNER constraint). New file `hero-equity.json` is
  additive. `stats-loader.js` keeps `stats.json` as primary and `data/stats.json` as fallback;
  the funnel keys (`q02_baseline_pass`, `q04_walkforward_pass`, `q08_davey_stats_pass`,
  `portfolio_candidates`) stay static with a "measured 2026-09-02" caption until the producer
  supplies them (Codex follow-up, publisher path).
- One headline count: `eas_compiled` (4,799 today). Copy never hard-codes it; use
  `data-stat`/templates. Static fallbacks equal today's values.

## 7. Exposure rules (unchanged, enforced by review)

No VPS paths, hostnames, terminal names/counts, account numbers, provider names, internal
ticket ids, credentials, or build tooling in the publish dir. Reviewer greps the whole
`Website/` tree, including JSON and JS.

## 8. Build plan (workflow, git worktree `C:/QM/deploy/qm-ops-refresh`, branch `refresh/apple-2026-09`)

1. `style.css` v3 + nav/footer markup contract (one agent) → all other agents consume it.
2. Charts module + generator + `hero-equity.json` (one agent, with the realism checklist).
3. Pages in parallel (index; pipeline; strategies + template + regeneration script; performance
   + about + faq; blog index + 21 posts; legal + 404), each removing inline CSS and adopting the
   shared nav/footer.
4. Review: (a) exposure grep, (b) HTML validity + links + sitemap, (c) visual QA via headless
   Chrome screenshots at 1440/1024/390 px (agents read the PNGs), (d) chart realism checklist.
5. Preview: point the 8090 server at the refresh worktree; OWNER review; no push.

## 9. Open OWNER decisions surfaced by the audit

1. Publish the aggregate backtest equity curve (index 100, no per-EA data)? Default in preview:
   yes, captioned; flag `QM_PUBLIC_EQUITY=synthetic` swaps to synthetic.
2. Keep the 402 orphaned strategy pages and 27 raw MT5 reports in the deploy?
3. Netlify: the live site still serves the pre-2026-08-20 build; the connected source/branch or
   build status must be checked in the Netlify dashboard (site `2fb3e857…`).

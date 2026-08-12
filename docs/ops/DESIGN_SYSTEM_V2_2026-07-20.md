# QuantMechanica Design System v2 — "PAPER/INK" (Direction C · Unified Neutral)

**Status:** OWNER-ratified 2026-07-20 (Direction C of the three-way proposal;
decision recorded in `D:\QM\reports\state\owner_decisions.json`).
**Replaces:** STEEL/EMERALD dark theme (OWNER call 2026-05-23).
**Scope:** every internal operating surface — web dashboards, cockpit, DXZ
journal, mail digests, EA chart panels. Video/intro branding stays dark (the
one documented exception). quantmechanica.com public surfaces are a separate
OWNER-visible step (see rollout table).

The unchanged brand discipline carries over verbatim: **sharp corners, hairline
borders, NO glow / gradient / blur / motion.** Tagline "The Quantitative Edge"
untouched.

---

## 1. Design tokens

Canonical CSS custom-property names as used by `tools/strategy_farm/dashboards/style.css`
and the `:root` block in `tools/strategy_farm/render_cockpit.py`. The mail palette
(`tools/strategy_farm/gmail_alarm.py::PALETTE`) mirrors these values under its
legacy key names (mail needs inline CSS, no vars).

### Surfaces & text

| Token         | Hex       | Role                                            |
|---------------|-----------|-------------------------------------------------|
| `--bg`        | `#f6f5f2` | Page background — warm paper, not clinic white  |
| `--surface-1` | `#ffffff` | Cards / panels / tables (white on paper)        |
| `--surface-2` | `#f1efe8` | Insets, inputs, hover, tile fills               |
| `--surface-3` | `#e8e4d9` | Deepest inset                                   |
| `--text`      | `#1c1a16` | Primary ink                                     |
| `--text-2`    | `#45403a` | Secondary ink                                   |
| `--text-3`    | `#726b60` | Muted (labels, captions)                        |
| `--text-4`    | `#9a938a` | Subtle (footnotes, disabled)                    |
| `--border`    | `#e2ded4` | Hairline border (warm gray)                     |
| `--border-2`  | `#cfc9bc` | Stronger border (controls, emphasis)            |
| `--border-3`  | `#b3ab9c` | Strongest border                                |

### Accent — exactly ONE

| Token             | Hex       | Role                                          |
|-------------------|-----------|-----------------------------------------------|
| `--signal`        | `#2954d4` | THE brand accent (steel blue): links, focus, brand marks, section glyphs, kickers |
| `--signal-bright` | `#1e42b8` | Hover/active emphasis (darker on light bg)    |
| `--signal-dim`    | `#5b7ade` | De-emphasized accent                          |

The emerald-as-everything double role is **abolished**: emerald used to be
brand accent, PASS status *and* de-facto P&L color at once. Blue is now the
only accent; green and red are reserved for the two semantic systems below.

### Status colors — meaning unchanged, palette translated

| Token         | Hex       | Meaning                                          |
|---------------|-----------|--------------------------------------------------|
| `--pass`      | `#1a8f4c` | OK / PASS / done / healthy — **green**           |
| `--warn`      | `#b8720a` | WARN / attention — **amber**                     |
| `--fail`      | `#d13438` | CRITICAL / FAIL / broken — **red**               |
| `--promising` | `#8f6e06` | In-progress, looking good (distinct from warn)   |
| `--dead`      | `#98918a` | Retired / dead — warm gray                       |
| `--live`      | `#0e7490` | Live trading marker — teal                       |
| `--info`      | `#45403a` | Informational (ink)                              |

### P&L semantics — TRUE red/green (new in v2)

| Token      | Hex       | Meaning                 |
|------------|-----------|-------------------------|
| `--profit` | `#1a8f4c` | Positive P&L / equity up |
| `--loss`   | `#d13438` | Negative P&L / equity down |

`--profit`/`--loss` are deliberately separate tokens from `--pass`/`--fail`
even though the hues currently coincide: a PASS verdict and a profitable night
are different statements, and either pair can be retuned without touching the
other. Rules:

1. **Money movement** (net P&L, equity deltas, daily bars, equity curves) uses
   `--profit`/`--loss` — never the accent, never status tokens.
2. **Gate/health status** uses `--pass`/`--warn`/`--fail` — OK=green,
   WARN=amber, CRITICAL=red.
3. **MAINTENANCE is amber, never red.** `FACTORY_OFF.flag` renders as
   MAINTENANCE (amber) in the cockpit and as GELB in the mail ampel — a
   deliberate stop is not a CRITICAL (standing rule, unchanged).
4. The accent blue never encodes good/bad. If a number is colored blue it is
   navigation/emphasis, not a verdict.

### Typography

Unchanged: General Sans (Fontshare) for prose, JetBrains Mono (Google Fonts)
for numbers/labels on web surfaces; mail keeps its inline font stacks
(`Inter/Segoe UI` + `Source Code Pro/Consolas` mono). Tabular numerals for all
metrics.

### Video/intro exception (documented, dark)

Video and build-in-public branding remains dark (must hold against YouTube's
dark UI): bg `#0b0d12`, surface `#171a21`, accent lightened to `#4f6ee0`.
This is the only sanctioned dark surface in the system.

---

## 2. Decision reference

- **Proposal:** Claude, 2026-07-20 — three directions (A "Clean Terminal",
  B "Split Identity", C "Unified Neutral") built on one shared 9-token
  contract. OWNER picked **C**: paper-light everywhere in operations, dark only
  for video, true red/green P&L on light ground (EarnForex-panel reference for
  EA chart panels).
- **Recorded:** `D:\QM\reports\state\owner_decisions.json` (2026-07-20).
- The previous brand doc "QuantMechanica_Design_System" exists only in the
  Obsidian vault (`G:\My Drive\QuantMechanica - Company Reference\…`) — no repo
  copy found. The vault is mid-restructure and is deliberately **not** touched
  by this rollout; when the restructure lands, point the vault page at this
  file. **This document is the canonical v2 spec until then.**

---

## 3. Surface inventory & rollout status

| Surface | File(s) | Status 2026-07-20 |
|---|---|---|
| Strategy dashboards (strategies.html, index, EA detail pages, portfolio) | `tools/strategy_farm/dashboards/render_dashboards.py` + `dashboards/style.css` | **DONE** — commit `a864bd159` |
| Cockpit v7 (freshness badge, MAINTENANCE state, Live/Frontier/Heartbeat tiles) | `tools/strategy_farm/render_cockpit.py` | **DONE** — commit `b1a09cc95` |
| DXZ trading journal | `tools/strategy_farm/dashboards/render_dxz_journal.py` | **DONE** — commit `d87d77871` |
| 06:00 morning mail + FAIL-digest/health alarm (shared palette) | `tools/strategy_farm/morning_brief.py`, `tools/strategy_farm/gmail_alarm.py` | **DONE** — commit `397289b19` (dry-run verified, no mail sent) |
| Account monitor EA panel | `framework/monitor/QM_AccountMonitor.mq5` | **DONE** — built light from day one (2026-07-20) |
| EA chart theme (light chart look) | `framework/include/QM/QM_ChartTheme.mqh` | **DONE** (include exists, compile-tested) |
| Fleet-wide chart adoption on live/factory EAs | `QM_ChartUI` → `QM_ChartTheme` migration + `QM_Branding` byte-swap fix | **PENDING** — rides the 2026-07-26 recompile wave (KS-coverage/audit bundle); do not recompile ahead of it |
| Old EA detail pages already on disk | `D:\QM\strategy_farm\dashboards\ea_QM5_*.html` | **TRANSITIONAL** — incrementally re-rendered pages carry new inline SVG P&L colors; ~2.5k unchanged pages keep old inline hexes until their data next changes (they already load the new `style.css`) |
| quantmechanica.com public surfaces | external deploy — only JSON contracts live in `public-data/` | **PENDING** — separate OWNER-visible step; this doc defines the token contract the site must consume |

---

## 4. Implementation notes (for the next agent touching a surface)

- Web surfaces consume tokens via CSS custom properties; **change values only
  in** `dashboards/style.css` and the cockpit `:root`. Never hardcode palette
  hexes in structural CSS.
- Inline SVGs (equity curves, daily bars) cannot use vars in all contexts —
  they hardcode `#1a8f4c`/`#d13438`. Keep them in sync with `--profit`/`--loss`.
- Mail is inline-CSS only (client requirement). Palette lives in
  `gmail_alarm.PALETTE`; `morning_brief.py` imports it. Key `"emerald"` now
  holds the status/profit green (name kept for compatibility); `"accent"` is
  the brand blue.
- Legacy aliases in `style.css` (`--em*`, `--qm-*`) resolve to the new tokens;
  old class names keep rendering correctly.
- Text on solid colored chips (health pill, ampel label, PROMOTED tag) uses the
  paper/white tokens — fine on the saturated status colors. Text on *tinted*
  fills (heatmap cells, swimlane) must be ink (`--text`), never `--bg`.
- Qxx-only phase labels in every surface (standing rule) — the restyle changed
  no label text.

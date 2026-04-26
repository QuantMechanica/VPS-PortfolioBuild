# QuantMechanica Brand Guide — V5 Application

Created: 2026-04-26
Owner: OWNER (brand authority), CTO (technical application), Documentation-KM (consistency)
Source of truth for brand: laptop `G:\My Drive\QuantMechanica\ClaudeDesign_Upload\01_Brand_System\` (Brand Book HTML + Brand Guidelines docx + Logo files)
Source of truth for code application: this file + `branding/brand_tokens.json`

This guide is **V5-application-focused**. The full visual brand is in the Brand Book on Drive. This file says how that brand is applied to MT5 EAs, the framework, scripts, internal dashboards, and any V5 artifact that ships with the project.

## 1. Hard Rules — Inherited Verbatim From Brand Book

These cannot be overridden by V5 work. If a V5 deliverable conflicts with one of these, fix the deliverable.

| Rule | Detail |
|---|---|
| Dark mode only | `#000000` or `#020617` (Slate-950) backgrounds. No light backgrounds anywhere. |
| `"I"` voice, never `"we"` | One person, Build in Public. Logger event payloads, dashboard copy, README — always `I`, never `we`. |
| Two fonts only | **Inter** (UI / body / headlines), **Source Code Pro** (numbers / data / code). No third font, ever. |
| Emerald as the only accent | `#10b981` for primary, `#34d399` for hover/light. No other accent colour. |
| Red only for FAIL / Loss / Danger | Never as design accent. `#ef4444` for actual error states. |
| No profit promises | Never `100% win rate`, `guaranteed`, `proven returns`. |
| No emojis in professional content | EAs, MQL5 code, framework docs, blog. (Social-media exception not applicable to V5 framework code.) |
| No stock photos / no Lambo / no money piles | Visual content is data, charts, code — nothing else. |
| No clickbait | EA names, log events, dashboard labels are all data-driven. |
| Restrained glow | Subtle emerald `box-shadow: 0 0 8px #10b981`. Never neon. |

## 2. Color Tokens

Mirrored from `Drive .../03_Website/style.css`. Machine-readable copy is `branding/brand_tokens.json`.

### Surfaces

| Token | Hex | Use |
|---|---|---|
| `--qm-bg` | `#020617` | Default background |
| `--qm-surface-0` | `#060b18` | Lower surface (footer, deep card) |
| `--qm-surface-1` | `#0f172a` | Card / panel default |
| `--qm-surface-2` | `#1e293b` | Elevated card / input |
| `--qm-surface-glass` | `rgba(15,23,42,0.6)` | Glass panel with backdrop blur |

### Borders

| Token | Value |
|---|---|
| `--qm-border` | `rgba(148,163,184,0.08)` |
| `--qm-border-strong` | `rgba(148,163,184,0.18)` |
| `--qm-border-bright` | `rgba(148,163,184,0.32)` |

### Text

| Token | Hex | Use |
|---|---|---|
| `--qm-text` | `#f8fafc` | Primary text |
| `--qm-text-dim` | `#cbd5e1` | Secondary |
| `--qm-text-muted` | `#94a3b8` | Tertiary, labels |
| `--qm-text-subtle` | `#64748b` | Captions, sub-info |
| `--qm-text-faint` | `#475569` | Disabled, footnotes |

### Brand — Emerald Family

| Token | Hex |
|---|---|
| `--em` | `#10b981` |
| `--em-l` | `#34d399` |
| `--em-d` | `#059669` |
| `--em-s` (subtle bg) | `rgba(16,185,129,0.12)` |
| `--em-glow` | `rgba(16,185,129,0.25)` |

### Status Colors

| Status | Token | Hex | Application |
|---|---|---|---|
| PASS / Profit / Live OK | `--qm-pass` | `#10b981` | Successful gates, profit P&L, healthy EA |
| PROMISING / Warning | `--qm-promising` | `#f59e0b` | YELLOW gates, cautionary state |
| FAIL / Loss / Error | `--qm-fail` | `#ef4444` | Failed gates, loss P&L, killed EA |
| DEAD / Inactive | `--qm-dead` | `#6b7280` | Retired EA, paused sleeve |
| LIVE | `--qm-live` | `#06b6d4` | Active live deployment marker |
| WARN (legacy alias) | `--qm-warn` | `#f59e0b` | Same as `--qm-promising` |

### MT5 Color Mapping

For chart objects and indicator buffers in MQL5 (which uses BGR int):

| Brand token | MQL5 `clr*` constant (closest) | Custom int (if needed) |
|---|---|---|
| `--qm-bg #020617` | `C'0x17,0x06,0x02'` (BGR) | `0x020617` (RGB) → use `RGBToColor` helper |
| `--em #10b981` | `C'0x81,0xb9,0x10'` | `clrMediumSeaGreen` is acceptable substitute |
| `--qm-fail #ef4444` | `C'0x44,0x44,0xef'` | `clrCrimson` is acceptable |
| `--qm-promising #f59e0b` | `C'0x0b,0x9e,0xf5'` | `clrOrange` is acceptable |
| `--qm-live #06b6d4` | `C'0xd4,0xb6,0x06'` | `clrDeepSkyBlue` is acceptable |
| `--qm-text #f8fafc` | `C'0xfc,0xfa,0xf8'` | `clrWhiteSmoke` is acceptable |
| `--qm-text-muted #94a3b8` | `C'0xb8,0xa3,0x94'` | `clrSlateGray` is acceptable |

`framework/include/QM_Branding.mqh` exposes these as constants so EA code never hard-codes colour ints.

## 3. Typography

| Role | Font | Weight | Size | Letter-spacing |
|---|---|---|---|---|
| Brand wordmark | Inter | 700/800 | 32px+ | -1px |
| Headlines | Inter | 700/800 | 28-72px (responsive) | -2px |
| Body | Inter | 400/500 | 13-17px | normal |
| Labels (UPPERCASE) | Inter | 500 | 11-13px | +1px tracking |
| Stat numbers | Source Code Pro | 600 | 24-72px (responsive) | -1px to -2px |
| Code / Data inline | Source Code Pro | 400/500 | 11-15px | normal |
| Timestamps | Source Code Pro | 400 | 11-13px | normal |

For MQL5 chart objects: MT5 fonts on Windows: prefer `Consolas` (mono substitute for Source Code Pro), `Segoe UI` (sans substitute for Inter). Both ship with Windows Server 2022.

## 4. Wordmark

**`Quant`** + **`Mechanica`**, no space, with optional 10×10 emerald dot 10px to the left.

- `Quant` → text colour `#f8fafc` (white-smoke)
- `Mechanica` → text colour `#10b981` (emerald)
- Dot → emerald, animated breathe on web; static in print, MT5 charts, EA logger header
- No tagline appended to wordmark unless brand-context requires it

In ASCII / log output (where colour is not available): `QuantMechanica V5` or `QM5`.

## 5. Voice — Application To V5 Artifacts

Voice rules from Brand Book applied to V5 surfaces:

### Logger output (`QM_Logger.mqh`)

JSON-line `payload.message` field always uses `"I"` — *but only when the message has narrative tone*. Pure machine events stay neutral.

```json
{"event":"ENTRY","payload":{"side":"BUY","reason":"breakout_confirmed"}}        // neutral OK
{"event":"DEINIT","payload":{"reason":2,"message":"I saw a manual stop"}}       // narrative OK
```

Never:

```json
{"event":"DEINIT","payload":{"message":"We were stopped manually"}}             // wrong, "we"
{"event":"ENTRY","payload":{"message":"This trade will print money"}}           // wrong, hype
```

### EA names

`QM5_NNNN_<slug>` is the canonical pattern (per `framework/V5_FRAMEWORK_DESIGN.md`). Slug must be data-descriptive, not promotional:

- `QM5_1001_breakout-atr` ✅
- `QM5_1001_atr-momentum-edge` ✅
- `QM5_1001_money-printer` ❌
- `QM5_1001_winner-bot` ❌

### Strategy Card titles

Same rule. Card title is the EA's economic thesis, not its sales pitch.

- `Carry Differential Regime` ✅
- `97% Win Rate Forex Master` ❌

### Dashboard / Chart copy

| Use | Don't use |
|---|---|
| `Open P/L` | `Profit Today!` |
| `Trades Today` | `Wins Today` |
| `Magic 10010000` | `Lucky Number 10010000` |
| `News mode: SKIP_DAY` | `Smart News Filter ON` |
| `Kill switch: ARMED` | `Safety: ON` |
| `Pipeline: P5b YELLOW` | `Almost there!` |

### Public copy (when V5 produces any)

`I run the V5 pipeline.` `I deploy after P10 PASS.` `I publish failures.` Never `we` even when describing automated pipeline behaviour — the operator is one person, Paperclip is the operator's tool.

## 6. Application — Where The Brand Lives In V5

| Surface | What carries the brand |
|---|---|
| EA file headers | `// QuantMechanica V5 — QM5_NNNN_<slug> — <strategy thesis line>` |
| Logger JSON-line | `payload.brand: "QM5"` baked into every event by `QM_Logger.mqh` |
| Chart objects | Colours via `QM_Branding.mqh` constants, fonts Consolas / Segoe UI |
| Per-EA chart widget | `QM_ChartUI.mqh` (header bar with wordmark, status grid, see § 7) |
| Backtest reports | Optional post-process `framework/scripts/brand_report.ps1` injects QM CSS |
| Set-file headers | Comment block includes `; QuantMechanica V5` line |
| Strategy Cards | Markdown header includes brand line |
| Decision Logs / Migration Logs | Plain markdown, brand voice in prose |
| Compile harness output | Banner line in stdout includes wordmark |
| Public web dashboard | Already covered by `Drive .../03_Website/style.css` and `WEBSITE_DASHBOARD_PAPERCLIP_STYLE.md` |

## 7. Per-EA Chart UI Spec — Pointer

The MT5 in-chart dashboard widget that every V5 EA renders is specified in `framework/V5_FRAMEWORK_DESIGN.md` under `QM_ChartUI.mqh`. This brand guide constrains:

- Colours from § 2 only
- Fonts: Segoe UI (sans), Consolas (mono); fall back to system defaults if absent
- Layout: card-grid, header / stat-tiles / status-row / log-footer
- Status badges: PASS / PROMISING / FAIL / DEAD / LIVE per § 2
- Spacing: 4px base unit (matches `--space-1` in style.css)
- Border colour: `--qm-border` (subtle), `--qm-border-strong` on hover/active
- Wordmark: top-left of header, abbreviated `QM5` if width ≤ 240px

## 8. Forbidden — Repo-Wide

Repeating the Brand Book's hard list because these surface most often in code:

- ❌ Fonts other than Inter / Source Code Pro / Consolas / Segoe UI fallbacks
- ❌ Colours not in § 2
- ❌ `"We"` in any user-facing string
- ❌ Profit promises in any string, comment, or docstring
- ❌ Emojis in `.mq5`, `.mqh`, `.ps1`, `.py`, `.md` files (this rule is enforced by `framework/scripts/build_check.ps1`)
- ❌ Stock-photo URLs in `.html` artifacts
- ❌ Light-theme CSS overrides

## 9. Brand Asset Locations

### Within this repo

- `branding/QM_BRANDING_GUIDE.md` — this file
- `branding/brand_tokens.json` — machine-readable tokens
- `framework/include/QM_Branding.mqh` — MT5 colour constants (per `framework/V5_FRAMEWORK_DESIGN.md`)
- `framework/scripts/brand_report.ps1` — backtest report styler (per framework spec)

### On Drive (read-only canonical source)

- `G:\My Drive\QuantMechanica\ClaudeDesign_Upload\01_Brand_System\Brand_Guidelines.docx` — full guidelines
- `G:\My Drive\QuantMechanica\ClaudeDesign_Upload\01_Brand_System\QuantMechanica_Brand_Book.html` — visual brand book
- `G:\My Drive\QuantMechanica\ClaudeDesign_Upload\01_Brand_System\Logo_Transparent_2000px.png` — primary logo
- `G:\My Drive\QuantMechanica\ClaudeDesign_Upload\03_Website\style.css` — full design system CSS (source of token values)
- `G:\My Drive\QuantMechanica\ClaudeDesign_Upload\04_Voice_Content\Brand_Voice_Samples.md` — voice reference
- `G:\My Drive\QuantMechanica\Company\Research\DASHBOARD_DESIGN_BRIEF.md` — dashboard pattern reference

### Drive sync rule

Brand assets live on Drive as canonical; the repo holds working copies. If Drive brand guidelines change, this guide must be updated in the same week and the change recorded in `decisions/`.

## 10. Confirmed Defaults (OWNER 2026-04-26)

1. **`framework/include/QM_Branding.mqh` auto-generated** from `brand_tokens.json` via `framework/scripts/sync_brand_tokens.ps1`. CONFIRMED. Hand-mirror is forbidden — every `QM_CLR_*` constant flows from the JSON, single-source.
2. **Logo SVG + minimum PNGs in repo `branding/assets/`** — DONE 2026-04-26 (favicon.svg, og-image.svg, logo_transparent_2000px.png, logo_black_bg_2000px.png). Mascot PNGs and YouTube banners stay on Drive.
3. **Mascot ("Quant", 9 poses) NEVER appears in V5 EA / framework / chart-UI / report surfaces.** CONFIRMED. YouTube and social only. `framework/scripts/build_check.ps1` greps for `pose_*_transparent.png` references in `framework/` and `EAs/` and blocks the build.

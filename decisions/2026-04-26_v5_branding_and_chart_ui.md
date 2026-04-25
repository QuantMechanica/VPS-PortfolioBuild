# Decision: V5 brand application + per-EA chart UI

- Date: 2026-04-26
- Status: design accepted, implementation pending Codex (continues from P0-26)
- Owner: OWNER (brand authority), CTO (technical), Documentation-KM (consistency)
- Affected docs: `branding/QM_BRANDING_GUIDE.md`, `branding/brand_tokens.json`, `framework/V5_FRAMEWORK_DESIGN.md`, `docs/ops/PHASE0_EXECUTION_BOARD.md`

## Context

OWNER asked for the V5 framework to:

1. carry QuantMechanica branding consistently across every V5 surface (EA, chart, logger, reports)
2. standardize trade management, entry, exit (so V5 EAs do not each reinvent these)
3. include a per-EA in-chart dashboard widget

The Brand Book, Voice Samples, complete style.css, and Dashboard Design Brief all exist on Drive in `ClaudeDesign_Upload/`. No invention required — V5 inherits the V4 brand 1:1 and applies it to MT5-EA-specific surfaces.

## Decision

### Brand

`branding/QM_BRANDING_GUIDE.md` is the V5-application brand guide. It restates the hard rules from the Brand Book, exposes the colour / typography / spacing tokens in MT5-applicable form (BGR ints, MT5-resident font names), and constrains where the brand lives in V5 surfaces (EA file headers, logger payloads, set-file headers, chart objects, backtest reports).

`branding/brand_tokens.json` is the machine-readable token source. `framework/scripts/sync_brand_tokens.ps1` regenerates `framework/include/QM_Branding.mqh` from this JSON whenever tokens change, so MQL5 code never hand-mirrors design values.

### Trade management modules

`framework/V5_FRAMEWORK_DESIGN.md` extended with 7 new includes:

- `QM_Branding.mqh` — colour + font constants
- `QM_OrderTypes.mqh` — typed enums for the 5 MT5 order types
- `QM_Entry.mqh` — single entry point for every trade, enforces kill-switch / news / risk / one-position-per-magic-symbol
- `QM_Exit.mqh` — single exit point, named exit-reason enum logged on every close
- `QM_StopRules.mqh` — ATR / structure / volatility / fixed-pip stop strategies
- `QM_TradeManagement.mqh` — position lifecycle (open / modify / partial / pyramiding opt-in)
- `QM_ChartUI.mqh` — in-chart per-EA dashboard widget

V5 hard rule introduced by these modules: an EA's strategy logic never calls raw `OrderSend` / `OrderModify` / `PositionClose`. It expresses intent through the framework. This is what eliminates V4's "every EA self-contained, helpers duplicated" failure mode.

### Per-EA chart UI

Specced in `framework/V5_FRAMEWORK_DESIGN.md` § QM_ChartUI.mqh:

- Header: QuantMechanica wordmark, EA name, UTC timestamp
- 6 stat tiles in two rows: Risk %, Open P/L, Today P/L, Magic, News Mode, Kill Switch
- Status row: AutoTrading state, NewsFilter state, Calendar load state
- Log footer: last major event one-liner
- Pure ChartObject API (no custom indicator buffer)
- `OnTimer` 1s refresh (not `OnTick`)
- Brand-conformant colours via `QM_Branding.mqh`
- Layout: 720×200 px panel anchored configurable corner, collapses to one-line below 720px chart width
- Tester mode: minimal rendering (header only) to avoid tester overhead

## Alternatives Considered

- **Free-form colour picking per EA / per developer.** Rejected. V4's lack of a brand-tokens layer is exactly what made every EA visually different. V5 forces brand-token-only via build_check grep for hard-coded `clr*` constants.
- **Logger-only branding (skip chart UI).** Rejected. OWNER explicitly asked for the in-chart dashboard, and the brand needs to be visible on the trading surface where humans look during live operation.
- **HTML-rendered EA dashboard via WebView (MT5 supports it).** Rejected for V5 day-1. WebView introduces a heavyweight dependency, breaks portable terminals, and over-shoots the requirement (a 6-tile status panel does not need an HTML engine).
- **Auto-generate `QM_Branding.mqh` at compile-time from CSS.** Rejected. CSS parsing in PowerShell is fragile; the `brand_tokens.json` intermediate is the right contract — both CSS and MQH are downstream consumers.
- **Mascot ("Quant") in EA chart UI.** Rejected per Brand Book § 07 — mascot is YouTube / social-media only, not framework / EA / dashboard surfaces.
- **Pyramiding as default trade-management behaviour.** Rejected. V5 default is one-position-per-magic-symbol (`QM_Entry` rejects `QM_ENTRY_REJECTED_DUPLICATE`); pyramiding is opt-in via explicit `QM_TM_AddToPosition` call. This protects against runaway position-stacking from accidental signal duplication.

## Consequences

- `branding/` folder created in repo (was not there before; this is the first repo-wide non-strategy non-process content area).
- Codex implementation order grows from 15 to 25 steps; estimated implementation time scales accordingly. The trade-management modules and ChartUI add real work but eliminate per-EA reinvention.
- `framework/scripts/build_check.ps1` gains two responsibilities: (1) grep for hard-coded `clr*` constants in EA code, (2) grep for forbidden words ("we" used as we-the-collective, profit-promise vocabulary, third-party fonts). Both block the build.
- Every V5 EA is visually consistent on every chart, every backtest report, every dashboard. This is the "brand discipline" V4 lacked.
- The chart UI doubles as live operational evidence — OWNER can glance at any T6 chart and see kill-switch state, news mode, magic, and last event without opening logs.
- `branding/brand_tokens.json` becomes a critical-path file: changes to it propagate to MQL5, CSS, dashboards, and scripts. Documentation-KM owns the change-control discipline.

## Open Items

1. Whether to copy logo SVG into `branding/assets/` so VPS can render dashboards / reports without Drive mount. Default proposed in brand guide: yes, SVG only.
2. Whether the V5 mascot rule (no mascot in framework) survives operational use — default no, OWNER may revisit if there's a strong case.
3. Whether `QM_ChartUI` rendering is also exposed as a standalone indicator (so non-V5 charts can render the brand panel for visualization). Out of scope for now.

## Sources

- `branding/QM_BRANDING_GUIDE.md`
- `branding/brand_tokens.json`
- `framework/V5_FRAMEWORK_DESIGN.md` (§ Repo Layout, § QM_Branding through QM_ChartUI, § Implementation Order)
- Drive: `ClaudeDesign_Upload/00_README.md`
- Drive: `ClaudeDesign_Upload/01_Brand_System/QuantMechanica_Brand_Book.html`
- Drive: `ClaudeDesign_Upload/03_Website/style.css`
- Drive: `ClaudeDesign_Upload/04_Voice_Content/Brand_Voice_Samples.md`
- Drive: `Company/Research/DASHBOARD_DESIGN_BRIEF.md`

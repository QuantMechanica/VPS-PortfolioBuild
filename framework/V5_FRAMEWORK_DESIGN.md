# V5 EA Framework — Design

Created: 2026-04-26
Owners: CTO + Development
Reviewer: Quality-Tech (statistics + risk), Claude Board Advisor (architecture + V5 boundary)
Implementation: Codex (laptop or VPS-CTO agent) implements the MQL5 / PowerShell against this spec.
Decision source: `decisions/2026-04-26_v5_framework_design.md`
Scope: this is the *design*. Code lives under `framework/` once Codex implements.

## Why This Document Exists

Codex's V4 framework inventory (2026-04-26) confirmed that V4 had **no shared `Company/Include` library**. Every V4 EA was self-contained, which is the root cause of three V4 failure modes that V5 must eliminate:

- duplicated magic-number arithmetic with no central registry → collisions
- duplicated risk sizing with subtle drift between EAs → unreviewable risk posture
- doc/code drift on the runner side (V2.1 runner guide referenced scripts that did not exist)

V5 ships a single shared framework that every V5 EA imports. No shared lib, no V5 EA.

## Design Principles

1. **One source of truth per concern.** Magic, risk, news, kill-switch, logger — each lives in exactly one include file. No duplication across EAs.
2. **Compile-time validation over runtime trust.** Magic registry, set-file schema, input contracts are all checked at compile / build time, not at first-tick.
3. **Evidence by construction.** Every runtime decision (entry, exit, kill) writes a structured log line. P1..P10 evidence is just log query.
4. **V5 namespace is clean.** EA prefix `QM5_`, ea_id range 1000-9999. No collision with V4 SM_XXX (which used 1-~770).
5. **Inherit V4 only where V4 was right.** Magic formula, dual risk-mode contract, markdown receipts. Everything else is rebuilt.
6. **MT5-native, no external runtime deps in the EA itself.** Helpers (compile harness, smoke runner) may use PowerShell + Python, but the EA is pure MQL5.

## Repo Layout

```
framework/
  V5_FRAMEWORK_DESIGN.md       # this file
  README.md
  CHANGELOG.md
  include/
    QM_Common.mqh              # umbrella; #include this in every EA
    QM_Logger.mqh              # structured logging
    QM_MagicResolver.mqh       # ea_id * 10000 + symbol_slot, with registry check
    QM_RiskSizer.mqh           # RISK_PERCENT / RISK_FIXED dual mode
    QM_NewsFilter.mqh          # OFF/PAUSE/SKIP_DAY/FTMO_PAUSE/5ers_PAUSE/no_news/news_only
    QM_KillSwitch.mqh          # daily-loss, portfolio-DD, manual halt
    QM_DSTAware.mqh            # DarwinexZero NY-Close GMT+2/+3 → UTC
    QM_TradeContext.mqh        # OrderSend wrappers with error classification
    QM_Errors.mqh              # named error codes + classification (SETUP_DATA_*, EA_*, BROKER_*)
    QM_Branding.mqh            # MT5 colour constants from branding/brand_tokens.json
    QM_OrderTypes.mqh          # typed wrappers for the 5 MT5 order types
    QM_Entry.mqh               # standardized entry patterns (market/limit/stop + confirmation)
    QM_Exit.mqh                # standardized exit patterns (SL/TP/trailing/BE/time/news)
    QM_StopRules.mqh           # SL/TP placement strategies (ATR / structure / fixed-pips)
    QM_TradeManagement.mqh     # position lifecycle (open/modify/close/partial/pyramiding)
    QM_ChartUI.mqh             # in-chart dashboard widget (per-EA live status panel)
  templates/
    EA_Skeleton.mq5            # minimal compilable EA
    chart_template.tpl         # default MT5 chart template for V5 EAs (QM brand)
    setfile_template.set       # the canonical .set file shape
  EAs/
    QM5_1001_<slug>/
      QM5_1001_<slug>.mq5      # one EA per folder
      sets/                    # this EA's set files
      docs/                    # this EA's strategy card + lessons
  registry/
    magic_numbers.csv          # ea_id, ea_slug, symbol_slot, symbol, magic, reserved_at
    ea_id_registry.csv         # ea_id, slug, status, owner, created_at
  scripts/
    compile_one.ps1            # compiles a single EA via metaeditor.exe
    compile_all.ps1            # iterates EAs/, summary report
    build_check.ps1            # pre-commit: compile + magic-collision + setfile-schema
    run_smoke.ps1              # P1 smoke harness wrapper around MT5 tester
    validate_setfile.ps1       # schema check on a .set file
  conventions/
    SET_FILE_FORMAT.md
    NAMING_CONVENTIONS.md
    INPUT_STANDARD.md
    LOG_SCHEMA.md
    ERROR_TAXONOMY.md
  build/                       # compile output (gitignored)
  tests/
    smoke/                     # smoke EA + set + expected-output
    unit/                      # MQL5 unit-test EAs for the includes
```

`framework/build/` is gitignored. Everything else is committed.

## Naming + ID Schema

### EA naming

- **Folder:** `framework/EAs/QM5_NNNN_<slug>/`
- **File:** `QM5_NNNN_<slug>.mq5`
- **MT5 EA name (compiled):** `QM5_NNNN_<slug>` — must be ≤ 32 chars (MT5 constraint)
- **slug:** lowercase, kebab-case, ≤ 16 chars (e.g. `breakout-atr`)

### ea_id range

| Range | Use |
|---|---|
| `1` – `999` | reserved (V4 SM_XXX namespace; do NOT reuse) |
| `1000` – `4999` | V5 production EAs (sequential allocation by Research) |
| `5000` – `8999` | V5 research / sandbox / experimental EAs |
| `9000` – `9999` | V5 framework test EAs (smoke, unit, harness) |

`ea_id` is allocated by adding a row to `framework/registry/ea_id_registry.csv` before any code is written. Allocation requires CEO + CTO sign-off.

### Set file naming

- **Pattern:** `QM5_NNNN_<SYMBOL>_<TF>_<ENV>.set`
- `<SYMBOL>` exact MT5 symbol name including `.DWX` suffix in research / backtest, stripped only at deploy packaging
- `<TF>` ∈ `{M1, M5, M15, M30, H1, H4, D1, W1, MN1}`
- `<ENV>` ∈ `{backtest, demo, shadow, live}`

Examples:
- `QM5_1001_EURUSD.DWX_H1_backtest.set`
- `QM5_1001_EURUSD_H1_live.set`

### Strategy Card naming

- `strategy-seeds/cards/QM5_NNNN_<slug>_card.md`
- One card per ea_id. The card pre-dates the code — Research writes the card, CTO approves, then ea_id is allocated.

## Magic-Number Schema

**Inherited from V4:** `magic = ea_id * 10000 + symbol_slot`

- `ea_id`: 4-digit V5 EA identifier (1000-9999)
- `symbol_slot`: 0-9999, allocated per EA per symbol; typically 0-9 used
- `magic` stays comfortably within MT5 `int` (32-bit signed)

### Registry

`framework/registry/magic_numbers.csv` columns:

```
ea_id,ea_slug,symbol_slot,symbol,magic,reserved_at,reserved_by,status
1001,breakout-atr,0,EURUSD,10010000,2026-04-26,CTO,active
1001,breakout-atr,1,GBPUSD,10010001,2026-04-26,CTO,active
```

`status` ∈ `{active, deprecated, retired}`.

### Validation

`framework/scripts/build_check.ps1` runs at every compile:

1. parse every EA's call to `QM_Magic(ea_id, symbol_slot)`
2. confirm each (ea_id, symbol_slot) pair exists in `magic_numbers.csv` with `status=active`
3. confirm no two registry rows produce the same `magic` value
4. abort build on any violation

`QM_MagicResolver.mqh` exposes:

```mql5
int  QM_Magic(int ea_id, int symbol_slot);   // computes + caches
bool QM_MagicRegistered(int ea_id, int slot); // queries baked-in registry hash
```

The registry file is hashed at compile time; the hash is baked into the EA binary so a runtime mismatch between binary and registry triggers `OnInit` abort.

## Risk Sizing — Dual Mode (KEPT from V4)

Two inputs, exactly one non-zero:

```mql5
input double RISK_PERCENT = 0.0;   // % of equity per trade, 0..5.0
input double RISK_FIXED   = 0.0;   // cash amount per trade, account currency
```

**OnInit() validation:**
- exactly one of the two > 0 → continue
- both 0 → abort with `EA_INPUT_RISK_BOTH_ZERO`
- both > 0 → abort with `EA_INPUT_RISK_BOTH_SET`

**V5 addition:** portfolio-level weighting

```mql5
input double PORTFOLIO_WEIGHT = 1.0;  // 0.0..1.0, sleeve weight in basket
```

The actual lot size becomes:

```
lot = QM_RiskSizer(RISK_PERCENT or RISK_FIXED) * PORTFOLIO_WEIGHT
```

V4 had no portfolio weight input — sleeve weighting was applied externally. V5 makes it a first-class input so deploy manifest weight propagates into the EA itself.

`QM_RiskSizer.mqh` handles symbol-specific tick value, contract size, margin requirement, currency conversion. It exposes:

```mql5
double QM_LotsForRisk(string symbol, double sl_points);
```

The EA never computes lots from raw inputs — always via `QM_LotsForRisk`.

## Set File Convention

### Format

Standard MT5 `.set` plus a mandatory header comment block:

```
;==========================================================
; QM5 Set File
; ea_id:        1001
; ea_slug:      breakout-atr
; ea_version:   v0.3.1
; set_version:  s2026-04-26-001
; symbol:       EURUSD
; timeframe:    H1
; environment:  backtest
; magic_slot:   0
; risk_mode:    PERCENT
; portfolio_weight: 1.00
; build_hash:   <set by build_check.ps1>
; author:       CTO
; date:         2026-04-26
;==========================================================
```

### Required inputs

Every set file must explicitly set every EA input — no "default" values. `validate_setfile.ps1` rejects set files that omit any input declared in the EA's `OnInit` schema export.

### Storage

- `framework/EAs/QM5_NNNN_<slug>/sets/` during research
- after P9 manifest approval, the manifest references the set by **SHA256**, not by path — so the set file is content-addressed at deploy time

## Common Includes — Module Specs

### QM_Common.mqh

Umbrella include. Every V5 EA starts with:

```mql5
#include <QM/QM_Common.mqh>
```

`QM_Common.mqh` then includes everything else. Removes the need for EAs to manage individual #includes.

### QM_Logger.mqh

- log levels: `TRACE, INFO, WARN, ERROR, FATAL`
- output: per-EA log file at `<MT5 data folder>/MQL5/Logs/QM/QM5_NNNN_<slug>.log`
- format: one JSON object per line:
  ```json
  {"ts_utc":"2026-04-26T14:23:01.234Z","ts_broker":"2026-04-26T16:23:01","level":"INFO","ea_id":1001,"slug":"breakout-atr","symbol":"EURUSD","tf":"H1","magic":10010000,"event":"ENTRY","payload":{"side":"BUY","lot":0.12,"sl":1.07523,"tp":1.08410,"reason":"breakout_confirmed"}}
  ```
- broker-time and UTC always both present
- `QM_LogEvent(level, event, payload)` is the single API
- emergency `QM_LogFatal(...)` flushes synchronously and triggers KillSwitch

### QM_MagicResolver.mqh

Spec above. Plus:

- never returns 0 (0 is reserved by MT5 for "no magic")
- collision check against runtime open positions: if a foreign magic ever conflicts, log `EA_MAGIC_COLLISION_DETECTED` and refuse to trade

### QM_RiskSizer.mqh

- `QM_LotsForRisk(symbol, sl_points)` returns lot size
- supports symbol-level overrides (e.g. WS30 typically needs cents-per-point math)
- never returns lots that exceed `SymbolInfoDouble(SYMBOL_VOLUME_MAX)` or fall below `SymbolInfoDouble(SYMBOL_VOLUME_MIN)` — clamps with `WARN`
- never sizes a trade that would exceed `KillSwitch.PerTradeRiskCap`

### QM_NewsFilter.mqh

Modes (per the canonical P8 spec + the news-compliance-variants-TBD recommendation):

```mql5
enum QM_NewsMode {
   QM_NEWS_OFF,             // no filter
   QM_NEWS_PAUSE,           // pause N min before/after
   QM_NEWS_SKIP_DAY,        // skip the whole day
   QM_NEWS_FTMO_PAUSE,      // FTMO blackout windows
   QM_NEWS_5ERS_PAUSE,      // The5ers blackout windows
   QM_NEWS_NO_NEWS,         // only trade on no-news days
   QM_NEWS_NEWS_ONLY        // only trade in news windows
};
```

- reads `D:\QM\data\news_calendar\news_calendar_2015_2025.csv` and `forex_factory_calendar_clean.csv`
- caches calendar in memory at `OnInit`
- exposes `bool QM_NewsAllowsTrade(string symbol, datetime t, QM_NewsMode mode)`
- if calendar file missing or stale → returns `false` for *all* modes except `QM_NEWS_OFF`, and logs `SETUP_DATA_MISSING` (per CLAUDE.md hard rule)
- FTMO and 5ers blackout-window definitions go into `framework/include/news_rules/ftmo.mqh` and `5ers.mqh` — separate small files because they will get tweaked as firm rules change

### QM_KillSwitch.mqh

Three independent kill paths, each can shut the EA down:

| Kill | Trigger | Action |
|---|---|---|
| `KS_DAILY_LOSS` | daily P&L below `daily_loss_halt_pct` of starting equity | close all open positions, refuse new entries until next broker day, `QM_LogFatal` |
| `KS_PORTFOLIO_DD` | portfolio-level DD signal received from external monitor (file or named pipe) | same |
| `KS_MANUAL` | presence of a halt-flag file `D:\QM\data\halt\<ea_id>.halt` | same |

`OnTick` first thing: `QM_KillSwitchCheck()`. Before any trade decision.

### QM_DSTAware.mqh

- `datetime QM_BrokerToUTC(datetime broker_time)` — applies DarwinexZero NY-Close convention (GMT+2 outside US DST, GMT+3 in US DST)
- `datetime QM_UTCToBroker(datetime utc)` — inverse
- US DST rules baked in (second Sunday of March, first Sunday of November) — no reliance on broker server clock for DST
- explicit unit tests at March / November transitions

### QM_TradeContext.mqh

- wraps `OrderSend` with classified error handling:
  - `BROKER_REQUOTE` — retry once with same SL/TP
  - `BROKER_OFF_QUOTE` — retry once after `Sleep(200)`
  - `BROKER_NOT_ENOUGH_MONEY` → `QM_LogFatal` and refuse further trades
  - `BROKER_TRADE_DISABLED` → `QM_LogError` and skip this signal
  - `BROKER_INVALID_VOLUME` → log + abort (RiskSizer must clamp pre-call)
- correlates broker error code to journal log so post-hoc audit can reconstruct the event chain

### QM_Branding.mqh

V5 brand colour constants for MQL5 chart objects, indicators, and UI elements. Sourced from `branding/brand_tokens.json` (auto-generated by `framework/scripts/sync_brand_tokens.ps1` per `branding/QM_BRANDING_GUIDE.md` § 10 default).

```mql5
// Surface
#define QM_CLR_BG          C'0x17,0x06,0x02'   // BGR of #020617
#define QM_CLR_SURFACE_1   C'0x2a,0x17,0x0f'
// Brand
#define QM_CLR_EMERALD     C'0x81,0xb9,0x10'   // #10b981
#define QM_CLR_EMERALD_LT  C'0x99,0xd3,0x34'   // #34d399
// Text
#define QM_CLR_TEXT        C'0xfc,0xfa,0xf8'
#define QM_CLR_TEXT_DIM    C'0xe1,0xd5,0xcb'
#define QM_CLR_TEXT_MUTED  C'0xb8,0xa3,0x94'
#define QM_CLR_TEXT_SUBTLE C'0x8c,0x74,0x64'
// Status
#define QM_CLR_PASS        C'0x81,0xb9,0x10'
#define QM_CLR_PROMISING   C'0x0b,0x9e,0xf5'
#define QM_CLR_FAIL        C'0x44,0x44,0xef'
#define QM_CLR_DEAD        C'0x80,0x72,0x6b'
#define QM_CLR_LIVE        C'0xd4,0xb6,0x06'
// Fonts (MT5 strings, OS-resolved)
#define QM_FONT_SANS       "Segoe UI"
#define QM_FONT_MONO       "Consolas"
```

EAs and indicators reference `QM_CLR_*` constants only; no hard-coded `clr*` ints anywhere else in V5 MQL5 code. `framework/scripts/build_check.ps1` greps for hard-coded `clr` constants in `framework/EAs/` and warns.

### QM_OrderTypes.mqh

Typed wrappers around MT5's 5 order types (`ORDER_TYPE_BUY`, `_SELL`, `_BUY_LIMIT`, `_SELL_LIMIT`, `_BUY_STOP`, `_SELL_STOP`). Removes raw int constants from EA code.

```mql5
enum QM_OrderType {
   QM_BUY,
   QM_SELL,
   QM_BUY_LIMIT,
   QM_SELL_LIMIT,
   QM_BUY_STOP,
   QM_SELL_STOP
};

bool QM_OrderTypeIsBuy(QM_OrderType t);
bool QM_OrderTypeIsLimit(QM_OrderType t);
bool QM_OrderTypeIsStop(QM_OrderType t);
ENUM_ORDER_TYPE QM_OrderTypeToMT5(QM_OrderType t);
```

### QM_Entry.mqh

Standardized entry patterns. Every V5 EA goes through `QM_Entry()` — never calls `QM_TradeContext.OrderSend` directly for entries. This guarantees:

- pre-entry kill-switch check
- pre-entry news-filter check
- pre-entry portfolio-weight enforcement
- magic-resolution
- structured log entry

```mql5
struct QM_EntryRequest {
   QM_OrderType  type;          // QM_BUY / QM_SELL / limit / stop variants
   double        price;         // 0 = market price for QM_BUY/QM_SELL
   double        sl;            // absolute price; computed via QM_StopRules
   double        tp;            // absolute price; 0 = no TP (managed by QM_Exit)
   string        reason;        // free-form, logged
   int           symbol_slot;   // for magic resolution (default 0)
   int           expiration_seconds; // for limit/stop orders, 0 = GTC
};

enum QM_EntryResult {
   QM_ENTRY_OK,
   QM_ENTRY_REJECTED_KILLSWITCH,
   QM_ENTRY_REJECTED_NEWS,
   QM_ENTRY_REJECTED_RISK,
   QM_ENTRY_REJECTED_BROKER,
   QM_ENTRY_REJECTED_DUPLICATE     // existing position with same magic+symbol
};

QM_EntryResult QM_Entry(const QM_EntryRequest &req, ulong &out_ticket);
```

V5 hard rule: an EA may have at most one open position per (magic, symbol). `QM_Entry` enforces this via `QM_ENTRY_REJECTED_DUPLICATE`. EAs that need pyramiding use `QM_TradeManagement.AddToPosition` (see below) which is explicitly opt-in.

### QM_Exit.mqh

Standardized exit patterns. Three exit triggers, all wired through `QM_Exit`:

```mql5
enum QM_ExitReason {
   QM_EXIT_TP_HIT,           // broker hit TP
   QM_EXIT_SL_HIT,           // broker hit SL
   QM_EXIT_TRAILING,         // trailing stop closed
   QM_EXIT_BREAK_EVEN,       // BE rule moved SL to entry, then hit
   QM_EXIT_TIME_STOP,        // hold-time exceeded
   QM_EXIT_NEWS_EXIT,        // news-mode forced flat
   QM_EXIT_KILLSWITCH,       // kill-switch closed
   QM_EXIT_MANUAL,           // OWNER closed via halt-flag file
   QM_EXIT_OPPOSITE_SIGNAL,  // EA strategy logic reversed
   QM_EXIT_PARTIAL           // partial close (also fires on remaining-close)
};

bool QM_Exit(ulong ticket, QM_ExitReason reason, double partial_lots = 0.0);
```

`QM_Exit` always logs `event:"EXIT"` with `payload.reason` set to the named enum. Post-trade analysis can group exits by reason to understand what's killing the EA.

### QM_StopRules.mqh

SL / TP placement strategies. Each rule is a function returning the absolute price.

```mql5
// All take symbol + side + entry price + per-strategy params.
double QM_StopFixedPips(string sym, QM_OrderType side, double entry, int sl_pips);
double QM_StopATR     (string sym, QM_OrderType side, double entry, int atr_period, double atr_mult);
double QM_StopStructure(string sym, QM_OrderType side, double entry, int lookback_bars);
double QM_StopVolatility(string sym, QM_OrderType side, double entry, int adr_days, double adr_mult);

// TP analogues
double QM_TakeFixedPips(string sym, QM_OrderType side, double entry, int tp_pips);
double QM_TakeRR       (string sym, QM_OrderType side, double entry, double sl_price, double rr);
double QM_TakeATR      (string sym, QM_OrderType side, double entry, int atr_period, double atr_mult);
```

V5 default: ATR-based SL with 1.5x multiplier on the bar before entry, 2.0R fixed TP via `QM_TakeRR`. EAs may override per-strategy.

### QM_TradeManagement.mqh

Position lifecycle. The EA's `OnTick` strategy logic doesn't call `OrderSend` / `OrderModify` / `PositionClose` directly — it expresses intent via `QM_TradeManagement` calls.

```mql5
// Lifecycle
bool QM_TM_OpenPosition(const QM_EntryRequest &req, ulong &out_ticket);
bool QM_TM_ClosePosition(ulong ticket, QM_ExitReason reason);
bool QM_TM_PartialClose(ulong ticket, double lots, QM_ExitReason reason);

// Modification
bool QM_TM_MoveSL(ulong ticket, double new_sl, string reason);
bool QM_TM_MoveTP(ulong ticket, double new_tp, string reason);
bool QM_TM_MoveToBreakEven(ulong ticket, int trigger_pips, int buffer_pips);
bool QM_TM_TrailATR(ulong ticket, int atr_period, double atr_mult);
bool QM_TM_TrailStep(ulong ticket, int trigger_pips, int step_pips);

// Pyramiding (opt-in only)
bool QM_TM_AddToPosition(ulong existing_ticket, const QM_EntryRequest &add_req);

// Inspection
int  QM_TM_OpenPositionCount(int magic);
double QM_TM_TotalExposureLots(int magic);
double QM_TM_OpenPnL(int magic);
```

V5 rule: every modify/trail call carries a `reason` string for the log. Post-mortem analysis can reconstruct exactly why each adjustment happened.

### QM_ChartUI.mqh

Per-EA in-chart dashboard widget. Renders a status panel directly on the EA's MT5 chart, branded per `branding/QM_BRANDING_GUIDE.md`.

#### Layout

```
┌─ QuantMechanica ────────── QM5_1001_breakout-atr ────── 14:23:01 UTC ─┐
│                                                                       │
│  ┌─ RISK ─────────┐ ┌─ OPEN P/L ─────┐ ┌─ TODAY ────────┐            │
│  │  0.50 %        │ │  +€127.40      │ │  +€312.10      │            │
│  │  €52.30 cap    │ │  +0.42 %       │ │  6 trades      │            │
│  └────────────────┘ └────────────────┘ └────────────────┘            │
│                                                                       │
│  ┌─ MAGIC ────────┐ ┌─ NEWS MODE ────┐ ┌─ KILL SWITCH ──┐            │
│  │  10010000      │ │  SKIP_DAY      │ │  ARMED         │            │
│  │  slot 0        │ │  [no events]   │ │  3% daily cap  │            │
│  └────────────────┘ └────────────────┘ └────────────────┘            │
│                                                                       │
│  STATUS: AutoTrading ON · NewsFilter ACTIVE · Calendar OK             │
│  LAST: 14:22:54 ENTRY BUY 0.12 @ 1.07523 reason=breakout_confirmed    │
└───────────────────────────────────────────────────────────────────────┘
```

#### MT5 Implementation

Pure `ChartObject*` API (no custom indicator buffer required):

- `OBJ_RECTANGLE` for panel + tile backgrounds (anchored top-left in chart pixels)
- `OBJ_LABEL` for every text element
- Updates on `OnTimer` (1s tick) — not `OnTick` (which would burn CPU on quiet symbols)
- All colours from `QM_Branding.mqh`
- Wordmark in header: `Quant` (white) + `Mechanica` (emerald) — two adjacent OBJ_LABELs
- Status colors per § 2 of `branding/QM_BRANDING_GUIDE.md`:
  - Risk under cap → emerald, over cap → fail
  - Today P/L positive → emerald, negative → fail, zero → muted
  - Kill switch ARMED → muted, TRIGGERED → fail
  - News mode → emerald if calendar loaded, fail if `SETUP_DATA_MISSING`

#### API

```mql5
// Called once from QM_FrameworkInit
bool QM_ChartUI_Init(int ea_id, string slug);

// Called by QM_Logger automatically when major events fire
void QM_ChartUI_OnEvent(string event, string payload_summary);

// Called by OnTimer (1s) inside QM_Common's timer handler
void QM_ChartUI_Refresh();

// Cleanup
void QM_ChartUI_Shutdown();

// Manual hide (for tester runs that don't need on-chart UI)
input bool qm_chartui_enabled = true;
```

#### Anchor + Resize

- Default anchor: top-left, 16px from chart edges
- Width: 720px (fixed) — readable on all V5 chart resolutions
- Height: 200px (fixed) — three rows of tiles + status + log row
- Below 720px chart width: collapses to a one-line status bar showing only `QM5 · Risk x.xx% · P/L ±€y.yy · KS state`
- Position configurable via input: `qm_chartui_corner = TOP_LEFT|TOP_RIGHT|BOTTOM_LEFT|BOTTOM_RIGHT`

#### Tester behaviour

- During Strategy Tester runs: `QM_ChartUI` renders only the header (compile/run smoke check), tiles update only at `OnTester` rather than each tick. No timer overhead.
- `qm_chartui_enabled = false` disables entirely (set in tester ini files for sweep runs)

### QM_Errors.mqh

Named error codes used across the framework:

```
EA_INPUT_RISK_BOTH_ZERO
EA_INPUT_RISK_BOTH_SET
EA_INPUT_PORTFOLIO_WEIGHT_OUT_OF_RANGE
EA_MAGIC_COLLISION_DETECTED
EA_MAGIC_NOT_REGISTERED
SETUP_DATA_MISSING
SETUP_DATA_MISMATCH
SETUP_DATA_STALE
KS_DAILY_LOSS, KS_PORTFOLIO_DD, KS_MANUAL
BROKER_REQUOTE, BROKER_OFF_QUOTE, BROKER_NOT_ENOUGH_MONEY,
  BROKER_TRADE_DISABLED, BROKER_INVALID_VOLUME, BROKER_OTHER
```

`QM_Errors.mqh` exposes string constants — never raw integer codes in EA code.

## EA Template (`templates/EA_Skeleton.mq5`)

Minimal compilable EA. Strategy logic is empty `// TODO: V5 strategy goes here`. Codex generates this once; every new EA copies and customizes.

Skeleton structure:

```mql5
#include <QM/QM_Common.mqh>

input int    ea_id              = 9999;     // override per EA
input int    magic_slot_offset  = 0;
input double RISK_PERCENT       = 0.5;
input double RISK_FIXED         = 0.0;
input double PORTFOLIO_WEIGHT   = 1.0;
input QM_NewsMode news_mode     = QM_NEWS_OFF;

int OnInit() {
   if(!QM_FrameworkInit(ea_id, magic_slot_offset, RISK_PERCENT, RISK_FIXED,
                        PORTFOLIO_WEIGHT, news_mode))
      return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT", "{}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
}

void OnTick() {
   if(!QM_KillSwitchCheck()) return;
   if(!QM_NewsAllowsTrade(_Symbol, TimeCurrent(), news_mode)) return;
   // TODO: V5 strategy logic
}

double OnTester() {
   return QM_DefaultObjective();   // PF, configurable per EA via input
}
```

## Compile + Smoke Harness

### compile_one.ps1

```
compile_one.ps1 -EAPath framework/EAs/QM5_1001_breakout-atr -Strict
```

- invokes `metaeditor.exe /compile:<path>.mq5 /log:<build/path>.log`
- parses log: 0 errors, 0 warnings (in Strict mode)
- validates `.ex5` size > 0 (NO_REPORT detection)
- writes summary row to `D:\QM\reports\compile\<datetime>\summary.csv`
- exit code 0 on full PASS, non-zero with reason class

### compile_all.ps1

- iterates `framework/EAs/`
- runs `compile_one` for each
- summary report under `D:\QM\reports\compile\<datetime>\`

### build_check.ps1

Pre-commit / pre-merge gate. Runs:

1. `compile_all.ps1 -Strict`
2. magic-collision check on `registry/magic_numbers.csv`
3. `validate_setfile.ps1` for every `.set` in tree
4. JSON-line schema validator on logger output (sample run)

Exit non-zero blocks the commit (Husky hook or CI step).

### run_smoke.ps1

```
run_smoke.ps1 -EAId 1001 -Symbol EURUSD -Year 2024 -Terminal T1
```

- writes a tester ini, invokes `terminal64.exe /portable /config:<ini>`
- parses HTML report, extracts trades / PF / DD / NetProfit
- writes `D:\QM\reports\smoke\QM5_1001\<datetime>\` with raw + JSON summary
- P1 PASS criteria: ≥ 20 trades, no `OnInit` failure, deterministic across two re-runs

### validate_setfile.ps1

- parses set file
- compares input list against the EA's `OnInit` exported schema (Codex extracts this at compile time and writes `framework/EAs/QM5_NNNN_<slug>/inputs.schema.json`)
- ensures header comment block is present and complete
- computes SHA256 and writes it back into the header comment

## What V5 Explicitly Does NOT Inherit From V4

- V4 EA file structure (every EA self-contained with duplicated helpers)
- V4 SM_NNN naming (V5 prefix `QM5_`)
- V4 ea_id range (V5 starts at 1000 to leave 1-999 forever as V4 namespace)
- V4 set file format (V5 mandates header comment + schema validation)
- V4 logger format (V5 uses JSON-line structured logs)
- V4 P8 hand-orchestration (V5 builds proper `QM_NewsFilter` + tooling)
- The missing `CODEX_PIPELINE_V2.1_SPEC.md / IMPACT.md / DIFF.md` sub-gate detail (per Codex 2026-04-26: those files do not exist on the laptop). V5 sub-gate detail is authored fresh once the framework can produce real distributions.

## Implementation Order (for Codex)

When this design is approved, Codex implements in strict order:

1. **`QM_Errors.mqh`** — named error codes only, no logic. Compiles in isolation.
2. **`QM_Branding.mqh`** — colour + font constants. Standalone, no dependencies. Generated by `scripts/sync_brand_tokens.ps1` from `branding/brand_tokens.json`.
3. **`QM_Logger.mqh`** — JSON-line logger. Standalone test EA in `tests/unit/log_smoke.mq5`.
4. **`QM_MagicResolver.mqh`** + `registry/magic_numbers.csv` (with one test row).
5. **`QM_RiskSizer.mqh`** — pure math, unit-testable.
6. **`QM_DSTAware.mqh`** — pure math, unit-testable, with March/November transition tests.
7. **`QM_KillSwitch.mqh`** — depends on Logger + Errors.
8. **`QM_NewsFilter.mqh`** — depends on Logger + DSTAware. Reads news CSVs from `D:\QM\data\news_calendar\`.
9. **`QM_OrderTypes.mqh`** — typed enums + helpers, no logic.
10. **`QM_TradeContext.mqh`** — depends on Logger + Errors + OrderTypes.
11. **`QM_StopRules.mqh`** — pure math, unit-testable per rule.
12. **`QM_Entry.mqh`** — depends on TradeContext + KillSwitch + NewsFilter + RiskSizer + MagicResolver.
13. **`QM_Exit.mqh`** — depends on TradeContext + Logger.
14. **`QM_TradeManagement.mqh`** — depends on Entry + Exit + StopRules.
15. **`QM_ChartUI.mqh`** — depends on Branding + Logger; rendered via ChartObject API.
16. **`QM_Common.mqh`** — umbrella include + `QM_FrameworkInit` / `QM_FrameworkShutdown` / `OnTimer` orchestration.
17. **`templates/EA_Skeleton.mq5`** — must compile clean, must run a one-tick smoke without errors, must render `QM_ChartUI` correctly.
18. **`templates/chart_template.tpl`** — MT5 chart template with QM brand colours (background, grid, candle, MA defaults).
19. **`scripts/sync_brand_tokens.ps1`** — generates `QM_Branding.mqh` from `branding/brand_tokens.json`.
20. **`scripts/compile_one.ps1`** — must compile EA_Skeleton successfully.
21. **`scripts/build_check.ps1`** — must run end-to-end on the skeleton.
22. **`scripts/run_smoke.ps1`** — must run a smoke pass on T1 with the skeleton.
23. **`scripts/brand_report.ps1`** — post-process MT5 .htm reports with QM brand CSS.
24. **`tests/smoke/`** — a smoke EA + set file + expected output, used as regression gate.
25. **Quality-Tech review** of full framework before any V5 strategy EA is built.

Each step writes its own evidence note under `D:\QM\reports\framework\<step>/`.

## Confirmed Defaults (2026-04-26)

OWNER asked for a defaults proposal; below are the binding choices. Each line is the chosen default + the alternative it overrules + the reason.

### 1. Logger output path → **per-EA file**

- Path: `<MT5 data folder>/MQL5/Logs/QM/QM5_NNNN_<slug>.log`, JSON-line, one file per EA per terminal.
- Rejected: single shared rotating file. Reason: V5 runs many EAs in parallel on T1-T5; lock contention on a shared file under tester load creates real corruption risk, and grep-by-EA is the dominant query pattern.
- Operational: a daily zero-overhead rollover script under `framework/scripts/rotate_logs.ps1` archives any log > 100 MB into `<dir>/archive/<date>/`.

### 2. `PORTFOLIO_WEIGHT` > 1.0 → **hard fail with `EA_INPUT_PORTFOLIO_WEIGHT_OUT_OF_RANGE`**

- Range: `0.0 < PORTFOLIO_WEIGHT ≤ 1.0`. Zero or negative or > 1.0 → `OnInit` returns `INIT_FAILED`.
- Rejected: clamp + warn. Reason: portfolio weight comes from the deploy manifest. A weight > 1.0 is always a manifest authoring error — silently clamping would hide the error and ship a sleeve at unintended sizing. V5's evidence-first stance prefers loud failure.

### 3. News CSV refresh → **in-place update with hash check at every `OnInit`**

- `QM_NewsFilter` reads `D:\QM\data\news_calendar\*.csv` at every `OnInit`, computes SHA256, logs the hash via `QM_LogEvent(QM_INFO, "NEWS_CALENDAR_LOADED", {hash, rows, modified_utc})`.
- Refresh process: a weekly Task-Scheduler job updates the CSVs in place from the canonical source; hash change is visible via the `OnInit` log line on next EA restart.
- Rejected: weekly cron + manifest re-deploy. Reason: every news-rule change shouldn't require redeploying every EA. The hash log gives auditable change history without operational overhead.
- Hard rule (preserved): if either CSV is missing or unreadable at `OnInit`, all news modes except `QM_NEWS_OFF` return `false` for all queries and `SETUP_DATA_MISSING` is logged. EA does not silently fall back to "no news filter".

### 4. EA per folder → **one folder per EA**

- `framework/EAs/QM5_NNNN_<slug>/` with `QM5_NNNN_<slug>.mq5`, `sets/`, `docs/`.
- Rejected: flat layout with shared `setfiles/`. Reason: per-EA grouping keeps the strategy card, set files, and lessons-learned for one sleeve in one place. Lessons-learned are the V5 mechanism for preventing V4-style waiver creep — they need to live next to the EA, not in a shared graveyard.

### 5. `OnTester` default objective → **Profit Factor**, switchable per-EA via `QM_DefaultObjective()`

- Default: `OnTester` returns `Profit Factor` for V5 day-1.
- Per-EA override: an EA can set `qm_objective = QM_OBJ_SHARPE` or `QM_OBJ_PF_NCOMP` (composite `PF * sqrt(N) * (1 - DD)`) via input.
- Rejected (as default): bare Sharpe — too sensitive to small N during early V5 testing. Rejected (as default): V5-composite — has tunable weights that drift; better as opt-in.
- Quality-Tech reviews this default after the first 5 V5 EAs reach P3 (tracked in `PIPELINE_V5_SUB_GATE_SPEC.md` § Recalibration Triggers).

### 6. Compile tool → **`metaeditor.exe`** (not `terminal64.exe /compile`)

- All `compile_one.ps1` calls invoke `metaeditor.exe /compile:<path>.mq5 /log:<build/path>.log`.
- Rejected: `terminal64.exe /compile`. Reason: `metaeditor.exe` produces a cleaner machine-parseable log (line / column / severity / code), and does not require a running terminal context. Terminal-mode compile leaves more side-effects in the data folder.
- Strict mode default in `build_check.ps1`: 0 errors, 0 warnings. Per-EA override possible via `framework/EAs/QM5_NNNN_<slug>/.compile-warnings-allowed` (a file listing tolerated warning codes), but use is logged and CEO + CTO sign-off required to add a code.

### What this unblocks

Codex can implement per § Implementation Order without further round-trip on these six. Any future override goes through a new ADR entry under `decisions/`.

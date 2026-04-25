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
  templates/
    EA_Skeleton.mq5            # minimal compilable EA
    chart_template.tpl         # default MT5 chart template for V5 EAs
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
2. **`QM_Logger.mqh`** — JSON-line logger. Standalone test EA in `tests/unit/log_smoke.mq5`.
3. **`QM_MagicResolver.mqh`** + `registry/magic_numbers.csv` (with one test row).
4. **`QM_RiskSizer.mqh`** — pure math, unit-testable.
5. **`QM_DSTAware.mqh`** — pure math, unit-testable, with March/November transition tests.
6. **`QM_KillSwitch.mqh`** — depends on Logger + Errors.
7. **`QM_NewsFilter.mqh`** — depends on Logger + DSTAware. Reads news CSVs from `D:\QM\data\news_calendar\`.
8. **`QM_TradeContext.mqh`** — depends on Logger + Errors.
9. **`QM_Common.mqh`** — umbrella include + `QM_FrameworkInit` / `QM_FrameworkShutdown` orchestration.
10. **`templates/EA_Skeleton.mq5`** — must compile clean, must run a one-tick smoke without errors.
11. **`scripts/compile_one.ps1`** — must compile EA_Skeleton successfully.
12. **`scripts/build_check.ps1`** — must run end-to-end on the skeleton.
13. **`scripts/run_smoke.ps1`** — must run a smoke pass on T1 with the skeleton.
14. **`tests/smoke/`** — a smoke EA + set file + expected output, used as regression gate.
15. **Quality-Tech review** of full framework before any V5 strategy EA is built.

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

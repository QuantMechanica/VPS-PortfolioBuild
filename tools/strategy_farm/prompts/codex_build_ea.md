# Codex EA Build Handoff

You are the Development role for QuantMechanica Option A.

Your only job: implement **one** MQL5 EA mechanically from **one** APPROVED Strategy
Card, register it in the company registries, compile it, and run the smoke test.
No improvisation, no second card, no other pipeline phase work.

## Binding Process

Read and follow these documents:

- `C:\QM\repo\framework\V5_FRAMEWORK_DESIGN.md`
- `G:\My Drive\QuantMechanica - Company Reference\03 Pipeline\P1 Build Validation.md`
- `G:\My Drive\QuantMechanica - Company Reference\06 Infrastructure\EA Framework.md`
- `G:\My Drive\QuantMechanica - Company Reference\06 Infrastructure\Risk Conventions.md`
- `G:\My Drive\QuantMechanica - Company Reference\01 Identity\Hard Rules.md`
- `G:\My Drive\QuantMechanica - Company Reference\04 Processes\Determinism Over LLM Calls.md`

Structural reference EA (use only for layout/style, NOT to copy strategy logic):

- `C:\QM\repo\framework\EAs\QM5_1006_davey-eu-day\`

Registries (must update on success):

- `C:\QM\repo\framework\registry\magic_numbers.csv`
- `C:\QM\repo\framework\registry\ea_id_registry.csv`

## Current Build Task

Task ID: `{{task_id}}`
EA ID: `{{ea_id}}`
Slug: `{{slug}}`
Card path: `{{card_path}}`
Source ID: `{{source_id}}`
Target EA directory: `{{ea_dir}}`
Build artifact target: `{{build_result_path}}`

## Hard Rules (cannot violate)

- **HR3 Model 4** — backtest config must specify Model 4 (Every Real Tick).
- **HR4 Risk Model** — both `RISK_FIXED` ($1,000 backtest) and `RISK_PERCENT` (0.5% live)
  inputs MUST exist as user-visible EA inputs. Default to RISK_FIXED in tester.
- **HR5 Magic Schema** — `magic = ea_id_int * 10000 + symbol_slot`. Collision in
  `magic_numbers.csv` = HARD ABORT. Set `blocked_reason: "magic collision <details>"`
  and stop. Never silently overwrite.
- **HR9 Enhancement Doctrine** — this is a new EA; no existing positions to protect.
  But: do NOT deviate from the card during implementation. If the card is ambiguous,
  flag it in `open_questions` and proceed with the most literal reading.
- **HR14 NO ML** — no neural networks, no `MathNN_*`, no ONNX runtime calls, no
  Python-bridge inference, no adaptive parameters (parameters mutating based on
  running PnL or recent equity), no retraining-style logic.
- **Framework architecture** — the EA MUST implement these named sections/functions
  (verifiable by `build_check.ps1`):
  - No Trade Filter (time, spread, news)
  - Trade Entry
  - Trade Management
  - Trade Close
  - News Filter Hook (callable for P8 News Impact phase)

## CANONICAL NAMING (strict — Claude review will reject on any drift)

- Directory: **`{{ea_dir}}`** — use this EXACT path. Do NOT strip the `QM5_` prefix.
  The directory name must be `QM5_<NNNN>_<slug>` (e.g. `QM5_1044_vpmacd-us-indices`),
  NOT `<NNNN>_<slug>` (e.g. `1044_vpmacd-us-indices`).
- `.mq5` file: **`{{ea_id}}_{{slug}}.mq5`** (e.g. `QM5_1044_vpmacd-us-indices.mq5`)
- `.ex5` file: same basename with `.ex5` extension after compile.
- Setfile naming: **`{{ea_id}}_{{slug}}_<SYMBOL>_<TF>_<env>.set`**
  (e.g. `QM5_1044_vpmacd-us-indices_WS30.DWX_H1_backtest.set`).

If you generate the smoke setfile manually, name it per the convention above. P2
setfiles via `gen_setfile.ps1` (see workflow step 9) inherit this pattern.

## DWX SYMBOL DISCIPLINE (strict)

- Before registering ANY symbol in `magic_numbers.csv`, verify it appears in
  `C:/QM/repo/framework/registry/dwx_symbol_matrix.csv`. The matrix is the
  full set; the broker does NOT provide tick data for anything outside it.
- **SP500.DWX is available as a Custom Symbol on T1-T5 since 2026-05-16T19:15Z**
  (OWNER-provided ticks 2018-07→2026-05, 9.4GB; evidence=`docs/ops/evidence/2026-05-16T191500Z_sp500_dwx_custom_symbol_t2_t5_rollout.md`).
  It is **backtest-only**: the broker does NOT route orders on SP500, so live
  promotion to T6 is forbidden for SP500.DWX-only EAs — that's a Board Advisor
  T6-gate concern, not yours. At build time: SP500.DWX is a valid
  `magic_numbers.csv` registration target exactly like NDX.DWX or WS30.DWX.
  Use it when the card calls for SP500/SPX/SPY.
- **Permanently unavailable** (still): `SPX500.DWX`, `SPY.DWX`, `ES.DWX`, etc.
  — these are NOT the canonical Custom Symbol name. The single available
  Custom Symbol for the S&P 500 is `SP500.DWX`. Do not invent variants.
- For US large-cap exposure, the available basket is now: **SP500.DWX**
  (S&P 500, backtest-only), **NDX.DWX** (Nasdaq 100, live-tradable), **WS30.DWX**
  (Dow 30, live-tradable).
- Other "card-stated symbol not in matrix" cases — port to nearest available
  DWX equivalent and document the choice in `open_questions`:
  - Russell 2000 / IWM → fall back to **WS30.DWX** (no Russell CFD).
  - Sector ETFs (XLK, XLF, etc.) → fall back to **NDX.DWX** or **WS30.DWX**.
  - DAX / FTSE / Nikkei → use **DE30.DWX**, **UK100.DWX**, **JP225.DWX** if
    present in the matrix (verify first).
  - Forex pairs: use exact match if present, else closest correlated pair.
  - **NEVER** register a symbol that isn't in `dwx_symbol_matrix.csv`. If no
    acceptable port exists, set `blocked_reason` and stop. No phantom symbols.

## P2 SATURATION RULE (strict — register the FULL portable basket)

**Register ALL portable symbols listed in the card's R3 PASS section, not just
the "primary" symbol.** This rule is load-bearing for pipeline throughput.

Why: `p2_baseline.py` distributes symbols across T1-T5 round-robin. Single-symbol
registration means 4 of 5 terminals sit idle during P2 — directly violating the
Mission Baseline 2026-05-09 "MT5 idle = mission-failure-signal" principle.

How to apply:

1. Read the card's `## R1-R4 Bewertung` table, specifically the R3 row.
2. R3 row narrates the portable DWX basket. With SP500.DWX now available
   (backtest-only since 2026-05-16T19:15Z), the US large-cap basket is
   **SP500.DWX (S&P 500), NDX.DWX (Nasdaq 100), WS30.DWX (Dow 30)**.
   Add **GDAXI.DWX (DAX 40), UK100.DWX (FTSE 100)** for global multi-index
   baskets. Example R3: "Available indices basket: SP500/NDX/WS30 US +
   GDAXI/UK100 EU — five major liquid country indices."
3. Register ALL four (or however many R3 names) in `magic_numbers.csv` with
   distinct symbol slots (e.g. NDX slot 0, WS30 slot 1, GDAXI slot 2, UK100 slot 3).
4. Generate a P2 setfile (via `gen_setfile.ps1` step 9) for EACH registered symbol
   at the card's primary timeframe.
5. Smoke can still run on a single symbol (smoke is bounded by design).

Exception — the card explicitly says "single-symbol baseline" or "do not expand"
in its Implementation Notes: respect that and register only the named symbol. Then
note in `open_questions`: "card forbids multi-symbol; P2 will use 1 terminal".

If the card's Implementation Notes say "primary X, expand to Y, Z in P3" (the
common pattern), interpret that as a P3 PARAMETER-SWEEP statement (different
configs per symbol), not a P2 RESTRICTION. P2 baseline still registers all
portable symbols — P3 then sweeps params per symbol on the already-built EA.

## FRAMEWORK CORSET (strict — use the modules, do not reimplement)

The V5 framework provides the entire per-tick scaffold. Your `.mq5` should be
just **5 strategy hooks + input params**. Start from
`framework/templates/EA_Skeleton.mq5` — it has all framework wiring already.

**OUTPUT SCHEMA:** Your final `build_result.json` MUST match the schema in
`C:/QM/repo/tools/strategy_farm/prompts/SCHEMAS.md` § "build_result.json".
If you add or rename a field, update SCHEMAS.md in the same change set —
otherwise the downstream codex_review step will produce false FAILs.
Touch only:

- `input` declarations for strategy-specific params
- Body of `Strategy_NoTradeFilter`, `Strategy_EntrySignal`,
  `Strategy_ManageOpenPosition`, `Strategy_ExitSignal`, `Strategy_NewsFilterHook`

Use these framework helpers — DO NOT reimplement them:

| Need                              | Use                                                                |
|-----------------------------------|--------------------------------------------------------------------|
| Closed-bar gate                   | `QM_IsNewBar()` or `QM_IsNewBar(sym, tf)`                          |
| ATR / EMA / SMA / RSI             | `QM_ATR(sym, tf, period, shift=1)` etc. (`QM_Indicators.mqh`)      |
| WMA / LWMA / SMMA / HMA           | `QM_WMA`, `QM_LWMA`, `QM_SMMA`, `QM_HMA` (all `(sym, tf, period, shift=1)`) |
| MACD                              | `QM_MACD_Main(...)`, `QM_MACD_Signal(...)`                         |
| ADX + DI                          | `QM_ADX`, `QM_ADX_PlusDI`, `QM_ADX_MinusDI`                        |
| Bollinger                         | `QM_BB_Upper / Middle / Lower`                                     |
| Stochastic                        | `QM_Stoch_K(sym, tf, k=5, d=3, slow=3)`, `QM_Stoch_D(...)`         |
| CCI                               | `QM_CCI(sym, tf, period=14)`                                       |
| Open / close / partial position   | `QM_TM_OpenPosition` / `ClosePosition` / `PartialClose`            |
| SL/TP modify, BE, trailing        | `QM_TM_MoveSL/MoveTP/MoveToBreakEven/TrailATR/TrailStep`           |
| Stop distance from ATR/structure  | `QM_StopATR / QM_StopStructure / QM_StopVolatility / QM_StopFixedPips` |
| Lot sizing from SL points         | `QM_LotsForRisk(symbol, sl_points)`                                |
| News gate                         | `QM_NewsAllowsTrade(symbol, broker_time, qm_news_mode)`            |
| Kill-switch / Friday-close        | `QM_KillSwitchCheck` / `QM_FrameworkHandleFridayClose`             |

### Optional Signal Mixins (`QM_Signals.mqh`)

Each returns `+1` / `0` / `-1` so you can compose patterns without re-doing
the indicator math. **Use when they fit. Skip for novel / structural logic
(Order Blocks, Heiken Ashi sequences, custom regime).** Include with
`#include <QM/QM_Signals.mqh>`.

| Helper                                                       | Returns                                |
|--------------------------------------------------------------|----------------------------------------|
| `QM_Sig_MA_Position(sym, tf, fast, slow, shift)`             | +1 fast>slow / -1 fast<slow / 0 equal  |
| `QM_Sig_MA_Cross(sym, tf, fast, slow, shift)`                | +1 bullish cross / -1 bearish cross    |
| `QM_Sig_Price_Above_MA(sym, tf, period, deadband_pts, shift)`| price-vs-MA with deadband              |
| `QM_Sig_Range_Breakout(sym, tf, lookback, shift)`            | +1 break above N-bar high              |
| `QM_Sig_RSI_Reversal(sym, tf, period, lo, hi, shift)`        | +1 oversold reversal up / -1 inverse   |
| `QM_Sig_ADX_Strong(sym, tf, period, threshold, shift)`       | 1 trending / 0 ranging                 |
| `QM_Sig_BB_MeanRev(sym, tf, period, devs, shift)`            | +1 below lower band / -1 above upper   |
| `QM_Sig_TurnOfMonth(broker_now, day_from_end, day_into_next)`| 1 inside ToM window                    |
| `QM_Sig_DayOfWeek(broker_now, bool day_enabled[7])`          | 1 if today enabled (Mon=0..Sun=6)      |
| `QM_Sig_Session(broker_now, start_h, end_h)`                 | 1 inside hour window (wrap-safe)       |

Composition example for a trend-pullback long:
```mql5
if(QM_Sig_MA_Position(_Symbol, PERIOD_H4, 50, 200, 1) > 0 &&
   QM_Sig_ADX_Strong(_Symbol, PERIOD_H4, 14, 25.0, 1) > 0 &&
   QM_Sig_RSI_Reversal(_Symbol, PERIOD_H1, 14, 30.0, 70.0, 1) > 0)
   { /* build LONG req */ return true; }
```

Forbidden patterns (Claude review will `REJECT_REWORK` on any):
- Per-EA `IsNewBar()` function — use `QM_IsNewBar()`
- File-scope `g_last_*_bar` / `last_checked_bar` / `iTime(...)` gating —
  this is a per-EA new-bar reimplementation even if it is named differently.
  If daily/weekly signals need closed-bar cadence, use the framework
  `QM_IsNewBar(symbol, timeframe)` overload or read fixed closed-bar shifts
  from `QM_*` helpers. Do not maintain your own timestamp gate.
- Direct `iATR / iMA / iRSI / iMACD / iADX / iBands` calls — use the `QM_*` readers
- `CopyBuffer` on raw handles — the readers do it for you
- File-scope `g_atr_handle` / `IndicatorRelease` — handles are pooled
- `CopyRates` over warmup window on every tick

## PERFORMANCE DISCIPLINE (strict — smoke runtime is bounded)

Following the Framework Corset above eliminates ~all known perf-failure
patterns. The remaining rules cover custom math the framework can't help with:

- **Bounded nested loops.** If your entry-signal call chain has nested loops
  whose product exceeds ~1000 inner ops per tick, the smoke test will time
  out. Cache the innermost terms once per new-bar instead of recomputing them
  on every outer-loop iteration.
- **Closed-bar gate** for any non-trivial computation. Wrap with
  `if(!QM_IsNewBar()) return;` so the work runs once per closed bar, not per
  tick.
- **Custom bar arrays.** If you genuinely need raw OHLC arrays (e.g. for
  custom seasonality math), call `CopyRates` ONCE inside a `QM_IsNewBar` gate
  and cache the result in file-scope variables. Never call it unconditionally
  from `OnTick`.
- **Logging discipline.** No `Print()` / INFO / DEBUG logging inside `OnTick`
  on the per-tick code path. Gate logs by `QM_IsNewBar` or rate-limit to at
  most once per broker-time hour. In particular, per-tick logging during
  Friday-close windows (21:00-23:59) produces ~16K log lines per day and is a
  smoke-runtime killer in its own right.
- **Smoke runtime budget.** A correctly-architected EA should finish a 1-year
  D1 backtest smoke in well under 10 min wall-clock. If smoke wall-time
  >10 min, that is a perf bug, not "the strategy is slow": set
  `blocked_reason: "smoke runtime infeasible — <root cause>"`, populate
  `rework_directives` with imperative file-scoped fixes, and stop.

## INTRADAY DISCIPLINE (strict — for cards with `intraday: true` or `closed_bar_cache_required: true`)

QM5_1044 (VPMACD), QM5_1046 (VWAP intraday), QM5_1050 (SMC Order Blocks) all
hit METATESTER_HUNG smoke timeouts because the EA recomputed strategy state
(EMA warmup / VWAP session / order-block list / structure pivots) on every
OnTick. MT5's Model-4 ticks fire thousands of times per bar — recomputing
N-bar-deep state per tick costs O(N × ticks_per_bar × bars_total).

**Intraday EAs MUST cache strategy state per closed bar.** Pattern:

```mq5
// File-scope cached state (advanced once per new bar)
double  g_session_vwap = 0.0;
double  g_upper_band = 0.0;
double  g_lower_band = 0.0;
datetime g_last_advanced_bar = 0;

void AdvanceState_OnNewBar()
  {
   // Called ONCE per new closed bar from OnTick (gated by QM_IsNewBar).
   // Reads the LAST closed bar's data, updates cumulative state by ONE step,
   // recomputes bands. Never loops back further than necessary.
   double close_last = iClose(_Symbol, _Period, 1);
   double volume_last = (double)iVolume(_Symbol, _Period, 1);
   g_session_vwap = /* cumulative VWAP advance — one bar's contribution */ ;
   g_upper_band  = /* close + rolling_avg_range * mult */ ;
   g_lower_band  = /* close - rolling_avg_range * mult */ ;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Called every OnTick. ONLY reads cached state + current Bid/Ask.
   // NO CopyRates loops. NO iATR/iMA recomputes (use QM_ATR(...) which
   // is handle-pooled). NO order-block detection scans.
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid > g_upper_band && /* per-tick cheap check */) {
       /* fill req → return true */
   }
   return false;
  }

void OnTick()
  {
   if(!QM_FrameworkInit_OK) return;
   // ... framework guards ...
   if(QM_IsNewBar())            // FIRST: advance closed-bar state
       AdvanceState_OnNewBar();
   // Per-tick path below — must be O(1):
   Strategy_ManageOpenPosition();  // reads cached state only
   if(Strategy_ExitSignal()) ...;
   if(Strategy_EntrySignal(req)) ...;
  }
```

**Forbidden in OnTick (per-tick path):**
- `CopyRates(_Symbol, ..., 1, N)` where N > 1
- VWAP or moving-average re-summing from session-open / N bars back
- Loop over `iClose / iHigh / iLow` for arbitrary N bars
- Order-block / pivot / structure detection that scans history
- Any `for` loop bounded by lookback length

**Allowed in OnTick (per-tick path):**
- `SymbolInfoDouble(_Symbol, SYMBOL_BID/ASK)` — single tick read
- Comparison of current tick to file-scope cached values
- `QM_*` indicator readers from `QM_Indicators.mqh` (handles pooled, copy_buffer single shift)
- Trade management via `QM_TM_*` helpers
- `if(!QM_IsNewBar()) return;` early exit to skip per-bar work

If the card carries `intraday: true` or `closed_bar_cache_required: true`
in its frontmatter, you MUST follow this pattern. If you cannot express the
strategy's edge in cached-per-bar form, set `blocked_reason: "intraday
strategy requires per-tick lookback that exceeds smoke budget — needs card
redesign"` and stop. Claude review will REJECT_REWORK if any forbidden
pattern is found inside `OnTick` (post-`QM_IsNewBar`-gate is fine).

## ONE-PASS BUILD DISCIPLINE (strict — do NOT iterate on smoke result)

Observed 2026-05-16 (QM5_1046): Codex emitted a working .mq5, ran smoke 1 which
hit OnInit-failure, then iterated — rewrote .mq5, smoke 2 deadlocked MT5
tester (init OK, test never produced trades, MT5 process at 0.3% CPU for 11 min
before being killed). The iteration converted a clean OnInit-failure into an
infinite-loop deadlock.

**You build the EA EXACTLY ONCE.** Smoke is a single non-iterative pass:

- If smoke `passed` or `zero_trades` → emit build_result JSON, exit cleanly.
  Q01 now treats `zero_trades` as a pre-fanout trade-generation failure, so the
  reviewer/router will send it to rework instead of Q02. Do not iterate inside
  this build wake; preserve the evidence honestly.
- If smoke `compile_failed` or `build_check_failed` — emit JSON with the
  failure reason in `blocked_reason`, exit. Claude review will REJECT_REWORK
  with directives. **You** do not retry the build; the next wake reads the
  rework directives from the verdict file.
- If smoke `framework_error` (tester crashed, REPORT_MISSING, OnInit-failure,
  setup data mismatch per HR8) — emit JSON with diagnostic in
  `blocked_reason`. Do NOT rewrite the .mq5 hoping the next smoke succeeds.
  Setup errors aren't strategy errors and re-running won't fix them.

**Why one-pass:** the autonomous chain (wake → build → review → enqueue) is
designed around a SINGLE build result. Multiple smoke runs per wake compound
wake duration risk (45 min ExecutionTimeLimit), risk MT5-tester deadlocks
from buggy iteration variants, and burn Codex tokens that downstream review
already accounts for. If your initial .mq5 has a bug, surfacing it in the
build_result JSON is more valuable than masking it with a hopeful rewrite.

## Workflow

1. Read `{{card_path}}` fully. Extract Entry, Exit, Stop Loss, Position Sizing,
   and Filters sections. If the card has `g0_status: APPROVED` is NOT set in the
   frontmatter — STOP and return `blocked_reason: "card not APPROVED"`.

2. Reserve an ea_id row in `framework\registry\ea_id_registry.csv` if not already
   present. Append `{{ea_id}},{{slug}}` row (preserve CSV header + line endings).

3. Compute magic_base = numeric suffix of `{{ea_id}}` × 10000. For each symbol the
   card targets (or all symbols in `framework\registry\dwx_symbol_matrix.csv` if the
   card is symbol-agnostic), reserve a slot in `magic_numbers.csv`. One row per
   `(ea_id, symbol, magic)`. HARD ABORT on collision.

3a. **Regenerate `framework\include\QM\QM_MagicResolver.mqh`** by running the
    idempotent regenerator:
    ```powershell
    python C:\QM\repo\framework\scripts\update_magic_resolver.py
    ```
    The script reads `magic_numbers.csv` + scans active EA dirs and rewrites
    the `.mqh` with the full, canonical row set + bumped `QM_MAGIC_REGISTRY_ROWS`
    + updated `QM_MAGIC_REGISTRY_SHA256`. DO NOT hand-edit the `.mqh` — past
    builds that did so silently dropped rows from other EAs (QM5_1050 build
    2026-05-16 dropped the 1047 rows → QM5_1047 smoke failed with
    `EA_MAGIC_NOT_REGISTERED`). The script is the only sanctioned mutation
    path. Run it after every CSV change, before compile.

4. Create directory `{{ea_dir}}`. Copy `framework/templates/EA_Skeleton.mq5`
   to `{{ea_dir}}/{{ea_id}}_{{slug}}.mq5` as a starting point — it has the
   framework wiring + 5 Strategy_ hook stubs pre-populated.

5. Edit `{{ea_id}}_{{slug}}.mq5` to fill the 5 Strategy_ hooks against the
   card's Entry/Exit/Stop/Sizing/Filters sections. Use ONLY the framework
   helpers listed in the Framework Corset section above — no per-EA
   `IsNewBar`, no raw `iATR / iMA / iRSI / iMACD / iADX / iBands` calls.

6. Run `pwsh -File C:\QM\repo\framework\scripts\build_check.ps1 -EALabel {{ea_id}}_{{slug}}`.
   Must pass.

7. Run `pwsh -File C:\QM\repo\framework\scripts\compile_one.ps1 -EALabel {{ea_id}}_{{slug}}`.
   Must produce `.ex5`.

8. Run exactly one smoke test on the first registered symbol. `run_smoke.ps1`
   requires a symbol and year; do not invoke it with only `-EALabel`.
   Use terminal dispatch instead of hard-coding T1, because T1-T10 may already
   be occupied by terminal-worker backtests:
   ```powershell
   pwsh -File C:\QM\repo\framework\scripts\run_smoke.ps1 `
     -EALabel {{ea_id}}_{{slug}} -Symbol <FIRST_REGISTERED_SYMBOL.DWX> `
     -Year 2024 -Terminal any -Period <CARD_TIMEFRAME> -MinTrades 1
   ```
   Must yield ≥1 trade for `smoke_result: passed`. If it yields zero trades,
   report `smoke_result: "zero_trades"` with `blocked_reason: "q01_trade_generation_zero_trades"`.

9. **Generate P2 setfiles for ALL registered symbols** using `gen_setfile.ps1`.
   For each symbol in `symbols_registered`, invoke:
   ```powershell
   pwsh -File C:\QM\repo\framework\scripts\gen_setfile.ps1 `
     -EaSlug {{ea_id}}_{{slug}} -Symbol <SYMBOL.DWX> -TF H1 -Env backtest
   ```
   This populates `framework/EAs/{{ea_id}}_{{slug}}/sets/` with one setfile per
   symbol named `{{ea_id}}_{{slug}}_<SYMBOL>_H1_backtest.set`. Without these the
   P2 phase runner exits FATAL ("no setfiles match pattern").

   If the card targets timeframes other than H1, generate one setfile per
   (symbol × TF) combination.

## Required Output Contract

Write **exactly one JSON object** to `{{build_result_path}}` AND echo it to stdout.
No prose around it. Schema:

```json
{
  "task_id": "{{task_id}}",
  "ea_id": "{{ea_id}}",
  "ea_dir": "framework/EAs/{{ea_id}}_{{slug}}",
  "mq5_path": "<absolute path>",
  "ex5_path": "<absolute path or null if compile failed>",
  "magic_base": <int>,
  "symbols_registered": ["EURUSD.DWX", "..."],
  "setfiles_generated": ["<absolute paths to .set files in sets/>"],
  "build_check_passed": true,
  "compile_succeeded": true,
  "smoke_result": "passed" | "zero_trades" | "compile_failed" | "build_check_failed" | "framework_error",
  "smoke_report_path": "<absolute path or null>",
  "blocked_reason": null,
  "open_questions": []
}
```

`ea_id` in the response MUST be the FULL card-frontmatter value (e.g.
`"QM5_1044"`), not the numeric suffix only. Same for paths.

**Each field reports ITS OWN stage's truth, independently.** A later failure
does NOT retroactively null prior successes — downstream (Claude review,
farmctl) routes work based on per-stage truth.

| Field                  | Truth source                                                                      |
|------------------------|-----------------------------------------------------------------------------------|
| `mq5_path`             | absolute path of `.mq5` if it was written to disk, else `null`                    |
| `ex5_path`             | absolute path of `.ex5` if `compile_one` emitted it, else `null`                  |
| `build_check_passed`   | `true` iff `build_check.result=PASS`, regardless of compile/smoke outcome         |
| `compile_succeeded`    | `true` iff `compile_one.result=PASS` AND `ex5_path` exists, regardless of smoke   |
| `smoke_result`         | one of `passed` / `zero_trades` / `compile_failed` / `build_check_failed` / `framework_error` |
| `smoke_report_path`    | path to `summary.json` from `run_smoke` if smoke ran at all, else `null`          |
| `setfiles_generated`   | absolute paths actually written by `gen_setfile.ps1` (could be partial)           |
| `symbols_registered`   | symbols you actually appended to `magic_numbers.csv` (could be partial)           |
| `blocked_reason`       | one-line diagnostic for the FIRST failing stage, else `null`                      |
| `open_questions`       | items the reviewer needs to know (e.g. card ambiguities resolved)                 |

Examples of correct honesty:

- `build_check` PASS + compile PASS + smoke=framework_error →
  `build_check_passed: true, compile_succeeded: true, mq5_path: "<real>",
  ex5_path: "<real>", smoke_result: "framework_error",
  blocked_reason: "framework_error <classes> ..."`
  (do NOT null mq5_path / ex5_path; downstream needs them for review)
- `build_check` PASS + compile FAIL (errors>0) + smoke skipped →
  `build_check_passed: true, compile_succeeded: false, ex5_path: null,
  smoke_result: "compile_failed", blocked_reason: "compile errors=N ..."`
- `build_check` FAIL + nothing else ran →
  `build_check_passed: false, compile_succeeded: false, mq5_path: "<real>",
  ex5_path: null, smoke_result: "build_check_failed",
  blocked_reason: "build_check.result=FAIL ..."`
  (mq5_path still real — you wrote the .mq5 before build_check ran)

`smoke_result: "zero_trades"` means the Q01 trade-generation gate failed.
Keep `build_check_passed: true` and `compile_succeeded: true` if those stages
passed, but set `blocked_reason: "q01_trade_generation_zero_trades"` so review
routes it to Codex fix or card rework before Q02 fanout.

Lying or pessimistic-pauschal-zeroing the success fields blocks the
review→backtest pipeline (Claude review reads these flags to decide
APPROVE vs REJECT_REWORK). QM5_1046 build 2026-05-16 13:13 zeroed
mq5_path / ex5_path / compile_succeeded even though all three were real,
and we lost a review cycle.

## Final Response Rule

Your final response to this prompt is **only** the JSON object. No commentary, no
markdown fences around it, no leading "Here is the result". Just the JSON. Board
Advisor will read the file at `{{build_result_path}}`.

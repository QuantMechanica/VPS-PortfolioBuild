# QM5_32007 London-Fix FX Build — Q01 PASS / CPU-Ceiling Stop

Date: 2026-08-17

Branch: `agents/board-advisor`

EA: `QM5_32007_london-fix-wm-reuters-currency-drift`

Canonical build task: `02d91117-ca8c-4bdc-9231-8b7f6ebc3677`

## Outcome

The highest-ranked unclaimed, buildable diversity candidate was an approved
M5 London-fix currency-flow card covering `EURUSD.DWX` and `GBPUSD.DWX`. It is
now a complete, compile-clean V5 Q01 build package with two fixed-$1,000-risk
backtest setfiles. The implementation is structural, evaluates only completed
price bars, trades at most once per weekday and symbol, and uses no ML,
external feed, grid, martingale, or banned raw-indicator API.

No smoke test, build-result recording, or Q02 enqueue was attempted. Five
immediate host-CPU samples exceeded the farm's explicit 97% admission ceiling,
so the mission's paced-fleet stop rule bound. The canonical build task remains
`pending`; the expected runtime build-result path was deliberately not
materialized, preventing an automatic record/enqueue transition while the
ceiling is binding.

## Selection and collision control

The first attempted energy-diversity candidate, `QM5_41052`, was rejected by
the canonical prebuild guard and was already being implemented by another
agent, so it was left untouched. A read-only approved-card/registry/build-task
scan then selected `QM5_32007` as the strongest clean FX candidate: a
time-of-day institutional-flow mechanism with about one decision per day,
instead of another index, metal, or XNG sleeve.

`farmctl build-ea` atomically created task
`02d91117-ca8c-4bdc-9231-8b7f6ebc3677` from the runtime-approved card. The
runtime card, repo-approved card, and localized EA card are byte-identical
(SHA-256 `d4eb252548ba2771baa15184c837a9a81c14745eb851f2c0920149dcef89404f`).
The existing active identities were reused without registry mutation:

| Slot | Symbol | Magic |
|---:|---|---:|
| 0 | `EURUSD.DWX` | 320070000 |
| 1 | `GBPUSD.DWX` | 320070001 |

## Mechanical implementation

- Signal: `(Close15:30 UTC - Close11:30 UTC) / Close11:30 UTC`; buy at
  `+0.15%` or above and sell at `-0.15%` or below.
- Execution: the card's `15:31` timestamp is deterministically normalized to
  the first tick of the M5 bar opening at 15:30, after the 15:30 endpoint is
  complete. This preserves the framework new-bar gate without relying on an
  exact intrabar tick; it is explicitly recorded for downstream review.
- Protection: fixed 12-pip broker SL, fixed 22-pip TP, and UTC 16:05 time exit.
- Filters: ATR(14)-based spread ceiling, UTC rollover blackout, one owned
  position, central entry-only news policy, Friday close, and kill switch.
- Data access: one bounded 80-bar `CopyRates` scan behind the framework new-bar
  gate; no per-tick history scans or raw indicator handles.
- Risk: both backtest sets seal `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the
  correct magic slot. No live setfile was created.

The approved card conflicts internally on daily loss thresholds (2.0% realized
loss versus 2.5% starting-balance drawdown) and depicts break-even/trailing
states without numerical triggers. Those ambiguous mechanics were not
invented: central V5 risk controls own the loss caps, and position management
remains the card's explicit fixed SL/TP plus time exit. The card's performance
and prop-challenge claims are treated as unverified; governed phases must
measure efficacy.

## Deterministic Q01 evidence

| Check | Result |
|---|---|
| Approved-card prebuild guard | PASS; task created from G0-approved R1–R4 card |
| Card localization | PASS; all three copies have identical SHA-256 |
| `validate_spec_doc.py` | PASS, 1/1 |
| `validate_build_guardrails.py` | PASS for MQ5 and both setfiles, no findings |
| `validate_symbol_scope.py --fail-on-leak` | `SINGLE_SYMBOL_OK`, 0 violations |
| `build_check.ps1 -Strict -EALabel ...` | PASS, 0 failures, 0 warnings |
| MetaEditor compile | PASS, 0 errors, 0 warnings; EX5 emitted |

- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260817_214423.json`.
- Compile summary:
  `D:\QM\reports\compile\20260817_214423\summary.csv`.
- Compile log:
  `C:\QM\repo\framework\build\compile\20260817_214423\QM5_32007_london-fix-wm-reuters-currency-drift.compile.log`.

| Artifact | SHA-256 |
|---|---|
| MQ5 | `3ab919caf1935041aa81810bfb8cf9e78568f954adbcc96cbc6034e239ca815c` |
| EX5 | `5456c05312c883d3fcaf6463a9e4068e68a2dbeb55eca11358f4cf10a2793747` |
| SPEC | `dc9f9a4c945a6d8e26085ed2c2d74903efcb27e8e9581b584e8ce07dd8955eb8` |
| EURUSD setfile | `cba881d802da6fb99712e7cfd5f5726e154b4a921be760738d3218dffdde20b9` |
| GBPUSD setfile | `0113f19a3c1a2366300bcef8590d520fcd7ca0b687a1bbc2193ce88260fd628a` |

## CPU-ceiling stop

At approximately `2026-08-17T21:45:23Z`, five one-second total-host-CPU
samples were `100.00%`, `98.95%`, `99.22%`, `99.51%`, and `98.75%`. Every
sample exceeded `tools/strategy_farm/terminal_worker.py`'s hard
`CPU_MAX_LOAD_PERCENT=97.0` ceiling.

The immediately preceding canonical `farmctl mt5-slots` census found active
Q02 work on five governed terminals (`T2`, `T3`, `T4`, `T5`, and `T8`), all
with reservations. The unrelated T_Live and FTMO processes were observed only
by the read-only census and were not controlled. No process, terminal,
reservation, work item, AutoTrading state, or live artifact was started,
stopped, released, or changed.

## Deterministic continuation

After a fresh sustained CPU sample is wholly below 97% and governed terminal
capacity is available:

1. verify the artifact hashes above and confirm task
   `02d91117-ca8c-4bdc-9231-8b7f6ebc3677` remains the sole build task;
2. run exactly one governed `EURUSD.DWX` M5 2024 smoke via `-Terminal any`
   using the generated fixed-risk setfile;
3. materialize the canonical build-result JSON and use `farmctl record-build`
   for the append-only Q02 handoff.

This build makes no efficacy, certification, decorrelation, or portfolio
admission claim. No T_Live file, AutoTrading setting, live/deploy manifest,
portfolio gate, or T_Live manifest was touched.

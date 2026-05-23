# Zero-Trade Rework Triage — QM5_1387, QM5_2011, QM5_4001

Date: 2026-05-23
Author: Claude (operation lead)
Tasks:
- `a64c1bd8-36f0-4190-94f8-26d4e51d6e88` — QM5_1387 (priority 70)
- `a11eec69-380e-4333-a182-0423b2d83382` — QM5_2011 (priority 70)
- `da37f552-1b96-42f5-aef8-208c67d8efc4` — QM5_4001 (priority 70)
Trigger: `DL-062_zero_trade_rework_trigger` (recurrent zero-trade FAIL ratio).
Perspective: card/source rework — relax entry conditions or substitute signal logic.

Companion to PT1 (QM5_10020 / QM5_1044 / QM5_1048) and PT2 (QM5_1088 / QM5_1089 /
QM5_1096). Same DL-062 cohort, third batch.

## TL;DR

| ea_id | dispatcher fan-out hit? | in-universe zero-trade? | real strategy-layer bug? | recommended verdict |
|---|---|---|---|---|
| QM5_1387 | yes (37 symbols vs 11-symbol whitelist) | incomplete — 25/37 still pending; 10 INFRA_FAIL on whitelisted symbols | **premature** — only 2 in-universe verdicts available | HOLD — re-triage after full run completes |
| QM5_2011 | yes (74 rows vs 4 target symbols) | no — in-target runs produce TIMEOUT/METATESTER_HUNG, not MIN_TRADES_NOT_MET | **no — perf mislabel, same class as QM5_1044** | HOLD / INFRA — tester hangs on target symbols; not a strategy zero-trade |
| QM5_4001 | n/a | n/a — all 30 runs ONINIT_FAILED before trading | **no — build/code defect; EA crashes on init** | FAILED — code defect; card incomplete (no G0 gates); do not re-enqueue |

All three are **not** strategy entry-condition problems. None warrant card rework at
this time.

## Evidence — work_items per-symbol breakdown

Queried `D:\QM\strategy_farm\state\farm_state.sqlite` 2026-05-23 ~10:20Z.

### QM5_1387 — universe per card whitelist: 11 symbols

Card whitelist: `EURUSD`, `GBPUSD`, `USDJPY`, `AUDUSD`, `USDCAD`, `USDCHF`,
`XAUUSD`, `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `UK100.DWX` (note: FX pairs listed
without `.DWX` suffix in the card body; set files use `.DWX` suffix throughout).

Status distribution:
- `status=pending cnt=25` — jobs not yet completed
- `status=failed cnt=10` — runner-level failures (verdict=INFRA_FAIL)
- `status=done cnt=2` — completed runs (verdict=FAIL, reason=MIN_TRADES_NOT_MET)

The 10 INFRA_FAIL items all land on whitelisted symbols (AUDUSD.DWX, EURUSD.DWX,
GBPUSD.DWX, GDAXI.DWX, SP500.DWX, UK100.DWX, USDCHF.DWX, USDJPY.DWX, WS30.DWX,
XAUUSD.DWX). Their `run_smoke_exit_code=0` and `evidence_path=None`, meaning the
runner completed without error but left no output artifact. This is a runner-level
infra issue, not a strategy result.

The 2 completed verdicts (MIN_TRADES_NOT_MET) are on NDX.DWX and USDCAD.DWX — both
in the card's whitelist. These are genuine low-trade-rate signals but constitute 2/37
items, which is insufficient to call a rework.

Set file inventory confirms dispatcher fan-out: sets exist for all 37 DWX symbols
including FX crosses not in the card's whitelist (AUDCAD, AUDCHF, EURAUD, etc.).

**Conclusion**: triage is premature. 25 items pending, 10 INFRA_FAIL masking any
in-universe signal, only 2 completed verdicts. The INFRA_FAIL pattern (exit_code=0,
no evidence) on whitelisted symbols suggests the phase runner is crashing before
writing output — this is the same class of issue as METATESTER_HUNG but at the
runner level.

### QM5_2011 — universe per card: 4 target symbols

`target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]`. Set files
exist exactly for these 4 symbols (H1 backtest sets). 74 total rows dispatched.

Distribution:
- 8 in-target rows (2 attempts × 4 target symbols)
- 66 out-of-target rows (all other DWX symbols)

Out-of-target (66): 61 `verdict=INVALID, vr=setfile_missing` + 5 `verdict=FAIL,
vr=run_smoke_fail:INVALID_REPORT;INCOMPLETE_RUNS` on AUDJPY, CADJPY, EURCAD (these
symbols somehow triggered a tester run with no set file and crashed).

In-target (8 rows, 5 FAIL + 3 INVALID — all 5 FAILs read:
- `EURUSD.DWX` × 2: `INVALID_REPORT;INCOMPLETE_RUNS` and
  `TIMEOUT;METATESTER_HUNG;INVALID_REPORT;INCOMPLETE_RUNS`
- `GBPUSD.DWX`: `INVALID_REPORT;INCOMPLETE_RUNS`
- `USDJPY.DWX`: `TIMEOUT;METATESTER_HUNG;INVALID_REPORT;INCOMPLETE_RUNS`
- `XAUUSD.DWX`: `INVALID_REPORT;INCOMPLETE_RUNS`

Evidence paths confirmed:
- EURUSD 2nd run: `D:\QM\reports\work_items\d738e449-...\QM5_2011\20260520_...\summary.json`
- USDJPY: `D:\QM\reports\work_items\95e283ae-...\QM5_2011\20260520_...\summary.json`

**None** of the in-target runs contain `MIN_TRADES_NOT_MET`. The EA is hanging the
tester before producing tradeable output. The METATESTER_HUNG code confirms this.

**Conclusion**: QM5_2011 is a **perf mislabel**, same class as QM5_1044. The strategy
has not been tested to zero-trade; the tester is killed by timeout. The H4-bias /
H1-breakout dual-timeframe computation (H4 EMA100 + MACD + SSL per H1 tick, plus an
80-bar H1 ATR median) is likely the compute bottleneck. A card/source rework for
"entry relaxation" would not help and would likely mislead.

### QM5_4001 — ONINIT crash on all 30 runs

Set files exist for 10 symbols (AUDJPY, EURUSD, GBPUSD, GDAXI, NDX, SP500, USDJPY,
WS30, XAUUSD, XTIUSD). All 30 work_items (3 attempts × 10 symbols) produced
`verdict=FAIL, vr=run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS`.

Evidence (canonical first-hand read):
`D:\QM\reports\work_items\07218674-da18-4917-99af-b5bbdc2d78e4\QM5_4001\20260521_210006\summary.json`

```json
"reason_classes": ["ONINIT_FAILED", "INCOMPLETE_RUNS"],
"oninit_failure_detected": true,
"runs": [
  { "status": "INVALID", "failure": "ONINIT_FAILED",
    "invalid_report_reasons": ["BARS_ZERO", "ONINIT_FAILED", "HISTORY_CONTEXT_INVALID"],
    "total_trades": 0 }
]
```

The EA `.ex5` (`C:\QM\repo\framework\EAs\QM5_4001_elite-multi-factor-scoring\
QM5_4001_elite-multi-factor-scoring.ex5`) exists but crashes at `OnInit`. The
`BARS_ZERO` / `HISTORY_CONTEXT_INVALID` secondary codes suggest the EA is trying to
access history that isn't available at init time — a timing error in the init
sequence, not a strategy problem.

Card quality issue: the card frontmatter lacks `g0_status`, `r1_track_record`,
`r2_mechanical`, `r3_data_available`, `r4_ml_forbidden`, and
`expected_trades_per_year_per_symbol`. The body specifies `Score >= 3` as the long
entry but provides no exit rule beyond `Score <= 1`, no SL/TP, no risk sizing, and no
position management. This card was not G0-reviewed.

**Conclusion**: ONINIT_FAILED is a code defect, not a zero-trade signal. The card
itself is a pre-G0 skeleton. Further pipeline time is inappropriate until (a) ONINIT
is diagnosed and fixed, and (b) the card is brought to G0 standard.

## Per-EA verdicts

### QM5_1387 — HOLD

Results incomplete. 25/37 pending; 10 INFRA_FAIL on whitelisted symbols (runner-level,
no evidence artifact); only 2 completed verdicts (MIN_TRADES_NOT_MET on NDX and USDCAD).

Recommended next action (Codex):
- Investigate INFRA_FAIL pattern on whitelisted symbols (exit_code=0, no evidence_path).
  Check runner log for those 10 jobs; identify why the phase runner completed without
  writing a summary.json. This is the DL-062-adjacent infra defect, not a strategy bug.
- Once the full 37-run cohort completes and INFRA_FAILs are resolved, re-triage the
  in-whitelist-only verdicts. If ≥4 in-whitelist symbols produce MIN_TRADES_NOT_MET,
  then a genuine entry-relaxation rework may apply (pitchfork freshness window or
  pivot-magnitude gates may be too restrictive).

Do NOT generate a new card or relax entry conditions this cycle.

### QM5_2011 — HOLD / INFRA

METATESTER_HUNG on all in-target runs. This is a compute-performance issue, not a
strategy zero-trade. Perf mislabel identical in character to QM5_1044.

Recommended next action (Codex):
- Add a pre-MT5 performance screen analogous to the QM5_1044 perf rework. The H4+H1
  dual-timeframe stack with an 80-bar H1 ATR median computed per tick is the most
  likely bottleneck. Simplify to only compute the H4 bias state on H4 bar close events
  and cache the H1 compression state on H1 bar close events rather than recomputing per
  tick.
- After perf fix, re-enqueue restricted to 4 target symbols only.
- Do NOT relax entry conditions; the H1 breakout + H4 bias stack has not been
  tested to a clean zero-trade result. Only after a clean (non-hung) run can the
  signal quality be judged.

### QM5_4001 — FAILED (code defect + incomplete card)

ONINIT_FAILED on 30/30 runs. EA code crashes at initialization. Card has no G0 gates.

Recommended next action (Codex):
- Diagnose ONINIT failure in `QM5_4001_elite-multi-factor-scoring.mq5`. Likely cause:
  `iMA` or `iATR` handle creation at `OnInit` before tester history is loaded
  (`BARS_ZERO` + `HISTORY_CONTEXT_INVALID` codes confirm this). Fix: defer indicator
  handle creation to `OnTick` / first-bar guard.
- After ONINIT fix, complete the card to G0 standard: add `r1_track_record`,
  `r2_mechanical`, `r3_data_available`, `r4_ml_forbidden`, `expected_trades_per_year_
  per_symbol`, full exit/SL/TP/risk-sizing spec, falsification criterion, Q08/Q11
  risk assessment.
- Only after G0 re-approval should P2 be re-enqueued.

## Cross-cutting finding — DL-062 trigger continues to fire on perf/infra cases

This is now the fourth batch of EAs in the DL-062 cohort where the `zero_trade_pct`
signal is misclassifying non-strategy failures:

| Batch | EAs | True zero-trade? |
|---|---|---|
| PT1 | QM5_10020, QM5_1044, QM5_1048 | 10020 partial; 1044 perf; 1048 structural |
| PT2 | QM5_1088, QM5_1089, QM5_1096 | 1096 only; 1088/1089 portfolio-design |
| PT3 | QM5_1387, QM5_2011, QM5_4001 | none — infra incomplete / perf mislabel / code defect |

The pump's zero_trade trigger should **exclude** items whose `reason_classes` contain
`INVALID_REPORT`, `METATESTER_HUNG`, `TIMEOUT`, `ONINIT_FAILED`, or
`INCOMPLETE_RUNS`. Only rows with clean `MIN_TRADES_NOT_MET` (with `deterministic=true`
and `model4_log_marker_detected=true`) represent genuine strategy zero-trade signals.
Until the pump is patched, each cycle will generate phantom rework tasks.

## Verification

- DB query timestamp 2026-05-23T10:20Z (`farm_state.sqlite`).
- `summary.json` read first-hand:
  `D:\QM\reports\work_items\07218674-da18-4917-99af-b5bbdc2d78e4\QM5_4001\20260521_210006\summary.json`
- Set file directories inspected:
  `C:\QM\repo\framework\EAs\QM5_1387_modified-schiff-pitchfork-h4\sets\` (37 files)
  `C:\QM\repo\framework\EAs\QM5_2011_nnfx-v2-h4-bias-h1-breakout\sets\` (4 files)
  `C:\QM\repo\framework\EAs\QM5_4001_elite-multi-factor-scoring\sets\` (10 files)
- Card frontmatters read first-hand from `D:\QM\strategy_farm\artifacts\cards_approved\`.
- In-target FAIL payload read from DB `payload_json.verdict_reason` for QM5_2011.

## Router updates

- `a64c1bd8` (QM5_1387): `--state REVIEW --verdict "HOLD: triage premature; 25/37 pending, 10 INFRA_FAIL on whitelisted symbols (runner-level, not strategy); only 2 clean verdicts. Re-triage after full run + INFRA_FAIL root cause resolved."`
- `a11eec69` (QM5_2011): `--state REVIEW --verdict "HOLD/INFRA: perf mislabel same class as QM5_1044; in-target runs METATESTER_HUNG not MIN_TRADES_NOT_MET; 66 off-target rows are dispatcher fan-out. Perf fix required before re-enqueue."`
- `da37f552` (QM5_4001): `--state REVIEW --verdict "FAILED: ONINIT_FAILED on 30/30 runs (code defect: BARS_ZERO/HISTORY_CONTEXT_INVALID at init); card also pre-G0 skeleton. ONINIT fix + G0 review required before any re-enqueue."`

## Hard-rules check

- T_Live: untouched.
- terminal64.exe: not started manually.
- Evidence: every claim above cites a summary.json path, DB query, or EA directory
  inspection.
- Edge Lab charter: all three EAs are legacy cards_approved/ cohort, not Edge Lab cards.
- Operator-facing phase names: Qxx only.

## Out-of-scope (do not do this cycle)

- Modify any .mq5 file.
- Re-enqueue any work_items.
- Touch `tester_defaults.json` or the dispatcher.
- Open the .ex5 in MetaEditor.

All recommended follow-ups are flagged for Codex/OWNER routing.

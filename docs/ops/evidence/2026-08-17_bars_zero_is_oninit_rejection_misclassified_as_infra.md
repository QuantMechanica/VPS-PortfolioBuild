# BARS_ZERO is an EA input rejection recorded as infrastructure (2026-08-17)

## The trigger

Three `INFRA_FAIL` rows appeared inside thirteen minutes, all in the `QM5_410xx` band on
energy symbols, while the same symbols on the same terminals had passed twenty minutes
earlier:

| EA | Symbol | Terminal | Verdict | Ended |
|---|---|---|---|---|
| QM5_41029 | XTIUSD | T1 | PASS | 08:22 |
| QM5_41034 | XTIUSD | T4 | PASS | 08:43 |
| QM5_41035 | XTIUSD | T5 | FAIL (economic) | 08:48 |
| QM5_41036 | XTIUSD | T5 | FAIL (economic) | 08:54 |
| QM5_41037 | XNGUSD | T2 | PASS | 09:06 |
| **QM5_41033** | XTIUSD | T9 | **INFRA_FAIL** | 09:22 |
| **QM5_41032** | XTIUSD | T6 | **INFRA_FAIL** | 09:24 |
| **QM5_41038** | XNGUSD | T2 | **INFRA_FAIL** | 09:35 |

`T2` passed XNGUSD at 09:06 and failed XNGUSD at 09:35 — same terminal, same symbol, 29
minutes apart. So it is neither terminal-specific nor missing symbol data.

## What the tester actually reported

The failures differ from the successes in exactly one summary field: `attempted_runs=3/3`
instead of `1/3`, with `reason_classes=["BARS_ZERO","INCOMPLETE_RUNS"]` and every run
carrying `failure=BARS_ZERO`, `exit_code=null`, `bars=null`.

The tester log settles it:

```
Symbols  XTIUSD.DWX: symbol to be synchronized
Symbols  XTIUSD.DWX: symbol synchronized, 3720 bytes of symbol info received
History  XTIUSD.DWX,Daily: history cache allocated for 1368 bars and contains
         193 bars from 2017.10.02 00:00 to 2018.06.29 00:00
Tester   tester stopped because OnInit reports incorrect input parameters
```

**The history loaded. The symbol synchronised. The EA rejected its own inputs in `OnInit`
and returned `INIT_PARAMETERS_INCORRECT`, so the run never started, the report carried zero
bars, and the classifier stamped `BARS_ZERO` → `INFRA_FAIL`.**

That is a strategy/build defect recorded as infrastructure. Three consequences:

1. **It will be requeued forever and fail identically every time.** An infra verdict invites
   a retry; an input rejection is deterministic.
2. **It pollutes the stranded-infra census.** The 1,562 deep-phase "recoverable" pairs
   (`2026-08-17_stranded_infra_recovery_wave1.md`) contain an unknown number of these.
3. **The detector that exists for this did not fire.** `oninit_failure_detected` is `false`
   in all four summaries, even though `ONINIT_FAILED` is an established reason class with
   373 occurrences since 2026-08-01. The "OnInit reports incorrect input parameters" wording
   is not matched.

## Blast radius, and the limit of what can be measured

Of 936 `INFRA_FAIL` rows with evidence since 2026-08-01, **103 carry `BARS_ZERO`**. Only
**4 still have a readable tester log**, and **all 4 are OnInit rejections** — QM5_41033,
QM5_41032, QM5_41038 and QM5_41041 (the fourth failed while this was being written).
`oninit_failure_detected` fired on **0 of 4**.

**The other 99 cannot be classified: their tester logs are gone**, purged by
`QM_StrategyFarm_ReportsLogPurge_12h`. The log is the only artifact that distinguishes an
EA input rejection from a genuine data failure, so the purge destroys the evidence needed to
tell strategy from infrastructure. That is a forensic gap in its own right.

Reason-class distribution across the same 936 rows, for context:

| Class | n |
|---|---:|
| INCOMPLETE_RUNS | 672 |
| ONINIT_FAILED | 373 |
| (none) | 263 |
| **BARS_ZERO** | **103** |
| NO_HISTORY | 92 |
| TIMEOUT | 91 |
| METATESTER_HUNG | 36 |
| LOG_BOMB | 30 |

Census: `artifacts/bars_zero_oninit_misclassification_20260817.json`.

*Method note: my first pass found 0 hits because MT5 tester logs are UTF-16 and I decoded
them as UTF-8, leaving NUL-interleaved text no pattern can match. Corrected before drawing
any conclusion.*

## What the cause is NOT — checked, not assumed

`QM5_41033`'s `OnInit` has exactly two `INIT_PARAMETERS_INCORRECT` returns: the entry gate
(`:624`) and `Strategy_NoTradeFilter()` (`:653`). Both were tested against reality:

- **Not setfile drift.** The staged setfile on T9 hashes
  `98F3A253582A26CF9094C3733F82FE9377BA59E22B66C574B1D3DDD3A5B632C5`, byte-identical to the
  repo copy.
- **Not a value mismatch.** Every input `Strategy_NoTradeFilter()` checks matches its
  required value exactly: `qm_ea_id=41033`, `qm_magic_slot_offset=0`, `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, `qm_news_temporal=0`, `qm_news_compliance=0`,
  `qm_news_mode_legacy=0`, `qm_news_stale_max_hours=336`, `qm_news_min_impact=high`,
  `qm_friday_close_enabled=true`, `qm_friday_close_hour_broker=21`,
  `strategy_entry_grace_minutes=180`, `strategy_atr_period=20`, `strategy_atr_sl_mult=3.0`,
  `strategy_max_hold_days=8`, `strategy_max_spread_points=1500`,
  `strategy_reconcile_tolerance=1.0e-10`.
- **Not `SymbolSelect` alone.** All seven EAs in the band call it once in the same position,
  passers and failers alike (`QM5_41029:589`, `QM5_41034:776`, `QM5_41037:776`,
  `QM5_41033:620`, `QM5_41032:589`, `QM5_41038:797`, `QM5_41041:614`).
- **Not the symbol or the terminal.** T2 passed and failed the same symbol 29 minutes apart;
  all terminals hold complete `Bases\Custom` coverage including `XTIUSD.DWX` and
  `XNGUSD.DWX`, and containment mode is `enabled: false`.

So the discriminator between the passing and failing members of one build wave is not
visible from configuration, staging or symbol state. Establishing it needs EA-level
debugging with an instrumented `OnInit` — implementation work, dispatched rather than
guessed at.

## Actions

1. Codex task filed: instrument `OnInit` to report *which* predicate rejects, fix the four
   EAs, and close the detector gap so this class lands as `ONINIT_FAILED` rather than
   `BARS_ZERO`/`INFRA_FAIL`.
2. **P1 wave scaling is gated on this.** Cause before quantity: until the classifier
   separates input rejections from data failures, an unknown share of the 1,562 "recoverable"
   pairs are deterministic rejections, and requeueing them manufactures identical failures.
   Wave 1 (five Q07 canaries) stands; Wave 2 waits.
3. The four affected rows must **not** be requeued as infra.

## Evidence

- `artifacts/bars_zero_oninit_misclassification_20260817.json`
- `D:\QM\reports\work_items\058c59e8-…\QM5_41033\20260817_092133\raw\run_01\20260817.log`
- Summaries for QM5_41032 / 41033 / 41038 / 41041 under their work-item report roots
- `framework/EAs/QM5_41033_wti-flow-dom/QM5_41033_wti-flow-dom.mq5:620,624,653` and
  `Strategy_NoTradeFilter` at `:458-487`

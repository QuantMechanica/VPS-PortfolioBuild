# QM5_20219 USDJPY/NZDUSD FX cointegration Q02 handoff

Date: 2026-08-05
Branch: agents/board-advisor
Status: Q01 PASS; one logical-basket Q02 work item PENDING

## Outcome

QM5_20219_usdjpy-nzdusd is a new, dedicated, low-frequency D1 FX
cointegration basket. It was selected as the first unbuilt pair after the
already-mechanized ranks 34 through 39 in the frozen sign-aware 66-pair scan.
The EA, binary, two RISK_FIXED backtest setfiles, Strategy Card, deterministic
registry rows, magic resolver, and basket manifest are committed on this
branch.

Q02 work item 5eb61981-472e-4f08-82c0-53fbec77d6c8 was enqueued at
2026-08-05T06:22:21Z for logical symbol
QM5_20219_USDJPY_NZDUSD_COINTEGRATION_D1. It was pending and unclaimed at
handoff. The physical USDJPY.DWX host setfile was deliberately skipped with
reason basket_manifest_logical_setfile_preferred.

## Anchor triage

- QM5_12532 has canonical Q02 PASS and later Q05 FAIL.
- QM5_12533 has canonical Q02 PASS and later Q04 FAIL.
- Neither anchor has an open Q02 ONINIT or NO_HISTORY blocker, so no anchor
  repair or duplicate requeue was warranted.

## Selection and source boundary

The deterministic scan command was:

    python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges

USDJPY/NZDUSD is sign-aware rank 40 of 66:

| Measure | Frozen value |
|---|---:|
| DEV net Sharpe | 0.12191561234631561 |
| OOS net Sharpe | 0.05091758006605608 |
| OOS return | 0.5798657681076694% |
| OOS state changes | 14 |
| DEV beta | -0.7823029792857074 |
| Half-life | 206.28130086271622 D1 bars |

Exact-pair card, EA, registry, and unordered traded-symbol manifest checks
found no prior dedicated USDJPY/NZDUSD fixed-beta D1 sleeve. The method is
bounded to the OWNER-ratified Tier-A extraction of Ernest Chan's pair-trading
examples in strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md.
Chan supplies the mechanical method, not a pair-specific performance claim.

The near-zero OOS score, approximately 206-bar half-life, and inferred cadence
of roughly three completed packages per year per symbol are adverse evidence.
The binding Q02 floor remains five trades per year per symbol. A terminal
frequency or economic failure retires this sleeve; it does not authorize a
filter, beta refit, or parameter rescue.

## Implementation contract

- Host and first traded leg: USDJPY.DWX, D1.
- Companion and second traded leg: NZDUSD.DWX.
- Fixed residual: ln(USDJPY) - (-0.782302979) * ln(NZDUSD).
- Entry: absolute z-score greater than 2.0 using a strictly prior 60-bar
  residual window.
- Exit: absolute z-score below 0.5; both legs also have 2.0 ATR(20) stops.
- Negative beta makes the long-spread package long both instruments and the
  short-spread package short both instruments.
- Partial entries and orphaned legs are flattened atomically.
- Backtest risk is RISK_FIXED=1000, RISK_PERCENT=0, PORTFOLIO_WEIGHT=1.
- The basket is residual-neutral only; it retains USD, JPY, NZD, carry, and
  broad risk-sentiment exposure.

## Q01 evidence

- Strict compile: PASS, zero errors, zero warnings.
- Strict build check: PASS, zero failures, zero warnings.
- Build report:
  D:\QM\reports\framework\21\build_check_20260805_060126.json
- Compile summary:
  D:\QM\reports\compile\20260805_055944\summary.csv
- Strategy Card schema lint: PASS on draft, approved, and EA-local copies.
- Spec validation: PASS.
- Symbol scope: BASKET_OK with zero violations.
- Basket manifest regression: 38 passed.
- Magic resolver regression: 4 passed.
- Magic rows: USDJPY.DWX slot 0 / 202190000 and NZDUSD.DWX slot 1 /
  202190001.
- Manual smoke or backtest run: none.

## Q02 enqueue and fleet safety

The guarded enqueue used tools/strategy_farm/sweep_enqueue_built_eas.py with
the exact EA filter. Canonical lock contention was never bypassed or removed.
The successful acquisition occurred on attempt 874 of the final paced wait,
after 372 earlier busy observations. Factory load at successful acquisition
was 3 of the 7-terminal ceiling: T1, T4, and T8. The post-enqueue scan was also
3 of 7. The maximum explicitly sampled load before enqueue was 6 of 7, so the
CPU ceiling was not reached.

The queue had 1,576 pending rows against its separate 7,000-row queue ceiling.
Exactly one priority-track logical item was inserted. No dispatch tick,
terminal reservation, tester launch, T_Live action, or AutoTrading action was
performed.

## Commit chain

- efcddb103: source-backed G0 approval and research decision.
- f82280060: deterministic EA-ID allocation and initial setfiles.
- 42f235275: compiled binary, final setfile hashes, magic rows, and resolver.
- 68f5698ce: EA source, spec, manifest, cards, and regression test.

No portfolio admission/contribution gate and no T_Live manifest was changed.

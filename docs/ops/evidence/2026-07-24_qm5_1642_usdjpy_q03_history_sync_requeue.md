# QM5_1642 USDJPY Q03 auxiliary-history repair

- UTC: `2026-07-24T10:36:52+00:00`
- Branch: `agents/board-advisor`
- Mission unit: priority-2 diverse-instrument funnel recovery
- EA: `QM5_1642_aa-xasset-xmom-third`
- Strategy: structural D1 cross-sectional momentum, monthly rebalance
- Symbol / phase: `USDJPY.DWX` / Q03
- Reopened work item: `7d431c31-0183-4783-a60f-2ac06a26baeb`
- Coordination task: `00afa47b-c7f9-483b-9407-220fce6c0ad1`

## Selection

The unclaimed build backlog had no eligible diversity-first card: QM5_1459
requires an unavailable lumber series, QM5_1457 requires unapproved Treasury /
ETF inputs, QM5_20061 is another index sleeve, and the only forex build
(QM5_20062) was already claimed by the Claude pump.

QM5_1642 is an approved, source-backed, non-ML cross-asset sleeve with about
12 decisions per year per symbol. Its USDJPY instance had already passed Q02
and was blocked from the Q04 funnel only by Q03 infrastructure.

## Diagnosis

The latest Q03 summary is:

`D:\QM\reports\work_items\7d431c31-0183-4783-a60f-2ac06a26baeb\QM5_1642\20260724_101532\summary.json`

It records four non-OK attempts, `BARS_ZERO;INCOMPLETE_RUNS`, and
`oninit_failure_detected=false`. The run-04 terminal journal shows that the
USDJPY test and EA initialized successfully, then the EA's auxiliary
cross-asset history failed:

```text
USDJPY.DWX,Daily: testing ... started with inputs
successfully initialized
NDX.DWX: history synchronization error
automatical testing finished
```

This is the shared-history synchronization transient, not a strategy verdict.
The identical build and setfile produced a deterministic Q02 PASS on T9:

`D:\QM\reports\work_items\756d3ea8-756d-4edb-a278-99304c5fcba5\QM5_1642\20260723_142921\summary.json`

That run recorded 27 trades over 2018-07-02 through 2022-12-31 (about six per
year) with PF 1.72, clearing the binding five-trades-per-year floor.

Evidence-bound and current SHA-256 values match:

- MQ5: `7aecf540726e4647a7e91ff68933eca35c1478a769c32b5209a53533319d0893`
- EX5: `8e9d5a3904da0f8db251ca082cbc493b0a1b64b784fa63af11623c2bea673ffa`
- USDJPY RISK_FIXED setfile: `53754e6076594a859077eb2609eed42e2ae2db87590cab69f529ad8ff51d2e0f`

No rebuild or strategy change was warranted. Contemporaneous QM5_1642 Q03
siblings also returned the same empty-report class on T1 and T2:
`320045bb-4924-45fd-982f-4bac3c790e07` (SP500) and
`b8f2f3dd-20ad-4cec-9ee6-a3e983d4cac1` (XTIUSD).

## Resolution

Under `BEGIN IMMEDIATE`, the existing USDJPY Q03 row was reopened in place as
`pending`; no duplicate work item was inserted. Verdict, evidence, claim, and
stale runtime/classification fields were cleared. The payload now:

- marks the sleeve `priority_track=true`;
- preserves the failed evidence and known-good Q02 lineage;
- steers the retry away from T1, T2, and T3 through `avoid_terminals`.

The completed coordination task records the exclusive claim and handoff. The
pre-change database backup is:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_1642_usdjpy_q03_repair_20260724T103337Z.sqlite`

At the handoff preflight, six factory MetaTester processes were active, below
the paced-fleet ceiling of seven. No backtest was launched manually. T_Live,
AutoTrading, portfolio gates, and deploy manifests were not touched. The farm
pipeline remains the sole judge of the retried Q03 result.

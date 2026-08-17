# A Q07 seed that collapses to zero while its siblings run is a broken run, not a strategy result

## Context: the fix worked, and it opened a new blind spot

`08c4aaed5` corrected Q07's classification of healthy low-trade seeds — the wrapper's exit code
is 1 for an economically valid `MIN_TRADES_NOT_MET`, so it was never a tester-health proxy. The
new predicate keys on per-run `status`/`exit_code`, `oninit_failure_detected`,
`log_bomb_detected`, and preserves every fail-closed path. Reviewed and approved: all four
demanded controls present by name, 49 tests passing, and the two affected rows reclassified from
stored evidence with `attempt_count=0` — no re-runs.

Reclassifying `INFRA_FAIL` → `FAIL` is the right direction. But it introduced the mirror-image
blind spot, and one row has already gone through it.

## The two rows are not the same case, and I had conflated them

| Row | seeds (trades) | reading |
|---|---|---|
| `e317cb4a` QM5_1077 / XAUUSD | `[0, 0, 0, 0, 0]` | **uniformly zero** — a genuine no-signal result. Correctly FAIL. |
| `b37c01d6` QM5_1116 / EURJPY | `[602, 612, **0**, 612, 607]` | four healthy seeds at PF 1.04–1.11, one at zero |

The seed perturbs **only `qm_rng_seed`**. It cannot take ~610 trades to 0. That single zero is a
broken run.

My earlier write-up quoted `min_trades_required=45` from QM5_1077's summary and treated it as the
Q07 floor. **Q07 has its own `MIN_TRADES` = 20**; the two floors are different, the reclassification
correctly uses 20, and my document conflated them. Corrected here.

## Why the predicate cannot see it — and why that is not the predicate's fault

The broken seed's summary reports, on every axis available:

```
result=FAIL   reason_classes=['MIN_TRADES_NOT_MET']   min_trades_required=45
runs[0].status=OK   runs[0].exit_code=0
oninit_failure_detected=False   log_bomb_detected=False   deterministic=True
```

Healthy by every signal the tester exposes. So a tester-health predicate must call it healthy,
and it then falls through to `seed_trades_below_floor` — **failing the whole pair on an
implausible zero instead of re-running the one anomalous seed.**

The information that betrays it is not in the seed's own summary. It is in the **comparison with
its siblings**, which no per-seed check can reach.

## Population scan: six rows, five still ahead of it

All 266 Q07 aggregates on disk, matching `min seed trades == 0` while `median >= 45`:

```
QM5_20004  NDX.DWX      [56, 54, 54, 0, 53]        1 zero
QM5_20105  CADJPY.DWX   [80, 79, 76, 79, 0]        1 zero
QM5_13013  NDX.DWX      [0, 61, 60, 61, 0]         2 zeros
QM5_1116   EURJPY.DWX   [602, 612, 0, 612, 607]    1 zero   <- already reclassified to FAIL
QM5_9573   NDX.DWX      [68, 67, 67, 0, 0]         2 zeros
QM5_11177  XAUUSD.DWX   [271, 274, 273, 0, 0]      2 zeros  <- clearest case
```

**QM5_11177 is the cleanest evidence**: three seeds at ~272 trades and two at exactly 0. Five of
the six are still stored `INVALID`, so they would follow `b37c01d6` if the sweep continued.

## What this trades for what

| | before `08c4aaed5` | after |
|---|---|---|
| blind spot | **over-inclusive** — every low-trade seed INVALID | **under-inclusive** — an outlier zero becomes an economic FAIL |
| cost | wasted retries on deterministic outcomes | a pair loses its remaining pipeline on a broken run |

Still a net improvement, and the old behaviour was worse — hence approved. But the second failure
mode is the more expensive one per occurrence: a wasted retry costs one dispatch, while a wrong
FAIL costs the pair everything downstream.

## The guard, and the test that defines it

Dispatched as `268d88ed` (priority 95). The requirement is stated relative to siblings rather than
as an absolute threshold, and **the contrast is the test**:

- QM5_1077 `[0,0,0,0,0]` must stay **FAIL** — uniform zero is a real answer.
- QM5_1116 `[602,612,0,612,607]` must **not** be a plain FAIL.

A guard that cannot separate those two is the wrong guard, so both are required as tests before
the predicate is written.

Disposition of a suspect seed must be explicit and fail-closed — re-run that seed, or return
INVALID with a reason naming the outlier (`seed_zero_trades_outlier:seed=99:median=607`). It must
**not** silently drop the seed and grade on the remaining four: that would let a broken run
*improve* a verdict, which is worse than either existing failure mode.

The five unreclassified rows hold their `INVALID` state until the guard lands.

## The cause is worth one investigation

A seed producing no trades while siblings produce hundreds is either a seeded-setfile generation
fault or a silent tester failure. The decisive check is cheap: compare the seeded harsh setfile for
a zero seed against a sibling's. **If they differ in anything beyond `qm_rng_seed`, that is the
answer and it is a generator bug** — which would connect this to today's exponent finding, where a
single mis-serialised value silently changed EA behaviour. Requested on QM5_11177, where two of
five seeds are exactly zero.

## Evidence

- `08c4aaed5` — the approved fix; `framework/scripts/q07_multiseed.py:631-673` (`_tester_health_invalid_reason`), `:678-698` (`evaluate_seeds`)
- `framework/scripts/tests/test_q05_q07_verdicts.py` — the four controls, 49 tests passing
- `D:\QM\reports\work_items\b37c01d6…\QM5_1116\Q07\EURJPY_DWX\aggregate.json` and the five per-seed summaries
- 266 Q07 aggregates scanned for the outlier pattern
- related: `2026-08-17_q07_low_trades_misclassified_as_infra.md`,
  `2026-08-17_P3_verdict_class_pass_and_gate_coverage.md`

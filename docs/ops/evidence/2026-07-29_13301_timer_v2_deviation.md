# QM5_13301 timer-v2 deviation after session-gap catch-up

Date: 2026-07-29
Work item: `8ac4c99e-6c0d-4263-af55-785920a129e7`
Execution verdict: **Q02 done/PASS**
Deviation verdict: **tick-only cascade collapsed; preregistered fidelity bound FAIL**

## Scope and safety

This is a backtest-instrument measurement, not a live deployment. Live remains
one gated EA per symbol/chart with native `OnTick`. The timer variant is not
authorized for T_Live.

The OWNER-selected rerun executed as one exact, hash-bound T6 work item while
the autonomous Factory remained intentionally OFF. T5, T3 and T_Live were
excluded; the existing T_Live process was neither stopped nor changed;
AutoTrading was not touched. The controller held the global Factory mutation
lock from pre-run snapshot through worker completion.

The first two controller attempts stopped before a claim because the canonical
worker's repo package root was absent from its import path. Both left the DB and
work item byte-identical. The corrected third attempt ran one T6 tester and
finished `done/PASS`, worker exit 0.

## Immutable execution identity

| role | path / identity | SHA-256 |
|---|---|---|
| fixed timer-v2 MQ5 | `framework/EAs/QM5_13301_timer-measurement/QM5_13301_timer-measurement.mq5` | `d44de4ff09e73f496b14e3223aeb974fa6c01840d6b998bed168d6a9de1d742d` |
| staged/deployed timer-v2 EX5 | `D:/QM/strategy_farm/artifacts/ex5_staging/13301_timer_v2_49aeb2bc/timer_1s/QM5_13301_timer-measurement.ex5` | `999702d2ac8885ad60de991a0bd31b979a0a1bbbf37f52a5c64f15da3bdf0a86` |
| timer-v2 set | `QM5_13301_timer-measurement_GDAXI.DWX_M5_backtest.set` | `da10a694fea366887fa7bd4bfbcdb20e9f95f98a4e39d2d16ddec4f65b974325` |
| timer-v2 native report | work item run `20260729_103347`, Model 4, 2018-07-02 through 2025-12-31 | `362013531fb96b9deeb5ff5e501877344696b5d976dc0edac43f520e41df9fea` |
| unchanged tick-reference EX5 | work item `efc84bc7-8e44-4cb0-8e05-a03ed24d8f7d`, run `20260728_192704` | `3f3deac97d4819bf030bcf3e5153bc21f439a6aedb0ca430b3967fcbb236c625` |
| tick native report | same reference run and window | `47d884c7171b748ab31d636a0de80d3de7f7fb29c410227cb70257fc8276b3df` |
| harvested timer-v2 stream | `q08_trades_13301_GDAXI_DWX.timer_v2.jsonl`, 551 rows | `2b27c8773fdf34ecc7e4eae5226705a67102c2113efacc22b9077f137f39cff6` |

The harvested stream's `(entry_time, exit_time, volume)` multiset matches the
timer native report exactly. Native reports are used for economics because they
include entry- and exit-side commission and reconcile to their displayed total
net profit to the cent.

Operational evidence:

- pre-run SQLite snapshot:
  `qm13301_t6_pre_oneshot_20260729_103339Z.sqlite`, SHA-256
  `c48f5c048c5ddbb436b4130e28d76b342aed46fd187001d7cc5ed182dae076d0`;
- run receipt:
  `qm13301_t6_oneshot_receipt_20260729_103339Z.json`, SHA-256
  `fabd8b0348eccd540e51bdabd1bf2898fd10fd92ca9afae8cf51afb494ac2387`;
- evidence-harvest recovery receipt:
  `qm13301_t6_harvest_recovery_20260729_103339Z.json`, SHA-256
  `d5a986966b939505d1fff9665e4cca5ce8ed269a21d3d4d8fcef2c52e759672a`;
- reproducible comparison:
  `timer_v2_deviation_analysis_v3.json`, SHA-256
  `1471bdf5d72540f172b9fa922af5e9749463a0e069f334cd6efb2195b849abaf`.
- completed-hold release: the exact
  `ISOLATED_T6_ONE_SHOT_REQUIRED` hold was released only after the row reached
  `done/PASS`, while Factory OFF remained asserted; the pre-release snapshot
  `qm13301_completed_hold_pre_release_20260729_110051Z.sqlite` has SHA-256
  `30632fe02b835e1f6b5dac5fb0bffe2750305785749e9c66fda9cd83aa76c21d`.
  The hash-bound receipt is
  `docs/ops/evidence/2026-07-29_qm13301_completed_hold_release.json`.

The run receipt records a harvest false-negative: the fresh run rewrote the
stream during the worker window but produced byte-identical content to the
preflight file. The corrected recovery path authenticated the original receipt,
its post-run logical DB hash, the unchanged Factory-OFF hash and zero T1-T10
processes before atomically publishing that exact stream. It did not rerun or
mutate the work item.

## Trade decomposition

The principal defect is closed: timer-v2 restores every tick-reference entry.

| measure | timer-v1 | timer-v2 | change |
|---|---:|---:|---:|
| tick-reference trades | 551 | 551 | 0 |
| timer trades | 282 | 551 | **+269** |
| exact rows | 137 | 436 | +299 |
| same-entry/same-volume non-exact | 145 | 115 | -30 |
| different entry | 0 | 0 | 0 |
| timer-only | 0 | 0 | 0 |
| tick-only / missing in timer | **269** | **0** | **-269** |
| entry-identity rate | 51.18% | **100.00%** | +48.82 pp |

Timer-v2's 115 non-exact rows split further:

| timer-v2 class | rows | share of 551 |
|---|---:|---:|
| exact entry, exit, volume and net | 436 | 79.13% |
| same entry/volume/exit timestamp, different net | 26 | 4.72% |
| same entry/volume, shifted exit timestamp | 89 | 16.15% |
| different entry / extra / missing | 0 / 0 / 0 | 0% |

Thus the prior one-position cascade is gone. The residual is an exit-execution
fidelity error, not an entry-selection or trade-availability error.

## Residual location

Among the 89 actually shifted exits:

| statistic | timer-v2 |
|---|---:|
| median absolute shift | **5 s** |
| p90 absolute shift | **32 s** |
| maximum absolute shift | **82,163 s** (22:49:23) |
| ≤1 s / ≤5 s / ≤10 s | 18 / 46 / 60 |
| ≤30 s / ≤60 s | 79 / 86 |
| >60 s / >1 h | 3 / 2 |
| timer earlier / later | 88 / 1 |
| exits crossing a calendar date | 1 |
| timer exits at 20:55 report time | 57 |

The residual remains strongly session-boundary-clustered: 57/89 timer exits
occur at 20:55 report time. The three largest discrepancies are:

| entry report time | tick exit | timer exit | shift | net delta |
|---|---|---|---:|---:|
| 2020-04-22 11:39:09 | 2020-04-23 19:44:25 | 2020-04-22 20:55:02 | -82,163 s | -$496.58 |
| 2020-07-15 13:21:22 | 2020-07-15 16:07:25 | 2020-07-15 18:59:53 | +10,348 s | -$339.71 |
| 2025-09-01 11:32:00 | 2025-09-01 20:57:38 | 2025-09-01 20:55:26 | -132 s | -$17.55 |

Report timestamps are normalized to a common epoch solely for subtraction; the
differences do not depend on a timezone interpretation. The maximum is now an
early timer exit rather than a missing-trade cascade, but it remains a material
single-trade deviation.

## Economic deviation

The rolling metric uses the preregistered 60-calendar-day definition with the
start date counted as day one (`start + 59 days`, inclusive) on native-report
round trips.

| measure | gated tick | timer-v2 | absolute delta | relative delta |
|---|---:|---:|---:|---:|
| trades | 551 | 551 | 0 | 0.000% |
| native-report net | $72,892.18 | $72,006.23 | -$885.95 | **-1.215%** |
| med60 | 1.76274% | 1.74563% | -0.01711 pp | **-0.971%** |
| \|worst day\| | 1.85303% | 1.85303% | 0.00000 pp | 0.000% |
| wDD p90 | 5.01877% | 5.00948% | -0.00929 pp | **-0.185%** |
| FUND_SCORE | 0.351229 | 0.348465 | -0.002764 | **-0.787%** |

All economic components remain within the preregistered ±10% band and the timer
introduces no worse single-day loss. The report-level PF is 1.35 tick versus
1.34 timer-v2.

## Preregistered-bound decision

| criterion | result |
|---|---|
| every economic component within ±10% | **PASS** |
| no worse single-day loss | **PASS** |
| identical entries; no timer-only or tick-only trades | **PASS** |
| deviations only simple shifted exits | **FAIL** — 26 same-timestamp net changes |
| median absolute exit shift ≤1 s | **FAIL** — measured 5 s |

The complete preregistered bound therefore **fails**, despite the economically
small aggregate error and the successful elimination of all 269 missing trades.
There is no silent agent acceptance. The existing OWNER lock for FTMO slot 2 =
**QM5_13108**, not QM5_13301, remains unchanged.

For any future research-only joint instrument that nevertheless simulates 13301
on a one-second timer, the measured error bar is: net -1.215%, med60 -0.971%,
FUND_SCORE -0.787%, with 16.15% shifted exits and two >1-hour outliers. Live
decisions continue to reference the gated per-symbol EA, never this instrument.

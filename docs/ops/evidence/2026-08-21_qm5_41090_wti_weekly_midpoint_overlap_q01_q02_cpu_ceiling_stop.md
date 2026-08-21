# QM5_41090 WTI weekly midpoint overlap Q01 and Q02 CPU-ceiling stop

Date: 2026-08-21

Branch: `agents/board-advisor`

EA: `QM5_41090_wti-wmid-overlap-mom`

Outcome: `Q01 PASS`; `Q02 NOT_ENQUEUED_CPU_CEILING`

## New structural energy sleeve

`QM5_41090` is a low-frequency, symmetric WTI continuation strategy on exact
`XTIUSD.DWX` D1. At the first tradable D1 bar of a new Monday-anchored broker
week, it reconstructs the high/low packages of the two immediately completed
consecutive weeks, requiring three to five unique sessions in each.

The ranges must share a strictly positive price interval. The EA buys only
when the newest arithmetic high/low midpoint is strictly higher and sells only
when it is strictly lower. Equal midpoints, touch-only or disjoint ranges,
malformed history, or late attachment consume the week flat. The completed
weekly packages' opens and closes never enter signal eligibility or direction.

Each accepted position has one frozen `3.5 * ATR(20,D1)` hard stop, no target,
one durable attempt per week, and a normal next-week exit with ten-day stale
repair. This is direct crude-oil auction-state exposure outside the certified
XAU/SP500/NDX/XNG book. Carrier and mechanic are a diversification hypothesis;
Q09 alone may establish realized portfolio correlation.

## Governance, novelty, and build trail

Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, supplies the
peer-reviewed own-price continuation lineage and explicitly includes WTI
futures. The exact weekly midpoint/overlap proxy is disclosed as an untested
QM translation; no source return or continuous-CFD equivalence transfers.

| Artifact | Commit / evidence |
|---|---|
| governed source approval | `1cd9eafe8` |
| bounded source extraction | `2a07d20bc` |
| deterministic EA-ID reservation | `baca6a1bf` |
| G0-approved card | `84da6d784` |
| slot-zero magic and resolver | `0417c441f` |
| implementation and Q01 build | `2143db94d` |
| strict compile summary | `D:/QM/reports/compile/20260821_120607/summary.csv` |
| strict build report | `D:/QM/reports/framework/21/build_check_20260821_120607.json` |
| static P1 report | `D:/QM/reports/pipeline/QM5_41090/P1/P1_QM5_41090_result.json` |

The canonical pre-allocation duplicate check was clean across 4,579 registry
identities and 625 cards. Manual family review separated this mechanic from
`QM5_41089` endpoint migration—which requires both endpoints to move together
and can accept disjoint ranges—and from WTI outside-settlement, close-location,
WR4, range-breakout, and completed-close return-path identities. The new rule
requires overlap, classifies only arithmetic high/low centers, and permits one
endpoint to move against the midpoint direction.

## Q01 evidence

- card schema/prohibited-ML lint: PASS;
- G0 card and approved-card build guard: PASS;
- deterministic reference suite: 12 tests PASS, including open/close exclusion,
  three-to-five-session packages, label equivalence, year boundaries, strict
  overlap, midpoint direction/equality, durable attempts, and lifecycle repair;
- strict MetaEditor compile: PASS, 0 errors and 0 warnings;
- strict V5 build check: PASS, 0 failures and two non-fatal card-discovery
  warnings; the explicit card lint passed independently;
- static P1 validation: PASS;
- MQ5 SHA-256:
  `3CE14A194ACAF47C536CE3A81A7D41EAC398DA0BFB561D294199C211AB2D8452`;
- EX5 SHA-256:
  `74E21FA158807136FB784930014F504FC1EE21E335855C7A883BB91540B14292`;
- setfile byte SHA-256:
  `2653D3D1BB61ADE7967AC69952E4D6456B2995F37D9F498820BE9E5841BE9932`;
- normalized set build hash:
  `8f241de5ef45aa7c506e4485fa5a77405ca17d74076f06cf08e081656718aac0`.

The sole preset is an exact D1 backtest set with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF, and Friday close
OFF. No manual tester or smoke backtest ran.

## Q02 target reconciliation

The canonical read-only target query returned zero work items. The exact
target-only, non-mutating preview selected one fresh baseline and no stranded
row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41090 --symbols XTIUSD.DWX --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

No `--apply` invocation was made.

## Binding capacity stop

At `2026-08-21T12:07:26Z`, canonical read-only `farmctl mt5-slots` inventory
reported seven active governed research terminals—`T2` through `T8`—at the
paced terminal ceiling of seven, with zero duplicate terminal workers and
zero orphaned terminal processes. The separate T_Live and FTMO processes were
observed only so they could be excluded; neither was accessed or changed.

Five whole-host CPU samples then remained at 100 percent, above the 97 percent
hard ceiling:

| Sample UTC | CPU |
|---|---:|
| `2026-08-21T12:08:35.2590000Z` | 100% |
| `2026-08-21T12:08:39.2980000Z` | 100% |
| `2026-08-21T12:08:43.3150000Z` | 100% |
| `2026-08-21T12:08:47.3310000Z` | 100% |
| `2026-08-21T12:08:51.3410000Z` | 100% |

The mission's CPU-ceiling stop rule therefore bound. Q02 was not enqueued,
dispatched, reserved, or run. No terminal was controlled and no work-item
state was mutated.

## Safe handoff

After CPU is freshly below 97 percent and governed terminal occupancy is
below seven, repeat the exact target query, target-only preview, and capacity
preflight before using the same target-only command with `--apply`. Do not
broaden the sweep.

Q02 must retire this identity on zero trades, fewer than five completed
positions per full post-warm-up year, nonpositive governed economics, or any
label/anchor/high-low/overlap/midpoint/attempt/lifecycle defect. It may not be
rescued by accepting equality or non-overlap, adding an open/close or current-
week gate, reversing the side, or tuning the hold.

This record does not authorize AutoTrading, `T_Live`, live/demo/shadow/stress/
optimization presets, deploy or T_Live manifest changes, portfolio-gate
changes, portfolio admission, a decorrelation claim, or a correlation waiver.

Machine-readable evidence:
`artifacts/qm5_41090_q02_cpu_ceiling_20260821T120851Z_board_advisor.json`.

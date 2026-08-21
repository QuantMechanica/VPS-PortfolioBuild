# QM5_41089 WTI weekly range migration Q01 and Q02 CPU-ceiling stop

Date: 2026-08-21

Branch: `agents/board-advisor`

EA: `QM5_41089_wti-wrange-migrate-mom`

Outcome: `Q01 PASS`; `Q02 NOT_ENQUEUED_CPU_CEILING`

## New structural energy sleeve

`QM5_41089` is a low-frequency, symmetric WTI continuation strategy on exact
`XTIUSD.DWX` D1. At the first tradable bar of a new Monday-anchored broker
week, it reconstructs the two immediately preceding consecutive completed
weeks, each with three to five unique sessions. It buys only when the newest
completed week's aggregate high and low are both strictly higher than its
parent's; it sells only when both are strictly lower. Equality at either
endpoint, inside/outside geometry, mixed migration, malformed history, or a
late restart consumes the week flat.

Each accepted position has one frozen `3.5 * ATR(20,D1)` hard stop, no target,
one persisted attempt per week, and a normal next-week exit with ten-day stale
repair. This is direct crude-oil auction-range exposure outside the certified
XAU/SP500/NDX/XNG book. Carrier and mechanic are a diversification hypothesis
only; Q09 alone may establish realized portfolio correlation.

## Governance, novelty, and build trail

Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, supplies the
peer-reviewed own-price continuation lineage and explicitly includes WTI
futures. The exact two-week range-endpoint migration proxy is disclosed as an
untested QM mechanization; no source return or continuous-CFD equivalence
transfers.

| Artifact | Commit / evidence |
|---|---|
| governed source approval | `801e20b8e` |
| bounded source extraction | `dd28629d1` |
| deterministic EA-ID reservation | `c3ce76c12` |
| G0-approved card | `bb1252ccb` |
| slot-zero magic and resolver | `283a30a22` |
| implementation and Q01 build | `502ffd26a` |
| strict compile summary | `D:/QM/reports/compile/20260821_111448/summary.csv` |
| strict build report | `D:/QM/reports/framework/21/build_check_20260821_111518.json` |
| static P1 report | `D:/QM/reports/pipeline/QM5_41089/P1/P1_QM5_41089_result.json` |

The canonical pre-allocation duplicate check was clean across 4,578 registry
identities, 625 cards, and zero vault nodes. Manual family review separated
this mechanic from WTI outside-settlement, close-location, WR4, NR7/inside/
opening-range breakout, completed-close return-path, and H4 high/low-star
identities, and from the certified XNG cumulative-RSI2 pullback.

## Q01 evidence

- card schema/prohibited-ML lint: PASS;
- G0 card lint and approved-card build guard: PASS;
- numbered SPEC validation: PASS;
- symbol scope: `SINGLE_SYMBOL_OK`, zero violations;
- deterministic reference suite: 11 tests PASS;
- strict MetaEditor compile: PASS, 0 errors, 0 warnings;
- strict V5 build check: PASS, 0 failures and two non-fatal known card-
  discovery warnings; the explicit card lints passed independently;
- static P1 validation: PASS;
- MQ5 SHA-256:
  `C2A05CE1981CE566FCE9DCFFE52C280CB0B7813BF82736B0A152C0692B0F2E0D`;
- EX5 SHA-256:
  `B721A05369B2324E225BDB34B4DA4533651268311D6992FD56D949B543D7AE40`;
- setfile byte SHA-256:
  `47B05CEBB920EE57866C0F7CF8D8E742BDD28DFC57F72E8FED61C035D683F261`;
- normalized set build hash:
  `28331434b2e5d3c4534f88528987e58f833f50579d24d419ed26117468a27bf9`;
- strict build-report SHA-256:
  `0D847B27265FACB1ADF662362934EF9E3585F86D4E2201F7630EAF74EC9D1B2E`;
- static P1-report SHA-256:
  `EB5EC718A55066308D6742039F4E6A3217AB3845AFA5D46A4E0AE53DDCC60969`.

The sole preset is a D1 backtest set with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF, and Friday close
OFF. No manual tester or smoke backtest ran.

## Q02 target reconciliation

The canonical read-only target query returned zero work items. The exact
target-only, non-mutating preview selected one fresh baseline and no stranded
row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41089 --symbols XTIUSD.DWX --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
part3 deferred: promoted=0 kept=0
priority_track items: 1
```

No `--apply` invocation was made.

## Binding capacity stop

At `2026-08-21T11:16:54Z`, canonical read-only `farmctl mt5-slots` inventory
reported six active governed research terminals—`T2`, `T3`, `T4`, `T6`,
`T8`, and `T10`—below the paced terminal ceiling of seven. It reported zero
duplicate terminal workers and zero orphaned terminal processes. The separate
T_Live and FTMO processes were observed only so they could be excluded;
neither was accessed or changed.

Five whole-host CPU samples then reached the 97 percent hard ceiling:

| Sample UTC | CPU |
|---|---:|
| `2026-08-21T11:17:13.1350000Z` | 100% |
| `2026-08-21T11:17:17.1440000Z` | 100% |
| `2026-08-21T11:17:21.1480000Z` | 97% |
| `2026-08-21T11:17:25.1530000Z` | 97% |
| `2026-08-21T11:17:29.1540000Z` | 96% |

The mission's CPU-ceiling stop rule therefore bound. Q02 was not enqueued,
dispatched, reserved, or run. No terminal was controlled and no work-item
state was mutated.

## Safe handoff

After CPU is freshly below 97 percent and governed terminal occupancy remains
below seven, repeat the exact target query, target-only preview, and capacity
preflight before using the same target-only command with `--apply`. Do not
broaden the sweep.

Q02 must retire this identity on zero trades, fewer than five completed
positions per full post-warm-up year, nonpositive governed economics, or any
label/anchor/OHLC/range-state/attempt/lifecycle defect. This record does not
authorize AutoTrading, T_Live, deploy/T_Live manifest changes, portfolio-gate
changes, portfolio admission, a decorrelation claim, or a correlation waiver.

Machine-readable evidence:
`artifacts/qm5_41089_q02_cpu_ceiling_20260821T111729Z_board_advisor.json`.

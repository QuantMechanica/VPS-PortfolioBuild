# QM5_41087 WTI weekly WR4 Q01 PASS and Q02 enqueue

Date: 2026-08-21

Branch: `agents/board-advisor`

EA: `QM5_41087_wti-wr4-close-mom`

Outcome: `Q01 PASS`; `Q02 ENQUEUED_PENDING`

## New structural energy exposure

`QM5_41087` is a low-frequency, symmetric WTI continuation strategy on exact
`XTIUSD.DWX` D1. At the first tradable bar of a new Monday-anchored broker
week, it reconstructs the four immediately preceding consecutive completed
weeks, each with three to five sessions.

The newest completed week must have a full high-low range strictly greater
than each of the three older ranges. It buys only when that week's own
open-to-close log body is positive and its close-location value is strictly
above `0.75`. It sells only when the body is negative and close location is
strictly below `0.25`. Range ties, threshold equality, invalid history, body/
location disagreement, and late attachment consume the week flat.

The position has a frozen `3.5 * ATR(20,D1)` stop, no target, one attempt per
week, and a normal next-week exit with ten-calendar-day repair. This is direct
crude-oil repricing exposure, mechanically distinct from the book's index,
metal, and XNG oscillator logic. Different exposure is a diversification
hypothesis only; Q09 alone may establish realized correlation.

## Source and governance trail

Moskowitz, Ooi, and Pedersen (2012), `Time Series Momentum`, supplies
peer-reviewed own-return-continuation evidence and explicitly includes WTI
futures. Toby Crabel's 1990 trading book supplies the range-expansion lineage.
The exact weekly WR4/body/CLV conjunction is explicitly disclosed as an
untested QM mechanization; no source return or CFD equivalence transfers.

| Artifact | Commit / evidence |
|---|---|
| governed source approval | `40d5669ac` |
| deterministic EA-ID reservation | `3a6d5930f` |
| G0-approved card | `506065180` |
| slot-zero magic allocation and resolver | `87b2cbaeb` |
| governed fixed-risk setfile | `b7c80f7d8` (shared factory artifact auto-commit) |
| implementation and Q01 build | `7616e193e` |
| strict compile summary | `D:/QM/reports/compile/20260821_085956/summary.csv` |
| strict build report | `D:/QM/reports/framework/21/build_check_20260821_085956.json` |
| static P1 report | `D:/QM/reports/pipeline/QM5_41087/P1/P1_QM5_41087_result.json` |

The canonical pre-allocation duplicate check returned CLEAN across 4,574
registry rows, 625 cards, and zero vault nodes. Manual family review separated
this mechanic from two-week WTI close-location momentum, outside-week
settlement, NR7/inside-week breakouts, current-week opening range, and the
certified XNG cumulative-RSI2 pullback.

## Q01 evidence

- card schema/prohibited-ML lint: PASS;
- G0 card lint: PASS;
- approved-card build prerequisite guard: PASS;
- numbered SPEC validation: PASS;
- symbol scope: `SINGLE_SYMBOL_OK`;
- deterministic reference suite: 10 tests PASS;
- strict MetaEditor compile: PASS, 0 errors, 0 warnings;
- targeted strict V5 build check: PASS, 0 failures, with two non-fatal card
  discovery warnings because the checker does not recurse into the approved
  card directory; the explicit card and G0 lints passed independently;
- static P1 validation: PASS;
- MQ5 SHA-256:
  `90C5989F424FAB3E644F8C37B6494D048F00F3C38E94543C20F1AAF8BA8ECD0B`;
- EX5 SHA-256:
  `CCCE6D9F05CF5D174840D5343F909E7040059E449C150F3C453B36E92C3B092D`;
- setfile SHA-256:
  `D1BAA3A92039CE9BE8C8FB223F31B3CF822774D41311E9447E15E79AA1D21B17`;
- strict build-report SHA-256:
  `9FA016C00B639D2ECD50EE65216CF200C94E7B8187C29FBF8257F01DFB5E3428`;
- static P1-report SHA-256:
  `FD7F48968AF330FA33F307B676FE03052FF70AB1BD47B21BBAEDFF1B2A67BC0A`.

The sole preset is a D1 backtest set with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF, and Friday close
OFF. No manual tester or smoke backtest ran.

## Q02 capacity preflight and enqueue

Initial target-only reconciliation found zero existing work items. The
non-mutating canonical preview selected exactly one fresh baseline item and no
stranded item.

At `2026-08-21T09:03:06Z`, canonical `farmctl mt5-slots` inventory reported
five active governed research terminals—`T2`, `T3`, `T4`, `T6`, and `T8`—
below the paced ceiling of seven. It reported no duplicate terminal workers
and no orphaned terminal processes. The separate T_Live and FTMO processes
were observed only so they could be excluded; neither was accessed or changed.

Five whole-host CPU samples were below the 97 percent hard ceiling:

| Sample UTC | CPU |
|---|---:|
| `2026-08-21T09:03:31.1616710Z` | 88% |
| `2026-08-21T09:03:35.3172964Z` | 94% |
| `2026-08-21T09:03:39.3399263Z` | 96% |
| `2026-08-21T09:03:43.3757813Z` | 91% |
| `2026-08-21T09:03:47.4140350Z` | 88% |

After a final empty target reconciliation, the target-only canonical apply
created one row:

| Field | Value |
|---|---|
| work item | `e928a598-a8f3-4283-820b-4e6461fe0f52` |
| phase / kind | `Q02` / `backtest` |
| symbol | `XTIUSD.DWX` |
| status | `pending` |
| attempts | `0` |
| claimed by | none |
| created UTC | `2026-08-21T09:04:21Z` |

No dispatcher tick, terminal reservation/control, priority mutation, second
enqueue, or backtest was issued. The paced fleet owns subsequent claim and
execution.

## Falsification and safety handoff

Q02 must retire this identity on zero trades, fewer than five completed
positions per full post-warm-up year, nonpositive governed economics, or any
label/anchor/OHLC/rank/body/CLV/attempt/lifecycle defect. It may not be rescued
by accepting ties, reducing the lookback, moving thresholds, reversing the
side, or adding another filter.

This record does not authorize AutoTrading, `T_Live`, live/demo/shadow/stress/
optimization presets, deploy or T_Live manifest changes, portfolio-gate
changes, portfolio admission, a decorrelation claim, or a correlation waiver.

Machine-readable evidence:
`artifacts/qm5_41087_q02_enqueue_20260821T090421Z_board_advisor.json`.


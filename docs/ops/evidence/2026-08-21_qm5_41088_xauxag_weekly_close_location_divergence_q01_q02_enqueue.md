# QM5_41088 XAU/XAG weekly close-location divergence Q01 and Q02 enqueue

Date: 2026-08-21

Branch: `agents/board-advisor`

EA: `QM5_41088_xauxag-wclv-div-rv`

Outcome: `Q01 PASS`; `Q02 ENQUEUED_PENDING`

## New structural commodity exposure

`QM5_41088` is a low-frequency, symmetric XAU/XAG relative-value basket on
exact `XAUUSD.DWX` and `XAGUSD.DWX` D1. On the first tradable bar of a new
Monday-anchored broker week, it aggregates synchronized OHLC for the exact
immediately completed week, requiring three to five sessions per leg.

It computes each metal's close location inside its own completed-week range.
Gold strictly above two-thirds with silver strictly below one-third sells XAU
and buys XAG; the strict inverse state buys XAU and sells XAG. Equality,
interior or same-tercile states, invalid ranges, asynchronous history, and late
attachment consume the week flat. The package targets equal absolute USD
notional within 20 percent, shares one aggregate `RISK_FIXED=1000` budget, has
frozen `3.5*ATR(20,D1)` stops and no target, and exits at the next week boundary
with ten-day repair.

This mechanic is market-neutral by construction target, not by proven factor
or beta outcome. It differs from the book's outright XAU, index, and XNG
signals and from existing XAU/XAG weekly-return, ratio-rank, common-shock,
range-breakout, and weekend-gap identities. Diversification remains a
hypothesis; unchanged Q09 alone may establish realized correlation.

## Reputable source and governance trail

The bounded source packet cites Karsten Schweikert (2018), "Are gold and
silver cointegrated? New evidence from quantile cointegrating regressions,"
*Journal of Banking & Finance* 88, DOI
`10.1016/j.jbankfin.2017.11.010`, and CME Group's official gold/silver-ratio
spread definition. It explicitly discloses the opposite completed-week
per-leg close-location fade as an untested QM translation. No source return,
density, CFD equivalence, hedge ratio, neutrality, cost, or correlation result
transfers.

| Artifact | Commit / evidence |
|---|---|
| governed source approval | `2b66172a6` |
| deterministic EA-ID reservation | `14ed68e12` |
| G0-approved card | `b51b2de24` |
| two-slot magic allocation and resolver | `433b05f0c` |
| implementation and Q01 build | `386cd462f` |
| strict compile summary | `D:/QM/reports/compile/20260821_095406/summary.csv` |
| strict build report | `D:/QM/reports/framework/21/build_check_20260821_095406.json` |
| static P1 report | `D:/QM/reports/pipeline/QM5_41088/P1/P1_QM5_41088_result.json` |

The canonical pre-allocation duplicate check returned CLEAN across 4,577
registry rows, 625 cards, and zero vault nodes. Manual family review separated
this mechanic from opposite-sign weekly leg returns (`QM5_41083`), ratio-close
rank (`QM5_41079`), same-sign return magnitude (`QM5_41086`), relative-range
breakout (`QM5_41060`), and weekend-gap fade (`QM5_41062`).

## Q01 evidence

- card schema/prohibited-ML lint: PASS;
- G0 card lint: PASS;
- approved-card build prerequisite guard: PASS;
- numbered SPEC validation: PASS;
- basket guardrail and symbol scope: `BASKET_OK`, zero violations;
- deterministic reference suite: 10 tests PASS;
- strict MetaEditor compile: PASS, 0 errors, 0 warnings;
- targeted strict V5 build check: PASS, 0 failures, with two non-fatal card
  discovery warnings because the checker does not recurse into the approved
  card directory; the explicit card and G0 lints passed independently;
- static P1 validation: PASS;
- MQ5 SHA-256:
  `8F4BC1A495522D51D989A515BA139554B04371FA1CCF48B65B9FD70A1CC34D16`;
- EX5 SHA-256:
  `9F5A3D1517A120ED32A0C512D07FF6B274CD22640535ED6944F19A8EB27D3412`;
- setfile byte SHA-256:
  `85F043A9EE9CBA1BBFCE38FE77670A4151E7EFE36370189640B80F5912EE2C29`;
- normalized set build hash:
  `4007647C320486F5AE9DE30F56AC655A00FAAA0627CCFDDC22F0242C6A3A8CE5`;
- strict build-report SHA-256:
  `E55E96C0E84D75F2630F6FB6FB6C92D20ED9B28929E404060FEC36CC9B9AA481`;
- static P1-report SHA-256:
  `CD9BAB7333C6D711183B7A6F2ABDB846A6FFC03D9CD23A87630A1CB412015E1F`.

The sole preset is one D1 logical-basket backtest set with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF,
and Friday close OFF. No manual tester or smoke backtest ran.

## Q02 reconciliation and capacity

At the lane's post-build target reconciliation, the shared canonical sweep had
already created exactly one Q02 row. Its payload records
`claude_sweep_enqueue_2026-06-10.never_tested` as the enqueuer. The supported
target-only non-mutating preview therefore selected zero fresh or stranded
rows, and this lane correctly issued no duplicate apply.

At `2026-08-21T09:56:02Z`, canonical read-only `farmctl mt5-slots` inventory
reported six running governed research terminals—`T1`, `T2`, `T4`, `T5`,
`T7`, and `T8`—below the paced ceiling of seven. It reported no duplicate
terminal workers and no orphaned terminal processes. The separate `T_Live`
and FTMO processes were observed only so they could be excluded; neither was
accessed or changed.

Five whole-host CPU samples were below the 97 percent hard ceiling:

| Sample UTC | CPU |
|---|---:|
| `2026-08-21T09:56:19.3370476Z` | 46% |
| `2026-08-21T09:56:23.3832812Z` | 71% |
| `2026-08-21T09:56:27.4092799Z` | 94% |
| `2026-08-21T09:56:31.4377932Z` | 91% |
| `2026-08-21T09:56:35.4807767Z` | 88% |

Final read-only reconciliation confirmed the singular current row:

| Field | Value |
|---|---|
| work item | `bf1dfee8-add9-481a-93c1-568314f1c5b3` |
| phase / kind | `Q02` / `backtest` |
| logical symbol | `QM5_41088_XAU_XAG_WCLVDIV_RV_D1` |
| status | `pending` |
| attempts | `0` |
| claimed by | none |
| created UTC | `2026-08-21T09:52:58Z` |

No dispatcher tick, terminal reservation/control, priority mutation, second
enqueue, or backtest was issued. The paced fleet owns subsequent claim and
execution.

## Falsification and safety handoff

Q02 must retire this identity on zero packages, fewer than five completed
packages per full post-warm-up year, nonpositive governed economics, or any
label/anchor/OHLC/CLV/attempt/notional/risk/lifecycle defect. It may not be
rescued by accepting boundary equality, moving the terciles, changing the
side or hold, adding a return filter, or fitting a ratio center or hedge ratio.

This record does not authorize AutoTrading, `T_Live`, live/demo/shadow/stress/
optimization presets, deploy or T_Live manifest changes, portfolio-gate
changes, portfolio admission, a decorrelation claim, or a correlation waiver.

Machine-readable evidence:
`artifacts/qm5_41088_q02_enqueue_20260821T095258Z_board_advisor.json`.

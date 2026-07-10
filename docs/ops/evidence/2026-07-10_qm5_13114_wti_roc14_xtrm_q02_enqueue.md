# QM5_13114 WTI ROC-14 Extreme Q02 Enqueue Evidence

Date: 2026-07-10

EA: `QM5_13114_wti-roc14-xtrm`

## Outcome

- G0 card: `APPROVED` under the mission-directed R1-R4 review.
- Pre-allocation dedup: `CLEAN`.
- Q01 strict compile: `PASS`, zero errors and zero warnings.
- Q01 framework build check: `PASS`, zero failures and zero warnings.
- Build task `3283ae39-9e38-40b2-9eb9-24637074a3df`: `done`.
- Q02 work item `a442a21b-72db-407c-a6b0-c368332dc7c7`: `pending` at handoff.

## Edge And Q02 Input

- Edge: contrarian WTI state after a completed month-end 14-month ROC crosses
  outward through +40% or -40%; the latest extreme state persists until the
  opposite crossing and is expressed as one bounded package per broker month.
- Host: `XTIUSD.DWX`, D1, magic slot 0 (`131140000`).
- Setfile:
  `framework/EAs/QM5_13114_wti-roc14-xtrm/sets/QM5_13114_wti-roc14-xtrm_XTIUSD.DWX_D1_backtest.set`.
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- No live setfile exists.

## Source And Falsification Boundary

The primary source is Gurrib, Starkova, and Hamdan (2024), DOI
`10.32479/ijeep.16520`, with the complete open published paper reviewed. The
paper reports only eight continuous positions, dependence on a 2009 outlier,
and four losing positions from 2017 onward. Those facts are carried into the
card as falsification risks; no source performance number is a QM expectation.

The EA uses a continuous Darwinex WTI CFD and monthly fixed-risk packages, not
the source's futures series and continuous position accounting. Q02 must reject
the port if frequency, costs, PF, or drawdown fail.

## Capacity Guard

At handoff, T1, T2, T3, T6, T7, and T8 were running active Q02 work items and
the T4 paced worker was also present. No manual smoke test or backtest was
launched. `record-build` only placed the pending Q02 item into the normal worker
queue.

## Safety

No `T_Live`, AutoTrading, live/deploy manifest, portfolio admission, portfolio
KPI, or portfolio gate was touched.

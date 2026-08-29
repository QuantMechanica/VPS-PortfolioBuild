# QM5_41198_collins-66mom-opt - Strategy Spec

**EA ID:** QM5_41198
**Slug:** collins-66mom-opt
**Source:** b67285d3-d174-51c7-9acc-c9cf0688e278
**Parent EA:** QM5_20266_collins-66mom
**Parent source:** SRC08
**Author of this spec:** Codex
**Last revised:** 2026-08-29

## 1. Strategy Logic

Once per new XTIUSD.DWX D1 bar, the EA reads only completed shifts 1 through
9. Let `C=close[1]`, `H9=max(high[1..9])`, `L9=min(low[1..9])`,
`XH=H9-C`, `XL=C-L9`, and `XX=max(XH,XL)`.

When `XH > XL`, it arms a buy stop at `open[0] + 0.66 * XL`; when
`XL > XH`, it arms a sell stop at `open[0] - 0.66 * XH`. The frozen hard
stop is 1.32 times XX behind the pending entry. An unfilled order expires
after 24 hours. A later opposite Collins trigger closes an open position but
does not reverse it on the same tick. The final rule exit is a restart-safe
20-completed-D1-bar time stop.

The derivative adds six optional closed-D1 pattern veto slots: three for buy
entries and three for sell entries. Zero disables a slot, so the Q02 control
is mechanically identical to the approved parent. An enabled predicate may
suppress an entry on its own side; it cannot create a trade or alter exits,
sizing, pending-order geometry, or hard stops.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| strategy_lookback_d1 | 9 | completed D1 bars in the range envelope |
| strategy_entry_fraction | 0.66 | source stop-entry fraction |
| strategy_stop_fraction | 1.32 | hard-stop fraction of XX |
| strategy_pending_expiry_hours | 24 | pending-stop lifetime |
| strategy_max_hold_bars | 20 | maximum completed D1 holding periods |
| strategy_max_spread_points | 1000 | entry spread cap |
| strategy_min_stop_points | 10 | extra broker-distance safety floor |
| opt_pp_buy1..3 | 0 | optional buy-side pattern veto predicate IDs |
| opt_pp_sell1..3 | 0 | optional sell-side pattern veto predicate IDs |

The Q02 baseline keeps all six pattern inputs at zero. Pattern discovery is a
later governed measurement and is not part of this build.

## 3. Symbol Universe

| Slot | Symbol | Magic | Rationale |
|---:|---|---:|---|
| 0 | XTIUSD.DWX | 411980000 | approved WTI falsification carrier |

The EA rejects every other symbol and timeframe. WTI adds crude-oil exposure
beyond the certified book's index, metal, and XNG concentration; portfolio
diversification remains a later Q09 claim, not a build assumption.

## 4. Timeframe

The host, signal, pattern-reference, holding-period, and execution cadence is
D1. Range geometry uses completed bars only. Orders are considered at the
first tradable tick of a new broker D1 bar and each bar is durably consumed
before downstream entry gates, preventing retry after restart or rejection.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades per year | 15-40, central prior 28 |
| Maximum hold time | 20 completed D1 bars |
| Entry style | day-only asymmetric stop entry |
| Regime preference | directional expansion from close-location asymmetry |

The source reports financial-futures evidence, not WTI performance. This
carrier is a falsifiable structural port and inherits no profitability claim.

## 6. Source Citation

Derivative source ID: b67285d3-d174-51c7-9acc-c9cf0688e278. Parent source ID:
SRC08.

Collins, Art. *Beating the Financial Futures Market: Combining Small Biases
into Powerful Money Making Strategies*. John Wiley & Sons, 2006, Chapter 41,
printed pages 177-179 and Appendix Table 41.3, printed page 232.

Derivative approval and R1-R4 evidence are recorded in
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_41198_collins-66mom-opt.md`.
The complete parent rules are recorded in
`C:/QM/repo/strategy-seeds/cards/approved/QM5_20266_collins-66mom_card.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02-Q10) | RISK_FIXED | USD 1,000 per trade |
| Live | not authorized | n/a |

The backtest preset explicitly fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`. It retains the parent's two-axis DXZ news gate and
Friday-close behavior. No live preset, deployment artifact, or portfolio-gate
change is created.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-29 | Approved DL-089 derivative V5 build | farm task 084ae29d-4ecb-4dcf-829f-2ccfaec060a3 |

# QM5_20266_collins-66mom - Strategy Spec

**EA ID:** QM5_20266
**Slug:** `collins-66mom`
**Source:** `SRC08`
**Author of this spec:** Codex
**Last revised:** 2026-08-08

## 1. Strategy Logic

This EA is a low-frequency structural WTI port of Art Collins' Continuous
66 Percent Momentum rule. Once per newly observed `XTIUSD.DWX` D1 bar it
uses only completed shifts 1 through 9:

```text
C  = close[1]
H9 = max(high[1..9])
L9 = min(low[1..9])
XH = H9 - C
XL = C - L9
XX = max(XH, XL)
```

If `XH > XL`, the EA arms a buy stop at `open[0] + 0.66 * XL`; if
`XL > XH`, it arms a sell stop at `open[0] - 0.66 * XH`. The hard stop is
`1.32 * XX` behind the pending entry. Each D1 bar is consumed through a
terminal Global Variable before entry gates are evaluated, so rejection,
send failure, stop-out, or restart cannot cause a same-bar retry.

Unfilled stops expire after 24 hours and are canceled at the next genuine D1
transition or Friday-close boundary. A later opposite Collins setup is
flatten-only when its stop level is touched; there is no same-tick reversal.
Positions also close after 20 completed D1 bars. There is no take-profit,
trailing stop, averaging, grid, martingale, external feed, or ML component.

## 2. Parameters

| Parameter | Default | Declared values | Meaning |
|---|---:|---|---|
| `strategy_lookback_d1` | 9 | 7, 9, 12 | Completed D1 bars in the envelope |
| `strategy_entry_fraction` | 0.66 | 0.50, 0.66, 0.75 | Source-side stop-entry fraction |
| `strategy_stop_fraction` | 1.32 | 1.00, 1.32, 1.50 | Hard-stop multiple of `XX` |
| `strategy_pending_expiry_hours` | 24 | fixed at Q02 | Pending-stop lifetime |
| `strategy_max_hold_bars` | 20 | 10, 20, 30 | Completed-D1 stale-state exit |
| `strategy_max_spread_points` | 1000 | 700, 1000, 1500 | Entry spread cap |
| `strategy_min_stop_points` | 10 | fixed at Q02 | Extra broker-distance safety floor |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0, magic `202660000`.

## 4. Timeframe

- Host and signal timeframe: D1.
- Raw OHLC scan: bounded shifts 1 through `strategy_lookback_d1`, evaluated
  only on a D1 transition.
- Entry cadence: at most one persisted arm attempt per broker D1 bar.

## 5. Expected Behaviour

- Research prior: 15-40 completed WTI trades/year, central estimate 28.
- Q02 falsification floor: at least five completed trades/year.
- Regime preference: crude-oil directional expansion from an asymmetric
  close location inside the completed nine-day envelope.
- The source reports financial-futures results, not WTI results. This carrier
  is an explicit out-of-sample port and receives no transferred performance.

## 6. Source Citation

Collins, Art. *Beating the Financial Futures Market: Combining Small Biases
into Powerful Money Making Strategies*. John Wiley & Sons, 2006. Chapter 41,
printed pages 177-179, and Appendix Table 41.3, printed page 232.

## 7. Risk Model and Safety

| Phase | Risk mode | Value |
|---|---|---:|
| Q02 backtest | RISK_FIXED | 1000 |
| Live | not authorized | n/a |

The setfile fixes `RISK_PERCENT=0` and `PORTFOLIO_WEIGHT=1`. Framework kill
switch, news entry gating, MAE evidence, and Friday close remain active.
News never blocks management or exits. This build creates no live setfile and
does not touch the portfolio gate, deploy manifests, `T_Live`, or AutoTrading.

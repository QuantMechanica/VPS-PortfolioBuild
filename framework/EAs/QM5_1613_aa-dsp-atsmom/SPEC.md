# QM5_1613_aa-dsp-atsmom - Strategy Spec

**EA ID:** QM5_1613
**Slug:** aa-dsp-atsmom
**Source:** ede348b4-0fa7-5be1-baa8-09e9089b67b7
**Author of this spec:** Codex
**Last revised:** 2026-08-24

---

## 1. Strategy Logic

On each newly completed D1 bar, the EA calculates the approved fixed averaged
time-series momentum signal:

`ATSMOM = 0.7043 * (Close(1) - 0.25*Close(4) - 0.25*Close(7) - 0.25*Close(10) - 0.25*Close(13))`

- Open long while flat when `ATSMOM > 0`.
- Open short while flat when `ATSMOM < 0`.
- Close a long when `ATSMOM <= 0`; close a short when `ATSMOM >= 0`.
- Place an initial stop at `2.5 x ATR(20, D1)`.
- Reject a new entry when the current D1 spread exceeds 2.5 times the median
  spread of the preceding 20 completed D1 bars.

The state-based entry deliberately permits re-entry after an ATR stop while the
completed-bar signal retains its sign. News and Friday restrictions block new
entries but do not suppress the card's risk-reducing exits.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_min_daily_bars` | 30 | Minimum completed D1 history required before evaluation |
| `strategy_atr_period` | 20 | D1 ATR lookback for the initial stop |
| `strategy_atr_sl_mult` | 2.5 | ATR multiplier for the initial stop |
| `strategy_spread_median_days` | 20 | Completed D1 spread observations used for the median |
| `strategy_spread_median_mult` | 2.5 | Maximum current-spread multiple of the D1 median |

## 3. Symbol Universe

The approved card universe contains exactly nine concepts:

- Equity indices: `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`.
- Gold and energy: `XAUUSD.DWX`, `USOIL.DWX`.
- FX: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`.

The governed execution-symbol registry maps the card's `USOIL.DWX` concept from
the broker alias `USOIL.cash` to the logical custom symbol `XTIUSD.DWX`. The
portable build and its setfile therefore use `XTIUSD.DWX`; no unapproved symbol
is included in the delivered setfile universe.

## 4. Timeframe and Cadence

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe references | None |
| Signal cadence | Once per completed D1 bar via `QM_IsNewBar(_Symbol, PERIOD_D1)` |
| Position policy | One position per symbol and resolved magic |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 100 (card estimate; pipeline-measured) |
| Typical hold time | 2-15 D1 bars |
| Regime preference | Trending / momentum |

## 6. Source Citation

**Source ID:** ede348b4-0fa7-5be1-baa8-09e9089b67b7

Henry Stern, "An Introduction to Digital Signal Processing for Trend Following",
Alpha Architect, 2020-08-13 (updated 2025-03):
https://alphaarchitect.com/an-introduction-to-digital-signal-processing-for-trend-following/

R1 lineage and the R2-R4 PASS decisions remain governed by the approved Strategy
Card at `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1613_aa-dsp-atsmom.md`.

## 7. Risk Model

| Environment | Active mode | Other mode |
|---|---|---|
| Backtest | `RISK_FIXED = 1000` ($1,000 per trade) | `RISK_PERCENT = 0` |
| T6 live, if separately authorized | `RISK_PERCENT = 0.5` | `RISK_FIXED = 0` |

This build and specification do not authorize a backtest, promotion, or live
deployment.

# QM5_12614_tsmom-6m-fx-basket-3pair - Strategy Spec

**EA ID:** QM5_12614
**Slug:** tsmom-6m-fx-basket-3pair
**Source:** Moskowitz, Ooi & Pedersen (2012), "Time series momentum"
**Author of this spec:** Codex
**Last revised:** 2026-06-29

---

## 1. Strategy Logic

The EA implements the approved 6-month time-series momentum card on three
major FX `.DWX` symbols: EURUSD.DWX, GBPUSD.DWX, and USDJPY.DWX. Each symbol
is an independent magic slot of the same EA.

On the first D1 bar of a new calendar month, the EA compares the most recently
closed D1 close with the close 126 D1 bars earlier. A positive return opens or
keeps a long position; a negative return opens or keeps a short position. If a
position already exists and the signal is unchanged, the slot holds it. If the
signal reverses, the slot closes the current position and opens in the new
direction.

The code computes the card's 20-day realized volatility series as an entry data
guard and caps the derived scale at 2.0. Order submission remains on the V5
standard entry path; per-slot fixed-risk splitting is supplied by the backtest
setfiles through `PORTFOLIO_WEIGHT=0.333333`.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_lookback_d1_bars | 126 | 20+ | D1 bars used for the 6-month return-sign signal |
| strategy_vol_window_d1 | 20 | 2-63 | D1 bars used for realized volatility availability and scale calculation |
| strategy_target_pair_vol | 0.033333 | >0 | Card target annual volatility per slot, one third of 10% |
| strategy_max_vol_scale | 2.0 | >0 | Cap on the derived volatility scale |
| strategy_min_d1_bars | 155 | 130+ | Minimum D1 bars required before a slot may trade |
| strategy_atr_period | 14 | 2+ | D1 ATR period for the hard stop |
| strategy_atr_sl_mult | 3.0 | >0 | ATR multiple for the hard stop |
| strategy_spread_days | 20 | 1-64 | D1 spread history window for the median spread filter |
| strategy_spread_mult | 3.0 | >0 | Skip entry when current spread exceeds median times this multiple |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - slot 0, major FX time-series momentum sleeve.
- GBPUSD.DWX - slot 1, major FX time-series momentum sleeve.
- USDJPY.DWX - slot 2, major FX time-series momentum sleeve.

**Explicitly not for:**
- Non-FX symbols or FX pairs outside the approved card universe.

The card labels its slots 1-3, but the V5 registry and review convention use
zero-based slots. The implemented order is the same: EURUSD, GBPUSD, USDJPY.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` after the framework tick guards |
| Rebalance cadence | First D1 bar of each calendar month |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | around 8 direction-change or re-entry events |
| Typical hold time | weeks to months |
| Expected drawdown profile | moderate to high, commission-sensitive FX trend sleeve |
| Regime preference | persistent medium-term FX trends |
| Win rate target | medium |

The strategy is deliberately low-frequency. A slot may hold through a monthly
rebalance if the 126-bar return sign is unchanged.

---

## 6. Source Citation

Primary source:
- Moskowitz, Tobias J.; Ooi, Yao Hua; Pedersen, Lasse Heje (2012). "Time series
  momentum." Journal of Financial Economics, 104(2), 228-250.
- Approved card source URI:
  https://www.aqr.com/insights/research/journal-article/time-series-momentum

Card mapping:
- Section III supports the 6-month time-series momentum horizon.
- Section IV supports diversification across multiple FX instruments.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | USD 1,000 total basket baseline, split by setfile `PORTFOLIO_WEIGHT=0.333333` |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

Each slot receives an ATR(14, D1) x 3.0 hard stop. The Q02 setfiles use
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and one-third portfolio weight per slot.
No manual tester run was launched from this build session; Q02 is enqueued by
`farmctl record-build`.

Q02 queue note: enqueued by `farmctl record-build` on 2026-06-29:
EURUSD.DWX work item `3cf5bd2d`, GBPUSD.DWX work item `f9794a25`,
and USDJPY.DWX work item `e26fef3d`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-29 | Initial approved FX basket build | Built for EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX |
| v1-q02 | 2026-06-29 | Build recorded and Q02 enqueued | Work items 3cf5bd2d, f9794a25, e26fef3d pending |

# QM5_12612_tsmom-12m-vol-scaled-ndx - Strategy Spec

**EA ID:** QM5_12612
**Slug:** `tsmom-12m-vol-scaled-ndx`
**Source:** `e5a3f925-5a9e-513d-9e70-5c7c70fa0e59`
**Author of this spec:** Gemini
**Last revised:** 2026-08-21

---

## 1. Strategy Logic

This EA implements the single-symbol NDX.DWX volatility-scaled version of the Moskowitz, Ooi, and Pedersen (2012) 12-month time-series momentum rule.

On the first new D1 bar of each broker-calendar month:
1. Signal Direction: compares the last completed NDX.DWX close with the close 252 D1 bars earlier (`lookback_bars = 252`). If positive, signal is +1 (LONG); if negative, -1 (SHORT).
2. Volatility Scaling: computes realized annualized volatility over a 63-bar trailing window from daily log returns (`vol_window = 63`). Multiplier `vol_scalar = target_vol / Max(realized_vol, 0.01)`, clamped between 0.10 and 2.00 (with `target_vol = 0.10`).
3. Rebalance / Execution:
   - If signal reverses: existing position is closed and new position is opened in the new direction with risk scaled by `vol_scalar`.
   - If signal direction is unchanged but `vol_scalar` changed by > 20%: position is resized (closed and reopened with new sizing).
   - Otherwise, the position is held.
4. Hard Stop: ATR(14, D1) x 3.0 provides protective risk control.

The EA uses only Darwinex MT5 price history and broker calendar timing. It does not use external APIs, ML, grids, or martingale sizing.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `qm_ea_id` | 12612 | fixed | Canonical EA ID |
| `qm_magic_slot_offset` | 1 | 0-12 | Registered magic slot (slot 1 = NDX.DWX) |
| `strategy_lookback_d1_bars` | 252 | 126-315 | Lookback D1 bars for 12-month sign signal |
| `strategy_vol_window` | 63 | 21-126 | Trailing D1 bars for realized volatility estimation |
| `strategy_target_vol` | 0.10 | 0.05-0.25 | Annualized target volatility |
| `strategy_vol_resize_threshold` | 0.20 | 0.10-0.50 | Relative vol_scalar change threshold to trigger resize |
| `strategy_min_d1_bars` | 275 | 252-320 | Minimum D1 history required before trading |
| `strategy_atr_period` | 14 | 10-30 | ATR period for protective hard stop |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | ATR hard stop distance multiplier |
| `strategy_spread_days` | 20 | 10-30 | Completed D1 bars for median spread guard |
| `strategy_spread_mult` | 3.0 | 2.0-5.0 | Max allowable spread as multiple of median spread |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - core DWX index instrument, live-tradable at Darwinex.

**Explicitly NOT for:**
- Non-DWX broker symbols.
- Unregistered asset classes.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()`; evaluated on the first D1 bar of each month |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~8 direction-change trades + occasional vol resizes (~10-12 events/yr) |
| Typical hold time | Several months while trend regime persists |
| Expected drawdown profile | Medium trend drawdown during chop / regime transitions |
| Regime preference | Sustained multi-month trends in US tech equities |
| Win rate target | Medium (~40-50% with positive skew) |

---

## 6. Source Citation

This card was mechanised from:
- **Source ID:** `e5a3f925-5a9e-513d-9e70-5c7c70fa0e59`
- **Source:** [[sources/aqr-moskowitz-ooi-pedersen-time-series-momentum-2012]]
- **Paper:** Moskowitz, Ooi & Pedersen (2012). "Time series momentum." Journal of Financial Economics, 104(2), 228-250.
- **URI:** https://www.aqr.com/insights/research/journal-article/time-series-momentum
- **R1-R4 verdict (Q00):** all PASS per approved card

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 base per trade (vol-scaled) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-21 | Initial build from approved card | Built during single-pass orchestration cycle |

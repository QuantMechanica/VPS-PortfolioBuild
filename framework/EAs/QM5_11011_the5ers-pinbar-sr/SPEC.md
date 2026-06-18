# QM5_11011_the5ers-pinbar-sr - Strategy Spec

**EA ID:** QM5_11011
**Slug:** the5ers-pinbar-sr
**Source:** 1d445184-7c47-57da-9856-a123682a932d (see `sources/the5ers-blog`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA looks for H4 pin bars at confirmed support or resistance. A support or resistance level is confirmed by at least two swing points in the last 120 bars within 0.50 ATR of the level, and the level must be at least 10 bars old. A bullish pin bar places a buy stop above the pin high; a bearish pin bar places a sell stop below the pin low. The stop is outside the opposite pin extreme, the target is 2.0R, pending orders expire after 3 H4 bars, and open positions close if price closes back through the pin midpoint or after 20 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_atr_period | 14 | 5-50 | ATR period used for candle geometry, level tolerance, trigger buffer, and stop buffer. |
| strategy_pin_min_atr_mult | 0.75 | 0.25-2.00 | Minimum pin-bar range as a multiple of ATR. |
| strategy_pin_max_atr_mult | 3.00 | 1.00-6.00 | Maximum pin-bar range as a multiple of ATR to reject news spikes. |
| strategy_wick_frac | 0.70 | 0.50-0.90 | Required dominant wick share of the full candle range. |
| strategy_body_frac | 0.25 | 0.05-0.50 | Maximum candle body share of the full range. |
| strategy_level_tol_atr | 0.50 | 0.10-1.00 | ATR-scaled tolerance for S/R touches and clusters. |
| strategy_trigger_atr_mult | 0.10 | 0.00-0.50 | ATR buffer beyond the pin extreme for stop entry. |
| strategy_sl_buffer_atr_mult | 0.10 | 0.00-0.50 | ATR buffer beyond the opposite pin extreme for stop loss. |
| strategy_tp_rr | 2.00 | 0.50-5.00 | Take-profit multiple of initial risk. |
| strategy_sr_lookback | 120 | 30-300 | H4 bars scanned for swing support/resistance. |
| strategy_swing_strength | 3 | 1-10 | Neighbour bars on each side required to confirm a swing. |
| strategy_sr_min_touches | 2 | 2-5 | Minimum clustered swing touches required for a level. |
| strategy_sr_min_age_bars | 10 | 1-50 | Minimum age of the S/R level before use. |
| strategy_pending_valid_bars | 3 | 1-10 | H4 bars before the pending stop expires. |
| strategy_time_stop_bars | 20 | 1-80 | Maximum H4 bars to hold an open position. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card target forex pair with H4 OHLC and ATR available.
- GBPUSD.DWX - card target forex pair with H4 OHLC and ATR available.
- USDJPY.DWX - card target forex pair with H4 OHLC and ATR available.
- XAUUSD.DWX - card target gold symbol with H4 OHLC and ATR available.
- GDAXI.DWX - canonical DWX DAX symbol; used as the available port for card-stated GER40.DWX.

**Explicitly NOT for:**
- GER40.DWX - card-stated DAX name is not present in `dwx_symbol_matrix.csv`; use GDAXI.DWX.
- SPX500.DWX - not present in the DWX matrix.
- SPY.DWX - not present in the DWX matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | Up to 20 H4 bars, roughly 3.3 trading days |
| Expected drawdown profile | Bounded single-position reversal system with fixed 1R stop and 2R target. |
| Regime preference | Support/resistance reversal after pin-bar rejection. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1d445184-7c47-57da-9856-a123682a932d
**Source type:** blog
**Pointer:** https://the5ers.com/forex-pin-bar/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11011_the5ers-pinbar-sr.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-18 | Initial build from card | fb0901f0-072d-461d-a056-fa7b66fff818 |

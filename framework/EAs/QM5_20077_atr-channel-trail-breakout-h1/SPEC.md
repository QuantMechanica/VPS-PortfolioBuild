# QM5_20077_atr-channel-trail-breakout-h1 - Strategy Spec

**EA ID:** QM5_20077
**Slug:** `atr-channel-trail-breakout-h1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (ForexFactory Trading Systems ATR-channel cluster)
**Author of this spec:** Gemini
**Last revised:** 2026-08-24

---

## 1. Strategy Logic

QM5_20077 implements a deterministic ATR-channel breakout and auto-trailing flip state machine on H1 bars. The strategy constructs dynamic volatility bands around an EMA spine: `UpperBand = EMA(close, 21) + 2.5 * ATR(14)` and `LowerBand = EMA(close, 21) - 2.5 * ATR(14)`. When the closed H1 bar breaches a band, the channel direction state updates (`+1` for long, `-1` for short) and the opposite band acts as the trailing stop loss. For long positions, the stop level ratchets only upward (`max(stop_level, LowerBand)`); for short positions, it ratchets only downward (`min(stop_level, UpperBand)`).

Entries are gated by:
1. Macro Trend Filter: H1 Close must be above `EMA(close, 200)` for long entries, and below `EMA(close, 200)` for short entries.
2. Channel Width Filter: Channel width `(UpperBand - LowerBand)` must exceed `0.5 * ATR(14, D1)` to prevent entries during volatility collapse.
3. Session Filter: Entries allowed only between 06:00 and 21:00 broker time.
4. Spread Guard: Entry skipped if current spread exceeds `1.5 * 20-bar median spread`.
5. Max SL Distance: Initial SL distance is capped at `4.0 * ATR(14, H1)`.

Exits occur when:
1. Channel Flip Exit: Closed H1 price crosses the trailing stop level against the open position.
2. Macro-Trend Invalidation: Closed H1 price crosses the 200-period EMA against the open position.
3. Framework Friday close at 21:00 broker time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_base_ma_period` | 21 | 10-50 | Period for channel centerline EMA on H1 |
| `strategy_atr_period` | 14 | 5-30 | Period for ATR band scaling on H1 |
| `strategy_band_mult` | 2.5 | 1.5-4.0 | Band distance multiplier (k) |
| `strategy_macro_ema_period` | 200 | 100-300 | Period for macro-trend filter EMA on H1 |
| `strategy_d1_atr_period` | 14 | 5-30 | Period for daily ATR volatility floor filter |
| `strategy_min_channel_width_d1_atr_mult` | 0.5 | 0.1-1.5 | Minimum channel width multiplier of D1 ATR |
| `strategy_max_sl_atr_mult` | 4.0 | 2.0-8.0 | Maximum initial stop-loss cap in H1 ATR multiples |
| `strategy_session_start_hour` | 6 | 0-23 | Start hour (broker time) for new entries |
| `strategy_session_end_hour` | 21 | 0-23 | End hour (broker time) for new entries |
| `strategy_spread_mult` | 1.5 | 1.0-3.0 | Multiplier on 20-bar median spread filter |
| `strategy_spread_median_bars` | 20 | 5-50 | Number of bars for median spread calculation |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major with liquid H1 trend and volatility characteristics.
- `GBPUSD.DWX` - FX major with strong directional momentum.
- `USDJPY.DWX` - FX major responsive to ATR-band trailing expansions.
- `XAUUSD.DWX` - Commodity metal with sustained trend extensions.
- `NDX.DWX` - Index CFD with high momentum follow-through.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `D1` (for Daily ATR volatility filter) |
| Bar gating | `QM_IsNewBar()` on H1 |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~22 |
| Typical hold time | 1 to 5 days (trend-following swing) |
| Expected drawdown profile | Drawdowns occur during prolonged tight ranging channels with whipsaws |
| Regime preference | Trending / Volatility expansion |
| Target profit factor | 1.35 |

---

## 6. Source Citation

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** Forum cluster
**Pointer:** ForexFactory Trading Systems ATR-channel cluster
**R1-R4 verdict (Q00):** all PASS / see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_20077_atr-channel-trail-breakout-h1.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | 0.5% of equity |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-24 | Initial build from approved card | Gemini draft for task 6c35c3ec-b576-4919-a321-796b7c813350 |

# QM5_10966_ftmo-even-star - Strategy Spec

**EA ID:** QM5_10966
**Slug:** ftmo-even-star
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f (see `strategy-seeds/sources/c11dc4d3-bdfb-5076-aeed-5d943e9ef03f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades a short H4 reversal after an uptrend reaches resistance and prints an Evening Star. It requires SMA(50) above SMA(100), at least two higher swing highs and two higher swing lows over the last 40 H4 bars, and a three-candle pattern near either a prior swing high or a round-number level. After the pattern completes, it enters short when a later closed H4 candle breaks below candle 3 low within the next 3 bars. The stop is the pattern high plus 0.25 ATR(14), the primary target is 2.0R, an eligible prior swing low can replace the target when it sits between 1.5R and 3.0R, breakeven is applied at 1.0R, and positions are time-closed after 20 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | 2-100 | H4 ATR period used for pattern body sizing, resistance tolerance, and stop buffer. |
| `strategy_sma_fast_period` | 50 | 2-300 | Fast H4 SMA for the uptrend filter and slope filter. |
| `strategy_sma_slow_period` | 100 | 3-500 | Slow H4 SMA for the uptrend filter. |
| `strategy_swing_lookback_bars` | 40 | 10-200 | Bars used to confirm higher swing highs and higher swing lows. |
| `strategy_resistance_lookback_bars` | 60 | 10-300 | Bars used to locate the prior resistance swing high and alternate target swing low. |
| `strategy_entry_window_bars` | 3 | 1-10 | Number of closed H4 bars after candle 3 allowed to break below candle 3 low. |
| `strategy_max_hold_bars` | 20 | 1-100 | Maximum holding period in H4 bars before strategy close. |
| `strategy_slope_negative_max_bars` | 10 | 0-50 | Blocks entries when SMA(50) has already sloped negative for more than this many bars. |
| `strategy_round_step_points` | 1000 | 1-100000 | Point interval used to detect round-number resistance. |
| `strategy_candle1_body_atr_mult` | 0.80 | 0.10-5.00 | Minimum candle 1 real body as a multiple of ATR(14). |
| `strategy_candle2_body_ratio` | 0.35 | 0.05-1.00 | Maximum candle 2 real body as a fraction of candle 1 body. |
| `strategy_resistance_atr_mult` | 0.35 | 0.05-2.00 | Maximum distance from prior swing high resistance, in ATR multiples. |
| `strategy_round_tolerance_pct` | 0.15 | 0.01-2.00 | Percent tolerance around round-number resistance. |
| `strategy_sl_atr_buffer_mult` | 0.25 | 0.00-2.00 | Stop buffer above the three-candle pattern high, in ATR multiples. |
| `strategy_min_stop_atr_mult` | 0.50 | 0.05-5.00 | Minimum planned stop distance in ATR multiples. |
| `strategy_max_stop_atr_mult` | 2.50 | 0.10-10.00 | Maximum planned stop distance in ATR multiples. |
| `strategy_primary_rr` | 2.00 | 0.25-10.00 | Default reward-to-risk target. |
| `strategy_alt_tp_min_rr` | 1.50 | 0.25-10.00 | Minimum R multiple for using nearest prior H4 swing low as target. |
| `strategy_alt_tp_max_rr` | 3.00 | 0.25-10.00 | Maximum R multiple for using nearest prior H4 swing low as target. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair in the card's approved P2 basket.
- `USDJPY.DWX` - liquid major FX pair in the card's approved P2 basket.
- `GBPUSD.DWX` - liquid major FX pair in the card's approved P2 basket.
- `XAUUSD.DWX` - liquid metal symbol in the card's approved P2 basket.

**Explicitly NOT for:**
- Equity indices - not in the card's approved R3 basket for this candlestick reversal.
- Sector ETFs or unavailable CFD aliases - not present in the card and not required by the DWX matrix mapping.

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
| Trades / year / symbol | 25 |
| Typical hold time | Up to 20 H4 bars, roughly 3 trading days. |
| Expected drawdown profile | Selective reversal entries with fixed 1R initial loss and breakeven after 1R. |
| Regime preference | Reversal after uptrend exhaustion at resistance. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Source type:** article
**Pointer:** FTMO, "Trading strategy using the Evening Star Pattern", 2025-04-18, https://ftmo.com/en/trading-strategy-using-the-evening-star-pattern/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10966_ftmo-even-star.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-06 | Initial build from card | a07d6c77-67a0-43cb-af8e-ace104d2df4a |

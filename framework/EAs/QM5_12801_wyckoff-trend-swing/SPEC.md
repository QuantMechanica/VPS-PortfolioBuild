# QM5_12801_wyckoff-trend-swing - Strategy Spec

**EA ID:** QM5_12801
**Slug:** `wyckoff-trend-swing`
**Source:** `hyonix-wyckoff-trend-swing-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

The EA trades H4 Wyckoff-style trend swings after price retests recent support or resistance. A long setup requires an uptrend by EMA(50) over EMA(200), ADX strength, an H4 support touch and reclaim, and a volume spike versus the recent H4 average. A short setup mirrors the rule at resistance in a downtrend. The initial stop is ATR-based with support/resistance buffering, half the position is closed at 1.5R, and the remaining runner uses an ATR trail or exits on trend failure/time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_tf` | `PERIOD_H4` | H4 only | Base timeframe for all strategy logic. |
| `strategy_sr_lookback_bars` | 36 | 12-120 | Lookback used to define current support and resistance. |
| `strategy_volume_lookback_bars` | 24 | 6-80 | Bars used for the average-volume baseline. |
| `strategy_volume_spike_mult` | 1.25 | 1.0-3.0 | Required signal-bar volume multiple. |
| `strategy_atr_period` | 14 | 5-50 | ATR period for stop, trail, and volatility filters. |
| `strategy_fast_ema_period` | 50 | 10-100 | Fast trend EMA. |
| `strategy_slow_ema_period` | 200 | 80-300 | Slow trend EMA. |
| `strategy_adx_period` | 14 | 5-50 | ADX trend-strength period. |
| `strategy_adx_min` | 17.0 | 5.0-40.0 | Minimum ADX required for entries. |
| `strategy_sr_touch_atr_mult` | 0.45 | 0.10-1.50 | ATR band for support/resistance touch. |
| `strategy_reclaim_atr_mult` | 0.12 | 0.00-0.75 | ATR reclaim distance after touch. |
| `strategy_sl_atr_mult` | 2.2 | 0.8-5.0 | ATR stop distance cap. |
| `strategy_sl_buffer_atr_mult` | 0.35 | 0.0-1.5 | Support/resistance buffer for stop. |
| `strategy_max_sl_atr_mult` | 3.2 | 1.0-6.0 | Maximum allowed stop distance. |
| `strategy_partial_rr` | 1.5 | 0.5-4.0 | Reward/risk level for partial close. |
| `strategy_partial_fraction` | 0.50 | 0.10-0.90 | Fraction closed at the partial target. |
| `strategy_trail_atr_mult` | 1.2 | 0.3-4.0 | ATR multiple for runner trailing stop. |
| `strategy_reentry_guard_bars` | 8 | 0-40 | Minimum bars between reused signals. |
| `strategy_time_stop_bars` | 45 | 5-120 | Maximum holding period in H4 bars. |
| `strategy_spread_atr_mult` | 0.20 | 0.05-1.00 | Maximum spread as a fraction of ATR. |
| `strategy_min_atr_close_pct` | 0.0015 | 0.0001-0.0200 | Minimum ATR/close volatility. |
| `strategy_max_atr_close_pct` | 0.0600 | 0.0100-0.1500 | Maximum ATR/close disaster-regime filter. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq index proxy from the card's index-first basket.
- `GDAXI.DWX` - DAX/GER40 proxy from the card's index-first basket.
- `SP500.DWX` - US500 proxy; backtest-only custom symbol.
- `XAUUSD.DWX` - Gold instrument from the card's index/gold R3 scope.

**Explicitly NOT for:**
- Forex pairs - not listed in this card's instrument scope.
- `XTIUSD.DWX` and `XNGUSD.DWX` - energy symbols are outside this card's index/gold scope.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, strategy_tf)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Several H4 bars to multiple days |
| Expected drawdown profile | Approximately 12% at Q02 fixed risk before later gates |
| Regime preference | Trend swing with support/resistance retests and volume confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `hyonix-wyckoff-trend-swing-2026`
**Source type:** OWNER/local Hyonix triage plus Wyckoff method reference
**Pointer:** `C:/Users/Administrator/Downloads/Hyonix/Hyonix/WyckoffTrendSwing.mq5`
**R1-R4 verdict (Q00):** all PASS / see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12801_wyckoff-trend-swing.md`

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
| v1 | 2026-06-30 | Initial build from card | 55186639 |

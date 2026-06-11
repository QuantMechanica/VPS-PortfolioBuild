# QM5_9696_ff-genesis-matrix-m5 - Strategy Spec

**EA ID:** QM5_9696
**Slug:** `ff-genesis-matrix-m5`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades completed M5 bars during the Frankfurt/London/New York overlap window. A long entry requires all four Genesis Matrix cells to be bullish, Stochastic(14,3,3) %K rising after crossing up from below 35 within the last three bars, a bullish Heiken Ashi candle, and the M5 candle opening and closing above EMA(5). A short entry mirrors those rules with all Genesis cells bearish, %K falling after crossing down from above 65, bearish Heiken Ashi, and the candle below EMA(5). Exits are by opposite Genesis Matrix colour, opposite Stochastic zone cross, 1.6R target, structural/ATR stop, time stop after 18 M5 bars, and the V5 Friday close guard.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_M5` | M5 expected | Base signal timeframe from the card. |
| `strategy_session_start_hhmm` | `800` | 0-2359 | Broker-time Frankfurt-open start gate. |
| `strategy_session_end_hhmm` | `1830` | 0-2359 | Broker-time three-hours-after-New-York-open end gate. |
| `strategy_max_spread_points` | `250` | >=0 | Skip entries when current spread is above this many points; 0 disables. |
| `strategy_ema_period` | `5` | >=1 | EMA close period for candle side confirmation. |
| `strategy_stoch_k_period` | `14` | >=1 | Stochastic %K period. |
| `strategy_stoch_d_period` | `3` | >=1 | Stochastic %D period. |
| `strategy_stoch_slowing` | `3` | >=1 | Stochastic slowing. |
| `strategy_stoch_cross_lookback` | `3` | 1-10 | Number of closed bars allowed for the zone cross freshness rule. |
| `strategy_stoch_long_cross_level` | `35.0` | 0-100 | Long entry lower-zone threshold. |
| `strategy_stoch_short_cross_level` | `65.0` | 0-100 | Short entry upper-zone threshold. |
| `strategy_atr_period` | `14` | >=1 | ATR period for stop padding and volatility filter. |
| `strategy_atr_median_days` | `20` | >=0 | Same-session ATR median sample days. |
| `strategy_min_atr_median_ratio` | `0.60` | >=0 | Minimum ATR as a fraction of the 20-day same-session median. |
| `strategy_m5_bars_per_day` | `288` | >0 | Shift spacing for same-session M5 ATR samples. |
| `strategy_swing_lookback` | `8` | >=1 | Recent swing window for structural stop placement. |
| `strategy_sl_atr_padding` | `0.20` | >=0 | ATR padding beyond the swing low/high. |
| `strategy_take_profit_r` | `1.60` | >0 | Fixed R-multiple take profit. |
| `strategy_time_stop_bars` | `18` | >=1 | Maximum holding period in M5 bars. |
| `strategy_tvi_lookback` | `8` | >=1 | Bounded tick-volume impulse proxy for the Genesis TVI cell. |
| `strategy_cci_period` | `20` | >=1 | CCI period for the Genesis CCI cell. |
| `strategy_cci_neutral_band` | `0.0` | >=0 | Neutral band around CCI zero. |
| `strategy_t3_proxy_period` | `8` | >=1 | EMA-slope proxy period for the Genesis T3 cell. |
| `strategy_gann_hilo_period` | `10` | >=1 | SMA high/low period for the Genesis GannHiLo cell. |
| `strategy_heiken_ashi_warmup` | `20` | >=3 | Bars used to warm up the Heiken Ashi open calculation. |
| `strategy_news_first5_enabled` | `true` | true/false | Skip the first five minutes after high-impact scheduled news. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - primary liquid FX pair named in the card's P2 basket.
- `GBPUSD.DWX` - liquid London/New York FX pair named in the card's P2 basket.
- `USDJPY.DWX` - liquid major FX pair named in the card's P2 basket.
- `XAUUSD.DWX` - liquid metals symbol named in the card's P2 basket.

**Explicitly NOT for:**
- `SP500.DWX` - not part of this card; the card is FX/metals session momentum.
- `NDX.DWX` - not part of this card; the card is FX/metals session momentum.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `110` |
| Typical hold time | Intraday, capped at 18 M5 bars (about 90 minutes) |
| Expected drawdown profile | High-frequency scalper with tight structural/ATR stops and fixed 1.6R targets. |
| Regime preference | Session momentum and volatility expansion. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** `https://www.forexfactory.com/thread/373796-genesis-matrix-trading`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9696_ff-genesis-matrix-m5.md`

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
| v1 | 2026-06-11 | Initial build from card | 11948f15-ea00-4ea9-b97f-bcdd33b05f2d |

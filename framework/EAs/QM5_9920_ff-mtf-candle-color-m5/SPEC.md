# QM5_9920_ff-mtf-candle-color-m5 - Strategy Spec

**EA ID:** QM5_9920
**Slug:** `ff-mtf-candle-color-m5`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades M5 candle-color momentum when the last completed M5 candle is the same color as the current M15, M30, and H1 candles. A long entry requires all four candles to be green; a short entry requires all four candles to be red. Entries are evaluated only once per completed M5 bar and are blocked outside the London through early New York session, when M15 ATR(14) is below its 60-bar 25th percentile, when spread is above the configured cap, or when the same direction traded within the last three completed M5 bars. Exits occur on the first completed M5 candle that flips against the position, at the fixed/ATR-capped SL and closest 15-pip-or-1.2R TP, or after twelve M5 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | 1-100 | ATR period used for M5 stop sizing and M15 volatility filter. |
| `strategy_atr_percentile_lookback` | 60 | 4-500 | Number of closed M15 ATR samples used for the volatility percentile filter. |
| `strategy_atr_min_percentile` | 25.0 | 0.0-100.0 | Minimum M15 ATR percentile required for new entries. |
| `strategy_fixed_sl_pips` | 15 | 1-100 | Base FX stop distance before ATR caps are applied. |
| `strategy_min_sl_atr_mult` | 0.8 | 0.1-10.0 | Lower ATR cap for the initial stop distance. |
| `strategy_max_sl_atr_mult` | 2.0 | 0.1-10.0 | Upper ATR cap for the initial stop distance. |
| `strategy_base_tp_pips` | 15 | 1-100 | Fixed TP candidate used against the 1.2R candidate. |
| `strategy_tp_rr` | 1.2 | 0.1-10.0 | Reward/risk TP candidate; the closer of this and fixed TP is used. |
| `strategy_extend_trigger_pips` | 12 | 1-100 | Profit threshold that allows the optional extended TP. |
| `strategy_extended_tp_pips` | 20 | 1-150 | Extended TP cap after a favorable move before color disagreement. |
| `strategy_min_same_dir_gap_bars` | 3 | 0-100 | Minimum completed M5 bars between same-direction entries. |
| `strategy_time_stop_bars` | 12 | 1-500 | Maximum holding time in M5 bars. |
| `strategy_session_start_hour` | 7 | 0-23 | Broker-hour start for London and early New York entry window. |
| `strategy_session_end_hour` | 16 | 0-23 | Broker-hour end for London and early New York entry window. |
| `strategy_max_spread_points` | 35 | 0-1000 | Maximum spread in points for new entries; 0 disables this entry guard. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - primary liquid FX major in the card's P2 basket.
- `GBPUSD.DWX` - liquid FX major with DWX M5/M15/M30/H1 OHLC and ATR data.
- `USDJPY.DWX` - liquid FX major with DWX M5/M15/M30/H1 OHLC and ATR data.
- `EURJPY.DWX` - liquid FX cross in the card's P2 basket.

**Explicitly NOT for:**
- `XAUUSD.DWX` - the card states XAUUSD is not in the primary basket and would need ATR-only stop handling if tested later.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `M15`, `M30`, `H1` current candle color plus `M15` ATR(14) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `160` |
| Typical hold time | `Up to 12 M5 bars; normally minutes to about one hour` |
| Expected drawdown profile | `Scalping-style frequent small losses controlled by fixed/ATR-capped stops` |
| Regime preference | `Multi-timeframe momentum during London and early New York liquidity` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** `https://www.forexfactory.com/thread/215160-simple-scalping-system-all-red-or-all-green`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9920_ff-mtf-candle-color-m5.md`

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
| v1 | 2026-06-11 | Initial build from card | 339e43f9-ddd9-4cad-8a8c-d865f619449e |

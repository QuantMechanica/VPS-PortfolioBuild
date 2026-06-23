# QM5_10843_tv-fracture-th - Strategy Spec

**EA ID:** QM5_10843
**Slug:** tv-fracture-th
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see TradingView open-source script citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA trades the M15 Fracture Threshold EMA score from the approved TradingView card. A long entry requires EMA(4) to cross above EMA(5) on the confirmed bar, at least 5 of 7 bullish MasterTrend conditions, a passing tick-volume regime, and an active London or New York session. A short entry mirrors the same rules with EMA(4) crossing below EMA(5) and at least 5 of 7 bearish MasterTrend conditions. The initial stop is 1.5 * ATR(14), the take profit is 3.0R, and there is no discretionary exit or trailing stop in the baseline.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_fast | 4 | 2-20 | Fast EMA used for the trigger cross and score condition. |
| strategy_ema_signal | 5 | 2-30 | Signal EMA used for the trigger cross and score condition. |
| strategy_rsi_period | 14 | 2-100 | RSI period for the RSI above or below 50 score condition. |
| strategy_ema_mid | 21 | 2-200 | Mid EMA used for close-vs-EMA and EMA-vs-SMA score checks. |
| strategy_sma_mid | 50 | 2-300 | SMA used in the MasterTrend moving-average stack. |
| strategy_ema_slow1 | 55 | 2-400 | First slow EMA in the MasterTrend stack. |
| strategy_ema_slow2 | 89 | 2-500 | Second slow EMA in the MasterTrend stack. |
| strategy_ema_baseline | 750 | 100-1500 | Long baseline EMA for the final price-vs-trend score condition. |
| strategy_min_score | 5 | 4-6 | Minimum bullish or bearish score out of 7 required for entry. |
| strategy_volume_gate_on | true | true/false | Enables the relative tick-volume regime filter. |
| strategy_vol_short | 5 | 1-100 | Short tick-volume moving-average length. |
| strategy_vol_long | 20 | 2-300 | Long tick-volume moving-average length. |
| strategy_vol_smooth | 14 | 1-100 | EMA smoothing length for short-volume-MA divided by long-volume-MA. |
| strategy_vol_threshold | 0.90 | 0.00-3.00 | Minimum smoothed volume ratio required for entry. |
| strategy_session_london_on | true | true/false | Enables the London session window. |
| strategy_london_start_hr | 10 | 0-23 | Broker-time start hour for the London window. |
| strategy_london_end_hr | 19 | 0-24 | Broker-time end hour for the London window. |
| strategy_session_ny_on | true | true/false | Enables the New York session window. |
| strategy_ny_start_hr | 16 | 0-23 | Broker-time start hour for the New York window. |
| strategy_ny_end_hr | 23 | 0-24 | Broker-time end hour for the New York window. |
| strategy_atr_period | 14 | 2-100 | ATR period for the initial stop distance. |
| strategy_atr_sl_mult | 1.5 | 0.1-10.0 | ATR multiplier for the initial stop. |
| strategy_reward_risk | 3.0 | 0.1-10.0 | Fixed take-profit multiple of initial risk. |
| strategy_spread_stop_frac | 0.15 | 0.0-1.0 | Entry is skipped when real spread exceeds this fraction of stop distance. |
| strategy_warmup_bars | 750 | 100-2000 | Minimum bar history required before trading because EMA(750) is part of the score. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid FX major with native DWX M15 OHLC, ATR, RSI, EMA/SMA, and tick volume.
- GBPUSD.DWX - liquid FX major matching the card's FX portability statement.
- XAUUSD.DWX - liquid metal CFD with DWX M15 data and tick volume.
- GDAXI.DWX - canonical DWX DAX symbol; used as the available matrix substitute for card-stated GER40.DWX.
- NDX.DWX - liquid US index CFD matching the card's index portability statement.

**Explicitly NOT for:**
- GER40.DWX - card-stated DAX alias is not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is the registered canonical DAX target.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX tester data guarantee.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | minutes to hours |
| Expected drawdown profile | Trend-confluence entries with fixed ATR stops can cluster losses during choppy low-trend periods. |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy script
**Pointer:** https://www.tradingview.com/script/NwMwuyA5-Fracture-Threshold-Strategy-JOAT/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10843_tv-fracture-th.md`

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
| v1 | 2026-06-23 | Initial build from card | 18784bb9-63b4-49c9-bd2e-303f517cc788 |

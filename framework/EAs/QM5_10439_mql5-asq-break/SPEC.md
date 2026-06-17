# QM5_10439_mql5-asq-break - Strategy Spec

**EA ID:** QM5_10439
**Slug:** mql5-asq-break
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades completed M5-bar breakouts only during the 08:00-20:00 broker-time session. A long entry requires EMA(150) above EMA(510), EMA separation greater than 0.5 x ATR(14), the close above both EMAs, a close above the prior 20-bar high plus 0.25 x ATR(14), RSI(14) between 40 and 65, bullish candle momentum, and H1 EMA(50) above EMA(200). A short entry mirrors the same seven conditions with EMA direction down, a close below the prior 20-bar low minus 0.25 x ATR(14), RSI(14) between 35 and 60, bearish candle momentum, and H1 EMA(50) below EMA(200). Exits are the fixed 2.0R take profit, the ATR stop, the framework Friday close, and a move to breakeven after price reaches +1R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_fast_ema_period | 150 | >= 1 | Fast M5 EMA for primary trend direction. |
| strategy_slow_ema_period | 510 | > fast EMA | Slow M5 EMA for primary trend direction. |
| strategy_atr_period | 14 | >= 1 | ATR period used for separation, breakout buffer, stop, and spread filter. |
| strategy_ema_atr_sep_mult | 0.5 | > 0 | Minimum EMA separation as a multiple of M5 ATR. |
| strategy_breakout_lookback | 20 | >= 1 | Prior-bar range length used for high and low breakout levels. |
| strategy_breakout_atr_buffer | 0.25 | >= 0 | ATR buffer added to the breakout high or low. |
| strategy_long_rsi_min | 40.0 | 0-100 | Lower bound for long RSI zone. |
| strategy_long_rsi_max | 65.0 | 0-100 | Upper bound for long RSI zone. |
| strategy_short_rsi_min | 35.0 | 0-100 | Lower bound for short RSI zone. |
| strategy_short_rsi_max | 60.0 | 0-100 | Upper bound for short RSI zone. |
| strategy_htf_filter_enabled | true | true/false | Enables the baseline H1 EMA agreement filter. |
| strategy_htf | PERIOD_H1 | MT5 timeframe | Higher timeframe used for EMA agreement. |
| strategy_htf_fast_ema_period | 50 | >= 1 | Fast H1 EMA for higher-timeframe agreement. |
| strategy_htf_slow_ema_period | 200 | > fast EMA | Slow H1 EMA for higher-timeframe agreement. |
| strategy_sl_atr_mult | 1.2 | > 0 | Stop distance as a multiple of M5 ATR. |
| strategy_h1_sl_cap_atr_mult | 3.0 | > 0 | Maximum stop distance as a multiple of H1 ATR. |
| strategy_take_rr | 2.0 | > 0 | Take-profit multiple of the stop distance. |
| strategy_be_trigger_r | 1.0 | > 0 | Breakeven trigger measured in initial risk units. |
| strategy_session_start_hour | 8 | 0-23 | Broker-time session start hour for new trading. |
| strategy_session_end_hour | 20 | 1-24 | Broker-time session end hour for new trading. |
| strategy_max_spread_atr_frac | 0.15 | >= 0 | Blocks entry when modeled spread exceeds this fraction of M5 ATR. |
| strategy_friday_cutoff_hour | 16 | 0-23 | Friday broker-time hour after which new entries are blocked. |
| strategy_max_entries_per_day | 3 | >= 1 | Maximum same-symbol same-magic entries per broker day. |

---

## 3. Symbol Universe

**Designed for:**
- XAUUSD.DWX - Card-listed gold CFD, suitable for intraday trend breakout testing.
- EURUSD.DWX - Card-listed major FX pair, suitable for liquid M5 breakout testing.
- GBPUSD.DWX - Card-listed major FX pair, suitable for liquid M5 breakout testing.
- XAGUSD.DWX - Card-listed silver CFD, suitable for intraday metals breakout testing.

**Explicitly NOT for:**
- SP500.DWX - Not in this card's R3 FX/metals basket.
- NDX.DWX - Not in this card's R3 FX/metals basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | H1 EMA(50), H1 EMA(200), H1 ATR(14) stop cap |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Intraday, minutes to hours |
| Expected drawdown profile | Controlled by ATR stop, 2.0R target, 1R breakeven, and daily entry cap. |
| Regime preference | Breakout with trend and momentum confirmation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/71189
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10439_mql5-asq-break.md`

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
| v1 | 2026-06-18 | Initial build from card | 16b51075-0b30-4dbf-b472-15ceeee7db6d |

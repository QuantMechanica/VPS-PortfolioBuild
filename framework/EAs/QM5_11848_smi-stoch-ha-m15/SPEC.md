# QM5_11848_smi-stoch-ha-m15 — Strategy Spec

**EA ID:** QM5_11848
**Slug:** smi-stoch-ha-m15
**Source:** 9d97eec6-6cfc-5561-885f-067424721621 (see approved card artifact)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades M15 momentum reversals on JPY crosses. A long setup requires the custom SMI line to curl upward from the -40 zone or cross upward through zero, EMA(5) to cross above EMA(6), the closed Heiken Ashi candle to be white, and Stochastic(10,1,7) to be rising from 20 or lower; the oscillator and EMA trigger events may occur within a short closed-bar lookback to avoid exact same-bar starvation. A short setup mirrors those rules from the +40 zone or a zero-line cross, with EMA(5) crossing below EMA(6), a red Heiken Ashi candle, and Stochastic falling from 80 or higher. Exits occur when SMI reaches the opposite target zone, price touches EMA(60), the fixed 30-50 pip target is hit, the swing/volatility stop is hit, or the framework Friday close fires.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| smi_hl_period | 14 | 5-50 | High/low lookback for the custom SMI calculation. |
| smi_smooth1 | 10 | 2-50 | First EMA smoothing pass for SMI numerator and denominator. |
| smi_smooth2 | 14 | 2-50 | Second EMA smoothing pass for SMI numerator and denominator. |
| smi_signal_period | 5 | 1-20 | Final SMI signal smoothing period from the card tuple. |
| smi_extreme | 40.0 | 10-80 | SMI target and extreme threshold. |
| ema_fast_period | 5 | 2-50 | Fast EMA for the entry bias. |
| ema_slow_period | 6 | 2-50 | Slow EMA for the entry bias. |
| ema_exit_period | 60 | 10-200 | EMA touch exit reference. |
| ema_trend_period | 200 | 50-400 | Warmup trend EMA from the card tuple. |
| stoch_k_period | 10 | 3-50 | Stochastic K period. |
| stoch_d_period | 1 | 1-20 | Stochastic D period. |
| stoch_slowing | 7 | 1-20 | Stochastic slowing period. |
| stoch_lo | 20.0 | 1-50 | Oversold threshold for long confirmation. |
| stoch_hi | 80.0 | 50-99 | Overbought threshold for short confirmation. |
| signal_lookback_bars | 3 | 1-6 | Closed bars over which EMA, SMI, and Stochastic trigger events may align. |
| swing_lookback_bars | 8 | 2-30 | Closed bars used for previous swing stop placement. |
| atr_period | 14 | 2-100 | ATR period for the volatility stop floor. |
| sl_atr_mult | 2.0 | 0.5-10.0 | ATR multiplier for the minimum stop distance. |
| hard_sl_pips | 25 | 5-100 | Fixed-pip minimum hard stop before ATR widening. |
| tp_pips | 40 | 30-50 | Fixed profit target in the source's stated 30-50 pip zone. |
| breakeven_trigger_pips | 20 | 18-22 | Profit in pips before moving SL to breakeven. |
| breakeven_buffer_pips | 2 | 0-10 | Positive buffer used for the breakeven SL move. |
| session_start_utc_hour | 7 | 0-23 | Earliest UTC hour for entries. |
| spread_pct_of_stop | 15.0 | 0-100 | Blocks only genuinely wide spreads relative to stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURJPY.DWX — explicitly named by the card and present in the DWX matrix.
- GBPJPY.DWX — explicitly named by the card and present in the DWX matrix.

**Explicitly NOT for:**
- Non-JPY FX pairs — the source and card target JPY-cross M15 behavior.
- Indices, metals, and energy symbols — not part of the card's R3 portable basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Intraday, usually minutes to hours |
| Expected drawdown profile | Moderate, bounded by swing/ATR stop and breakeven rule |
| Regime preference | Intraday momentum reversal with short trend follow-through |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 9d97eec6-6cfc-5561-885f-067424721621
**Source type:** forex strategy PDF
**Pointer:** forexstrategiesresources.com, "Easy 15min Trading System #301", source PDF `353827940-Easy-15min-Trading-System-Forex-Strategies.pdf`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11848_smi-stoch-ha-m15.md`

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
| v1 | 2026-06-20 | Initial build from card | 89ad45a9-79fd-4f7d-8b56-e38c0f835a83 |

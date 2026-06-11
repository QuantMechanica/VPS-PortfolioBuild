# QM5_9957_ff-tf15-tdi-10ema-m15 - Strategy Spec

**EA ID:** QM5_9957
**Slug:** ff-tf15-tdi-10ema-m15
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades the ForexFactory TF15 EURUSD/GBPUSD M15 method. A long entry is allowed only when the last closed M15 bar is above EMA(200), has crossed from at-or-below to above EMA(10), the EMA(10) slope over three bars is positive, and the TDI green RSI line crosses above the yellow market-base line. Shorts mirror the same rules below EMA(200), below EMA(10), with negative EMA(10) slope and a bearish TDI cross. The EA uses a 20-pip stop unless that distance is outside the card's ATR(14) bounds, then uses 1.0 ATR; take profit is 1.0R, break-even is applied after 12 pips, and positions exit early on a TDI cross back against the trade.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_fast_ema_period | 10 | 1-200 | EMA used for the close-above or close-below trigger. |
| strategy_side_ema_period | 200 | 1-1000 | EMA side filter; no longs below it and no shorts above it. |
| strategy_far_ema_period | 800 | 1-2000 | Far EMA used for the EMA(200)-EMA(800) separation filter. |
| strategy_slope_bars | 3 | 1-20 | Bars used to confirm EMA(10) slope direction. |
| strategy_tdi_rsi_period | 13 | 2-100 | RSI period for the TDI line calculation. |
| strategy_tdi_green_smooth | 2 | 1-20 | Smoothing length for the TDI green line. |
| strategy_tdi_yellow_smooth | 34 | 2-100 | Smoothing length for the TDI yellow market-base line. |
| strategy_atr_period | 14 | 1-100 | ATR period for the stop fallback and EMA-separation filter. |
| strategy_stop_pips | 20 | 1-200 | Source fixed stop distance in pips. |
| strategy_atr_min_mult | 0.7 | 0.1-5.0 | Lower ATR multiple bound for accepting the fixed stop. |
| strategy_atr_max_mult | 1.5 | 0.1-5.0 | Upper ATR multiple bound for accepting the fixed stop. |
| strategy_atr_fallback_mult | 1.0 | 0.1-5.0 | ATR multiple used when the fixed stop is outside bounds. |
| strategy_take_profit_rr | 1.0 | 0.1-10.0 | Take-profit multiple of initial risk. |
| strategy_be_trigger_pips | 12 | 1-200 | Profit in pips required before moving SL to break-even. |
| strategy_be_buffer_pips | 0 | 0-50 | Extra pips beyond entry when moving to break-even. |
| strategy_session_start_minutes | 480 | 0-1439 | Broker-time session start in minutes from midnight, 08:00. |
| strategy_session_end_minutes | 990 | 0-1439 | Broker-time session end in minutes from midnight, 16:30. |
| strategy_ema_sep_atr_mult | 0.5 | 0.0-10.0 | Minimum EMA(200)-EMA(800) separation as ATR multiple. |
| strategy_max_spread_stop_frac | 0.12 | 0.0-1.0 | Maximum spread as a fraction of selected stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Source pair named in the card and directly available in the DWX matrix.
- GBPUSD.DWX - Source pair named in the card and directly available in the DWX matrix.

**Explicitly NOT for:**
- Non-FX index, commodity, and cross-asset symbols - the source method is specified for EURUSD and GBPUSD M15 first, with pip-based FX-major stop and break-even conventions.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) through the framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 75 |
| Expected trade frequency | London-session M15 10EMA/TDI setup on EU/GU; estimate 50-100 trades/year/symbol after 200EMA side and session filters. |
| Typical hold time | Not specified in frontmatter; intraday M15 trades expected to hold minutes to hours until 1R, break-even, or TDI cross-back. |
| Expected drawdown profile | Fixed 1R stop with break-even after 12 pips; drawdown should cluster during choppy EMA-compression regimes, which are filtered by EMA(200)-EMA(800) separation. |
| Regime preference | Intraday trend-pullback and momentum continuation during London through early New York. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** https://www.forexfactory.com/thread/345586-another-simple-system-time-frame-15
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9957_ff-tf15-tdi-10ema-m15.md`

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
| v1 | 2026-06-11 | Initial build from card | b2844372-0760-43d1-b0b9-95dd96afc988 |

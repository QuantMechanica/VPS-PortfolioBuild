# QM5_10368_et-ema-stop - Strategy Spec

**EA ID:** QM5_10368
**Slug:** et-ema-stop
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades intraday index bars on M5. When the last closed bar crosses above EMA(200), it places a buy-stop at that bar's high plus 6 ticks; when the last closed bar crosses below EMA(200), it places a sell-stop at that bar's low minus 6 ticks. Each pending stop expires at the 16:00 broker-time session end, and any open position is closed after the session end if SL/TP has not already closed it. Profit target is 1.5 ATR(14), protective stop is 1.0 ATR(14), and the EA skips entries when the stop is too tight relative to spread.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_ema_period | 200 | 2+ | EMA length used for the cross trigger. |
| strategy_atr_period | 14 | 1+ | ATR lookback for SL and TP distances. |
| strategy_trigger_ticks | 6.0 | >0 | Stop-entry offset from the signal bar high or low, in symbol ticks. |
| strategy_stop_atr_mult | 1.0 | >0 | Protective stop distance as ATR multiple. |
| strategy_target_atr_mult | 1.5 | >0 | Profit target distance as ATR multiple. |
| strategy_session_start_hhmm | 800 | 0000-2359 | Broker-time session start for new entries. |
| strategy_session_end_hhmm | 1600 | 0000-2359 | Broker-time session end for order expiry and EOD exit. |
| strategy_spread_lookback | 64 | 1-64 | Rolling spread sample count for the median spread filter. |
| strategy_spread_median_mult | 2.5 | >0 | Maximum current spread as a multiple of rolling median spread. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 index-CFD port of ES/SPX-style source logic; backtest-only per DWX discipline.
- NDX.DWX - Liquid US large-cap index CFD, live-tradable basket member.
- WS30.DWX - Liquid US large-cap index CFD, live-tradable basket member.
- GDAXI.DWX - Matrix-backed DAX custom symbol used as the DWX equivalent for the card's GER40 target.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; ported to GDAXI.DWX.
- SPX500.DWX / SPY.DWX / ES.DWX - Not canonical DWX custom symbols for S&P 500 exposure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Typical hold time | Intraday, from stop trigger until ATR target, ATR stop, or 16:00 broker-time session exit |
| Expected drawdown profile | Whipsaw-prone around EMA(200), bounded by one ATR hard stop per trade |
| Regime preference | Intraday trend-continuation and volatility expansion after EMA cross |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/easylanguage-code.251026/ posts #4-#5
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10368_et-ema-stop.md`

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
| v1 | 2026-05-25 | Initial build from card | 6bf1b693-2d6e-4ea0-a6d3-c01b7f0f6ab8 |

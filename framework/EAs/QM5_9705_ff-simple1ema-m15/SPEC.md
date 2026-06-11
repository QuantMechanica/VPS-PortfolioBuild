# QM5_9705_ff-simple1ema-m15 - Strategy Spec

**EA ID:** QM5_9705
**Slug:** ff-simple1ema-m15
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see ForexFactory source citation in approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades completed M15 bars around EMA(9). A long signal forms when a recent bar closed above EMA(9), and within the next four bars the candidate bar is fully pulled away above the EMA by at least 5 pips and closes above the prior bar high. A short signal mirrors the rule below the EMA, with the candidate high at least 5 pips below EMA(9) and the close below the prior bar low.

Entries are market orders on the next bar after the candidate close. The stop is placed beyond the candidate candle by 1 pip plus spread, trades with less than 10 pips stop distance are rejected, the target is 2R, and open positions exit after 20 M15 bars or when a completed bar closes back across EMA(9) against the position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_period | 9 | >=1 | EMA period used for setup, pull-away, and recross exit. |
| strategy_atr_period | 14 | >=1 | ATR period used for the entry-gap and slope filters. |
| strategy_setup_expiry_bars | 4 | >=1 | Maximum bars after an EMA-side setup close for a candidate signal. |
| strategy_pullaway_pips | 5.0 | >0 | Minimum candidate candle distance from EMA(9). |
| strategy_sl_buffer_pips | 1.0 | >=0 | Extra stop buffer beyond the candidate candle before adding spread. |
| strategy_min_sl_pips | 10.0 | >0 | Minimum allowed stop distance. |
| strategy_gap_atr_mult | 0.35 | >=0 | Rejects entry-bar gaps larger than this multiple of ATR(14). |
| strategy_slope_bars | 5 | >=1 | EMA lookback for the horizontal-MA filter. |
| strategy_slope_atr_mult | 0.10 | >=0 | Minimum absolute EMA slope as a multiple of ATR(14). |
| strategy_rr_target | 2.0 | >0 | Take-profit multiple of initial risk. |
| strategy_max_hold_bars | 20 | >=0 | Maximum holding time in M15 bars; 0 disables the time stop. |
| strategy_session_start_h | 7 | 0-23 | Broker hour when the liquid-session window starts. |
| strategy_session_end_h | 20 | 0-23 | Broker hour when the liquid-session window ends. |
| strategy_max_spread_pips | 3.0 | >=0 | Maximum spread allowed for new trades; 0 disables the spread filter. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed major FX symbol with native DWX coverage.
- GBPUSD.DWX - Card-listed major FX symbol with native DWX coverage.
- USDJPY.DWX - Card-listed major FX symbol with native DWX coverage.
- XAUUSD.DWX - Card-listed liquid metal symbol with native DWX coverage.

**Explicitly NOT for:**
- Other DWX symbols - Not listed in the approved card for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 75 |
| Typical hold time | Intraday, maximum 20 M15 bars (about 5 hours) unless SL/TP/EMA recross exits first. |
| Expected drawdown profile | Moderate intraday momentum drawdown controlled by fixed initial stop and 2R target. |
| Regime preference | Intraday momentum / EMA breakout after pull-away confirmation. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** Feliks, "Simple 1 EMA Strategy on M15", ForexFactory, 2010-06-23, https://www.forexfactory.com/thread/242787-simple-1-ema-strategy-on-m15
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9705_ff-simple1ema-m15.md`

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
| v1 | 2026-06-11 | Initial build from card | e42779d0-d442-4fff-9c9a-8b02c8251e54 |

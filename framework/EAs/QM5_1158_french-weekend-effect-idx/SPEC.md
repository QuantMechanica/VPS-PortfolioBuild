# QM5_1158_french-weekend-effect-idx - Strategy Spec

**EA ID:** QM5_1158
**Slug:** french-weekend-effect-idx
**Source:** afab7a6f-c3c8-51ae-a609-f376744beb8e
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

This EA trades a deterministic weekly equity-index calendar rule. It opens one long position at the Tuesday session open, or the next available Wednesday/Thursday session if Tuesday does not trade, and closes the position near the Friday session close. The stop is ATR(D1,14) x 3 below entry, and the EA stays flat through the weekend and Monday.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_entry_day_of_week | 2 | 1-5 | Tuesday entry day using MQL5 day-of-week numbering. |
| strategy_latest_entry_day | 4 | 2-5 | Last allowed fallback entry day if Tuesday has no tradable session. |
| strategy_exit_day_of_week | 5 | 1-5 | Friday scheduled time-stop exit day. |
| strategy_fallback_exit_day | 4 | 1-5 | Thursday fallback exit if the symbol has no scheduled Friday session. |
| strategy_entry_window_minutes | 90 | 1-240 | Window after session open in which a weekly entry may fire. |
| strategy_exit_before_close_min | 30 | 1-240 | Minutes before session close to force the weekly time-stop exit. |
| strategy_atr_period | 14 | 2-100 | D1 ATR period used for the hard stop. |
| strategy_atr_stop_mult | 3.0 | 0.1-10.0 | ATR multiple below entry for the hard stop. |
| strategy_block_news_wed_fri | true | true/false | Skip the weekly entry when high-impact news affects the symbol on Wed-Fri. |
| strategy_require_m30_execution | true | true/false | Require M30 execution timeframe as specified by the card. |
| strategy_max_spread_points | 0 | 0+ | Optional spread cap; 0 disables the cap. |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - Nasdaq 100 index CFD in the approved R3 basket.
- WS30.DWX - Dow 30 index CFD in the approved R3 basket.
- GDAXI.DWX - DAX 40 index CFD in the approved R3 basket.
- UK100.DWX - FTSE 100 index CFD in the approved R3 basket.
- SP500.DWX - S&P 500 custom symbol from the approved R3 basket; backtest-only T6 caveat applies.

**Explicitly NOT for:**
- Non-index `.DWX` symbols - the source edge is an equity-index day-of-week anomaly.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M30 |
| Multi-timeframe refs | D1 ATR for stop sizing |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 52 |
| Typical hold time | About 4 trading days |
| Expected drawdown profile | Weekly index exposure with ATR-defined loss per cycle and portfolio MAX_DD protection from the framework. |
| Regime preference | Calendar seasonality / equity-index weekly bias |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** afab7a6f-c3c8-51ae-a609-f376744beb8e
**Source type:** paper
**Pointer:** D:/QM/strategy_farm/artifacts/cards_approved/QM5_1158_french-weekend-effect-idx.md
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1158_french-weekend-effect-idx.md`

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
| v1 | 2026-06-12 | Initial build from card | b15a3fa0-c209-4714-975d-37b27dad4f57 |

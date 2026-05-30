# QM5_10417_et-pricepivot-x - Strategy Spec

**EA ID:** QM5_10417
**Slug:** et-pricepivot-x
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

This EA computes the prior-day floor pivot as `(PriorDayHigh + PriorDayLow + PriorDayClose) / 3`. During the 08:30-15:55 broker-time session, it buys when the completed M1 close crosses above that pivot and sells when the completed M1 close crosses below it. Each entry uses a stop at `0.4 * ATR(20, M1)`, a target at `0.8 * ATR(20, M1)`, rejects trades where stop distance is less than four current spreads, and closes any remaining open position after the session window.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_session_start_hhmm | 830 | 0-2359 | Broker-time session start for new entries. |
| strategy_session_end_hhmm | 1555 | 0-2359 | Broker-time session end for new entries and forced flat close. |
| strategy_atr_period | 20 | 1+ | ATR period on the chart timeframe. |
| strategy_sl_atr_mult | 0.4 | >0 | Stop distance as a multiple of ATR. |
| strategy_tp_atr_mult | 0.8 | >0 | Target distance as a multiple of ATR. |
| strategy_min_stop_spreads | 4.0 | >=0 | Minimum stop distance in current spread multiples. |
| strategy_max_entries_per_direction_per_session | 2 | 1+ | Initial entry plus one re-entry per direction per session. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 custom symbol named in the card R3 basket.
- NDX.DWX - Nasdaq 100 index exposure named in the card R3 basket.
- WS30.DWX - Dow 30 index exposure named in the card R3 basket.
- GDAXI.DWX - Canonical DWX DAX symbol used for the card's GER40.DWX target.
- XAUUSD.DWX - Gold exposure named in the card R3 basket.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; ported to GDAXI.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M1 |
| Multi-timeframe refs | PERIOD_D1 prior-day high, low, and close for pivot calculation |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Intraday, from entry until SL, TP, or 15:55 broker-time session close |
| Expected drawdown profile | Churn risk around the pivot, controlled by spread and bracket exits |
| Regime preference | Session-window price-level cross |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/ninjatrader-7-code.309172/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10417_et-pricepivot-x.md`

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
| v1 | 2026-05-25 | Initial build from card | 40d5b453-3e22-4acb-9fd7-414b15038738 |

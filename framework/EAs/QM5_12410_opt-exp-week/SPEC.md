# QM5_12410_opt-exp-week - Strategy Spec

**EA ID:** QM5_12410
**Slug:** opt-exp-week
**Source:** b7832a20-938e-5f24-b9d7-e0b2ab63b623
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades a deterministic monthly calendar effect around standard US equity option expiration. It opens a long index CFD position on the Monday before the third-Friday expiration date when at least three tradable weekdays remain. It stays flat outside the expiration-week window and closes any open position after that window ends, with an emergency stop at 1.5 times ATR(20) on D1.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_entry_offset_calendar_days | 4 | 0-7 | Calendar-day distance from expiration date required for entry; 4 maps to Monday before Friday expiration. |
| strategy_min_tradable_days_remaining | 3 | 1-5 | Minimum weekday count from entry date through expiration date. |
| strategy_atr_period | 20 | 1-200 | D1 ATR period used for the emergency stop. |
| strategy_atr_sl_mult | 1.5 | 0.1-10.0 | ATR multiplier for the emergency stop distance. |
| strategy_median_spread_60d_points | 0.0 | 0.0+ | User-supplied 60-day median spread in points; zero leaves the cap inactive for DWX zero-spread tests. |
| strategy_spread_median_mult | 2.0 | 0.1-10.0 | Multiplier applied to median spread to form the spread cap. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 custom symbol matches the card's primary US large-cap index exposure.
- NDX.DWX - Nasdaq 100 is part of the approved portable US large-cap DWX basket.
- WS30.DWX - Dow 30 is part of the approved portable US large-cap DWX basket.

**Explicitly NOT for:**
- SPX500.DWX - not present in `dwx_symbol_matrix.csv`; SP500.DWX is the canonical S&P 500 custom symbol.
- SPY.DWX - not present in `dwx_symbol_matrix.csv`; the EA trades index CFDs, not ETF symbols.
- ES.DWX - not present in `dwx_symbol_matrix.csv`; futures execution is outside this card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | About 4-5 calendar days, Monday through expiration Friday |
| Expected drawdown profile | Sparse calendar exposure with event-specific equity gap risk |
| Regime preference | Calendar seasonality in index exposure |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b7832a20-938e-5f24-b9d7-e0b2ab63b623
**Source type:** public implementation / catalog strategy
**Pointer:** https://github.com/paperswithbacktest/awesome-systematic-trading/blob/main/static/strategies/option-expiration-week-effect.py
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_12410_opt-exp-week.md`

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
| v1 | 2026-06-18 | Initial build from card | 9595e125-f2e2-4ae6-9471-edf52c6f1c7b |

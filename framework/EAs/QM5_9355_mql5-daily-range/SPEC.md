# QM5_9355_mql5-daily-range - Strategy Spec

**EA ID:** QM5_9355
**Slug:** mql5-daily-range
**Source:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

At the start of each trading day the EA uses the previous completed D1 candle high and low as the breakout range. On each closed H1 bar, it opens long when the bar closes above the previous-day high and opens short when the bar closes below the previous-day low, with only the first valid signal per symbol per day accepted. The stop is the closer valid stop between recent H1 structure and the opposite previous-day range boundary; the take profit is set at 2R. If neither stop nor target is reached, the position is closed at the end of the broker trading day.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_swing_lookback_bars | 6 | 1-100 | Closed H1 bars used by `QM_StopStructure` for the recent swing stop candidate. |
| strategy_take_profit_rr | 2.0 | >0 | Reward-to-risk multiple used by `QM_TakeRR` for the primary target. |
| strategy_end_of_day_exit | true | true/false | Enables the card-specified end-of-day discretionary close. |
| strategy_eod_close_hour | 23 | 0-23 | Broker hour at or after which same-day open positions are closed if still active. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-stated FX target with full OHLC availability in the DWX matrix.
- GBPUSD.DWX - card-stated FX target with full OHLC availability in the DWX matrix.
- XAUUSD.DWX - card-stated metal target with full OHLC availability in the DWX matrix.
- GDAXI.DWX - DAX 40 DWX matrix symbol used as the available equivalent for card-stated GER40.DWX.

**Explicitly NOT for:**
- GER40.DWX - absent from `framework/registry/dwx_symbol_matrix.csv`; use GDAXI.DWX for this card's DAX exposure.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not valid for DWX backtest registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | PERIOD_D1 previous-day high and low |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Intraday, normally hours and no later than broker end-of-day close |
| Expected drawdown profile | Breakout whipsaw losses during range-bound sessions; winners capped by 2R target |
| Regime preference | Breakout / volatility expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Source type:** MQL5 article
**Pointer:** Allan Munene Mutiiria, "Creating an MQL5 Expert Advisor Based on the Daily Range Breakout Strategy", MQL5 Articles, 2024-10-21, https://www.mql5.com/en/articles/16135
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9355_mql5-daily-range.md`

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
| v1 | 2026-06-23 | Initial build from card | c1f3db61-a3ad-4c26-af56-4ecc72a22c71 |

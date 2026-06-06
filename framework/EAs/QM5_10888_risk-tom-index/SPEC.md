# QM5_10888_risk-tom-index - Strategy Spec

**EA ID:** QM5_10888
**Slug:** risk-tom-index
**Source:** 8ef51a3a-ad3e-53af-90b6-e0fb4c8f5b38
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades a long-only index turn-of-month window. After each D1 close, it enters long at the next market open when the just-closed trading day has two scheduled trading sessions remaining in the same month. It skips entry when ATR(20,D1) is above the 95th percentile of the prior 252 ATR samples, places an initial stop at 1.75 times ATR(20,D1), and exits near the close of the second trading day of the new month.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_atr_period | 20 | 1+ | D1 ATR period used for the stop and volatility filter. |
| strategy_atr_stop_mult | 1.75 | greater than 0 | Multiplier for the initial ATR stop. |
| strategy_atr_percentile_lookback | 252 | 20+ | Prior ATR sample count for the volatility percentile filter. |
| strategy_atr_skip_percentile | 95.0 | 1.0-99.9 | Entry is skipped when current ATR is above this percentile. |
| strategy_entry_days_before_month_end | 2 | 1+ | Number of remaining trading days in the month after the signal day. |
| strategy_exit_trading_day_of_month | 2 | 1+ | Trading-day ordinal in the new month used for calendar exit. |
| strategy_max_spread_points | 0 | 0+ | Optional spread cap in points; 0 disables the cap. |
| strategy_require_d1_period | true | true/false | Blocks trading unless the chart/test period is D1. |

---

## 3. Symbol Universe

**Designed for:**
- GDAXI.DWX - DAX index CFD port for the card's GER40.DWX target, which is not present in the DWX matrix.
- NDX.DWX - Nasdaq 100 index exposure from the approved R3 basket.
- WS30.DWX - Dow 30 index exposure from the approved R3 basket.
- SP500.DWX - S&P 500 custom symbol exposure from the approved R3 basket; backtest-only per OWNER caveat.

**Explicitly NOT for:**
- GER40.DWX - Card-stated DAX name is not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is the registered DWX equivalent.
- SPX500.DWX - Not the canonical S&P 500 custom symbol.
- SPY.DWX - Not available as a DWX broker/custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | About four trading days, from the next open after T-2 month-end signal through the close of the second trading day of the new month. |
| Expected drawdown profile | Gap exposure during a short monthly index holding window. |
| Regime preference | Calendar seasonality / turn-of-month index drift. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 8ef51a3a-ad3e-53af-90b6-e0fb4c8f5b38
**Source type:** article
**Pointer:** John Ferry, "A return to simplicity", Risk.net, 2008-02-01
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10888_risk-tom-index.md`

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
| v1 | 2026-06-06 | Initial build from card | 5e6f9ef2-0db5-45a4-9bca-d7b0654077b0 |

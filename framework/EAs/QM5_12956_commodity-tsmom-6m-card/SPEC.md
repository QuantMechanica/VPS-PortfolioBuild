# QM5_12956_commodity-tsmom-6m-card - Strategy Spec

**EA ID:** QM5_12956
**Slug:** commodity-tsmom-6m-card
**Source:** MOP-TSMOM-2012
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

This EA trades WTI crude oil time-series momentum on `XTIUSD.DWX` only. On the first D1 bar of a new broker-calendar month, it computes the log return from the latest completed D1 close to the close 126 completed D1 bars earlier. It buys when that return is above 2.0 percent, sells when it is below -2.0 percent, and otherwise stays flat. Any open package is closed on the next monthly rebalance bar or after 31 calendar days, with a hard stop set at 3.0 times ATR(20).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_momentum_lookback_d1` | 126 | 105, 126, 147 | Completed D1 bars used for the six-month momentum return. |
| `strategy_min_abs_return_pct` | 2.0 | 0.5, 1.0, 2.0, 3.5 | Minimum absolute log return percent needed to open long or short. |
| `strategy_atr_period` | 20 | 14, 20, 30 | D1 ATR period used for the hard stop. |
| `strategy_atr_sl_mult` | 3.0 | 2.5, 3.0, 4.0 | ATR multiplier for the initial stop-loss distance. |
| `strategy_max_hold_days` | 31 | 21, 31, 45 | Maximum calendar days to hold an open package. |
| `strategy_max_spread_points` | 1000 | 700, 1000, 1500 | Entry is skipped when the symbol spread is above this point cap. |

---

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` - Darwinex WTI crude oil CFD, matching the card's single-symbol WTI momentum target and present in `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- `XAUUSD.DWX` - gold is not part of this single-symbol WTI card.
- `XNGUSD.DWX` - natural gas is explicitly excluded by the card.
- Other commodities or index CFDs - the card sets `single_symbol_only: true`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 9 |
| Typical hold time | Monthly package, up to 31 calendar days |
| Expected drawdown profile | Medium-high; card expectation around 18 percent drawdown |
| Regime preference | Intermediate WTI trend / commodity trend premium |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** MOP-TSMOM-2012
**Source type:** paper
**Pointer:** https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12956_commodity-tsmom-6m-card.md`

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
| v1 | 2026-07-07 | Initial build from card | 7ccf23b8-5df8-4527-8cbb-40453d657774 |

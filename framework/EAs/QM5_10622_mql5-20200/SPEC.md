# QM5_10622_mql5-20200 - Strategy Spec

**EA ID:** QM5_10622
**Slug:** `mql5-20200`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see approved card citation)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA evaluates one H1 bar per day at 18:00 GMT. It computes `Open[t2] - Open[t1]` using the source defaults `t2=2` and `t1=7`; if the difference is at least 70 points it opens a market long, and if the difference is at most -70 points it opens a market short. Each entry uses the source fixed protective levels of 2000 stop-loss points and 200 take-profit points. There is no discretionary strategy exit beyond the fixed SL/TP and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_trade_hour_gmt` | 18 | 0-23 | GMT hour when the daily H1 check is allowed to open a trade. |
| `strategy_t1_shift` | 7 | >=1 | Older H1 open-price shift in the source difference formula. |
| `strategy_t2_shift` | 2 | >=1 | Newer H1 open-price shift in the source difference formula. |
| `strategy_delta_points` | 70 | >0 | Minimum open-price difference in points required for an entry. |
| `strategy_take_profit_points` | 200 | >0 | Fixed take-profit distance in symbol points. |
| `strategy_stop_loss_points` | 2000 | >0 | Fixed stop-loss distance in symbol points. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - source baseline EURUSD H1 pair and direct DWX match.
- `GBPUSD.DWX` - liquid FX major using the same OHLC and clock-time inputs.
- `USDJPY.DWX` - liquid FX major using the same OHLC and clock-time inputs.
- `XAUUSD.DWX` - liquid metal CFD using the same OHLC and clock-time inputs.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX data-backed registration target.
- Non-H1 runs - the source rule is specified on H1 and the EA blocks other chart periods.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | Hours to days, until fixed SL/TP or Friday close. |
| Expected drawdown profile | Wide fixed stop means individual losing trades can be materially larger than winners; downstream gates must judge distribution quality. |
| Regime preference | Price-momentum continuation after the scheduled open-price difference threshold. |
| Win rate target (qualitative) | Medium to high, implied by the asymmetric 200-point TP versus 2000-point SL source design. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** Pavel Smirnov / autoforex, "20/200 pips - Simple profitable Expert Advisor", https://www.mql5.com/en/code/214
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10622_mql5-20200.md`

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
| v1 | 2026-05-31 | Initial build from card | b311664c-bf58-4e41-96de-aff1d7cc93f4 |

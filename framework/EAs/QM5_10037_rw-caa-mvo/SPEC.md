# QM5_10037_rw-caa-mvo - Strategy Spec

**EA ID:** QM5_10037
**Slug:** rw-caa-mvo
**Source:** dcbac84f-6ecf-5d21-9630-50faa69306ec
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

At the start of each month, the EA reads the last four complete monthly returns for SP500.DWX, NDX.DWX, WS30.DWX, and XAUUSD.DWX. It enumerates long-only portfolio allocations in 10 percent steps with total allocation no greater than 100 percent, then selects the highest average monthly return candidate whose annualized volatility is at or below 10 percent. Each chart instance opens a long position only if its own selected allocation is above zero; monthly rebalancing closes the prior position and re-enters if the new allocation remains positive.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_lookback_months | 4 | 3-12 | Number of complete monthly returns used for allocation selection. |
| strategy_target_vol_pct | 10.0 | >0 | Annualized volatility ceiling for eligible allocation candidates. |
| strategy_grid_step_pct | 10 | 10-100 | Allocation grid step in percent; the card baseline is 10 percent. |
| strategy_atr_period | 20 | >1 | D1 ATR period for catastrophic stop placement. |
| strategy_atr_sl_mult | 4.0 | >0 | ATR multiple for the per-symbol catastrophic stop. |
| strategy_rebalance_day_limit | 7 | 1-10 | Latest calendar day treated as the first-trading-day rebalance window. |

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 sleeve named in the card and present in the DWX matrix as a backtest-only custom symbol.
- NDX.DWX - Nasdaq 100 sleeve named in the card and present in the DWX matrix.
- WS30.DWX - Dow 30 sleeve named in the card and present in the DWX matrix.
- XAUUSD.DWX - Gold sleeve named in the card and present in the DWX matrix.

**Explicitly NOT for:**
- TBD_BOND_PROXY - The card marks the bond/rate sleeve as optional and no approved DWX bond proxy was provided for this build.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | PERIOD_MN1 monthly momentum for allocation returns |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | Monthly rebalance hold, usually about one month |
| Expected drawdown profile | Conservative target-volatility allocation with catastrophic ATR stops per sleeve |
| Regime preference | Multi-asset momentum allocation with volatility constraint |
| Win rate target (qualitative) | medium |

## 6. Source Citation

This card was mechanised from:

**Source ID:** dcbac84f-6ecf-5d21-9630-50faa69306ec
**Source type:** paper
**Pointer:** https://robotwealth.com/wp-content/uploads/2017/07/Momentum-and-Markowtiz-A-Golden-Combination.pdf
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10037_rw-caa-mvo.md`

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
| v1 | 2026-06-11 | Initial build from card | e65fc295-93e4-41b7-9d67-ea28dc7ae049 |

# QM5_12511_bt-target-vol - Strategy Spec

**EA ID:** QM5_12511
**Slug:** bt-target-vol
**Source:** 2d7aaa5f-321c-524b-99ce-bc921cddfc60
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA is a long-only weekly volatility-targeted basket sleeve. On each new D1 bar it reads the prior 252 completed D1 returns for the configured basket, computes inverse-realized-volatility weights, normalizes those weights, estimates basket covariance, and scales exposure so the basket targets 10% annualized volatility. On the first tradable D1 bar of each week it opens long exposure for the chart symbol when the capped target weight is above 5%; it closes when the target weight falls below 2%, when fewer than two symbols have valid basket data, when basket volatility cannot be computed, or when the 20-day basket loss breaches two times target monthly volatility.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_target_annual_vol | 0.10 | >0 | Annualized volatility target used to scale inverse-vol weights. |
| strategy_vol_lookback_d1 | 252 | 20-510 | Completed D1 bars used for realized volatility and covariance. |
| strategy_short_vol_lookback_d1 | 20 | 2 to vol lookback - 1 | Short realized-vol window used for the no-increase volatility shock filter and basket loss window. |
| strategy_spread_median_days | 60 | 1-510 | D1 bars used to estimate median spread from historical rates. |
| strategy_spread_median_mult | 2.0 | >0 | Blocks the current symbol when current spread exceeds this multiple of median spread. |
| strategy_single_symbol_cap | 0.40 | 0.01-1.00 | Maximum capped target weight per symbol. |
| strategy_entry_weight_threshold | 0.05 | > exit threshold | Minimum target weight required to open a long position. |
| strategy_exit_weight_threshold | 0.02 | >=0 | Target weight below which an open position is closed. |
| strategy_rebalance_tolerance | 0.0 | >=0 | Weekly close/reopen threshold for target-weight drift; zero means every weekly rebalance refreshes the position. |
| strategy_atr_period_d1 | 20 | >0 | ATR period for the per-symbol emergency stop. |
| strategy_atr_sl_mult | 4.0 | >0 | ATR multiple below entry for the emergency stop. |

---

## 3. Symbol Universe

**Designed for:**
- GDAXI.DWX - registered as the available DAX custom symbol because GER40.DWX from the card is not in the DWX matrix.
- NDX.DWX - Nasdaq 100 index exposure from the card basket.
- WS30.DWX - Dow 30 index exposure from the card basket.
- XAUUSD.DWX - gold CFD exposure from the card basket.
- XTIUSD.DWX - crude oil CFD exposure from the card basket.

**Explicitly NOT for:**
- GER40.DWX - card-stated name is not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is used instead.
- SP500.DWX - card notes it may be added backtest-only, but the primary P2 basket does not require it.
- Non-DWX symbols - V5 backtests use `.DWX` research symbols only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Expected trade frequency | Weekly rebalance with 12-month inverse-vol and target-vol sizing; estimate 35-52 rebalance actions/year/symbol. |
| Typical hold time | Not explicit in frontmatter; weekly rebalance body implies positions may hold days to weeks until target weight or emergency exit triggers. |
| Expected drawdown profile | Allocation strategy with volatility-shock risk; 4x ATR stop and 20-day basket loss flatten are required controls. |
| Regime preference | volatility-targeting / inverse-volatility / weekly-rebalance / long-flat / portfolio-allocation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 2d7aaa5f-321c-524b-99ce-bc921cddfc60
**Source type:** GitHub repository documentation
**Pointer:** Philippe Morissette, `bt` flexible backtesting for Python; `docs/source/Target_Volatility.rst`, Target Volatility notebook, commit `2630651f212c025f0cec351d6319ad81d587ad6e`.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_12511_bt-target-vol.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-11 | Initial build from card | c7fb3d39-df5b-4edf-ba3d-8b5cca89acf9 |

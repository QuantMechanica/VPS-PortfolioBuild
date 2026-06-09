# QM5_10034_rw-pairs-z - Strategy Spec

**EA ID:** QM5_10034
**Slug:** `rw-pairs-z`
**Source:** `dcbac84f-6ecf-5d21-9630-50faa69306ec` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

On each D1 close the EA evaluates a two-symbol spread, `Y close - beta * X close`, using `beta = 0.40` by default. It computes the rolling z-score of that spread over 100 closed D1 bars. If the z-score crosses below -1.0 the EA buys the spread by buying Y and selling X; if it crosses above +1.0 it shorts the spread by selling Y and buying X. The EA closes both legs when the z-score crosses zero, when absolute z-score reaches 3.0, or when the position has been open for 30 D1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_z_lookback_d1` | 100 | 20+ | Rolling D1 spread window used for z-score mean and standard deviation. |
| `strategy_beta` | 0.40 | >0 | Fixed hedge ratio applied to the X leg in `Y - beta * X`. |
| `strategy_entry_z` | 1.00 | >0 | Absolute z-score crossing level for new spread entries. |
| `strategy_exit_z` | 0.00 | 0+ | Exit band; zero means close on a zero-line crossing. |
| `strategy_stop_z` | 3.00 | >entry | Synthetic spread stop when absolute z-score expands this far. |
| `strategy_atr_period_d1` | 20 | 1+ | ATR period for per-leg catastrophic stop placement. |
| `strategy_atr_sl_mult` | 3.00 | >0 | ATR multiple for each leg's broker stop. |
| `strategy_time_stop_bars` | 30 | 1+ | Maximum D1 bars to hold a spread before time-stop exit. |
| `strategy_half_life_lookback` | 250 | 30+ | D1 window for the AR(1) half-life estimate. |
| `strategy_max_half_life_days` | 60.0 | >0 | Skip a pair when estimated half-life is above this many trading days. |
| `strategy_max_spread_points` | 0 | 0+ | Optional current broker-spread ceiling; 0 disables because the card gives no numeric threshold. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - Y leg for the primary card pair, representing the S&P 500 custom symbol.
- `NDX.DWX` - X leg for the primary card pair, representing Nasdaq 100 exposure.
- `XAUUSD.DWX` - Y leg for the secondary commodity pair named in card frontmatter.
- `XAGUSD.DWX` - X leg resolved from the card's approved-silver condition; it is present in `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- Any symbol without the `.DWX` suffix - the card requires DWX research and backtest symbols.
- Unpaired single-symbol runs outside the four registered legs - the strategy is a synthetic spread, not a standalone directional rule.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | Up to 30 trading days |
| Expected drawdown profile | Mean-reversion losses cluster when the spread trends instead of reverting. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `dcbac84f-6ecf-5d21-9630-50faa69306ec`
**Source type:** blog
**Pointer:** Kris Longmore, "Pairs Trading in Zorro", Robot Wealth; approved card `artifacts/cards_approved/QM5_10034_rw-pairs-z.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10034_rw-pairs-z.md`

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
| v1 | 2026-06-09 | Initial build from card | c7761526-fc98-4e37-96e3-1c9a270a1e07 |

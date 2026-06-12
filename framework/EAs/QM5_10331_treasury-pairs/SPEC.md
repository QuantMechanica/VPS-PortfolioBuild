# QM5_10331_treasury-pairs - Strategy Spec

**EA ID:** QM5_10331
**Slug:** treasury-pairs
**Source:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9 (see SSRN abstract 565441)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades mean reversion in highly correlated index-CFD pairs. On each M15 closed bar it estimates a 20 trading day hedge ratio, computes the spread `A - beta * B`, and measures the spread's 20 trading day z-score. It shorts the spread when z-score is at or above +2.0, goes long the spread when z-score is at or below -2.0, exits when the z-score crosses back through zero, and closes both legs on a 16-bar time stop, adverse 3.5 z-score stop, loss stop, or Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_hedge_days | 20 | 5-120 | Trading-day lookback for hedge ratio and spread z-score. |
| strategy_corr_days | 60 | 20-180 | Trading-day lookback for the pair-correlation filter. |
| strategy_bars_per_day | 96 | 1-1440 | M15 bars per calendar day used to translate day lookbacks into bars. |
| strategy_entry_z | 2.0 | 0.5-5.0 | Absolute z-score threshold for opening a spread trade. |
| strategy_exit_z | 0.0 | -1.0-1.0 | Mean-reversion threshold for closing a spread trade. |
| strategy_stop_z | 3.5 | 1.0-8.0 | Adverse absolute z-score threshold for extreme-risk close. |
| strategy_min_corr | 0.75 | 0.0-1.0 | Minimum 60-day return correlation required to trade the pair. |
| strategy_max_hold_bars | 16 | 1-500 | Maximum holding period in M15 bars. |
| strategy_loss_r_mult | 1.25 | 0.1-5.0 | Combined mark-to-market loss multiple of planned risk that forces both legs flat. |
| strategy_spread_percentile | 80.0 | 1.0-100.0 | Rolling spread-cost percentile cutoff for each leg. |
| strategy_deviation_points | 20 | 0-500 | Broker deviation limit for market orders. |
| strategy_min_beta | 0.05 | 0.001-10.0 | Minimum absolute hedge ratio accepted. |
| strategy_max_beta | 20.0 | 1.0-100.0 | Maximum absolute hedge ratio accepted. |

---

## 3. Symbol Universe

**Designed for:**
- GDAXI.DWX - matrix-valid DAX leg used as the portable replacement for card-stated GER40.DWX.
- UK100.DWX - matrix-valid liquid European index leg used as the fallback for unavailable FRA40.DWX.
- SP500.DWX - card-stated S&P 500 index leg, backtest-only per DWX discipline.
- NDX.DWX - card-stated Nasdaq 100 index leg for SP500/NDX pair.
- WS30.DWX - card-stated Dow 30 index leg for SP500/WS30 pair.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`.
- FRA40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`.
- SPX500.DWX, SPY.DWX, ES.DWX - non-canonical S&P 500 variants; SP500.DWX is the only allowed matrix symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | Up to 16 M15 bars, approximately 4 hours. |
| Expected drawdown profile | Bounded pair loss via 3.5 z-score stop and 1.25R combined loss close. |
| Regime preference | Mean-reverting correlated index spreads. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
**Source type:** paper
**Pointer:** Purnendu Nath, "High Frequency Pairs Trading with U.S. Treasury Securities", SSRN abstract 565441, 2003, https://papers.ssrn.com/sol3/papers.cfm?abstract_id=565441
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10331_treasury-pairs.md`

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
| v1 | 2026-06-12 | Initial build from card | 5cccff22-b99e-41d4-b638-7b7b57b65979 |

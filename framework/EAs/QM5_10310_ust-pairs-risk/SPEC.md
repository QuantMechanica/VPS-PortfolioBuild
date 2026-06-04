# QM5_10310_ust-pairs-risk - Strategy Spec

**EA ID:** QM5_10310
**Slug:** `ust-pairs-risk`
**Source:** `fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9`
**Author of this spec:** Codex
**Last revised:** 2026-06-04

---

## 1. Strategy Logic

The EA trades a liquid pair spread on M15 bars. It estimates a 60 trading day relationship between the chart symbol and its configured peer, then computes the spread `S = log(A) - beta * log(B)` and a 20 trading day z-score. A high positive z-score opens the chart leg in the short-spread direction, while a high negative z-score opens it in the long-spread direction. Open exposure is closed when the spread reverts near zero, when the z-score reaches the hard-stop level, when 10 day correlation drops below the exit threshold, when the maximum holding period is reached, or when package loss hits the P2 risk cap.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_tf` | `PERIOD_M15` | M15 primary | Base timeframe for pair state and entries. |
| `strategy_formation_days` | `60` | `1+` | Lookback days for return correlation and beta estimation. |
| `strategy_z_days` | `20` | `1+` | Lookback days for spread z-score mean and sigma. |
| `strategy_exit_corr_days` | `10` | `1+` | Lookback days for the correlation exit check. |
| `strategy_min_entry_corr` | `0.75` | `0.0-1.0` | Minimum formation-window correlation required before entry. |
| `strategy_min_exit_corr` | `0.50` | `0.0-1.0` | Correlation floor that forces exit when breached. |
| `strategy_entry_z` | `1.75` | `0.0+` | Absolute z-score threshold for spread entry. |
| `strategy_exit_z` | `0.20` | `0.0+` | Absolute z-score threshold for mean-reversion exit. |
| `strategy_hard_stop_z` | `3.0` | `0.0+` | Absolute z-score threshold for extreme-risk stop. |
| `strategy_max_hold_days` | `3` | `1+` | Maximum holding period before time stop. |
| `strategy_cooldown_hours_after_stop` | `24` | `0+` | Same-direction cooldown after a hard stop. |
| `strategy_max_cost_fraction` | `0.10` | `0.0-1.0` | Maximum spread cost as a fraction of entry-to-mean distance. |
| `strategy_atr_period` | `14` | `1+` | ATR period for leg stop distance. |
| `strategy_atr_sl_mult` | `2.0` | `0.0+` | ATR multiplier for leg stop distance. |
| `strategy_min_stop_points` | `50` | `1+` | Minimum stop distance in points. |

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - rates-sensitive FX leg from the approved R3 primary port.
- `USDCAD.DWX` - rates-sensitive FX peer for USDJPY.
- `EURUSD.DWX` - liquid major FX spread leg from the approved R3 primary port.
- `GBPUSD.DWX` - liquid major FX peer for EURUSD.
- `XAUUSD.DWX` - gold leg for rates-sensitive gold/JPY spread behavior.
- `SP500.DWX` - available S&P 500 index port for index-pair coverage.
- `NDX.DWX` - Nasdaq 100 peer for SP500 and WS30 index spread behavior.
- `WS30.DWX` - Dow 30 index port included under available index pairs.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker or custom-symbol data support.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, strategy_tf)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | Up to 3 trading days |
| Expected drawdown profile | Bounded by hard z-score stop and P2 loss cap. |
| Regime preference | Mean-reverting spread behaviour in liquid correlated pairs. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9`
**Source type:** `paper`
**Pointer:** `https://ssrn.com/abstract=565441`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10310_ust-pairs-risk.md`

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
| v1 | 2026-06-04 | Initial build from card | d472860a-9150-40e6-bc16-67f8ce9c1b94 |

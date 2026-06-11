# QM5_10226_tv-psar-sma-exit - Strategy Spec

**EA ID:** QM5_10226
**Slug:** `tv-psar-sma-exit`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

This EA trades long only. It enters when Parabolic SAR flips from above the prior confirmed bar close to below the latest confirmed bar close. It exits an open long when the confirmed bar has Parabolic SAR above price and the close is below the 11-period SMA. The initial stop is the lower of the entry-bar low and 2 ATR below entry, with no take-profit, break-even, partial close, or strategy-specific trailing rule.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_H1` | `H1`, `H4` | Signal timeframe from the card's H1/H4 test instruction; H1 is the build default. |
| `strategy_psar_step` | `0.02` | `> 0` | Standard Parabolic SAR acceleration step. |
| `strategy_psar_maximum` | `0.20` | `> strategy_psar_step` | Standard Parabolic SAR maximum acceleration. |
| `strategy_sma_exit_period` | `11` | `> 1` | SMA period used in the explicit exit rule. |
| `strategy_atr_period` | `14` | `> 0` | ATR period for the protective fallback stop. |
| `strategy_atr_stop_mult` | `2.0` | `> 0` | ATR multiple used for the protective fallback stop. |
| `strategy_max_spread_atr_pct` | `0.10` | `>= 0` | Standard V5 spread cap as a fraction of ATR stop distance; `0` disables it. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed forex target with native DWX coverage.
- `XAUUSD.DWX` - Card-listed gold target with native DWX coverage.
- `GDAXI.DWX` - DAX-compatible DWX symbol used because `GER40.DWX` is not in `dwx_symbol_matrix.csv`.
- `NDX.DWX` - Card-listed Nasdaq index target with native DWX coverage.

**Explicitly NOT for:**
- `GER40.DWX` - Card-stated name is not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is registered instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | Not specified in card frontmatter. |
| Expected drawdown profile | Not specified in card frontmatter; fixed-risk stop-first trend/reversal profile. |
| Regime preference | Trend-following with reversal entry. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView popular Pine script source
**Pointer:** `https://www.tradingview.com/script/f0EqNMhP-Parabolic-SAR-with-Early-Buy-MA-Based-Exit-Strategy/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10226_tv-psar-sma-exit.md`

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
| v1 | 2026-06-12 | Initial build from card | 4d3f8772-bfa1-43fb-b769-f854c2a6ce08 |

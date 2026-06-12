# QM5_10325_round-close - Strategy Spec

**EA ID:** QM5_10325
**Slug:** round-close
**Source:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9 (see `strategy-seeds/sources/fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

At the start of each new D1 bar, the EA reads the just-closed D1 close and finds the nearest round-number level on a fixed index-point grid. It buys if the close is just above that round level and sells if the close is just below it, using `RoundBandPoints = max(0.10 * ATR(14), 10 index points)`. The stop is `0.75 * ATR(14)` from the market entry. The position exits at the next D1 bar or earlier if price crosses back through the triggering round level against the position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | `1+` | D1 ATR period for the entry band and stop distance. |
| `strategy_round_grid_points` | 100.0 | `>0` | Round-number grid spacing in index points; P3 can sweep 50 and 100. |
| `strategy_band_atr_mult` | 0.10 | `>0` | ATR multiplier used for the round-level proximity band. |
| `strategy_min_band_points` | 10.0 | `>0` | Minimum proximity band in index points. |
| `strategy_stop_atr_mult` | 0.75 | `>0` | ATR multiplier for initial stop loss. |
| `strategy_max_hold_d1_bars` | 1 | `1+` | Time exit in completed D1 bars after entry. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 index CFD/custom symbol named in the approved R3 basket.
- `NDX.DWX` - Nasdaq 100 index CFD named in the approved R3 basket.
- `WS30.DWX` - Dow 30 index CFD named in the approved R3 basket.
- `GDAXI.DWX` - available DWX DAX custom symbol; used as the matrix-valid port for card `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - not canonical DWX symbols for the S&P 500 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | One trading day, with early exit on cross-back through the round level. |
| Expected drawdown profile | Index continuation sleeve with ATR-bounded single-position risk. |
| Regime preference | Round-number microstructure continuation after D1 close clustering. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
**Source type:** paper
**Pointer:** https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4718961
**R1-R4 verdict (Q00):** all frontmatter verdicts PASS / see `artifacts/cards_approved/QM5_10325_round-close.md`

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
| v1 | 2026-06-12 | Initial build from card | a5f4577e-7964-40c1-8be5-b9c83e4fe47e |

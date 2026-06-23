# QM5_1165_unger-gold-linreg-trend - Strategy Spec

**EA ID:** QM5_1165
**Slug:** unger-gold-linreg-trend
**Source:** eb97a148-0af9-5b9c-878c-25fb5dfa34f9 (see `sources/unger-robbins-cup`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades XAUUSD.DWX on completed H1 bars. It fits a linear regression line to the last `strategy_lr_period` H1 closes, computes the standard deviation of the residuals, then builds an upper trigger at `line + strategy_lr_dev * residual_stdev` and a lower trigger at `line - strategy_lr_dev * residual_stdev`. It opens long when the completed close crosses above the upper trigger and opens short when the completed close crosses below the lower trigger. Open positions exit by ATR-derived SL/TP, by a completed H1 close crossing back through the regression line, or when `strategy_max_hold_bars` H1 bars have elapsed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lr_period` | 40 | 2-256 | Number of completed H1 closes used for the regression channel. |
| `strategy_lr_dev` | 1.0 | > 0 | Residual standard-deviation multiplier for upper/lower breakout levels. |
| `strategy_atr_period` | 14 | > 0 | ATR lookback used for stop and target distance. |
| `strategy_sl_atr_mult` | 2.0 | > 0 | Stop-loss distance in ATR multiples. |
| `strategy_tp_atr_mult` | 4.0 | > 0 | Take-profit distance in ATR multiples. |
| `strategy_max_hold_bars` | 72 | > 0 | Maximum H1 bars to hold a position. |
| `strategy_start_hour_broker` | 7 | 0-23 | First broker-time hour where new entries may be opened. |
| `strategy_end_hour_broker` | 22 | 0-23 | End broker-time hour for new entries; open trades are still managed outside this window. |
| `strategy_max_spread_points` | 250 | >= 0 | Maximum positive modeled spread in points for entry; zero spread is allowed for `.DWX` backtests. |

Framework inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - Direct Darwinex gold CFD mapping for the source's gold futures strategy.

**Explicitly NOT for:**
- Equity indices, FX pairs, energies, and silver - The approved card names gold only and R3 PASS confirms only `XAUUSD.DWX` for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework template |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 500 |
| Typical hold time | Up to 72 H1 bars; exact frontmatter metric not provided. |
| Expected drawdown profile | Trend-breakout strategy with ATR-normalized fixed risk; exact frontmatter metric not provided. |
| Regime preference | Gold trend and volatility expansion; inferred from the approved card concepts. |
| Win rate target (qualitative) | Medium; source/card does not provide a numeric target. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** eb97a148-0af9-5b9c-878c-25fb5dfa34f9
**Source type:** Unger Academy article plus supporting book
**Pointer:** `artifacts/cards_approved/QM5_1165_unger-gold-linreg-trend.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1165_unger-gold-linreg-trend.md`

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
| v1 | 2026-06-23 | Initial build from card | 49f419cd-8c70-46c4-a5d3-40f18ac178e3 |

# QM5_1047_halloween-sell-in-may-idx - Strategy Spec

**EA ID:** QM5_1047
**Slug:** halloween-sell-in-may-idx
**Source:** afab7a6f-c3c8-51ae-a609-f376744beb8e (see `strategy-seeds/sources/afab7a6f-c3c8-51ae-a609-f376744beb8e/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA implements the Halloween / Sell-in-May index seasonality rule. It opens one long position after the October holding-window boundary, represented in D1 execution as the first broker D1 bar in November. It closes the position after the April holding-window boundary, represented as the first broker D1 bar in May. Baseline trading is long-only, with no May-October short leg and no discretionary management beyond the V5 framework hard stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_entry_month_after` | 11 | 1-12 | Calendar month whose first D1 broker bars trigger the November-April long entry. |
| `strategy_exit_month_after` | 5 | 1-12 | Calendar month whose first D1 broker bars trigger the May-October flat exit. |
| `strategy_month_window_days` | 7 | 1-31 | Maximum day-of-month accepted for the first post-month-end broker D1 bar. |
| `strategy_atr_period` | 14 | >=1 | ATR lookback used for the wide hard stop. |
| `strategy_atr_stop_mult` | 4.0 | >0 | ATR multiplier for the hard stop distance. |
| `strategy_momentum_overlay` | false | true/false | Optional six-month positive-return filter; baseline keeps it off. |
| `strategy_momentum_d1_bars` | 126 | >=1 | D1 lookback for the optional six-month momentum overlay. |
| `strategy_require_d1` | true | true/false | Blocks trading if the chart timeframe is not D1. |
| `strategy_max_spread_points` | 0 | >=0 | Optional spread cap in points; 0 disables the cap. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 proxy for the paper's SPX/SPY target, backtest-only custom symbol.
- `NDX.DWX` - Nasdaq 100 index exposure in the available US large-cap basket.
- `WS30.DWX` - Dow 30 index exposure in the available US large-cap basket.
- `GDAXI.DWX` - DAX 40 index exposure for the documented cross-market effect.
- `UK100.DWX` - FTSE 100 index exposure for the documented cross-market effect.

**Explicitly NOT for:**
- `SPX500.DWX` - unavailable in the DWX matrix.
- `SPY.DWX` - unavailable in the DWX matrix.
- `ES.DWX` - unavailable in the DWX matrix.

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
| Trades / year / symbol | 2 |
| Typical hold time | About 6 months |
| Expected drawdown profile | Wide ATR hard stop; drawdown dominated by equity-index seasonal exposure. |
| Regime preference | Seasonality / calendar anomaly |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** afab7a6f-c3c8-51ae-a609-f376744beb8e
**Source type:** paper
**Pointer:** https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4856537
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1047_halloween-sell-in-may-idx.md`

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
| v1 | 2026-06-11 | Initial build from card | 3be0a9af-fad5-4ccc-bbef-33f1fb23ccf4 |

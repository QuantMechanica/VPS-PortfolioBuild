# QM5_9267_mql5-fractal-level-break - Strategy Spec

**EA ID:** QM5_9267
**Slug:** `mql5-fractal-level-break`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades H4 breaks of the latest confirmed Bill Williams fractal levels. A long entry is allowed when the last closed bar crosses above the latest confirmed upper fractal by at least 0.15 * ATR(14); a short entry mirrors this below the latest confirmed lower fractal. The EA ignores entries when current ATR(14) is below its 100-bar 20th percentile, uses the opposing latest fractal or a 2.0 * ATR fallback for the stop while enforcing at least 1.0 * ATR distance, and sets the initial take profit at 2.5R. It exits when price closes back through the broken fractal level, when a fresh opposing confirmed fractal forms on the wrong side of entry, or after 20 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | >= 1 | ATR period used for breakout buffer, volatility filter, and stop fallback. |
| `strategy_fractal_lookback_bars` | 120 | >= 5 | Maximum closed bars scanned for latest confirmed upper and lower fractals. |
| `strategy_atr_percentile_bars` | 100 | >= 20 | ATR history length used for the low-volatility percentile filter. |
| `strategy_atr_percentile_min` | 20.0 | 0-100 | Minimum allowed ATR percentile; lower current ATR blocks entries. |
| `strategy_breakout_atr_buffer` | 0.15 | >= 0 | Required close distance beyond the fractal level as a fraction of ATR. |
| `strategy_stop_atr_mult` | 2.0 | > 0 | ATR fallback stop distance from entry. |
| `strategy_min_stop_atr_mult` | 1.0 | > 0 | Minimum stop distance from entry as a fraction of ATR. |
| `strategy_take_profit_rr` | 2.5 | > 0 | Initial take-profit distance in R multiples. |
| `strategy_max_hold_bars` | 20 | >= 1 | Failsafe time exit after this many H4 bars. |
| `strategy_max_spread_atr_fraction` | 0.15 | >= 0 | Blocks new trading when live spread exceeds this fraction of ATR; zero modeled DWX spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid forex major with DWX H4 OHLC, fractals, and ATR available.
- `GBPJPY.DWX` - card-listed liquid forex cross with DWX H4 OHLC, fractals, and ATR available.
- `WS30.DWX` - card-listed major index CFD with DWX H4 OHLC, fractals, and ATR available.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker/tester data guarantee.
- Non-DWX live symbols - deploy-time DWX stripping is handled outside this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 38 |
| Typical hold time | Several H4 bars, failsafe exit after 20 H4 bars |
| Expected drawdown profile | Breakout whipsaw risk in dead ranges, reduced by ATR percentile filter |
| Regime preference | Breakout / volatility expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** MQL5 article
**Pointer:** Stephen Njuki, "MQL5 Wizard Techniques you should know (Part 56): Bill Williams Fractals", 2025-03-04, https://www.mql5.com/en/articles/17334
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9267_mql5-fractal-level-break.md`

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
| v1 | 2026-06-20 | Initial build from card | 9e890647-b4fc-46c1-be92-3be8231fc984 |

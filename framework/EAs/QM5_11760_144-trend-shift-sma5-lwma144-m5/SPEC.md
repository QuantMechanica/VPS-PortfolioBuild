# QM5_11760_144-trend-shift-sma5-lwma144-m5 - Strategy Spec

**EA ID:** QM5_11760
**Slug:** `144-trend-shift-sma5-lwma144-m5`
**Source:** `7977a977-69b4-5432-9af3-a8ebb04c0214` (see `sources/144-trend-shift-scalping-forex`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades a trend-shift crossover on M5. It opens long when SMA(5) crosses above LWMA(144) on the just-closed bar and the close is no more than 10 pips above the LWMA; it opens short on the inverse cross when the close is no more than 10 pips below the LWMA. The stop is the most recent confirmed Bill Williams fractal on the protective side of entry, with a 5-bar structural fallback if no fractal is available, and the take profit is fixed at 2R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_sma_period` | 5 | 2-50 | Fast SMA trigger period. |
| `strategy_lwma_period` | 144 | 20-300 | Slow LWMA trend reference period. |
| `strategy_proximity_pips` | 10 | 1-100 | Maximum distance from close to LWMA at the crossover bar. |
| `strategy_fractal_lookback` | 20 | 3-100 | Closed-bar depth scanned for the most recent confirmed fractal stop. |
| `strategy_sl_lookback` | 5 | 2-50 | Fallback structural stop window when no confirmed fractal is present. |
| `strategy_tp_rr` | 2.0 | 0.5-10.0 | Take-profit multiple of entry-to-stop risk. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - primary FX pair named by the card and present in the DWX matrix.
- `GBPUSD.DWX` - primary FX pair named by the card and present in the DWX matrix.

**Explicitly NOT for:**
- Index, metal, energy, and cross-FX symbols - the approved card names only EURUSD and GBPUSD.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `200` |
| Typical hold time | minutes to hours |
| Expected drawdown profile | Scalping crossover sleeve with fixed 2R exits and fractal stops. |
| Regime preference | trend-shift / volatility-expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `7977a977-69b4-5432-9af3-a8ebb04c0214`
**Source type:** retail PDF / article
**Pointer:** `408196018-144-Trend-Shift-Scalping-Forex-Trading-Strategy.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11760_144-trend-shift-sma5-lwma144-m5.md`

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
| v1 | 2026-06-23 | Initial build from card | 730365dc-2f16-4ab4-92ca-59bdeee086b8 |

# QM5_11726_tc-m5-s13-cci-macd-breakthrough - Strategy Spec

**EA ID:** QM5_11726
**Slug:** tc-m5-s13-cci-macd-breakthrough
**Source:** 40a4454c-64ff-5015-8538-9f7b32abc0e9
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades M5 momentum breakouts on EURUSD.DWX and GBPUSD.DWX. A long signal occurs when CCI(14) crosses from below +100 to at or above +100 on the last closed bar, with MACD(12,26,9) histogram positive and rising. A short signal occurs when CCI(14) crosses from above -100 to at or below -100, with MACD histogram negative and falling. Positions exit only by the fixed-pip stop loss, fixed-pip take profit, or framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_cci_period | 14 | 2-200 | CCI lookback period. |
| strategy_cci_level | 100.0 | 1.0-300.0 | Positive and negative CCI breakout threshold. |
| strategy_macd_fast | 12 | 2-100 | MACD fast EMA period. |
| strategy_macd_slow | 26 | 3-200 | MACD slow EMA period. |
| strategy_macd_signal | 9 | 2-100 | MACD signal EMA period. |
| strategy_sl_pips | 13 | 1-200 | Fixed stop-loss distance in pips. |
| strategy_tp_pips | 9 | 1-200 | Fallback take-profit distance in pips for unlisted symbols. |
| strategy_eurusd_tp_pips | 8 | 1-200 | EURUSD.DWX take-profit distance in pips. |
| strategy_gbpusd_tp_pips | 10 | 1-200 | GBPUSD.DWX take-profit distance in pips. |
| strategy_spread_pct_of_stop | 25.0 | 0.0-100.0 | Blocks only genuinely wide positive spread relative to stop distance; zero modeled spread is allowed. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card target symbol with standard DWX M5 FX data and EURUSD-specific 8 pip target.
- GBPUSD.DWX - card target symbol with standard DWX M5 FX data and GBPUSD-specific 10 pip target.

**Explicitly NOT for:**
- Non-FX index, metal, energy, and cross-rate symbols - the card names only EURUSD and GBPUSD and does not authorize basket expansion beyond those targets.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 400 |
| Typical hold time | Not specified in card frontmatter; fixed 8-10 pip TP and 13 pip SL imply intraday holds. |
| Expected drawdown profile | Not specified in card frontmatter; fixed-risk M5 breakout profile. |
| Regime preference | Momentum breakout / volatility expansion. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 40a4454c-64ff-5015-8538-9f7b32abc0e9
**Source type:** book
**Pointer:** `sources/tc-20-forex-strategies-m5-367145560`, Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", Strategy #13
**R1-R4 verdict (Q00):** all PASS per approved frontmatter; see `artifacts/cards_approved/QM5_11726_tc-m5-s13-cci-macd-breakthrough.md`

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
| v1 | 2026-06-20 | Initial build from card | bd78b08f-8050-4fe5-a9d7-d9c70d8dfd2f |

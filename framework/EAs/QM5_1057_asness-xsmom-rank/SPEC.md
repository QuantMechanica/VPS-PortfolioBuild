# QM5_1057_asness-xsmom-rank - Strategy Spec

**EA ID:** QM5_1057
**Slug:** asness-xsmom-rank
**Source:** 7ede58dd-d184-5099-9d48-7a65de230853 (see `strategy-seeds/sources/7ede58dd-d184-5099-9d48-7a65de230853/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

On the first D1 bar after a calendar month changes, the EA ranks the registered basket by 12-month-minus-1-month return: close 21 D1 bars ago divided by close 252 D1 bars ago minus one. If the chart symbol is in the top two ranks, it opens long; if the chart symbol is in the bottom two ranks, it opens short. Existing positions are closed on the monthly rebalance bar before a fresh rank signal is allowed, and no discretionary exits are used outside monthly rebalance and the hard stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_lookback_d1_bars | 252 | 22-504 | Lookback close used for the 12-month leg of the 12-1 return. |
| strategy_skip_d1_bars | 21 | 1-63 | Recent D1 bars skipped to avoid short-term reversal. |
| strategy_rank_slots_each_side | 2 | 1-5 | Number of top-ranked symbols to long and bottom-ranked symbols to short. |
| strategy_atr_period | 20 | 5-100 | D1 ATR period used for the hard stop. |
| strategy_atr_sl_mult | 5.0 | 0.5-10.0 | ATR multiple for the hard stop distance. |
| strategy_spread_median_days | 20 | 1-64 | D1 spread samples used for the median spread filter. |
| strategy_spread_mult | 3.0 | 0.5-10.0 | Current spread must not exceed this multiple of median spread. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - FX major in the card universe.
- GBPUSD.DWX - FX major in the card universe.
- USDJPY.DWX - FX major in the card universe.
- AUDUSD.DWX - FX major in the card universe.
- USDCAD.DWX - FX major in the card universe.
- USDCHF.DWX - FX major in the card universe.
- NZDUSD.DWX - FX major in the card universe.
- XAUUSD.DWX - Gold exposure in the card universe.
- NDX.DWX - Nasdaq 100 index exposure in the card universe.
- WS30.DWX - Dow 30 index exposure in the card universe.
- GDAXI.DWX - DAX exposure; used as the DWX matrix symbol for the card's GER40.DWX reference.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; DAX exposure is represented by GDAXI.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` wiring |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 from card frontmatter; realised trades depend on whether the symbol ranks top two or bottom two each month. |
| Typical hold time | About one month between month-boundary rebalance bars. |
| Expected drawdown profile | Wide 5x ATR hard stops; long-short momentum can hold through volatile reversals. |
| Regime preference | Cross-sectional momentum / trend persistence. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 7ede58dd-d184-5099-9d48-7a65de230853
**Source type:** encyclopedia entry with academic paper backbone
**Pointer:** Quantpedia Cross-Sectional Momentum Effect; Asness, Moskowitz, and Pedersen (2013), "Value and Momentum Everywhere"
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1057_asness-xsmom-rank.md`

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
| v1 | 2026-06-13 | Initial build from card | 10b89dd9-1bbb-4db5-b3b8-6e5626965b45 |

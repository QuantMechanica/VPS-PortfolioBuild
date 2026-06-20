# QM5_11634_fsr-double-stoch21-9-h1 - Strategy Spec

**EA ID:** QM5_11634
**Slug:** fsr-double-stoch21-9-h1
**Source:** 5e9e8c4d-0c88-5dc6-a550-b3b070a5b44d
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades an H1 double-stochastic crossover pattern. Stoch(21,9,9) is the slow direction signal: a bullish %K/%D cross with %K below 80 establishes a long bias, and a bearish %K/%D cross with %K above 20 establishes a short bias. Once a bias exists, Stoch(9,3,3) supplies the entry trigger through a matching %K/%D cross. Open trades exit when Stoch(9,3,3) crosses in the opposite direction, or through the framework Friday close and broker stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_slow_k_period | 21 | 1-200 | Slow stochastic %K period used to establish direction. |
| strategy_slow_d_period | 9 | 1-100 | Slow stochastic %D smoothing period. |
| strategy_slow_slowing | 9 | 1-100 | Slow stochastic slowing value. |
| strategy_fast_k_period | 9 | 1-100 | Fast stochastic %K period used for entry and exit timing. |
| strategy_fast_d_period | 3 | 1-50 | Fast stochastic %D smoothing period. |
| strategy_fast_slowing | 3 | 1-50 | Fast stochastic slowing value. |
| strategy_slow_overbought | 80.0 | 50.0-100.0 | Blocks new long bias when the slow stochastic %K is above this level. |
| strategy_slow_oversold | 20.0 | 0.0-50.0 | Blocks new short bias when the slow stochastic %K is below this level. |
| strategy_atr_period | 14 | 1-200 | ATR period used for the factory-default stop. |
| strategy_atr_sl_mult | 2.0 | 0.1-10.0 | ATR multiple for stop-loss placement. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed H1 forex major with DWX data available.
- GBPUSD.DWX - Card-listed H1 forex major with DWX data available.
- USDJPY.DWX - Card-listed H1 forex major with DWX data available.
- XAUUSD.DWX - Card-listed H1 metal symbol with DWX data available.

**Explicitly NOT for:**
- Non-DWX symbols - The build and pipeline registries require the `.DWX` custom-symbol universe for research and backtest runs.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - The broker/tester does not provide usable DWX tick history for them.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Not specified in card frontmatter. |
| Expected drawdown profile | Not specified in card frontmatter. |
| Regime preference | Oscillator crossover / momentum timing; exact regime not specified in card frontmatter. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 5e9e8c4d-0c88-5dc6-a550-b3b070a5b44d
**Source type:** forum / local PDF archive
**Pointer:** forex-strategies-revealed.com, "Complex Forex Strategy #6 (Double Stochastic)", captured in the Forex Strategies Revealed collection PDF export.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11634_fsr-double-stoch21-9-h1.md`

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
| v1 | 2026-06-20 | Initial build from card | 17ec11ab-6247-4055-b800-6185786c776d |

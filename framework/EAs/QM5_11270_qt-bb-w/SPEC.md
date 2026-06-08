# QM5_11270_qt-bb-w - Strategy Spec

**EA ID:** QM5_11270
**Slug:** `qt-bb-w`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (see `strategy-seeds/sources/72f9fcfa-6c75-5544-80c4-31e15c9817ab/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades long-only Bollinger bottom-W reversals. It builds 20-period Bollinger Bands from close prices, searches the prior 75 closed H1 bars for a first bottom near the lower band, a middle node near the middle band, an intervening node above the middle band, and a second bottom near but above the lower band and above the first bottom. When the latest closed bar breaks above the upper band after that pattern, the EA opens a market buy with an ATR(14) stop. It exits when the 20-period standard deviation contracts below the beta ATR threshold or after 30 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bb_period` | 20 | 20-30 | Bollinger lookback used for middle band and standard deviation. |
| `strategy_bb_deviation` | 2.0 | 1.8-2.2 | Standard deviation multiplier for upper and lower bands. |
| `strategy_pattern_horizon` | 75 | 50-100 | Closed-bar search horizon for the bottom-W node sequence. |
| `strategy_alpha_atr` | 0.10 | 0.05-0.20 | ATR-normalized tolerance for near-band and node proximity checks. |
| `strategy_beta_atr` | 0.10 | 0.05-0.15 | ATR-normalized standard-deviation contraction threshold for exits. |
| `strategy_atr_period` | 14 | 14 | ATR period for stop distance and normalized thresholds. |
| `strategy_atr_sl_mult` | 2.0 | 2.0 | ATR multiple for the hard stop. |
| `strategy_structural_sl_atr_mult` | 0.25 | 0.25 | Offset below the second bottom for the optional tighter structural stop. |
| `strategy_time_stop_bars` | 30 | 30 | Fallback maximum hold time measured in H1 bars. |
| `strategy_spread_stop_fraction` | 0.10 | 0.10 | Blocks trading when spread exceeds this fraction of planned stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - Card primary basket forex major with DWX OHLC/tick coverage.
- `EURUSD.DWX` - Card primary basket forex major with DWX OHLC/tick coverage.
- `USDJPY.DWX` - Card primary basket forex major with DWX OHLC/tick coverage.
- `XAUUSD.DWX` - Card primary basket metal symbol with DWX OHLC/tick coverage and Bollinger volatility behaviour.

**Explicitly NOT for:**
- Non-DWX symbols - Build and pipeline use `.DWX` symbols only.
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - No broker/custom-symbol data guarantee.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `20` |
| Typical hold time | Up to 30 H1 bars; earlier if Bollinger standard deviation contracts. |
| Expected drawdown profile | Medium-high risk due to selective reversal entries after volatility expansion. |
| Regime preference | Mean-reversion reversal with volatility-expansion confirmation. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** GitHub repository/script
**Pointer:** `https://github.com/je-suis-tm/quant-trading/blob/master/Bollinger%20Bands%20Pattern%20Recognition%20backtest.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11270_qt-bb-w.md`

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
| v1 | 2026-06-08 | Initial build from card | 09110c8a-2d35-4b16-a02e-e050d586d81e |

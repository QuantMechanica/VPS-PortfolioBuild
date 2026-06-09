# QM5_10071_mql5-bb-touch - Strategy Spec

**EA ID:** QM5_10071
**Slug:** `mql5-bb-touch`
**Source:** `a120af9a-fb72-526c-bb80-d1d098a617b5` (see `strategy-seeds/sources/a120af9a-fb72-526c-bb80-d1d098a617b5/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA is a Bollinger Band touch mean-reversion system. It calculates one Bollinger set from low prices and one from high prices on the active H1 chart. It buys when ask reaches or falls below the lower band built from lows, and sells when bid reaches or rises above the upper band built from highs. A buy exits when bid reaches the lower band built from highs; a sell exits when ask reaches the upper band built from lows. A 2.0 ATR catastrophic stop is added because the card requires framework safety while preserving the band exit as the primary exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 2-200 | Bollinger Band lookback period from the source example. |
| `strategy_bb_deviation` | 2.0 | 0.1-5.0 | Standard deviation multiplier for both Bollinger sets. |
| `strategy_atr_period` | 14 | 1-200 | ATR lookback used only for the catastrophic stop. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-10.0 | ATR multiplier for the catastrophic stop distance. |

> Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target forex major with native DWX data.
- `GBPUSD.DWX` - card target forex major with native DWX data.
- `USDJPY.DWX` - card target forex major with native DWX data.
- `XAUUSD.DWX` - card target metal CFD with native DWX data.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - unavailable for DWX backtesting.
- Equity-index-only baskets - not listed by this card.

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
| Trades / year / symbol | `120` |
| Typical hold time | Not specified in frontmatter; expected to be intraday to multi-bar H1 holds until the opposite band-touch exit. |
| Expected drawdown profile | Mean-reversion drawdowns during persistent directional moves; ATR stop caps catastrophic loss. |
| Regime preference | Mean-revert, range-bound volatility. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `a120af9a-fb72-526c-bb80-d1d098a617b5`
**Source type:** article
**Pointer:** Maxim Khrolenko, "Creating a Multi-Currency Multi-System Expert Advisor", MQL5 Articles, 5 December 2013, `https://www.mql5.com/en/articles/770`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10071_mql5-bb-touch.md`

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
| v1 | 2026-06-09 | Initial build from card | 9e63544d-d4f2-4a16-a5c5-0debe35138ad |

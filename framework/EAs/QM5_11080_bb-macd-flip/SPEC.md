# QM5_11080_bb-macd-flip - Strategy Spec

**EA ID:** QM5_11080
**Slug:** bb-macd-flip
**Source:** 0693c604-4f96-56ef-be79-15efe9f48b86 (see `strategy-seeds/sources/0693c604-4f96-56ef-be79-15efe9f48b86/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA computes BB-MACD as EMA(close, 12) minus EMA(close, 26) on completed H1 bars. It smooths that BB-MACD series over 10 samples and computes a 2.5 standard-deviation envelope for source parity, then trades the source color flip rule: long when BB-MACD slope flips from down to up, and short when it flips from up to down. Open long positions close on the next short flip, and open short positions close on the next long flip; the ATR catastrophic stop can close first.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_ema` | 12 | 1-100 | Fast EMA period used in BB-MACD. |
| `strategy_slow_ema` | 26 | 2-200 | Slow EMA period used in BB-MACD; must exceed fast EMA. |
| `strategy_bb_length` | 10 | 2-100 | Smoothing and standard-deviation sample length for BB-MACD bands. |
| `strategy_bb_stdev_mult` | 2.5 | 0.1-10.0 | Standard-deviation multiplier for the BB-MACD envelope. |
| `strategy_stricter_zero` | false | true/false | Optional source variant requiring bullish flips above zero and bearish flips below zero. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | 2.5 | 0.1-20.0 | ATR multiple for the catastrophic stop. |
| `strategy_use_take_profit` | false | true/false | Enables the optional bounded-test ATR target. |
| `strategy_atr_tp_mult` | 3.5 | 0.1-30.0 | ATR multiple for the optional take-profit target. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 primary P2 basket forex major with complete DWX coverage.
- `GBPUSD.DWX` - Card R3 primary P2 basket forex major with complete DWX coverage.
- `USDJPY.DWX` - Card R3 primary P2 basket forex major with complete DWX coverage.
- `XAUUSD.DWX` - Card R3 primary P2 basket gold CFD with complete DWX coverage.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the build registers only verified DWX symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | Card frontmatter not specified; opposite H1 momentum flip implies hours to days. |
| Expected drawdown profile | Momentum-cycle whipsaws during flat BB-MACD slope regimes. |
| Regime preference | Card frontmatter not specified; mechanics indicate trend-following momentum cycles. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Source type:** GitHub indicator source
**Pointer:** https://github.com/EarnForex/BB-MACD and `artifacts/cards_approved/QM5_11080_bb-macd-flip.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11080_bb-macd-flip.md`

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
| v1 | 2026-06-07 | Initial build from card | 68577f3e-71d6-4a67-8993-979197583bfa |

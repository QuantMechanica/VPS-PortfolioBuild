# QM5_10505_mql5-macd-sar - Strategy Spec

**EA ID:** QM5_10505
**Slug:** mql5-macd-sar
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

This EA evaluates MACD and Parabolic SAR on each closed H1 bar. It buys when MACD main is above MACD signal, MACD signal is below zero, and SAR is below the current bid. It sells when MACD main is below MACD signal, MACD signal is above zero, and SAR is above the current bid. Open positions are closed when the opposite MACD/SAR signal appears; each entry also carries a 1.5 x ATR(14) stop and a 1.5R take-profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_H1` | MT5 timeframe enum | Signal timeframe from the card. |
| `strategy_macd_fast` | `12` | `> 0` and `< strategy_macd_slow` | MACD fast EMA period. |
| `strategy_macd_slow` | `26` | `> strategy_macd_fast` | MACD slow EMA period. |
| `strategy_macd_signal` | `9` | `> 0` | MACD signal period. |
| `strategy_psar_step` | `0.02` | `> 0` and `< strategy_psar_maximum` | Parabolic SAR acceleration step. |
| `strategy_psar_maximum` | `0.20` | `> strategy_psar_step` | Parabolic SAR maximum acceleration. |
| `strategy_atr_period` | `14` | `> 0` | ATR period for the fixed hard stop. |
| `strategy_atr_sl_mult` | `1.5` | `> 0` | Stop distance multiplier applied to ATR(14). |
| `strategy_take_profit_rr` | `1.5` | `> 0` | Take-profit distance as a multiple of initial risk. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card R3 primary basket forex symbol with DWX availability.
- `GBPUSD.DWX` - card R3 primary basket forex symbol with DWX availability.
- `USDJPY.DWX` - card R3 primary basket forex symbol with DWX availability.
- `XAUUSD.DWX` - card R3 primary basket metal symbol with DWX availability.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - unavailable for DWX backtests.

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
| Typical hold time | Not specified in card frontmatter. |
| Expected drawdown profile | ATR-normalized hard-stop strategy; drawdown profile not specified in card frontmatter. |
| Regime preference | MACD momentum with Parabolic SAR confirmation. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/20827
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10505_mql5-macd-sar.md`

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
| v1 | 2026-06-13 | Initial build from card | 92f30edc-b19a-4815-a989-251444a9a5d7 |

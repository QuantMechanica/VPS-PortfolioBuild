# QM5_10543_mql5-turbofx - Strategy Spec

**EA ID:** QM5_10543
**Slug:** `mql5-turbofx`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA evaluates only closed bars. It looks for `N` consecutive candles of the same direction where each candle body is strictly larger than the previous candle body. A bullish expanding sequence creates a short signal, while a bearish expanding sequence creates a long signal. The baseline exits by ATR hard stop, fixed 1.5R target, and an optional time stop after a fixed number of H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sequence_bars` | 3 | 2-8 | Number of closed same-direction candles required in the expanding sequence. |
| `strategy_min_body_atr_frac` | 0.0 | 0.0-2.0 | Optional minimum final candle body as a fraction of ATR. |
| `strategy_atr_period` | 14 | 1-100 | ATR period used for the hard stop and optional body filter. |
| `strategy_atr_sl_mult` | 1.5 | 0.1-5.0 | ATR multiple for the stop loss. |
| `strategy_tp_rr` | 1.5 | 0.1-5.0 | Fixed reward-to-risk target multiple. |
| `strategy_time_stop_bars` | 12 | 0-24 | Optional time stop in bars; 0 disables it. |
| `strategy_opposite_exit` | false | true/false | Optional close on an opposite expanding-candle sequence. |
| `strategy_max_spread_points` | 0 | 0-500 | Optional spread ceiling in points; 0 disables it. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 lists this major forex pair for OHLC candle-body testing.
- `GBPUSD.DWX` - Card R3 lists this major forex pair for OHLC candle-body testing.
- `USDJPY.DWX` - Card R3 lists this major forex pair for OHLC candle-body testing.
- `XAUUSD.DWX` - Card R3 lists this liquid metal symbol for OHLC candle-body testing.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no verified DWX test data.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | `6-24 H1 bars` |
| Expected drawdown profile | `Mean-reversion reversal entries can cluster losses during persistent trends.` |
| Regime preference | `mean-revert / body-expansion reversal` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/17289`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10543_mql5-turbofx.md`

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
| v1 | 2026-05-29 | Initial build from card | 400229f7-5322-4a3d-bcd2-2b68a20b46c9 |

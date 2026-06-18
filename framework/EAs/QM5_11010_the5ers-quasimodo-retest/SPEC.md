# QM5_11010_the5ers-quasimodo-retest - Strategy Spec

**EA ID:** QM5_11010
**Slug:** the5ers-quasimodo-retest
**Source:** 1d445184-7c47-57da-9856-a123682a932d (see `strategy-seeds/sources/1d445184-7c47-57da-9856-a123682a932d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades H1 Quasimodo retests after a confirmed swing-sequence reversal. It detects non-repainting 3-left/3-right swing highs and lows, then looks for the bearish `HH1, HL1, HH2, LL1` sequence or the bullish `LL1, LH1, LL2, HH1` sequence with the momentum break exceeding `0.50 * ATR(14)`. After the break, it enters on the next H1 open when the last closed bar retests the Quasimodo level within `0.35 * ATR(14)` and closes on the trade side of that level. It exits at 2.0R, on an adverse close beyond the retested level by `0.50 * ATR(14)`, or after 60 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fractal_left` | 3 | 1-10 | Bars to the older side of a swing point that must be lower for highs or higher for lows. |
| `strategy_fractal_right` | 3 | 1-10 | Closed bars to the newer side of a swing point that confirm it is non-repainting. |
| `strategy_scan_window` | 120 | 20-300 | Maximum H1 bars scanned for the Quasimodo swing sequence. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for break threshold, retest tolerance, stop buffer, and adverse exit buffer. |
| `strategy_break_atr_mult` | 0.50 | 0.10-2.00 | Minimum momentum break beyond the prior swing level, as a multiple of ATR. |
| `strategy_retest_atr_mult` | 0.35 | 0.10-2.00 | Retest tolerance and stop buffer, as a multiple of ATR. |
| `strategy_exit_atr_mult` | 0.50 | 0.10-2.00 | Adverse close distance beyond the retested level that triggers strategy exit. |
| `strategy_tp_rr` | 2.0 | 0.5-5.0 | Take-profit distance as an R multiple of initial risk. |
| `strategy_retest_window` | 80 | 5-200 | Maximum H1 bars after the momentum-break swing for a valid retest. |
| `strategy_time_stop_bars` | 60 | 1-240 | Maximum H1 bars to hold a trade before time-stop exit. |
| `strategy_spread_pct_of_stop` | 25.0 | 0-100 | Blocks only genuinely wide positive spread above this percentage of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card target; liquid DWX forex pair with H1 OHLC and ATR data.
- `GBPUSD.DWX` - Card target; liquid DWX forex pair with H1 OHLC and ATR data.
- `USDJPY.DWX` - Card target; liquid DWX forex pair with H1 OHLC and ATR data.
- `XAUUSD.DWX` - Card target; liquid DWX metal symbol with H1 OHLC and ATR data.
- `GDAXI.DWX` - Canonical DWX DAX symbol used as the available matrix equivalent for card target `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - Named in the card but not present in `framework/registry/dwx_symbol_matrix.csv`; replaced by `GDAXI.DWX`.

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
| Trades / year / symbol | 30 |
| Typical hold time | Up to 60 H1 bars; many trades should exit earlier by SL, TP, or signal exit. |
| Expected drawdown profile | Reversal strategy with fixed initial risk and 2.0R target; drawdown expected to cluster in persistent trend continuations. |
| Regime preference | Reversal / liquidity-retest after a momentum-break swing sequence. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1d445184-7c47-57da-9856-a123682a932d
**Source type:** blog
**Pointer:** https://the5ers.com/five-powerful-reversal-patterns-every-trader-must-know/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11010_the5ers-quasimodo-retest.md`

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
| v1 | 2026-06-18 | Initial build from card | be4982c3-d686-45e0-a401-8c63a782f83b |

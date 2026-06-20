# QM5_9274_mql5-five-drives - Strategy Spec

**EA ID:** QM5_9274
**Slug:** `mql5-five-drives`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades the 5 Drives harmonic reversal pattern on H4 bars. It scans confirmed swing pivots with five bars on each side, takes the latest A-B-C-D-E-F sequence, and requires the source-defined Fibonacci gates: AB extension of XA, BC extension of AB, final CD retracement of BC, and reciprocal AB=CD within tolerance. A bullish high-low-high-low-high-low pattern buys at the next available market price after confirmation; a bearish low-high-low-high-low-high pattern sells. The stop is placed beyond F by the Fibonacci extension of the final drive, capped by 3.0 times ATR(14), and the target is TP2, two-thirds of the distance from entry to pivot E. Positions that do not hit stop or target close after 30 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_pivot_left` | 5 | 1+ | Bars older than the candidate pivot required for confirmation. |
| `strategy_pivot_right` | 5 | 1+ | Bars newer than the candidate pivot required for confirmation. |
| `strategy_min_span_bars` | 30 | 1+ | Minimum A-to-F pattern span in H4 bars. |
| `strategy_max_span_bars` | 160 | >= min span | Maximum A-to-F pattern span in H4 bars. |
| `strategy_pivot_scan_bars` | 190 | >= span plus pivot window | Closed-bar history scanned for pivots once per new bar. |
| `strategy_drive_min` | 1.13 | positive | Lower bound for the source AB/XA drive extension gate. |
| `strategy_drive_max` | 1.618 | positive | Upper bound for the source AB/XA drive extension gate. |
| `strategy_mid_ext_min` | 1.618 | positive | Lower bound for the source BC/AB extension gate. |
| `strategy_mid_ext_max` | 2.24 | positive | Upper bound for the source BC/AB extension gate. |
| `strategy_final_retrace` | 0.50 | positive | Target final CD retracement of BC. |
| `strategy_ratio_tolerance` | 0.10 | 0.0+ | Allowed proportional error for 0.50 retracement and AB=CD equality. |
| `strategy_atr_period` | 14 | 1+ | ATR period used for the maximum allowed stop distance. |
| `strategy_atr_cap_mult` | 3.0 | positive | Skip entries whose entry-to-stop distance exceeds this ATR multiple. |
| `strategy_stop_fib_ext` | 1.618 | > 1.0 | Stop extension beyond F, using `(extension - 1.0) * final_drive`. |
| `strategy_tp_fraction` | 0.6666666667 | 0.0-1.0 | TP2 fraction of the distance from entry to pivot E. |
| `strategy_time_exit_bars` | 30 | 1+ | Maximum holding period in base timeframe bars. |

> Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed DWX forex target with enough H4 OHLC history for harmonic pivots.
- `GBPJPY.DWX` - Card-listed DWX forex target with volatile swings suited to six-pivot reversal structures.
- `XAUUSD.DWX` - Card-listed DWX metal target with large H4 swing ranges suited to harmonic pattern completion.
- `NDX.DWX` - Card-listed DWX index target with liquid H4 trend/reversal swings.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no verified DWX tester data.
- Symbols not registered for `QM5_9274` in `magic_numbers.csv` - no active magic slot.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through framework `OnTick` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 18 |
| Typical hold time | Up to 30 H4 bars, approximately five trading days. |
| Expected drawdown profile | Stop is structure-based beyond F and capped at 3.0 ATR, so losses should be bounded per setup. |
| Regime preference | Low-frequency price-action reversal after extended harmonic swings. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** MQL5 article
**Pointer:** `https://www.mql5.com/en/articles/19463`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9274_mql5-five-drives.md`

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
| v1 | 2026-06-20 | Initial build from card | 0156e0e9-4eaa-4205-819b-ad771d993510 |

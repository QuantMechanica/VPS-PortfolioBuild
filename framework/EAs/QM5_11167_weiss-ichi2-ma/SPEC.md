# QM5_11167_weiss-ichi2-ma - Strategy Spec

**EA ID:** QM5_11167
**Slug:** `weiss-ichi2-ma`
**Source:** `3005c768-aa91-5daf-9dd7-500d7bfcb7a6` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed D1 bars. A long signal occurs when SMA(9)[1] is above SMA(26)[1] and SMA(26)[1] is rising versus SMA(26)[2]. A short signal is implemented from the card's literal short bullet: SMA(26)[1] is below SMA(9)[1] and SMA(26)[1] is falling versus SMA(26)[2]. Existing positions are closed on the opposite qualified signal, and new entries use a market order with a catastrophic protective stop at max(3 * ATR(20,D1), broker minimum).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_sma_period` | 9 | 1+ | Fast SMA period used on D1 completed bars. |
| `strategy_slow_sma_period` | 26 | 1+ | Slow SMA period used for alignment and slope confirmation. |
| `strategy_atr_period` | 20 | 1+ | ATR period for the catastrophic protective stop. |
| `strategy_atr_sl_mult` | 3.0 | > 0 | ATR multiplier for the catastrophic protective stop. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX pair with native DWX D1 OHLC data.
- `USDJPY.DWX` - major FX pair with native DWX D1 OHLC data.
- `XAUUSD.DWX` - liquid metals exposure listed in the approved R3 basket.
- `XTIUSD.DWX` - liquid energy exposure listed in the approved R3 basket.
- `SP500.DWX` - S&P 500 custom symbol listed in the approved R3 basket; backtest-only for live promotion decisions.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no verified DWX test data.
- Non-D1 deployments - the card defines D1 completed-bar SMA logic only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` with D1 setfiles |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 10 |
| Typical hold time | Not specified in frontmatter; stop-and-reverse implies multi-day trend holds. |
| Expected drawdown profile | Trend-following whipsaw risk during sideways regimes. |
| Regime preference | Trend-following / moving-average-crossover. |
| Win rate target (qualitative) | Not specified in frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3005c768-aa91-5daf-9dd7-500d7bfcb7a6`
**Source type:** book
**Pointer:** Richard L. Weissman, *Mechanical Trading Systems: Pairing Trader Psychology with Technical Analysis*, Wiley, 2005, Chapter 3, pp. 52-53; approved card at `artifacts/cards_approved/QM5_11167_weiss-ichi2-ma.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11167_weiss-ichi2-ma.md`

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
| v1 | 2026-06-07 | Initial build from card | c8d68cf4-4547-4a70-a91d-e9151eaa91ee |

# QM5_12506_bb-bottom-w — Strategy Spec

**EA ID:** QM5_12506
**Slug:** `bb-bottom-w`
**Source:** `46758070-d6b1-52ef-a3ee-ffcbffb7bb54` (see `strategy-seeds/sources/46758070-d6b1-52ef-a3ee-ffcbffb7bb54/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA detects the Bollinger-band W-bottom reversal pattern on H1 bars. It scans the last 75 closed bars for three structural nodes: a first touch of the lower Bollinger band (first bottom), a subsequent recovery to the middle Bollinger band (middle node), and a second touch of or below the lower band at or below the first bottom's close (second bottom). When this W-shape is present and the most recent closed bar's close has broken above the upper Bollinger band, a long market order is placed. The position is held until the Bollinger band width contracts below a beta-ATR threshold (volatility squeeze exit) or until the ATR-based trailing stop is hit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 20–30 | SMA period for Bollinger Bands |
| `strategy_bb_deviation` | 2.0 | 1.5–2.5 | Sigma multiplier for BB upper/lower |
| `strategy_atr_period` | 20 | 14–20 | ATR period used for SL, alpha, and beta thresholds |
| `strategy_pattern_horizon` | 75 | 50–100 | Number of past closed bars to scan for W-bottom |
| `strategy_alpha_atr_fraction` | 0.05 | 0.025–0.1 | Band-touch tolerance = fraction of ATR |
| `strategy_beta_atr_fraction` | 0.05 | 0.025–0.1 | BB-width exit threshold = fraction of ATR |
| `strategy_sl_atr_mult` | 3.0 | 2.0–4.0 | Emergency SL distance = mult × ATR below entry ask |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep liquidity FX pair; clear BB mean-reversion dynamics
- `GBPUSD.DWX` — high-volume cable pair; volatile enough for clear W-bottoms
- `USDJPY.DWX` — liquid USD/JPY; responds well to support/resistance at BB extremes
- `XAUUSD.DWX` — gold; strong trend-and-revert character suits W-bottom detection
- `NDX.DWX` — Nasdaq 100 index; pronounced V/W recovery patterns after sell-offs
- `WS30.DWX` — Dow 30 index; broad-market recoveries generate W-shapes on BB

**Explicitly NOT for:**
- Monthly (MN1) instruments — untestable in MT5 tester per project constraint

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` (default; H4 is an alternative sweep in P3) |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~6 |
| Typical hold time | hours to days |
| Expected drawdown profile | medium; emergency ATR stop limits per-trade risk |
| Regime preference | mean-revert / volatility-expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `46758070-d6b1-52ef-a3ee-ffcbffb7bb54`
**Source type:** other (GitHub script)
**Pointer:** https://github.com/je-suis-tm/quant-trading/blob/master/Bollinger%20Bands%20Pattern%20Recognition%20backtest.py
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12506_bb-bottom-w.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-11 | Initial build from card | 7a8f0aba-004b-4d61-bcdf-0a8f033cdf0d |

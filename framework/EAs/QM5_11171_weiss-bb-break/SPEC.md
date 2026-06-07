# QM5_11171_weiss-bb-break - Strategy Spec

**EA ID:** QM5_11171
**Slug:** `weiss-bb-break`
**Source:** `3005c768-aa91-5daf-9dd7-500d7bfcb7a6`
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates the completed D1 bar. It opens long when the last close is above the upper 20-period Bollinger Band with 2.0 standard deviations, and opens short when the last close is below the lower band. It exits a long when price touches or crosses back down to the 20-period Bollinger middle line, and exits a short when price touches or crosses back up to that same middle line. There is no profit target; a catastrophic protective stop is placed at the greater of 3 x ATR(20) or the broker minimum stop distance.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 16-24 in optional P3 sweep | Bollinger Band and middle-line lookback period |
| `strategy_bb_deviation` | 2.0 | 1.8-2.4 in optional P3 sweep | Standard-deviation multiplier for the entry bands |
| `strategy_atr_period` | 20 | fixed by card fallback | ATR period for the catastrophic protective stop |
| `strategy_atr_stop_mult` | 3.0 | fixed by card fallback | ATR multiple for the catastrophic protective stop |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair from the card's primary P2 basket.
- `USDJPY.DWX` - liquid major FX pair from the card's primary P2 basket.
- `XAUUSD.DWX` - liquid metal market from the card's primary P2 basket.
- `XTIUSD.DWX` - liquid energy market from the card's primary P2 basket.
- `SP500.DWX` - S&P 500 custom symbol from the card's primary P2 basket; valid for backtest only.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the build registry only supports verified DWX symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 9 |
| Typical hold time | Days to weeks, inferred from D1 breakout entries and 20-day mean exits |
| Expected drawdown profile | Trend-following whipsaw risk around the middle band, with catastrophic ATR stop protection |
| Regime preference | Trend-following breakout and volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3005c768-aa91-5daf-9dd7-500d7bfcb7a6`
**Source type:** book
**Pointer:** Richard L. Weissman, *Mechanical Trading Systems: Pairing Trader Psychology with Technical Analysis*, Chapter 3, pp. 60-62; web text at `https://studylib.net/doc/28245153/richard-l.-weissman---mechanical-trading-systems`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11171_weiss-bb-break.md`

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
| v1 | 2026-06-07 | Initial build from card | 1e86e1bf-743a-46a5-acb9-df524efca157 |

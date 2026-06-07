# QM5_11168_weiss-ma3-flat - Strategy Spec

**EA ID:** QM5_11168
**Slug:** weiss-ma3-flat
**Source:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6 (see `strategy-seeds/sources/3005c768-aa91-5daf-9dd7-500d7bfcb7a6/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed D1 bars. It opens long when SMA(9) is above SMA(26) and SMA(26) is above SMA(52), and it opens short when SMA(9) is below SMA(26) and SMA(26) is below SMA(52). Long positions close when either part of the bullish stack breaks; short positions close when either part of the bearish stack breaks. There is no profit target; the only protective stop is a catastrophic stop at the larger of 3 * ATR(20) or the broker minimum stop distance.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_sma_period` | `9` | `1+` | Fast SMA period from the card. |
| `strategy_mid_sma_period` | `26` | `1+` | Middle SMA period from the card. |
| `strategy_slow_sma_period` | `52` | `1+` | Slow SMA period from the card. |
| `strategy_atr_period` | `20` | `1+` | ATR period for the catastrophic protective stop. |
| `strategy_atr_stop_mult` | `3.0` | `0+` | ATR multiplier for the catastrophic protective stop. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX pair explicitly listed in the card's R3 basket.
- `USDJPY.DWX` - major FX pair explicitly listed in the card's R3 basket.
- `XAUUSD.DWX` - liquid metals symbol explicitly listed in the card's R3 basket.
- `XTIUSD.DWX` - liquid energy symbol explicitly listed in the card's R3 basket.
- `SP500.DWX` - S&P 500 custom symbol explicitly listed in the card's R3 basket; backtest-only per DWX symbol discipline.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX data contract for pipeline testing.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P 500 variants; the canonical custom symbol is `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `8` |
| Typical hold time | Multiple D1 bars until the 9/26/52 SMA stack de-stacks. |
| Expected drawdown profile | Trend-following drawdowns can cluster during sideways or whipsaw periods. |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

Card frontmatter frequency: Daily 9/26/52 SMA neutral trend follower; Weissman reports 65-84 trades per asset over 10 years, so use 8 trades/year/symbol conservatively.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6
**Source type:** book
**Pointer:** Richard L. Weissman, *Mechanical Trading Systems: Pairing Trader Psychology with Technical Analysis*, Wiley, 2005, Chapter 3, pp. 53-54, https://studylib.net/doc/28245153/richard-l.-weissman---mechanical-trading-systems
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11168_weiss-ma3-flat.md`

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
| v1 | 2026-06-07 | Initial build from card | 30759998-e303-4e70-8cb9-72ce4a16621c |

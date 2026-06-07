# QM5_11166_weiss-chan-swing - Strategy Spec

**EA ID:** QM5_11166
**Slug:** weiss-chan-swing
**Source:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades a daily Donchian channel breakout. On each completed D1 bar it refreshes a buy stop at the highest high of the prior 15 D1 bars and a sell stop at the lowest low of the prior 15 D1 bars, with no new entry allowed while this EA already has a position on the symbol. Long positions close when price breaks the prior 8-day low or after 8 D1 bars, and short positions close when price breaks the prior 8-day high or after 8 D1 bars. The protective stop is 2 x ATR(20,D1), clamped between 1% and 5% of entry price.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_entry_channel_bars | 15 | 1+ | D1 lookback for breakout stop levels. |
| strategy_exit_channel_bars | 8 | 1+ | D1 lookback for opposite channel exits. |
| strategy_max_hold_bars | 8 | 1+ | Maximum holding period in D1 bars. |
| strategy_atr_period | 20 | 1+ | ATR period for the protective stop. |
| strategy_atr_mult | 2.0 | >0 | ATR multiplier for the protective stop before clamping. |
| strategy_min_stop_pct | 1.0 | >=0 | Minimum stop distance as percent of entry price. |
| strategy_max_stop_pct | 5.0 | >= strategy_min_stop_pct | Maximum stop distance as percent of entry price. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid major FX pair in the card's portable D1 basket.
- USDJPY.DWX - liquid major FX pair in the card's portable D1 basket.
- XAUUSD.DWX - liquid metal symbol in the card's portable D1 basket.
- XTIUSD.DWX - liquid energy symbol in the card's portable D1 basket.
- SP500.DWX - available S&P 500 custom symbol for backtest-only index exposure.

**Explicitly NOT for:**
- SPX500.DWX - not a canonical available DWX custom symbol.
- SPY.DWX - not a canonical available DWX custom symbol.
- ES.DWX - not a canonical available DWX custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 18 |
| Typical hold time | Up to 8 D1 bars |
| Expected drawdown profile | Trend-breakout losses controlled by ATR stop clamped to a 1%-5% price band. |
| Regime preference | breakout / trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6
**Source type:** book
**Pointer:** Richard L. Weissman, Mechanical Trading Systems: Pairing Trader Psychology with Technical Analysis, Wiley, 2005, Chapters 3 and 5, pp. 59-60 and 92-94, https://studylib.net/doc/28245153/richard-l.-weissman---mechanical-trading-systems
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11166_weiss-chan-swing.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-07 | Initial build from card | 0853bd38-4e0b-40bc-aa4f-26652e6efb00 |

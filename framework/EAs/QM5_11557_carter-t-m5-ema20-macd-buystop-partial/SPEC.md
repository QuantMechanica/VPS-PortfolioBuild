# QM5_11557_carter-t-m5-ema20-macd-buystop-partial - Strategy Spec

**EA ID:** QM5_11557
**Slug:** carter-t-m5-ema20-macd-buystop-partial
**Source:** 42530cb3-0265-534a-89cc-150f80733ff5 (see `strategy-seeds/sources/42530cb3-0265-534a-89cc-150f80733ff5/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades the Carter System #18 M5 EMA(20) and MACD breakout rule. A long setup requires the previous closed bar to cross from below EMA(20) to above EMA(20), while MACD(12,26,9) has crossed above zero within the last five closed bars; it then places a Buy Stop 10 pips above the current EMA(20). A short setup mirrors the same rule below EMA(20) with a recent MACD zero-line cross down and a Sell Stop 10 pips below the current EMA(20). The initial stop is 20 pips from entry, half the position is closed at 1R, and the remainder is moved to breakeven and trailed by EMA(20) +/- 15 pips.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_period | 20 | 2-200 | EMA period used for price cross, stop-order anchor, and trailing stop. |
| strategy_macd_fast | 12 | 2-100 | MACD fast EMA period. |
| strategy_macd_slow | 26 | 3-200 | MACD slow EMA period. |
| strategy_macd_signal | 9 | 2-100 | MACD signal period. |
| strategy_macd_recency_bars | 5 | 1-20 | Closed-bar lookback window for the MACD zero-line cross. |
| strategy_entry_offset_pips | 10 | 1-50 | Stop-order offset from EMA(20). |
| strategy_sl_pips | 20 | 1-25 | Initial conservative stop distance in pips. |
| strategy_pending_expiry_bars | 1 | 1-12 | Number of M5 bars before an unfilled pending order expires. |
| strategy_partial_close_pct | 50.0 | 1-99 | Percent of original position volume closed at 1R. |
| strategy_trail_offset_pips | 15 | 1-50 | EMA trail offset for the remaining position. |
| strategy_no_friday_entry | true | true/false | Blocks new entries on Friday broker time. |
| strategy_spread_pct_of_stop | 25.0 | 0-100 | Wide-spread cap expressed as percent of stop distance; zero modeled spread passes. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - the card's R3 row explicitly names M5 EURUSD.DWX with available DWX history.

**Explicitly NOT for:**
- Non-EURUSD.DWX FX pairs - not listed in the card's R3 PASS section for this specific EA.
- Indices, metals, energy, and crypto `.DWX` symbols - outside the Carter FX M5 setup described by the card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 250 |
| Typical hold time | Intraday, usually minutes to hours depending on 1R and EMA trailing stop. |
| Expected drawdown profile | Frequent small fixed-risk losses with partial exits intended to reduce tail exposure. |
| Regime preference | Intraday EMA breakout / momentum continuation. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 42530cb3-0265-534a-89cc-150f80733ff5
**Source type:** book / self-published PDF
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11557_carter-t-m5-ema20-macd-buystop-partial.md`

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
| v1 | 2026-06-20 | Initial build from card | 84cbf3df-3dac-48df-a342-ff970370db88 |

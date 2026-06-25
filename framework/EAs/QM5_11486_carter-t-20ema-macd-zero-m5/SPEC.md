# QM5_11486_carter-t-20ema-macd-zero-m5 - Strategy Spec

**EA ID:** QM5_11486
**Slug:** carter-t-20ema-macd-zero-m5
**Source:** b3b11449-1e72-5140-917b-c35b6253f1e7
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades the M5 Carter System #18 setup: price must cross the 20 EMA on the just-closed bar, while MACD main has been on the confirming side of zero within the last five closed bars. A long places a buy stop 10 pips above EMA20, with stop 20 pips below EMA20; a short places a sell stop 10 pips below EMA20, with stop 20 pips above EMA20. Once filled, the EA closes half at 1R, moves the remainder to breakeven, and trails the remainder by EMA20 minus or plus 15 pips.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_ema_period | 20 | 1+ | EMA period used for price cross, pending entry anchor, stop anchor, and trail anchor. |
| strategy_macd_fast | 12 | 1+ | MACD fast EMA period. |
| strategy_macd_slow | 26 | 1+ | MACD slow EMA period. |
| strategy_macd_signal | 9 | 1+ | MACD signal period. |
| strategy_macd_lookback | 5 | 1+ | Closed bars checked for MACD main on the confirming zero-line side. |
| strategy_entry_offset_pips | 10 | 1+ | Pending stop entry offset from EMA20. |
| strategy_stop_ema_pips | 20 | 1+ | Conservative stop offset from EMA20. |
| strategy_trail_ema_pips | 15 | 1+ | Remainder trailing stop offset from EMA20 after TP1. |
| strategy_partial_fraction | 0.5 | 0.0-1.0 | Fraction of position to close at TP1. |
| strategy_tp_rr | 1.0 | 0.1+ | Risk multiple where the partial close is attempted. |
| strategy_spread_cap_pips | 15 | 1+ | Maximum spread in pips for new trade processing. |
| strategy_no_friday_entry | true | true/false | Suppresses new entries on Friday per the card. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed M5 DWX forex symbol.
- GBPUSD.DWX - card-listed M5 DWX forex symbol.
- USDJPY.DWX - card-listed M5 DWX forex symbol.
- AUDUSD.DWX - card-listed M5 DWX forex symbol.
- USDCAD.DWX - card-listed M5 DWX forex symbol.

**Explicitly NOT for:**
- Non-DWX symbols - build and pipeline artifacts use the Darwinex `.DWX` research symbols only.
- Non-FX index symbols - the card's R3 universe is M5 DWX forex, not an equity-index basket.

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
| Trades / year / symbol | 120 |
| Typical hold time | Intraday M5 hold; minutes to hours depending on EMA trail. |
| Expected drawdown profile | Moderate per-trade risk with frequent small stops and occasional trailed winners. |
| Regime preference | Short-term trend change and momentum continuation. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b3b11449-1e72-5140-917b-c35b6253f1e7
**Source type:** self-published strategy article/book excerpt
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", System #18 (thomascarterbook.blogspot.com, 2014)
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11486_carter-t-20ema-macd-zero-m5.md`

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
| v1 | 2026-06-25 | Initial build from card | 6171563c-375a-4f66-8364-5cf91a38ea1c |

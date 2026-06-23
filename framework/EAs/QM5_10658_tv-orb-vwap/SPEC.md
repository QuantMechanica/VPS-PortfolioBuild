# QM5_10658_tv-orb-vwap - Strategy Spec

**EA ID:** QM5_10658
**Slug:** tv-orb-vwap
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see TradingView source URL in approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades an M5 opening-range breakout. It builds the first 3 bars after the configured session open as the opening range, accumulates session VWAP from M5 typical price and tick volume, and buys when a closed bar breaks above the range high while price is above rising VWAP, volume clears the baseline, and the candle closes in the upper 70% of its range. Shorts mirror the rule below the range low, below falling VWAP, with a close in the lower 70%. The stop is the opposite side of the opening range, the target is 1.0 times the opening-range size, and any open position is forced flat outside the configured session.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| InpSessionOpenMinutesET | 570 | 0-1439 | Session open reference time in ET minutes-of-day, default 09:30 ET. |
| InpSessionEndMinutesET | 720 | 0-1439 | Session end reference time in ET minutes-of-day, default 12:00 ET. |
| InpOpeningRangeBars | 3 | 1-6 | Number of M5 bars used to define the opening range. |
| InpVwapSlopeLookback | 5 | 1-20 | Bars used to test whether VWAP is rising or falling. |
| InpVolAvgLookback | 20 | 1-100 | Prior bars used for the tick-volume baseline. |
| InpVolMult | 1.0 | 0.0-5.0 | Breakout tick-volume must exceed baseline times this multiplier. |
| InpCandleStrength | 0.70 | 0.50-0.95 | Required close location inside the breakout candle range. |
| InpTpRangeMult | 1.0 | 0.25-3.0 | Take-profit distance as a multiple of opening-range size. |
| InpMaxTradesPerDay | 2 | 1-4 | Maximum entries allowed per session/day. |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - Nasdaq 100 US index proxy named in the approved R3 basket.
- SP500.DWX - S&P 500 custom-symbol proxy already registered for this EA; backtest-only caveat remains a T6 concern.
- WS30.DWX - Dow 30 US index proxy named in the approved R3 basket.
- GDAXI.DWX - DAX custom-symbol equivalent for card-stated GER40.DWX, which is not present in the matrix.
- XAUUSD.DWX - Gold proxy named in the approved R3 basket.
- EURUSD.DWX - Major FX pair named in the approved R3 basket.
- GBPUSD.DWX - Major FX pair named in the approved R3 basket.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is used instead.
- SPX500.DWX, SPY.DWX, ES.DWX - unavailable S&P 500 variants; SP500.DWX is the canonical custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | intraday, minutes to a few hours |
| Expected drawdown profile | repeated small losses in choppy session opens |
| Regime preference | breakout / volatility-expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/wLSGHPUe-ORB-Breakout-Strategy-with-VWAP-and-Volume-Filters/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10658_tv-orb-vwap.md`

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
| v1 | 2026-06-23 | Initial build from card | 1003eb65-efc7-4304-86ef-9108dbcff7e1 |

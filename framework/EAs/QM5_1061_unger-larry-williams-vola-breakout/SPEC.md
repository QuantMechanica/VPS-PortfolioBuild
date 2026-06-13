# QM5_1061_unger-larry-williams-vola-breakout - Strategy Spec

**EA ID:** QM5_1061
**Slug:** unger-larry-williams-vola-breakout
**Source:** eb97a148-0af9-5b9c-878c-25fb5dfa34f9 (see `sources/unger-robbins-cup`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

At the first bar of the symbol's cash session, the EA reads today's D1 open and the prior day's D1 high-low range. It places a buy stop at `Open_today + K * yesterday_range` and a sell stop at `Open_today - K * yesterday_range`, with each order expiring at the session close. The first filled side cancels the opposite pending order, no profit target is used, and open trades are closed at the cash-session close. Stop loss is `SL_ATR * ATR(14, D1)` from the pending entry price.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_k` | 0.50 | 0.30-0.70 | Multiplier applied to yesterday's D1 range for the breakout trigger. |
| `strategy_atr_period` | 14 | 5-50 | D1 ATR lookback used for the stop distance. |
| `strategy_sl_atr_mult` | 1.50 | 1.00-2.00 | ATR multiple used to place the hard stop loss. |
| `strategy_spread_days` | 20 | 5-60 | D1 spread sample count used for the median-spread entry filter. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` - canonical DAX custom symbol in the DWX matrix, used for the card's GER40/DAX exposure.
- `NDX.DWX` - Nasdaq 100 index exposure from the approved card universe.
- `WS30.DWX` - Dow 30 index exposure from the approved card universe.
- `XAUUSD.DWX` - gold exposure from the approved card universe.

**Explicitly NOT for:**
- `GER40.DWX` - card label, not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered canonical substitute.
- `SP500.DWX` - not part of this card's approved R3 universe.
- Forex-only baskets - the edge is specified for index and metal cash-session breakouts.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `PERIOD_D1` open, prior-day high/low, and ATR(14) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | Intraday, from cash-session breakout fill to same-session close or ATR stop. |
| Expected drawdown profile | Bounded by fixed ATR stop and one armed breakout pair per symbol per day. |
| Regime preference | Volatility-expansion breakout during liquid cash sessions. |
| Win rate target (qualitative) | Medium; no profit target, winners run until time exit. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** eb97a148-0af9-5b9c-878c-25fb5dfa34f9  
**Source type:** book plus podcast support  
**Pointer:** `sources/unger-robbins-cup`; Andrea Unger, *The Unger Method*, chapter 3  
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1061_unger-larry-williams-vola-breakout.md`

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
| v1 | 2026-06-13 | Initial build from card | 746a9558-0bf7-4fc8-8c9a-d1b11c9ec185 |

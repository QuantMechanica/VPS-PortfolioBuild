# QM5_11582_goodwin-asian-session-breakout-usdjpy-h1 - Strategy Spec

**EA ID:** QM5_11582
**Slug:** goodwin-asian-session-breakout-usdjpy-h1
**Source:** d0660b7f-b405-5126-b8d1-7e0734054c2d (see `strategy-seeds/sources/d0660b7f-b405-5126-b8d1-7e0734054c2d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA trades USDJPY.DWX after the NY-close session boundary. Each day it reads the prior closed D1 candle: bullish prior day permits only a long breakout, bearish prior day permits only a short breakout, and a doji produces no entry. It scans M1 bars from 00:00 to 04:30 broker time, places or simulates the corresponding stop breakout on the first H1 framework gate after the range cutoff, uses a fixed 150-pip stop, and exits any open position at the 23:50 broker-time session close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_session_start_broker_minute | 0 | 0-1439 | Broker minute for the NY-close session start, mapping 17:00 ET to 00:00 broker. |
| strategy_range_cutoff_broker_minute | 270 | 0-1439 | Broker minute for the 21:30 ET range cutoff. |
| strategy_h1_order_gate_broker_minute | 300 | 0-1439 | First H1 framework gate after the 04:30 broker cutoff. |
| strategy_pending_expiry_broker_minute | 390 | 0-1439 | Broker minute for pending stop expiry, mapping 23:30 ET to 06:30 broker. |
| strategy_eod_exit_broker_minute | 1430 | 0-1439 | Broker minute for the 16:50 ET time exit. |
| strategy_sl_pips | 150 | 1-1000 | Fixed stop-loss distance in pips. |
| strategy_spread_cap_pips | 20 | 1-1000 | Fail-open spread guard; only genuinely wide positive spread blocks. |

---

## 3. Symbol Universe

**Designed for:**
- USDJPY.DWX - the card names USD/JPY and R3 confirms USDJPY.DWX data availability.

**Explicitly NOT for:**
- Non-JPY FX pairs - the source card and fixed pip stop are specified for USD/JPY only.
- Index and commodity symbols - the prior-D1 direction plus Asian-session range is not carded for those markets.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | D1 prior-candle direction; M1 session range scan |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Intraday, from post-range breakout until 23:50 broker or SL |
| Expected drawdown profile | Fixed 150-pip stop with no martingale or grid exposure |
| Regime preference | Breakout / volatility expansion after the Asian-session range |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d0660b7f-b405-5126-b8d1-7e0734054c2d
**Source type:** book / guidebook
**Pointer:** Jarrod Goodwin, "Beat the Markets Strategy Guidebook", thetransparenttrader.com, Strategy 3
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11582_goodwin-asian-session-breakout-usdjpy-h1.md`

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
| v1 | 2026-06-23 | Initial build from card | 17b6393f-fbb4-4c64-9e61-04e4145c659e |

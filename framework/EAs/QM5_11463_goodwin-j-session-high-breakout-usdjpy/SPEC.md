# QM5_11463_goodwin-j-session-high-breakout-usdjpy - Strategy Spec

**EA ID:** QM5_11463
**Slug:** goodwin-j-session-high-breakout-usdjpy
**Source:** 038d2a5d-1c89-5745-afdb-2cd76b623b77 (see `sources/goodwin-j-beat-markets-guidebook`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA builds the 17:00-21:30 EST session range using M30 bars, expressed in broker time as 23:00 to 03:30. After that range is complete, it checks the prior D1 candle: if the prior D1 close is above its open, it places a buy stop at the session high; if the prior D1 close is below its open, it places a sell stop at the session low. Each order has a fixed 150-pip stop and no take profit. Open positions are closed and unfilled pending orders are cancelled at 16:50 EST, expressed as 22:50 broker time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_session_open_min` | 1380 | 0-1439 | Broker-time minute for the session range start, default 23:00. |
| `strategy_accum_end_min` | 210 | 0-1439 | Broker-time minute when the range stops accumulating and the stop order may be placed, default 03:30. |
| `strategy_eod_exit_min` | 1370 | 0-1439 | Broker-time minute for EOD flatten and pending-order cancellation, default 22:50. |
| `strategy_stop_loss_pips` | 150 | >0 | Fixed stop distance in pips from the stop-order entry price. |
| `strategy_spread_cap_pips` | 20 | >=0 | Blocks new entries only when a genuinely positive spread exceeds this pip cap. |
| `strategy_use_prior_bar_filter` | true | true/false | Requires the prior D1 candle color to choose long or short direction. |

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - Goodwin's primary tested instrument and the card's primary FX pair.
- `EURUSD.DWX` - Card-listed portable major FX pair with H1/D1 DWX data.
- `GBPUSD.DWX` - Card-listed portable major FX pair with H1/D1 DWX data.

**Explicitly NOT for:**
- Non-FX index and commodity symbols - the approved R3 basket is FX H1/D1, and the source result is a USDJPY session breakout.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | D1 prior candle color; M30 session range bars inside the H1 strategy. |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 220 |
| Expected trade frequency | Daily session candidate, filtered by prior-D1 dojis, pending-order fills, spread, and EOD cancellation. |
| Typical hold time | Intraday, from post-range breakout to 22:50 broker EOD or fixed stop. |
| Expected drawdown profile | Breakout losses can cluster in quiet or false-break sessions; fixed 150-pip stop bounds each trade. |
| Regime preference | Session range breakout / volatility expansion. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 038d2a5d-1c89-5745-afdb-2cd76b623b77
**Source type:** book / guidebook
**Pointer:** Jarrod Goodwin, `Beat the Markets Strategy Guidebook`, local PDF `622374394-Beat-the-Markets-Strategy-Guidebook.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11463_goodwin-j-session-high-breakout-usdjpy.md`

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
| v1 | 2026-06-20 | Initial build from card | e033875b-f285-41b2-8bce-20079a3c66a1 |

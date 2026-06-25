# QM5_11406_carter-tf16-ema7-21-pullback — Strategy Spec

**EA ID:** QM5_11406
**Slug:** `carter-tf16-ema7-21-pullback`
**Source:** `29c77a02-59bd-52f7-bcb3-b3108d5f1e79` (Thomas Carter, *20 Trend Following Systems* (2014), Strategy #16)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

In an established trend the EA waits for price to pull back to the EMA21 and then
buys (or sells) the resumption. LONG requires the trend STATE — EMA7 above EMA21,
EMA21 sloping up (its value now is greater than 3 closed bars ago), and the last
closed price above both EMAs. The single trigger EVENT is a pullback: within the
last few closed bars a bar's Low touched or pierced EMA21. On the most recent such
"touch bar" the EA places a BUYSTOP one point above that bar's high, so it only
fills if price breaks out and confirms the bounce off the dynamic EMA21 support.
The stop-loss is the lowest low of the touch bar and the bars around it (risk
capped at 70 pips); the take-profit is twice the risk distance. Once an open
trade has moved by one ATR in profit, the stop is moved to breakeven. If the trend
flips (EMA7 crosses to the wrong side of EMA21) before the pending order fires,
the order is cancelled. SHORT is the exact mirror. One position or one pending
order per symbol at a time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 7 | 5-15 | Fast EMA; trend direction vs slow EMA |
| `strategy_ema_slow_period` | 21 | 15-30 | Slow EMA; dynamic S/R for the pullback touch |
| `strategy_slope_lookback` | 3 | 2-5 | EMA21 slope window (shift1 vs shift 1+N) |
| `strategy_pullback_lookback` | 3 | 1-5 | Closed bars (shift 1..N) scanned for the EMA21 touch |
| `strategy_sl_lookback` | 5 | 3-10 | Structure-stop window (extreme over N bars to touch bar) |
| `strategy_sl_cap_pips` | 70 | 20-120 | Hard cap on risk distance (pips) |
| `strategy_tp_rr` | 2.0 | 1.5-3.0 | Take-profit as RR multiple of risk |
| `strategy_be_atr_period` | 14 | 5-30 | ATR period for moving SL to breakeven after +1 ATR |
| `strategy_entry_buffer_pips` | 0 | 0-5 | Extra buffer past the trigger (0 = +1 point) |
| `strategy_pending_expiry_bars` | 3 | 1-10 | Cancel un-triggered pending after N bars |
| `strategy_spread_pct_of_stop` | 15.0 | 5-50 | Block only if spread exceeds this % of stop distance |

---

## 3. Symbol Universe

**Designed for:** liquid majors/crosses where EMA pullback trends are clean and
spreads are tight on H4.

- `EURUSD.DWX` — most liquid major; tight spread, clean EMA trends on H4.
- `GBPUSD.DWX` — trends strongly; good pullback behaviour.
- `USDJPY.DWX` — persistent directional moves; pullbacks respect the EMA21.
- `USDCHF.DWX` — major with smooth trends; mirror of EUR/USD flow.
- `EURJPY.DWX` — high-beta cross; pronounced trend/pullback cadence.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — gapless CFD pip-scaling and the 70-pip cap are
  forex-calibrated; the card scopes this EA to the five forex pairs above.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~50` |
| Typical hold time | `hours to a few days` (H4 swing) |
| Expected drawdown profile | `moderate; trend-following with capped 70-pip risk and 2R targets` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `low/medium` (RR 2.0 trend-following) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `29c77a02-59bd-52f7-bcb3-b3108d5f1e79`
**Source type:** `book`
**Pointer:** Thomas Carter, *20 Trend Following Systems* (2014), Strategy #16 — local PDF lineage only
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11406_carter-tf16-ema7-21-pullback.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor build |
| v2 | 2026-06-25 | Rebuild from card | d3bc19ac-bde3-458d-94e9-384a2181794a |

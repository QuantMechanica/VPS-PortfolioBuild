# QM5_11581_goodwin-kangaroo-tail-breakout-d1 - Strategy Spec

**EA ID:** QM5_11581
**Slug:** goodwin-kangaroo-tail-breakout-d1
**Source:** d0660b7f-b405-5126-b8d1-7e0734054c2d (see `sources/goodwin-beat-markets-strategy-guidebook`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades a D1 three-bar reversal pattern on USDJPY.DWX. After a new D1 bar opens, it checks whether the middle bar of the prior three closed bars made the lowest low for a long setup or the highest high for a short setup. The latest closed bar must satisfy the 0.5 percent close filter, then the EA places a buy stop at that bar's high or a sell stop at that bar's low. There is no take-profit; positions and unfilled pending orders are closed or removed at the broker-time end-of-day cutoff.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_close_filter_pct` | 0.5 | 0.0-5.0 | Maximum allowed percent close move between the latest closed bar and the middle setup bar. |
| `strategy_min_sl_pips` | 20 | 1-200 | Minimum stop-loss distance in pips; widens the structural stop when the latest closed bar range is too small. |
| `strategy_eod_close_hour_broker` | 23 | 0-23 | Broker-time hour for the end-of-day close and pending-order expiry. |
| `strategy_eod_close_min_broker` | 55 | 0-59 | Broker-time minute for the end-of-day close and pending-order expiry. |

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - the approved card's R3 PASS instrument and a verified DWX forex symbol with D1 history.

**Explicitly NOT for:**
- Other `.DWX` symbols - the approved card names USD/JPY only and does not authorize a portable basket expansion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | Less than one trading day; closed at broker-time EOD |
| Expected drawdown profile | Stop-order breakout reversal with fixed-risk sizing and no averaging |
| Regime preference | D1 reversal breakout after a three-bar kangaroo-tail structure |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d0660b7f-b405-5126-b8d1-7e0734054c2d
**Source type:** book
**Pointer:** Jarrod Goodwin, "Beat the Markets Strategy Guidebook", thetransparenttrader.com, Strategy 2
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11581_goodwin-kangaroo-tail-breakout-d1.md`

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
| v1 | 2026-06-25 | Initial build from card | 52b83c2e-6103-4a30-820e-8c897a8e3919 |

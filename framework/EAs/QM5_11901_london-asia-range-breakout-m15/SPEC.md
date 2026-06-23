# QM5_11901_london-asia-range-breakout-m15 - Strategy Spec

**EA ID:** QM5_11901
**Slug:** london-asia-range-breakout-m15
**Source:** c5e1f8b3-4a92-5d68-9c47-e3f6a1c8d4b9 (see `artifacts/cards_approved/QM5_11901_london-asia-range-breakout-m15.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA builds the Asia session range on M15 bars from 00:00 UTC through 07:59 UTC. Between 08:00 UTC and 11:00 UTC it waits for the first closed M15 candle that closes above the Asia high or below the Asia low, then enters in the breakout direction. A long trade uses the breakout candle low minus 2 pips as stop loss and a fixed 30-pip take profit; shorts mirror this with the breakout candle high plus 2 pips. Only the first valid breakout per UTC day can trade, and any remaining open position is closed at 20:00 UTC.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_asia_start_hour_utc` | 0 | 0-23 | UTC hour where the Asia range begins. |
| `strategy_asia_end_hour_utc` | 8 | 1-24 | UTC hour where the Asia range ends; default covers 00:00-07:59. |
| `strategy_london_open_hour_utc` | 8 | 0-23 | UTC hour where breakout scanning begins. |
| `strategy_breakout_window_minutes` | 180 | >0 | Minutes after London open where breakout closes are valid. |
| `strategy_required_asia_bars` | 32 | >0 | Minimum M15 bars required to accept the Asia range. |
| `strategy_scan_bars` | 96 | >= required bars | Bounded closed-bar scan depth for the session range. |
| `strategy_stop_buffer_pips` | 2 | >0 | Stop buffer beyond the breakout candle extreme. |
| `strategy_take_profit_pips` | 30 | >0 | Fixed take-profit distance from breakout close. |
| `strategy_timeout_hour_utc` | 20 | 0-23 | UTC hour for same-day hard timeout close. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - Primary Cable pair from the source, directly tied to London-session volatility expansion.
- `EURUSD.DWX` - Major London-session forex pair with high liquidity during the same window.
- `EURJPY.DWX` - London-session cross with enough European and JPY overlap volatility.
- `GBPJPY.DWX` - Sterling/Japan cross with strong London-open range expansion behaviour.
- `AUDJPY.DWX` - JPY cross included by the approved card as a portable London-session volatility extension.

**Explicitly NOT for:**
- `USDJPY.DWX` - Excluded by the approved card because it does not share the same London-open discontinuity as the selected basket.
- `USDCAD.DWX` - Excluded by the approved card for the same London-volume-fit reason.
- `USDCHF.DWX` - Excluded by the approved card for the same London-volume-fit reason.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `200` |
| Typical hold time | Intraday; from the London breakout window until TP, SL, or 20:00 UTC timeout. |
| Expected drawdown profile | Fixed-risk breakout profile with losses bounded by breakout candle extreme plus 2 pips. |
| Regime preference | Volatility expansion / session range breakout. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c5e1f8b3-4a92-5d68-9c47-e3f6a1c8d4b9
**Source type:** retail-FX community strategy PDF / forum-style source
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11901_london-asia-range-breakout-m15.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11901_london-asia-range-breakout-m15.md`

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
| v1 | 2026-06-23 | Initial build from card | 121aa02c-21b3-441a-b9c2-6612c9ff4789 |

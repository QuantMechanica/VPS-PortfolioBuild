# QM5_12425_gold-orb - Strategy Spec

**EA ID:** QM5_12425
**Slug:** gold-orb
**Source:** 041e0d5c-bf76-501d-bee2-31c0f4a6e233 (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades a gold H1 opening-range breakout on XAUUSD.DWX. The first H1 bar at the configured broker session-start hour seeds the opening range high and low; later H1 bars either expand that range or count as consolidation bars inside it. Once the required number of inside bars has formed, a bullish candle body breaking above the range creates signal 11 for a long entry, and a bearish candle body breaking below the range creates signal 10 for a short entry. Entries use fixed source point distances for SL and TP, with no adaptive equity-slope or losing-streak resume logic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `session_start_hour_broker` | 1 | 0-23 | Broker-time H1 hour whose closed candle seeds the opening range. |
| `range_consolidation` | 3 | 1+ | Number of subsequent in-range H1 candles required before breakout signals are armed. |
| `sl_points` | 400 | 1+ | Fixed stop-loss distance in raw MT5 points from the entry reference. |
| `tp_points` | 1200 | 0+ | Fixed take-profit distance in raw MT5 points; 0 disables TP. |
| `enable_long` | true | true/false | Allows signal 11 long entries. |
| `enable_short` | true | true/false | Allows signal 10 short entries. |
| `strategy_trailing_enabled` | false | true/false | Enables source-style trailing as a sweep parameter. |
| `trail_activate_points` | 700 | 1+ | Profit in raw points required before trailing begins. |
| `trail_lock_points` | 100 | 0+ | Minimum profit in raw points secured when trailing activates. |
| `trail_step_points` | 10 | 1+ | Minimum SL improvement in raw points before the trail moves again. |
| `max_forming_bars` | 24 | 0+ | Defensive bound on range formation bars before ignoring the session. |
| `max_spread_points` | 500 | 0+ | Spread cap in raw points; zero modeled spread remains tradable. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - The approved card and source repository target XAUUSD H1 directly, and the DWX matrix confirms the symbol exists.

**Explicitly NOT for:**
- Non-gold symbols - The session anchor and source point distances are calibrated to the XAUUSD opening-range breakout source.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | Not specified in card; bounded by fixed TP, fixed SL, optional trailing, and framework Friday close. |
| Expected drawdown profile | Breakout strategy with fixed point risk per trade and V5 fixed-risk backtest sizing. |
| Regime preference | Breakout / volatility expansion after an opening range. |
| Win rate target (qualitative) | Not specified in card. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 041e0d5c-bf76-501d-bee2-31c0f4a6e233
**Source type:** GitHub MQL5 repository
**Pointer:** https://github.com/yulz008/GOLD_ORB and `artifacts/cards_approved/QM5_12425_gold-orb.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12425_gold-orb.md`

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
| v1 | 2026-06-23 | Initial build from card | 4cbe3887-41a1-4589-917b-fa53d59bfd6b |

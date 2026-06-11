# QM5_11469_nekritin-peters-big-shadow-d1h4 - Strategy Spec

**EA ID:** QM5_11469
**Slug:** `nekritin-peters-big-shadow-d1h4`
**Source:** `7f773fbb-884e-54c9-a5d8-3f4087497622` (see `sources/nekritin-peters-naked-forex-wiley`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades a D1 two-candle Big Shadow pattern. A bullish setup requires the last closed candle to have a higher high and lower low than the candle before it, close above its open, close in the top 25% of its range, and make a new high versus the prior room-to-left window. A bearish setup mirrors those rules with a bearish close, bottom-quartile close, and a new low versus the room-to-left window.

Entries are stop orders one pip beyond the Big Shadow high or low and expire after one D1 bar. The stop loss is one pip beyond the opposite Big Shadow extreme, capped at 100 pips. The take profit is the nearest qualifying prior D1 fractal swing point in the profitable direction from the last 50 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_room_bars` | 7 | >= 1 | Prior D1 bars used for the room-to-left high or low test. |
| `strategy_close_near_pct` | 0.25 | 0.0-1.0 | Maximum fraction of the candle range allowed between close and the signal-side extreme. |
| `strategy_atr_multiplier` | 0.0 | >= 0.0 | Optional range filter; 0 disables it, values above 0 require Big Shadow range above ATR14 times this multiplier. |
| `strategy_entry_offset_pips` | 1 | >= 0 | Stop-entry offset beyond the Big Shadow high or low. |
| `strategy_stop_offset_pips` | 1 | >= 0 | Stop-loss offset beyond the opposite Big Shadow extreme. |
| `strategy_max_stop_pips` | 100 | > 0 | Maximum allowed stop distance in pips. |
| `strategy_spread_cap_pips` | 25 | > 0 | Maximum spread allowed for entry evaluation. |
| `strategy_sr_lookback_bars` | 50 | >= 5 | D1 bars scanned for prior fractal swing TP levels. |
| `strategy_fractal_wing` | 2 | >= 1 | Bars on each side required for a local fractal swing. |
| `strategy_min_tp_pips` | 1 | >= 0 | Minimum TP distance beyond the stop-entry price. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed major FX pair with D1 DWX data.
- `GBPUSD.DWX` - Card-listed major FX pair with D1 DWX data.
- `USDJPY.DWX` - Card-listed major FX pair with D1 DWX data.
- `AUDUSD.DWX` - Card-listed major FX pair with D1 DWX data.
- `USDCAD.DWX` - Card-listed major FX pair with D1 DWX data.

**Explicitly NOT for:**
- `SP500.DWX` - Not in the card's D1 FX basket.
- `NDX.DWX` - Not in the card's D1 FX basket.
- `XAUUSD.DWX` - Not in the card's D1 FX basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 8 |
| Typical hold time | days |
| Expected drawdown profile | Low-frequency stop-entry reversal system with full 100-pip stop cap per trade. |
| Regime preference | volatility-expansion reversal at support/resistance extremes |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `7f773fbb-884e-54c9-a5d8-3f4087497622`
**Source type:** book
**Pointer:** `sources/nekritin-peters-naked-forex-wiley`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11469_nekritin-peters-big-shadow-d1h4.md`

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
| v1 | 2026-06-11 | Initial build from card | 128cc12e-2250-494e-b149-a608b2a898a4 |

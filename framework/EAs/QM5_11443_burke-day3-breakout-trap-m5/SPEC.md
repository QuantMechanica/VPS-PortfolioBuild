# QM5_11443_burke-day3-breakout-trap-m5 - Strategy Spec

**EA ID:** QM5_11443
**Slug:** `burke-day3-breakout-trap-m5`
**Source:** `04305b6c-b4ce-522b-87b5-71708b6b8327` (see `sources/burke-stacey-playbook`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA looks for a three-day extension on D1, then fades that extension on M5. A short setup exists when each of the last three closed D1 candles is bullish and closes above the prior day's high; a long setup is the mirror, with bearish D1 candles closing below the prior day's low. During the London or NY UTC session window, the EA enters when the just-closed M5 candle crosses back through EMA(20) in the fade direction. Exits are handled by fixed 20-pip SL and 50-pip TP plus the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_pattern_bars` | 3 | 2-4 for planned P3 sweep | Count of consecutive closed D1 extension bars. |
| `strategy_ema_period` | 20 | 13-34 for planned P3 sweep | M5 EMA period used for cross-back timing. |
| `strategy_sl_pips` | 20 | 15-25 for planned P3 sweep | Fixed stop-loss distance in pips. |
| `strategy_tp_pips` | 50 | 30-75 for planned P3 sweep | Fixed take-profit distance in pips. |
| `strategy_london_start_utc` | 7 | 0-23 | London session start hour in UTC, inclusive. |
| `strategy_london_end_utc` | 12 | 1-24 | London session end hour in UTC, exclusive. |
| `strategy_ny_start_utc` | 13 | 0-23 | NY session start hour in UTC, inclusive. |
| `strategy_ny_end_utc` | 17 | 1-24 | NY session end hour in UTC, exclusive. |
| `strategy_spread_cap_pips` | 15 | 1-50 | Maximum real spread in pips; zero modeled spread passes. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed liquid major FX pair with M5 and D1 DWX history.
- `GBPUSD.DWX` - Card-listed liquid major FX pair with M5 and D1 DWX history.
- `USDJPY.DWX` - Card-listed liquid major FX pair with M5 and D1 DWX history.
- `AUDUSD.DWX` - Card-listed liquid major FX pair with M5 and D1 DWX history.
- `USDCAD.DWX` - Card-listed liquid major FX pair with M5 and D1 DWX history.

**Explicitly NOT for:**
- Index `.DWX` symbols - The card names FX instruments only.
- Metals, crypto, and commodities - The pip-based Burke FX session pattern was not approved for these markets.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `PERIOD_D1` for the three-day trap pattern |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework `OnTick` gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Typical hold time | Intraday; expected to close by fixed SL/TP or Friday close. |
| Expected drawdown profile | Mean-reversion snapback risk with clustered losses during persistent trends. |
| Regime preference | Mean-reversion after short-term directional extension. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `04305b6c-b4ce-522b-87b5-71708b6b8327`
**Source type:** book/playbook notes
**Pointer:** `707586131-1-Stacey-Burke-Best-Trade-Setups-Playbook-Notes-Part-2.pdf`, Part 2 pages 51-106
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11443_burke-day3-breakout-trap-m5.md`

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
| v1 | 2026-06-25 | Initial build from card | b4fc1a2a-9791-4ca4-b9d7-c7b7fb3cb97b |

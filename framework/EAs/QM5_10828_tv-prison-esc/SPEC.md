# QM5_10828_tv-prison-esc — Strategy Spec

**EA ID:** QM5_10828
**Slug:** `tv-prison-esc`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (TraderHayz, Prison Escape Breakout Strategy, TradingView)
**Author of this spec:** Claude
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

An opening-range breakout. From 08:30 America/Chicago a morning range-definition
window opens; confirmed swing pivots (a bar that is the highest/lowest of the
`pivot_depth` bars on each side) formed inside the window build a price range,
where `rangeHigh` is the maximum of the recent pivot highs and `rangeLow` is the
minimum of the recent pivot lows. The EA goes long when price closes above
`rangeHigh` for `breakout_closes` consecutive confirmed bars (default two) while
inside the 08:30–10:30 Chicago entry window; it goes short on the mirror
condition below `rangeLow`. A trade is skipped unless the range width is between
`range_min_atr_mult` and `range_max_atr_mult` times ATR(14). The protective stop
sits on the opposite side of the range and the take-profit is `target_rr` × the
entry-to-stop distance (1R baseline). All open positions are flattened at 12:30
Chicago. At most one position per symbol/magic and one entry per session day.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `pivot_depth` | 5 | 3-8 | Swing-pivot left/right confirmation bars |
| `pivot_lookback_n` | 2 | 1-32 | Recent pivot highs & lows spanning the range (A–D ≈ 2+2) |
| `breakout_closes` | 2 | 1-3 | Consecutive closes beyond the range to confirm a break |
| `range_min_atr_mult` | 0.5 | 0.0-3.0 | Skip if range width < this × ATR(`atr_period`) |
| `range_max_atr_mult` | 3.0 | 0.5-6.0 | Skip if range width > this × ATR(`atr_period`) |
| `atr_period` | 14 | 5-50 | ATR period for width / FVG filters |
| `target_rr` | 1.0 | 0.5-3.0 | Take-profit as a multiple of risk (1R baseline) |
| `use_fvg_filter` | false | bool | Optional 3-bar fair-value-gap confirmation |
| `fvg_atr_mult` | 0.5 | 0.0-1.0 | Min FVG width as × ATR(`atr_period`) when enabled |
| `session_start_chicago_hhmm` | 830 | 0-2359 | Range-def + entry window open (America/Chicago) |
| `entry_end_chicago_hhmm` | 1030 | 0-2359 | Entry window close (America/Chicago) |
| `hard_flat_chicago_hhmm` | 1230 | 0-2359 | Hard flat all positions (America/Chicago) |
| `chicago_to_broker_offset_hours` | 8 | 0-23 | broker(NY-close) = Chicago + 8h (constant; both follow US DST) |
| `max_spread_points` | 0 | 0-10000 | 0 = disabled; else block new entries above this spread |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` — Nasdaq 100; volatile US cash-open morning, the strategy's home regime (live-tradable).
- `WS30.DWX` — Dow 30; same US index-open breakout behaviour (live-tradable).
- `GDAXI.DWX` — DAX 40; card names "GER40"; GDAXI.DWX is the matrix-canonical DAX symbol (port).
- `XAUUSD.DWX` — Gold; card-named metals leg with strong morning trends.

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only (broker does not route orders); not registered for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~180` |
| Typical hold time | `minutes to a few hours (intraday; hard flat 12:30 Chicago)` |
| Expected drawdown profile | `clustered losing days when the morning range chops / fails to follow through` |
| Regime preference | `breakout` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `forum` (TradingView open-source community script)
**Pointer:** `https://www.tradingview.com/script/8DYAhtxl-Prison-Escape-Breakout-Strategy/` (author `TraderHayz`)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10828_tv-prison-esc.md`

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
| v1 | 2026-06-06 | Initial build from card | 86cb48a2-2b29-4d89-a5f5-0fb57ef85a2d |

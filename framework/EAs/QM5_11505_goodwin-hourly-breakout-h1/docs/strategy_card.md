---
ea_id: QM5_11505
slug: goodwin-hourly-breakout-h1
type: strategy
source_id: 2a126283-6905-5bb7-903a-cccd5f2b533f
sources:
  - "[[sources/goodwin-beat-the-markets-strategy-guidebook]]"
concepts:
  - "[[concepts/session-breakout]]"
  - "[[concepts/daily-directional-filter]]"
  - "[[concepts/intraday-session-exit]]"
indicators:
  - "None (pure price action + session time filter)"
period: H1
source_citation: "Jarrod Goodwin, 'Beat the Markets — Strategy Guidebook', self-published / The Transparent Trader, ~2014. R1 CONDITIONAL — named individual, self-published."
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: Single source_id present; named-author self-published guidebook satisfies R1 (author track record not required per 2026-05-15 revision).
r2_mechanical: PASS
r2_reasoning: D1 bias check, session high/low BuyStop/SellStop, and time-window entry/exit all expressible as deterministic MT5-native iClose/iHigh/iLow comparisons.
r3_data_available: PASS
r3_reasoning: Targets USDJPY.DWX and GBPUSD.DWX, both live-tradable DWX FX instruments with H1+D1 history available.
r4_ml_forbidden: PASS
r4_reasoning: Pure price-action and time-filter logic; no ML, no adaptive PnL-dependent params, one position per magic.
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 60
card_body_incomplete: true
card_body_missing: "source_citation"
g0_approval_reasoning: "R1 source_id single Goodwin guidebook; R2 mechanical daily-bias session-breakout/time-exit with daily cadence supports >=2 trades/year/symbol; R3 DWX FX H1/D1 testable; R4 deterministic no ML/HR14 conflict"
---

# QM5_11505 Goodwin — Hourly Session Breakout (H1)

## Quelle
- Source: Jarrod Goodwin, "Beat the Markets — Strategy Guidebook", self-published / The Transparent Trader (~2014).
- Citation: 2014 URL/source record: [[sources/goodwin-beat-the-markets-strategy-guidebook]] / The Transparent Trader (www.thetransparenttrader.com).
- R1: CONDITIONAL — named author, self-published guidebook.

## Mechanik

**Concept**: Trade the NY session breakout in the direction confirmed by the prior daily bar. If yesterday's D1 bar closed higher than it opened (bullish), place a BuyStop at the session high as of 17:05 EST (start of NY session). Exit at session end. This combines a directional daily filter with a momentum session-breakout entry.

**Logic**: Yesterday's daily direction defines the prevailing bias. The session high at 17:05 EST captures the pre-NY range. A breakout above that level in an up-bias environment confirms momentum continuation into the NY session. The intraday exit removes overnight risk.

**Time conversion**: 
- Source time: "17:05 EST"
- EST = UTC-5; EDT = UTC-4
- Darwinex broker time = GMT+2 (outside US DST) / GMT+3 (during US DST)
- 17:05 EST = 22:05 UTC = 00:05 broker time (GMT+2) / 01:05 broker time (GMT+3)
- QM P1: Parameterize entry hour as broker-time hours — use `ENTRY_HOUR` and `ENTRY_MINUTE` input, default to broker-time equivalent.
- Session end source: "21:30–22:00 EST" = ~02:30–03:00 broker time (GMT+2)

**QM note**: Session entry at midnight-area broker time means this strategy straddles a D1 candle boundary on Darwinex's broker time. The "daily bar" direction check uses the D1 bar most recently completed before the entry window. This is `iClose(NULL,PERIOD_D1,1) > iOpen(NULL,PERIOD_D1,1)` checked at entry time.

**Note**: Source specifies USD/JPY explicitly. QM assigns H1 as the timeframe (H1 chart for OHLC access).

### Entry

**LONG (NY session breakout, bullish daily bias):**
1. **Daily bias check**: `iClose(NULL,PERIOD_D1,1) > iOpen(NULL,PERIOD_D1,1)` — prior D1 bar is bullish
2. **Time check**: Current time is within the entry window: broker-time hour = 00 (or 01 during DST), minute = 05–15 (one check per bar)
3. **Session high tracking**: Compute the highest high from 17:05 EST today up to current bar: `iHighest(NULL,PERIOD_H1,MODE_HIGH,<bars_since_session_start>,0)`
4. Place BuyStop pending order at `session_high + 1 pip`; GTC expiry = end of session (~02:30–03:00 broker time)
5. **SL**: 150 pips fixed (source-specified)

**SHORT (bearish daily bias):**
1. `iClose(NULL,PERIOD_D1,1) < iOpen(NULL,PERIOD_D1,1)` — prior D1 bar is bearish
2. Same time window check
3. Session low: `iLowest(NULL,PERIOD_H1,MODE_LOW,<bars_since_session_start>,0)`
4. SellStop at `session_low - 1 pip`; same SL logic

### Exit
- **Session end exit**: Close all open trades when broker time reaches session end (~02:30 broker time = 21:30 EST); hardcoded time exit
- **SL**: 150 pips fixed (source-specified)
- **TP**: Source unspecified for TP. QM P2: `2 × SL distance` (300 pips) OR session-end exit, whichever comes first.
- P2 cap: SL capped at 150 pips (matches source)

### Stop Loss
- `SL_long = entry - 150 * pip_size`
- `SL_short = entry + 150 * pip_size`
- Source: 150 pips fixed.

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: H1 (for OHLC access and iHighest/iLowest lookback)
- Instruments: USDJPY.DWX (source-specified), GBPUSD.DWX (QM expansion — session breakout common on GBP)
- Entry window: broker time 00:05–00:15 (GMT+2) or 01:05–01:15 (GMT+3 DST)
- Exit window: broker time 02:30–03:00
- No Friday entry (late NY session → Friday night → skip)
- Spread cap: 15 pips

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | CONDITIONAL | Jarrod Goodwin, self-published guidebook. Named individual, no verifiable institutional credentials. |
| R2 Mechanical | PASS | Daily bar: iClose/iOpen comparison on D1. Session high/low: iHighest/iLowest on H1. Time filter: broker time comparison. All MT5-native arithmetic. |
| R3 Data Available | PASS | H1 + D1 DWX FX. All MT5-native. |
| R4 No ML | PASS | Threshold comparisons + time filter only. No ML. |

G0 APPROVE eligible with CONDITIONAL R1 note. The EST→broker-time conversion is the main implementation risk. QM P1 must parameterize entry/exit hours and document the DST-aware conversion. Wide SL (150 pips) on H1 USD/JPY may be appropriate given NY session range, but R/R must be validated in P2.

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from Jarrod Goodwin, "Beat the Markets — Strategy Guidebook", ~2014

## Implementation Notes for Codex (P1)
- Input parameters: `ENTRY_HOUR_GMT2` (default 0), `ENTRY_MINUTE` (default 5), `EXIT_HOUR_GMT2` (default 2), `EXIT_MINUTE` (default 30), `DST_OFFSET` (default 0, set to 1 during US DST season)
- Entry window check: `Hour() == ENTRY_HOUR_GMT2 + DST_OFFSET && Minute() >= ENTRY_MINUTE && Minute() <= 15`
- `double daily_open1 = iOpen(NULL,PERIOD_D1,1)`, `double daily_close1 = iClose(NULL,PERIOD_D1,1)`
- Daily bias: `bool bullish_bias = daily_close1 > daily_open1`
- Session high: `int bars_since = (Hour() - ENTRY_HOUR_GMT2) + 1; double session_high = iHighest(NULL,PERIOD_H1,MODE_HIGH,bars_since,0);` (approximate)
- BuyStop pending: price = `session_high + pip_size`; SL = `entry - 150 * pip_size`; expiry = end of session
- Exit: At exit time, close all open trades on this symbol/EA
- P3 sweeps: entry time window (±1h), SL (100/150/200 pips), add 5-day SMA trend filter, session (NY vs London)

## Verwandte Strategien
- Related: QM5_11503 (goodwin-outside-daily-bar-d1) — same source
- Related: QM5_11504 (goodwin-kangaroo-tail-d1) — same source
- Related: QM5_11499 (langer-bb20-d1trend-m5-scalp) — D1 trend filter + intraday entry

## Lessons Learned
- *(populated as pipeline progresses)*

---
ea_id: QM5_1164
slug: unger-gold-donchian-bias
type: strategy
source_id: eb97a148-0af9-5b9c-878c-25fb5dfa34f9
sources:
  - "[[sources/unger-robbins-cup]]"
concepts:
  - "[[concepts/intraday-bias]]"
  - "[[concepts/channel-breakout]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/time-window]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "Unger Academy May 2024 SoM gold bias M15 Donchian(20) breakout in morning-long (08-12 NY) + night-short (20-02 NY) windows + time-based exit + ATR safety stop; R1 PASS Unger Academy article + book ISBN 978-8896590164; R2 PASS deterministic Donchian cross + fixed time windows + ATR stop; R3 PASS XAUUSD.D"
---

# Unger Gold Donchian Bias - Morning Long and Night Short Breakouts

## Quelle
- Source: [[sources/unger-robbins-cup]] - Unger Academy May 2024 Strategy of the Month article.
- Article: "Strategy of the Month (May 2024): The Winner Is a Simple but Highly Effective Bias on Gold" - Unger Academy.
- Location: "Winner: Bias Strategy on Gold" section; source describes a gold bias strategy that buys during the morning session and shorts at night, entering on Donchian Channel breaks, using time-based exits and a safety stop loss with no take profit.
- Supporting source: *The Unger Method - Andrea Unger's Trading Method* (Unger Academy Publishing, 2nd ed. 2021, ISBN 978-8896590164).

## Mechanik

Universe: XAUUSD.DWX primary. Execution timeframe M15.

### Entry
1. Compute Donchian Channel on completed M15 bars: default `DONCHIAN_N = 20`.
2. Long setup:
   - current time is inside the morning long window, default 08:00-12:00 New York time,
   - completed M15 close breaks above the prior Donchian upper channel.
3. Short setup:
   - current time is inside the night short window, default 20:00-02:00 New York time,
   - completed M15 close breaks below the prior Donchian lower channel.
4. Enter at market on signal-bar close.
5. One position per magic and one entry per bias window.

### Exit
- Time-based exit tied to the active bias window:
  - close long by 12:00 New York time,
  - close short by 02:00 New York time.
- Close earlier on safety stop.
- No take profit in first build, matching the source description.

### Stop Loss
- `SL = 1.5 * ATR(14,M15)`.
- P3 sweep Donchian length, long/short windows, and SL multiple.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25%`.

### Zusaetzliche Filter
- Skip major US macro releases for gold unless P8 later approves deployable news mode.
- Standard V5 spread filters.
- One position per magic.

## Concepts
- [[concepts/intraday-bias]] - primary
- [[concepts/channel-breakout]] - primary
- [[concepts/metals]] - secondary

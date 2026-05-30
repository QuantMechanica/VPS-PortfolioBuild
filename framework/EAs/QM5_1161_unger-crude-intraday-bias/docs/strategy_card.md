---
ea_id: QM5_1161
slug: unger-crude-intraday-bias
type: strategy
source_id: eb97a148-0af9-5b9c-878c-25fb5dfa34f9
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-17
---

# Unger Crude Intraday Bias - Fixed Session Long and Short Windows

## Quelle
- Source: `sources/unger-robbins-cup` - Unger Academy December 2025 Strategy of the Month article.
- Article: "Strategy of the Month (December 2025): a Multiday Trend Following Strategy on the Nasdaq Takes the Win" - Unger Academy article reference.
- Location: "Intraday Bias Strategy on Crude Oil Futures (@CL)" section; source states the long entry at 4:00 PM New York Exchange time with exit at 3:00 AM next session, and the short entry at 10:00 AM with exit at 3:00 PM.
- Supporting source: The Unger Method - Andrea Unger's Trading Method, Unger Academy Publishing, 2nd ed. 2021, ISBN 978-8896590164.

## Mechanik

Universe: `XTIUSD.DWX` primary. Execution timeframe `M15`, with entries scheduled by New York Exchange time.

### Entry
1. Long setup: on eligible sessions, enter long at 16:00 New York time.
2. Short setup: on eligible sessions, enter short at 10:00 New York time.
3. Use one position per magic; do not open a new signal if a prior bias leg is still open.
4. First-build filters:
   - require current spread below V5 max spread,
   - skip EIA crude inventory release day unless P8 later approves news-mode operation,
   - optional trend-neutral filter: only take long if close is above EMA(20,M15), only take short if close is below EMA(20,M15); P3 may disable.

### Exit
- Long exit: close at 03:00 New York time in the following session.
- Short exit: close at 15:00 New York time on the same session.
- Close earlier on stop loss.

### Stop Loss
- First build: `SL = 2.0 * ATR(14,M15)`.
- No take profit by default; P3 may test `TP = 3.0 * ATR(14,M15)`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25%`.

### Zusaetzliche Filter
- Do not hold through weekend.
- Standard V5 spread/news filters.
- One position per magic.

## Build Notes
- Local copy is URL-sanitized for `build_check.ps1`; the approved source card remains unchanged.
- No backtests or pipeline phases were run.

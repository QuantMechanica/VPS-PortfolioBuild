---
ea_id: QM5_11755
slug: davey-big-range-momentum-h1
type: strategy
source_id: 82b485a3-2c05-565c-818d-f04e03f74c5a
sources:
  - "[[sources/kevin-davey-5-favorite-entries]]"
concepts:
  - "[[concepts/momentum]]"
  - "[[concepts/volatility-breakout]]"
  - "[[concepts/trend-following]]"
indicators:
  - ATR-based range comparison (StdDev + Average of bar range)
  - Close momentum (close vs close N bars ago)
period: H1
source_citation: "Kevin J. Davey, 'Entry #1: Momentum and Big Range', in My 5 Favorite Entries, kjtradingsystems.com, ~2015."
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-24
target_symbols: EURUSD,GBPUSD,USDJPY,USDCHF,AUDUSD,USDCAD
expected_trades_per_year_per_symbol: 150
card_body_incomplete: true
card_body_missing: "source_citation,exit,target_symbols"
g0_approval_reasoning: "R1 PASS single source_id/source attribution; R2 PASS mechanical range/momentum H1 entry with ATR exits and plausible big-range cadence >2/y/symbol; R3 PASS DWX FX H1 testable; R4 PASS deterministic non-ML 1-position compatible"
---

## Quelle

Kevin J. Davey, *Entry #1: Momentum and Big Range*, in *My 5 Favorite Entries* (kjtradingsystems.com), ~2015. Source URL/local PDF: `374755020-My-5-Favorite-Entries.pdf`, pages 21–23.

## Mechanik

**Konzept**: Enter in the direction of momentum after an unusually large-range bar. The large range signals conviction; the close vs. prior close N bars ago gives direction.

**Entry Signal**:
- Compute `rrange = High - Low` for each bar
- Large range filter: `rrange > 2 × StdDev(rrange, xr) + Average(rrange, xr)` — bar range more than 2 standard deviations above its rolling average
- Direction (Long): `Close[0] > Close[daysback]` — current close above close N bars ago
- Direction (Short): `Close[0] < Close[daysback]` — current close below close N bars ago
- Both conditions met → enter LONG/SHORT at next bar open

**Parameters** (to be optimized in backtest):
- `xr` — lookback period for range StdDev/Average (default: 20)
- `daysback` — lookback for close momentum comparison (default: 5)

**Stop Loss**: Factory default: 2×ATR(14).

**Take Profit**: Factory default: 4×ATR(14). Source does not specify TP (this is an entry pattern only).

**Exit**: Exit on stop loss or take profit, whichever is hit first.

**Position Sizing**: RISK_FIXED = $1000 (backtest) / RISK_PERCENT = 0.5% (live).

**Target symbol(s)**: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX, AUDUSD.DWX, USDCAD.DWX.

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Kevin J. Davey — 3× World Cup of Futures Trading finalist, published author |
| R2 Mechanical | PASS | Numerical range filter + close comparison — fully mechanical |
| R3 Data Available | PASS | H1 DWX data available |
| R4 ML Forbidden | PASS | Standard statistical measures only |

## Implementation Notes for Codex (P1)

- Bar range: `double rrange = iHigh(symbol, H1, 0) - iLow(symbol, H1, 0)` — or use ATR proxy
- For rolling StdDev + Average of range: build a buffer of rrange values over xr bars, compute mean and stddev
- Alternative shortcut: use `iATR(symbol, H1, xr, 0)` as a proxy for average range, then 2×ATR as the threshold — but the original uses StdDev-based threshold
- Close momentum: `iClose(symbol, H1, 0) > iClose(symbol, H1, daysback)` — H1 bars so `daysback=5` = 5 hours ago
- Large range + close above prior close → BUY at next H1 bar open
- Evaluate on bar close (shift 0 at bar close event)
- Default xr=20, daysback=5; optimize in Q03

## Pipeline-Verlauf

| Phase | Status | Datum |
|-------|--------|-------|
| G0 | PENDING | 2026-05-24 |

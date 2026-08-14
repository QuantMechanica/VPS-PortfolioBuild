---
ea_id: QM5_11483
slug: williams-l-outside-bar-exhaustion-d1
type: strategy
source_id: 729c9425-1ec7-5842-a8b8-3db326d892e5
sources:
  - "[[sources/williams-larry-long-term-secrets-short-term-trading]]"
concepts:
  - "[[concepts/outside-bar]]"
  - "[[concepts/exhaustion-reversal]]"
  - "[[concepts/failed-continuation]]"
  - "[[concepts/stop-order-entry]]"
indicators: []
period: D1
source_citation: "Larry Williams, Long-Term Secrets to Short-Term Trading (John Wiley & Sons, 1999). R1 PASS — World Cup champion 1987, Wiley author. Outside bar setup sourced via Jarrod Goodwin's Beat the Markets Strategy Guidebook, crediting Williams."
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 15
g0_approval_reasoning: "R1 one source_id with Williams/Goodwin lineage attribution; R2 mechanical D1 outside-bar exhaustion entry/exit and plausible 15 trades/year/symbol; R3 DWX FX testable; R4 deterministic non-ML one-position rules."
---

# QM5_11483 Williams-L — Outside Bar Exhaustion Reversal (D1)

## Quelle
- Source: Larry Williams, "Long-Term Secrets to Short-Term Trading" (Wiley, 1999)
- R1: PASS — World Cup Trading Championship 1987 (2500%+ return), creator of Williams %R, multiple Wiley books.

## Mechanik

**Concept**: When a daily bar makes an Outside Bar (range expands beyond both extremes of the prior bar) AND closes below the prior bar's Low (apparently very bearish), this extreme selling exhausts itself. The market has swept all nearby stops and trapped bears at the very low of an extended range. The next session, as sellers find no follow-through, longs trapped by the breakdown cover and new buyers step in, causing a snap-back rally. The LONG entry at the next open captures this reversal.

**Counter-intuitive logic**: The close below prior Low appears bearish, but it signals capitulation — the selling was forced and exhausting, not orderly continuation. Williams trades the reversal of this exhaustion.

**Mirror SHORT**: Outside bar closes above prior High (apparent bullish exhaustion) → SHORT at next open.

### Entry

**LONG (bearish exhaustion outside bar):**
1. Outside bar: `High[1] > High[2]` AND `Low[1] < Low[2]` — bar[1] range exceeds prior bar's range in both directions
2. Bearish close: `Close[1] < Low[2]` — bar[1] closes below prior bar's low (extreme downside exhaustion)
3. Enter BUY at open of bar[0] (market order at next D1 open)
4. No Friday entry (do not enter at Sunday open following a Friday exhaustion bar — weekend gap risk)
5. SL = entry - 200 pips (Goodwin/Williams parametrization); or `Low[1] - ATR(14) × 0.5` if tighter

**SHORT (bullish exhaustion outside bar):**
1. `High[1] > High[2]` AND `Low[1] < Low[2]` (outside bar)
2. Bullish close: `Close[1] > High[2]` — closes above prior bar's high
3. Enter SELL at open of bar[0]
4. SL = entry + 200 pips

### Exit
- **Profit exit**: At close of bar[0] (the entry bar), check if position is profitable → if YES, exit at open of bar[1] (next bar's open); if NO, hold
- **Time stop / hard exit**: After 5 D1 bars open, exit regardless
- **SL**: 200 pips (hard stop from entry price)

### Stop Loss
- 200 pips from entry (Williams/Goodwin specification)
- P2 cap: 200 pips (trade is designed for high win rate with wide SL)

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: D1
- Instruments: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX
- Spread cap: 25 pips
- No Friday entry (avoid Sunday gap risk on the follow-through)
- P3 will test direction bias: LONG-only, SHORT-only, or both

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Larry Williams — World Cup 1987 champion, Wiley author "Long-Term Secrets to Short-Term Trading" (1999). |
| R2 Mechanical | PASS | Outside bar HH+LL: OHLC comparison. Close vs prior Low/High: OHLC. Market order at open. All MT5-native. |
| R3 Data Available | PASS | D1 DWX FX. iHigh/iLow/iClose/iOpen MT5-native. |
| R4 No ML | PASS | Binary OHLC conditions, fixed 200-pip SL. No ML. |

G0 APPROVE — R1 PASS (Williams, Wiley 1999).

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from Larry Williams, Long-Term Secrets to Short-Term Trading (Wiley 1999) via Goodwin's Beat the Markets Strategy Guidebook

## Implementation Notes for Codex (P1)
- Outside bar: `iHigh(D1,1) > iHigh(D1,2) && iLow(D1,1) < iLow(D1,2)`
- Bearish exhaustion (LONG): `iClose(D1,1) < iLow(D1,2)`
- Bullish exhaustion (SHORT): `iClose(D1,1) > iHigh(D1,2)`
- Entry: market order at `iOpen(D1,0)` on new bar trigger
- SL: 200 pips = `200 * SymbolInfoDouble(_Symbol,SYMBOL_POINT) * 10` (5-digit broker)
- Profit exit check: on next bar open, compare current price vs entry; if profit > 0, close at market
- Alternative: place TP order at `entry + 0.5*SL_pips` (50% of SL) to implement a 1:2 risk:reward instead of Williams's profit-exit logic; test both in P3
- P3 sweeps: SL pips (100/150/200), TP method (profit-exit-next-open/ATR-1x/fixed-100), minimum range (outside bar range > ATR/no filter), direction (both/LONG-only/SHORT-only)

## Verwandte Strategien
- Related: QM5_11477 (williams-l-fakeout-day-d1) — same source author; Fake-Out Day has HH+HL (not outside bar); different failure pattern
- Related: QM5_11478 (williams-l-smash-day-d1) — same author; Smash Day has close in lower half of OWN range (no outside bar requirement)
- Related: QM5_11461 (goodwin-j-outside-bar-daily-reversion-d1) — also D1 outside bar; Goodwin's version may use different close requirements

## Lessons Learned
- *(populated as pipeline progresses)*

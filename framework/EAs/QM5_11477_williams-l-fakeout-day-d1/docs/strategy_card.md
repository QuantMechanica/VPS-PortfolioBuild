---
ea_id: QM5_11477
slug: williams-l-fakeout-day-d1
type: strategy
source_id: b943674a-985e-5634-8420-47a9412c3ab5
sources:
  - "[[sources/williams-larry-inner-circle-workshop]]"
concepts:
  - "[[concepts/reversal-candle]]"
  - "[[concepts/false-breakout]]"
  - "[[concepts/failure-day]]"
  - "[[concepts/stop-order-entry]]"
indicators: []
period: D1
source_citation: "Larry Williams, Inner Circle Workshop Trading Method (~2000). R1 PASS — World Cup Trading Championship winner (2500%+ return 1987), pioneered Williams %R, multiple Wiley books. Local PDF: Inner Circle Workshop Trading Method. (Larry Williams) (Z-Library).pdf."
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 25
g0_approval_reasoning: "R1 single source_id/source; R2 mechanical D1 OHLC fakeout stop-entry/exit with plausible cadence >2 trades/year/symbol; R3 DWX FX D1 testable; R4 deterministic no ML."
---

# QM5_11477 Williams-L — Fake-Out Day Reversal (D1)

## Quelle
- Source: Larry Williams, "Inner Circle Workshop Trading Method" (~2000)
- R1: PASS — World Cup Trading Championship 1987 (2500%+ annual return), multiple Wiley books, creator of Williams %R indicator.

## Mechanik

**Concept**: The "Fake-Out Day" (part of Williams' "Failure Day Family") is a daily bar that misleads traders by making a new short-term high (Higher High + Higher Low), suggesting bullish continuation — but then closes below the prior day's close, revealing that sellers overwhelmed buyers by the end of the session. The next day, if price breaks above the Fake-Out Day's High, it signals a short squeeze / reversal as the bears who shorted the breakdown are stopped out. Williams' rule: "Buy at the prior day's High."

**Why it works**: The false signal to the downside (declining close despite higher range) traps short sellers. Their stop losses cluster just above the Fake-Out Day's High. When price rises through that level, the stops fire, accelerating the upside reversal.

**Mirror (Sell)**: A Fake-Out Day SELL has a Lower High + Lower Low + Higher Close than the prior day — appeared to be a false break to the upside but sellers reclaimed control; SELLSTOP at prior day's Low.

### Entry

**LONG (Fake-Out Day BUY):**
1. Bar[1] has Higher High than Bar[2]: `High[1] > High[2]`
2. Bar[1] has Higher Low than Bar[2]: `Low[1] > Low[2]`
3. Bar[1] closes BELOW Bar[2]'s close: `Close[1] < Close[2]` — the fake-out (surprise bearish close after higher range)
4. Entry trigger: BUYSTOP at `High[1] + 1pip` — place at open of bar[0]; cancel if not filled by close of bar[0]
5. SL: `Low[1] - 1pip` (Fake-Out Day's Low)

**SHORT (Fake-Out Day SELL):**
1. `High[1] < High[2]` AND `Low[1] < Low[2]` — Lower High + Lower Low (breakdown)
2. `Close[1] > Close[2]` — higher close despite lower range (fake-out of the bearish breakdown)
3. SELLSTOP at `Low[1] - 1pip`; SL = `High[1] + 1pip`

### Exit
- **TP**: nearest resistance (for long) / support (for short) on D1 chart — fractal or prior swing
  - Target: 1-2× the Fake-Out Day's range beyond entry
- **Time stop**: if not filled in 1 bar, cancel; if open for 5 D1 bars without profit, exit at market
- **SL**: beyond the Fake-Out Day's opposite extreme + 1 pip

### Stop Loss
- Opposite extreme of Fake-Out Day + 1 pip
- P2 cap: 80 pips (if Fake-Out Day range > 80 pips, skip)

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: D1
- Instruments: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX
- Spread cap: 25 pips
- No Friday entry (avoid entering at week's end)
- Optional: require that the Fake-Out Day's close is in the bottom 33% of bar range (for long) — stronger signal

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Larry Williams — World Cup 1987 champion, Wiley author, creator of Williams %R. Workshop PDF source. |
| R2 Mechanical | PASS | Higher High/Low vs prior bar: OHLC comparison. Close vs prior close: OHLC comparison. BUYSTOP at High[1]: OHLC arithmetic. All MT5-native. |
| R3 Data Available | PASS | D1 DWX FX. iHigh/iLow/iClose bar indices MT5-native. |
| R4 No ML | PASS | Pure OHLC conditions — no parameters beyond bar indices. |

G0 APPROVE — R1 PASS (Larry Williams, World Cup champion).

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from Larry Williams, Inner Circle Workshop (~2000)

## Implementation Notes for Codex (P1)
- Higher High: `iHigh(D1,1) > iHigh(D1,2)`
- Higher Low: `iLow(D1,1) > iLow(D1,2)`
- Close below prior close (bearish surprise): `iClose(D1,1) < iClose(D1,2)`
- BUYSTOP: `iHigh(D1,1) + pip_offset`; cancel at close of bar[0] if not filled
- SL: `iLow(D1,1) - pip_offset`
- Optional close-in-lower-third filter: `(iHigh(D1,1) - iClose(D1,1)) > 0.67 * (iHigh(D1,1) - iLow(D1,1))`
- TP: `iHigh(D1,1) + 1.5 * (iHigh(D1,1) - iLow(D1,1))` as simple measured-move TP
- P3 sweeps: close-position filter (none/bottom-33%/bottom-50%), SL option (Fake-Out Low / 50 pips / 80 pips), TP method (1×range/1.5×range/next-fractal), time-stop bars (1/3/5)

## Verwandte Strategien
- Related: QM5_11478 (williams-l-smash-day-d1) — same source; Smash Day is similar pattern with close in wrong half of bar range (inside the bar rather than outside)
- Related: QM5_11461 (goodwin-j-outside-bar-daily-reversion-d1) — also D1 bar pattern reversal; outside bar vs. same-direction-false-close
- Related: QM5_11453 (davey-big-range-bar-momentum-d1) — also D1 bar pattern; extended range vs. false-close pattern

## Lessons Learned
- *(populated as pipeline progresses)*

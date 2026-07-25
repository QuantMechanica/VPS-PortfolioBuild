# STR-086 — Claude independent spec (pre-reconciliation)

Source: thread 86766 (jarroo/PeterCrowns, 2008; the DIBS Method). Exec TF
H1. Cohort: EURUSD.DWX, GBPUSD.DWX (Peter's strongest/weakest-selection
is discretionary → fixed test-design cohort, flagged).

## Rules

1. Day anchor: 06:00 GMT ("0600GMT is always 0600GMT"; ±1h DST
   immaterial per Peter) → daily open = the H1 bar opening at 06:00 UTC
   via QM_BrokerToUTC; the line in the sand.
2. Direction: price ABOVE the daily open → long-only; BELOW → short-only
   (evaluated per closed bar vs the frozen day open).
3. INSIDE BAR on H1: High(1) <= High(2) AND Low(1) >= Low(2)
   (equality allowed — the thread's stricter definition).
4. Trend-side IB → pending STOP 1 pip beyond the IB extreme in the trend
   direction (buy: IB high + 1 pip above the open-side). SL = the other
   side of the IB − 1 pip (risk = IB range + 2 pips + spread).
5. MM (netted, 20101 machinery): close HALF at +1R (FTT); the remaining
   half KEEPS THE INITIAL SL unmoved ("do not move the SL"); no TP on
   the remainder (framework Friday close bounds it; PC's discretionary
   trailing = variant, unbuilt; flagged).
6. One position; a new IB signal only when flat (house convention;
   source allowed multiple entries — flagged). Pending cancelled when
   the day-side flips or a new IB supersedes (one pending max); day roll
   at 06:00 UTC clears state.
7. IB straddling the open → skip (the thread's open question; flagged).

Overlap: QM5_9993 = the MWD level-bounce from a different thread
(distinct); STR-002/20101 borrowed only the A/B/C MM idea from DIBS.

## Inputs

```
strategy_open_utc_hour = 6
strategy_breakout_buffer_pips = 1.0
```

## Hooks sketch

Filter: H1/params/warmup ≥ 2 days. Entry: day-side + IB detection +
pending placement (state machine). Manage: pending lifecycle + half-close
at +1R (retry-latched; SL never moved). Exit: false. News: default.

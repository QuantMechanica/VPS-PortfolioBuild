# STR-051 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_macd50-ukgrid-gbpusd` · chart TF M15 (aggregation base) ·
Symbol (slot 0): GBPUSD.DWX. Base: EA_Skeleton. COMPLEXITY FLAG: custom
UK-clock 4h bars + manual MACD recursion (heaviest EA of the run).

## Inputs (group "Strategy")

```
input int    strategy_macd_fast   = 5;
input int    strategy_macd_slow   = 13;
input double strategy_delta_price = 0.00050; // absolute price (5 GBPUSD pips)
input double strategy_p1_tp_pips  = 30.0;
input double strategy_p2_tp_pips  = 45.0;
input double strategy_sl_pips     = 30.0;
input int    strategy_seed_bars   = 240;     // custom-bar EMA seed depth (determinism)
```

## Custom UK 4h grid

- London offset helper IN-EA: UK civil = UTC+0 winter / UTC+1 summer with
  transitions computed by calendar arithmetic (last Sunday of March /
  last Sunday of October, 01:00 UTC) — exactly the QM_DSTAware US-DST
  pattern, cited in comments; broker→UTC via QM_BrokerToUTC.
- Custom bars: aggregate closed M15 bars into 4h buckets aligned to UK
  00/04/08/12/16/20. A bucket is complete when all its M15 bars are
  closed and present; missing data ⇒ bucket incomplete.
- Recompute on new M15 bar only (cached; bounded backward scan for the
  seed window, perf-allowed).
- MACD main = EMA(5, custom closes) − EMA(13, custom closes), manual
  recursion seeded with SMA over the first period exactly
  strategy_seed_bars custom bars back (20103 determinism pattern).

## Entry

At the FIRST M15 bar whose open lies at/after a UK boundary in
{08,12,16,20} Mon-Fri (one evaluation per boundary, own latch): require
the just-completed custom bar [T−4h,T] and the comparator [T−12h,T−8h]
complete; delta = main(just-closed) − main(two earlier);
delta ≥ +0.00050 → LONG, ≤ −0.00050 → SHORT, else nothing. Flat-only
(own campaign open ⇒ ignore signals; no backfill of missed boundaries).
Market entry; SL 30 pips; TP = entry ± 45 pips server-side (P2 target).

## Manage

Half-close at +30 pips touch (initial-volume based, once) + SL to
breakeven; per-bar retry latch. Runner exits at server TP (+45) or BE.

## Hooks

1 Filter: chart M15; params; warmup ≥ seed window of M15 data.
2 Entry: boundary machine. 3 Manage: half/BE. 4 Exit: false.
5 News: default.

## Compliance

Registry magic slot 0; campaign risk 1% total (netted two-leg source
campaign); UK-DST calendar helper documented; UK/US DST mismatch weeks
have NO special handling (the UK rule is exact). Frequency est.
60-150/yr.

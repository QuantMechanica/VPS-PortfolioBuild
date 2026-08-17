# Z4 closed — the tolerance was inert in 14 of 15 pairs, decisive in one, and changed no outcome

## The prediction, and how it fared

Before the remaining twelve comparisons landed I recorded: *"the rest of the cohort will reproduce
its original verdicts exactly."* All fifteen are now comparable.

**Confirmed for 14. Falsified for 1** — and the one is the case worth having.

| Pair | old trades / PF / DD | new trades / PF / DD | |
|---|---|---|---|
| QM5_13203 / XTI_XNG | 67 / 0.94 / 3.29 | 67 / 0.94 / 3.29 | identical |
| QM5_13205 / XAU_XAG | 2 / 6.97 / 0.32 | 2 / 6.97 / 0.32 | identical |
| **QM5_20262 / XNGUSD** | **0 / 0.0 / 0.0** | **19 / 1.16 / 3.5** | **DIFFERS** |
| QM5_20289 / XTIUSD | 53 / 0.71 / 11.98 | = | identical |
| QM5_20290 / XTIUSD | 51 / 1.37 / 5.12 | = | identical |
| QM5_20295 / XTIUSD | 51 / 1.14 / 5.37 | = | identical |
| QM5_20296 / XNGUSD | 38 / 0.89 / 7.2 | = | identical |
| QM5_20297 / XNGUSD | 38 / 1.9 / 5.85 | = | identical |
| QM5_20298 / XTIUSD | 37 / 0.77 / 10.58 | = | identical |
| QM5_20299 / XNGUSD | 25 / 1.47 / 2.37 | = | identical |
| QM5_20300 / XTIUSD | 39 / 1.19 / 6.48 | = | identical |
| QM5_20301 / XTIUSD | 39 / 0.69 / 11.14 | = | identical |
| QM5_20302 / XTIUSD | 39 / 1.01 / 6.39 | = | identical |
| QM5_21516 / XTIUSD | 43 / 1.08 / 4.66 | = | identical |
| QM5_21527 / XTIUSD | 25 / 1.04 / 3.88 | = | identical *(confounded: `.ex5` also rebuilt)* |

QM5_21527's identity is still informative: two variables moved and nothing changed.

## The one case, with its mechanism traced to the line

QM5_20262/XNGUSD, `xng-lr-trend` — a linear-regression trend EA:

```
mq5:47    input double strategy_slope_epsilon = 1.0e-10;
mq5:417   if(MathAbs(slope) <= strategy_slope_epsilon)      <- the slope significance test
setfile   strategy_slope_epsilon=0.0000000001               <- after the generator fix
```

With the setfile carrying `1.0e-10`, MT5 truncated it to `1.0e-1` = **0.1**. The test then read
"is |slope| ≤ 0.1?" and answered yes for essentially every bar, so **every entry was rejected and
the EA produced zero trades.** With the correct value it produces 19.

That is the exponent defect doing exactly what the theory said, on a real EA, measured end to end.

## But it changed no outcome, and that distinction is the result

The verdict moved from `ZERO_TRADES` to **`FAIL / run_smoke_fail:MIN_TRADES_NOT_MET`** — not to PASS.
19 trades is below the 45-trade smoke floor.

So the pair went from *"generates no signal at all"* to *"generates signal, but not enough of it."*
Substantively different as a diagnosis, identical as a funnel outcome. **15 of 15 still fail.**

I had briefly read 19 trades / PF 1.16 as a rescue. It is not one, and the difference matters: a
rescue would have meant a candidate re-entering the pipeline, whereas this is a corrected
explanation for a pair that fails either way.

## What Z4 establishes

1. **The false-negative hypothesis is closed for this cohort.** One pair was genuinely mis-measured;
   none was mis-*judged*. No EA was discarded because of the parameter — the fourteen inert cases
   failed on merit, and the one affected case fails on frequency with the parameter corrected.
2. **The generator fix is a correctness fix, not a recovery lever** — now empirically rather than by
   argument. It stops a real defect (it killed QM5_41033 deterministically, and it silenced
   QM5_20262 entirely), and it recovers no candidates.
3. **A silent wrong parameter is worse than a loud one, and QM5_20262 proves it.** QM5_41033 had a
   `QM_InputRequireDouble` guard and died loudly in OnInit, so it was found in hours. QM5_20262's
   guard exists today (`mq5:515`) but postdates its 2026-08-07 run, so on that day the EA ran with a
   filter nine orders of magnitude too coarse, reported `ZERO_TRADES`, and looked like an honest
   no-signal strategy for ten days. **That is what the self-describing input guards are worth**, and
   it is the argument for putting one on every tolerance-style input rather than some.

## The one thing this leaves open

`ZERO_TRADES` is treated as a genuine strategy answer — correctly, in general. QM5_20262 shows it can
also be the signature of a silently mis-parsed filter input. There are 1,162 `ZERO_TRADES` rows in
the recent window; the ones worth a second look are those whose EA has an unguarded tolerance-style
input **and** whose setfile predates the generator fix. That is a bounded query, not a re-run
programme, and it belongs with the remaining exponent sweep rather than here.

## Evidence

- `artifacts/z4_exponent_old_vs_new_20260817.json` — all 15 pairs, re-runnable
- `ea_metrics` old/new rows fetched by `work_item_id` (append-only, as established earlier today)
- `QM5_20262_xng-lr-trend.mq5:47,417,515`; setfile `strategy_slope_epsilon=0.0000000001`
- work items `ab875180` (ZERO_TRADES, 2026-08-07) and `b65eb03a` (FAIL, 2026-08-17T14:29)
- related: `2026-08-17_P0_lifted_ea_metrics_is_append_only_and_the_tolerance_was_inert.md`,
  `2026-08-17_exponent_taint_15_eas_may_have_failed_for_the_wrong_reason.md`

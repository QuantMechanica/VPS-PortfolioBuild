# Research finding (analytical, NON-mechanizable) — H2: density vs edge

## Verdict
REFUTED IN PROXY.  Activity is NOT the binding FTMO constraint.  Only 9.5% (424/4455) of
scored strategy rows fall below the >=5 trades/yr activity floor; mean 373 trades/yr.
Higher trade counts are associated with LOWER pass rate (50.6% at >=50 trades vs 54.2%
below), while expectancy dominates (profit factor >=1.0: 68.8% pass vs 27.7% below).

## Why this is analytical, not tradeable
H2 is a diagnostic about what discriminates pass/fail in the population — it prescribes no
entry, exit, or stop, and consumes no holdout.  It is deliberately NON-mechanizable: it is
a screen/lesson, not a candidate.  It correctly informs H-CW (target probability-per-trade
under a bounded daily loss, not raw density), but it is not itself a Strategy Card and is
expected to fail the mechanization gate.

## Evidence
See h2_result.json (activity distribution, deterministic from the OBSERVE summary) and the
campaign kimi_answer.md section 1.

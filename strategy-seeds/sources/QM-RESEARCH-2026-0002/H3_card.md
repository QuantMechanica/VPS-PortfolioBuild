# Research finding (NOT established) — H3: shared loser-regime no-trade filter

## Verdict
NOT ESTABLISHED / INCONCLUSIVE.  The variable H3 needs is missing: all 15 top failure
clusters are session=unspecified (96.5% of rows carry no time-of-day attribution), so the
posited common regime/time-of-day condition cannot be identified from this projection and
no bounded filter can be derived from it.  The closest proxies argue AGAINST naive session
conditioning (session=open EAs pass only 44.4% vs 51.2% population).

## Why this is not mechanizable here
Without a daily-loss series, an OOS split, or session attribution, the preregistered
refutation criterion (OOS daily-loss survival improvement at >= net expectancy) is
untestable.  The bounded, bar-structure no-trade filter this motivates is folded into
H-CW (first-bar-range shock filter + spread filter), which IS measurable from bar data;
H3 on its own remains a not-established finding, not a Strategy Card, and is expected to
fail the mechanization gate.

## Evidence
See h3_result.json (failure clusters, deterministic from the OBSERVE summary) and the
campaign kimi_answer.md section 1.

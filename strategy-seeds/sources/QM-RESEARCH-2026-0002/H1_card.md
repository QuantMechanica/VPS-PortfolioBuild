# Research finding (NOT a mechanizable card) — H1: intraday-vs-swing for FTMO fitness

## Verdict
INCONCLUSIVE.  The preregistered refutation test ("intraday session-flat variants reduce
worst-day loss / wdd_p90 vs med60") is NOT runnable on this OBSERVE projection: there is
no worst-day-loss, wdd_p90, or per-trade equity field in any file.  The testable proxy
(gate PASS rate by holding class) shows intraday beating swing by only +0.85pp
(0.5164 vs 0.5079) while the multi-day "position" class beats both (0.5567) and scalp is
the worst (0.3991) — which breaks any monotone "shorter holding => better" reading.

## Why this is not mechanizable as stated
A single gate-pass gap of noise magnitude, confounded by 96.5% session-unspecified rows
and by unequal class populations, is not a tradeable edge.  The mechanizable direction it
motivates (session-flat index continuation) is carried by H-CW, not by H1 itself.

## Evidence
See h1_result.json (holding-class outcome distribution, deterministic from the OBSERVE
summary) and the campaign kimi_answer.md section 1.  This is a finding, not a Strategy
Card; it has no entry/exit/stop rules and is expected to fail the mechanization gate.

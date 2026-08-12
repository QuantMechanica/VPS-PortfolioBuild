# Stranded-pair canary — updated result, and a correction

Date: 2026-07-27 (later than `2026-07-27_stranded_canary_result.md`)
Author: Claude

## The correction

The canary task closed as INCONCLUSIVE reporting **"3/3 completed recovered"**, and I
relayed that to OWNER as directionally positive. With 8 of the 10 now resolved, that early
read does not hold.

| work item | EA | symbol | status | verdict |
|---|---|---|---|---|
| 47b62d39 | QM5_12406 | XTIUSD.DWX | done | **PASS** |
| 511318c1 | QM5_11912 | AUDUSD.DWX | done | **PASS** |
| c5734bae | QM5_11062 | WS30.DWX | done | ZERO_TRADES |
| 5a6ce70f | QM5_11072 | USDCAD.DWX | done | INFRA_FAIL |
| 49ab260f | QM5_9940 | SP500.DWX | failed | INFRA_FAIL |
| 93077cce | QM5_10591 | GBPJPY.DWX | failed | INFRA_FAIL |
| 9eefa526 | QM5_10792 | NDX.DWX | failed | INFRA_FAIL |
| b0af005d | QM5_10485 | USDJPY.DWX | failed | INFRA_FAIL |
| c1dad1ca | QM5_10226 | EURUSD.DWX | pending | — |
| fc0c0e57 | QM5_10809 | XAUUSD.DWX | pending | — |

**Resolved: 8. Real verdicts: 3 (2 PASS, 1 ZERO_TRADES). Failed again with `INFRA_FAIL`:
5.** That is a recovery rate near **25%**, not 100%.

The early "3/3" was true of the first three completions and was reported honestly as
INCONCLUSIVE by the canary task itself. My relay of it as "directionally positive, no
regressions" was the overstatement — five of the next five failed.

## What it means for the 1,246 remaining stranded pairs

They are **not broadly recoverable**. On this sample roughly one in four returns a real
verdict, and `ZERO_TRADES` is arguably a fourth outcome again — the EA ran and produced
nothing, which is a real verdict but not a usable sleeve.

So the value of the stranded population as a sleeve pool is far lower than the raw count
of 442 EAs suggested. Combined with the RECYCLE preflight result — 0 of 431 immediately
buildable, 410 needing card, source or registry correction — the picture is consistent:
**both large backlogs are mostly not recoverable candidates, they are debris.**

## What is still worth doing

- The 5 fresh `INFRA_FAIL` results are the useful part. They failed **after** the June
  cause was fixed and after today's classification work, so they carry a current,
  diagnosable failure rather than a historical one. They are a better diagnostic sample
  than the 43,422-row historical graveyard.
- Requeueing the remaining 1,246 on a 25% expected yield, against a queue already ~2,000
  deep, does not obviously pay. That remains an OWNER capacity decision and this document
  does not take it.

## Not established

- Whether the 25% generalises. Ten pairs, eight resolved, chosen deliberately across two
  cohorts and distinct EAs and symbols — better than a convenience sample, but still
  small.
- Whether the 5 fresh failures share one mechanism. Nobody has looked yet.

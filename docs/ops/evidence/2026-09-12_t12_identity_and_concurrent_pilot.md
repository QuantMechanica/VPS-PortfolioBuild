# T12 identity smoke and T11/T12 concurrent pilot

Date: 2026-09-12 07:34–07:38 UTC  
Router task: `c2396a30-2724-4ac8-9f13-deb299c6ef95`

## Result

The task-authorized weekend retry used `research_canary.py` only, with
`QM_CANARY_CPU_LIMIT=100`, a one-second admission sample interval, Model 4, and
one local agent. T12 reproduced the fleet identity cell exactly:

| Metric | Fleet reference | T12 | Result |
|---|---:|---:|---|
| Total net profit | 2941.71 | 2941.71 | MATCH |
| Profit factor | 1.03 | 1.03 | MATCH |
| Total trades | 208 | 208 | MATCH |

Identity receipt:
`D:/QM/reports/research/C2396A30_T12_IDENTITY_20260912/20260912_073454_0eed25d2/receipt.json`.
Native report:
`D:/QM/reports/research/C2396A30_T12_IDENTITY_20260912/20260912_073454_0eed25d2/report.htm`
(SHA-256 `869516697efeddfa2440258d078f7b725cb01d2bd6d863aa19fa077a1b8ea948`).

The receipt status is `COMPLETED_REVIEW_REQUIRED`, not a false clean-isolation
claim: the ordinary fleet advanced from 147737 to 147738 rows and refreshed
`worker_pids.json` while the research run was in flight. T12 remained absent from
the signed T1–T10 activation and the controller did not claim or mutate a farm row.
The native report is therefore valid identity evidence, while the changing fleet
snapshot is explicitly retained for review.

## One-shot concurrent pilot

After the identity match, exactly one concurrent run was admitted on each inert
research seat with the same EX5 and setfile hashes:

- EX5: `68d37d3a6b6d5d4354e5a9aa494488d8d2809b1f662ff75fbb26440658137c01`
- setfile: `afa42711867677bd7d5641f93e52a104f31c86a181f835579241b214f35bf47c`
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `qm_news_stale_max_hours=336`

Both seats failed closed before testing and produced no report:

| Seat | Receipt | Admission CPU / free RAM | Terminal result |
|---|---|---:|---|
| T11 | `D:/QM/reports/research/C2396A30_CONCURRENT_T11_20260912/20260912_073814_6bd09905/receipt.json` | 94.56% / 41.00 GiB | `REFUSED: tester exited without report` |
| T12 | `D:/QM/reports/research/C2396A30_CONCURRENT_T12_20260912/20260912_073815_829adabf/receipt.json` | 94.34% / 40.88 GiB | `REFUSED: tester exited without report` |

The controller-launched terminal journals bind the refusal to a pending MT5
LiveUpdate handoff, not RAM exhaustion. At 09:38:29 local, both journals record
`LiveUpdate start ... /update /path:<seat> /portable /config:<bound ini>`, followed
by terminal exit code 0 and no `automatic testing started` line. The source journals
are `D:/QM/mt5/T11/logs/20260912.log` and
`D:/QM/mt5/T12/logs/20260912.log`.

Independent host samples were taken 30 seconds apart:

| UTC | CPU | Free RAM | T11/T12 agents |
|---|---:|---:|---:|
| 07:38:17 | 99.32% | 40.08 GiB | 0 / 0 |
| 07:38:48 | 91.02% | 41.08 GiB | 0 / 0 |

The second sample is after the 07:38:30 refusals and proves the seat processes
were gone. No repeat was attempted because the task authorized one concurrent
pilot only.

## Verification and recommendation

- `python -m pytest tools/strategy_farm/tests/test_research_canary.py -q`:
  **40 passed**.
- `python -m py_compile tools/strategy_farm/research_canary.py`: PASS.
- Post-run process census: no T11/T12 `terminal64.exe` or `metatester64.exe`.
- No T_Live/FTMO, AutoTrading, factory claim, or fleet-worker action.

Recommendation: T12 is a valid standalone research seat, but do not schedule
T11+T12 beside a saturated weekday fleet yet. A single T12 agent reached a
99.94% five-sample runtime CPU mean, and the first concurrent launch exposed an
unreconciled per-seat LiveUpdate path. Re-test concurrency only in another
explicit OWNER window after both research-seat builds are reconciled and a fresh
dry run proves no update handoff.

**REVIEW:** identity acceptance is met; concurrent capacity is measured as a
fail-closed refusal and is not approved for weekday use.

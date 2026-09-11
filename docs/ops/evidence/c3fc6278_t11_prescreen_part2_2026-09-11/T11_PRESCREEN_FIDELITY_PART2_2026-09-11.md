# T11 pre-screen fidelity, part 2 â€” controller delivered; measurement launch refused

Router task: `c3fc6278-7c6f-4871-b311-59b8650d4961`. Date: 2026-09-11.
Disposition: **REVIEW / PARTIAL â€” LIVEUPDATE_RECURRED_NO_REPORT**.

The controller extension and frozen experimental inputs are delivered. The first governed
M1 OHLC admission pilot passed CPU/RAM/history/input checks but T11 exited through LiveUpdate
without a tester report. **No new speed, fidelity, optimizer throughput, admissible pre-screen
mode, or expected time saving is established.** The experimental acceptance criteria remain unmet.

## Implemented controller and verification

`C:/QM/repo/tools/strategy_farm/research_canary.py` now supports `--modelling-mode`
(`real-ticks`, `ohlc-m1`, `generated-ticks`, `open-prices`) or mutually exclusive `--model`,
and `--optimize off|complete|genetic`. Default behavior remains real ticks without optimization.
Enabled input ranges come from the hash-bound staged `.set`, using
`value||start||step||stop||Y`. Optimizer runs request native XML, preserve it, and extract the
SpreadsheetML pass table into a SHA-bound CSV. XML without a pass table refuses completion.
The tests exercise complete and genetic report capture using test doubles; these are not native
optimizer measurements.

The payload's cheap-mode numbers are incorrect. Native MT5 values are **0 generated ticks,
1 M1 OHLC, 2 open prices, 4 real ticks**. Complete optimization is 1, genetic is 2, and native
optimization report export is XML. The CLI follows the vendor mapping and records both name
and code. [MetaQuotes configuration reference](https://www.metatrader5.com/en/terminal/help/start_advanced/start).

Research-only guards now validate positive fixed risk, zero percent risk, finite values and news
staleness at most 336 hours, reject optimization of these safety inputs, verify the INI expert
matches the hash-bound EX5, and refuse existing T11 processes. The CPU sampler is primed, then
collects five complete one-minute admission samples and five one-second runtime samples.
The default remains 95%; even an environment override cannot exceed 97%. A guard abort affects
only the identity-bound research job. Resource refusals in the final version retain observations.
The transient factory lock is observational; worker map, work-item count and activation identity
remain checked before/after. Failure to read the final snapshot no longer prevents receipt writing.

Before resuming the terminal, a controller-local Windows Job API sets
`KILL_ON_JOB_CLOSE | ACTIVE_PROCESS_LIMIT` to `max_agents + 1`, with max_agents limited to 1â€“2.
The terminal consumes one slot, leaving at most two child slots while it is running. Helpers use
that same budget and can make a run fail; this does not prove two-agent optimizer utilization.
No fleet worker or shared Job API implementation was changed. The limit is set before process
assignment/resume, rather than waiting to notice an overshoot. Native Windows API set/query returned
flags 8200 and limit 3: [native check](native_job_cap_verification.json).
[Microsoft Job limit reference](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-jobobject_basic_limit_information).

Focused verification: **38 tests passed**, including all model/optimizer combinations, sparse XML
columns, malformed and unsafe ranges, CPU override clamp, report capture, isolation observation,
and Job-limit failure cleanup. Ten optimizer draft setfiles also passed safety/range validation.
Exact commands and hashes are in [verification](verification.json).

## Governed native attempt

Receipt: `D:/QM/reports/research/T11_PRESCREEN_PART2_c3fc6278/20260911_110621_51e53c05/receipt.json`.
Its unchanged copy is [pilot_receipt.json](pilot_receipt.json); source hashes and process observations
are in [launch_refusal_audit.json](launch_refusal_audit.json).

| Observation | Result |
|---|---|
| Cell | Existing identity fixture, USDJPY.DWX H1, 2021, s3_l3_x18 |
| Requested mode | M1 OHLC, native Model 1, optimization off |
| Five admission CPU samples | 88.3, 91.4, 92.4, 88.5, 92.7%; average 90.66% |
| CPU ceiling / override | 95%; environment override absent |
| Available RAM at admission | 47,885,922,304 bytes |
| Staged EX5 | SHA-256 `68d37d3a6b6d5d4354e5a9aa494488d8d2809b1f662ff75fbb26440658137c01` |
| Risk/news | RISK_FIXED=1000, RISK_PERCENT=0, news staleness=336 |
| Process containment | Job assigned while suspended, process ceiling 3, primary thread resumed |
| Outcome | Exit 0 after 1.890 seconds; missing report; receipt REFUSED |
| Full admission/attempt wall time | 304.078 seconds; **not backtest speed** |
| Isolation | Same worker PID hash, same 147,570 work items, same activation; no T11 processes at post-check |

At journal-local 13:11:25 (11:11:25 UTC), the terminal initialized this run's INI, launched
the SYSTEM-profile `liveupdate/terminal64.exe`, and shut down. The controller launch included
`/portable /skipupdate /config:...`; the earlier successful smoke does not establish that
`/skipupdate` reliably prevents update hand-offs. The cause of this recurrence is not established.
The matching [journal excerpt](t11_launch_journal_excerpt.txt) is preserved. No tester report
or new optimization pass table was produced, and no further cells were launched against this
failed prerequisite. This is an infrastructure observation, not an EA or pipeline verdict.

The pilot used the controller version loaded at launch. Subsequent non-launch changes added
controller-source hashing, richer CPU refusal observations and final-snapshot error handling.
The receipt is preserved as emitted, not retroactively augmented with fields it lacked.

## Frozen matrix and fidelity coverage

The requested historical ground truth remains frozen at **320 WINSWEEP + 25 DL089** cells;
newer factory cells do not silently change its population. All 345 identities are unique and all
1,380 referenced summary/report/INI/setfile hashes matched. See
[verification](ground_truth_verification.json) and [ground truth](frozen_ground_truth.csv).

The [20-cell pilot plan](speed_pilot_20_cells.csv) selects two WINSWEEP cells for each year
2019â€“2025 and six DL089 arms by SHA-256(cell_key), without looking at their outcomes.
The failed admission pilot used the already staged identity fixture and is additional to this
matrix. It did not supply a measurement for it.

| Cohort | Real-tick baseline cells | New completed cheap cells | Spearman/year and pooled | Plateau top-5/10 | Sign agreement | FN at 50%/30% |
|---|---:|---:|---|---|---|---|
| WINSWEEP | 320 | 0 | NICHT GEZEIGT | NICHT GEZEIGT | NICHT GEZEIGT | NICHT GEZEIGT |
| DL089 | 25 | 0 | NICHT GEZEIGT | NICHT GEZEIGT | NICHT GEZEIGT | NICHT GEZEIGT |

[Speed matrix](speed_matrix.csv) and [fidelity matrix](fidelity_matrix.csv) enumerate all three
cheap modes and per-year/pooled coverage. Missing measurements use empty numeric fields, not zero
correlation or zero false negatives. Historical receipt elapsed times are labeled historical;
they do not estimate T11 mode speedup. [Run receipt index](research_receipts.json).

For resumption, rank net and costed return/max-DD separately with average-rank Spearman and
undefined results for constant series. Top-k overlap is intersection/k. Define false negatives
as eligible real-tick top-10 members excluded by the cheap retained set divided by eligible
real-tick top-10 count; deterministic ties use length then start for window ranks.
Apply the registered section-5 costed DEV median and full-grid neighbourhood median, preserving
seven-year activity/trade admissibility. Incomplete neighbourhoods cannot be silently scored.
DL089 pattern IDs have no registered window neighbourhood or plateau aggregation rule; a literal
section-5 plateau comparison for that cohort remains undefined until specified. Mode selection
uses DEV only; OOS is confirmation, never a source of filter tuning.

## Optimizer experiment topology

The unchanged EA accepts `strategy_range_start_hour` and `strategy_range_end_hour`; it has
no range-length input. Start 0..9 and length 2..8 constrained by end<=13 contain 60 valid windows.
A single rectangular start/end optimization does not reproduce this domain. Exact inputs are
prepared as ten start-fixed optimizer shards, each sweeping the permitted end hours: see
[grid plan](optimizer_grid_plan.json), [draft setfiles](optimizer_sets/), and
[range verification](optimizer_input_verification.json). Seven separate annual reset windows imply
70 optimizer invocations and 420 native passes. These inputs were not staged or run.

A single full 2019â€“2025 optimizer run would have different annual reset semantics; it cannot
replace the per-year ground truth. Neither a changed EA nor a rectangular superset was substituted
to make a nominal one-run demonstration. Native optimizer export and two-agent utilization remain
NICHT GEZEIGT despite parser and guard tests passing.

## OWNER decision-card draft â€” not adopted

**Decision proposed now:** keep full real-tick confirmation and defer pre-screen adoption.
Restore reproducible report-producing T11 launch behavior through the governed controller before
resuming this frozen experiment. No mode or cutoff is currently admissible on this evidence.

Candidate future scope is census ordering for these measurement programs only. After adequate
paired DEV evidence, a candidate cutoff must retain real-tick confirmation of all survivors and
a deterministic, year/arm-stratified random sample of 10% of dropped cells. A failed control or
unstable yearly fidelity restores complete confirmation. This is a proposed experiment rule,
not an accepted threshold or permission to skip work. Cheap runs cannot supply Q-series verdicts.

The [11:09 UTC backlog snapshot](census_backlog_snapshot.json) has **6,255 raw pending census
rows**, of which **1,119** belong to the two target programs. These counts include pending holds;
other programs' eligibility is not established. Conditional arithmetic from that snapshot:

| Population | Retained | Real-tick confirmations incl. controls | Fewer real-tick cells |
|---|---:|---:|---:|
| All 6,255 rows, hypothetical eligibility | 50% | 3,441 | 2,814 |
| All 6,255 rows, hypothetical eligibility | 30% | 2,315 | 3,940 |
| 1,119 target rows | 50% | 616 | 503 |
| 1,119 target rows | 30% | 415 | 704 |

[Scenario CSV](backlog_scenarios.csv). Formula: kept=ceil(N*r), controls=ceil((N-kept)*0.1).
Net saving would be `(N-confirmations)*t_real - N*t_cheap - extra control/orchestration cost`.
There is no measured t_cheap, accepted retention ratio or demonstrated filter fidelity, so
**expected time saving = NICHT GEZEIGT**. The five-minute admission overhead must be counted in
end-to-end timings; it cannot be mistaken for test-engine time or discarded from the economics.

## Cycle boundaries

Canonical control-plane commands only; no routing or work-item creation. The router-assigned
Codex spawn lease was observed, not acquired a second time. No strategy card, EA, news seed,
fleet worker or live setting was changed. No manual terminal-configuration edits were made. T11 ran only through
`research_canary.py`. No T1â€“T10 backtest was interrupted. The G: reference mount was unavailable;
local charter, profitability track, task payload and canonical evidence were read.

Initial health returned overall FAIL with 15 FAIL / 17 WARN / 54 OK. QM5_10260 had 286 done,
1 failed and 1 pending row; the pending row is Q04 NDX.DWX, unclaimed since 2026-09-02.
[Queue snapshot](qm5_10260_queue.json). These observations did not authorize unrelated repairs.
Final health and queue checks are preserved separately after the router task reaches REVIEW.


Final cycle check: after the task moved to REVIEW, the canonical Codex IN_PROGRESS list
returned `[]`. Health at **2026-09-11T11:18:36Z** remains **FAIL: 15 FAIL / 21 WARN / 51 OK**;
[full snapshot](final_health.json). The final [QM5_10260 queue](final_qm5_10260_queue.json)
confirms the same single unclaimed Q04 NDX.DWX item. No extra task was selected.
Controller and experimental packet commit: `9683a4facd` on `agents/board-advisor`.

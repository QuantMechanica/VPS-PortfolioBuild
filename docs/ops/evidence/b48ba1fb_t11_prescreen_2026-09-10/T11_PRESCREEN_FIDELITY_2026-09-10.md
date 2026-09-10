# T11 pre-screen fidelity: readiness and ground-truth deviation

Task: `b48ba1fb-0201-4bfd-a700-fbc14c98a668`. Snapshot: 2026-09-10 19:35 UTC.
Disposition: **REVIEW — DEVIATION_NO_MT5_LAUNCH; experiment acceptance incomplete.**

No cheap-mode speedup, fidelity, winning mode, cut-off, or expected backlog saving was measured.
The deliverable is a reproducible baseline and readiness packet, not a completed performance study.
No pipeline verdict, counter, gate, strategy card, EA, or worker configuration was changed.

## Why measurement stopped

1. **T11 readiness is incomplete.** `D:/QM/mt5/T11/Bases/symbols.custom.dat` is absent
   ([current check](symbol_catalog_check.json)). The same missing file caused a native
   `symbol EURUSD.DWX not exist` failure in the [09 September QM warm experiment](../2026-09-09_qm_warm_ea_parity.md).
   That experiment repaired its separate disposable lab, not the T11 root. The current task says
   to stop if T11 is unusable and permits no fallback to T12. No catalog was installed and no
   diagnostic launch was performed here. This is a missing prerequisite, not a measured USDJPY INIT result.
2. **No inspected launch path satisfies this session's combined constraints.** The scheduled-cycle
   instruction forbids manual `terminal64.exe` starts. `framework/scripts/run_smoke.ps1:20`
   admits Model 4 only. Its Custom-history admission at line 2947 calls
   `tools/strategy_farm/custom_history_smoke_admission.py:79`, which requires an active,
   worker-bound work item. This task explicitly prohibits adding work items or writing the state DB.
   Its narrow native-symbol monitor exception is unrelated to this EA/task. The isolated
   `mt5_latency_lab.py` and `mt5_qm_warm_fixture.py` bind earlier reservations, fixtures, binaries,
   symbols and dates; they cannot run this sweep unchanged. `optimizer_feasibility_probe.py`
   explicitly contains no launcher. No admission check was bypassed or weakened.
3. **The task's DL-089 premise differs from current records.** The current canonical DB contains
   **25**, not >=340, MEASURED cells for the QM5_41398 pattern census, all in 2019. It lacks
   **75** cells to reach the requested minimum 100. Older binaries or programs were not substituted.
   The WINSWEEP side has **320** MEASURED cells, plus 1 active and 99 pending at this snapshot.
   [Baseline summary](baseline_summary.json), [all measured cell evidence](real_tick_vs_cheap_cells.csv).

These are specific preflight findings. The lack of 100 pattern cells alone would not prevent a
small speed pilot; the launch/readiness restrictions are the reason no pilot was started.

## S1 — readiness and isolation

| Check | Evidence/result |
|---|---|
| Router ownership | Assigned Codex IN_PROGRESS; router's existing spawn lease recorded in raw `assigned_task.json` and `spawn_lease.json`; no duplicate lease acquisition |
| Worker exclusion | T11/T12 disabled; worker map contains T1–T10 only; no T11 process or attributed work item before/after collector |
| Scheduler scan | No explicit T11 terminal/path action match; indirect script targets were not exhaustively audited; [readiness.json](readiness.json) |
| Installed terminal | Version **5.0.0.6140**, hash in baseline summary; not assumed identical to the build used by the newer lab |
| USDJPY archive inventory | 7 annual HCC files and 84 monthly TKC files for 2019–2025; **961,133,319 bytes**; [inventory](t11_history_inventory.csv) |
| Data quality limit | Presence/size/link inventory only. Tick contents, gaps, symbol metadata, and real-tick completeness require native validation; file presence is not PASS |
| Symbol catalog | Missing; [current check](symbol_catalog_check.json) |
| Tester defaults | Deposit 100,000 USD, leverage 100, RISK_FIXED 1,000 and canonical Model 4 in `framework/registry/tester_defaults.json`; raw snapshot preserved |
| Commission | Defaults file does not declare a commission/swap schedule. Existing receipts bind canonical tester-group SHA-256 `25314333af81faf48e2afe2db5d52beea640cc74ec33a85a46b7c43aadb921dd`. A zero override is not evidence of zero fees. No values invented |
| Resource guard | Three one-second preflight host CPU samples **90.6%, 93.0%, 93.7%**; free RAM **36,317,786,112–36,465,823,744 bytes**; raw `cpu_guard.json`. No five-minute sustained-CPU inference; runtime pause behavior not exercised |
| Isolation outcome | Zero research launches/agents; T11-attributed work items 0 before and after; worker PID map unchanged over the collector interval; SQLite URI `mode=ro`, `PRAGMA query_only=ON` |

Raw audit root: `D:/QM/reports/research/t11_prescreen_2026-09-10/`.
It contains audit snapshots, **no newly generated tester outputs**. Before/after claims are bounded
by `isolation_before.json` / `isolation_after.json`; the factory keeps progressing independently.
The research code has no work-item mutation, worker restart, terminal launch, or lock-acquisition call.
Required router status updates are separate from this read-only experiment.

## S2 — speed matrix

The only new calculation is elapsed time from existing `payload.started_at_iso` to
`summary.timestamp_utc`, authenticated per cell. It includes receipt completion overhead;
it is not engine-only time, T11 timing, or a new sequential benchmark.

| Mode / source | Cells | Mean s/cell | Median s/cell | Min–max s | Speedup vs T11 reference | Research agents / CPU / RAM |
|---|---:|---:|---:|---:|---|---|
| Factory real-tick WINSWEEP receipts | 320 | 140.249 | 135.754 | 96.439–221.538 | Not measured | Historical; no comparable resource series |
| Factory real-tick DL-089 receipts | 25 | 134.318 | 132.672 | 114.559–165.652 | Not measured | Historical; no comparable resource series |
| T11 real ticks, one year | 0 | — | — | — | NICHT GEZEIGT | 0 / not measured / not measured |
| T11 real ticks, full window plus year split | 0 | — | — | — | NICHT GEZEIGT | 0 / not measured / not measured |
| T11 1-minute OHLC | 0 | — | — | — | NICHT GEZEIGT | 0 / not measured / not measured |
| T11 generated every tick | 0 | — | — | — | NICHT GEZEIGT | 0 / not measured / not measured |
| T11 open prices | 0 | — | — | — | NICHT GEZEIGT | 0 / not measured / not measured |
| T11 complete optimizer | 0 | — | — | — | NICHT GEZEIGT | 0 / not measured / not measured |
| T11 genetic optimizer | 0 | — | — | — | NICHT GEZEIGT | 0 / not measured / not measured |

Source: [per-cell CSV](real_tick_vs_cheap_cells.csv), including summary/report/INI/setfile paths
and SHA-256s; [aggregate](baseline_summary.json). All **345/345** recorded reports, INIs, setfiles,
Model 4 identities and unchanged binary bindings passed collector checks; authentication errors = 0.
Backtest risk inputs were checked for positive RISK_FIXED, zero RISK_PERCENT, and news staleness <=336.
EX5 identity: `68d37d3a6b6d5d4354e5a9aa494488d8d2809b1f662ff75fbb26440658137c01`.

## S3 — fidelity availability

| Year | WINSWEEP real-tick cells | DL-089 real-tick cells | Cheap matched cells |
|---|---:|---:|---:|
| 2019 | 46 | 25 | 0 |
| 2020 | 46 | 0 | 0 |
| 2021 | 46 | 0 | 0 |
| 2022 | 46 | 0 | 0 |
| 2023 | 46 | 0 | 0 |
| 2024 | 45 | 0 | 0 |
| 2025 | 45 | 0 | 0 |
| Pooled | 320 | 25 | 0 |

| Cohort / comparison | Spearman by year / pooled | Plateau top-5 / top-10 overlap | Sign agreement | FN at top 50% | FN at top 30% |
|---|---|---|---|---|---|
| WINSWEEP vs each cheap mode | Not measured | Not measured | Not measured | Not measured | Not measured |
| DL-089 vs each cheap mode | Not measured | Not measured | Not measured | Not measured | Not measured |

[Fidelity matrix CSV](fidelity_matrix.csv) explicitly enumerates each cohort, mode and year/pooled
scope with blank numeric fields. No blank is encoded as zero correlation or zero false negatives.
The ground-truth CSV's gross return/max-DD is descriptive, **not** the registered costed plateau score.
The pre-registered plan requires costed DEV medians, neighbourhood medians, entry-day and trade
admissibility across all seven years. Incomplete neighbourhoods must not be silently rescored.
No rankings, winners, plateau admissibility or OOS confirmation are asserted here.

For a resumed comparison, freeze cell identities, binary/history/build/cost settings, ranking ties
and control sample before running. Report both per-year and pooled rank correlation, with
constant-series correlations undefined. Specify the ranked quantity; report net-profit and costed
return/max-DD separately. Top-k overlap is intersection/k; false negatives are real-tick top-10
members outside the retained cheap ranking divided by the eligible real-tick top-10 count.
Keep unmatched and invalid cells out of paired denominators and visible in coverage tables.
Mode/cut-off selection uses DEV; OOS is a frozen confirmation, not another tuning opportunity.
Pattern-arm ranks need an explicit aggregation rule; the window grid neighbourhood cannot be
transferred to arbitrary predicate IDs.

## S4 — other options

| Option | Quantitative evidence | Fidelity caveat | Isolation risk | Effort estimate |
|---|---|---|---|---|
| Resident warm terminal | Prior QM5_10012 C/D cold **56.157/94.728 s**, warm C/D/C **41.079/43.750/49.547 s**; census speedup not measured | Prior normalized report/logger parity is limited to that EA, symbol and short fixture | Extend exact fixture allowlist, process/run ownership and evidence export without touching fleet | M |
| Full-window run + year split | **7 → 1 launches** structurally; measured speedup absent | Equity DD is not recoverable exactly from a closed-trade list alone; reset state, open positions, warm-up and costs may differ at year boundaries | Isolated reports; never replace canonical per-year receipts | M |
| Optimizer forward filter | 0 new passes; speedup not measured | Forward split must follow registered DEV/OOS; using OOS to select the filter leaks holdout information | Per-pass identity/export needed; aggregate pass rows lack some admissibility evidence | M |
| Tick-cache reuse | 0 new cache trials; speedup not measured | Bind cache to unchanged data/build/settings; never accept stale result caches as runs | Private T11 cache only; no links into worker archives | M |
| Local tester parallelism | Task cap **4** research agents; 0 launched | Completion counts are not equivalent to receipt fidelity | Host CPU already above 90% in brief samples; RAM and unique agent ownership must be monitored continuously | L |
| T11/T12 outside fleet caps | T11 archive inventory available; no measured capacity benefit | Outside the worker cap does not mean outside physical CPU/RAM contention | T12 remains out of scope; T11 catalog/launcher prerequisites unresolved | M |

Historical warm numbers: [native acceptance JSON](../2026-09-09_qm_warm_ea_parity.json)
and [interpretation](../2026-09-09_qm_warm_ea_parity.md). This newer laboratory evidence supersedes
the August statement that no resident backend exists; it still does not authorize or measure
QM5_41398 census operation. August [V4b](../3e129337_v4b_mt5_native_optimizer_feasibility_2026-08-27.md)
remains relevant to pass-table evidence gaps. Effort S/M/L is engineering judgment, not measured time.

## S5 — OWNER decision-card draft (not adopted)

**Decision now:** defer pre-screen adoption and any reduction in real-tick coverage. Review the
missing T11 symbol-catalog prerequisite and provide a task-bound isolated runner path compatible
with the scheduled-cycle launch prohibition and no-work-item rule. Obtain >=100 current-binary
pattern measurements through the existing factory; do not fabricate or enqueue them from this task.

**Candidate later scope:** census window sweeps and pattern-arm ordering only. Never substitute
cheap runs for Q02–Q10 verdict evidence or increment any success counter. No EA ML or mechanics changes.

**Mode/cut-off:** unset until S2/S3 are actually measured. A proposal must include observed false
negatives, per-year heterogeneity, top-k overlap, resource cost and confidence bounds. Real-tick
confirmation covers retained candidates plus a reproducible random, year/arm-stratified control
sample of dropped candidates. Failed validation or inadequate controls restores full confirmation.
No cut-off can be recommended from the present packet.

**Backlog arithmetic only:** for the task's stated backlog N=6,453, retained fraction x and control
fraction c of dropped cells give confirmations `ceil(N*x) + ceil((N-ceil(N*x))*c)`.
At hypothetical x=50%, c=10%, that is 3,550 confirmations / 2,903 fewer cells; at x=30%, c=10%,
2,388 confirmations / 4,065 fewer. [Scenario CSV](backlog_scenarios.csv).
These are conditional counts, not expected savings, measured speedups, approval, or dispatch instructions.
Cheap-run cost and class eligibility must be deducted before an economic claim. The empirically
supported reduction remains **unknown**.

## Verification and close-out boundary

`collect_baseline.py` ran successfully against a read-only DB snapshot and authenticated all
available target cells. Frozen evidence was independently checked for CSV count/identity, report
and INI hashes, blank cheap fields, LF, complete history filename coverage, isolation deltas and
arithmetic. See `verification.json` and `artifact_manifest.json` for exact checks and file hashes.

The G: company-reference mount was unavailable. Local charter, profitability track, canonical
task payload and referenced evidence were read. No untracked operational repair was attempted.
This packet must remain REVIEW; the full S2–S5 experimental acceptance criteria remain unmet.

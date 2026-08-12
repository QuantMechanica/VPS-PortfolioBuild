# Codex adversarial challenge — ULTRACODE programme plan

**Date:** 2026-07-26  
**Plan challenged:** `docs/ops/plans/2026-07-26_ULTRACODE_PROGRAMME.md`  
**Audit checkout:** `agents/board-advisor` at `b6e3c2b0181240ee4172866965348cb9fdf6851b`

## Scope and evidence integrity

This was a read-only challenge except for this requested evidence file. I did not access
`T_Live`, install or alter tasks, run a backtest, mutate the farm DB, edit source, or make a
commit.

The queue figures below are a point-in-time `mode=ro`, `PRAGMA query_only=ON` read of the
actual factory DB, `D:\QM\strategy_farm\state\farm_state.sqlite`, at approximately 08:58
Europe/Berlin. The similarly named repo-local DB is not the live factory DB. This distinction
must be explicit in every future acceptance command.

| Phase | Active | Pending | Done | Failed |
|---|---:|---:|---:|---:|
| P2 | 0 | 0 | 442 | 4 |
| Q02 | 1 | 2,151 | 23,712 | 47,032 |
| Q03 | 1 | 29 | 11,895 | 731 |
| Q04 | 1 | 25 | 15,082 | 144 |
| Q05 | 1 | 0 | 756 | 93 |
| Q06 | 0 | 0 | 366 | 1 |
| Q07 | 5 | 2 | 302 | 6 |
| Q08 | 0 | 0 | 471 | 40 |
| Q09_PORTFOLIO | 0 | 0 | 105 | 0 |
| Q10 | 0 | 0 | 37 | 0 |

Total: **9 active, 2,207 pending**. Of the pending Q02 rows, only 25 have a truthy
`priority_track`; none has a `retest_class`. Payload text shows that at least 1,334 rows are
from `claude_sweep_enqueue_2026-06-10.stranded_infra_fail`, 218 contain
`deferred_promotion`, 151 contain `auto_q02`, and 125 contain `never_tested`. These labels
overlap and are not a sound scheduling taxonomy. The plan's “generic pool” premise is
therefore materially under-specified, and its quoted Q02 count was already stale while this
review was running.

## Verdict map

| Workstream | Verdict | Decisive finding |
|---|---|---|
| A + H | **REVISE** | A targets the wrong/secondary claim path and contradicts the idle-only recovery rule; H is directionally correct but misses the exact early-return branch and test needed. |
| B | **REVISE** | Density is the right FTMO constraint, but five cards and five builds do not prove density, admission, or `P(pass)>0.5`; two named families contradict the plan's own frequency target. |
| C | **REVISE** | The proposed 24/24 Q10 evidence set does not exist, and “trailing 24 months” is not current when the latest Q10 history ends 2025-12-31. |
| D | **REVISE** | Q08 streams contain no trade direction; P/L sign cannot recover it. Existing native-report reconciliation code should be reused, and current swap rates must be labelled as a scenario rather than historical actuals. |
| E1 | **REVISE** | The fast recovery controller already exists and is faster than the proposed 15-minute task. The missing mechanism is reliable, approved, deduplicated alerting and proof of the existing chain. |
| E2 | **REVISE** | The briefing is stale/hard-coded and needs live-state truth, but it must consume watchdog state rather than add prohibited process probing. |
| E3 | **REVISE** | Exact chart/profile validation is right, but an on-disk `.chr` is not proof of runtime attachment; existing profile parsers should be generalized and paired with fresh runtime identity evidence. |
| E4 | **REJECT** | Increasing cadence would publish a known-invalid comparator more often: obsolete manifest, unfiltered logs, unmatched windows, and placeholder Monte Carlo. Repair the evidence contract before rescheduling. |
| F | **REVISE** | The proposed heuristics will false-positive on deterministic or rounded outputs. Existing seed-authentication logic and provenance must be used, and health DB reads must really be read-only. |
| G | **REJECT** | A second Python guardian creates split-brain authority. The repo already has a purpose-built account governor, policy include, and observer; close that design's explicit blockers instead. |

## Workstream challenges

### WS-A + WS-H — **REVISE**

The problem is real, but the proposed control point is not.

The production terminal claimant is
`tools/strategy_farm/terminal_worker.py`, not merely the legacy claim loop in
`tools/strategy_farm/farmctl.py`. `_priority_pending_query()` at approximately
`terminal_worker.py:264-334` ranks a truthy `priority_track` before phase, with Q10 through
Q02 then ordered below it. `claim_atomic()` begins an immediate transaction and applies
terminal/resource eligibility before atomically taking the row at approximately
`terminal_worker.py:818-1065`. By contrast, the pending selector around
`farmctl.py:5303-5373` has a different ordering contract and the later active update around
`farmctl.py:5465-5477` is not the production claimant's atomic path.

This has three consequences:

1. A change confined to `farmctl.py` will not govern the active terminal workers.
2. The proposed FTMO density rows can already jump the queue by using the existing
   `priority_track` path. WS-A therefore does not “fund” WS-B with capacity.
3. A hard 80/20 reservation for recovery conflicts with Operating Rule 22
   (`docs/ops/OPERATING_RULES_2026-07-03.md:114-117`), which permits recovery work only on
   otherwise-idle capacity. It must not pre-empt eligible frontier/priority work.

The 20% mechanism is also not concurrency-safe if implemented as a pre-sort, a per-process
counter, or a payload backfill. Several workers can observe the same ratio, resource filters
can reject the selected class, and worker restarts erase in-memory windows. “One in five
claims” must mean successful eligible claims, not query attempts.

**Exact revision required for A:** replace the hard recovery reservation with an
eligibility-aware **maximum** recovery share. Preserve `priority_track`/frontier ordering.
Only when the priority/frontier selector returns no eligible work may recovery consume idle
capacity, up to a durable rolling cap. Put the policy in one selector used by every claimant,
or remove the secondary claimant. Consult and advance the durable class ledger within the
same `BEGIN IMMEDIATE` transaction as the successful claim. Specify the window denominator,
restart behavior, resource-filter fallback, and no-starvation invariant.

The explicit backfill/revert also needs provenance. The current
`prioritize_intraday_ftmo.py` opens the DB read-write even for its dry-run path and its revert
can remove a pre-existing `priority_track`. A safe operation must bind each target row ID to
its pre-image payload hash, add a unique batch/source marker, record the exact post-image
hash, and revert only a matching post-image with compare-and-swap semantics. “Remove the
flag” is not a safe rollback.

WS-H identifies a genuine taxonomy error. In
`farmctl._derive_phase_runner_verdict()` (approximately `farmctl.py:2077-2140`), generic
top-level `INFRA`/`ERROR`/`TIMEOUT` handling returns before the Q08 dominant-reason helper.
The existing tests around
`tools/strategy_farm/tests/test_verdict_taxonomy_ws2.py:91-131` cover top-level `INVALID`,
not the exact top-level `INFRA_FAIL` plus authentic insufficient-trades subgate case.

**Exact revision required for H:** for Q08 only, evaluate authenticated dominant subgate
evidence before the generic top-level infrastructure return. Reclassify only the explicit
insufficient-trades family to `INVALID`; preserve genuine launch, transport, report, and
timeout failures as `INFRA_FAIL`. Acceptance must include:

- top-level `INFRA_FAIL` plus dominant `INVALID/INSUFFICIENT_*` becomes `INVALID`;
- genuine infrastructure evidence remains `INFRA_FAIL`;
- mixed, missing, or unauthenticated subgate evidence preserves the top-level verdict;
- a read-only corpus comparison lists every historical row whose classification would
  change, with no unrelated phase changes.

Unit tests of a new sorter are not adequate proof for A. Acceptance needs a multi-connection
SQLite contention test covering successful-claim ratios, restart continuity, ineligible
rows, frontier precedence, and both claim entry points.

### WS-B — **REVISE**

The plan correctly recognizes that FTMO needs more independent opportunity density. It does
not yet propose a mechanism that proves it.

The sealed FTMO research artifact
`D:\QM\reports\portfolio\ftmo_book_engine_20260722\research_summary.json` is
`RESEARCH_ONLY_NO_GO`. Its four-sleeve baseline has zero estimated 30-day pass probability
and only about 0.127 conditional pass probability by day 180. Its
`density_gap_correction.json` says the previous solver was invalid and gives a planning
bound of roughly seven new reference-class sleeves at 0.5% risk, 300 trades/year, and
0.15R/trade to reach 80%—not evidence that five arbitrary cards are sufficient.

The nominated families also fail the plan's own 3–5 trades/week premise:

- `QM5_13128` has about 57 trades over roughly 7.2 years, around 8/year.
- `QM5_12969` has about 331 trades over roughly 8.2 years, around 40/year.
- `QM5_20007` has repeated Q02 infrastructure failures and no completed evidence that it is
  a density motor.
- A new FX session-fade family risks repeating the already-ratified conclusion that
  `FX-High-Freq` is commission-dead
  (`docs/ops/OPERATING_RULES_2026-07-03.md:97-104`).

There are also nearer, evidence-bearing candidates:

- `QM5_13213/USDJPY` has about 1,624 Q10 trades and Q10 PASS, but Q08 FAIL_SOFT and Q09
  `no_diversification`.
- `QM5_13301/GDAXI` has about 742 Q10 trades and Q10 PASS, but Q08 FAIL_SOFT and Q09
  `CHALLENGER_SUPERIOR`.

Those Q09 failures must not be waived. They should be adjudicated first because a legitimate
gate repair or a confirmed rejection is faster information than five greenfield builds.

The admission contract is also split. `tools/strategy_farm/portfolio/ftmo_qualification.py:27,321-353`
requires PASS across Q02-Q08 and Q10, while the sealed research engine admits `QM5_12969`
despite Q08 FAIL_SOFT because it passed Q09 portfolio admission. Until one OWNER-ratified
admission contract is canonical, a reported `P(pass)` is not reproducible.

Finally, `P(pass)>0.5` is incomplete without a horizon and objective. Phase 1 by 30 days,
Phase 1 by 180 days, both phases, and first reward are different outcomes. An unlimited-time
pass probability is economically misleading.

**Exact revision required:** make the first B deliverable a canonical, manifest-bound FTMO
objective and admission ledger:

1. define account size, phase, loss/target rules, horizon, both-phase treatment, first-reward
   treatment, costs, and the one admission contract;
2. adjudicate `13213`, `13301`, `12969`, and `20007` without relaxing a gate;
3. rerun the existing sealed model read-only to quantify the residual density gap;
4. source only enough new families to fill that measured gap, with a pre-build opportunity
   estimate of at least 156–260 trades/year for any sleeve called a 3–5/week motor,
   after-cost edge, and an orthogonality hypothesis;
5. treat five cards as a paperwork milestone, never as the workstream acceptance proof.

Acceptance is a reproducible joint-book replay under the canonical contract showing the
specified `P(pass)>0.5` at the specified horizon, with sensitivity to cost, correlation,
sequence, and execution density. It must also show portfolio-survivor purity; passing a card
lint and creating build rows proves none of those claims.

### WS-C — **REVISE**

The proposed audit is necessary before increasing capital risk, but its evidence premise is
false.

`framework/scripts/q10_confirmation.py:142-184` persists aggregate metrics and a native
report path; it does not persist the trade list needed for a new rolling-window analysis.
The DB/manifest join finds native Q10 reports for only **23 of the 24** FINAL24b sleeves.
`12567/XNGUSD`, which is in
`portfolio_manifest_sunday_FINAL24b_TOTALRISK12_20260726.json`, has no Q10 row. Therefore an
“all 24 from existing Q10 evidence” acceptance criterion cannot pass honestly.

The available Q10 histories run from 2017-01-01 to 2025-12-31. In late July 2026, a
“trailing 24 months” split ending at the evidence endpoint is already seven months behind
the intended deployment date. It is a recent **historical sample window**, not proof that
the edge is current.

This matters tonight. Decision A raises total risk from 9.75% to 12%, a 23.1% aggregate
increase. Because capped sleeves cannot scale, the runbook applies approximately 1.313x to
uncapped sleeves. At the same time:

- `12567/XNGUSD` has two identical, SHA-bound Q08 FAIL_HARD aggregates: 58 trades, only
  9/12 seasonal months, 41.52% decay, PF 1.7642 to 1.0318, and a negative low-volatility
  regime;
- Decision C for that sleeve remains an explicit OWNER choice;
- the deployment manifest is still `DRAFT`, `STAGE_ONLY`, and requires manual approval;
- 0/21 compared deployed binaries match the repo set, with a special stale/fresh binary
  ambiguity for `1567`;
- chart/profile damage and the dormant/corrupt KS baseline remain open runbook items.

**Exact revision required:** define a per-sleeve evidence inventory before calculating any
decay verdict. Parse native Q10 reports only when the report, set, EA binary, symbol, and
history window are cryptographically tied. A Q08 stream may substitute only when its SHA and
configuration are tied to the same candidate and its trade count/net reconcile to the
native report. Mark missing or non-comparable sleeves `UNKNOWN`; do not impute, silently
drop, or call 23/24 “all”. Label the window by its actual endpoint and age.

The shadow-output acceptance must include:

- coverage and provenance for every manifest sleeve;
- explicit `CURRENT`, `DECAYED`, and `UNKNOWN` lists with reason codes;
- boundary fixtures for 19.9/20.0/20.1% and 24.9/25.0/25.1%;
- byte-for-byte proof that no set, weight, manifest, registry, or T_Live file changed;
- a statement that the result is decision evidence, not authorization to auto-remove or
  auto-swap a sleeve.

For tonight's money gate, the C/D audit outcome—or an explicit OWNER acknowledgement of each
`UNKNOWN`—must precede written approval of TOTAL_RISK12. That does not reopen Decisions A-D;
it makes their stated manual money gate evidence-complete.

### WS-D — **REVISE**

Direction is not recoverable from the Q08 stream schema.

Across the 181 files under
`D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades\*.jsonl`, I found 47,515 valid JSON
rows. The union of trade keys is:

`commission`, `entry_time`, `event`, `mae_acct`, `magic`, `net`, `notional`, `profit`,
`swap`, `symbol`, `time`, `volume`.

There are zero `direction`, `side`, or trade-`type` fields. The required schema in
`framework/registry/event_vocabulary.json:11-34` does not require direction, and the emitter
around `framework/include/QM/QM_Common.mqh:878-942` does not emit it. There are 20,147 positive-net
and 27,348 negative-net rows, but net sign is outcome, not long/short direction. A losing
long and a winning short are indistinguishable by sign. The plan's sign-convention fallback
would silently produce fabricated swap charges.

The repo already contains the correct starting mechanism:
`tools/strategy_farm/portfolio/ftmo_report_cost_reconcile.py:56-128` parses native MT5 deal
rows, distinguishes `Direction` (`in`/`out`) from `Type` (`buy`/`sell`), FIFO-pairs partial
fills, and reconciles report counts. Its later logic handles rollover units and side-specific
swap. Reuse and generalize that path instead of inferring direction from Q08.

`venue_cost_model.json:150-153` still marks swap unresolved for all venues and has null
`swap_note` values. Existing FTMO evidence includes point-in-time symbol snapshots, but a
current broker rate applied over an eight-year backtest is a **deployment-cost stress
scenario**, not reconstruction of actual historical swap. DXZ rates, broker symbol mapping,
rate effective dates, swap mode/units, contract size, price digits, profit-currency
conversion, triple-day policy, server timezone/DST, and holiday treatment must all be bound
to the output. SP500 and XNG commission/contract-basis questions also remain open; swap
support must not conceal them.

**Exact revision required:** make native MT5 report deals the authoritative direction
source. Reconcile them to the durable Q08 stream/aggregate first; then apply a source-bound,
venue-specific current-rate scenario. If the native deals, mapping, rate, or conversion
inputs are absent or do not reconcile, produce `UNKNOWN`, not a signed estimate. Rename KPI
labels from “WITH actual swap” to “with current-rate swap scenario” unless a genuine
effective-dated historical rate series exists.

Acceptance must cover long and short positions, partial closes, same-day/no-roll trades,
one- and multi-night holds, triple rollover, DST/midnight boundaries, holidays, rate-unit
conversion, and profit-currency conversion. Before recosting, reconstructed trade count,
gross/net P/L, commission, existing swap, and source SHA must match the native evidence
within declared tolerances. Whole-book results must remain explicitly incomplete if any
material sleeve is `UNKNOWN`.

### WS-E1 — **REVISE**

The plan proposes a slower duplicate of controls that already exist.

`tools/strategy_farm/T_Live_Watchdog.ps1:562-603` starts the resident session supervisor and
delegates missing-terminal recovery. It is already intended to run every minute and has
atomic state writing plus reboot/shutdown safety around `:476-507` and `:649-832`.
`Live_MT5_SessionSupervisor.ps1:17-19,47-76,112-174,220-245` probes both sessions every ten
seconds, requires consecutive misses, uses the existing `T_Live_ON`/`FTMO_ON` launchers, and
fails closed on maintenance, unknown probes, or duplicate processes. A new task that waits
15 minutes would add a competing controller and make recovery slower.

The actual gap is alert transport. `silent_failure_monitor.py:19-34` records evidence, but
the former hourly Gmail FAIL/OK route is OWNER-disabled. The phrase “existing FAIL-digest
channel” is therefore not an implementable acceptance criterion and must not be used to
quietly re-enable mail.

**Exact revision required:** retain one recovery authority—the existing watchdog plus
resident supervisor—and turn E1 into an observability/handoff repair. Emit a
transition-deduplicated terminal/session alarm into an explicitly OWNER-approved existing
state/briefing/cockpit path; do not introduce another launcher. Preserve `NoReboot`,
maintenance, duplicate-process, probe-unknown, and reboot-countdown abort behavior.

Acceptance is a fixture/state-machine test of both sessions independently: missing,
recovered, duplicate, maintenance, probe unknown, launch failed, stale state, and reboot
suppression. Activation or restart of this chain is an evening money-edge action because
the launchers can enable experts; it is not an ordinary scheduled-task edit.

### WS-E2 — **REVISE**

The morning brief does need live truth. Today it directly reads live files, hard-codes
`LIVE_BOOK_SLEEVES = 24`, retains stale FTMO trial-dead prose, and builds its subject from
factory/frontier status rather than live red state (approximately
`tools/strategy_farm/morning_brief.py:79-81,459-463,647,688-693`).

Operating Rule 20 prohibits live-pulse process access and permits read-only file/state
evidence (`docs/ops/OPERATING_RULES_2026-07-03.md:105-109`). E2 must therefore not add its
own MT5 process probe.

**Exact revision required:** consume the watchdog/supervisor's atomic state contract, derive
expected accounts/sleeves from the currently signed manifest rather than a constant, and
report freshness, account identity, profile/deployment epoch, FTMO phase state, and live
contract status. Missing, malformed, or stale source state must become explicit
`UNKNOWN/RED`, never “green by absence”. A red live condition must reach the subject and
top summary. Trial-dead text must be generated from account state, not retained prose.

Acceptance should use frozen green/red/stale/malformed fixtures and prove deterministic
subject/body output without touching T_Live or probing a process.

### WS-E3 — **REVISE**

The profile-drift problem is real, but much of the parser already exists.

`prepare_dxz_v2_liveops_profile.ps1` parses `.chr` files and exact expert fields.
`verify_ftmo_round25_live_contract.ps1:95-200` already checks account/server, manifest,
profile files, chart symbol/timeframe/expert, EA path, magic, risk, binaries, and monitor.
Those should be generalized rather than replaced with a second parser.

An on-disk `.chr` proves only the recovery profile. It does not prove what the running MT5
session currently has open. Daily cadence also leaves an avoidable gap after an automatic
session recovery.

**Exact revision required:** bind the expected tuple
`(account, server, deployment_epoch, manifest_SHA, symbol, timeframe, EA, EA_binary_SHA,
magic, risk)` to the signed deployment manifest. Reuse the existing parser for disk-profile
truth, and require a fresh post-start `INIT_OK`/magic/EA identity heartbeat for runtime
truth. Detect missing, duplicate, orphan, and unparseable charts and require exactly one
account monitor. Keep disk-profile and runtime conclusions separately labelled.

Run the read-only verifier after any supervisor recovery and periodically thereafter, not
only once daily. Acceptance needs fixtures for 24/24 exact, stale profile, wrong magic,
wrong binary, duplicate chart, orphan chart, missing monitor, duplicate monitor, and
profile-correct/runtime-stale. No auto-correction is permitted.

### WS-E4 — **REJECT**

The current comparator is not fit to run more often.

`scripts/sunday_livevsbook_compare.ps1` points at an obsolete hard-coded 23-sleeve DRAFT
manifest (`:15`) and the scheduled task is actually named
`QM_NewBook_LiveVsBook_Sunday`, not the plan's generic description. The task currently runs
weekly on Sunday at 08:00 and its last result was successful; cadence is not its correctness
problem.

`tools/strategy_farm/portfolio/portfolio_live_forward_from_logs.py:42-55` ingests every matching QM5
log rather than filtering to the signed manifest and deployment epoch. Around `:58-109`, it
accumulates account/log history whose time basis is not matched to the book expectation.
Around `:117-186`, it compares against the supplied manifest but falls back to placeholder
Monte Carlo. Around `:216-220`, it writes the report directly rather than atomically.

Changing Sunday to daily would create seven times as much authoritative-looking but
mis-scoped evidence.

Reject the cadence-only implementation. A replacement workstream may be proposed only after
the comparator:

- binds one signed manifest SHA and deployment epoch;
- filters exactly the expected EA/magic/symbol/account identities;
- matches the same observation window, capital, weights, costs, and SUM-of-sleeves Monte
  Carlo basis;
- separates daily data-quality/status checks from a sufficiently powered weekly comparison;
- writes atomically and idempotently and marks incomplete inputs `UNKNOWN`.

Until those conditions pass fixtures and a read-only historical replay, retain the current
schedule and do not promote the output to a money gate.

### WS-F — **REVISE**

The health objective is sound; the proposed signatures are not yet specific enough.

Exact Q05/Q06 PF and trade-count equality can be legitimate after rounding or when a stress
does not bind. Zero cross-seed variance can be legitimate for a deterministic EA. Treating
either as corruption without set/report provenance will create false alarms. Q07 already
has stronger seed authentication in
`framework/scripts/q07_multiseed.py:131-301,540-588`; new checks should consume that
evidence instead of recreating seed identity from filenames.

There is also a read-only gap in the checker itself. `tools/strategy_farm/health.py:98-101`
opens SQLite normally. Although its checks currently query, the connection is not
`mode=ro`/`query_only`. `run_all()` then writes health state/alarm artifacts around
`:1888-1926`. The DB read and the intended output write should be separated in the contract.

The KS test is especially unsafe as “baseline file exists”. The runbook already records a
dormant/corrupt baseline. A valid check needs the expected baseline hash from a manifest and
observed proof that the expected events were actually loaded.

**Exact revision required:**

- compare Q05 and Q06 only after authenticating EA/set/binary/report hashes, stress
  telemetry, unrounded KPIs, and a minimum cohort/trade threshold;
- validate five distinct, fresh, requested Q07 seeds using the existing authentication and
  emit reason-specific failures (`seed_alias`, `stale_report`, `set_mismatch`,
  `deterministic_by_design`, and so on);
- bind KS baseline identity to a manifest/hash and require observed loaded-event evidence;
- open the production DB by URI with `mode=ro` plus `PRAGMA query_only=ON`; limit writes to
  the separate health output path.

Acceptance requires synthetic positive/negative fixtures, a read-only production snapshot
with a reviewed false-positive list, and a runtime budget showing the scheduled health pass
cannot materially contend with the factory.

### WS-G — **REJECT**

The proposed new supervisor duplicates an already designed safety authority.

The repo contains:

- `tools/strategy_farm/ftmo_trial_pulse.py`, an independent observer with account-monitor
  freshness checks and an optional armed halt artifact;
- `framework/EAs/QM5_13206_ftmo-account-governor`;
- `framework/Include/QM_FTMOGovernorPolicy.mqh`;
- an explicit FTMO governor specification whose deployment default is false and whose open
  blockers include client wiring, golden parity, target-before-four-days behavior,
  bootstrap, a signed manifest, and T6 verification.

A scheduled Python “guardian” that writes generic/per-EA halt files creates two policy
engines with different clocks, account state, latency, and failure modes. A 30-minute poll
also cannot enforce an intraday equity limit safely. This is a split-brain money control,
not defence in depth.

Reject the new guardian. Replace G with closure of the existing `13206` governor's ratified
blockers, while retaining `ftmo_trial_pulse.py` as an independent read-only observer/parity
oracle. There must be one armed trading authority.

The acceptance contract must encode and test the repo's FTMO rules, including:

- exact login, server, currency, account size, and phase identity;
- Prague-midnight day boundaries across DST;
- daily loss from balance/equity including floating P/L, commission, and swap;
- the 5% daily and 10% maximum loss floors;
- 10% Phase 1 and 5% Verification targets;
- four qualifying opening days, including target-before-day-four latch/flat/cancel
  behavior;
- funded-phase no-target behavior and, if “time to revenue” is the objective, first-reward
  timing/flatness;
- open positions and pending orders;
- a durable, monotone lock across restart, stale/missing feeds, and foreign positions;
- exact signed-manifest magic whitelist and fail-closed handling of unknown identities.

Enforcement belongs in the EA timer/client path already designed for sub-second response,
not a scheduled filesystem poll. No arming, deployment, or account-specific policy is
permitted before the new trial exists and the OWNER signs the exact manifest.

## Priority challenge

The plan's top-level priority claim is not supported by the actual system.

WS-B is the largest long-run FTMO research need, but it is not the fastest money move, and
WS-A is not its prerequisite. Existing `priority_track` rows already outrank all deep
phases in the real terminal claimant. Marking a B build correctly can bypass the generic
Q02 backlog now; reserving 20% recovery capacity does not accelerate it.

The faster, gate-preserving paths are:

1. **DXZ:** close the evidence and deployment-contract gaps on the already selected
   FINAL24b TOTAL_RISK12 book—especially Decision C/XNG, binary identity, `1567`, profile
   integrity, and C/D uncertainty—then present the existing DRAFT manifest for the already
   required OWNER money signature. This is nearer to revenue than creating five cards, but
   it must not leapfrog any runbook or money gate.
2. **FTMO objective:** ratify one admission contract and one finite-horizon definition of
   `P(pass)>0.5`. Without this, every density result is non-comparable.
3. **Existing density evidence:** adjudicate `13213` and `13301`, then rerun the sealed
   density-gap model. This can eliminate or sharpen greenfield work without relaxing their
   Q09 failures.
4. **FTMO control/account critical path:** close the existing governor blockers and obtain
   the OWNER-gated new trial. No amount of card throughput produces revenue before an
   account can be safely armed.
5. **Greenfield density:** create only the evidence-qualified cards needed by the residual
   model, then require portfolio admission and joint replay rather than build completion.

Busywork to cut or defer:

- cut the claim that A “funds” B; retain only an idle-capacity, concurrency-safe fairness
  repair if its measured benefit justifies touching the claimant;
- cut E4's cadence-only change;
- cut E1's second recovery loop;
- cut G's second guardian;
- cut the fixed “five cards” success metric and replace it with measured residual density;
- keep H as a small truthfulness repair, but do not sell it as a money motor;
- stage E2/E3/F as evidence-quality work after the immediate money-gate evidence, unless
  they are needed to make tonight's deployment contract truthful.

## Missing items

The diagnosis and plan omit the following items or rely on premises contradicted by the
audited system:

1. **Two DBs can be confused.** The live factory DB is under
   `D:\QM\strategy_farm\state`, as hard-coded in
   `factory_watchdog.ps1:325,628,855`; `C:\QM\repo\state\farm_state.sqlite` is not the live
   queue. Every dry-run/acceptance command must print and verify its resolved DB path before
   reading.
2. **The Q02 backlog lacks the proposed class label.** No pending Q02 row has
   `retest_class`; most payloads are recovery/history debris, not a clean generic discovery
   population. A ratio cannot be applied safely until classification provenance is
   explicit.
3. **FTMO probability lacks a time and revenue definition.** Phase 1, Verification, funded
   survival, and first reward must not be collapsed into one `P(pass)`.
4. **FTMO admission is internally inconsistent.** Strict phase PASS in
   `ftmo_qualification.py` and the research engine's admission of a Q08 FAIL_SOFT sleeve
   cannot both be canonical without a ratified rule explaining the difference.
5. **DXZ allocation mechanics are absent.** A new strategy needs strict gate admission,
   joint portfolio replay, survivor-port proof, symbol/venue eligibility, magic allocation,
   weight/risk construction, manifest inclusion, and OWNER approval. “Card built” has no
   direct path to DXZ capital.
6. **TOTAL_RISK12 amplifies uncertainty tonight.** The aggregate rise is 23.1% and uncapped
   sleeves scale about 31.3%, while decay, swap, binary identity, and profile integrity
   remain unresolved. An OWNER framework decision is not the same as the still-missing
   written manifest approval.
7. **Q10 coverage and freshness are overstated.** There are only 23 relevant native reports
   for 24 manifest sleeves, and they end in 2025. XNG's Q08 evidence is both the sharpest
   decay warning and outside the claimed Q10 audit basis.
8. **Swap evidence is point-in-time, not historical.** Current FTMO/DXZ rates can support a
   conservative scenario; they cannot be called actual historical carry without an
   effective-dated source series. Commission/contract-basis OPEN items remain separate.
9. **Recovery state is not alert delivery.** Atomic watchdog state exists, while the mail
   route is explicitly disabled. Every alert destination needs an owner, freshness SLA,
   transition/deduplication rules, and proof somebody/something consumes it.
10. **Disk profile is not runtime truth.** `.chr` validation must be paired with a
    post-start runtime identity heartbeat and deployment epoch.
11. **Live-vs-book lacks a sampling contract.** Manifest, identities, deployment epoch,
    observation window, starting capital, costs, and the Monte Carlo population must match
    before any divergence threshold has meaning.
12. **The health checker's own DB handle is not read-only.** A programme that advertises
    read-only health checks should enforce that at SQLite connection level.
13. **Scheduled-task creation is a state mutation.** Plan language that treats task
    installation as ordinary implementation conflicts with the required Factory-OFF,
    evening, and OWNER-controlled activation boundaries.
14. **The factory is moving the checkout.** During this review HEAD advanced through
    pump auto-commits. Parallel builders touching claimant, scheduler, or evidence paths can
    compile/test one revision and commit another unless base SHA, dirty paths, and generated
    artifacts are pinned.

## Sequencing and Factory-ON safety challenge

The plan's “source-only changes while Factory ON” rule is too broad for files that active
processes import or scheduled tasks reread.

| Change | What breaks while Factory ON | Required boundary |
|---|---|---|
| `terminal_worker.py` / `farmctl.py` selector edits | Existing Python daemons retain old imported code while respawned/new processes load new code, producing mixed claim policies against one DB. | Do not alter these files in the canonical active checkout. Stage elsewhere; merge in a Factory-OFF window, quiesce workers, snapshot DB, deploy one version, restart all workers, then run a claim-only canary. |
| Priority/retest payload backfill or scheduling ledger/schema | This is a DB state mutation; concurrent claimers can take rows between pre-image and update, invalidating rollback and ratios. | Factory OFF, zero active claimers, verified live DB path, backup/snapshot, compare-and-swap batch, post-audit, then controlled restart. |
| `q10_confirmation.py` or aggregate schema | A dispatched runner imports code per invocation. Old and new aggregate contracts can coexist if a row starts during deployment. | Factory OFF and no active/pending Q10, or an explicitly versioned schema with in-flight drain. No reruns/backtests are authorized by this challenge. |
| `health.py` scheduled source | A scheduled invocation can begin while files are only partially deployed or while tests refer to a different revision. | Stage/test separately; atomically activate/repoint during the Factory-OFF window. Its production DB connection must remain read-only. |
| Watchdog/session-supervisor source | The resident supervisor has its old script loaded, while the minute watchdog may load a new contract and restart money-edge processes. | Evening OWNER window only: stop/repoint/restart as one versioned unit, preserve `NoReboot`, and verify fixtures before any live read-only verification. |
| Morning brief / profile checker / LiveVsBook task | Task Scheduler rereads scripts at launch; a task can start mid-deploy and publish mixed-version evidence. | Install/repoint task XML and activate schedules only in the controlled window. First run against fixtures; live read-only verification only under its separately authorized session. |
| Venue-cost and decay defaults | Consumers can ingest a partially revised schema or treat new scenario fields as authoritative actual costs. | Version the schema/output, keep default non-authoritative, and activate only after consumer compatibility and provenance tests. |
| FTMO governor/observer | A second authority, changed halt format, or newly armed policy can alter trading behavior immediately. | Never while Factory ON as a routine code deploy. Build/test offline; account-specific arming only after trial creation, signed OWNER manifest, all governor blockers, and the prescribed verification phase. |

Source work in disjoint files can be prepared while the factory runs, preferably in an
isolated worktree pinned to a base SHA. What must be deferred tonight is not only “state
mutation”: all claimant activation, claimant-file replacement in the canonical checkout,
worker restarts, queue backfills, schema activation, scheduled-task install/repoint, resident
supervisor restart, live-filesystem verification, live profile operations, manifest deploy,
and FTMO arming. The Factory-OFF window does not itself authorize T_Live or a money action;
the runbook and OWNER gates still apply.

## Three highest-risk implementation details by workstream

### A + H

1. Modify the **actual atomic claimant**, with one shared ordering contract and no mixed
   worker versions.
2. Make recovery a durable, concurrency-safe idle-cap—not a 20% reservation—and make
   backfill/revert compare-and-swap provenance-safe.
3. Move only the authenticated Q08 insufficient-trades case ahead of the generic infra
   return; do not relabel genuine infrastructure failures.

### B

1. Define one finite-horizon FTMO outcome/admission contract before optimizing or quoting
   `P(pass)`.
2. Enforce the claimed 156–260 trades/year, after-cost edge, and independent opportunity
   hypothesis before calling a card a density motor.
3. Preserve all Q02-Q10 and portfolio-survivor gates; quantify residual joint-book benefit
   rather than counting cards/builds.

### C

1. Bind every calculation to report/set/binary/symbol/window hashes and propagate the
   unavoidable 24th-sleeve `UNKNOWN`.
2. Label window endpoint and evidence age; never present a 2025-12-31 endpoint as current
   July 2026 edge.
3. Keep the tool shadow-only and prove no byte changed in sets, weights, manifests,
   registries, or live paths.

### D

1. Recover side only from native deal `Type` plus `Direction`; never from P/L sign.
2. Correctly implement swap mode/units, partial fills, rollover nights, triple day,
   timezone/DST, holidays, contract size, and currency conversion.
3. Reconcile native deals to stream count/net/SHA before recosting and propagate unknown
   rates or mismatches to an incomplete whole-book result.

### E1

1. Preserve one recovery authority and all maintenance, duplicate, unknown-probe,
   `NoReboot`, and shutdown-abort fail-safes.
2. Route transition-deduplicated alerts only through an OWNER-approved consumer; do not
   silently revive disabled Gmail.
3. Activate the watchdog/supervisor as one version in the evening window because its
   launchers can enable expert trading.

### E2

1. Consume fresh atomic watchdog state rather than adding process access.
2. Derive expected live/FTMO state from the signed manifest/account phase and make red live
   status reach the subject.
3. Fail visibly on missing, stale, malformed, or mismatched state; absence is never green.

### E3

1. Bind the exact account/deployment/manifest/chart/EA/binary/magic/risk tuple.
2. Keep disk-profile truth separate from fresh runtime-attachment truth.
3. Trigger verification after recovery as well as periodically, while remaining strictly
   read-only and detecting duplicates/orphans.

### E4

1. Filter live data to one signed manifest SHA, deployment epoch, account, EA/magic, and
   symbol set.
2. Match observation window, capital, weights, costs, and SUM-of-sleeves Monte Carlo before
   comparing.
3. Make output atomic/idempotent and distinguish daily data quality from statistically
   meaningful weekly divergence.

### F

1. Authenticate provenance and unrounded telemetry before calling equality or zero variance
   corrupt.
2. Reuse the Q07 five-seed freshness/identity machinery and emit reason-specific,
   deterministic results.
3. Bind KS baselines to manifest hashes and keep production DB handles enforced
   `mode=ro`/`query_only` with bounded runtime.

### G

1. Keep exactly one armed account authority; the Python pulse remains an independent
   observer, not a competing halt engine.
2. Get Prague-midnight/DST, intraday equity components, phase targets, minimum days, and
   target-before-day-four behavior exactly aligned with the ratified policy.
3. Make the account/magic scope and safety lock durable, monotone, fail-closed, and fast
   enough for an intraday limit; never arm it without the exact OWNER-signed manifest.

OVERALL VERDICT: PROCEED-WITH-REVISIONS

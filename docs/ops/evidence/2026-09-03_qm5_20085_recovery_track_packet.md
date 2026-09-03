# QM5_20085 Recovery-Track Decision Packet — 2026-09-03

**EA:** `QM5_20085_lebeau-lucas-momentum-oscillator-h4-r1-recovery` (H4, recovery track, EA-id 20085)
**Author:** Claude (Orchestrator), board-advisor worktree, read-only DB inspection
**DB read mode:** `file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro` (no mutation performed)
**Companion:** `docs/ops/OPEN_ITEMS_STATUS.md` Vorlage 09:40Z (Auffangregel 21:35Z)
**Purpose:** Substantiate the OWNER Vorlage "park the recovery track" with the full attempt
history, the root-cause of the timeouts, the exact pending rows, and CEO-ready commands.
Nothing here mutates state — every `farmctl` / `governed_work_item_hold` command is *prepared*
for the CEO to run.

---

## 0. Executive summary

- QM5_20085 (H4 recovery track) has three symbols alive at **Q07** (seed-robustness gate):
  EURUSD, XAUUSD, WS30 — all PASS through Q06, all stuck at Q07. Every other symbol died at
  Q04. Best clean phase per symbol = **Q06**.
- **Q07 = 5 canonical seeds {42, 17, 99, 7, 2026}, each a full-history (2017-2025, 9y) Model-4
  real-tick backtest under HARSH stress**, per-seed inner cap **5400 s (90 min)**
  (`framework/scripts/q07_multiseed.py:60 DEFAULT_SEED_TIMEOUT_SEC=5400`; seeds registry
  `framework/registry/multiseed_seeds.json`).
- **Root cause splits by symbol:**
  - **XAUUSD / WS30 (tick-heavy):** the *binding* limit is the **90-min per-seed inner cap** —
    every gold seed runs the full 90 min and returns `INCOMPLETE_RUNS,TIMEOUT` with a 0-byte
    report (backtest never completes one seed). A larger *outer* budget alone changes nothing.
  - **EURUSD (light ticks):** seeds *do* complete (~59-75 min; two seeds produced 204 / 207
    trades). Its binding limit is the **outer budget** (216 min fits only ~2-3 of 5 seeds) plus
    intermittent `launch_fault` wedges.
- **20085 is NOT on the 25-path today:** 0 rows in `portfolio_candidates`, 0 in
  `candidate_qualifications`; highest phase reached anywhere = Q07. Parking it costs **zero**
  counter progress and frees one of only **two** fleet-wide Q07/Q08 long-run slots
  (`longrun_scheduling_policy.py:35 Q07_Q08_LONGRUN_FLEET_CAP=2`) — the exact slot the
  OWNER-priority recompile chains (11910/12710/10700) were contending for all morning.
- **Live rows right now:** 1 pending (WS30 `0bc6a5bc`), 1 active (XAUUSD `19d3d8e5` on T3).
  EURUSD has no live row (all 5 attempts terminal). No auto-requeue mechanism is scheduled, so
  parking is stable.

---

## 1. Full attempt history per symbol / phase

### 1a. Lineage summary (per (EA, symbol), all phases)

| Symbol | Q02 | Q03 | Q04 | Q05 | Q06 | Q07 |
|---|---|---|---|---|---|---|
| EURUSD | PASS | PASS | PASS_SOFT | PASS | **PASS** | 5× INFRA_FAIL (stuck) |
| XAUUSD | PASS | PASS | PASS_SOFT | PASS | **PASS** | 2× INFRA_FAIL + 1 ACTIVE |
| WS30   | PASS | PASS | PASS | PASS | **PASS** | 1× INFRA_FAIL + 1 PENDING |
| AUDUSD | PASS | PASS | FAIL | — | — | — |
| GBPUSD | PASS | PASS | FAIL | — | — | — |
| NDX    | PASS | PASS | FAIL | — | — | — |
| NZDUSD | PASS | — | FAIL | — | — | — |
| USDJPY | PASS | — | FAIL | — | — | — |
| XTIUSD | PASS | PASS | FAIL | — | — | — |

Only EURUSD/XAUUSD/WS30 reached Q07. All three passed Q06 (single-seed HARSH). None ever
produced a Q07 verdict — every Q07 row is INFRA (infra taxonomy), never a strategy PASS/FAIL.

### 1b. Q07 attempt ledger (times UTC; budget = payload `timeout_min`)

**EURUSD Q07** (promotion parent Q06 `a4cb2e43`; all `priority_track`, `append_only_rerun`):

| # | work_item | started | ended (updated) | wall | budget | verdict | recorded reason |
|---|---|---|---|---|---|---|---|
| 1 | `e5754875` | 08-17 (att2) | 08-17 15:46 | — | 216 | INFRA_FAIL | evidence not preserved (`evidence_path=None`) |
| 2 | `ce16e40a` | 08-23 ~15:2x | 08-23 16:12 | ~46m | 216 | INFRA_FAIL | `EVIDENCE_UNAVAILABLE:worker_crashed_handling_item` |
| 3 | `1b745b78` | 08-26 07:21 | 08-26 10:57 | ~216m | 216 | INFRA_FAIL | `summary_missing:launch_fault` (log never reached terminal_start) |
| 4 | `72891249` | 08-31 10:32 | 08-31 12:49 | ~137m | 216 | INFRA_FAIL | `seeds_invalid_evidence:[(17,'run_1_status=INVALID')]` — **but** seed42=204 trades OK, seed17=207 trades OK, seeds 99/7/2026 never ran (budget expired after 2 seeds) |
| 5 | `9eead733` | 09-03 03:52 | 09-03 07:28 | **216m** | 216 | INFRA_FAIL | `summary_missing:launch_fault` → `final_failure=summary_missing_retries_exhausted` (ran the full 216-min budget, reaped) |

**XAUUSD Q07** (promotion parent Q06 `65b74c41`):

| # | work_item | started | ended (updated) | wall | budget | verdict | recorded reason |
|---|---|---|---|---|---|---|---|
| 1 | `73aa9110` | 08-18 22:51 | 08-19 06:29 | ~7h38m | 696 (`absolute_ceiling_min=696`) | INFRA_FAIL | `seeds_invalid_evidence` — **all 5 seeds** `INCOMPLETE_RUNS,TIMEOUT` |
| 2 | `9597dd78` | 08-31 05:19 | 08-31 10:28 | ~5h09m | 418 | INFRA_FAIL | seeds 42,17 `INCOMPLETE_RUNS,TIMEOUT`; seed 99 `timeout_expired:5400s` (exit 124, killed at 5520s); seeds 7,2026 never ran |
| 3 | `19d3d8e5` | **ACTIVE** T3 | — (running) | see §1c | 418 | (none) | `append_only_rerun_of 9597dd78`; lineage `[9597dd78, 73aa9110]` |

**WS30 Q07** (promotion parent Q06 `2fd74910`):

| # | work_item | started | ended (updated) | wall | budget | verdict | recorded reason |
|---|---|---|---|---|---|---|---|
| 1 | `08055e0d` | 08-21 00:35 | 08-21 02:35 | ~120m | 120 | INFRA_FAIL | `summary_missing:launch_fault`; `commit_reservation 44 GB single_index_tick` |
| 2 | `0bc6a5bc` | **PENDING** (never claimed) | — | — | 120 | (none) | `append_only_rerun`; the one holdable row (see §4) |

### 1c. The active row `19d3d8e5` in detail

`19d3d8e5` is claimed by **T3**, `att=2`, `timeout_min=418`. Its log shows the phase runner
`q07_multiseed.py` has been **spawned four times**, each restart re-starting the 5-seed sequence
from seed 1 (partial progress is discarded on every reload):

```
2026-09-02T10:25:59Z  spawn q07_multiseed  T10
2026-09-02T11:44:13Z  spawn q07_multiseed  T10
2026-09-03T03:32:28Z  spawn q07_multiseed  T9   <- the "running since 03:32Z" run
2026-09-03T10:33:50Z  spawn q07_multiseed  T3   <- current; released by the T9 idle-reload, re-claimed by T3
```

Current process: `pid=36972`, `started_at_iso=2026-09-03T10:33:50Z`, budget 418 min →
**natural reap ≈ 17:31Z**. It is a *fresh* seed-1 start, not a continuation. On the two prior
XAUUSD attempts each seed consumed its full 90-min cap and returned a 0-byte report; this run is
on the identical trajectory and will almost certainly reap as INFRA_FAIL
(`seeds_invalid_evidence`) like `73aa9110` and `9597dd78`.

### 1d. `seeds_invalid_evidence` decoded (read from the aggregate.json evidence)

- XAUUSD `73aa9110` aggregate (`.../Q07/XAUUSD_DWX/aggregate.json`): `seeds=[42,17,99,7,2026]`,
  `per_seed_trades` all `0`, each `per_seed_detail` entry `exit_code=1`,
  `invalid_reason="invalid_summary:INCOMPLETE_RUNS,TIMEOUT"`, `timeout_sec=5400`,
  `runner_timeout_sec=5520`. Per-seed run start times (UTC) 22:52:28 / 00:24:16 / 01:55:33 /
  03:27:34 / 04:58:58 → **≈ 91-92 min per seed** — i.e. each seed ran to the 5400 s inner cap.
  The seed-42 `summary.json` is explicit: `runs[0].failure="TIMEOUT"`,
  `error="Tester run timed out after 5400 seconds..."`, `report_size_bytes=0`,
  `reason_classes=[TIMEOUT, INCOMPLETE_RUNS, MODEL4_MARKER_REQUIRED]`, `Model=4`.
- XAUUSD `9597dd78` aggregate: seed 99 escalates to `exit_code=124`, `timed_out=true`,
  `timeout_detail="subprocess_timeout_after=5520s"` (hard kill at the runner cap).
- EURUSD `72891249` aggregate (`.../Q07/EURUSD_DWX/aggregate.json`): seed 42 `exit_code=0,
  trades=204`; seed 17 `exit_code=0, trades=207` (after a run_01→run_02 retry, hence the
  `run_1_status=INVALID` flag); seeds 99/7/2026 `exit_code=1, trades=0` — **they never ran**
  (the 216-min outer budget was spent after two ~60-min seeds). This is the decisive contrast:
  **EURUSD seeds complete inside the 90-min cap; the outer budget is what runs out.**

---

## 2. Why the runs time out, and whether a bigger budget can finish

### 2a. Mechanism

Q07 is not one backtest — it is **5 sequential full-history Model-4 real-tick runs** under HARSH
stress, one per seed. Two independent limits apply:

1. **Inner per-seed cap** = 5400 s / 90 min (`q07_multiseed.py --timeout-sec`, default
   `DEFAULT_SEED_TIMEOUT_SEC=5400`; overridable only by the payload key `q07_seed_timeout_sec`
   → `farmctl.py:9414-9421`). None of the 20085 recovery rows set that key, so all used 90 min.
2. **Outer work-item budget** = payload `timeout_min`, workload-scaled from base 120 min
   (`PHASE_ACTIVE_TIMEOUT_MIN["Q07"]=120`) by `_scale_timeout_for_workload` (years × seeds),
   **hard-capped at 4× base = 480 min** (`_TIMEOUT_SCALE_CAP_MULTIPLIER=4`). Observed: EURUSD
   216, XAUUSD 418, WS30 120. This scales the wall budget only — it never raises the inner
   per-seed cap.

Neither the tick-data volume alone, the walk-forward *window count*, nor the news matrix is the
trigger — it is the **product of (per-seed real-tick cost) × (5 seeds)** measured against a
90-min-per-seed / ≤480-min-total budget that was tuned for lighter FX single-symbol EAs.

### 2b. Corroboration: a single gold seed already needs > 90 min

Q05 and Q06 for XAUUSD (single seed 42, same HARSH stress, same 9-year window, Model 4) **passed**
— i.e. one gold seed *does* complete, but it needs the multi-hour Q05/Q06 envelope, not 90 min.
Q07 caps each of its 5 seeds at 90 min, so every gold seed is guillotined mid-run (0-byte report).

### 2c. Could a higher budget plausibly finish? (per symbol)

- **XAUUSD — NO, not with an outer-budget raise alone.** The binding limit is the 90-min inner
  cap; there is **zero** evidence any gold seed ever finished under it (all 3 attempts, all 5
  seeds, 0 valid summaries). To have a chance you must raise **`q07_seed_timeout_sec` to
  ≈ 10800-14400 s (3-4 h/seed)** *and* the outer budget to **≥ ~1000-1200 min** — which exceeds
  the 480-min auto-scale cap, so it cannot come from the normal enqueue path. Even then success
  is uncertain (no completed-seed datapoint at Q07 harshness).
- **WS30 — NO (same class).** Index single-tick (44 GB reservation); the only attempt wedged at
  launch. The pending row's budget is only 120 min — the smallest of the three. Expect XAUUSD-like
  per-seed behaviour once it launches.
- **EURUSD — PLAUSIBLY YES, and only here.** Seeds complete in ~59-75 min each. Five seeds ≈
  300-375 min; a clean run at an outer budget of ~400-480 min (within the auto-scale cap) with the
  default 90-min inner cap would very likely complete all 5 and yield a *real* Q07 verdict.
  Bonus: `q07_multiseed.py` supports `--reuse-report-root`, and `72891249` already holds two
  valid EURUSD seeds (42, 17) — a lineage-bound rerun would only need to run the 3 remaining seeds.
  (Caveat: EURUSD's recent failures were `launch_fault` wedges, which a budget change does not fix.)

---

## 3. What is pending for 20085

- **Live rows (only two):**
  - `0bc6a5bc` — WS30.DWX Q07 — **status `pending`**, unclaimed, budget 120. Holdable.
  - `19d3d8e5` — XAUUSD.DWX Q07 — **status `active`** (claimed by T3), budget 418. Not holdable
    while active (see §4).
- **EURUSD:** no live row — all 5 Q07 attempts are terminal (`done`/`failed`). Because a Q07 row
  already exists for EURUSD, the pump will not re-cascade a new one from the Q06 PASS parent.
- **Recovery markers / `is_recovery_payload`:** these rows do **not** carry an
  `is_recovery_payload` flag (that flag belongs to the 2026-08-12 symbol-cap recovery class). The
  20085 recovery identity is expressed by (a) the EA directory name `...-h4-r1-recovery` and
  (b) `append_only_rerun: true` + `rerun_reason: "CEO 2026-09-02 stranding census: INFRA_FAIL
  without rerun ...; GREEN re-enqueue per Stehende Vollmacht"`. All three live rows were manually
  re-enqueued together on **2026-09-02 10:16Z** (`promotion_source=farmctl_enqueue_backtest_ea`).
- **Existing holds:** none on any 20085 row (`work_item_holds` count = 0).
- **Auto-requeue risk:** none active. `requeue_stranded_infra.py` /
  `requeue_false_progress_reap.py` are not attached to any scheduled task
  (`QM_StrategyFarm_Repair_Hourly` is Disabled), and the false-progress requeuer only accepts
  `reap_reason=NO_FORWARD_PROGRESS` rows with a liveness proof — these rows failed on
  `launch_fault` / `seeds_invalid_evidence`, so they would not qualify anyway. Parking is stable.

---

## 4. Park commands (prepared — CEO runs them)

### 4a. Governed hold for the pending recovery row (WS30 `0bc6a5bc`)

`governed_work_item_hold.py` (a) never changes `status`, (b) requires each target to be exactly
`status=pending, verdict=NULL, claimed_by=NULL` and match ea_id/symbol/phase, (c) takes a SQLite
backup, applies under `BEGIN IMMEDIATE`, and reads back that the row is non-claimable. `--hold-code`
must match `^[A-Z][A-Z0-9_]{2,127}$` (RECOVERY_BUDGET_EXHAUSTED is valid).

**Dry-run (plan) first:**

```
python C:/QM/repo/tools/strategy_farm/governed_work_item_hold.py plan \
  --target 0bc6a5bc-e91c-47d1-9ed1-c7c6bec7d8b7=WS30.DWX \
  --ea-id QM5_20085 \
  --phase Q07 \
  --hold-code RECOVERY_BUDGET_EXHAUSTED \
  --reason "QM5_20085 H4 r1-recovery track parked: Q07 5-seed robustness exceeds the 90-min per-seed inner cap / <=480-min outer budget for tick-heavy symbols (WS30 single-index-tick). All EURUSD/XAUUSD/WS30 Q07 attempts INFRA_FAIL (INCOMPLETE_RUNS,TIMEOUT / launch_fault); not on the 25-path (0 portfolio_candidates). OWNER Vorlage 2026-09-03 09:40Z, Auffangregel 21:35Z." \
  --release-condition "Re-enqueue only after an OWNER-approved Sunday-package Q07 budget revision for tick-heavy symbols: raise q07_seed_timeout_sec to >=10800s AND outer timeout_min above the current 480-min auto-scale cap, then an explicit orchestrator append_only_rerun. Not released by the pump."
```

**Apply (identical flags, `plan` → `apply`):**

```
python C:/QM/repo/tools/strategy_farm/governed_work_item_hold.py apply \
  --target 0bc6a5bc-e91c-47d1-9ed1-c7c6bec7d8b7=WS30.DWX \
  --ea-id QM5_20085 --phase Q07 --hold-code RECOVERY_BUDGET_EXHAUSTED \
  --reason "<same as plan>" --release-condition "<same as plan>"
```

> There is exactly **one** holdable (pending) recovery row. EURUSD has no pending row; XAUUSD's
> only live row is active (§4b). A hold on `0bc6a5bc` + not re-enqueuing EURUSD = the whole track
> parked, because the pump will not re-cascade rows whose phase already exists.

### 4b. The active row `19d3d8e5` (XAUUSD, T3) — recommendation: let it run out

`governed_work_item_hold.py` will **reject** this row (`work_item_precondition ... status=active,
claimed_by=T3`) — holds only park *pending* rows. Options:

1. **Let it run out its 418-min budget (recommended).** Natural reap ≈ 17:31Z → recorded
   INFRA_FAIL, becomes a terminal `failed` row (not pending), needs no hold, and will not
   re-dispatch. Cost: ~7 h of one Q07/Q08 long-run slot that is already committed. Zero action,
   zero risk, fully audited. This finishes ~4 h *before* the 21:35Z Auffangregel, so the slot is
   free either way by then.
2. **Governed abort — no single-command tool exists.** There is **no** governed "abort work item"
   command. `manual_process_kill_evidence.py` only *records* a non-destructive pre-action snapshot
   (it validates the pid is a governed T1-T10 identity, rejects T_Live, and returns an event id to
   cite) — the actual `Stop-Process`/`taskkill` on pid 36972 remains a manual, destructive step.
   Killing a live tester mid-run is out of my authority and out of scope for this packet (the task
   forbids killing processes here); it would need explicit OWNER/CEO action and buys only ~4 h of
   one slot. **Not recommended** unless that slot is needed for a P0 before ~17:30Z.

---

## 5. Alternative option — one last attempt at a larger budget (verified)

**Verification result: `farmctl enqueue-backtest` has NO timeout-override flag.** Its full flag
set is `--review-task-id, --ea, --phase, --from-work-item-id, --append-only-rerun-of,
--rerun-reason, --expected-current-ex5-sha256, --target-symbol/-timeframe/-setfile,
--owner-decision, --q09-anchor-binding-file`. There is **no** `--timeout`, `--budget`,
`--timeout-min`, or `--q07-seed-timeout-sec`. The outer budget (`timeout_min`) and the per-seed
inner cap (`q07_seed_timeout_sec`) are **payload keys with no first-class CLI setter**, and
`backfill_active_timeout.py` only reclassifies verdicts (FAIL→INFRA_FAIL) — it does not set
budgets. So a "600-min one-last-attempt" **cannot be expressed as a single enqueue command**, and
600 > the 480-min auto-scale cap regardless.

Consequences per symbol:

- A plain `enqueue-backtest --phase Q07 --append-only-rerun-of <terminal row> --rerun-reason ...`
  re-derives the **same** ~216/418/120-min budget and the **same** 90-min inner cap → reproduces
  the identical failure. **Do not** re-run on the standard path expecting a different result.
- **The only symbol worth one more attempt is EURUSD**, and only if it can reuse the two valid
  seeds. That requires a lineage-bound rerun with `--reuse-report-root` pointing at `72891249`
  plus the current EX5/MQ5 SHA bindings — but the reuse/bindings flow through the Q07 dispatch
  payload, not through public enqueue flags, so it still needs a payload-level enqueue (orchestrator
  path), not a one-liner. Even a EURUSD PASS does not move the counter today (§6).
- A genuine "raise the Q07 budget for the r1-recovery EA" (per-seed + outer) is a **contract /
  scheduling change** (ROT-adjacent: touches gate budgets and the 480-min cap), requiring an
  OWNER-approved decision + worker reload — precisely the "Sunday-package re-entry with higher
  budget" the Vorlage already defers. It is **not** a GRÜN re-enqueue.

**Recommendation:** do not spend another long-run slot on a standard-path retry. Park now; if the
OWNER wants a real answer for 20085, do it in the Sunday package as: (i) EURUSD reuse-rerun of the
2 valid seeds at ~450-min outer budget (cheap, plausible), and (ii) a decision on whether
tick-heavy XAUUSD/WS30 at Q07 are worth a 3-4h/seed budget class at all.

---

## 6. Counter relevance and cost of each option

**Counter relevance:** 20085 is **not on the path to 25** today. It has 0 rows in
`portfolio_candidates` and 0 in `candidate_qualifications`; its furthest phase anywhere is Q07,
four gates short of the Q14 terminal / Q12-admission that the 25-counter measures. A Q07 PASS on
any 20085 symbol would still need Q08→Q09→Q10→Q11→(Q12) — days of census — before it could touch
the counter. So **none** of the options below changes the 25-count today.

| Option | Action | Slot cost | Counter today | Risk / notes |
|---|---|---|---|---|
| **A — Park (recommended)** | Hold pending WS30 `0bc6a5bc`; let active XAUUSD `19d3d8e5` reap ~17:31Z; do not re-enqueue EURUSD | Frees 1 of 2 Q07/Q08 long-run slots after ~17:31Z; the pending WS30 slot is freed immediately | 0 | Reversible (hold has a release-condition); unblocks the OWNER-priority recompile chains that contend for the same cap |
| **B — Park + abort active now** | A, plus a manual (OWNER/CEO) kill of pid 36972 after a `manual_process_kill_evidence.py` snapshot | Frees the 2nd slot ~4 h earlier (by ~10:40Z vs ~17:31Z) | 0 | Destructive, no one-command tool, out of my authority; only worth it if a P0 needs that slot before ~17:30Z |
| **C — One more standard-path retry** | `enqueue-backtest --append-only-rerun-of` on a Q07 row | Burns a long-run slot for 3.6-7 h | 0 | **Reproduces the same INFRA_FAIL** (same budget, same 90-min inner cap). Not recommended |
| **D — Sunday-package budget revision** | OWNER decision to raise `q07_seed_timeout_sec` (+ outer budget above 480-min cap) for the r1-recovery EA, then rerun (EURUSD reuse-rerun is the cheap first step) | 1 slot for many hours (XAUUSD ≈ 15-20 h; EURUSD reuse ≈ 3-4 h) | 0 today | The Vorlage's intended path; ROT-adjacent (gate budget/cap change); needs worker reload |

**Cost of waiting (Auffangregel 21:35Z):** low. Option A is reversible and the active row reaps on
its own by ~17:31Z, so the concrete cost of *not* deciding before 21:35Z is at most one long-run
slot held by `19d3d8e5` until it reaps (already sunk) plus the pending WS30 row sitting unclaimed
(it is behind the census/priority rows and unlikely to claim a slot before then, but a hold removes
even that tail risk).

**Recommendation:** execute **Option A** now (hold `0bc6a5bc`, let `19d3d8e5` run out), and carry
the "real budget class for r1-recovery Q07" question into the Sunday package (Option D, EURUSD-first).

---

## Appendix — sources

- Live DB (read-only): `work_items`, `work_item_holds`, `portfolio_candidates`,
  `candidate_qualifications` for `ea_id='QM5_20085'`.
- Evidence JSONs: `D:\QM\reports\work_items\{73aa9110,9597dd78,72891249}\QM5_20085\Q07\<SYM>_DWX\aggregate.json`;
  seed-42 `summary.json` under `73aa9110\...\20260818_225228\`.
- Active row log: `D:\QM\strategy_farm\logs\work_item_19d3d8e5-dcae-41e1-9077-a81f99e86758.log`.
- Code: `framework/scripts/q07_multiseed.py` (seeds, `DEFAULT_SEED_TIMEOUT_SEC`, `--reuse-report-root`);
  `framework/registry/multiseed_seeds.json`; `tools/strategy_farm/farmctl.py`
  (`PHASE_ACTIVE_TIMEOUT_MIN`, `_scale_timeout_for_workload`, `_TIMEOUT_SCALE_CAP_MULTIPLIER`,
  Q07 dispatch `q07_seed_timeout_sec`→`--timeout-sec`, `enqueue-backtest` argparse);
  `tools/strategy_farm/longrun_scheduling_policy.py` (`Q07_Q08_LONGRUN_FLEET_CAP=2`);
  `tools/strategy_farm/governed_work_item_hold.py` (hold CLI + preconditions);
  `tools/strategy_farm/{requeue_false_progress_reap,manual_process_kill_evidence,backfill_active_timeout}.py`.


## CEO verification notes (2026-09-03 15:40Z, workflow wf_c2e17931-047)

Verifier could not refute. Non-material: EA dir is the "-h4-r1-recovery"
variant; the XAUUSD reap time (~17:31Z) is a forward projection from
updated_at 10:33:50Z + 418 min. Park action executes at the Auffangregel
(2026-09-03 21:35Z) unless OWNER answers.

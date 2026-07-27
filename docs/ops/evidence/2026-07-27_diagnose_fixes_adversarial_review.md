# Adversarial review of three DIAGNOSE-phase fixes (census follow-up)

Date/time: 2026-07-27 ~16:00-17:15 UTC
Author: Claude (board-advisor worktree), acting as ADVERSARY
Scope authority: `docs/ops/evidence/2026-07-27_factory_loose_ends_census.md` (router task
`621d3c75`). Mandate: assume each diagnosis is wrong; confirm or refute against code,
artifacts and the live system; hunt specifically for the recurring failure of this
codebase — a fix that changes a *label* without changing *behaviour*, or a claim
"verified" by re-reading the author's own document instead of the system.

Constraints honored: no `Factory_OFF/ON`, no reboot/logoff/tscon, T_Live untouched, no
work-item requeue/bulk-mutate, no claim-path change, no live task force-triggered. All
reads were read-only; the one live action was querying scheduled-task state.

Targets named by the task:
1. `docs/ops/evidence/2026-07-27_joint_ea_fidelity_diagnosis.md`
2. `docs/ops/evidence/2026-07-27_interactive_task_selfheal_fix.md`
3. `docs/ops/evidence/2026-07-27_q08_evidence_defects_fix.md`

---

## Verdict summary

| # | Claim under review | Verdict | Severity |
|---|---|---|---|
| 1 | Joint-EA fidelity **diagnosis** | **REFUTED — the deliverable does not exist.** No fidelity diagnosis was written. The 8.5% divergence is undiagnosed. I supply the missing empirical diagnosis below; it *contradicts* the workflow's load-bearing "byte-identical → 1.0" prediction and its "same-symbol sleeves are faithful" claim. | HIGH |
| 2 | Interactive-task self-heal fix | **PARTIALLY CONFIRMED.** Fix 1 (pruner→SYSTEM) confirmed live and G:-safe. Fix 2 (regex) is a correct deterministic parse fix. But the doc's headline — self-heal "verified end-to-end (not asserted)" — is **OVERSTATED**: no successful heal has *ever* been recorded, and the sole cited "transport proof" is a spurious `0/9` reading in a demonstrably healthy factory. | MEDIUM |
| 3 | Q08 NOT_APPLICABLE evidence fix | **CONFIRMED.** The NA→PASS leak the task feared is closed at three independent points; NA never launders a hard fail and never alone yields a PASS. Traced end-to-end; 82/82 unit tests pass. One narrow residual (partial-materialisation resolver) is pre-existing and out of scope. | LOW (fix is sound) |

---

## 1. FIDELITY — REFUTED: there is no diagnosis, and the real mechanism contradicts the workflow

### 1a. The named deliverable does not exist

`docs/ops/evidence/2026-07-27_joint_ea_fidelity_diagnosis.md` is **absent**:

- not on disk (`find docs -iname '*fidelity*'` returns only 2026-07-01/02 and ICT files);
- never committed (`git log --all --oneline -- docs/ops/evidence/2026-07-27_joint_ea_fidelity_diagnosis.md` → empty);
- not staged or untracked (`git status --porcelain | grep -i fidelity` → empty);
- its content is not hiding under another name: `grep` for the representative unmatched
  trade key `1510651994` across all of `docs/` matches **only**
  `2026-07-27_joint_backtest_run_EXECUTED.md` itself.

What exists is the run record, `2026-07-27_joint_backtest_run_EXECUTED.md` (commit
`e808e2d9c`). It correctly **stops** at the fail and explicitly declines to diagnose:
its line 121-124 names the next action as "build/fidelity review of the 107 unmatched
joint trades … under the fixed window, commission, data and comparison contract" and
lists every downstream measurement as `NOT RUN` / `NOT ESTABLISHED`. That is honest,
but it is not a diagnosis. **The task's premises — "if the diagnosis concludes the gap
is fixable", "if it concludes a sleeve cannot be lifted out of its EA" — have no
referent. Neither conclusion was drawn, because no diagnosis was performed.**

Any downstream artifact that assumes the fidelity gap has been explained is building on
absent evidence. This is the census's own rank-9/rank-1 pattern (a verdict with no
evidence behind it) reappearing at the joint-EA layer.

### 1b. The workflow's load-bearing prediction was FALSIFIED, and no one revisited it

The pre-run verdict `2026-07-27_joint_backtest_verdict.md:198-202` asserts that sleeve 0
"opens through the **default** `QM_Entry` path (`explicit_magic=0`), which the build
asserts is byte-identical to standalone 9936 … so a clean `1.0` is the **expected, and
load-bearing, result**." The run returned `0.914741`
(`…run_EXECUTED.md:20`). The load-bearing prediction failed by 8.5 points and **the
verdict doc was never reconciled with that outcome** — a textbook "verified by reading
the author's own document" gap: the confidence lives in the design doc, the
falsification lives in the run doc, and nothing joined them.

### 1c. Independent diagnosis (the missing work), from the two streams directly

Comparator: `tools/strategy_farm/compare_joint_replay.py`. Its pairing key is the
**exact integer** `(entry_time, close_time)` (`:46-48`), then net/volume within a
half-cent/half-step tolerance (`:81-84`). Streams:
`D:/QM/reports/joint_20180/harvest/20180_s0.jsonl` (joint replay, 1255 closed) vs
`D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/9936_USDJPY_DWX.jsonl` (gated,
1252 closed). Reproducing the comparator and then dissecting the residual:

- **1148 / 1252 trades are bit-identical on entry AND close AND net AND volume.** Two
  runs cannot agree to the cent on 1148 net values under different commission, tick model
  or timeframe — so the reference stream and the replay share data/model/commission.
  **This rules out the "wrong comparator reference / different tester model" artifact**
  the task asked me to check for.
- Of the 107 unmatched joint trades, **78 share the SAME `entry_time` AND the SAME
  `volume` as an unmatched gated trade, differing only in the close** (exit). Of those,
  **77 closed LATER in the joint run and 0 earlier** — a one-directional, systematic
  exit lag, not noise. Example (first reported mismatch):
  `entry=1510651994` — gated closes `1510665762` (net -579.92), joint closes
  `1510670955` (net -1022.03), **same volume 6.6**; the joint run held the identical
  position ~1.4 h longer and lost nearly 2×.
- The remaining **29 unmatched joint trades have no gated `entry_time` at all** (net
  +3 vs the gated book), consistent with the exit lag cascading into altered subsequent
  entry eligibility.

**Mechanism (established, not the doc's — there is no doc):** the joint EA reproduces
9936's **entry** path exactly (100% of matched entries, and all 78 divergent trades share
entry time+size) but **diverges on the exit/position-management path**, systematically
holding positions longer. This is a *behavioural* divergence, not a comparator artifact
and not a data mismatch.

### 1d. Consequences — two workflow claims are contradicted by this evidence

1. **"Same-symbol host sleeves are faithful; C1-C4 do not arise" is FALSE for the exit
   path.** `…verdict.md:44-52,67,82-86` argues the surviving USDJPY-only instrument is
   faithful because every position moves on a host tick. The entry path is indeed
   faithful — but the exit is not: `77/77` divergent trades close *later* inside the
   joint wrapper. The design's fidelity reasoning covered entry fills and missed exit
   cadence, exactly the class of blind spot the verdict itself flagged for the *dropped*
   gold sleeve (`…verdict.md:218-223`) — and it recurs in the sleeve that was kept.
2. **The "cannot lift a sleeve out of its EA" claim would be UNSUPPORTED — but so would
   "fully fixable".** The entry logic lifts out perfectly; only the exit wrapper drifts.
   That is a *narrow, investigable* defect (candidate causes, in order: a session-close /
   `order_cancel_hour` GMT offset applied differently under the joint OnInit; a trailing-
   stop evaluated at a different cadence; a per-position vs per-symbol management scope).
   It is neither proof a sleeve is un-liftable nor proof the gap is trivially fixable. The
   correct DIAGNOSE output is: *entries faithful, exits systematically late, root cause in
   the exit-management wrapper — one bug class, not a fundamental barrier.*

**Also note a comparator sharp edge for whoever picks this up:** the exact-integer close
key gives **zero** time tolerance, so a 39-second exit shift (seen in one example:
joint `1532019169` vs gated `1532019130`, net 247.71 vs 292.58) scores as fully
unmatched. The key correctly flags *that* something differs, but it conflates a
1-second rounding drift with a 1.4-hour hold difference. Any real diagnosis must
separate "key differs by a rounding tick" from "economically different exit" before
quantifying the gap — the current tool reports only the union.

**FIDELITY verdict: REFUTED (no diagnosis exists). Failure scenario if left as-is:** a
downstream plan cites "fidelity gap → sleeves can't be shared" or "fidelity gap is
fixable" as settled; both are unearned. The real, evidenced finding — a systematic
exit-timing wrapper divergence on an otherwise-faithful entry path — sits unwritten in
two streams on disk.

---

## 2. SELF-HEALING — PARTIALLY CONFIRMED; the "verified end-to-end" headline is overstated

### 2a. Fix 1 (pruner → SYSTEM) — CONFIRMED live, and G:-safe

`Get-ScheduledTaskInfo` at review time:
`QM_WorkItemLogPruner_Daily_0310` is now `principal=SYSTEM/ServiceAccount`,
`LastTaskResult=0x00000000`, `LastRunTime=2026-07-27 15:45`. Under the old Interactive
principal it was stuck `0x800710E0`. **The task now actually executes.**

G:-safety (the task's explicit check — "nothing moved to SYSTEM that needs the G: drive"):
`prune_workitem_logs.py` touches only `D:\QM\strategy_farm\state\farm_state.sqlite`
(`:31-34`) and `*.log` files under `D:\QM\reports` (`:33`, `:174-179`, `:206`), and it
resolves-and-refuses any path escaping the reports root (`:44-58`, `:100-102`). No `G:`,
no `My Drive`, no DPAPI, no `terminal64`. SYSTEM can reach every path it uses.
**Confirmed: the one task moved to SYSTEM has no G: dependency, and a no-op run (nothing
aged past the cutoff) is a legitimate success, not a masked failure.**

Live state of the other 7 tasks matches the doc's disposition: `AgyGovernor`,
`WorkerDedupe`, `Live_MT5_SessionSupervisor`, `GeminiOrchestration` remain
`Interactive / 0x800710E0` — i.e. **only 1 of 8 tasks was actually repaired**; the
other 7 stay stuck by design (DPAPI / G: / desktop / T_Live), correctly deferred to
OWNER. The doc is honest that self-heal therefore rests on the SYSTEM *watchdog* path,
not on these tasks.

### 2b. Fix 2 (watchdog regex) — the parse fix is real, but is NOT the same as "heals"

The regex change is genuine and correct:
- `factory_watchdog.ps1:87` now matches `LAUNCHED pid=\d+ into (?:\w+ )?session (\d+)`;
  `tester_cache_purge.ps1:62-65` carries the identical fix.
- The launcher really emits the word "console":
  `run_in_console_session.ps1:158` → `"LAUNCHED pid=$($pi.dwProcessId) into console
  session $sid …"`. The old pattern `into (?:interactive )?session` cannot match
  "console"; the new one does. Deterministically verified.
- The post-spawn verification block it re-enables is not a stub: `:100-111` counts live
  `terminal_worker.py` processes, throws on wrong-session workers, and throws
  `"dedupe launch made no progress"` if `workers_after <= workers_before`. So *when a
  heal fires*, it does verify recovery.

**But the doc's §4 heading — "Self-heal path verified end-to-end (not asserted)" — is
contradicted by the log and by the doc's own body.** Reading
`D:/QM/reports/state/factory_watchdog.jsonl` (500 records, 2026-07-26T18:16 →
2026-07-27T15:00):

- **`worker_dedupe_heal` count across the entire log: ZERO.** No successful heal has
  ever been recorded, before or after the fix.
- The **only** heal attempt on record is a single `heal_failed` at `2026-07-26T19:15:10Z`
  ("workers=0/9 … no session evidence … LAUNCHED pid=11668 into console session 3").
  The doc cites "18:00 **and** 19:15"; the log's first record is 18:16:40, so the 18:00
  citation has no backing record in the current file.
- Crucially, that 19:15 trigger was almost certainly **spurious**. Surrounding records:
  `19:10 noop_healthy workers=9/9`, `19:15 workers=0/9` (heal), `19:20 noop_healthy
  workers=9/9` — while `pending` drained monotonically (2162→2158) and
  `activeRecentProgress=9` throughout. A genuine total worker death cannot coexist with
  uninterrupted work progress and a full recovery one scan later; the `0/9` is a
  point-in-time process-scan miss. So the event the doc leans on as "transport proof …
  nine worker PIDs spawned … the factory physically healed" **did not heal a real
  shortage** — the nine workers at 19:20 are the same nine the scan missed at 19:15, and
  the verification block never ran (the old regex threw first).

The composition the doc offers (transport-log × deterministic-regex × a live watchdog
cycle that *guarded*) is logically reasonable, and the author is explicit that a real
shortage "was not manufactured" (correctly — the constraints forbid killing workers).
But that admission is precisely why the section title is too strong: **the end-to-end
heal — real shortage detected → workers respawned → recovery verified → clean
`worker_dedupe_heal` — has never been observed.** The fix demonstrably makes the *parse*
correct; it does not demonstrate the *heal*. This is the task's exact concern ("a task
that runs but whose payload silently no-ops is the same defect"): here the payload
(post-spawn verification path) is unexercised in production, and the one time the
transport ran, it ran against a phantom.

Blast radius is limited: the spawn happens at `:72-74` *before* the regex check either
way, so the fix does not change whether workers are spawned — only whether the outcome
is reported as `worker_dedupe_heal` vs `heal_failed` and whether verification runs. So
this is an overstated-verification finding, not a broken-fix finding.

### 2c. Residual the doc discloses but the headline obscures

The catastrophic escalation still queues: `factory_watchdog.ps1:1064` and `:1168`
`Start-ScheduledTask QM_StrategyFarm_FactoryON_AtLogon`, which is InteractiveToken and
would return `0x800710E0` while the session is disconnected — the same death class this
task set out to cure. The doc's §5 residual-gap paragraph states this plainly; the §4
title "verified end-to-end" does not carry the caveat. **Self-heal is restored for the
common worker-shortage case and remains broken for the full-reset/wedge case.**

**SELF-HEALING verdict: PARTIALLY CONFIRMED. Failure scenario:** a real mass-worker
death occurs; the fixed parse now lets the watchdog *report* and *verify* a heal — a
genuine improvement — but this path has never actually run, so a latent defect in the
verification/spawn composition would surface only on first real use; and if instead the
factory truly wedges (dispatch stall), escalation still delegates to an InteractiveToken
task that queues and never fires.

---

## 3. Q08 EVIDENCE — CONFIRMED: NA cannot leak into an unearned PASS

The task's core worry: a sub-gate that reports NOT-APPLICABLE instead of INVALID must
not thereby *approve* the property it could not evaluate. I traced the whole
verdict-combination contract and the two emission points. The boundary holds at three
independent layers.

### 3a. Emission is tightly gated to a genuinely structural determination

- **8.5 (`sub_8_5_neighborhood.py`).** NA requires a **triple** condition (`:83-86`):
  `not perturbs` AND `structurally_inapplicable is True` AND
  `evidence_status == "INVALID_NO_PERTURBABLE_PARAMS"`. Two failure modes are excluded
  *before* the NA check: a **missing artifact** returns INVALID at `:45-49`
  (`perturbations_runner_output_missing`), and a **degenerate 0-trade baseline** returns
  INVALID at `:68-73`. A bare empty-perturbation payload with no structural flag falls
  through to `:100-104` INVALID (`no_perturbations_tested_vacuous_pass`). So the census's
  94 `artifact_missing` cases and the empty-perturbation cases **stay INVALID → tooling →
  INFRA_FAIL**, never NA.
- **8.7 (`sub_8_7_pbo.py`).** NA is emitted **only** for meta `status == "INVALID_NA"`
  (`:81-89`). A plain meta INVALID and the fallback `insufficient_distinct_configs:got=N`
  path (`:90-97`, `:103-111`) stay INVALID. So the census's 81 `got=0` cases **stay
  INVALID**, never NA.
- **The single authority** both sub-gates trust is the runner's `structurally_inapplicable`
  flag, and its derivation is sound: `q08_5_neighborhood_runner.py:1023-1028` sets it to
  `not eligible AND baseline_is_structurally_inapplicable(...)`, and the helper (`:272`)
  returns `strategy_params > 0 AND perturbable == 0` over the **full baseline inventory**.
  The `strategy_params > 0` guard is load-bearing: the `11124` empty-template resolver
  defect (a setfile with the strategy header but **zero** params) yields
  `strategy_params == 0` → helper returns **False** → not NA. So the mis-resolved-setfile
  class stays a blocking INVALID, exactly as the doc claims — a card only earns NA if its
  setfile carries ≥1 strategy param and **all** of them are fixed/categorical.

### 3b. Even a valid NA cannot manufacture a PASS

`aggregate.py:_aggregate_verdict`:
- NA is classified with **no weight** (`:1458-1460`), inside the DL-082 §3c pass
  allowance (`_label_within_pass_allowance:132`, NA listed alongside PASS/INFORMATIONAL/
  LOW_SAMPLE). The EDGE_SOFT allowance is scoped to the frequency trio + MC shuffle only
  (`ALLOWANCE_SOFT_GATES = ("8.4","8.6","8.10","8.11")`, `:113`) — no merit hard gate is
  in it.
- A hard fail **dominates** and returns before any PASS path (`:1548-1549`), so NA can
  never launder a real EDGE_HARD/PBO/net-PF/cost breach into a PASS.
- The PASS path still requires **`real_quality_passes >= DL077_MIN_QUALITY_PASSES`**
  (`=1`, `:100`; check at `:1588-1593`), counting only non-trivial gates that actually
  passed (excludes 8.1/8.3). So two NA gates plus trivia cannot reach PASS — at least one
  genuine quality gate must pass on merit, and profitability must be computable and ≥1.0.

For a *genuinely* fixed-parameter strategy this is the correct semantics, not a bypass:
there is no parameter-selection surface, so PBO (selection overfitting) and the ±10%
neighborhood (parameter sensitivity) are undefined by construction — NA removes two
inapplicable gates rather than lowering the bar, and the EA is then judged on the same
merit gates + Q09 portfolio track as everyone else. Before the fix these EAs were
INFRA_FAIL (stuck forever); after, they get a real verdict — which is the census's
stated goal.

### 3c. Tests actually exercise the guards

`framework/scripts/tests/test_q08_davey_subgates.py`: **82 passed** (matches the doc).
The nine leak-relevant guards
(`…do_not_block_clean_pass`, `…never_rescues_a_genuine_hard_fail`,
`…empty_perturbations_without_structural_flag_stays_invalid`,
`…pbo_meta_plain_invalid_stays_invalid`, `…baseline_is_structurally_inapplicable_helper`,
and the NA-positive cases) **all pass** when run in isolation. Because no Q08 row was
re-run, no NA verdict exists in the live DB yet — consistent with the doc's "no
re-run" scope; the fix is code-forward.

### 3d. Residual (pre-existing, out of scope)

A narrow leak survives only if a resolver hands the runner a **partially** materialised
setfile — ≥1 fixed param present, the perturbable ones missing — which would satisfy
`strategy_params > 0 AND perturbable == 0` and mis-earn NA. The doc scopes the
`_guess_baseline_setfile` resolver fix out (§3) and relies on the upstream sha-lineage
gate to reject a wrong pick. Whether that fully closes the partial-materialisation case
is **NOT ESTABLISHED**, but it is a pre-existing resolver concern, not a defect
introduced by the NA change.

**Q08 verdict: CONFIRMED. Failure scenario searched for and NOT found:** an EA reaching
PASS while a real (non-structural) robustness property went unevaluated — blocked at the
emission gate (artifact_missing/insufficient_configs stay INVALID), at the structural
guard (`strategy_params > 0`), and at the aggregate (`real_quality_passes >= 1`, hard
dominates).

---

## 4. The recurring failure, applied to each (task item 4)

- **FIDELITY — label-without-behaviour / verified-by-own-doc: PRESENT in the worst form.**
  The "diagnosis" does not exist; the pre-run doc *predicted* 1.0 and was never
  reconciled with the 0.914741 fail. The divergence is real (streams, not prose) and
  unwritten.
- **SELF-HEALING — present, contained.** The regex fix changes real behaviour (parse →
  verification path), so it is not a pure label change. But the *evidentiary* framing
  ("verified end-to-end") is asserted from a spurious event and a guarded run, not from an
  observed heal — the "verified by re-reading my own reasoning" pattern, at the
  verification layer rather than the fix layer.
- **Q08 — absent.** This fix changes behaviour (NA is a new, weightless, non-blocking
  status with a distinct downstream path), the boundary is enforced in code at three
  points, and the claims are backed by executed unit tests I re-ran, not by narration.

---

## 5. Recommended next steps (no capacity/requeue action taken)

1. **Write the actual fidelity diagnosis.** The evidence is already on disk: entries
   faithful, exits systematically late (77/77), one wrapper bug class. Diff the joint
   sleeve-0 exit path (session-close hour / cancel hour / trailing cadence under the
   joint OnInit) against standalone 9936 on the 78 same-entry-late-exit trades. Do **not**
   let any downstream doc treat the gap as explained or as proof about sleeve-sharing
   until this exists.
2. **Down-rank the self-heal §4 title** from "verified end-to-end" to "parse fix
   verified; heal path unexercised — first real worker-death will be the first true
   test", and track the InteractiveToken escalation (`:1064,:1168`) as the remaining
   self-heal gap.
3. **Q08 fix is admissible as-is.** Optionally file the partial-materialisation resolver
   residual (§3d) as a separate build-lane ticket.

## Evidence index

- Absence: `git log --all -- docs/ops/evidence/2026-07-27_joint_ea_fidelity_diagnosis.md`
  (empty); `git status --porcelain`; `find docs -iname '*fidelity*'`.
- Fidelity streams: `D:/QM/reports/joint_20180/harvest/20180_s0.jsonl`,
  `D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/9936_USDJPY_DWX.jsonl`;
  comparator `tools/strategy_farm/compare_joint_replay.py:46-48,81-84`; run record
  `docs/ops/evidence/2026-07-27_joint_backtest_run_EXECUTED.md:20,121-124`; pre-run
  prediction `…_joint_backtest_verdict.md:44-52,198-202`.
- Self-heal: live `Get-ScheduledTaskInfo`; `prune_workitem_logs.py:31-58,174-206`;
  `factory_watchdog.ps1:87,100-111,1064,1168`; `tester_cache_purge.ps1:62-65`;
  `run_in_console_session.ps1:158`; `D:/QM/reports/state/factory_watchdog.jsonl`
  (0 `worker_dedupe_heal`, sole `heal_failed` 2026-07-26T19:15, spurious-0/9 trajectory).
- Q08: `aggregate.py:100,113,116-133,1458-1460,1548-1549,1588-1593,1601-1607`;
  `sub_8_5_neighborhood.py:45-49,68-73,83-95,100-104`;
  `sub_8_7_pbo.py:81-97,103-111`;
  `q08_5_neighborhood_runner.py:272,1013-1028`;
  `pytest framework/scripts/tests/test_q08_davey_subgates.py` → 82 passed.

# OWNER DECISION PACKAGE — Follow-ups D4 / D5 / Wiki-GREEN clarification (2026-09-16)

Raised by execution of the approved D1–D3 package. Three small items, each independently decidable. All evidence self-contained; paths are supporting references only.

---

## DECISION 4 — QM5_11731 FORCE-REBUILD / SOURCE-REPAIR AUTHORITY

**Decision required:** Ratify a force-rebuild (or source-repair) authority for QM5_11731 so its EURUSD-M5 pilot Q02 can be enqueued, or decline and leave it excluded.

**Affected scope:** QM5_11731 (tc-m5-s20-ema3-bb-macd) only. Exclusion file `D:\QM\strategy_farm\state\requeue_excluded_eas.txt`.

**Current blocker:** The single-symbol pilot path requires `enqueue-compile`, which fail-closes with `EX5_ALREADY_PRESENT` (ex5 git-tracked since 2026-08-04; force-rebuild allowlists name other programs, not this EA) and `BUILD_TASK_EXISTS` (its build task is done; binding requires an open one). No waiver names 11731. Documented: `docs/ops/evidence/2026-09-16_requeue_lifts/QM5_11731_D2B_continuation_RECEIPT.md`.

**Why OWNER authority is required:** Both refusing guards are fail-closed OWNER-class protections against rebuilding bound artifacts; only OWNER (or Fable with OWNER standing) can register a new exception.

**Evidence:** EA is fully admissible (G0 APPROVE_FOR_BACKTEST, Q01 smoke passed, artifacts clean, zero work items ever; the 2026-07 enqueue died `no_work_items_created` — infra, not economics). The historical May-2026 exclusion reason (M5 without DWX history 2017–2022) is obsolete: 95,540 done M5 work items fleet-wide; EURUSD.DWX history 2017–2025 on disk.

**If APPROVED:** register the authority (force-rebuild allowlist entry naming 11731, or source-repair authority under OWNER-DEC-REQUEUE-LIFT-20260916) → `enqueue-compile --apply` → governed local compile (MetaEditor — provider-mandate determination: codex is NOT contractually required) → `intake-first-q02 --apply` = EURUSD.DWX M5 canary ONLY → pilot checks a–e → governed fanout to GBPUSD/USDCHF/USDJPY only if clean. If the EURUSD canary fails on setup/data: re-park, diagnose, no auto-retry; economic FAIL is a legitimate result.

**If DECLINED:** EA stays excluded; one admissible Q02 foregone.

**Risks:** rebuilding a bound ex5 (contained: prior ex5 bytes are git-history-preserved; the rebuild is hash-recorded); pilot cost (one M5 Q02). Decline risk: negligible.

**Rollback:** re-add the exclusion line (hash-bound receipt pattern already established).

**Kimi recommendation:** `APPROVE WITH CONDITIONS` — (1) authority names QM5_11731 only; (2) EURUSD-only first enqueue, fanout gated on the D2B pilot checks; (3) exclusion lift happens only after the compile row exists (pump never sees the EA unprotected).

**Post-approval execution:** mechanical (~30 min), exact commands staged in the receipt. No further OWNER action.

---

## DECISION 5 — QM5_41478 RE-COMPILE AUTHORITY

**Decision required:** Ratify the re-compile of QM5_41478's repaired source (one behavior-preserving line: `ZeroMemory(req);` fixing `EA_TRADE_REQUEST_UNINITIALIZED`), via force-rebuild entry or by registering OWNER-DEC-Q12-SIBLING-41478-20260916 as the EA's source-repair authority.

**Affected scope:** QM5_41478 grimes-complex-pb-opt (measurement sibling of QM5_10911) only. Parent untouched.

**Current blocker:** The governed compile ran 0 errors/0 warnings and the deterministic `build_gate_hardening` gate fail-closed on the uninitialized-request defect. The fix is committed (`89980c99cb`, source `b0771317…`) but re-compiling has no legitimate path: fresh enqueue refuses `WORK_ITEMS_EXIST_AT_APPLY`; repair-successor refuses `BUILD_TASK_BINDING_NOT_REQUESTED` (41478 has no build_ea task); force-rebuild allowlists exclude it. Receipt: `docs/ops/evidence/2026-09-16_seal_41478/RECEIPT.md`.

**Why OWNER authority is required:** Same fail-closed guard class as D4; the repair authority must be ratified, not assumed.

**Evidence:** Everything up to the compile is DONE and verified — seal (`798d2eeb→7d6b37e6`, sibling-only scope recorded), allocation (magic 414780000, `9784505ad8`), promotion (`577907f208`), readiness green; the service dry-run's refusal flipped to "no COMPILE_OK receipt" proving the seal chain is fully recognized. The single-line fix is behavior-preserving (the struct's default constructor already zero-initializes; the gate now passes 0 findings, guardrails PASS).

**If APPROVED:** re-compile (governed local MetaEditor lane) → COMPILE_OK receipt → `farmctl service-dl089-matrix --work-item-id 96239586-47c0-5fe2-8ef5-3d29910cc47c --apply` → Q02 seed → 1,085-cell census → Q13 → Q14. Unlocks one of the three pairs "3 short of Q14."

**If DECLINED:** 41478 stays sealed-but-uncompiled; the 10911/GDAXI pair stays short of Q14.

**Risks:** re-compile stamps a new ex5 hash (contained: hash-bound everywhere; prior attempt uncommitted per EX5_COMMIT_GUARD); census cost is bounded and resource-scheduled.

**Rollback:** retire the sibling's registry rows via the governed allocator retirement path; parent evidence untouched.

**Kimi recommendation:** `APPROVE`, no conditions (the defect + fix are deterministic-gate-verified; the scope is one EA).

**Post-approval execution:** mechanical (~20 min). No further OWNER action.

---

## CLARIFICATION 6 — D1 BATCH-2 WIKI-GREEN GATE (not a new authority)

**Question:** D1's batch-2 condition requires "Strategy Wiki sync GREEN." A full rebuild now yields AMBER solely from `stale=1285` — a pre-existing ambient REJECTED-class backlog (drift-definition matter, predates D1). D1-attributable drift is zero: all 16 cohort cards' nodes FRESH, missing=0, and the one transient missing node (QM5_41480) resolved on rebuild.

**Ask:** Is the intended bar (a) literal GREEN — batch 2 waits until the ambient 1285-node backlog is dispositioned (a separate hygiene program, possibly days), or (b) "zero D1-attributable drift" — batch 2 proceeds now with the ambient backlog tracked separately?

**Kimi recommendation:** (b), with the ambient backlog registered as its own tracked item. Rationale: the gate's purpose (detect amendment-induced wiki corruption) is fully satisfied by the per-cohort FRESH proof; holding batch 2 hostage to an unrelated backlog delays up to 8 crisis-gate candidates for no integrity gain.

---

# Legacy COMPILE_EA "unclaimable" rows — hygiene audit (2026-09-03)

**Author:** Claude (board-advisor worktree) · **Session:** https://claude.ai/code/session_018TXU36R3wPUNEzGHtsFZpM
**DB read:** `file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro` (strictly read-only; no writes to the farm DB, no enqueue/hold/release/supersede/restart, no commands executed)
**Worktree merge:** `git merge --ff-only agents/board-advisor` → fast-forward `a92cda60fe..f5bd0a08ff`. HEAD == `agents/board-advisor` == **`f5bd0a08ff3bbda5c159ede09f1ca552b694b289`**.

---

## Headline finding (overturns the stated hypothesis)

The prompt's premise — *"pending, attempt_count 0, NO active hold, therefore a **release candidate** via `release_compile_wave.py`"* — does **not** hold. All 18 listed rows are **already `work_item_supersedes`-superseded**. That, not a missing release binding, is why they are never claimed.

Per row, the three independently true facts:

1. **Their activation hold is already inactive** (`work_item_holds.active = 0`, released 2026-08-25T20:54:22Z for 17 of them, 2026-09-02T06:05:04Z for `e313ef05`). So "no active hold" is correct — but it is not what blocks them, and it means `release_compile_wave.py` has **nothing to release**.
2. **Each has a `work_item_supersedes` row** pointing at a newer, current-source COMPILE_EA row. This is the predicate that removes them from every claim path.
3. **A newer COMPILE_EA row for the same `ea_id` exists** (the superseding row), and in 16/18 cases it has already compiled (`verdict=COMPILE_OK`).

**Classification: all 18 = (a) dead / identity-superseded. Zero (b) release candidates. Zero (c) unclear.**

**Recommended action for all 18: NONE.** They are correctly non-claimable and immutable-by-design ("A pending row may remain immutable while its replacement proceeds" — farmctl.py:2459-2461). Neither of the CEO commands in the task template should be run against them:
- `release_compile_wave.py --work-item-id <id>` is a **provable no-op** — its `inspect()` requires `h.active=1` (release_compile_wave.py:88-89); every hold here is `active=0`, so `plan["release"]` is empty and `apply_wave` returns `applied:0` (release_compile_wave.py:399-400). Even if a hold were re-armed, the supersede row would still exclude the row.
- `work_item_supersedes.py record --apply <id>` is **redundant and harmful to provenance** — the supersede already exists with full evidence. Because the table PK is `(work_item_id, source_encoding)` (work_item_supersedes.py:47-56) and `cmd_record` writes `source_encoding='operator:record'` (work_item_supersedes.py:270), a re-record would **insert a second, generic supersede row** alongside the accurate one rather than being a clean idempotent no-op.

**One genuinely actionable item, out of the 18-row scope:** the QM5_41285 chain. `e313ef05` (in the list) was superseded on 2026-09-02 by **`e23cfbc8`**, which *is* a live release candidate — pending, `bound_build_task_id=5589bbaa-7b6c-433a-ae64-fad387bca3fc`, and still under an **active** `COMPILE_EA_WORKER_ROLLOUT_PENDING` hold. See the last section.

---

## Why they are not claimable — predicate analysis (with file:line)

The one selector every claimant uses is `farmctl.pending_claim_order_sql()` (terminal_worker.py:572-579 → farmctl.py:2153). Its `WHERE` clause excludes a pending row when **any** of these holds; for all 18 rows the **superseded** clause is the operative one:

| Guard | Location | Status for these 18 |
|---|---|---|
| `status='pending'` | farmctl.py:2452 | pass (all pending) |
| active hold `NOT EXISTS` | farmctl.py:2455-2458 | **pass** — holds are `active=0`, so this does NOT exclude them |
| **superseded `NOT EXISTS`** | **farmctl.py:2462-2465** | **FAIL — a `work_item_supersedes` row exists → excluded** |
| poison-pill `NOT EXISTS` | farmctl.py:2466-2470 | pass (no active quarantine for any ea) |

The same superseded-row exclusion is enforced at two further layers, so no restart-surviving worker and no RAM-latch path can revive them:

- **Claim UPDATE guard** (terminal_worker.py): the pre-claim `blocked` probe (terminal_worker.py:3573-3587) and the atomic `UPDATE ... WHERE ... NOT EXISTS (SELECT 1 FROM work_item_supersedes s ...)` (terminal_worker.py:3595-3601) both re-check supersede inside `BEGIN IMMEDIATE`.
- **RAM-latch COMPILE_EA bypass** `_ram_latch_compile_bypass_available` (terminal_worker.py:2609-2637) — the "compile-only under RAM pressure" latch — also filters on `NOT EXISTS work_item_supersedes` (terminal_worker.py:2631-2634).
- **DB trigger** `trg_work_items_superseded_no_activate` (work_item_supersedes.py:65-72): a `BEFORE UPDATE OF status` trigger that `RAISE(IGNORE)`s any pending→active transition on a superseded row. Hard floor even against a pre-rollout claimant.

Contrast — why *today's* released rows claim in seconds: `release_compile_wave.py` flips the hold to `active=0` on a row that has **no** supersede entry (it never writes a supersede). With no hold and no supersede, that row passes farmctl.py:2455 and 2462 and is claimed. The 18 legacy rows have the hold cleared **but** carry a supersede entry, so they stay excluded.

---

## Per-row table

Failing predicate is identical for every row: **`work_item_supersedes` EXISTS** → excluded at farmctl.py:2462-2465 (and terminal_worker.py:2631 / 3595; trigger work_item_supersedes.py:65). All 18: `phase=COMPILE_EA`, `kind=compile`, `status=pending`, `claimed_by=NULL`, `attempt_count=0`, hold `COMPILE_EA_WORKER_ROLLOUT_PENDING` `active=0`. EA dir present for all 18.

| # | id (short) | ea_id | created (UTC) | superseded_by → state | class | recommended command |
|---|---|---|---|---|---|---|
| 1 | d646713d | QM5_41097 | 2026-08-21T21:24 | 59e863a3 → done/**COMPILE_OK** | (a) dead | none — already superseded 2026-08-25T20:54:22Z |
| 2 | 1cab0ed2 | QM5_11465 | 2026-08-22T05:23 | f892cd23 → done/**COMPILE_OK** (also newer 1d469fa4 done/OK) | (a) dead | none — already superseded |
| 3 | a44c3c83 | QM5_12954 | 2026-08-22T05:23 | e89f1b30 → done/**COMPILE_OK** | (a) dead | none — already superseded |
| 4 | f29ebccb | QM5_41113 | 2026-08-22T13:50 | d62f097c → done/**COMPILE_OK** | (a) dead | none — already superseded |
| 5 | 3c893190 | QM5_13128 | 2026-08-22T14:15 | ae6f09a7 → failed/**COMPILE_FAIL** ⚠ | (a) dead | none for this row — but EA has no OK compile (see ⚠ below) |
| 6 | 96d25526 | QM5_41123 | 2026-08-23T02:16 | f1c50421 → done/**COMPILE_OK** | (a) dead | none — already superseded |
| 7 | 24e3a252 | QM5_1567 | 2026-08-23T10:14 | 92664d37 → done/**COMPILE_OK** | (a) dead | none — already superseded |
| 8 | 73dc8eaf | QM5_41130 | 2026-08-23T11:01 | 0edf3c6a → done/**COMPILE_OK** | (a) dead | none — already superseded |
| 9 | 19504c2f | QM5_41131 | 2026-08-23T12:28 | 34785097 → done/**COMPILE_OK** | (a) dead | none — already superseded |
| 10 | 690cf433 | QM5_41132 | 2026-08-23T15:16 | bdae4d54 → done/**COMPILE_OK** | (a) dead | none — already superseded |
| 11 | 1fb58c79 | QM5_41133 | 2026-08-23T18:13 | 56b413ef → done/**COMPILE_OK** | (a) dead | none — already superseded |
| 12 | 4fa76159 | QM5_36002 | 2026-08-24T00:28 | ef5a170e → done/**COMPILE_OK** (also newer db055f7e done/OK) | (a) dead | none — already superseded |
| 13 | 979e7903 | QM5_41136 | 2026-08-24T07:16 | bc05a582 → done/**COMPILE_OK** | (a) dead | none — already superseded |
| 14 | 73d3e2a5 | QM5_35005 | 2026-08-24T11:40 | 0ca4936f → done/**COMPILE_OK** | (a) dead | none — already superseded |
| 15 | bb657945 | QM5_9914 | 2026-08-24T13:53 | 97d9e440 → done/**COMPILE_OK** | (a) dead | none — already superseded |
| 16 | 9230bf4d | QM5_9730 | 2026-08-24T14:08 | cf00f80b → failed/**COMPILE_FAIL** ⚠ | (a) dead | none for this row — but EA has no OK compile (see ⚠ below) |
| 17 | 5f4c9079 | QM5_9909 | 2026-08-24T14:34 | 4ef0946a → done/**COMPILE_OK** | (a) dead | none — already superseded |
| 18 | e313ef05 | QM5_41285 | 2026-09-02T05:46 | e23cfbc8 → **pending (held, task-bound)** | (a) dead | none for this row — act on successor e23cfbc8 (below) |

Supersede provenance for rows 1-17: `source_encoding=operator:compile-rollout-stale-source/v1`, `recorded_by=codex`, `recorded_at=2026-08-25T20:54:22Z`, `evidence_path=docs/ops/evidence/2026-08-25_e9944090_compile_rollout_reconciliation.md`, reason "stale COMPILE_EA source superseded by current-source COMPILE_EA … under router task e9944090-1e0f-4dea-af90-e74f8079d1c8". The superseding rows were minted under router ops-issue `e9944090` (14 rows, 2026-08-25T20:53:44Z) or `50467e7e` (4 rows: 41113/41123/41130/41131/41132, 2026-08-23T17:14:00Z), all as `append_only_source_repair=True` current-source recompiles.

Row 18 provenance: `source_encoding=operator:qm5-41285-unbound-compile-retry/v1`, `recorded_by=codex`, `recorded_at=2026-09-02T07:29:52Z`, reason `COMPILE_ENQUEUED_BEFORE_BUILD_TASK_BINDING`, `evidence_path=artifacts/qm5_41285_unbound_compile_retry_20260902.json`.

### (b)/(c) confirmations
Because **zero** of the 18 are class (b), the task's per-(b) checklist (EA dir + card in both `cards_approved` mirrors + registry magic + no newer COMPILE_EA row) has no in-scope target. For completeness it was inverted and applied as a *dead* test: every row **does** have a newer COMPILE_EA row for its ea (the superseding row and, for 3 eas, an even-newer one), which is exactly the "duplicate newer row" dead-signal. No row is class (c).

---

## ⚠ Two EAs whose current-source recompile FAILED (separate follow-up, NOT these rows)

For **QM5_13128** (row 5, successor `ae6f09a7`) and **QM5_9730** (row 16, successor `cf00f80b`), the newer current-source COMPILE_EA row is `failed/COMPILE_FAIL`, and every earlier attempt for those eas also failed. So these two EAs currently have **no** successful COMPILE_OK row at all. This does not change the classification of the two listed pending rows (they are dead/superseded and must stay non-claimable), but it means the *EAs* need a fresh, correctly-bound compile before they can enter the funnel. This is a build-lane follow-up on the successors' failure — not a release or supersede action on the 18 legacy rows. Flagging only; no command recommended here without inspecting the COMPILE_FAIL logs.

---

## The one live release candidate (out of the 18-row scope): QM5_41285 → e23cfbc8

`e313ef05` (row 18) points at successor **`e23cfbc8-3f6d-4b27-b369-c6061a6b44a5`**, which is the actual release-worthy row for this ea:

- `phase=COMPILE_EA`, `status=pending`, `claimed_by=NULL`, `attempt_count=0`, created 2026-09-02T07:29:52Z.
- **Held**: `work_item_holds` `COMPILE_EA_WORKER_ROLLOUT_PENDING` with `active=1` → excluded at farmctl.py:2455, awaiting a deliberate release. This is exactly the state today's released rows were in before `release_compile_wave.py` cleared them.
- **Task-bound**: `bound_build_task_id=5589bbaa-7b6c-433a-ae64-fad387bca3fc`, `compile_contract_version=qm.compile-ea-work-item/v1` → earns claim priority rank −1 (farmctl.py:2226-2246) once released.
- Not itself superseded; source hash `94954df9…548519f43`.
- Confirmations: EA dir `framework/EAs/QM5_41285_xauxag-mjt-rv` present; magic registered (magic_numbers.csv:18200-18201 `412850000/412850001`; ea_id_registry.csv:4786, active); approved card present in the D: mirror `D:/QM/strategy_farm/artifacts/cards_approved/QM5_41285_xauxag-mjt-rv_card.md`. **Caveat before release:** the card was *not* found in the repo `artifacts/cards_approved` / `state/artifacts/cards_approved` mirrors during this audit — the CEO should confirm the C:-side mirror (or dual-location expectation) is satisfied per the standing "cards_approved auf D: UND C:" rule before releasing.

If (and only if) the CEO decides to advance the QM5_41285 build, the release command is the standard one — **note it targets the successor, not `e313ef05`**:

```
python tools/strategy_farm/release_compile_wave.py --apply \
  --backup-reuse-max-age-minutes 0 \
  --work-item-id e23cfbc8-3f6d-4b27-b369-c6061a6b44a5
```

(Presented for decision only. Not executed here. This is a live-inventory action and remains the CEO's to run.)

---

## Discrepancy note

The prompt says "**Seventeen** COMPILE_EA rows" but lists **18** ids. All 18 were found and audited; all 18 are already superseded. The count most likely predates the addition of `e313ef05` (QM5_41285), which was created and superseded on 2026-09-02, distinct from the 17 legacy rows reconciled on 2026-08-25 under router task e9944090.

## Hard-limits compliance
- Farm DB opened only via `?mode=ro`; zero writes to it. No enqueue/hold/release/supersede/restart issued. No CEO command executed. No commit/push. No writes under `D:/QM`, `C:/QM/mt5`, or `C:/QM/repo/decisions/`. This file is the only artifact written, inside the worktree at `docs/ops/evidence/`. Every claim above cites a `file:line` or a read-only query (scripts in scratchpad: `q1.py`/`q2.py`/`q3.py`).

# OWNER CEO-MP-#7 — Public-data Q02-bypass hold release (2026-08-21)

**Authority:** OWNER decision `CEO-MP-#7`, ratified 2026-08-21 ("Geprüft und abgenommen,
folge der Empfehlung!"). Recorded in `D:/QM/reports/state/owner_decisions.json` and vault
`12 ToDo/AI ToDos/OWNER.md`.

**Executed by:** Claude (board-advisor worktree), on branch `agents/board-advisor`.

**Scope authorized:** (a) release the orphan hold `FACTORY_OFF_AUTO_Q02_BYPASS` on the
QM5_20182 Q02 row; (b) do NOT release the QM5_20172 hold — instead file a @Codex task to
fix the draft defect and drive a fresh generation-bound Q02; (c) leave the fail-closed
export guard untouched — it re-opens publication by itself once both holds are gone.

---

## 1. Verification before acting (read-only)

DB inspected read-only: `D:/QM/strategy_farm/state/farm_state.sqlite`.

### QM5_20182 (work item `60181936-0403-49bc-b221-dda4f35eb584`) — remediation complete

The held Q02 row is the auto-enqueued FACTORY_OFF artifact, NOT admission-authoritative:

| Q02 work item | symbol | status | verdict | created | updated |
|---|---|---|---|---|---|
| `60181936-0403-49bc-b221-dda4f35eb584` (held) | XTIUSD.DWX | failed | BLOCKED_FACTORY_OFF | 2026-07-29T08:37:57Z | 2026-07-29T09:54:40Z |
| `a8d09cc8-17b0-4f38-adf1-845b0f650cd1` | XTIUSD.DWX | done | **PASS** | 2026-07-31T07:35:30Z | 2026-07-31T08:20:02Z |
| `34f98716-dc52-43c4-b013-4112a9a18bb4` | XTIUSD.DWX | done | **PASS** | 2026-07-31T08:23:29Z | 2026-07-31T08:43:11Z |

Both PASS rows post-date the 2026-07-29 hold and carry real evidence:
- `D:\QM\reports\work_items\a8d09cc8-17b0-4f38-adf1-845b0f650cd1\QM5_20182\20260731_081616\summary.json` → `result=PASS`, `reason_classes=[OK]`
- `D:\QM\reports\work_items\34f98716-dc52-43c4-b013-4112a9a18bb4\QM5_20182\20260731_083929\summary.json` → `result=PASS`, `reason_classes=[OK]`

Both summaries bind the same current repo binary
`framework\EAs\QM5_20182_wti-sum-bull\QM5_20182_wti-sum-bull.ex5`
(sha256 `e339db4921cb9150b25271623cd149e4370759d174c4f...`). Remediation is demonstrably
complete → orphan hold release authorized.

### QM5_20172 (work item `88ba4560-fd7f-456f-903f-f4982d8f9cf3`) — still defective

| Q02 work item | symbol | status | verdict | created |
|---|---|---|---|---|
| `ab8d8b7a-1c17-4cdc-b259-080cab3b75df` | XTIUSD.DWX | done | **DRAFT_DEFECT** | 2026-07-26T09:55:07Z |
| `88ba4560-fd7f-456f-903f-f4982d8f9cf3` (held) | XTIUSD.DWX | failed | BLOCKED_STALE_BUILD_RESULT | 2026-07-29T07:20:50Z |

No fresh generation-bound Q02 PASS exists for QM5_20172. Hold correctly **retained**.

---

## 2. Hold released — QM5_20182

**Release path decision.** The operator CLI
`tools/strategy_farm/maintenance_control.py release-completed-hold` is legal only while
`FACTORY_OFF.flag` is asserted (`maintenance_control.py:1000` requires the flag file to
exist). At execution the factory was ON — `FACTORY_OFF.flag` absent, 7 `terminal64.exe`
running at the hard CPU ceiling — and CEO-MP-#7 forbids asserting Factory OFF / reboot.
No usable CLI path existed in the live state, so per the task's explicit fallback a
minimal targeted SQL `UPDATE` was applied to the ONE hold row (DB backed up first to
scratchpad `farm_state.pre_ceomp7_release.sqlite`).

**Before:**
```
work_item_id=60181936-0403-49bc-b221-dda4f35eb584 hold_code=FACTORY_OFF_AUTO_Q02_BYPASS
active=1 created_at=2026-07-29T09:54:40+00:00 updated_at=2026-07-29T09:54:40+00:00
released_at=None release_note=None
```

**UPDATE:** `SET active=0, updated_at, released_at, release_note WHERE work_item_id=? AND
hold_code=? AND active=1` → rowcount = 1, committed 2026-08-21T07:17:48+00:00.

**After:**
```
work_item_id=60181936-0403-49bc-b221-dda4f35eb584 hold_code=FACTORY_OFF_AUTO_Q02_BYPASS
active=0 updated_at=2026-08-21T07:17:48+00:00 released_at=2026-08-21T07:17:48+00:00
release_note="OWNER CEO-MP-#7 2026-08-21: remediation verified (fresh Q02 PASS 2026-07-31),
orphan hold released by Claude"
```

QM5_20172 hold left untouched (active=1, released_at=None). No verdict, work item, or
trade stream was deleted or overwritten. All `FTMO_BOOK3_Q02_ISOLATED_ONLY` holds intact.

---

## 3. @Codex task filed — QM5_20172

Created via `agent_router.py enqueue ops_issue` (capabilities `["ops","code"]` → routes to
Codex):

- **task_id:** `af13cc2d-3a28-4fd5-a226-9e2695b499aa`
- **type / state / priority:** ops_issue / TODO / 70
- **brief:** fix the draft defect in `framework/EAs/QM5_20172_wti-fri-bear` (the defect
  behind the DRAFT_DEFECT Q02), rebuild so the `.ex5` is generation-bound, then drive a
  fresh generation-bound Q02 whose expert-binary sha256 matches the rebuilt `.ex5`.
- **acceptance:** a fresh generation-bound Q02 result for QM5_20172 / XTIUSD.DWX; the
  `STALE_BUILD_RESULT_AUTO_Q02_BYPASS` hold on `88ba4560-...` is released ONLY after that,
  by whoever verifies it — never by weakening the export guard.

---

## 4. Export guard answer (fail-closed, blocks-on-ANY — NOT cohort-scoped)

Guard: `tools/strategy_farm/public_snapshot_incident_guard.py`. It selects every
`work_item_holds` row whose `hold_code` is in `BLOCKING_HOLD_CODES`
(`FACTORY_OFF_AUTO_Q02_BYPASS`, `STALE_BUILD_RESULT_AUTO_Q02_BYPASS`) with **no**
work-item/EA/cohort filter (query at `public_snapshot_incident_guard.py:54-59`), collects
any with `active==1` (`:71-72`), and sets **`publication_allowed = not holds`**
(`public_snapshot_incident_guard.py:76`). → It blocks on **ANY** active Q02-bypass hold
anywhere in the table; it is not scoped to the exported cohort.

Hourly task wiring `scripts/run_public_snapshot_task.ps1`: runs the guard first (`:89`) and
`throw`s the publication refused (`:113-120`) **before** `build_pipeline_state.py` (`:123`)
or `export_public_snapshot.ps1` (`:130`) ever run. Guard was NOT touched, weakened, or
bypassed.

**Guard state (read-only):**
- Before release: `active_incident_hold_count=2`, `publication_allowed=false`, exit 3.
- After release: `active_incident_hold_count=1` (only
  `STALE_BUILD_RESULT_AUTO_Q02_BYPASS` / `88ba4560-...`), `publication_allowed=false`,
  exit 3.

---

## 5. What still blocks fresh publication

Public-data will **NOT** publish fresh yet. Because the guard blocks on ANY active
Q02-bypass hold, the retained QM5_20172 `STALE_BUILD_RESULT_AUTO_Q02_BYPASS` hold keeps
`publication_allowed=false` — exactly as OWNER decision (c) anticipates ("once **both**
holds are gone the export publishes by itself"). Publication re-opens automatically once
Codex task `af13cc2d-3a28-4fd5-a226-9e2695b499aa` delivers a fresh generation-bound Q02 and
that second hold is released by its verifier. No guard change is needed or permitted.

**Backup:** `…/scratchpad/farm_state.pre_ceomp7_release.sqlite` (pre-mutation snapshot).

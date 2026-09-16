# Receipt — OWNER-DEC-REQUEUE-LIFT-20260916 / D2B continuation — QM5_11731 (EURUSD M5 pilot)

- Owner decision id: `OWNER-DEC-REQUEUE-LIFT-20260916` (D2B, APPROVED WITH CONDITIONS:
  EURUSD.DWX M5 pilot first, fan out only on a clean pilot)
- Operator: `kimi-interim` (continuation of the parked D2B STOP)
- EA: `QM5_11731` (slug `QM5_11731_tc-m5-s20-ema3-bb-macd`; 4-symbol card universe
  EURUSD/GBPUSD/USDCHF/USDJPY .DWX, all M5)
- Date (UTC): 2026-09-16 (06:54Z)
- **Outcome: STOP at step 1 of the authorized continuation path — the
  `enqueue-compile` candidate guards refuse QM5_11731, and no legitimate waiver
  exists for this EA. The exclusion was NOT lifted, nothing was enqueued, no
  factory DB row was written, no terminal was touched.**

## 1. Provider-mandate determination (the 41478/41475–41477 method)

Question: does the COMPILE_EA contract mandate codex, or is deterministic local
compile permitted?

**Answer: deterministic local MetaEditor compile is the mandated provider for the
COMPILE_EA lane; codex is NOT mandated anywhere in that contract.** Evidence:

- `run_compile_work_item` (`tools/strategy_farm/compile_work_items.py:6037`) — the
  sole COMPILE_EA executor — runs `framework/scripts/gen_setfile.ps1` and then
  `framework/scripts/build_check.ps1 -Strict -CompileWorkItemId <id> -ClaimedTerminal <T#>`
  and writes a `qm.compile-ea-evidence/v1` document. No codex/LLM call anywhere.
- `build_check.ps1:1608` invokes `compile_one.ps1`, which resolves
  `metaeditor64.exe` and compiles the staged source (compile_one.ps1:58-65).
- `validate_ex5_commit_guard.py:230` (EX5_COMMIT_GUARD pre-commit): staged `.ex5`
  changes must carry a governed COMPILE_EA receipt; its own error text says the fix
  is `farmctl enqueue-compile <EA_LABEL>` "and let the governed worker compile it".
- Codex appears only in the **authoring** lane (`build-ea` → codex → `record-build`),
  which for QM5_11731 already concluded 2026-08-04 (build task `1a17f439-…`, done,
  smoke passed). The 41475–41477 critic→Q00 lane used exactly this deterministic
  local compile with the worktree `.ex5` left uncommitted per EX5_COMMIT_GUARD.

## 2. Why the authorized continuation path is blocked at step 1

Authorized path: `enqueue-compile` → execute COMPILE_EA claim →
`intake-first-q02 --compile-work-item-id <id> --apply` → EURUSD M5 pilot → fanout.

Dry-run (batch form is read-only by default; the positional form would have applied
immediately, so the dry-run form was used):

```text
python tools/strategy_farm/farmctl.py enqueue-compile --from-file <label-file>
```

Full output preserved at `d2b_continuation_enqueue_compile_dry_run.json`.
Result: `ok=false, enqueued_count=0`, candidate refused with:

```json
"reasons": ["EX5_ALREADY_PRESENT", "BUILD_TASK_EXISTS"]
```

Both reasons are hard fail-closed guards in `classify_candidate`
(`compile_work_items.py`):

- `EX5_ALREADY_PRESENT` (compile_work_items.py:4336-4337) — the EA dir holds the
  wave-64-committed `.ex5` (git-tracked since 2026-08-04; `git ls-files` confirms).
  Waivable **only** via force-rebuild (`FORCE_REBUILD_WAIVABLE_REASONS`,
  compile_work_items.py:1185-1188) or a registered source-repair authority
  (compile_work_items.py:4423-4430).
- `BUILD_TASK_EXISTS` (compile_work_items.py:4375-4376) — `build_ids` includes any
  build_ea task in pending/active/**done** (compile_work_items.py:4158), and
  `1a17f439-…` is `done`. The `--build-task-id` binding waiver
  (`_build_task_binding`, compile_work_items.py:4173) requires the named task to be
  **open** (`BUILD_TASK_BINDING_NOT_OPEN`, compile_work_items.py:4203-4204) — it is
  not.

No legitimate waiver is available for QM5_11731:

- **Force-rebuild** — `force_rebuild_allowlist` (compile_work_items.py:1307) unions
  only the DL-089 (hardcoded ids), MAE-hook (12947-12952), and pre-0803
  (11910/10700/12710/10815/12580) cohorts. 11731 is in none, and
  `framework/registry/owner_priority_tracks.json` cannot add it (the hardcoded
  `DL089_FORCE_REBUILD_EA_IDS` name must also match).
- **Source-repair authority** — every authority in `_source_repair_authorized`
  (compile_work_items.py:3074+) and `BACKLOG_SOURCE_REPAIR_REGISTRATIONS`
  (compile_work_items.py:2088+) is bound to a specific EA/ticket; none names 11731
  (grep of compile_work_items.py: no `11731`).
- `--repair-successor-of` requires an existing failed COMPILE_EA row — QM5_11731 has
  **zero** work items of any kind (verified against the live DB).

The 2026-09-02 QM5_37003 recovery used `--build-task-id` + `PENDING_STRICT_Q01`
setfile headers to clear `BOUND_SETFILE_HASH_EXISTS`; that path cannot help here
because 11731's blocker is `EX5_ALREADY_PRESENT` (unwaivable) plus a **done** build
task (binding refuses non-open tasks). (Note: 11731's setfiles carry
`; build_hash: pending`, so `BOUND_SETFILE_HASH_EXISTS` correctly does **not** fire.)

## 3. Actions taken / not taken (state unchanged)

- Exclusion file `D:\QM\strategy_farm\state\requeue_excluded_eas.txt` — **untouched**;
  sha256 still `3f092f0a5029f483da2d25086245ecb53ebe1be79c28245b0451d93b6c45f3f3`
  (D2A after-hash); the `QM5_11731` line remains (grep count 1). The pump keeps
  skipping this EA — no unprotected auto-fanout is possible.
- No COMPILE_EA or Q02 row created; `work_items` count for QM5_11731 = 0 (verified).
- No build task, registry, setfile, ex5, terminal, or live state modified.
- All DB access was read-only; the only farm command run was the read-only
  enqueue-compile dry-run.

Per the decision's explicit stop rule ("If no legitimate single-symbol scope exists
in the tool, STOP and report rather than improvising"), I did **not**: delete or
un-commit the tracked `.ex5`, re-open the done build task, hand-create any work_item
row, or claim a repair/force-rebuild authority this EA does not hold.

## 4. What would legitimately unblock this EA (needs OWNER direction)

1. **OWNER-ratified force-rebuild** for QM5_11731 (or a small scoped source-repair
   registration), i.e. the code+decision change contemplated as option (b) in the
   D2B receipt. With that, the flow is: `enqueue-compile --from-file … --apply`
   (waives EX5_ALREADY_PRESENT + BUILD_TASK_EXISTS) → COMPILE_EA claim executes
   `run_compile_work_item` (deterministic MetaEditor compile) → done/COMPILE_OK row
   → `intake-first-q02 --compile-work-item-id <id> --apply` (EURUSD.DWX M5 canary;
   GBPUSD/USDCHF/USDJPY deferred under `q02_deferred_symbols.json`) → pilot (a–e) →
   governed fanout.
2. Alternative: OWNER ratifies a scoped single-symbol enqueue variant (also option
   (b) in the D2B receipt).

Until one of those exists, the pilot conditions (a–e), the canary work item, and
the fanout decision are **not reached** — this is a parked governance STOP, not an
EA failure. Note the compile provider question is fully resolved (deterministic
local compile), so the unblock is purely a candidate-guard/authority matter.

## 5. Report fields (per continuation brief)

- Provider-mandate determination: deterministic local MetaEditor compile is
  mandated for COMPILE_EA; codex NOT mandated (section 1).
- Compile row id + result: **none minted** — enqueue refused (section 2).
- Lift hashes: **none** — exclusion file unchanged at D2A after-hash
  `3f092f0a…f3f3` (section 3).
- Canary work-item id + claim + verdict: **none** — intake never reached.
- Pilot checks a–e: **not reached** (blocked upstream).
- Fanout decision: **not reached**; deferred symbols remain on the card only.
- Terminal/PIDs: none (no worker claim; nothing enqueued).
- STOP: **YES** — step 1 of the authorized path; reason and unblocks above.

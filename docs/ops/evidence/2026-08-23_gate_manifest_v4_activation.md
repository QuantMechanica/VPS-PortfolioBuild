# Gate Manifest v4 — activation evidence (tool + dry-run)

Date: 2026-08-23
Branch: `rb-activate`
Tool: `tools/strategy_farm/activate_gate_manifest_v4.py`

## Status and safety

PASS (dry-run). This ticket delivers the orchestrator's one-shot, idempotent
activation tool for Gate Manifest **v4** (the linear three-phase renumbering,
OWNER decision `decisions/2026-08-23_owner_gate_manifest_v4_linear.md`).
`--apply` was **not** run. The live database was opened only through a `mode=ro`
URI for the precondition census; the migration was exercised against a
throw-away **copy** in `scratch/rb-activate-dryrun/`. The factory was not
toggled and `T_Live` was not touched.

v4 carries every v3 gate criterion verbatim (ROT untouched); only identifiers,
order and phase grouping change. v3 stays loadable as a fixture, so the flip is
a one-line revert.

## What the tool does (six framed steps, fail-closed in `--apply`)

1. **Preconditions** — git tree clean for the tool's target files
   (`gate_manifest.py`, `config/gate_manifest.*.json`); `FACTORY_OFF.flag`
   present under `D:/QM/strategy_farm/state` (or `--allow-factory-on`, loud
   warning); no active (`pending`/`active`) `work_items` in a v3 storage phase
   whose id changes meaning under v4 — `Q09_NEWS, Q09_PORTFOLIO, Q10, Q14, Q15,
   Q16` (or `--allow-active`); the v4 draft validates `READ_INERT` under the
   loader.
2. **Promote** — writes `config/gate_manifest.v4.json` = the frozen draft with
   `activation_guard` set ACTIVE (`default_manifest_switch=true`,
   `activated_by=CLAUDE`, `activated_at=2026-08-23`, `review_refs =
   ["a4990f77a", "decisions/2026-08-23_owner_gate_manifest_v4_linear.md"]`) and
   `status=ACTIVE`. Only `status` and `activation_guard` differ from the draft.
   The loader's v4 ACTIVE guard now requires **both** those review refs
   (`gate_manifest.V4_ACTIVATION_REVIEW_REFS`), mirroring the v3 pattern;
   READ_INERT can never be the default. `.gitattributes` LF-pins the file.
3. **Flip** — `DEFAULT_MANIFEST = V4_MANIFEST`, `SCHEMA_VERSION =
   SCHEMA_VERSION_V4` in `gate_manifest.py` (byte-exact single-anchor,
   idempotent). `phase_ids` rebuilds from the new default. A `python -c` smoke
   runs in a **subprocess** (Python binds `load_gate_manifest`'s default arg at
   def-time, so the flip must be a real source edit + fresh import): asserts
   default schema v4, `PHASE_ORDER == Q00..Q17` linear, `next(Q14) is None`,
   macro phases present, and `phase_label('Q10','v3') == "Q11 (v3:Q10)"`.
4. **DB migration** — `sqlite3` backup-API copy to
   `D:/QM/strategy_farm/backups/farm_state_pre_v4_<ts>.sqlite`
   (`integrity_check=ok`), then the reviewed additive/append-only
   `ensure_work_item_gate_contract_schema` + `q09_news_schema.ensure_schema`;
   prints `gate_contract_version` counts and dependency-row counts before/after
   (dependency total must be equal or the step fails closed), then stamps a row
   in a new `gate_contract_activations(contract_version, activated_at,
   manifest_sha256, backup_path, git_head)` table. In `--apply` this runs in a
   post-flip subprocess so the new-row trigger stamps `v4`; in `--dry-run` it
   runs on the copy.
5. **Verify** — `pytest` on `test_gate_manifest.py`,
   `test_gate_contract_version.py`, `test_advancement_centralization.py`,
   `test_book_build_guard.py`, `test_q09_news_schema_v2.py`; then writes this
   evidence file.
6. **`--rollback-plan`** — prints the exact rollback commands.

## Dry-run result (clean tree, `--allow-factory-on --allow-active`)

```
[PASS] precondition: git tree clean for target files
[PASS] precondition: FACTORY_OFF.flag present
[PASS] precondition: no active work_items in meaning-changing phases
[PASS] precondition: v4 draft validates READ_INERT under the loader
[PASS] promote: write gate_manifest.v4.json (ACTIVE)
        target sha256=f71c1ea63f1e847b3670904a6de25bcb4b337df9e0a7cff8ee6405d9c3aa2c83
[PASS] flip: DEFAULT_MANIFEST + SCHEMA_VERSION -> v4
        before sha256=8032f2c6abea9f236d3fbfe5a4776bd7bbc12d8303e286fc3a86da4edf32135c
        after  sha256=d3f1bcbdde61f0374285e1c60d2ded01e77a095ad184ec5b178cbf785274b050
[PASS] flip smoke: v4 default loads and renders  (subprocess; --apply only)
[PASS] db migration: gate_contract_version + q09 schema
        gate_contract_version before={legacy=111392, v3=8} after={legacy=111392, v3=8}
        dependency rows before=102 after=102 (equal)
        activation stamped: contract_version=v4
[PASS] verify: pytest suites  (--apply only)
```

## Real environment state (honest `--dry-run`, no override flags)

The plain dry-run reports two real environmental holds the orchestrator must
resolve before `--apply`:

- **`FACTORY_OFF.flag` is absent** — the factory is currently ON. Run
  `Factory_OFF.ps1` first (never toggle it from here), or pass
  `--allow-factory-on` deliberately.
- **24 active `Q09_NEWS` rows** — the live news frontier. Because
  `Q09_NEWS -> Q10_NEWS` is a pure renumber and every historical row is read
  only under its own `gate_contract_version`, `--allow-active` is defensible,
  but it is an orchestrator/OWNER judgment, not a default.

The git-clean precondition also fails on a dirty dev tree; it passes once the
code commit is in (this branch, commit `e40f359c9`).

## Migrated counts (real, measured on the live-DB copy)

The live database already carries the additive `gate_contract_version` column
(installed by a routine `farmctl` init after rb-contract-version merged), so the
migration is a verified idempotent no-op on existing rows:

| Metric | Before | After |
|---|---|---|
| `gate_contract_version=legacy` | 111392 | 111392 |
| `gate_contract_version=v3` | 8 | 8 |
| `work_item_dependencies` rows | 102 | 102 |

Backup path pattern (apply):
`D:/QM/strategy_farm/backups/farm_state_pre_v4_<UTCstamp>.sqlite`.

## Touched-file hashes

Code changes (committed `e40f359c9`; before = parent blob, after = working):

| File | Before (sha256) | After (sha256) |
|---|---|---|
| `tools/strategy_farm/gate_manifest.py` | `4716222f0ea103eeb24ffb2a8ef72243682249def49cb4adf24acac335cd55b2` | `ef6ccbd1bcde47225feae905912c0aaf2943f8ef877c931f1eee909ec7bf7dc9` |
| `tools/strategy_farm/phase_ids.py` | `3625b07da3eb3e98e6719495d1b0915990af1bd9c11def90b37c9cd35be0adc6` | `16211d10b4311ee67926a76ba02dd0cdad527b3a2b923a10e5a31572b7116be9` |
| `tools/strategy_farm/tests/test_gate_manifest.py` | `8d4e22c57ea1719ba31efc025f7ab2c04f4eea4c194dc1add217edf9c48ad0df` | `db07335f70f108a664a097920e6a4f5c68d596853ce654c0d2f8ebc9bc777950` |
| `.gitattributes` | `6c853a8ff1cb460a4c7c6cb2414c756b38b0c2a58a0d2d1a5a8ee76e06358f20` | `80ad5ad2804154ca3bebde37ded37b236dd1049df2e0bfdd8753f8a5ee609b46` |

Apply-time changes (reported by the dry-run):

| File | Change | sha256 |
|---|---|---|
| `tools/strategy_farm/config/gate_manifest.v4.json` | created (ACTIVE) | `f71c1ea63f1e847b3670904a6de25bcb4b337df9e0a7cff8ee6405d9c3aa2c83` |
| `tools/strategy_farm/gate_manifest.py` | flip (before) | `8032f2c6abea9f236d3fbfe5a4776bd7bbc12d8303e286fc3a86da4edf32135c` |
| `tools/strategy_farm/gate_manifest.py` | flip (after) | `d3f1bcbdde61f0374285e1c60d2ded01e77a095ad184ec5b178cbf785274b050` |

(The flip before/after digests are the tool's in-memory text encoding; the
`gate_manifest.py` on-disk content hashes are in the table above.)

## Verification

```
> python -m pytest tools/strategy_farm/tests/test_gate_manifest.py \
    tools/strategy_farm/tests/test_gate_contract_version.py \
    tools/strategy_farm/tests/test_advancement_centralization.py \
    tools/strategy_farm/tests/test_book_build_guard.py \
    tools/strategy_farm/tests/test_q09_news_schema_v2.py \
    tools/strategy_farm/tests/test_activate_gate_manifest_v4.py -q
79 passed, 2 skipped
```

The 2 skips are the optional `jsonschema` Draft-2020-12 checks (library absent
in the base environment). The v3 default and all v3 runtime tables are
byte-identical after the `phase_ids` change (the v4 branches activate only when
the default is v4).

## Exact apply command (for the orchestrator)

Prerequisite: tree clean (this commit merged), factory OFF, and either the 24
active `Q09_NEWS` rows drained or `--allow-active` chosen deliberately.

```powershell
cd C:/QM/worktrees/rb-activate   # or the canonical checkout carrying this commit
# 1) stop the factory the normal way (NEVER toggled from this tool):
#    Factory_OFF.ps1
# 2) then activate:
python tools/strategy_farm/activate_gate_manifest_v4.py --apply --allow-active
#    (add --allow-factory-on ONLY if intentionally activating with the factory ON)
# 3) commit the apply artifacts (flip + v4.json + evidence) with explicit pathspecs,
#    then re-mint the runtime-activation decision and run Factory_ON.
```

## Rollback

```
# 1. Revert the flip + promotion commit (restores the v3 default)
git revert --no-edit <activation-commit-sha>
#    or, before committing:
git checkout -- tools/strategy_farm/gate_manifest.py
git rm -f tools/strategy_farm/config/gate_manifest.v4.json

# 2. Restore the pre-v4 DB backup ONLY if a bad migration must be undone.
#    The migration is additive + append-only, so normally NO db restore is
#    needed. If required, stop the factory first, then:
copy /Y "D:\QM\strategy_farm\backups\farm_state_pre_v4_<ts>.sqlite" \
        "D:\QM\strategy_farm\state\farm_state.sqlite"
#    (delete stale -wal/-shm sidecars beside the DB before restart)

# 3. Re-mint the runtime-activation decision and run Factory_ON once the tree
#    is clean again.
```

`python tools/strategy_farm/activate_gate_manifest_v4.py --rollback-plan` prints
this list.

## Risks / notes

- **Deferred (as in the v3 activation):** the deep v4 runtime rebinding of
  `work_item_dependencies` roles (`CHALLENGER_Q10 -> CHALLENGER_Q11`,
  `Q14_ADMISSION -> Q12_ADMISSION`) and the head-to-head / Q09 enqueue paths is
  a separately reviewed change. The `q09_news_schema` CHECK already accepts the
  v4 role union (append-only), and historical rows are read under their own
  contract version, so activation is safe without it; new v4-role writes are a
  follow-on.
- `phase_ids` v4 news-lane semantics (`Q10_NEWS/Q10_PORTFOLIO`) are derived from
  the manifest equivalence table and take effect only under a v4 default; the
  full factory dispatch/cascade behaviour under v4 has not been exercised
  end-to-end (no `--apply`).
- `--apply` runs the migration in a subprocess so the new-row trigger stamps
  `v4`; existing rows are never reclassified.

# Gate Manifest v4 — activation evidence

Date: 2026-08-23

Mode: APPLY

Authority: OWNER decision `decisions/2026-08-23_owner_gate_manifest_v4_linear.md` (linear three-phase renumbering, executed under the Stehende Vollmacht Auffangregel). v4 carries every v3 gate criterion verbatim; only identifiers, order and phase grouping change.

## Step results

- [PASS] precondition: git tree clean for target files
  - clean: 5 target files
- [PASS] precondition: FACTORY_OFF.flag present
  - present: D:\QM\strategy_farm\state\FACTORY_OFF.flag
- [PASS] precondition: open meaning-changing rows are cutover-eligible
  - eligible work_items=28 (--allow-active is no longer required)
  - dependency-role rewrites=0
- [PASS] precondition: v4 draft validates READ_INERT under the loader
  - READ_INERT; sha256=c51fbfffb1aca470...
  - schema=qm.gate-manifest/v4
- [PASS] promote: write gate_manifest.v4.json (ACTIVE)
  - activated_by=CLAUDE activated_at=2026-08-23
  - review_refs=['a4990f77a', 'decisions/2026-08-23_owner_gate_manifest_v4_linear.md']
  - target sha256=f71c1ea63f1e847b3670904a6de25bcb4b337df9e0a7cff8ee6405d9c3aa2c83
  - written: C:\QM\repo\tools\strategy_farm\config\gate_manifest.v4.json
- [PASS] flip: DEFAULT_MANIFEST + SCHEMA_VERSION -> v4
  - before sha256=abd09914e9f10648e3aec469caaac2526a52c01eea4f562c59f4cc285f8a6acb
  - after  sha256=bd4c7f43e18bf909a4a3ce41a1359d38f0be3cdc2849a0446ddf1bcec1914c07
  - gate_manifest.py flipped
- [PASS] flip smoke: v4 default loads and renders
  - schema=qm.gate-manifest/v4 active=v4
  - phase_order=Q00..Q17 linear; next(Q14)=None
  - macro: Q10=2_OPTIMIERUNG Q15=3_BUCHBEWERTUNG
  - phase_label('Q10','v3')='Q11 (v3:Q10)'
- [PASS] db migration: gate_contract_version + q09 schema
  - backup: D:\QM\strategy_farm\backups\farm_state_pre_v4_20260823T155246Z.sqlite (integrity_check=ok)
  - gate_contract_version before={legacy=111392, v3=26} after={legacy=111369, v3=21, v4=28}
  - dependency rows before=104 after=104 (equal)
  - cutover work_items=28 dependencies=0
  - activation stamped: contract_version=v4
- [PASS] verify: pytest activation + orchestrator integration suites
  - .....................................s.............................. [ 99%]
  - .                                                                        [100%]
  - 208 passed, 3 skipped, 6 subtests passed in 56.62s
  - full output: C:\QM\repo\scratch\rb-v4-cutover\activation_verify.log

## Touched-file hashes (before / after)

| File | Before | After |
|---|---|---|
| tools/strategy_farm/gate_manifest.py | see flip step | bd4c7f43e18bf909a4a3ce41a1359d38f0be3cdc2849a0446ddf1bcec1914c07 |
| tools/strategy_farm/config/gate_manifest.v4.json | see flip step | f71c1ea63f1e847b3670904a6de25bcb4b337df9e0a7cff8ee6405d9c3aa2c83 |

## Database migration

- backup: `D:\QM\strategy_farm\backups\farm_state_pre_v4_20260823T155246Z.sqlite`
- gate_contract_version before: `{legacy=111392, v3=26}`
- gate_contract_version after: `{legacy=111369, v3=21, v4=28}`
- dependency rows before/after: 104 / 104 (equal)

## Rollback

```
# Rollback Gate Manifest v4 activation

## 1. Revert the flip + promotion commit (restores v3 default)
git revert --no-edit <activation-commit-sha>
#   or, before committing:
git checkout -- tools/strategy_farm/gate_manifest.py
git rm -f tools/strategy_farm/config/gate_manifest.v4.json

## 2. Restore the pre-v4 database backup (only if a bad migration must be undone)
#   The migration is additive + append-only; normally NO db restore is needed.
#   If required, stop the factory first, then:
copy /Y "D:\QM\strategy_farm\backups\farm_state_pre_v4_20260823T155246Z.sqlite" "D:\QM\strategy_farm\state\farm_state.sqlite"
#   (delete stale -wal/-shm sidecars beside the DB before restart)

## 3. Re-mint the runtime-activation decision and run Factory_ON
#   after the tree is clean again.
```


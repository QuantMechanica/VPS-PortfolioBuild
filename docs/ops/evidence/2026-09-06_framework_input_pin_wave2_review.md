# Framework-input pin batch repair — Wave 2 review

Date: 2026-09-06  
Router task: `ce03756f-7fad-4bd4-aa57-561551851604`  
State: REVIEW; no compile enqueue, Q-phase enqueue, or worker reload

## Result

- Started from all 130 `APPEND_ONLY_IDENTITY_RESTART` rows in the canonical
  framework-input-pin census.
- Repaired and exact-authority-bound 119 active identities. The identical
  wave-1 hunk removes only `qm_rng_seed`, `qm_news_*`, and
  `qm_friday_close_*` comparisons from `Strategy_NoTradeFilter`, while the
  stress check is now a finite inclusive `0..1` range.
- Preserved host-chart, EA identity, magic-slot, framework-magic, fixed-risk,
  portfolio-weight, and strategy-specific guards.
- Added every repaired `.mq5` path to `.gitattributes` as `-text`; all repaired
  source bytes are LF and sealed by SHA-256 in the authority evidence.
- Excluded 11 census rows fail-closed: eight have no direct
  `QM_FrameworkTrackOpenPositionMae()` hook (one also has active symbol
  `XBRUSD.DWX`, absent from the DWX matrix), one duplicate `QM5_20292` source
  conflicts with the active registry/card identity, and two identities were
  already repaired and authority-bound by the pacer precedent.

## Immutable authority

`2026-09-06_framework_input_pin_wave2_authority.json` binds the 119 exact EA
identities to repaired source hashes, approved-card hashes, active
registry/magic preflight, and 30 available terminal `COMPILE_EA` predecessor
rows. It records the complete exclusions and asserts that no compile, Q-phase,
or worker action was applied.

Authority SHA-256:
`632245c688372465ddd29d374f828df210663d4d02fed2ca72822b72b53b0fca`.
`compile_work_items.py` loads the registrations only when that hash, task ID,
cohort, no-apply flags, validation counts, and 119-row schema all match.

## Restart plan

`2026-09-06_framework_input_pin_wave2_restart_plan.md` lists 261 distinct
terminal `(EA, symbol, phase)` rows for the repaired identities. After an EA
receives `COMPILE_OK`, Q02 rows use the governed `seed-fresh-q02` / append-only
rerun path; later phases use their governed append-only rerun paths. This
artifact is a list only: it did not enqueue a compile or any Q-phase row and
did not reload workers.

## Verification

- Canonical `EA_FRAMEWORK_INPUT_PINNED` predicate: 0 findings across all 119
  repaired sources.
- Authority loader: 119/119 registrations loaded; all source hashes and LF
  byte seals match.
- Focused tests:
  `python -m pytest tools/strategy_farm/tests/test_compile_backlog_authorities.py tools/strategy_farm/tests/test_framework_input_pin_predicate.py -q`
  — `474 passed`.
- Real CLI dry-runs: 119/119 `ELIGIBLE`, 119/119
  `source_repair_authorized=true`, and 119/119 `enqueued_count=0`. Complete
  receipts are in `2026-09-06_framework_input_pin_wave2_dry_run.json`.

No historical verdict, work-item row, registry row, card, set file, EX5, or
terminal process was modified. The committed artifact remains in REVIEW for
OWNER/close-out handling.

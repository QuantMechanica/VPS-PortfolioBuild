# QM5_1585 Build Preflight Evidence — 2026-08-22

- Task ID: `72e5f0a9-b4fc-4319-ba9c-83de09df0d23`
- Requested EA: `QM5_1585_demark-td-differential-h4`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1585_demark-td-differential-h4.md`
- Artifact: `C:/QM/repo/docs/ops/evidence/72e5f0a9_qm5_1585_build_preflight_2026-08-22.md`
- Decision: `PREFLIGHT_FAIL`

## Deterministic preflight

The strategy card contains `g0_status: APPROVED`, but the requested ID/slug does not own the deterministic allocation required by `qm-build-ea-from-card`:

- `framework/registry/ea_id_registry.csv:382` allocates active EA ID `1585` to `aa-spx-util-risk`, not `demark-td-differential-h4`.
- `framework/registry/magic_numbers.csv` has zero active rows for EA ID `1585`.

The existing source at `framework/EAs/QM5_1585_demark-td-differential-h4/QM5_1585_demark-td-differential-h4.mq5` remains a tracked, unchanged framework stub. It contains the `Unknown Strategy` / unimplemented-entry markers, has SHA-256 `77c5c0ba80f110e73e7090e42b5e0d8bf9a427d6e7276545ca84dd3f61b5b3ee`, and has no sibling `.ex5`.

## Action and boundary

Build work stopped before implementation, set generation, or compilation. The conflicting registry row was not repurposed or changed, and no replacement row was invented. No pipeline or live-use verdict is implied.

Focused checks used the approved-card G0 field, exact ID/slug lookup in `ea_id_registry.csv`, active-ID lookup in `magic_numbers.csv`, `git diff --quiet` on the source, stub-marker search, SHA-256 hashing, and `.ex5` existence testing.

## Review handoff

Resolve the ID/slug conflict and allocate active magic rows through the authorized registry writer, then issue a new deterministic build assignment.

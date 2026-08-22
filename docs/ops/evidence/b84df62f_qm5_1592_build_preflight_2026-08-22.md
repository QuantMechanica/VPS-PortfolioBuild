# QM5_1592 Build Preflight Evidence — 2026-08-22

- Task ID: `b84df62f-47b8-48cd-a35c-a505a7b731f6`
- Requested EA: `QM5_1592_ehlers-even-better-sinewave-mtf-h4`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1592_ehlers-even-better-sinewave-mtf-h4.md`
- Artifact: `C:/QM/repo/docs/ops/evidence/b84df62f_qm5_1592_build_preflight_2026-08-22.md`
- Decision: `PREFLIGHT_FAIL`

## Deterministic preflight

The strategy card contains `g0_status: APPROVED`, but the two deterministic allocation prerequisites required by `qm-build-ea-from-card` are absent:

- `framework/registry/ea_id_registry.csv` has no row for EA ID `1592`; therefore it has no exact active `1592,ehlers-even-better-sinewave-mtf-h4,...` allocation.
- `framework/registry/magic_numbers.csv` has zero active rows for EA ID `1592`.

The existing source at `framework/EAs/QM5_1592_ehlers-even-better-sinewave-mtf-h4/QM5_1592_ehlers-even-better-sinewave-mtf-h4.mq5` remains a tracked, unchanged framework stub. It contains the `Unknown Strategy` / unimplemented-entry markers, has SHA-256 `8c66100253c4f37c2db8bd8bf85325bd9d2f3b1ca056975f6774f46d5d587d38`, and has no sibling `.ex5`.

## Action and boundary

Build work stopped before implementation, set generation, or compilation. No registry row was created or changed, because registry allocation is an upstream deterministic-writer responsibility. No pipeline or live-use verdict is implied.

Focused checks used the approved-card G0 field, exact ID/slug lookup in `ea_id_registry.csv`, active-ID lookup in `magic_numbers.csv`, `git diff --quiet` on the source, stub-marker search, SHA-256 hashing, and `.ex5` existence testing.

## Review handoff

Allocate the exact EA ID/slug and active magic rows through the authorized registry writer, then issue a new deterministic build assignment.

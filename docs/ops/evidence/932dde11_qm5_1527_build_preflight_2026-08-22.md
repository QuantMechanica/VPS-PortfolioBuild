# QM5_1527 build preflight — deterministic stop

- Router task: `932dde11-f11f-41c1-83df-c7afd521bd3e`
- Task type / priority: `build_ea` / `50`
- Canonical checkout: `C:/QM/repo`
- Branch / inspected HEAD: `agents/board-advisor` / `18e4d06d0f970b7a0e10bbd55a4d26d5e0ed99b4`
- Verdict: `REVIEW — BUILD_NOT_STARTED_REGISTRY_GATE_FAIL`

## Governed preflight

| Gate | Evidence | Result |
|---|---|---|
| Approved Strategy Card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1527_connors-crsi-composite-h4.md` declares `ea_id: QM5_1527`, matching slug, and `g0_status: APPROVED` | PASS |
| Exact active EA registry identity | No row begins `1527,` in `framework/registry/ea_id_registry.csv` | FAIL |
| Magic registry | No row begins `1527,` in `framework/registry/magic_numbers.csv` | FAIL |
| Existing source | The canonical EA directory contains only `QM5_1527_connors-crsi-composite-h4.mq5`; this does not substitute for governed registry allocation | OBSERVED |

The only slug-related EA registry record is line 3121: `ea_id=12227`, slug
field `QM5_1527_connors-crsi-composite-h4`, status `retired`. It was
retired at `2026-08-21T18:52:34+00:00` under the OWNER-approved D1 disposition
at `docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv`.

Per `qm-build-ea-from-card`, an allocated active EA registry row and magic rows
are mandatory before implementation. No source, registry, resolver, setfile,
or binary was changed, and no compile or pipeline phase was run. Governed
identity/magic allocation or router disposition is required before build.

## Focused verification

```text
rg '^(1527),' framework/registry/ea_id_registry.csv framework/registry/magic_numbers.csv
=> no matches

rg '^(12227),' framework/registry/ea_id_registry.csv
=> 12227,QM5_1527_connors-crsi-composite-h4,...,retired,...
```

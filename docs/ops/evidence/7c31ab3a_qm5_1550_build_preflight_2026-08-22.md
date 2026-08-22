# QM5_1550 build preflight — deterministic stop

- Router task: `7c31ab3a-de96-4948-8138-b2c6aef8630d`
- Task type / priority: `build_ea` / `50`
- Canonical checkout: `C:/QM/repo`
- Branch / inspected HEAD: `agents/board-advisor` / `23ea1fbde29f93ea808528fec4cefd06eae69267`
- Verdict: `REVIEW — BUILD_NOT_STARTED_REGISTRY_GATE_FAIL`

## Governed preflight

| Gate | Evidence | Result |
|---|---|---|
| Approved Strategy Card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1550_bressert-double-cycle-composite-h4.md` declares `ea_id: QM5_1550`, matching slug, and `g0_status: APPROVED` | PASS |
| Exact active EA registry identity | No row begins `1550,` in `framework/registry/ea_id_registry.csv` | FAIL |
| Magic registry | No row begins `1550,` in `framework/registry/magic_numbers.csv` | FAIL |
| Existing source | The canonical EA directory has an `.mq5` skeleton; it does not substitute for governed registry allocation | OBSERVED |

The only slug-related EA registry record is line 3129: `ea_id=12235`, slug
field `QM5_1550_bressert-double-cycle-composite-h4`, status `retired`. It was
retired at `2026-08-21T18:52:34+00:00` under the OWNER-approved D1 disposition
at `docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv`.

Per `qm-build-ea-from-card`, an allocated active EA registry row and magic rows
are mandatory before implementation. No source, registry, resolver, setfile,
or binary was changed, and no compile or pipeline phase was run. Governed
identity/magic allocation or router disposition is required before build.

## Focused verification

```text
rg '^(1550),' framework/registry/ea_id_registry.csv framework/registry/magic_numbers.csv
=> no matches

rg '^(12235),' framework/registry/ea_id_registry.csv
=> 12235,QM5_1550_bressert-double-cycle-composite-h4,...,retired,...
```

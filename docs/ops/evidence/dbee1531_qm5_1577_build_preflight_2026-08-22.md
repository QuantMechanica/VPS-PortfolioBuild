# QM5_1577 build preflight — deterministic stop

- Router task: `dbee1531-c435-46d6-a577-f6b377c2b24d`
- Task type / priority: `build_ea` / `50`
- Canonical checkout: `C:/QM/repo`
- Branch / inspected HEAD: `agents/board-advisor` / `30a2627650d89497bcb10b583e6feb6ec86f639e`
- Verdict: `REVIEW — BUILD_NOT_STARTED_REGISTRY_GATE_FAIL`

## Governed preflight

| Gate | Evidence | Result |
|---|---|---|
| Approved Strategy Card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1577_ehlers-super-smoother-2pole-h4.md` declares `ea_id: QM5_1577`, matching folder slug, and `g0_status: APPROVED` | PASS |
| Exact active EA registry identity | No active row begins `1577,` in `framework/registry/ea_id_registry.csv` | FAIL |
| Magic registry | No row begins `1577,` in `framework/registry/magic_numbers.csv` | FAIL |
| Existing source | The canonical EA directory has only an `.mq5` skeleton; it does not substitute for governed identity allocation | OBSERVED |

The only slug-related EA registry record is line 3131: `ea_id=12237`, slug
field `QM5_1577_ehlers-super-smoother-2pole-h4`, status `retired`. It was retired
at `2026-08-21T18:52:34+00:00` under the OWNER-approved D1 disposition at
`docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv`.

Per `qm-build-ea-from-card`, exact active identity and magic rows are mandatory
before implementation. No source, registry, resolver, setfile, or binary was
changed, and no compile or pipeline phase was run. Governed allocation or
router disposition is required before build.

## Focused verification

```text
rg '^(1577),' framework/registry/ea_id_registry.csv framework/registry/magic_numbers.csv
=> no matches

rg 'ehlers-super-smoother-2pole-h4' framework/registry/ea_id_registry.csv
=> 12237,QM5_1577_ehlers-super-smoother-2pole-h4,...,retired,...
```

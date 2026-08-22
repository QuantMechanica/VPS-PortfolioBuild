# QM5_1531 build preflight — deterministic stop

- Router task: `531a62de-4ce9-4563-9352-edbffe0d6ed1`
- Task type / priority: `build_ea` / `50`
- Canonical checkout: `C:/QM/repo`
- Branch / inspected HEAD: `agents/board-advisor` / `de92bfbaeeb09daddc37c2fdefe1a1ac1b78ae24`
- Verdict: `REVIEW — BUILD_NOT_STARTED_REGISTRY_GATE_FAIL`

## Governed preflight

| Gate | Evidence | Result |
|---|---|---|
| Approved Strategy Card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1531_demark-td-open-bar-reversal-h4.md` declares `ea_id: QM5_1531`, matching slug, and `g0_status: APPROVED` | PASS |
| Exact active EA registry identity | No row begins `1531,` in `framework/registry/ea_id_registry.csv` | FAIL |
| Magic registry | No row begins `1531,` in `framework/registry/magic_numbers.csv` | FAIL |
| Existing source | The canonical EA directory contains only `QM5_1531_demark-td-open-bar-reversal-h4.mq5`; this does not substitute for governed registry allocation | OBSERVED |

The only slug-related EA registry record is line 3124: `ea_id=12230`, slug
field `QM5_1531_demark-td-open-bar-reversal-h4`, status `retired`. It was
retired at `2026-08-21T18:52:34+00:00` under the OWNER-approved D1 disposition
at `docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv`.

Per `qm-build-ea-from-card`, an allocated active EA registry row and magic rows
are mandatory before implementation. No source, registry, resolver, setfile,
or binary was changed, and no compile or pipeline phase was run. Governed
identity/magic allocation or router disposition is required before build.

## Focused verification

```text
rg '^(1531),' framework/registry/ea_id_registry.csv framework/registry/magic_numbers.csv
=> no matches

rg '^(12230),' framework/registry/ea_id_registry.csv
=> 12230,QM5_1531_demark-td-open-bar-reversal-h4,...,retired,...
```

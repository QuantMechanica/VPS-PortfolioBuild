# QM5_1525 build preflight — deterministic stop

- Router task: `b15b055e-d2fe-4f71-8f15-4bdf2f073258`
- Task type / priority: `build_ea` / `50`
- Canonical checkout: `C:/QM/repo`
- Branch / inspected HEAD: `agents/board-advisor` / `b2ff078ee1eb4818b6d8d5cc89e4188270bc083b`
- Verdict: `REVIEW — BUILD_NOT_STARTED_REGISTRY_GATE_FAIL`

## Governed preflight

| Gate | Evidence | Result |
|---|---|---|
| Approved Strategy Card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1525_ehlers-empirical-mode-decomp-h4.md` declares `ea_id: QM5_1525`, matching slug, and `g0_status: APPROVED` | PASS |
| Exact active EA registry identity | No row begins `1525,` in `framework/registry/ea_id_registry.csv` | FAIL |
| Magic registry | No row begins `1525,` in `framework/registry/magic_numbers.csv` | FAIL |
| Existing source | The canonical EA directory contains only `QM5_1525_ehlers-empirical-mode-decomp-h4.mq5`; this does not substitute for governed registry allocation | OBSERVED |

The only slug-related EA registry record is line 3119: `ea_id=12225`, slug field `QM5_1525_ehlers-empirical-mode-decomp-h4`, status `retired`. It was retired at `2026-08-21T18:52:34+00:00` under the OWNER-approved D1 disposition recorded at `docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv`.

Per `qm-build-ea-from-card`, an allocated active EA registry row and magic rows are mandatory before implementation. No source, registry, resolver, setfile, or binary was changed, and no compile or pipeline phase was run. The task requires governed identity/magic allocation or router disposition before a build can start.

## Focused verification

```text
rg '^(1525),' framework/registry/ea_id_registry.csv framework/registry/magic_numbers.csv
=> no matches

rg '^(12225),' framework/registry/ea_id_registry.csv
=> 12225,QM5_1525_ehlers-empirical-mode-decomp-h4,...,retired,...
```

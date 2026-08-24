# QM5_9225 build preflight refusal

- Checked at: `2026-08-24T01:48:04Z`
- Router task: `973e3dce-3504-408a-8c8e-89de1eab6366`
- Task type / priority: `build_ea` / `10`
- Requested EA: `QM5_9225_mql5-rvi-ma`
- Verdict: `BUILD_REFUSED_PRECONDITION`

## Deterministic preflight

| Gate | Evidence | Result |
|---|---|---|
| Approved card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9225_mql5-rvi-ma.md` has `g0_status: APPROVED`, `ea_id: QM5_9225`, and `slug: mql5-rvi-ma` | PASS |
| EA registry | `framework/registry/ea_id_registry.csv` has one active row: `9225,mql5-rvi-ma` | PASS |
| Magic registry | `framework/registry/magic_numbers.csv` has zero rows with `ea_id=9225`; the card requires slots for `EURUSD.DWX`, `GBPUSD.DWX`, and `XAUUSD.DWX` | **FAIL** |
| Existing folder | `framework/EAs/QM5_9225_mql5-rvi-ma/` contains only `QM5_9225_mql5-rvi-ma.mq5` (4,082 bytes; SHA-256 `2244ce3a3b0c25e8d9d255cb4df7f221d60581c3f2147f8744be2dfb2abd2d96`) | Incomplete; no `.ex5`, setfiles, card copy, or `SPEC.md` |

## Disposition

The governed `qm-build-ea-from-card` contract requires active magic rows before the build step and forbids the builder from allocating them. No EA source, registry, resolver, setfile, or pipeline artifact was changed, and no compile or pipeline phase was run.

Required upstream action: allocate active magic rows for EA 9225 and every card symbol, regenerate `QM_MagicResolver.mqh`, and verify that regeneration retains the rows. Then recycle the build task.

# QM5_9215 build preflight refusal

- Checked at: `2026-08-24T01:34:21Z`
- Router task: `52ee2c30-429a-4eed-b0e5-b00379fcd0f0`
- Task type / priority: `build_ea` / `10`
- Requested EA: `QM5_9215_mql5-bear-ema`
- Verdict: `BUILD_REFUSED_PRECONDITION`

## Deterministic preflight

| Gate | Evidence | Result |
|---|---|---|
| Approved card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9215_mql5-bear-ema.md` has `g0_status: APPROVED`, `ea_id: QM5_9215`, and `slug: mql5-bear-ema` | PASS |
| EA registry | `framework/registry/ea_id_registry.csv` has one active row: `9215,mql5-bear-ema` | PASS |
| Magic registry | `framework/registry/magic_numbers.csv` has zero rows with `ea_id=9215`; the card requires slots for `EURUSD.DWX`, `GBPUSD.DWX`, and `XAUUSD.DWX` | **FAIL** |
| Existing folder | `framework/EAs/QM5_9215_mql5-bear-ema/` contains only `QM5_9215_mql5-bear-ema.mq5` (4,082 bytes; SHA-256 `17414fc8889f9a5a6d1d260e215008ec485bb7064893ac84dbf24dd8035cf2a7`) | Incomplete; no `.ex5`, setfiles, card copy, or `SPEC.md` |

## Disposition

The governed `qm-build-ea-from-card` contract requires active magic rows before the build step and forbids the builder from allocating them. No EA source, registry, resolver, setfile, or pipeline artifact was changed, and no compile or pipeline phase was run.

Required upstream action: allocate active magic rows for EA 9215 and every card symbol, regenerate `QM_MagicResolver.mqh`, and verify that regeneration retains the rows. Then recycle the build task.

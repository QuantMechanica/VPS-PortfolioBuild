# QM5_9211 build preflight refusal

- Checked at: `2026-08-24T01:34:21Z`
- Router task: `7b3784ed-633a-45c9-9762-707630923a80`
- Task type / priority: `build_ea` / `10`
- Requested EA: `QM5_9211_mql5-trendloom`
- Verdict: `BUILD_REFUSED_PRECONDITION`

## Deterministic preflight

| Gate | Evidence | Result |
|---|---|---|
| Approved card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9211_mql5-trendloom.md` has `g0_status: APPROVED`, `ea_id: QM5_9211`, and `slug: mql5-trendloom` | PASS |
| EA registry | `framework/registry/ea_id_registry.csv` has one active row: `9211,mql5-trendloom` | PASS |
| Magic registry | `framework/registry/magic_numbers.csv` has zero rows with `ea_id=9211`; the card requires slots for `EURUSD.DWX`, `GBPUSD.DWX`, and `XAUUSD.DWX` | **FAIL** |
| Existing folder | `framework/EAs/QM5_9211_mql5-trendloom/` contains only `QM5_9211_mql5-trendloom.mq5` (4,082 bytes; SHA-256 `d5579501f9a3d6732534e7e9449ed3c9619c9edc047352a0a2e78855825cf7ba`) | Incomplete; no `.ex5`, setfiles, card copy, or `SPEC.md` |

## Disposition

The governed `qm-build-ea-from-card` contract requires active magic rows before the build step and forbids the builder from allocating them. No EA source, registry, resolver, setfile, or pipeline artifact was changed, and no compile or pipeline phase was run.

Required upstream action: allocate active magic rows for EA 9211 and every card symbol, regenerate `QM_MagicResolver.mqh`, and verify that regeneration retains the rows. Then recycle the build task.

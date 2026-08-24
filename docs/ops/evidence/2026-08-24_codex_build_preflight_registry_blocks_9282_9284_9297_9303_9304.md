# Codex build preflight: registry blocks for QM5_9282, QM5_9284, QM5_9297, QM5_9303, and QM5_9304

- Cycle: headless Codex single-pass orchestration
- Verified at: `2026-08-24T02:50:54.9837737Z`
- Task workspace: `C:/QM/worktrees/codex-orchestration-1`
- Canonical checkout: `C:/QM/repo`
- Canonical checkout HEAD before this evidence commit: `58390b67c5437eaf31b7aacee2f5ec28e66c6031`
- Build contract: `qm-build-ea-from-card`

## Scope

The deterministic router assigned five priority-10 `build_ea` tasks to Codex. The router already owns their spawn leases. This artifact records the governed V5 preflight. It does not allocate registry rows, alter EA source, compile, run a pipeline phase, or change live/terminal state.

| task_id | ea_id | requested slug |
|---|---:|---|
| `c0bb9235-3d6e-4d0f-a688-e8276b939e47` | 9282 | `demark-td-stress-h4` |
| `6a0ae4d5-66d4-4a37-9323-38e1224236db` | 9284 | `brooks-tight-trading-range-h4` |
| `5371ab7c-d88f-4452-a3c3-a338edcb5d28` | 9297 | `mql5-cmf-ma-cross` |
| `d82200c3-e4bc-429b-8be1-d20c0f6b5a21` | 9303 | `mql5-ma-rsi-day` |
| `0bf5bbf0-59b6-4f88-b50d-de609d881642` | 9304 | `mql5-nrtr-flip` |

## Deterministic preflight result

All five runtime cards exist under `D:/QM/strategy_farm/artifacts/cards_approved/`, declare the requested EA ID and slug, and have `g0_status: APPROVED`. None passes the complete registry contract required to start a V5 build.

| ea_id | approved card | active EA registry identity | active magic rows | first failed gate | verdict |
|---:|---|---|---:|---|---|
| 9282 | `QM5_9282_demark-td-stress-h4.md` | `9282,mql5-keltner-rebound,...,active` | 0 | mandatory card/registry slug match | Stop: `ea_id` 9282 is allocated to a different active slug. |
| 9284 | `QM5_9284_brooks-tight-trading-range-h4.md` | no row for EA ID 9284 | 0 | allocated active EA ID row | Stop: EA ID 9284 is unregistered. The retired row whose slug text contains `QM5_9284_...` is EA ID 12345 and is not an allocation for 9284. |
| 9297 | `QM5_9297_mql5-cmf-ma-cross.md` | `9297,mql5-cmf-ma-cross,...,active` | 0 | magic rows for every symbol slot | Stop: no governed magic rows exist. |
| 9303 | `QM5_9303_mql5-ma-rsi-day.md` | `9303,mql5-ma-rsi-day,...,active` | 0 | magic rows for every symbol slot | Stop: no governed magic rows exist. |
| 9304 | `QM5_9304_mql5-nrtr-flip.md` | `9304,mql5-nrtr-flip,...,active` | 0 | magic rows for every symbol slot | Stop: no governed magic rows exist. |

The approved cards for 9297, 9303, and 9304 each target `EURUSD.DWX`, `GBPUSD.DWX`, `XAUUSD.DWX`, and `GER40.DWX`, so their build step requires active magic rows covering all four governed symbol slots. Codex is not authorized to allocate those rows.

## Existing artifact inspection

Each canonical EA directory exists, but each contains only one 4,082-byte `.mq5` source file dated 2026-07-10 UTC:

- `framework/EAs/QM5_9282_demark-td-stress-h4/QM5_9282_demark-td-stress-h4.mq5`
- `framework/EAs/QM5_9284_brooks-tight-trading-range-h4/QM5_9284_brooks-tight-trading-range-h4.mq5`
- `framework/EAs/QM5_9297_mql5-cmf-ma-cross/QM5_9297_mql5-cmf-ma-cross.mq5`
- `framework/EAs/QM5_9303_mql5-ma-rsi-day/QM5_9303_mql5-ma-rsi-day.mq5`
- `framework/EAs/QM5_9304_mql5-nrtr-flip/QM5_9304_mql5-nrtr-flip.mq5`

No directory contains a compiled `.ex5`, `SPEC.md`, canonical setfile, or copied strategy card. Their presence therefore does not satisfy the build contract or change the failed registry gates.

## Reproducible verification

Registry checks were run against the canonical checkout:

```powershell
rg -n "(^|,)(9282|9284|9297|9303|9304)(,|$)|mql5-nrtr-flip|mql5-ma-rsi-day|mql5-cmf-ma-cross|brooks-tight-trading-range-h4|demark-td-stress-h4" C:/QM/repo/framework/registry/ea_id_registry.csv C:/QM/repo/framework/registry/magic_numbers.csv
rg -n "9282|9284|9297|9303|9304" C:/QM/repo/framework/registry/magic_numbers.csv
```

The first command returned the active 9282, 9297, 9303, and 9304 EA-registry rows plus the unrelated retired EA-ID-12345 row. The second command returned no matches. Direct inspection confirmed the magic registry schema begins `ea_id,ea_slug,symbol_slot,symbol,magic,...`.

Input hashes at verification time:

| input | SHA-256 |
|---|---|
| approved card QM5_9282 | `4C5B7538A08359135E6B1434EEF51CEC6C9B66857810E82321191F5FA8F5C348` |
| approved card QM5_9284 | `25A6C434B82680B1C4A59E5591BB6AA5AA5BDA5C4AF7546E299F8C3A1997E256` |
| approved card QM5_9297 | `7B07A9AE4E6D3B07E2883C7D6B4D79F950FF35E3CC1032108CA7DC6793A9091A` |
| approved card QM5_9303 | `C33988D1F8391F4FFF017687F5E3C062C21A9B3409188E96BA45FD29871EA452` |
| approved card QM5_9304 | `2D3061054AA683360F96262F239E9F8AAC94C3A6EA9B683574729CFBEF515F75` |
| `ea_id_registry.csv` | `4A0ABB97B79DF767FCB1571AADBF9D3DC349C22088B9980C6BEB50072B530A4F` |
| `magic_numbers.csv` | `1A30B5DF1986A641CB0F3BB6BE57D643CC003DCB3EC77ACA17C4636CCF930B1E` |

## Review verdict and unblock

`PRECHECK_FAIL`: the V5 build contract says to stop on any missing or mismatched registry precondition. No compile or pipeline verdict was manufactured, and no source, setfile, registry, framework, terminal, T_Live, or AutoTrading state was changed.

Required governed unblock:

1. Resolve the 9282 card/registry identity collision without overwriting the existing active allocation.
2. Allocate an active EA-registry identity for 9284.
3. Allocate active magic rows for every approved symbol slot for all five final identities, then regenerate and verify the magic resolver without dropped rows.
4. Reroute the build tasks only after the registries satisfy the preflight contract.


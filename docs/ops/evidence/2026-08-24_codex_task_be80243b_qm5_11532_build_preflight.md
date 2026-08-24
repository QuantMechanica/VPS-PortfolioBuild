# QM5_11532 build preflight — router task be80243b

- Checked at: `2026-08-24T03:26:14Z`
- Router task: `be80243b-1365-4e65-b5b5-68bdbc3b805a`
- Task type / priority: `build_ea` / `10`
- Canonical branch: `agents/board-advisor`
- Pre-evidence HEAD: `2556f74850c808570aaf68b77e0f352ce25c0f82`
- Procedure: `qm-build-ea-from-card`

## Verdict

`PRECHECK_FAIL: EA_ID_REGISTRY_NOT_ACTIVE`

The build is not admissible. The approved card, EA directory, source, binary, and active magic rows for both approved symbols exist, but `framework/registry/ea_id_registry.csv` still records EA 11532 with `status=pending`. Canonical compile admission requires exactly one matching EA row whose status is `active`; `tools/strategy_farm/compile_work_items.py` emits `EA_ID_REGISTRY_NOT_ACTIVE` otherwise. The build skill requires stopping at a failed registry preflight.

This is build-preflight evidence only. It is not a compile PASS and not a pipeline verdict.

## Evidence

| Check | Observation |
|---|---|
| Approved card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11532_carter-t-h1-ema5-15-60-pullback.md` |
| Card authorization | `g0_status: APPROVED` |
| Card SHA-256 | `bc7842e4bbc2e4f5faca20fa5d47da259783c77fde06fca6000db3feb37e743b` |
| Card targets | `EURUSD.DWX`, `GBPUSD.DWX`; timeframe `H1` |
| Card / folder / registry slug | `carter-t-h1-ema5-15-60-pullback` in all three locations |
| EA registry | one row; `ea_id=11532`; `status=pending` |
| Active magic rows | two: `EURUSD.DWX`, `GBPUSD.DWX` |
| Source | present and path-clean; SHA-256 `b5d7b69ed1a623025f4b23101e4075cfe8dc4c8237c59b8257a949c0a1aace56` |
| Binary | `.ex5` present |
| Canonical sets | zero |
| Registry snapshots | EA registry SHA-256 `4a0abb97b79df767fcb1571aadbf9d3dc349c22088b9980c6beb50072b530a4f`; magic registry SHA-256 `1a30b5df1986a641cb0f3bb6be57d643cc003dcb3ec77aca17c4636ccf930b1e` |

Focused verification used `Import-Csv` against both deterministic registries, exact card front-matter reads, `Get-FileHash -Algorithm SHA256`, on-disk source/binary/set counts, and `git status --porcelain=v1 -- <EA directory>`. The EA path had no uncommitted changes before this evidence was authored.

## Router disposition

The required `update-task ... --state REVIEW` dispatch was attempted with this evidence path. The canonical router refused it with `D6_BUILD_IDENTITY_MISSING` / `build_identity_json_missing_review_dispatch_refused`. A prose preflight report cannot impersonate the required strict-PASS, hash-bound `build_identity.json`, so no build identity was fabricated. This task is returned to `BLOCKED` with this artifact and verdict until the governed prerequisite is repaired.

## Governed next action

The registry-writer lane must make the already allocated EA identity active and verify its identity remains unique. The task payload names tracking task `8d1d903f-39cc-461f-ab90-7b932ce62fee`. Only after that gate passes should a routed build task author the required backtest sets (`RISK_FIXED > 0`, `RISK_PERCENT = 0`), run strict compile/build checks, and submit the resulting build artifact for review.

No registry, resolver, EA source, binary, setfile, terminal, AutoTrading, or pipeline state was changed during this handling.

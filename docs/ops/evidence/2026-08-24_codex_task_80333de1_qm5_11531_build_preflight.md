# QM5_11531 build preflight — router task 80333de1

- Checked at: `2026-08-24T03:20:08Z`
- Router task: `80333de1-acfc-472d-9291-dc0a78fe4a25`
- Task type / priority: `build_ea` / `10`
- Canonical branch: `agents/board-advisor`
- Pre-evidence HEAD: `9fc2def1ebe774f66e27954d173da06b772cfaae`
- Procedure: `qm-build-ea-from-card`

## Verdict

`PRECHECK_FAIL: EA_ID_REGISTRY_NOT_ACTIVE`

The build is not admissible. The approved card, EA directory, source, binary, and one active magic row exist, but `framework/registry/ea_id_registry.csv` still records EA 11531 with `status=pending`. Canonical compile admission requires exactly one matching EA row whose status is `active`; `tools/strategy_farm/compile_work_items.py` emits `EA_ID_REGISTRY_NOT_ACTIVE` otherwise. The build skill requires stopping at a failed registry preflight.

This is build-preflight evidence only. It is not a compile PASS and not a pipeline verdict.

## Evidence

| Check | Observation |
|---|---|
| Approved card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11531_carter-t-h1-ema6-23-stoch-macd.md` |
| Card authorization | `g0_status: APPROVED` |
| Card SHA-256 | `a5061ddee0ed44241dd5178b0dd1aa64684b5fc6f377b07cb2062c6926881cd9` |
| Card / folder / registry slug | `carter-t-h1-ema6-23-stoch-macd` in all three locations |
| EA registry | one row; `ea_id=11531`; `status=pending` |
| Active magic rows | one: slot `0`, `EURUSD.DWX`, magic `115310000` |
| Source | present and path-clean; SHA-256 `70a70e0c81a11ee87be8dea9874a57325310fba2602443f6d8a804f1a1468cc8` |
| Binary | `.ex5` present |
| Canonical sets | zero |
| Registry snapshots | EA registry SHA-256 `4a0abb97b79df767fcb1571aadbf9d3dc349c22088b9980c6beb50072b530a4f`; magic registry SHA-256 `1a30b5df1986a641cb0f3bb6be57d643cc003dcb3ec77aca17c4636ccf930b1e` |

Focused verification used `Import-Csv` against both deterministic registries, exact card front-matter reads, `Get-FileHash -Algorithm SHA256`, on-disk source/binary/set counts, and `git status --porcelain=v1 -- <EA directory>`. The EA path had no uncommitted changes before this evidence was authored.

## Router disposition

The required `update-task ... --state REVIEW` dispatch was attempted with this evidence path. The canonical router refused it with `D6_BUILD_IDENTITY_MISSING` / `build_identity_json_missing_review_dispatch_refused`. That is the intended fail-closed behavior: a prose preflight report cannot impersonate the required strict-PASS, hash-bound `build_identity.json`. No build identity was fabricated. Consistent with recent registry-preflight cases, this task is therefore returned to `BLOCKED` with this artifact and verdict until the governed prerequisite is repaired.

## Governed next action

The registry-writer lane must make the already allocated EA identity active and verify its identity remains unique. The task payload names tracking task `8d1d903f-39cc-461f-ab90-7b932ce62fee`. Only after that gate passes should a routed build task author the required backtest set (`RISK_FIXED > 0`, `RISK_PERCENT = 0`), run strict compile/build checks, and submit the resulting build artifact for review.

No registry, resolver, EA source, binary, setfile, terminal, AutoTrading, or pipeline state was changed during this handling.

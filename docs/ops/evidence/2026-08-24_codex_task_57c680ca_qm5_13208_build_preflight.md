# QM5_13208 build preflight — router task 57c680ca

- Checked at: `2026-08-24T03:26:14Z`
- Router task: `57c680ca-a82c-4e84-950a-71ac938b4bb6`
- Task type / priority: `build_ea` / `10`
- Canonical branch: `agents/board-advisor`
- Pre-evidence HEAD: `2556f74850c808570aaf68b77e0f352ce25c0f82`
- Procedure: `qm-build-ea-from-card`

## Verdict

`PRECHECK_FAIL: ACTIVE_MAGIC_ROWS_MISSING; ACTIVE_MAGIC_SYMBOLS_MISSING`

The build is not admissible. EA 13208 has an active, slug-matching EA registry row, but it has zero active rows in `framework/registry/magic_numbers.csv`. The approved card requires `XAUUSD.DWX` and `EURUSD.DWX`. Canonical compile admission emits `ACTIVE_MAGIC_ROWS_MISSING` and `ACTIVE_MAGIC_SYMBOLS_MISSING` when no active magic rows or symbols are bound. The build skill forbids allocating magic rows and requires stopping at this failed preflight.

This is build-preflight evidence only. It is not a compile PASS and not a pipeline verdict.

## Evidence

| Check | Observation |
|---|---|
| Approved card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_13208_mulham-4h-sweep-fvg.md` |
| Card authorization | `g0_status: APPROVED` |
| Card SHA-256 | `081909eb82278a71a5466989064b38175fc001584ff40525f12e5660486d2444` |
| Card targets | `XAUUSD.DWX`, `EURUSD.DWX`; timeframe `M15` |
| Card / folder / registry slug | `mulham-4h-sweep-fvg` in all three locations |
| EA registry | one row; `ea_id=13208`; `status=active` |
| Active magic rows | zero |
| Source | present and path-clean; SHA-256 `bdbb74a6ba9b35bca76744bd6b2f0a1902ba0e3b60ae42fa789879e5df5aa6d2` |
| Binary | `.ex5` absent |
| Canonical sets | zero |
| Registry snapshots | EA registry SHA-256 `4a0abb97b79df767fcb1571aadbf9d3dc349c22088b9980c6beb50072b530a4f`; magic registry SHA-256 `1a30b5df1986a641cb0f3bb6be57d643cc003dcb3ec77aca17c4636ccf930b1e` |

Focused verification used `Import-Csv` against both deterministic registries, exact card front-matter reads, `Get-FileHash -Algorithm SHA256`, on-disk source/binary/set counts, and `git status --porcelain=v1 -- <EA directory>`. The EA path had no uncommitted changes before this evidence was authored.

## Router disposition

The required `update-task ... --state REVIEW` dispatch was attempted with this evidence path. The canonical router refused it with `D6_BUILD_IDENTITY_MISSING` / `build_identity_json_missing_review_dispatch_refused`. A prose preflight report cannot impersonate the required strict-PASS, hash-bound `build_identity.json`, so no build identity was fabricated. This task is returned to `BLOCKED` with this artifact and verdict until the governed prerequisite is repaired.

## Governed next action

The EA directory already exists, satisfying the required directory-first ordering. The registry-writer lane must allocate active magic rows for every approved symbol, regenerate `QM_MagicResolver.mqh`, and verify no row was dropped. The task payload names tracking task `8d1d903f-39cc-461f-ab90-7b932ce62fee`. Only after that gate passes should the deterministic router return the build to Codex for source review, canonical backtest sets (`RISK_FIXED > 0`, `RISK_PERCENT = 0`), and strict compilation.

No registry, resolver, EA source, binary, setfile, terminal, AutoTrading, or pipeline state was changed during this handling.

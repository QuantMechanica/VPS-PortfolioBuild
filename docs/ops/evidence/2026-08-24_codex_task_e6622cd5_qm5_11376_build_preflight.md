# QM5_11376 build preflight — router task e6622cd5

- Checked at: `2026-08-24T03:20:08Z`
- Router task: `e6622cd5-4136-46d8-a294-e89cef17e8cd`
- Task type / priority: `build_ea` / `10`
- Canonical branch: `agents/board-advisor`
- Pre-evidence HEAD: `9fc2def1ebe774f66e27954d173da06b772cfaae`
- Procedure: `qm-build-ea-from-card`

## Verdict

`PRECHECK_FAIL: ACTIVE_MAGIC_ROWS_MISSING; ACTIVE_MAGIC_SYMBOLS_MISSING`

The build is not admissible. EA 11376 has an active, slug-matching EA registry row, but it has zero active rows in `framework/registry/magic_numbers.csv`. The approved card requires `EURUSD.DWX`, `GBPUSD.DWX`, and `USDJPY.DWX`. Canonical compile admission emits `ACTIVE_MAGIC_ROWS_MISSING` and `ACTIVE_MAGIC_SYMBOLS_MISSING` when no active magic rows or symbols are bound. The build skill forbids allocating magic rows and requires stopping at this failed preflight.

This is build-preflight evidence only. It is not a compile PASS and not a pipeline verdict.

## Evidence

| Check | Observation |
|---|---|
| Approved card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11376_4h-macd-5-13-ma5-cascade-h4.md` |
| Card authorization | `g0_status: APPROVED` |
| Card SHA-256 | `7fde989c7e1eda7e9f6e234adbdbbff364aabd5f3cc4160f7f0729dcb987023a` |
| Card targets | `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`; timeframe `H4` |
| Card / folder / registry slug | `4h-macd-5-13-ma5-cascade-h4` in all three locations |
| EA registry | one row; `ea_id=11376`; `status=active` |
| Active magic rows | zero |
| Source | present and path-clean; SHA-256 `6f2669284d8fa1656ec96110bceb4e9ea33642a5c551ebdce0cf00670b7f1d95` |
| Binary | `.ex5` absent |
| Canonical sets | zero |
| Registry snapshots | EA registry SHA-256 `4a0abb97b79df767fcb1571aadbf9d3dc349c22088b9980c6beb50072b530a4f`; magic registry SHA-256 `1a30b5df1986a641cb0f3bb6be57d643cc003dcb3ec77aca17c4636ccf930b1e` |

Focused verification used `Import-Csv` against both deterministic registries, exact card front-matter reads, `Get-FileHash -Algorithm SHA256`, on-disk source/binary/set counts, and `git status --porcelain=v1 -- <EA directory>`. The EA path had no uncommitted changes before this evidence was authored.

## Governed next action

The EA directory already exists, satisfying the required directory-first ordering. The registry-writer lane must allocate active magic rows for every approved symbol, regenerate `QM_MagicResolver.mqh`, and verify no row was dropped. The task payload names tracking task `8d1d903f-39cc-461f-ab90-7b932ce62fee`. Only after that gate passes should the deterministic router return the build to Codex for source review, canonical backtest sets (`RISK_FIXED > 0`, `RISK_PERCENT = 0`), and strict compilation.

No registry, resolver, EA source, binary, setfile, terminal, AutoTrading, or pipeline state was changed during this handling.

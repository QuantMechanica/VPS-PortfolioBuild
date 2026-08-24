# Codex build preflight — missing identities for QM5_1528, QM5_1338, and QM5_1323

- Checked at: `2026-08-24T03:28:24Z`
- Task type / priority: `build_ea` / `10`
- Canonical branch: `agents/board-advisor`
- Pre-evidence HEAD: `27dcb6ba3e67cc53c37821a6a56df031aa20fb45`
- Procedure: `qm-build-ea-from-card`

## Verdict

`PRECHECK_FAIL: EA_ID_REGISTRY_IDENTITY_INVALID; ACTIVE_MAGIC_ROWS_MISSING`

All three builds are inadmissible. Their approved cards and slug-matching EA directories exist, but exact numeric parsing of `framework/registry/ea_id_registry.csv` returns zero rows for EA IDs 1528, 1338, and 1323. Exact parsing of `framework/registry/magic_numbers.csv` also returns zero active rows for each ID. Canonical compile admission emits `EA_ID_REGISTRY_IDENTITY_INVALID` when the EA registry does not contain exactly one identity row. The build skill requires stopping at that first failed gate and forbids Development from allocating identities or magic rows.

This is build-preflight evidence only. It is not a compile PASS and not a pipeline verdict.

## Routed tasks and evidence

| Router task | EA / slug | Approved targets | Card SHA-256 | Source SHA-256 | EA rows | Active magic rows | On-disk state |
|---|---|---|---|---|---:|---:|---|
| `33a13dd3-49f4-474d-a85b-c013a0b72c5e` | `QM5_1528_hopwood-pause-ea-h4` | EURUSD, GBPUSD, USDJPY, XAUUSD `.DWX` | `e32e95dfb0bcc988c521b98c77bd35e5c9d629de7d661770fa5c43359ba378fc` | `a23fca9b3338a7a247989c05c0ad3a394cd9c53fd03a7d74a69aad65b670a78f` | 0 | 0 | clean MQ5; no EX5; zero sets |
| `886ebc65-07f3-4bee-9d95-c8abc29cc4a9` | `QM5_1338_nnfx-baseline-2confirm-h4` | EURUSD, GBPUSD, USDJPY, AUDUSD, NZDUSD, USDCAD, USDCHF, XAUUSD `.DWX` | `32b4eb3efee1d9679a880654f477ec284a526c9412d601f0f85c4e3939af57a9` | `225596b4119e62a7faf7e9375b66f4063ba9fb16053079ac74831ef90b08256f` | 0 | 0 | clean MQ5; no EX5; zero sets |
| `32e32389-8319-488b-b7b2-29407a7325a5` | `QM5_1323_tom-fps-donchian-h4` | EURUSD, GBPUSD, USDJPY, AUDUSD, XAUUSD, NDX `.DWX` | `35d943e9e9ba37364b6da70a6fb182d1181cb9208a1bbbaceb35d6e952d7d0dc` | `568387d6f228170b47109593e56acf94e1712da5e144d20e4ddcdbd5d14a3134` | 0 | 0 | clean MQ5; no EX5; zero sets |

Every referenced runtime card exists under `D:/QM/strategy_farm/artifacts/cards_approved/`, declares `g0_status: APPROVED`, and carries the slug shown above. Card, folder, and task slugs agree.

Registry snapshot hashes at verification time:

- `ea_id_registry.csv`: `4a0abb97b79df767fcb1571aadbf9d3dc349c22088b9980c6beb50072b530a4f`
- `magic_numbers.csv`: `1a30b5df1986a641cb0f3bb6be57d643cc003dcb3ec77aca17c4636ccf930b1e`

Focused verification used `Import-Csv` with exact numeric equality, exact card front-matter reads, `Get-FileHash -Algorithm SHA256`, source/binary/set counts, and `git status --porcelain=v1 -- <EA directory>`. None of the three EA paths had uncommitted changes before this evidence was authored.

## Router disposition

`update-task ... --state REVIEW` was attempted for all three tasks with this evidence path. The canonical router refused every dispatch with `D6_BUILD_IDENTITY_MISSING` / `build_identity_json_missing_review_dispatch_refused`. A preflight report cannot impersonate the required strict-PASS, hash-bound `build_identity.json`; none was fabricated. The tasks are therefore returned to `BLOCKED` with this artifact and their preflight verdicts until the governed prerequisites are repaired.

## Governed next action

The registry-writer lane must allocate or otherwise adjudicate the three card-declared identities, allocate active magic rows for every approved symbol, regenerate `QM_MagicResolver.mqh`, and verify no row was dropped. The task payloads name tracking task `8d1d903f-39cc-461f-ab90-7b932ce62fee`. Only after those gates pass should the deterministic router return builds to Codex for source review, canonical backtest sets (`RISK_FIXED > 0`, `RISK_PERCENT = 0`), and strict compilation.

No registry, resolver, EA source, binary, setfile, terminal, AutoTrading, or pipeline state was changed during this handling.

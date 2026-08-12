# Execution-contract residual triage — 2026-07-29

## Result

The execution-contract linter now treats checkout-only CRLF/LF changes as the
same input **only** for a dependency that is both inside `repo_root` and reported
by Git as tracked text. It first accepts the declared raw-byte hash; only after a
raw mismatch does it compare the Git-LF form. Untracked or external dependencies,
FTMO calendar sources, and `runtime_binding.setfile` remain raw-byte exact.

This removes all 27 false `dependency_hash_mismatch` findings caused by the
machine-wide `core.autocrlf=true` checkout. It does not rebind a registry entry or
make a stale runtime artifact look current.

| Scope | Before | After | Disposition |
|---|---:|---:|---|
| Complete registry | 76 issues | 49 issues | 27 checkout-EOL false positives removed |
| Density cohort | 52 issues | 25 issues | only stale SET bindings remain |
| QM5_20009 calendar cohort | 24 issues | 24 issues | external source/copy drift remains fail-closed |

## Remaining density SET bindings

The remaining 25 findings are all `runtime_setfile_hash_mismatch`:

| EA | Count |
|---:|---:|
| 20030 | 1 |
| 20031 | 2 |
| 20032 | 2 |
| 20033 | 4 |
| 20034 | 2 |
| 20037 | 1 |
| 20038 | 2 |
| 20039 | 2 |
| 20040 | 3 |
| 20041 | 2 |
| 20044 | 2 |
| 20045 | 2 |

For each of these 25 files, the declared hash matches neither the current LF
blob, the current CRLF checkout bytes, nor an LF/CRLF form of any tracked version
in that file's Git history. The three QM5_20043 SET bindings are the control:
they still match their declared raw CRLF hashes. Therefore the 25 mismatches are
not newline noise. Updating them requires a provenance-backed runtime-binding
decision; mechanically pinning the current working files would invent evidence.

## QM5_20009 external calendar drift

The declared 2026-07-24 hashes still match both QMDev1 Common copies exactly.
The shared `D:\QM` files have independently advanced to 2026-07-31:

| Role/path | Rows | Coverage | SHA-256 |
|---|---:|---|---|
| `D:\QM\data\news_calendar\news_calendar_2015_2025.csv` | 48,150 | 2015-01-01..2026-07-31 | `16d95a7ca00de57accbb2bf7ad63418873c7c1afbffd58b8ec35136abb057ece` |
| `D:\QM\data\news_calendar\forex_factory_calendar_clean.csv` | 48,159 | 2015-01-01..2026-07-31 | `e54a18bc317657260edb01a57eb29e97d7c1e3c451a2befc60dbc636d9286338` |
| `C:\Users\QMDev1\AppData\Roaming\MetaQuotes\Terminal\Common\Files\news_calendar_2015_2025.csv` | 48,057 | 2015-01-01..2026-07-24 | `8e898ca1c4aed5fbc4cbe43fc176e8d8595c2e6f5f05c2984c2468527d4f5b0d` |
| `C:\Users\QMDev1\AppData\Roaming\MetaQuotes\Terminal\Common\Files\forex_factory_calendar_clean.csv` | 48,066 | 2015-01-01..2026-07-24 | `3cf4b7d881b62105b70e34cb8400caa6c393b85743cce8046085c680ae05f3d1` |

Each of the four QM5_20009 sleeves therefore correctly reports two source-hash,
two coverage, and two copy-drift findings. Remediation requires validating the
new shared snapshot, synchronizing the two external source pairs atomically, and
then making an authorized registry/test rebind. No external file was changed.

## Verification

- New LF/CRLF and negative-boundary regression tests: 2 passed.
- Full `test_execution_contract_lint.py`: 48 passed, 3 expected residual tests
  failed (global registry cleanliness, density cleanliness, QM5_20009 exact
  calendar binding).
- Factory state, `D:\QM`, T_Live, and AutoTrading were not changed.

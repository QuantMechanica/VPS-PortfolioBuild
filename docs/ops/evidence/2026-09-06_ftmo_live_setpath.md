# FTMO live-mode trial set path — REVIEW

Router task `dfb6c2ba-a090-424a-a0c6-46c4544486ad`, 2026-09-06.
Code: `C:/QM/worktrees/codex-ftmo-live-setpath-20260906`, branch `agents/codex-ftmo-live-setpath-20260906`, commit `3eb51cfbfa`.

Implemented `tools/strategy_farm/ftmo/trial_setpath.py`. It reads the canonical farm database read-only, requires CONFIG_LOCKED evidence (adjudication v2/v3), checks the sealed baseline set hash and any populated database set hash, and derives a fresh batch only after validating all eight candidates. It never writes active EA sets or terminal directories. The only CLI output choice is a safe run name below `D:/QM/strategy_farm/artifacts/ftmo_trial_sets_review/`; traversal, redirected roots and existing destinations are refused.

The source is the **baseline bound inside the seal**, not the chosen news-arm set. All non-allowlisted inputs are byte-value identical, including magic slot and portfolio weight. Only RISK_FIXED, RISK_PERCENT and three explicit news compliance inputs may differ. The output uses RISK_FIXED=0, RISK_PERCENT=0.1 (dry-run example, no sizing authority), PRE30_POST30 temporal blackout, FTMO compliance and a positive stale-news ceiling no greater than 336. The existing generator represents environment in provenance comments: these EAs have no ENV input. The manifest and output comment therefore say environment=live without inventing an ignored ENV parameter. Live calendar binding is native MT5 calendar; the tester-only calendar bundle inputs are not presented as a live binding.

The manifest binds each source/seal/output SHA-256, the source binary identity, complete before/after compliance changes and frozen-parameter identity hash. It binds the FTMO Swing rulepack hash and validates its daily <=5% / total <=10% limits. These are **manifest constraints**, not a claim that writing a set installs an account governor. All outputs declare INERT_REVIEW_ONLY, installable=false and installed=false. Trial governor acceptance, current news health, broker-native symbol compatibility and authorized risk sizing are mandatory before a separate installation action. Source symbol provenance remains unchanged; native-symbol mapping is recorded separately.

## Verification

`python -m pytest -q tools/strategy_farm/tests/test_ftmo_trial_setpath.py`: **17 passed**. Earlier collection failed because the sparse checkout omitted shared fixture dependencies; adding the tracked config/framework/portfolio paths resolved collection. Tests cover unsealed source, source drift, altered strategy input, duplicate parameters, optimizer ranges, invalid risk, stale-news weakening, traversal and overwrite refusal.

Dry run from the isolated worktree:

```
python tools/strategy_farm/ftmo/trial_setpath.py --run-name acceptance_20260906 --risk-percent 0.1 --dry-run
```

Result: **8 sets** in `D:/QM/strategy_farm/artifacts/ftmo_trial_sets_review/acceptance_20260906/`, plus manifest. A second independent parser/hash comparison verified every frozen strategy parameter and both source/output hashes for all eight. See `2026-09-06_ftmo_live_setpath/verification.json`, `manifest.json` and `implementation.patch`.

| Candidate | Symbol | Unchanged input count |
|---|---|---:|
| 10706 | GBPUSD | 26 |
| 11421 | EURUSD | 11 |
| 11422 | USDCAD | 10 |
| 11910 | NZDUSD | 9 |
| 13054 | XTIUSD | 12 |
| 1537 | XAGUSD | 17 |
| 20048 | XTIUSD | 7 |
| 21505 | XAGUSD | 9 |

The task wording lists eight supported lanes; the readiness pack's actual sealed roster has eight sleeves across six symbols. XAUUSD and GER40 are supported mappings, not invented candidate sleeves. Original news seals often selected OFF/DXZ; the explicitly authorized FTMO/QM blackout override is recorded as a compliance difference and is not relabelled as a new pipeline PASS. No terminal, account, active set or live inventory was changed.

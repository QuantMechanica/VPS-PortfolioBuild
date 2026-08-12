# OPT-4 dual-venue book builders — implementation and dry-run evidence

Router task: `7d7cc716-98e1-453d-b427-4f7413d25bf2`  
Decision contract: DL-084  
Execution date: 2026-08-12  
Scope: analytic Q11_DXZ / Q11_FTMO storage lanes only; no terminal, farm-DB, deployment, challenge-account, T_Live, or AutoTrading action.

## Delivered contract

- `tools/strategy_farm/portfolio/book_builder_common.py`
  - resolves an explicit Q10-PASS roster plus Q16 `PROMOTE_CHALLENGER` / `ADMIT_BOTH` outcomes and fails closed if a selected challenger lacks Q10 PASS (lines 91-150);
  - binds every sleeve to the active magic registry and a canonical repository backtest set, rejecting any set without `RISK_FIXED > 0` and `RISK_PERCENT = 0` (lines 184-224);
  - supplies deterministic capped inverse-vol arithmetic (line 306) and a dependency-free safety validator that rechecks the emitted sleeve-list and roster hashes (line 381).
- `tools/strategy_farm/portfolio/build_book_dxz.py`
  - performs the common-history incumbent gate at line 76;
  - accepts the optional WS-2 cluster-overlay input as a hash-bound file (lines 98-111);
  - emits `APPLY_RECOMMENDED` only when return/MaxDD, worst-day, and MaxDD are all not worse (line 148), with no deployment or AutoTrading action (line 156).
- `tools/strategy_farm/portfolio/build_book_ftmo.py`
  - independently recomputes `FUND_SCORE = med60/max(2,2*abs(wDay),wDD_p90)` (line 62);
  - enforces one EA per symbol (line 95), explicit density evidence (line 157), roster/cost/ae5331f67-bound Phase-1 bootstrap input (line 198), and the reviewed FTMO cost/swap snapshot SHA-256 `7eab3bf8...` (line 42);
  - parks as `BAR_NOT_MET` unless every bar passes and always emits `challenge_recommendation: NONE` (lines 291-299).
- `tools/strategy_farm/config/dual_book_manifest.v1.schema.json` defines the shared hash-bound manifest contract.
- `tools/strategy_farm/tests/test_dual_book_builders.py` covers Q16 roster transforms, Q10 fail-closed behavior, cap arithmetic, conjunctive DXZ gate, FUND_SCORE recomputation, symbol uniqueness, snapshot binding/coverage, bootstrap bindings, and action-surface rejection.

## Current 24-sleeve dry run

Inputs:

- roster/current incumbent: `D:/QM/reports/portfolio/portfolio_manifest_live_24sleeve_20260724.json` (24 sleeves);
- sealed common-history streams: `D:/QM/reports/portfolio/dxz_final_20260719/QM/q08_trades` (the same 24 sleeve identities);
- FTMO scores: `D:/QM/strategy_farm/artifacts/portfolio/fund_scores.json`;
- FTMO cost/swap snapshot: `docs/ops/evidence/2026-07-30_ftmo_book3_symbol_cost_snapshot.json`, SHA-256 `7eab3bf8c97373fcb44e36aca39dd679fbd3e093783cd6eacd9cb171190b3280`.

Outputs:

- DXZ manifest: `D:/QM/reports/portfolio/book_dxz_2026-08-12_codex_dryrun/manifest.json`, SHA-256 `2f3693a4b43740b8b6e777635f5e2f6f9abc7b9b3f08ef7cd43a3d8409155443`.
- DXZ evidence: `D:/QM/reports/portfolio/book_dxz_2026-08-12_codex_dryrun/evidence.md`.
- FTMO manifest: `D:/QM/reports/portfolio/book_ftmo_2026-08-12_codex_dryrun/manifest.json`, SHA-256 `1f5bb61d72abf95ef6465818aaa341eecf746497e61b8112a1a875c1c34b6b6d`.
- FTMO evidence: `D:/QM/reports/portfolio/book_ftmo_2026-08-12_codex_dryrun/evidence.md`.

Observed verdicts:

- Q11_DXZ: `NOT_WORSE_BAR_NOT_MET`. On the identical 2019-07-23 through 2024-12-13, 1,349-day grid, the capped-inverse-vol proposal improved worst day (`-0.828051%` versus `-0.857107%`) but was worse on MaxDD (`2.269930%` versus `2.238353%`) and return/MaxDD (`4.500513` versus `4.526114`). No apply recommendation was emitted.
- Q11_FTMO: `BAR_NOT_MET`. Zero current roster sleeves met the FUND_SCORE >= 1.0 screening bar; density and the roster-bound Phase-1 lower-bound evidence were therefore absent. The recorded lower-bound gap is `0.80`; no challenge recommendation was emitted.

## Verification

```text
python -m pytest tools/strategy_farm/tests/test_dual_book_builders.py -q
.........s. [100%]
10 passed, 1 skipped
```

The skip is the optional third-party `jsonschema` package, which is not installed on this host. Both generated manifests passed the built-in dependency-free safety validator, including exact roster/sleeve hashes and the no-action contract.

Each builder was run twice with identical inputs. Manifest SHA-256 values were identical across repeats (`deterministic=True`). `python -m py_compile` and `git diff --check` also passed for all delivered Python/JSON/test files.

## Review disposition

`PASS_TO_REVIEW`. The tools are deterministic, dry-run-only evidence producers. Neither current book meets its application bar, which is a successful fail-closed result rather than a pipeline verdict or authorization.

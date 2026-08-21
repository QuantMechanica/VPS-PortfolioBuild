# Q11_FTMO: aggregate concentration control replaces the per-symbol cap

- Date: 2026-08-21
- Authority: OWNER-DEC-FTMO-SYMBOLPOLICY (OWNER 2026-08-21, "Deiner Empfehlung nach umsetzen")
- Router task: 9bdfde03-c9ef-43ce-b7ea-632347ad0f06
- File changed: `tools/strategy_farm/portfolio/build_book_ftmo.py`
- Test changed: `tools/strategy_farm/tests/test_dual_book_builders.py`

## Why

Ratified design (Vault `03 Pipeline/Q11 Portfolio Construction`, FTMO lane): *"im
FTMO-Buch duerfen MEHRERE EAs/Strategien auf demselben Symbol laufen — die
Risikokontrolle erfolgt auf Aggregat-Ebene (Korrelations-/Cluster-Kontrolle +
kontoweites Risikobudget), nicht ueber einen Symbol-Cap."*

The builder previously enforced `select_one_per_symbol`, kept only the highest
`fund_score` EA per symbol, stamped rejects `ONE_EA_PER_SYMBOL_LOWER_SCORE`, and
declared `symbol_policy = "ONE_EA_PER_SYMBOL_HIGHEST_FUND_SCORE_DETERMINISTIC_TIE_EA_ID"`.
That directly contradicts the ratified FTMO policy. Q11_FTMO holds 0 published rows
(dry runs only), so nothing downstream depended on the old behavior — safe to change.

## What changed

`select_one_per_symbol` is removed and replaced by `select_under_aggregate_control`:

1. Fund-score eligibility is unchanged (`FUND_SCORE_FLOOR = 1.0`).
2. Eligible sleeves are admitted greedily in deterministic order (fund_score desc,
   ea_id asc) subject to two AGGREGATE controls — no per-symbol cap:
   - **Correlation/cluster:** a candidate whose return-stream pairwise correlation with
     an already-admitted sleeve exceeds the threshold is rejected
     `CLUSTER_CORRELATION_EXCLUDED`. A candidate with NO correlation datum for an
     admitted peer is rejected fail-closed `CLUSTER_CORRELATION_UNVERIFIED` (cannot
     certify decorrelation without evidence — house style).
   - **Account-wide risk budget:** once the sum of admitted unit weights (each sleeve =
     1.0) would exceed the budget, further candidates are rejected `RISK_BUDGET_EXHAUSTED`.
3. Every candidate now carries an explicit accept/reject reason in `assessments` plus an
   `aggregate_control` detail block. Nothing is dropped silently. The old
   `ONE_EA_PER_SYMBOL_LOWER_SCORE` reason no longer exists.
4. Correlation data is REUSED from the existing artifact
   (`portfolio_correlation.py` output: `keys` + symmetric `correlation` matrix) via a new
   `load_correlation` loader and `--correlation` CLI arg. No new statistic invented.
5. Manifest updates: `symbol_policy` now reads
   `MULTIPLE_EAS_PER_SYMBOL_ALLOWED__AGGREGATE_CONTROL_PAIRWISE_CORRELATION_CLUSTER_AND_ACCOUNT_RISK_BUDGET`;
   a new `aggregate_control` block records thresholds, admitted pairwise correlations,
   and the explicit excluded list; the bar check `one_ea_per_symbol` is replaced by
   `aggregate_correlation_and_risk_budget_control`.
6. The tool remains a pure `DRY_RUN` analytic: `deployment_action`/`autotrading_action`
   stay `NONE`, `application_authority = OWNER_ONLY`. No deploy/live-account path added.

## Chosen aggregate-control parameters — OPEN OWNER ITEMS

No FTMO-lane number is pinned anywhere in the vault export, `decisions/`, or `docs/ops/`.
The following are clearly-labeled WORKING DEFAULTS (constants + manifest status
`WORKING_DEFAULT_OPEN_OWNER_ITEM`), overridable via CLI, and require OWNER ratification:

| Control | Working default | Anchor (not FTMO-ratified) |
|---|---|---|
| `WORKING_DEFAULT_MAX_PAIRWISE_CORRELATION` | **0.50** | `book_reoptimizer.py` greedy pairwise-correlation selection constraint `<=0.50` (OWNER 2026-07-15). DL-083 sets Q09 marginal-eval reject at 0.40. |
| `WORKING_DEFAULT_ACCOUNT_WEIGHT_BUDGET` | **10.0** unit weights | No ratified FTMO account-wide sleeve count exists; non-binding ceiling. |

**OWNER decision needed:** ratify (or override) the FTMO pairwise-correlation reject
threshold and the account-wide risk budget before any FTMO book is constructed.

## Test proof (fail-before / pass-after)

Test file `tools/strategy_farm/tests/test_dual_book_builders.py`, new tests:
- `test_ftmo_aggregate_control_admits_two_low_corr_eas_on_same_symbol` — two low-corr
  EURUSD sleeves BOTH admitted (old cap would have dropped one).
- `test_ftmo_aggregate_control_excludes_high_corr_ea_with_explicit_reason` — high-corr
  peer rejected `CLUSTER_CORRELATION_EXCLUDED`.
- `test_ftmo_aggregate_control_fails_closed_on_missing_correlation` — `CLUSTER_CORRELATION_UNVERIFIED`.
- `test_ftmo_aggregate_control_enforces_account_weight_budget` — `RISK_BUDGET_EXHAUSTED`.

Fail-before proof: `git stash` of ONLY `build_book_ftmo.py` (test kept) → the suite fails
at collection with
`ImportError: cannot import name 'select_under_aggregate_control'` (the new test cannot
run against the old builder because the old cap function was the only entry point).
Pass-after: with the new builder, `13 passed, 1 skipped`. Builder restored after the
stash proof; suite re-run `13 passed, 1 skipped`.

## Risks / open items

- Both aggregate-control numbers are OPEN OWNER ITEMS (see table) — not presented as ratified.
- Multi-sleeve admission REQUIRES a correlation artifact; without one the control is
  fail-closed and admits at most the single highest-score sleeve. This is deliberate.

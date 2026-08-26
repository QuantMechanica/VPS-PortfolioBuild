# Pattern `_opt` sibling build — router task `3fb7e743`

- Date: 2026-08-26
- Canonical checkout: `C:/QM/repo`
- Branch: `agents/board-advisor`
- Verdict: `PARTIAL_BUILD_READY_COMPILE_CPU_GUARD_PENDING`

This is build evidence, not a pipeline verdict. No Q phase was run or
adjudicated, no pattern matrix was materialized, and T_Live, AutoTrading, and
active T1-T10 backtests were left untouched.

## Governed identities

Identity reservation and magic allocation were performed serially. The magic
allocator reported zero active collisions before and after the change; the
strict resolver dry-run retained every active registry row.

| Parent | Governed sibling | Symbol / slot | Magic | Q12 declaration |
|---|---|---|---:|---|
| `QM5_10706_tv-mon-ls` | `QM5_41161_tv-mon-ls-opt` | `GBPUSD.DWX / 0` | `411610000` | `dfca24fa-28df-5f5e-818f-8dcf53611822` |
| `QM5_11421_ohlc-daily-squeeze-reversal-d1` | `QM5_41162_ohlc-daily-squeeze-reversal-d1-opt` | `EURUSD.DWX / 0` | `411620000` | `d0e53004-659c-563c-8314-c24ad4ab2a68` |
| `QM5_11422_williams-18ma-outside-bar-entry-d1` | `QM5_41163_williams-18ma-outside-bar-entry-d1-opt` | `USDCAD.DWX / 0` | `411630000` | `f9e1f7fc-f92e-5399-9f7d-c7e83e940ce5` |

Registry receipts:

- identity commit `031097abb` (`ops: reserve pattern optimization sibling identities`);
- allocator/build commit `d56f7e3ae` (`build: add pattern optimization siblings`);
- allocator dry-run: `2026-08-26_3fb7e743_pattern_sibling_allocator_dry_run.json`;
- allocator apply: `2026-08-26_3fb7e743_pattern_sibling_allocator_apply.json`;
- magic registry rows: 18,036 -> 18,039;
- generated resolver rows: 17,898 -> 17,901;
- resolver verification: strict dry-run PASS, zero dropped rows.

The prerequisite retirement of legacy identities 1001/1015/1016 was already
durable before allocation. DL-089 and the three approved parent sources were
not edited. Their source SHA-256 values remained:

| Parent | SHA-256 after the sibling build |
|---|---|
| `QM5_10706` | `909327914D7FD65301751C38421C5DEC3CDDF8E96864D45C26F4DB7A1F8FE27C` |
| `QM5_11421` | `B5DFD159B46281CDB30DAE3AE12A12FD67CDF810941B82A4A5F7E11A9DCE6A15` |
| `QM5_11422` | `A68B9F02372EDD490F2AF9EA32EFA6606DF7C2D8B40E30F3DDAC2E2D56CAB84E` |

## Build contract

Each sibling preserves its parent's entry/exit mechanics and adds only the
pattern measurement surface required by the declared experiment:

- exactly six integer inputs: `opt_pp_buy1..3` and `opt_pp_sell1..3`;
- a closed-D1 reference profile and `QM_PatternPermissionEvaluate`;
- a symmetric fail-closed BUY/SELL permission veto before order placement;
- invalid profiles fail `OnInit`;
- fixed-risk base setfile with explicit `environment: backtest`,
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `qm_news_stale_max_hours=336`.

Focused checks passed for all three EA directories:

- `validate_build_guardrails.py`: PASS with no findings;
- source/set contract census: six source inputs, six setfile inputs, one
  permission evaluator, and both directional veto paths;
- `optimization_fork_driver._pattern_measurement_readiness` against each new
  sibling: `status=READY`, no blockers, no missing inputs, permission wired,
  and the exact compliant risk contract;
- `git diff --check`: PASS;
- copied parent source hashes rechecked byte-unchanged.

The inherited parent build-hash comments were cleared before enqueue so that a
new sibling build, rather than the parent's binary identity, is bound. That
repair is commit `a32226826`.

## Governed compile receipts and current blocker

All three exact source hashes were admitted through `COMPILE_EA` and released
one at a time. Release receipts are durable beside this document:

| Sibling | COMPILE_EA work item | Bound source SHA-256 | Release receipt |
|---|---|---|---|
| `QM5_41161` | `c3c31312-6c90-4265-a54c-4f0acd60303e` | `22cda9e268b216d1df93cf33ecd8508d5d0ee31a8eb62abcc8df894e8d3fe9cd` | `2026-08-26_3fb7e743_QM5_41161_compile_release.json` |
| `QM5_41162` | `bfd92dec-957c-4534-b7fc-da7f355c05cc` | `92368d032c7c4cc1bc0e7243338e6e363d79de97960be8752dbc16e4b3c1f48f` | `2026-08-26_3fb7e743_QM5_41162_compile_release.json` |
| `QM5_41163` | `16f86fe7-50c5-4815-82f0-8aafe5ba4dfd` | `e29e22586a3011a3d18db83463101360a1818f14c3d355b9cd5b0df063190976` | `2026-08-26_3fb7e743_QM5_41163_compile_release.json` |

At the close of this orchestration pass every row is still `pending`, with no
activation hold, no failure class, and no compile/build-check receipt yet. The
resident idle-slot workers repeatedly logged `cpu_high_pause` at 100% load;
they also observed an independently scheduled `FACTORY_MUTATION.lock`. Active
factory tests were not interrupted. An ad-hoc `build_check -SkipCompile` probe
was correctly refused by `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; no manual
terminal was started.

Therefore acceptance criterion 1 (identity/magic/resolver) is complete, but
criterion 2 (three Compile-OK receipts) is not yet met. The build is safely
queued and source-hash bound, not failed.

## Q12 readiness

The new sibling bytes remove
`PATTERN_FILTER_INSTRUMENTATION_REQUIRED` when evaluated by the same readiness
function that authored the append-only Q12 declarations: all three return
`READY` with an empty blocker list. The existing Q12 rows remain unchanged and
pending, as required by their append-only contract.

They are not yet honestly claimable for measurement: the declaration's own
resolution template requires the sibling compile/build and Q02 prerequisites
before `opt_census.py` materializes any annual cells. Since the governed
compiler has not emitted its receipts, no Q02 run or 1,085-cell matrix was
invented in this pass. Criterion 3 is therefore statically resolved at the EA
instrumentation layer but operationally pending the three compile receipts and
subsequent governed Q02 prerequisites.

## Review hand-off

Keep this ticket in REVIEW as a partial, fail-closed build. A later routed
continuation may attach the three resident-worker Compile-OK/build-check
receipts, run the separately governed Q02 prerequisites, and only then
materialize each already-declared Q12 matrix. No pipeline or profitability
claim is made here.

# Q14 optimization admission evidence — d60eac6e — 2026-08-12

Router task: `d60eac6e-0c10-46cf-a4bd-addcc4303925`  
Implementation commit: `0181c8613` (`pipeline: add deterministic Q14 optimization admission`)

## Verdict

`PASS_FOR_REVIEW` — the Q14 fork is implemented as a deterministic analytic gate with a read-only dry-run default. No production Q14 row or opt-card was applied during this task; activation remains a separate OWNER-controlled action.

## Delivered contract

- `framework/scripts/q14_opt_admission.py`
  - reads distinct latest `(ea_id, symbol)` Q10 `done/PASS` identities from the farm DB;
  - binds the parent EX5, setfile, Q10 evidence, and SHA-256 identities;
  - refuses any parent set that is not exactly `RISK_FIXED=1000` and `RISK_PERCENT=0`;
  - applies the binding arithmetic: exit surgery needs at least 60 trades; volatility-regime filtering needs at least 150 trades and at least 12% max drawdown;
  - admits locked ports independent of those metrics only when the ex-ante carrier list is present;
  - leaves MTF entry in `BACKLOG_ONLY` state;
  - enforces 12 concurrent cards globally and two per parent;
  - emits timestamp-free deterministic `qm.opt-card/v1` bodies and `OPENED` `qm.opt-trial-ledger/v1` ledgers only on explicit `--apply`;
  - appends deterministic analytic Q14 work items with `OPT_ELIGIBLE` or `OPT_REJECTED` only on explicit `--apply`.
- `tools/strategy_farm/config/opt_program.v1.json`
  - freezes the nine-pair cohort, exact Q04 anchored OOS folds, the 2026 post-DEV holdout, hypotheses, single-parameter surfaces/bounds, success metrics, and caps;
  - the six high-drawdown exit candidates plus five arithmetic-qualified volatility candidates total 11 possible cards;
  - the three XAU volatility candidates remain frozen but fail closed under the task's binding 12% drawdown floor.
- Versioned schemas:
  - `tools/strategy_farm/config/opt_card.v1.schema.json`
  - `tools/strategy_farm/config/opt_trial_ledger.v1.schema.json`
- `farmctl admit-optimization` is dry-run by default; only `--apply` is classified as state-mutating and therefore receives the canonical-checkout and Factory-OFF guards.

## Production-snapshot dry run

Command:

```text
python tools/strategy_farm/farmctl.py admit-optimization
```

Observed against `D:/QM/strategy_farm/state/farm_state.sqlite`:

```text
source_q10_pass_pairs = 34
OPT_ELIGIBLE          = 11
OPT_REJECTED          = 3
dry_run               = true
applied               = false
Q14 rows after run    = 0
```

Two independently evaluated dry runs produced identical canonical JSON. SHA-256:

```text
dedc295d061a451bdc57827a821b80eeb34ad33790f8554021286f89c1a2d433
```

All 11 proposed bodies passed the built-in binding/window checks and the Q16 anchored-window loader. The first two proposed immutable body hashes were:

```text
OPT-13213-USDJPY-EXIT-SURGERY-1e2bb8e4c42f21f7
dd4e498f633b0b4ca2aecebc1fce9668d33ffb7e61fef9762cefb720c83ef5b5

OPT-13213-USDJPY-VOL-REGIME-FILTER-bacbed95fb36992e
25c97a27e5e052fa98de1ca0ca52f0d0d02b1f6c299bd11ad7b95a6716b658f3
```

## Focused verification

```text
python -m pytest tools/strategy_farm/tests/test_q14_opt_admission.py -q
11 passed

python -m pytest \
  tools/strategy_farm/tests/test_q14_opt_admission.py \
  tools/strategy_farm/tests/test_q16_head_to_head.py \
  tools/strategy_farm/tests/test_farmctl_scope_audit_isolation.py \
  tools/strategy_farm/tests/test_farmctl_job_object_containment.py \
  tools/strategy_farm/tests/test_farmctl_cascade.py -q
48 passed, 4 subtests passed

python -m pytest \
  tools/strategy_farm/tests/test_q14_opt_admission.py \
  tools/strategy_farm/tests/test_q16_head_to_head.py -q
17 passed

python -m py_compile framework/scripts/q14_opt_admission.py tools/strategy_farm/farmctl.py
PASS

git diff --check
PASS
```

Coverage includes latest-distinct Q10 selection, exact boundary arithmetic, missing carrier-list refusal, locked-port metric independence, MTF backlog refusal, global/parent caps, bad-risk refusal, timestamp-free deterministic dry runs, immutable card creation, OPENED ledger creation, Q14 row insertion, repeat-apply idempotence, Q16 window compatibility, and farmctl mutation classification.

No terminal was launched, no T1–T10 backtest was touched, and neither T_Live nor AutoTrading was accessed.

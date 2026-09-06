# DSR single-configuration declaration execution — 2026-09-06

- Router task: `f9ce2102-e858-435f-b83d-33ca7b9506dd`
- OWNER authority: receipt `5bf3bf5e-e3a9-40f8-8346-d2df9ca9b1e2`, YES / Option A
- Implementation branch: `agents/codex-dsr-declaration-20260906`
- Pre-amendment card preservation commit: `0ec2adaa1a`
- Implementation and card-amendment commit: `eaf53716c1`
- Disposition: REVIEW. No Q08 row was enqueued, no stored verdict was changed, and no threshold was changed.

## Implementation

The single-configuration producer now re-seals a Q08 context at the atomic claim boundary, after `claimed_at_iso` is known. At seal time it queries `work_items` for the candidate EA and refuses with `FACTORY_SEARCH_LEDGER_PRECEDES_Q08` if an earlier row is any `OPT_*` phase, Q12-Q16 phase, or carries an `optimization_fork`, `optimisation_fork`, or `opt_fork` marker. The immutable context records the Q08 row ID, claim timestamp, number of preceding rows examined, and an empty optimization-row list. Enqueue-time single-configuration sealing remains fail-closed because a Q08 claim row/timestamp does not yet exist.

MT5 set files may omit inputs that retain compiled defaults. The declaration lock is therefore the effective configuration: every directly declared source input default, overlaid by every explicit set-file assignment. The card, SPEC, MQ5, EX5, and set file remain separately path- and SHA-bound. A source-default change or explicit set drift invalidates the context.

The Card-v2 linter now emits:

- `card_sweep_q14_proposal_label_missing` when a P3 sweep, `Parameters To Test`, or `sweep_range` appears without a Q14-proposal label;
- `card_sweep_research_ledger_missing` when such a list claims a positive `research_trial_count` without a declared loser-inclusive ledger.

The governed `approve-card` path now supports an already-APPROVED card in its own approved directory as an in-place amendment. It records both prior and resulting card SHA-256 values and emits a `card/amended` event. A different source colliding with an existing approved target still refuses before mutation.

## Approved-card amendments

Both cards contain exactly one valid `qm-dsr-single-configuration` fenced JSON declaration, `complete=true`, `no_optimization_search=true`, `research_trial_count=0`, exact EA/symbol/timeframe and SPEC SHA, and a full string-valued effective lock. Runtime cards and the C: git mirrors have the same decoded content. The original C: mirrors are preserved in commit `0ec2adaa1a`; the amendments are a later commit.

| EA | Runtime card SHA-256 | SPEC SHA-256 | Locked entries | Q08 set SHA-256 |
|---|---|---|---:|---|
| QM5_11167 / XAUUSD.DWX / D1 | `a129085b60c41a8926ceee83eadf8d351da35cefb5d9d65f92b944a278d8aeaf` | `df4b72137c45e7a6c2af1de7728a26ed90b5e525b5aea29435c021378b877aff` | 29 | `0ba5c35227a883609d63ee74604c21c682deb99068f6a306df57a87283a43a17` |
| QM5_11196 / XAUUSD.DWX / H4 | `909953f0db31401760942cae40f9c26b50e1ebe91d91bc0c9fd53496d5e18fa5` | `b3c076515a4e7180c37a45a3e5d8d065e17a028ce35232373f40cbf0c210bf66` | 44 | `1b0a80e1cf9cfa827090d3da4d0bf1d325379e27a163382335fe5fd80b36e51f` |

The QM5_11167 lock intentionally follows the exact Q08 row's `..._backtest_ablation_01.set`, including fast SMA `8`, slow SMA `29`, and ATR multiplier `2.523967`; QM5_11196 follows its exact baseline set. Both preserve `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `qm_news_stale_max_hours=336`.

Governed approval receipts are durable in `events`:

- event `388141`, QM5_11167, `card/amended`, 2026-09-06T16:55:55Z;
- event `388142`, QM5_11196, `card/amended`, 2026-09-06T16:56:04Z.

The approve-card registry precheck separately reported existing magic-symbol ordering mismatches for both legacy cards. It did not alter either declaration and its attempted follow-on task was rejected by the canonical-router writer gate; no untracked work was created.

## Producer and evaluator replay

The replay opened `D:/QM/strategy_farm/state/farm_state.sqlite` read-only, used each historical Q08 claim timestamp and exact baseline artifact identities, extracted closing deals from the immutable MT5 reports, and wrote only content-addressed cohort proofs below this evidence directory.

| EA | Pre-claim rows examined | Declared / research / effective trials | Trades | DSR result | p-value | Threshold | Cohort proof |
|---|---:|---|---:|---|---:|---:|---|
| QM5_11167 | 72 | 1 / 0 / 1 | 311 | PASS | `0.0007074453939691516` | `0.05` | `cohorts/QM5_11167_XAUUSD_DWX_D1/e001f44f10aa4ffc3f3820ca92095f3f3d1b83e7922900ed04e9d12af5c59724.json` |
| QM5_11196 | 42 | 1 / 0 / 1 | 656 | PASS | `0.004103950626400629` | `0.05` | `cohorts/QM5_11196_XAUUSD_DWX_H4/edde44f7c347ef1cb4c119aa36fec1417a51c7606f7662bf2e5225e845d2e1c4.json` |

Both evaluator results report `DSR_V2_COMPUTED`, `selection_correction_applied=false`, and `expected_max_sharpe_daily=0.0`. These are read-only replay results, not pipeline verdicts.

The live database still contains exactly one historical Q08 row per EA and both remain unchanged at `done/INVALID`:

- `d7ab61ae-c7eb-400c-81d3-94b30a1a74e2` (QM5_11167);
- `b280892a-18ec-4375-841e-eb360aba5ee1` (QM5_11196).

## Verification

Focused command:

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_dsr_single_configuration.py \
  tools/strategy_farm/tests/test_dsr_cohort.py \
  tools/strategy_farm/tests/test_dsr_v2.py \
  tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py \
  tools/strategy_farm/tests/test_terminal_worker_identity.py \
  tools/strategy_farm/tests/test_mnt012_build_guards.py \
  tools/strategy_farm/tests/test_execution_contract_lint.py::<four scoped card-lint tests>
```

Result: `170 passed in 68.60s`.

Additional checks:

- `py_compile` passed for `dsr_single_configuration.py`, `dsr_cohort.py`, `terminal_worker.py`, `execution_contract_lint.py`, and `farmctl.py`.
- Declaration parser/schema-equivalent checks passed for both real cards; all locked values are strings and both sweep-specific lint issue sets are empty.
- Parameterized refusal fixtures cover `OPT_CENSUS`, another `OPT_*`, every Q12-Q16 phase, and an `optimization_fork` payload marker before claim. A Q14 row created after the claim is correctly ignored.
- No `.mq5`, `.mqh`, `.ex5`, set file, registry, threshold, pipeline verdict, queue row, T_Live, or AutoTrading state was changed.

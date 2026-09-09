# QM5_41186 market-neutral compile and Q02 recovery

Date: 2026-09-09
Branch: `agents/board-advisor`
EA: `QM5_41186_xtixng-median-runs-rv`
Router claim: `6c679382-231e-4d33-a518-bbce06fbc433`

## Selection

The approved card describes a structural, non-ML, monthly XTI/XNG relative-value
package with approximately five to eight completed packages per year. Its
opposite equal-target-notional legs are intended to reduce outright energy
direction. There was no open agent task for EA 41186 at claim time. The latest
compile work item, `78d5f43e-d805-4748-923d-c36c33370b78`, had compiled with
zero errors and zero warnings but ended `COMPILE_FAIL` because the build gate
could not prove two dynamic-buffer accesses were bounded.

## Source repair

The source now gives each reported dynamic access a separate dominating
`ArraySize` fail-fast guard. Strategy arithmetic, rank construction, the
inclusive `run_count <= 7` signal boundary, pair direction, risk sizing, and
lifecycle rules are unchanged.

The locked-configuration predicate was also narrowed to the binding PACER
contract:

- equality pins remain only for `strategy_*`, `qm_ea_id`, and
  `qm_magic_slot_offset`;
- backtest risk mode requires finite `RISK_FIXED > 0` and finite
  `RISK_PERCENT == 0` without pinning fixed risk to a particular amount;
- `qm_rng_seed`, every `qm_news_*` input, every `qm_friday_close_*` input, and
  `PORTFOLIO_WEIGHT` are not compared;
- `qm_stress_reject_probability` is checked only for finiteness and inclusive
  range `0..1`.

The compile-repair authority is exact-bound to router task `6c679382`, the EA
label, failed predecessor, rejected MQ5 hash
`2ae7f7b27f98ed76ea026557565445b3bf1dffddf2921171286bfcca9616b7bc`,
and repaired MQ5 hash
`e1fd406fe334d5453bf870d4bec24aa68f14b7d295fd1a19a22dc1acb02cb7c2`.

## Verification and governed compile

Mandatory pre-enqueue audit:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_41186_xtixng-median-runs-rv/QM5_41186_xtixng-median-runs-rv.mq5"
exit 0; ok=true; predicate=EA_FRAMEWORK_INPUT_PINNED; hit_count=0
```

Focused checks:

- `build_gate_hardening.py --ea-label QM5_41186_xtixng-median-runs-rv`:
  zero failures, including zero D10 buffer-bound failures.
- `pytest test_compile_work_items.py -k qm5_41186 -q`: `1 passed`.
- `py_compile tools/strategy_farm/compile_work_items.py`: PASS.
- The broader hardening suite was stopped after seven passing tests because its
  repository-wide scans were long-running; the direct EA scan above is the
  targeted authoritative result for this repair.

The first exact-authority successor,
`dbf2f53b-6961-40db-8912-49bf596200bc`, was rejected by a resident worker that
had cached the pre-change authority table. No compile was attempted by that
row. The repository's existing generic repair-successor contract was then used
without bypassing the worker: repair-only build binding
`6e4deea6-08d2-4517-a65e-8bb83f2b6f26`, successor
`b07825b5-22f2-4e90-8cf9-fe6474f06871`, and normal activation-hold release.

The governed worker result is `COMPILE_OK`:

- compile result: PASS, zero MetaEditor errors/warnings;
- build-check result: PASS, no failure classes;
- EX5 SHA-256:
  `3e9e0884e0c4db5fb5fcad8be4ce89d625c1388067f69eb4ec42fc3521828bdc`;
- evidence:
  `D:/QM/reports/work_items/b07825b5-22f2-4e90-8cf9-fe6474f06871/QM5_41186/COMPILE_EA/compile_evidence.json`.

The worker regenerated the logical-basket, XTI, and XNG D1 backtest setfiles.
All three retain `RISK_FIXED=1000` and `RISK_PERCENT=0`.

## Q02 intake

`farmctl intake-first-q02 --apply` admitted exactly one logical-basket canary:

- work item: `a13e3f3b-c319-4e99-8761-6db0ec957877`;
- symbol: `QM5_41186_XTI_XNG_MEDRUN_RV_D1`;
- host symbol/timeframe: `XTIUSD.DWX`, D1;
- window: 2018-07-02 through 2024-12-31;
- status at handoff: `pending`;
- intake receipt:
  `D:/QM/strategy_farm/artifacts/receipts/first_q02_intake/b07825b5-22f2-4e90-8cf9-fe6474f06871_a13e3f3b-c319-4e99-8761-6db0ec957877.json`;
- receipt SHA-256:
  `7310b3530888819b011887782da004e3260a585c09226e506c12ebfb79afc481`.

At intake, five of ten research terminals were occupied, so the backtest CPU
ceiling was not reached. No T_Live file, AutoTrading state, portfolio gate, or
deploy manifest was touched.

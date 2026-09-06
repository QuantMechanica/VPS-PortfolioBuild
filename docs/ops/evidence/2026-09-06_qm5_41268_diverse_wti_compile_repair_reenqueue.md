# QM5_41268 diverse WTI compile repair and re-enqueue

Date: 2026-09-06 UTC

Branch: `agents/board-advisor`

Mission unit: diversity-first Q01 build recovery for
`QM5_41268_wti-mepps-shift-tr` on `XTIUSD.DWX` D1.

## Selection and collision control

A fresh five-sample whole-host CPU window measured `68.813%`, `70.232%`,
`79.456%`, `82.135%`, and `69.596%` (average `74.046%`, maximum `82.135%`).
Both dimensions were strictly below the paced-fleet ceiling of `97%`.

The previously identified WTI candidate `QM5_41171` was excluded after the
canonical farm DB showed it had already advanced through Q05. The newest
collision-free, approved, uncompiled diversity candidate was therefore
`QM5_41268`, a deterministic monthly WTI distribution-shift continuation
sleeve with approximately six expected trades per year.

The existing build task `a7bd58e8-3abc-41ff-8e8d-6076e0e793ec` was claimed
atomically with claim ID `33bd0939-bc8a-4472-9eb3-eade9bc8266b`. At claim
time it had no build-dispatch marker, active sibling, open work item, or EX5.
The approved card has G0 and execution-contract status `APPROVED`, registered
EA identity `41268,wti-mepps-shift-tr`, and active slot-0 magic `412680000`
for `XTIUSD.DWX`.

## Deterministic repair

The prior governed compile work item
`7f224c84-9ae2-446e-a905-cb386e9695cc` failed with twelve MQL5 compiler
errors and `EA_INDICATOR_BUFFER_UNBOUNDED`. Two source-only defects explained
that result:

- `matrix` was used as an inverter parameter name even though MQL5 parses it
  as a type token. It was renamed to `input_matrix` without changing the
  quadratic-form arithmetic.
- The bounded pre-month close reconstruction relied on configured/loop
  bounds but lacked explicit `ArraySize` proofs at dynamic-buffer accesses.
  Fail-fast local bounds checks were added for both write and reversal paths.

No signal window, Fourier feature, covariance formula, threshold, direction,
cadence, stop, sizing, symbol, or lifecycle rule changed.

## Verification and governed handoff

- `skill_build_ea_guard.py`: PASS for EA registry, magic registry, and EA dir.
- `validate_spec_doc.py`: PASS.
- `test_wti_mepps_shift_tr_reference.py`: 12/12 PASS.
- `build_gate_hardening.py`: PASS with zero failures and zero warnings.
- Symbol-scope validation: exact registered/card carrier `XTIUSD.DWX` only.
- Canonical backtest set: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; no live/demo/shadow set was created.

Direct `build_check.ps1` correctly refused while factory terminals were
alive (`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`). The repaired source was instead
bound to append-only governed compile successor
`814aab56-5f04-42ad-a4c2-4bb2c9cfa061`, superseding the exact failed compile
row. The successor is pending behind the explicit
`COMPILE_EA_WORKER_ROLLOUT_PENDING` hold. A read-only release preflight said
the row is structurally releasable, but no release was applied because that
hold is reserved for the reviewed-worker restart ceremony.

Source SHA-256 at enqueue:
`fcfa8a6b84cb45114b89f119400ce9912488e7994ae0677a6dfeff8ad3a8ed49`.

Q02 was deliberately not created: an authenticated compile PASS and current
EX5 do not yet exist. The governed compile worker must finish first; the normal
build-record path can then run the single worker-bound smoke and append the
first fixed-risk Q02 row.

## Boundary

No backtest, optimization, dispatch tick, terminal restart, worker restart,
hold release, portfolio-gate mutation, live-manifest mutation, deploy-manifest
mutation, `T_Live` control, or AutoTrading action was performed.

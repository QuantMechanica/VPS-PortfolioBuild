# QM5_11078 EURUSD Q02 infrastructure repair - 2026-08-16

## Outcome

`QM5_11078_rsioma-reversal` was synchronized to the current V5 framework
wiring, rebuilt cleanly, and re-enqueued as one append-only EURUSD H4 Q02
successor. The strategy rules, approved symbol basket, risk model, registries,
and historical work-item row were not changed.

## Selection and collision control

- This was the highest-value collision-free diversity recovery after the
  approved build backlog was screened: a structural, low-frequency H4 FX EA
  sourced to EarnForex's public RSIOMA implementation.
- Approved card:
  `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11078_rsioma-reversal.md`
  (`g0_status: APPROVED`, R1-R4 PASS, SHA-256
  `f6528e5ca9cd446cff853852888c62fb9a85c1f53d5dce63cf51ad2ab963bccc`).
- Registered basket: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, and
  `USDCAD.DWX`; all four existing magic rows remained active and unchanged.
- Agent claim: `fa7fdd32-621a-465c-b4f9-03ab0c5c9d4b`, owned by
  `codex:agents/board-advisor`.
- No open Q02/Q03 row or competing EA claim existed when the recovery was
  claimed.

## Diagnosis

The source Q02 row `b72d8cb8-f07f-46cd-8864-1566fb8a88df` ended
`INFRA_FAIL` with `ONINIT_FAILED` and `INCOMPLETE_RUNS`. Its sealed evidence is:

`D:\QM\reports\work_items\b72d8cb8-f07f-46cd-8864-1566fb8a88df\QM5_11078\20260728_170028\summary.json`

The run requested `EURUSD.DWX`, H4, Model 4, and 2018-07-02 through
2022-12-31, but the report contained an empty expert/symbol identity, M0/1970,
zero bars, and no valid history context. Source and deployed artifacts matched
and stayed stable during that run. The bound EX5 was the stale June 21 binary
`b5b8e9ff78e6f1a15465f0806b67b81f4126d6b52877efbaf2ec210f3a79eff9`.

The EA also carried pre-audit framework boilerplate: its news gate sat above
position management and exits, it lacked first-statement Q08 MAE sampling, and
its entry request was not zero-initialized. These are framework defects, not
changes to the approved RSIOMA mechanics.

## Repair

- Made the EA's framework-wiring section line-for-line equivalent to the
  canonical skeleton.
- Added `QM_FrameworkTrackOpenPositionMae()` before every early return.
- Moved the two-axis news gate below Friday close, management, and strategy
  exits so it blocks new entries only.
- Added `ZeroMemory(req)` before the strategy entry hook.
- Rebuilt from a detached clean worktree at
  `b11f200e4d23a62c382588e832f05efbfb4bf014`, excluding another paced agent's
  uncommitted registry/resolver row.
- Updated the SPEC revision history for this framework-only repair.

## Verification

| Check | Result |
|---|---|
| `validate_spec_doc.py` | PASS, 1/1 |
| Single-EA framework/build gate | PASS, 0 failures, 0 warnings |
| Strict MetaEditor compile | PASS, 0 errors, 0 warnings |
| Build-gate report | `D:\QM\reports\framework\21\QM5_11078_board_advisor_repair\build_check_20260815_233205.json` |
| Strict compile summary | `D:\QM\reports\compile\QM5_11078_board_advisor_repair\20260815_233344\summary.csv` |
| MQ5 SHA-256 | `295497d9eb52f52e17f4acc4f349873164cc581df97282a43c9936f94578584f` |
| EX5 SHA-256 | `4598106a5015e78b28f4283536ae1041a7de74529eefb27c09a8907e8ff3c676` |
| EX5 size | 374,592 bytes |
| EURUSD setfile SHA-256 | `e3ff027ef105164f7e505d49272d1f24ee1a7eb9714f37d6213a17058f2d0d14` |
| Backtest risk binding | `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` |

## Q02 handoff

Farmctl preserved the terminal source row and inserted exactly one
authenticated successor:

- New work item: `562f8bf4-88c6-400f-9a6f-90e3a18462a5`
- Phase / identity: Q02 / `EURUSD.DWX` / H4 /
  `QM\QM5_11078_rsioma-reversal`
- Source row: `b72d8cb8-f07f-46cd-8864-1566fb8a88df`
- Payload flags: `append_only_rerun=true`, `repaired_infra_rerun=true`
- Artifact bindings match the MQ5, EX5, and EURUSD setfile hashes above.

The fleet was already at the backtest CPU ceiling, so no smoke or backtest was
started manually. The farm pump claimed the pending successor shortly after
enqueue; no retry, dispatch override, or tester intervention was performed.

## Safety boundary

- No `T_Live` file, AutoTrading setting, portfolio gate, deploy manifest, or
  live manifest was touched.
- No magic registry, EA-ID registry, or shared framework include was edited.
- The only strategy artifact change is canonical framework wiring; entry,
  exit, stop, sizing, and filter mechanics remain card-identical.

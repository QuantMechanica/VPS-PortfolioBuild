# QM5_41035 WTI Monthly Flow Divergence — Build And Q02 Enqueue

Date: 2026-08-17 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 ENQUEUED`

## Candidate And Claim Boundary

`QM5_41035_wti-mflow-div` is a new low-frequency direct-WTI structural
candidate. On the first executable `XTIUSD.DWX` D1 tick of a normalized broker
month, it reconstructs every completed session in the immediately prior month
plus the preceding month-end anchor. It separately sums close-to-open and
open-to-close log returns and reconciles their total to the exact completed
month return within `1e-10`. It trades only strict component opposition: buy
when session flow is positive and overnight flow is negative; sell when
session flow is negative and overnight flow is positive. Direction follows
session flow even when overnight flow dominates the completed-month total.
Agreement and exact-zero states consume the month flat. An open position is
held to the first observed next-month boundary, with a 40-day stale guard.

The OWNER-approved packet joins the complete governed Tier-A Williams
public/professional information-time decomposition with the complete-read,
peer-reviewed WTI one-month carrier lineage in Moskowitz, Ooi, and Pedersen
(2012). Neither source tests this exact conjunction, Darwinex continuous-CFD
mapping, broker-label normalization, timing, risk, profitability, or portfolio
relationship. Those are disclosed QM falsification choices; no source result
or decorrelation claim transfers.

## Governance, Allocation, And Non-Duplicate Boundary

- Source approval commit: `56fe6878e`.
- Deterministic EA-ID reservation commit: `1ce5038b6`.
- Strategy Card and OWNER G0 commit: `46e61b25f`.
- Pre-magic directory identity commit: `f035e8950`.
- Unrelated pre-staged review evidence was restored to the caller worktree and
  removed from branch scope in `5646e4cc9`.
- Magic registration/resolver commit: `dc526ed9f`.
- Q01 build commit: `96f28ca1d`.
- Registered slot 0 is `XTIUSD.DWX`, magic `410350000`.
- The canonical pre-card checker scanned 4,522 EA-registry rows and 618 root
  cards, found no exact identity, and raised the expected WTI-flow family for
  manual semantic review.
- `QM5_41034_wti-mflow-agree` uses the same completed-month endpoints but
  admits only same-sign component states. This EA admits only their disjoint
  opposition states and follows session flow.
- `QM5_41032_wti-flow-div` also trades opposed components, but reconstructs
  one exact Monday-Friday week and closes Friday. This EA consumes the entire
  completed broker month and holds to the next month.
- `QM5_41033_wti-flow-dom` is a weekly component-magnitude dominance state;
  `QM5_20187_wti-tsmom1m` follows every nonzero completed-month total. Neither
  has this monthly opposition eligibility plus session-following direction.
- Verdict:
  `CLEAN_WTI_MONTHLY_INFORMATION_FLOW_OPPOSITION_AFTER_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Exact route: `XTIUSD.DWX`, D1, slot 0.
- The only preset is a backtest setfile with `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; both news axes and framework
  Friday close are OFF.
- Each position has one frozen `3.5 * ATR(20,D1)` hard stop, no target, no
  scaling, a 1,500-point spread ceiling, and no retry after the persisted
  monthly attempt.
- Independent reference suite: 19 tests PASS, including both label offsets,
  exact month/anchor identity, 15/25 session bounds, endpoint arithmetic,
  both opposition directions under both possible total signs,
  agreement/zero rejection, reconciliation, grace timing, attempt identity,
  fixed risk, and next-month rollover.
- All three Strategy Card copies are byte-identical and pass schema/G0/ML
  lint. The seven-section spec, deterministic registry identities, and target
  build guardrails pass.
- Strict MetaEditor compile: PASS, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260817_011803/QM5_41035_wti-mflow-div.compile.log`.
- Targeted final build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260817_011835.json`.
- Static P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_41035/P1/P1_QM5_41035_result.json`.
- No smoke test, manual tester, pipeline phase runner, terminal control, or
  backtest was invoked.

## Capacity And Target-Only Queue Mutation

All samples counted only `terminal64.exe` processes whose executable path
matched exact `D:/QM/mt5/T1..T10/terminal64.exe` roots. `T_Live`, FTMO, and
other terminals were excluded.

- Initial sample at `2026-08-17T01:21:55.3559143Z`: 6/7,
  T1/T4/T5/T7/T9/T10.
- Immediate pre-apply sample at `2026-08-17T01:22:14.0087745Z`: 6/7,
  T1/T4/T5/T7/T9/T10.
- Post-enqueue sample at `2026-08-17T01:22:33.8639856Z`: 6/7,
  T1/T4/T5/T7/T9/T10.

The target-only dry run selected exactly one never-tested Q02 row and zero
stranded/recovery rows:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41035 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

The same scoped selection was applied once after the second capacity sample:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_41035 --max-part2-per-run 0
APPLY=True
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

Immediate `farmctl work-items --ea QM5_41035` readback found exactly one row:

| Field | Value |
|---|---|
| Work item | `6c8f3dd6-7d8c-4400-8c74-7f6cc754db29` |
| Phase / kind | `Q02` / `backtest` |
| Symbol / timeframe | `XTIUSD.DWX` / D1 |
| Created | `2026-08-17T01:22:20+00:00` |
| Observed status | pending, unclaimed |
| Attempt / evidence / verdict | 0 / none / none |

The rolling enqueue receipt is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, SHA-256
`9ef4f2c4ca0e18be33062ae4d106b463972118f2fa0c107c47eca4919b0a40d7`
at immediate readback.

## Artifact Integrity

| Artifact | SHA-256 |
|---|---|
| source approval | `7ca2e7d05fa8db202207b4f76c8a0c602cef0916e685330cfa51e64113a6befa` |
| G0 decision | `61d51338548a735c863fef1edac266f8e9e0d734c640ece7383262c54773ee42` |
| governed source packet | `9ff74b016dc8463d45f2552828f9cb94c5b7ab51bb86182b1ed943f709b68035` |
| each synchronized Strategy Card | `b3f8af4f8b6d57ceb959122c99efd85661a8368858a7144aa376bd46d4c7a8cb` |
| MQ5 source | `b404251b8d5d1401fabbec5c066a9dab125d6735a423c3ba8c827cae50e9a2d1` |
| compiled EX5 | `cade64d89083c6f90ff776a9797e682ffc73d7ca06150a27fb0efa9de285ec31` |
| SPEC | `702b38c60216e52bbc7e1cbc2b236076fa80af2f5e92848a188589b83b11c88d` |
| fixed-risk setfile | `bcb3a38a45ce488a74abc02c0d2b89911e86df1c1113a9e14d86ebc807c87db8` |
| reference suite | `3fcd75e759c98270a14bc413eb909fbcac660e8b5b6def08df4740011cdb07f3` |
| strict compile log | `1e321e315ef82a7b19b232a1530d93a6e50f6edd8acec48fcf6b4618abfe3393` |
| final build-check report | `67a61b53e9a0d34e6198c9401d7cefa4720df9ad8aeae60f983859c86088108a` |
| static P1 result | `20e40ba56e034619c945dddb3ed4921293be06db755812e45814924281f89a94` |

## Safety And Handoff

No manual backtest, smoke test, dispatcher tick, terminal start/stop, worker
mutation, AutoTrading action, `T_Live` access, live/demo/shadow/stress/
optimization preset, portfolio-gate edit, portfolio admission, deploy
manifest, or T_Live-manifest edit occurred.

Q02 must retire on zero trades, fewer than five completed positions per full
post-warm-up year, wrong month identity/endpoints, component agreement,
direction different from session flow, failed reconciliation, current-bar
leakage, late or repeated entry, wrong rollover lifecycle, nondeterminism,
invalid risk mode, or nonpositive governed economics. This receipt records an
enqueue, not a Q02 verdict, certification, profitability result, decorrelation
finding, or portfolio admission.

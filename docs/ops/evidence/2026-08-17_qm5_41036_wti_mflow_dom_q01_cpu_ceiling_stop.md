# QM5_41036 WTI Monthly Opposed-Flow Dominance — Q01 PASS / Q02 CPU-Ceiling Stop

Date: 2026-08-17 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT_ENQUEUED_CPU_CEILING`

## Candidate And Claim Boundary

`QM5_41036_wti-mflow-dom` is a new low-frequency direct-WTI structural
candidate. At the first executable `XTIUSD.DWX` D1 tick of a normalized
broker month, it reconstructs every completed session in the immediately
prior month plus the preceding month-end anchor. It separately sums
close-to-open and open-to-close log returns, requires strict opposite signs,
and reconciles the sum to the exact completed-month return within `1e-10`.
The sign of the component with larger absolute magnitude determines
direction. Equal magnitude, agreement, exact zero, invalid endpoints, failed
reconciliation, a late attachment, or a consumed month remains flat. An
opened position is held to the next normalized month, subject to its frozen
`3.5 * ATR(20,D1)` hard stop and 40-day stale guard.

The OWNER-approved packet combines the governed Tier-A Williams
public/professional information-clock decomposition with the complete-read,
peer-reviewed WTI one-month carrier lineage in Moskowitz, Ooi, and Pedersen
(2012). Neither source tests this exact conjunction, Darwinex continuous-CFD
mapping, timing, risk, profitability, or correlation. These remain explicit
QM falsification questions; this Q01 receipt makes no decorrelation,
certification, or portfolio-admission claim.

## Governance And Non-Duplicate Boundary

- Source approval commit: `81183098b`.
- Deterministic EA-ID reservation commit: `747c5646e`.
- Strategy Card and OWNER G0 commit: `059b4d12a`.
- Pre-magic directory identity commit: `0c72e0ce0`.
- Magic registration/resolver commit: `16361de8c`.
- Q01 build commit: `575f65b58`.
- Registered route: slot 0, `XTIUSD.DWX`, magic `410360000`.
- The canonical pre-card checker scanned 4,523 registry rows and 619 cards,
  found no exact identity, and raised the expected WTI information-flow
  family for manual review.
- `QM5_41035_wti-mflow-div` always follows the session component during a
  monthly opposition state. This EA follows whichever opposed component has
  larger absolute magnitude.
- `QM5_41034_wti-mflow-agree` admits only same-sign monthly components;
  this EA rejects agreement and admits only opposition.
- `QM5_41033_wti-flow-dom` uses a weekly Monday-to-Friday cadence; this EA
  consumes a full completed broker month and holds to the next month.
- Manual verdict:
  `CLEAN_WTI_MONTHLY_OPPOSED_FLOW_DOMINANCE_AFTER_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- The sole preset is a backtest setfile with `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Both news axes and framework
  Friday close are OFF; no live/demo/shadow/stress/optimization set exists.
- Independent mechanic suite: 20 tests PASS, covering both energy-label
  conventions, month/anchor identity, 15/25 session bounds, all endpoints,
  opposition/agreement/zero/equal-magnitude states, all four component-
  dominance directions, reconciliation, restart grace, persisted attempt,
  fixed risk, and next-month rollover.
- All three Strategy Card copies are byte-identical and pass schema/G0/ML
  lint.
- Direct strict MetaEditor compile: PASS, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260817_022304/QM5_41036_wti-mflow-dom.compile.log`.
- Target-scoped strict build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260817_022335.json`.
- No backtest, smoke test, manual tester, phase runner, dispatcher tick, or
  terminal control was invoked.

## Binding Capacity Gate

The read-only capacity sample counted only `terminal64.exe` processes whose
resolved executable path exactly matched `D:/QM/mt5/T1..T10/terminal64.exe`.
It excluded `T_Live`, FTMO, and all non-factory terminals:

| Terminal | PID |
|---|---:|
| T1 | 11608 |
| T4 | 14920 |
| T5 | 11888 |
| T6 | 12228 |
| T8 | 7060 |
| T9 | 7804 |
| T10 | 14244 |

Seven governed roots were active, exactly the paced-fleet ceiling of seven.
The enqueue helper's `--help` path emitted an `APPLY=False` dry-run summary
rather than help; it made no queue mutation. Per the mission stop condition,
no `--apply`, enqueue, dispatch, or tester action followed. Immediate
read-only `farmctl work-items --ea QM5_41036` returned `count=0`, so no Q02
row exists from this handoff.

## Artifact Integrity

| Artifact | SHA-256 |
|---|---|
| source approval | `bfeaf4436961d03ca332b24f4c6c36905a3b9cfb3d005173563455fa6a01e98b` |
| G0 decision | `b3ee75f40a96f4317878a29fda45e8a97884efd7ca8ceb2c8b4668c2a22d50d6` |
| governed source packet | `a9e33fdca5b12d91b7a9e2ba93e065d2a3d90676c934d50eda185068e4f780d4` |
| each synchronized Strategy Card | `0253441fa79b644a5ee54b37c226b92be175e6d057eb32ad57f3120675405769` |
| MQ5 source | `baf3cece07b9eed8256753b3918479ad6ba0867094f85fe449019ab9006c803c` |
| compiled EX5 | `c86fe8d74e11c586a123e3f3bb0b6cb0e0c03e6859c0e1116b6aa29afb9cb27b` |
| SPEC | `2b40f702bb98f83f3379b9309cf9d3864c3225ec54f589f9aae3a50c840b3411` |
| fixed-risk setfile | `a19b69299f49449fcd4939d86e809e9c147ed7dc71b10c0db516c0dfbc9a6276` |
| reference suite | `a7a4167bc631fae63fab07267dcde1e81d9480cd6bb544eb6031bc4c35ef80b7` |
| direct strict compile log | `717b8df0fa615b4c84637ae992f4ee5a43cbfe153a6e0ad89a221b93ab666101` |
| final build-check report | `3fd2b939ad196d39f59d381027cb58e40b225e8562334262f07582d5c274286b` |

## Safety And Handoff

No queue apply, backtest, terminal start/stop, worker mutation, AutoTrading
action, `T_Live` access, live manifest, portfolio gate, deploy manifest,
portfolio admission, or correlation waiver occurred.

The next authorized action is a fresh exact-path capacity sample, followed
only when below seven by one target-scoped Q02 dry run and apply. Q02 must
retire on zero trades, fewer than five completed positions per full post-
warm-up year, wrong month identity/endpoints, invalid opposition/dominance,
failed reconciliation, leakage, late/repeated entry, wrong lifecycle,
nondeterminism, invalid risk mode, or nonpositive governed economics.

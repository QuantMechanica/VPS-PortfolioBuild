# QM5_41032 WTI Weekly Flow-Divergence Build And Q02 Enqueue

Date: 2026-08-17 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 ENQUEUED`

## Candidate And Claim Boundary

`QM5_41032_wti-flow-div` is a new low-frequency direct-WTI structural
candidate. On the first eligible tick of a genuine Monday, it reconstructs
the exact completed prior Monday-through-Friday `XTIUSD.DWX` D1 week plus the
preceding-Friday close. It separately sums five close-to-open log returns as
overnight public flow and five open-to-close log returns as professional
session flow. It buys only when session flow is positive and overnight flow
is negative, and sells only when session flow is negative and overnight flow
is positive. Agreement and exact-zero states are flat. The ordinary exit is
the framework Friday close at broker hour 21.

The OWNER-approved source packet combines a fully preserved Tier-A
public/professional flow-decomposition extraction with peer-reviewed WTI trend
carrier lineage. The exact opposition rule, session-following direction, CFD
mapping, timing, risk, profitability, and portfolio relationship are disclosed
QM falsification choices. No source result or decorrelation claim transfers.

## Governance, Allocation, And Non-Duplicate Boundary

- Source approval commit: `ae0550fda`.
- Deterministic EA-ID reservation commit: `ef287429d`.
- Strategy Card and OWNER G0 commit: `27fdad84e`.
- Pre-magic directory identity commit: `7e3d55463`.
- Magic registration/resolver commit: `b930122a7`.
- Q01 build commit: `57f3f3c2a`.
- Registered slot 0 is `XTIUSD.DWX`, magic `410320000`.
- The canonical checker scanned 4,519 registry rows and 615 root cards, found
  no exact duplicate, and raised the expected lexical family neighbors for
  manual review.
- `QM5_41029_wti-flow-agree` trades only same-sign weekly components; this EA
  trades only the disjoint sign-opposition states and follows session flow.
- `QM5_12784` uses 14-day signed-value moving averages and line crossings;
  this EA uses fixed five-session log sums, no line, and an exact weekly clock.
- `QM5_41030` is a market-neutral XAU/XAG cross-metal basket; this EA is direct
  WTI, has no cross-asset subtraction, and owns one leg.
- `QM5_21520` is XNG close-return/tick-volume rank logic, while
  `QM5_12567` is an oscillator pullback; neither shares this endpoint split.
- Verdict: `CLEAN_WTI_WEEKLY_FLOW_OPPOSITION_FOLLOW_SESSION`.

## Fixed-Risk Build And Q01 Evidence

- Exact route: `XTIUSD.DWX`, D1, slot 0.
- The only preset is a backtest setfile with `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; both news axes are OFF.
- Each position has a frozen `3.0 * ATR(20,D1)` hard stop, no target, no
  scaling, and no retry after the persisted Monday attempt.
- Independent reference suite: 12 tests PASS for both divergence directions,
  agreement/zero rejection, endpoint integrity, flow reconciliation, calendar
  labels, holiday rejection, grace timing, date identity, and stale repair.
- All three Strategy Card copies are byte-identical and pass card/schema/ML
  lint. The seven-section spec and fixed-risk set identity pass.
- Strict MetaEditor compile: PASS, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260816_220539/QM5_41032_wti-flow-div.compile.log`.
- Targeted build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260816_220604.json`.
- Static P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_41032/P1/P1_QM5_41032_result.json`.
- No smoke test, manual tester, pipeline phase runner, or terminal control was
  invoked.

## Capacity And Target-Only Queue Mutation

All samples counted only `terminal64.exe` processes whose executable path
matched exact `D:/QM/mt5/T1..T10/terminal64.exe` roots. `T_Live`, FTMO, and
other terminals were excluded.

- Initial sample at `2026-08-16T22:07:14.6187072Z`: 6/7,
  T1/T2/T3/T4/T5/T7.
- Immediate pre-apply sample at `2026-08-16T22:07:31.6528550Z`: 6/7,
  T1/T2/T3/T4/T5/T7.
- Post-enqueue sample at `2026-08-16T22:07:58.6968962Z`: 6/7,
  T1/T2/T3/T4/T5/T7.

The target-only dry run selected exactly one never-tested Q02 row and zero
stranded/recovery rows:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41032 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

The same scoped selection was applied once after the second capacity sample:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_41032 --max-part2-per-run 0
APPLY=True
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

Immediate `farmctl work-items --ea QM5_41032` readback found exactly one row:

| Field | Value |
|---|---|
| Work item | `ec025b29-077d-46ba-bedc-4f45033d520b` |
| Phase / kind | `Q02` / `backtest` |
| Symbol / timeframe | `XTIUSD.DWX` / D1 |
| Created | `2026-08-16T22:07:31+00:00` |
| Observed status | pending, unclaimed |
| Attempt / evidence / verdict | 0 / none / none |

The rolling enqueue receipt is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, SHA-256
`fc193f75dd1b5cf90b15c89294ecd93ad70599f06846c63eb2ee416be775bc88`
at immediate readback.

## Artifact Integrity

| Artifact | SHA-256 |
|---|---|
| source approval | `f883ee2327cb25bd699752bff20f1a6ed77ffe53438de0696855c09f1911c2e6` |
| G0 decision | `1a66c52c44e45706a4d20d9ac8372bbab089851c1d66ac9040c296bc1fb69a18` |
| governed source packet | `0ab5c5ae14253c8636c721f36f16c778de51120a65f0ab5f52948811b6ad88d7` |
| each synchronized Strategy Card | `70427faea684145f59c5e3d1077eb3c4a608044411d785dcec9765e0ad8edf0b` |
| MQ5 | `56d6102fd04e8b111f32621a947d2daa2ec7aef46753b14d2fd45a91c851cc79` |
| EX5 | `c0f99e7636d31eefef010a4a9354dfb034b5b0e6f7fab6a43b7385c2de95083f` |
| SPEC | `bfe27917780aceac134a5cd7b96c33250ffdb5f35bfc8171908ee1917c99b58e` |
| fixed-risk setfile | `a3c71383ed82d3af6a3d4ca7b9e1871ef5820eb4ef19f07101abd88e4f568fa6` |
| reference suite | `77699b1ab0ca145663001662b6f3d6bb93a990b04cfea2cd1114af79d7c08ebd` |
| build-check report | `c41dfce922d3854ceeef7cc460970ca9ddc42db8c611d3cb566cb65c96472549` |
| static P1 result | `52f4c69281343abee83bc075d5a69ec1f504c24e215ba43a2e9afd89380cb7ed` |

## Safety And Handoff

No manual backtest, smoke test, dispatcher tick, terminal start/stop,
reservation change, AutoTrading action, `T_Live` action, live/demo/shadow/
stress/optimization preset, deploy or T_Live manifest, portfolio-gate edit,
portfolio admission, or correlation waiver occurred.

Q02 must retire on zero trades, fewer than five completed positions per full
post-warm-up year, wrong weekday sequence or endpoints, agreement-state entry,
direction opposite session flow, current-bar leakage, late or repeated Monday
entry, wrong lifecycle, nondeterminism, invalid risk mode, or nonpositive
governed economics. This receipt records an enqueue, not a Q02 verdict,
certification, profitability result, decorrelation finding, or portfolio
admission.

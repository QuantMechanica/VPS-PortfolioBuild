# QM5_41034 WTI Monthly Flow Agreement — Q01 PASS / Q02 CPU-Ceiling Stop

Date: 2026-08-17 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT_ENQUEUED_CPU_CEILING`

## Candidate And Claim Boundary

`QM5_41034_wti-mflow-agree` is a new low-frequency direct-WTI structural
candidate. On the first executable `XTIUSD.DWX` D1 tick of a normalized broker
month, it reconstructs every completed session in the immediately prior month
plus the preceding month-end anchor. It separately sums close-to-open and
open-to-close log returns, requires both components to share one strict sign,
and reconciles their sum to the exact completed-month return within `1e-10`.
It follows the agreed direction through the current month and exits at the
first observed next-month boundary. Opposition, equality, zero, invalid
arithmetic, failed reconciliation, 15/25-session-bound failure, or a late or
consumed month is flat.

The OWNER-approved packet joins the complete governed Tier-A Williams
public/professional information-time decomposition with the complete-read,
peer-reviewed WTI one-month formation/hold lineage in Moskowitz, Ooi, and
Pedersen (2012). Neither source tests this exact conjunction, Darwinex
continuous-CFD mapping, broker-label normalization, timing, risk,
profitability, or portfolio relationship. Those are disclosed QM
falsification choices; no source result or decorrelation claim transfers.

## Governance, Allocation, And Non-Duplicate Boundary

- Source approval commit: `ddb43e0da`.
- Deterministic EA-ID reservation commit: `043a5f7ee`.
- Strategy Card and OWNER G0 commit: `1269dd608`.
- Pre-magic directory identity commit: `f07a08b06`.
- Magic registration/resolver commit: `276b49ea9`.
- Q01 build commit: `e977b057e`.
- Registered slot 0 is `XTIUSD.DWX`, magic `410340000`.
- The canonical pre-card checker scanned 4,521 EA-registry rows and 617 card
  files, found no exact identity, and raised the expected WTI-flow family for
  manual review.
- `QM5_41029_wti-flow-agree` reconstructs one exact week and holds
  Monday-to-Friday. This EA consumes an entire completed broker month and
  holds to the next month.
- `QM5_20187_wti-tsmom1m` follows every nonzero completed-month total. This EA
  admits only the strict same-sign information-flow subset.
- `QM5_41032_wti-flow-div` and `QM5_41033_wti-flow-dom` trade weekly
  opposition states; `QM5_41023_wti-mends-mom` compares month-boundary
  close-to-close segments for a five-session hold; `QM5_12784_progo-xti`
  uses 14-day moving-line crossings.
- Verdict:
  `CLEAN_WTI_MONTHLY_INFORMATION_FLOW_AGREEMENT_AFTER_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Exact route: `XTIUSD.DWX`, D1, slot 0.
- The only preset is a backtest setfile with `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; both news axes and framework
  Friday close are OFF.
- Each position has one frozen `3.5 * ATR(20,D1)` hard stop, no target, no
  scaling, a 1,500-point spread ceiling, and no retry after the persisted
  monthly attempt.
- Independent reference suite: 15 tests PASS, including both label offsets,
  exact month/anchor identity, 15/25 session bounds, every endpoint,
  agreement/disagreement/zero states, reconciliation, grace timing, attempt
  identity, fixed risk, and next-month rollover.
- All three Strategy Card copies are byte-identical and pass schema/G0/ML
  lint. The seven-section spec, deterministic registry identities, and target
  build guardrails pass.
- Strict MetaEditor compile: PASS, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260817_002122/QM5_41034_wti-mflow-agree.compile.log`.
- Targeted final build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260817_002244.json`.
- Static P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_41034/P1/P1_QM5_41034_result.json`.
- No smoke test, manual tester, pipeline phase runner, terminal control, or
  backtest was invoked.

## Binding Capacity Gate

The exact-path read-only sample at `2026-08-17T00:26:08.5213140Z` counted only
`terminal64.exe` processes whose executable path matched exact
`D:/QM/mt5/T1..T10/terminal64.exe` roots. It explicitly excluded `T_Live`,
FTMO, and every non-factory terminal:

| Terminal | PID |
|---|---:|
| T1 | 17768 |
| T2 | 2460 |
| T3 | 10208 |
| T4 | 14920 |
| T5 | 2044 |
| T9 | 17120 |
| T10 | 11684 |

Seven governed roots were running, exactly the seven-terminal paced-fleet
ceiling. Per the mission stop condition, neither the target-only queue dry run
nor any apply/enqueue command was invoked. Immediate read-only
`farmctl work-items --ea QM5_41034` returned `count=0`; no Q02 row exists from
this handoff.

## Artifact Integrity

| Artifact | SHA-256 |
|---|---|
| source approval | `85e33773c2ef2b750117350a409538d3329fa56e8395e579601a3a0722a28c06` |
| G0 decision | `a4572660ec2836c73bc1dd0145e5e015db4598e02c1c813ac8c32bbe12064b75` |
| governed source packet | `5a964b304dac1cb19d258b1f049b5d12004473bdffa71bd6451622acd0732124` |
| each synchronized Strategy Card | `f01b2fa5f362ebd63f642ee18e46b2d738a262d470fcecd3bf6e573288983c85` |
| MQ5 source | `bef76798b44ff0d098745277d05f39ed79f01e234a5aab0fdf3a9bc9355e719d` |
| compiled EX5 | `91f7f5acc0b5a4388bb9febcf0e413ce6e27127262152a4164f0a6d51c096b07` |
| SPEC | `38053463bb8eb0a0e5147862b41c00d3f97370589a2f7fa00ac0bec991d366e9` |
| fixed-risk setfile | `98a3948cf45bf56e4b8376d2edc248018effb27aa0f05c57c0058461c121e37a` |
| reference suite | `2e5634651f26a1ed9a8cf0752cf72f1ad71c0b21f4ae037938f20b72bbbfd71e` |
| strict compile log | `7a9ed6616953456a737895f26cf57a828235ade31833618a4a1998eacf02beca` |
| final build-check report | `2d3d0691215c2e6f1da63eb871f92989c196054ea7e77ac755adc956b30545e3` |
| static P1 result | `ec44579ac881ce51d1786afcc3c776a123de5a7552107284d7f28a0aa43ab22d` |

## Safety And Handoff

No queue dry run, queue apply, dispatcher tick, manual tester run, pipeline
phase runner, terminal start/stop, worker mutation, AutoTrading action,
`T_Live` access, live/demo/shadow/stress/optimization preset, portfolio-gate
edit, portfolio admission, deploy manifest, or T_Live-manifest edit occurred.

The next authorized action is one target-only paced Q02 enqueue only after a
fresh exact-path T1-T10 sample is below seven. Q02 must retire on zero trades,
fewer than five completed positions per full post-warm-up year, wrong month
identity/endpoints, component opposition, failed reconciliation, direction
different from the agreed completed flow, current-bar leakage, late or
repeated entry, wrong rollover lifecycle, nondeterminism, invalid risk mode,
or nonpositive governed economics. This receipt records a capacity stop, not
a Q02 verdict, certification, profitability result, decorrelation finding, or
portfolio admission.

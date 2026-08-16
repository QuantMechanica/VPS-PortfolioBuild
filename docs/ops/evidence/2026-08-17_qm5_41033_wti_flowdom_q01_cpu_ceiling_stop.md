# QM5_41033 WTI Flow Dominance — Q01 PASS / Q02 CPU-Ceiling Stop

Date: 2026-08-17 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT_ENQUEUED_CPU_CEILING`

## Candidate And Claim Boundary

`QM5_41033_wti-flow-dom` is a new low-frequency direct-WTI structural
candidate. On the first eligible tick of a genuine broker Monday, it
reconstructs the exact completed prior Monday-through-Friday
`XTIUSD.DWX` D1 week plus the preceding-Friday close. It separately sums five
close-to-open and five open-to-close log-return components, requires their
signs to oppose, and reconciles their sum to the exact completed
Friday-to-Friday return. A positive reconciled total buys and a negative total
sells, so direction follows the component with larger absolute magnitude.
Agreement, equality, zero, invalid arithmetic, failed reconciliation, a
holiday shift, or a consumed/late Monday is flat. Framework Friday close at
broker hour 21 is the ordinary exit.

The OWNER-approved source packet joins a complete Tier-A Williams
public/professional flow-decomposition extraction with complete-read,
peer-reviewed WTI trend-carrier lineage from Moskowitz, Ooi, and Pedersen
(2012). Neither source tests this exact conjunction, opposition gate,
dominant-component translation, Darwinex continuous CFD mapping, timing,
risk, profitability, or portfolio relationship. Those are disclosed QM
falsification choices; no source result or decorrelation claim transfers.

## Governance, Allocation, And Non-Duplicate Boundary

- Source approval commit: `1447c6ba8`.
- Deterministic EA-ID reservation commit: `2f63c7b5f`.
- Strategy Card and OWNER G0 commit: `e4fdb9ee5`.
- Pre-magic directory identity commit: `e8b1ad6cc`.
- Magic registration/resolver commit: `77a0cadb2`.
- Q01 build commit: `b78e9233b`.
- Registered slot 0 is `XTIUSD.DWX`, magic `410330000`.
- The canonical pre-card checker scanned 4,520 registry rows and 616 card
  files, found no exact identity, and raised the expected WTI-flow family for
  manual review.
- `QM5_41032_wti-flow-div` shares the strict sign-opposition eligibility state
  but always follows session flow. This EA follows the reconciled total: it
  agrees only when session magnitude dominates, takes the opposite side when
  overnight magnitude dominates, and is flat on equality.
- `QM5_41029_wti-flow-agree` trades the disjoint same-sign state;
  `QM5_41022_wti-wdual-mom` splits close-to-close weekly segments rather than
  every session by information time; the other reviewed WTI/XNG neighbors use
  rolling thresholds, ranks, line crossings, or different carriers.
- Verdict:
  `CLEAN_WTI_WEEKLY_OPPOSED_FLOW_DOMINANCE_AFTER_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Exact route: `XTIUSD.DWX`, D1, slot 0.
- The only preset is a backtest setfile with `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; both news axes are OFF and
  Friday close is ON at broker hour 21.
- Each position has one frozen `3.0 * ATR(20,D1)` hard stop, no target, no
  scaling, and no retry after the persisted exact-Monday attempt.
- Independent reference suite: 15 tests PASS, including both session-dominant
  directions, both overnight-dominant directions, equality/agreement/zero
  rejection, reconciliation failure, all-ten-endpoint telescoping, exact
  calendar labels, holiday rejection, grace timing, attempt identity, and
  stale repair.
- All three Strategy Card copies are byte-identical and pass card/schema/ML
  lint. Target-specific strict execution-contract issues are zero; the global
  contract audit still reports unrelated pre-existing calendar/hash debt.
- Strict MetaEditor compile: PASS, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260816_231159/QM5_41033_wti-flow-dom.compile.log`.
- Targeted final build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260816_231231.json`.
- Static P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_41033/P1/P1_QM5_41033_result.json`.
- No smoke test, manual tester, pipeline phase runner, terminal control, or
  backtest was invoked.

## Binding Capacity Gate

The exact-path read-only sample at `2026-08-16T23:13:27.1452304Z` counted only
`terminal64.exe` processes whose executable path matched exact
`D:/QM/mt5/T1..T10/terminal64.exe` roots. It explicitly excluded `T_Live`,
FTMO, and every non-factory terminal:

| Terminal | PID |
|---|---:|
| T1 | 19552 |
| T3 | 10208 |
| T5 | 2044 |
| T6 | 17520 |
| T7 | 360 |
| T8 | 12488 |
| T9 | 15740 |

Seven governed roots were running, exactly the seven-terminal paced-fleet
ceiling. Per the mission stop condition, neither the target-only queue dry run
nor any apply/enqueue command was invoked. Immediate read-only
`farmctl work-items --ea QM5_41033` returned `count=0`; no Q02 row exists from
this handoff.

## Artifact Integrity

| Artifact | SHA-256 |
|---|---|
| source approval | `1648dd97c90d3af06b66651eb7db3015622298a2e7bd7202d5871d6396db7e6e` |
| G0 decision | `56d34d64120f59fe7f497b638475e750ddd53e43d1e632c97ccc4b63cc99e713` |
| governed source packet | `0992a196d92aad091ada57fe0a4ae3b4590182cc88977580e5185d403b2f83a8` |
| each synchronized Strategy Card | `a0cd7ec520fa6c3b55d4484d3330df77edc7f31117df7d1e580687b0153c4e71` |
| MQ5 source | `ec2bc4cee9ad9be033175b7ab4c45d5a7d77d4832566077edfe9cc1602826e68` |
| compiled EX5 | `a2b81cf05fdd76f9ea9559d6a85c36165755771af2c3883642c6124af6c568d6` |
| SPEC | `2e2030a72a11603f8ccabe953262d9a15a4f0097a220c2d133d0533498119ba7` |
| fixed-risk setfile | `98f3a253582a26cf9094c3733f82fe9377ba59e22b66c574b1d3ddd3a5b632c5` |
| reference suite | `8a1237073140fc3fb55a5377d91f37b62798c4ea98307b4f72411a03aac6c285` |
| final build-check report | `657e7583fcc29c6d29222aa9f399524c323187dbd06c2921cfada67cdc80d6ce` |
| static P1 result | `587d27bc26860643a144076d90ac76402706b57d77a5bf02c6495f677997b5eb` |

## Safety And Handoff

No queue dry run, queue apply, dispatcher tick, manual tester run, pipeline
phase runner, terminal start/stop, worker mutation, AutoTrading action,
`T_Live` access, live/demo/shadow/stress/optimization preset, portfolio-gate
edit, portfolio admission, deploy manifest, or T_Live-manifest edit occurred.

The next authorized action is one target-only paced Q02 enqueue only after a
fresh exact-path T1-T10 sample is below seven. Q02 must retire on zero trades,
fewer than five completed positions per full post-warm-up year, wrong weekly
identity/endpoints, agreement-state entry, failed reconciliation, direction
different from the completed total-flow sign, current-bar leakage, late or
repeated Monday entry, wrong lifecycle, nondeterminism, invalid risk mode, or
nonpositive governed economics. This receipt records a capacity stop, not a
Q02 verdict, certification, profitability result, decorrelation finding, or
portfolio admission.

# QM5_41030 XAU/XAG Relative-Flow Divergence — Q01 PASS / Q02 CPU-Ceiling Stop

Date: 2026-08-16 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT_ENQUEUED`

## Candidate And Claim Boundary

`QM5_41030_xauxag-flowdiv` is a new low-frequency XAU/XAG logical basket.
On an exact synchronized broker Monday it decomposes both metals' completed
prior Monday-through-Friday week into close-to-open and open-to-close log
flows. It subtracts silver from gold in each component and trades only strict
disagreement, following the session-relative sign with opposite equal-
notional legs through Friday.

The opposite legs seek to suppress common precious-metal direction. They do
not establish beta, volatility, factor, market, dollar, or portfolio
neutrality. Q09 alone may establish realized correlation if the candidate
survives earlier gates.

## Governed Lineage, Allocation, And Non-Duplicate Boundary

- Source approval commit:
  `ee6468d58337120ca856dd365a1295e2138000c3`.
- Deterministic EA allocation commit:
  `1e77986e5b78ba52659d020ed944f18245338efa`.
- Approved card and G0 commit:
  `c587eee813b5be6d1346613052236a6639345fb2`.
- Pre-magic directory identity commit:
  `99312b9d60c1a438b9afe98c523208ce50534056`.
- Two-magic registration and resolver commit:
  `bcf8a757f651c3401a284112f0837277a922674f`.
- Q01 build commit:
  `d6aff54e59f6cbd23c3a44e6cc2f2d53d7ceccae`.
- Registered slots are XAU slot 0 / magic `410300000` and XAG slot 1 /
  magic `410300001`.
- The pre-allocation checker scanned 4,517 registry rows and 613 root cards
  with no exact or fuzzy match. Manual review separated fixed weekend,
  ratio/residual-level, monthly cross-sectional momentum, fresh-run fade,
  single-leg WTI flow-agreement, and commodity-oscillator families.
- Verdict:
  `CLEAN_XAUXAG_WEEKLY_RELATIVE_FLOW_DISAGREEMENT_SESSION_FOLLOW_AFTER_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Logical carrier: `QM5_41030_XAU_XAG_FLOWDIV_D1`, hosted on
  `XAUUSD.DWX` D1 with companion `XAGUSD.DWX`.
- The only preset is a backtest setfile with `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; both news axes are OFF.
- Each leg has a frozen `3.0 * ATR(20,D1)` hard stop; package sizing uses
  final normalized stop distances, one aggregate fixed-risk budget, an equal-
  notional target, and a 20% post-rounding mismatch cap.
- Independent reference suite: 12 tests PASS for synchronized calendar
  identity, no holiday substitution, both strict disagreement directions,
  agreement/zero flat behavior, completed endpoint reconciliation, entry
  grace, package sizing, attempt identity, and weekly lifecycle.
- Strict MetaEditor compile: PASS, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260816_200126/QM5_41030_xauxag-flowdiv.compile.log`.
- Targeted strict build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260816_200126.json`.
- Static P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_41030/P1/P1_QM5_41030_result.json`.
- All three Strategy Card copies are byte-identical and pass schema/ML lint.
- The basket manifest and locked logical-basket setfile identities validate.

## Binding Capacity Gate

The fresh path-anchored read-only sample at
`2026-08-16T20:04:37.1494225Z` counted only `terminal64.exe` processes whose
executable path matched exact `D:/QM/mt5/T1..T10/terminal64.exe` roots. It
excluded `T_Live` and every non-factory terminal:

| Terminal | PID |
|---|---:|
| T1 | 12792 |
| T2 | 15160 |
| T3 | 9480 |
| T4 | 15464 |
| T5 | 14692 |
| T7 | 19196 |
| T9 | 4536 |
| T10 | 12036 |

Eight factory terminals were running, exceeding the seven-terminal paced-
fleet ceiling. Per the mission stop condition, no target-only selection dry
run, enqueue/apply command, dispatcher tick, phase runner, or manual tester was
invoked. Q02 remains `NOT_ENQUEUED`; no work item was created by this task.

## Artifact Integrity

| Artifact | SHA-256 |
|---|---|
| source approval | `9C9CC1A8C46B1FC8D9F093D04D8423F87BC53907A80C7A163235D1FE6EF70F00` |
| G0 decision | `203A894C96996B9DCCB5DFF13684A0D4F4729E3D06F497A84BAC4C28E25F0455` |
| governed source packet after capacity seal | `6B58F287E6E56275933986096DE6993CC4DBD70B358DAE8603FA71B1BB337EFC` |
| each synchronized Strategy Card after capacity seal | `42574049865E1FB21CD566FF3BB671C5F8279EF4AD503BC90369B70F4B79FD70` |
| MQ5 | `2C788859A5A85842F00F58C9141DF91DF1E159AD8137501CC9B56E7AE4879EA0` |
| EX5 | `194E3B4180D3423A3F572B35659820B6E76E88EE8EAB497DBD04463C684B9830` |
| SPEC after capacity seal | `3D79B80E48BAD71F6ABA9CB36B4CAC81647C64DFCC5B37C051A41B60ED67BE94` |
| basket manifest | `65C61EAC399698B6E4494B29F48D42BAB3D45FBE55992EDB46879558140C45B6` |
| fixed-risk setfile | `3ECEA1B5981F5BB346D78724FB3910502C907B3A06E232B8B4F0313D37F3C849` |
| reference suite | `4D2F9593BD03DEB680775EE92CF29EBEDCD9D1AF45E007F37FFF947714653747` |
| strict build-check report | `F6CD697B3CAC0D6F404187E335BF02AA47B83E7D360474B9CA52B7EBCCEDE24A` |
| static P1 result | `3153961488DB46095106C50CA5C26FBAAD339B7141CE8990D3F719D4F85CBD59` |

## Safety And Handoff

No queue mutation, backtest, worker reservation, terminal start/stop,
AutoTrading action, `T_Live` state change, live/demo/shadow/stress/optimization
preset, deploy manifest, T_Live manifest, portfolio-gate edit, portfolio
admission, or correlation waiver occurred.

The next authorized action is one target-only paced Q02 enqueue only after a
fresh exact-path T1-T10 sample is below seven. Q02 must retire on zero trades,
fewer than five completed packages per full post-warm-up year, wrong or
shifted calendar identity, wrong endpoints/subtraction/signs/sides, current-
bar leakage, late or repeated entry, excess risk or hedge mismatch, orphan
survival, wrong lifecycle, nondeterminism, invalid risk mode, or nonpositive
governed economics. This receipt is a capacity stop, not a Q02 verdict,
certification, profitability result, decorrelation finding, or portfolio
admission.

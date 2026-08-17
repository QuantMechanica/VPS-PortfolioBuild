# QM5_41037 XNG Monthly Information-Flow Divergence — Q01 PASS / Q02 CPU-Ceiling Stop

Date: 2026-08-17 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT_ENQUEUED_CPU_CEILING`

## Candidate And Claim Boundary

`QM5_41037_xng-mflow-div` is a new low-frequency natural-gas structural
candidate. At the first executable `XNGUSD.DWX` D1 tick of a normalized
broker month, it reconstructs every completed session in the immediately
prior month plus the preceding month-end anchor. It separately sums
prior-close-to-open and open-to-close log returns, requires strictly opposed
component signs, and reconciles their sum to the exact completed-month return
within `1e-10`. It follows the session component: positive session flow
against negative overnight flow buys, while negative session flow against
positive overnight flow sells. Agreement, exact zero, invalid endpoints,
failed reconciliation, a late attachment, or a consumed month remains flat.

An opened position is held to the next normalized broker month, subject to a
frozen `3.5 * ATR(20,D1)` hard stop and a 40-day stale guard. The sole preset
is the backtest baseline with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

The approved packet combines the governed Tier-A Williams
public/professional information-clock decomposition with the complete-read,
peer-reviewed natural-gas one-month carrier lineage in Moskowitz, Ooi, and
Pedersen (2012). Neither source tests this exact conjunction, Darwinex
continuous-CFD mapping, timing, risk, profitability, or correlation. These
remain explicit QM falsification questions; this receipt makes no
certification, decorrelation, or portfolio-admission claim.

## Governance And Non-Duplicate Boundary

- Source approval commit: `29856a0d7`.
- Deterministic EA-ID reservation commit: `ad2300bdd`.
- Strategy Card and OWNER G0 commit: `e1101d71c`.
- Pre-magic directory identity commit: `2b458b64b`.
- Magic registration/resolver commit: `f249b8a7d`.
- Q01 build commit: `1f0bcd2fc`.
- Registered route: slot 0, `XNGUSD.DWX`, magic `410370000`.
- The canonical pre-card checker scanned 4,524 registry rows and 620 cards,
  found no exact identity, and raised only the expected information-flow
  family for manual review.
- `QM5_12567` is a long-only D1 RSI(2)/SMA(200) pullback with oscillator and
  time exits. This candidate is symmetric, monthly, and uses only completed
  open/close return decomposition.
- `QM5_20204_xng-tsmom1m` follows every nonzero completed-month total; this
  candidate trades only opposed components and follows session-flow sign.
- `QM5_20054_xng-1m-contr` fades every completed-month total; this candidate
  never uses total-return direction as its entry direction.
- `QM5_21504_xng-flowrev` and `QM5_21520_xng-flow-mom` use weekly
  five-close/tick-volume tails; this candidate uses a completed broker-month
  open/close decomposition and no volume.
- `QM5_41035_wti-mflow-div` carries the same information-clock rule on WTI.
  This card is the explicitly authorized second-XNG carrier and is not a
  duplicate of the existing certified XNG RSI/MA logic.
- Manual verdict:
  `CLEAN_XNG_MONTHLY_PUBLIC_SESSION_FLOW_DIVERGENCE_AFTER_CARRIER_AND_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- The sole preset is a backtest setfile. Both news axes and framework Friday
  close are OFF; no live/demo/shadow/stress/optimization set exists.
- Independent mechanic suite: 19 tests PASS, covering both energy-label
  conventions, month/anchor identity, 15/25 session bounds, every endpoint,
  opposition/agreement/zero states, session direction independent of total
  sign, reconciliation, restart grace, attempt identity, fixed risk, and
  next-month rollover.
- All three Strategy Card copies are byte-identical and pass schema/G0/ML
  lint.
- Direct strict MetaEditor compile: PASS, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260817_033613/QM5_41037_xng-mflow-div.compile.log`.
- Target-scoped strict build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260817_033633.json`.
- Static P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_41037/P1/P1_QM5_41037_result.json`.
- No backtest, smoke test, manual tester, phase runner, dispatcher tick, or
  terminal control was invoked.

## Binding Capacity Gate

At `2026-08-17T03:39:17.4615208Z`, the read-only capacity sample counted
only `terminal64.exe` processes whose resolved executable path exactly
matched `D:/QM/mt5/T1..T10/terminal64.exe`. It excluded `T_Live`, FTMO,
and all non-factory terminals:

| Terminal | PID |
|---|---:|
| T1 | 9044 |
| T2 | 1960 |
| T4 | 14920 |
| T6 | 5284 |
| T7 | 10276 |
| T8 | 16584 |
| T9 | 14040 |
| T10 | 19652 |

Eight governed roots were active, exceeding the paced-fleet ceiling of seven.
Per the mission stop condition, no enqueue-helper dry run, `--apply`,
enqueue, dispatch, backtest, or tester action followed. Immediate read-only
`farmctl work-items --ea QM5_41037` returned `count=0`, so no Q02 row
exists from this handoff.

## Artifact Integrity

| Artifact | SHA-256 |
|---|---|
| source approval | `cf79ee266bb2aaad1b57b189722c56eb4bdcc74f221bcde45a1619f34b7998a3` |
| G0 decision | `cb812420298d7c605162341e478624bf284bf77779baafcf55c05c39ae996970` |
| governed source packet | `7efcdabeeedd6ebe10e60ad56c286c6c71f2ed86f5f6e575e6bb3fc56e7c6c32` |
| each synchronized Strategy Card | `3f2e2c6313b75b9baeeecd7889d1a40ff2a3b160b60c00b1b9ad2d404bdab7f2` |
| MQ5 source | `ec05a5b924c26f9a7c68eda0a0c9cabfb8ef9dd84f287592d262bae7ee176fd7` |
| compiled EX5 | `62fd43fa9d1a95736671c6349dba2ed581eaa3781e4f8372963f24b7e7a17782` |
| SPEC | `017a23193e1d1c154c3e4426a68eba734c71063adaf2946bdf7a77110288ace9` |
| fixed-risk setfile | `1ca026f834a6665ff531fcef18130418d49bd6493a4126782a8963aa63e90f43` |
| reference suite | `f5d5c45ac1e4b9840c08a44b510fa90969f05ad92be57fb0c05cadfcab33e9c4` |
| direct strict compile log | `642ce057d68e825f0ef753c9adbef3439b7317246f2dc37301d5946e73d867f2` |
| final build-check report | `75e0d0c9effb6aab92a14206612cc80db1a4ff5db803e4569f5d33abee73c377` |
| static P1 report | `a8aa78c68d47e6e0047208f44760343407ce041b52b31851946b1630b60037e3` |

## Safety And Handoff

No queue apply, backtest, terminal start/stop, worker mutation, AutoTrading
action, `T_Live` access, live manifest, portfolio gate, deploy manifest,
portfolio admission, or correlation waiver occurred.

The next authorized action is a fresh exact-path capacity sample, followed
only when below seven by one target-scoped Q02 dry run and apply. Q02 must
retire on zero trades, fewer than five completed positions per full
post-warm-up year, wrong month identity/endpoints, invalid opposition,
failed reconciliation, leakage, late/repeated entry, wrong lifecycle,
nondeterminism, invalid risk mode, or nonpositive governed economics.

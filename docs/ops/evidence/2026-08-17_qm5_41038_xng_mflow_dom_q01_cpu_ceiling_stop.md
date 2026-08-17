# QM5_41038 XNG Monthly Opposed-Flow Dominance — Q01 PASS / Q02 CPU-Ceiling Stop

Date: 2026-08-17 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT_ENQUEUED_CPU_CEILING`

## Candidate And Claim Boundary

`QM5_41038_xng-mflow-dom` is a new low-frequency natural-gas structural
candidate. At the first executable `XNGUSD.DWX` D1 tick of a normalized broker
month, it reconstructs every completed session in the immediately prior month
plus the preceding month-end anchor. It separately sums prior-close-to-open
and open-to-close log returns, requires strict sign opposition, and reconciles
their total to the exact completed-month return within `1e-10`. Direction is
the sign of the component with greater absolute magnitude. Agreement, exact
zero, equal magnitude, invalid endpoints, failed reconciliation, late attach,
or an already-consumed month remains flat.

An opened position is held to the next normalized broker month, subject to a
frozen `3.5 * ATR(20,D1)` hard stop and a 40-day stale guard. The sole preset
is the backtest baseline with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

The approved packet combines the governed Tier-A Williams information-clock
decomposition with the complete-read, peer-reviewed natural-gas one-month
carrier lineage in Moskowitz, Ooi, and Pedersen (2012). Neither source tests
this exact conjunction, the dominance rule on Darwinex continuous XNG CFD
bars, profitability, or portfolio correlation. Those remain QM falsification
questions; this receipt makes no certification or decorrelation claim.

## Governance And Non-Duplicate Boundary

- Source approval commit: `a57d5f9a6`.
- Deterministic EA-ID reservation commit: `917e207a5`.
- Strategy Card and OWNER G0 commit: `c426fafa5`.
- Pre-magic directory identity commit: `772185331`.
- Magic registration/resolver commit: `370e6f0fb`.
- Q01 build commit: `91ec5ddd4`.
- Registered route: slot 0, `XNGUSD.DWX`, magic `410380000`.
- Canonical dedup found no exact identity and raised five expected flow-family
  neighbors for manual semantic review.
- `QM5_12567` is a long-only D1 RSI(2)/SMA(200) pullback. This candidate is
  symmetric, monthly, and uses completed open/close return decomposition.
- `QM5_41037_xng-mflow-div` uses the same XNG endpoints and opposition gate
  but always follows session flow. This candidate follows whichever opposed
  component has larger absolute magnitude, so eligible states can produce
  the opposite direction.
- `QM5_41036_wti-mflow-dom` carries the same mechanic on WTI. This candidate
  is the mission-authorized XNG carrier with separate identity, fills, risk,
  and future result evidence; no WTI outcome transfers.

## Fixed-Risk Build And Q01 Evidence

- The sole preset is a backtest setfile. Both news axes and framework Friday
  close are OFF; no live/demo/shadow/stress/optimization set exists.
- Independent mechanic suite: 20 tests PASS, covering both energy-label
  conventions, exact month/anchor identity, 15/25 session bounds, all flow
  states and dominance directions, equality rejection, reconciliation,
  restart grace, persisted attempt identity, fixed risk, and rollover.
- All three Strategy Card copies are byte-identical and pass schema/G0/ML
  lint.
- Direct strict MetaEditor compile: PASS, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260817_044631/QM5_41038_xng-mflow-dom.compile.log`.
- Target build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260817_044649.json`.
- Static P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_41038/P1/P1_QM5_41038_result.json`.
- No backtest, smoke test, phase runner, dispatcher tick, or terminal control
  was invoked.

## Binding Capacity Gate

Samples counted only `terminal64.exe` processes whose resolved executable
path exactly matched `D:/QM/mt5/T1..T10/terminal64.exe`. `T_Live`, FTMO, and
all non-factory terminals were excluded.

- Initial sample at `2026-08-17T04:49:48.7592198Z`: 6/7 active roots —
  T2, T3, T4, T7, T8, and T9.
- The target-only dry run selected exactly one never-tested Q02 row and zero
  stranded/recovery rows.
- Immediate pre-apply sample at `2026-08-17T04:50:28.2241503Z`: 7/7 active
  roots — T2, T3, T4, T6, T7, T8, and T9.
- The conditional guard exited with `CPU_CEILING_BINDING_NO_ENQUEUE` before
  invoking the helper with `--apply`.
- Immediate target readback returned `count=0`; no Q02 work item exists.

Per the mission stop condition, no apply, enqueue, dispatch, backtest, tester,
or terminal action followed the binding sample.

## Artifact Integrity

| Artifact | SHA-256 |
|---|---|
| source approval | `ce18f79539654b16f1f7d9dab29f5ec22511b12f98049ce7391c52c727fc9ccb` |
| G0 decision | `15cad7438b170f225cf9ed4ccdd840ca0ec341504eefb6d9946f0bc7e424fc5d` |
| governed source packet (pre-capacity annotation) | `22eda37d480510fd3a6076c9c7f565dd88bf99e8e08ffa417e7002a662c780f5` |
| each synchronized Strategy Card (Q01 state) | `2a63ff7491345cea8e845fc84b0e19e8fbde3f4a15132dcbfdc9efb3b6854476` |
| MQ5 source | `50a87679ac7bc95956f8c17324aca823da2a99fcc0a12ae5472f0dca23280cab` |
| compiled EX5 | `3931fc9bfae49a8f0ecbd1fbdc219386ee7fa8e5d889e94d945f76002286e395` |
| fixed-risk setfile | `4edffb2013bbd244f4b7e69a1354adb1bf97ddb5967626f6d532321953602653` |
| reference suite | `7cbbf0a4197c81fc2d36fd096a16c4d48f7a2fccae8502cb959e65e7273d904e` |
| strict compile log | `27604df85461984c7ab5f2759a955a38d932d2ef28aa545a7e2d75f596bf0b30` |
| final build-check report | `16525b185b0d2d346ec6ce4ecf59b67653ab7b9115a5f008b25bca0300d7794b` |
| static P1 result | `3cc50d6662ce43d573a530ce4788f8e778402a0f557598ae48ffa824345ec405` |

## Safety And Handoff

No queue mutation, manual MT5 run, terminal start/stop, worker mutation,
AutoTrading action, `T_Live` access, live manifest, portfolio-gate edit,
deploy manifest, portfolio admission, or correlation waiver occurred.

The next authorized action is a fresh exact-path capacity sample, followed
only when below seven by one target-only Q02 dry run and apply. Q02 must retire
on zero trades, fewer than five completed positions per full post-warm-up
year, wrong month identity/endpoints, invalid opposition or dominance,
failed reconciliation, leakage, late/repeated entry, wrong lifecycle,
nondeterminism, invalid risk mode, or nonpositive governed economics.

# QM5_21503 WTI Exact-Week Low-Volatility Momentum — Q01 PASS / Q02 CPU-Ceiling Stop

Date: 2026-08-17 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT_ENQUEUED_CPU_CEILING`

## Candidate And Claim Boundary

`QM5_21503_xti-weekly-tsmom-lowvol` is a new low-frequency direct-WTI
structural candidate outside the certified XAU/SP500/NDX/XNG book. At the
first executable D1 edge of a genuine broker Monday, it reconstructs the exact
completed prior Monday-Friday week plus its preceding Friday anchor. It reads
exactly 206 completed closes, follows the completed weekly return sign only
when its five-return realized volatility has an inclusive rank count no higher
than 13 against forty older, non-overlapping five-return blocks, and otherwise
remains flat.

The signal has no return-magnitude threshold, rolling any-day formation,
oscillator, volume input, reversal switch, fitted value, or external runtime
feed. The Monday attempt is persisted before fallible gates. An opened position
uses a frozen `3.0 * ATR(20,D1)` hard stop and the framework Friday close at
broker hour 21, with later-week and eight-day stale repair.

Zhao, Ding, Yu, and Kang (2026), SSRN 6425598 / DOI
`10.2139/ssrn.6425598`, support short-horizon commodity continuation and
stronger momentum in low-volatility states within the bounded accessible
material. They do not test this exact calendar, price-only proxy, lower-tercile
rank, Darwinex continuous WTI CFD, fixed clock/risk package, profitability, or
portfolio correlation. Q02 must falsify activity/economics and Q09 alone may
establish realized decorrelation; this receipt makes no certification claim.

## Governance And Non-Duplicate Boundary

- Source approval commit: `398b88395`.
- Strategy Card, OWNER G0, and EA registry normalization commit: `fbdd2eced`.
- Pre-magic build-directory identity commit: `73daf3638`.
- Magic registration/resolver commit: `389dc0474`.
- Q01 build commit: `4e26ee483`.
- Registered route: slot 0, `XTIUSD.DWX`, magic `215030000`.
- `QM5_13049_xti-1w-mom-vol` uses a rolling any-day five-D1 return, a 1.25%
  magnitude threshold, overlapping 20-D1 volatility, a 120-observation rank,
  and reversal/time exits. This build instead uses an exact completed calendar
  week, no magnitude threshold, five-return RV, forty disjoint older blocks,
  a fixed inclusive lower-tercile count, and Friday flattening.
- `QM5_41020_wti-wclose-mom` reads only a Tuesday-Friday segment and has no RV
  gate. `QM5_41022_wti-wdual-mom` requires two split-week signs to agree and
  has no RV gate. `QM5_21521_wti-volswitch` uses volume and can reverse the
  completed return. None implements this card's information set and rule.
- `QM5_12567_cum-rsi2-commodity` is an XNG long-only cumulative-RSI pullback;
  this candidate is symmetric, direct WTI, exact-week, and price/RV based.

## Fixed-Risk Build And Q01 Evidence

- The sole preset is
  `QM5_21503_xti-weekly-tsmom-lowvol_XTIUSD.DWX_D1_backtest.set` with
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
- Both news axes are OFF and framework Friday close is ON at broker hour 21.
  No live/demo/shadow/stress/optimization preset exists.
- Independent mechanic suite: 13 tests PASS. Coverage includes native and
  uniformly shifted energy labels, exact weekday/date identity, 206-close
  history, all 205 disjoint return intervals, endpoint reconciliation,
  inclusive rank counts 13/14/40, long/short/zero states, invalid history,
  grace, pre-gate attempt consumption, later-week repair, eight-day repair,
  and static source gate order.
- All three Strategy Card copies are byte-identical and the extraction/card
  schema and ML-ban lint reports `status=ok` with no hits or missing sections.
- Direct strict MetaEditor compile on the T1 build installation: PASS, 0 errors
  and 0 warnings. Log:
  `framework/build/compile/20260817_055647/QM5_21503_xti-weekly-tsmom-lowvol.compile.log`.
- Target build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260817_055747.json`.
- Static P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_21503/P1/P1_QM5_21503_result.json`.
- Magic resolver tests passed 13/13 after allocation.
- The repository-wide registry validator remains unsuitable as a target gate
  because it reports the known DL-087 legacy/systemic rows; target checks found
  exactly one EA identity, slug, magic, and magic value for QM5_21503.
- No backtest, smoke test, phase runner, dispatcher tick, or terminal control
  was invoked.

## Binding Capacity Gate

At `2026-08-17T06:02:40.7895764Z`, the canonical read-only
`farmctl mt5-slots` sample reported eight governed factory testers running:
`T1`, `T2`, `T3`, `T4`, `T5`, `T6`, `T7`, and `T10`. Its scan timestamp was
`2026-08-17T06:02:41Z`. A simultaneous read-only Windows processor sample
reported average load `100%`.

The command also reported the separate live and FTMO processes as non-factory
entries; neither counted toward the governed tester set and neither was opened,
controlled, changed, or used. The eight governed testers and 100% load are a
binding hard backtest CPU ceiling. Per the mission stop condition, no target
dry run, queue apply, enqueue, dispatch, backtest, tester, or terminal action
followed the sample.

## Artifact Integrity

| Artifact | SHA-256 |
|---|---|
| source approval | `8aacf5771e061200aa0df17214887c9414d9ab0c2a738c7119f4e31a1520f0ae` |
| G0 decision | `871c5c6645b70c7a6e2cca6e37ca4adb020180f7bcbe23190f892281cb4883e1` |
| governed source packet | `5853cc7d33ece0bf97181eba67241333e6b9625175f9ef9fa951dc450a3d7424` |
| each synchronized Strategy Card | `2fefa492fd4630f1f7ef123fb4bd22e7be66d6e5246f37373700a5b7fb6c2478` |
| MQ5 source | `322b913671f60cec6a6a0adf4f3b6d16163be720dd9065675ec5d057efdc201a` |
| compiled EX5 | `91e24d3e29d2011b3a5252c93bd454453276c148cdb92437842e4b9c4dd1761d` |
| fixed-risk setfile | `3b46f2909c69c52b63208fe02ddc50f46baaa2acceb009dab29a26ecf94f8fe0` |
| reference suite | `9699bb5390d3cfeaf0fde01ddf20b783fc58a0b47f520212b03abd2784ff5a1a` |
| strict compile log | `3b8da71504a61d05fb73174de57ce6beefd3f57a6a4311b0c04742eda315a451` |
| final build-check report | `621f9cab28adbfdc6687fd4a9c1609aa4db4adb6a05929fafddabfdac3b9b073` |
| static P1 result | `cf77311889e8e47d249fab53b9fbe8ee781c1198e7e069b0bb9bea52fba8b8dc` |

## Safety And Handoff

No queue mutation, manual MT5 run, terminal start/stop, worker mutation,
AutoTrading action, `T_Live` action, live manifest, portfolio-gate edit,
deploy manifest, portfolio admission, or correlation waiver occurred.

The next authorized action is a fresh governed capacity sample. Only below the
hard ceiling may one target-only Q02 enqueue be applied for the canonical
fixed-risk setfile. Q02 must retire on zero trades, fewer than five completed
positions per full post-warm-up year, wrong week endpoints, overlapping
returns, wrong inclusive rank or direction, leakage, late/repeated entry,
wrong lifecycle, invalid risk mode, nondeterminism, or nonpositive governed
economics. No weak result may be rescued by changing the exact week, rank,
direction, stop, lifecycle, or risk contract.

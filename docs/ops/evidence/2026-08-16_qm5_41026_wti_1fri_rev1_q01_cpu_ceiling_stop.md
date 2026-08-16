# QM5_41026 WTI First-Friday Reversal — Q01 PASS / Q02 CPU-Ceiling Stop

Date: 2026-08-16 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT_ENQUEUED`

## Candidate And Claim Boundary

`QM5_41026_wti-1fri-rev1` is a new exact-`XTIUSD.DWX`, D1,
low-frequency structural calendar/reversal interaction. It evaluates only the
first genuine normalized Friday of each broker month and buys only after a
strictly negative return between the immediately prior two exact consecutive
broker-calendar month-end closes. The month is consumed before fallible gates,
the V5 Friday-close guard supplies the normal exit at broker hour 21, and a
frozen `3.0 * ATR(20,D1)` hard stop protects the package.

Gorska and Krawiec (2015), *Quantitative Methods in Economics* 16(4), supply
the positive WTI Friday direction. Yang, Goncu, and Pantelous, SSRN 3069253,
supply fixed-horizon commodity-reversal lineage. Neither source tests this
conjunction, first-Friday selector, Darwinex broker-month mapping, continuous
CFD carrier, Friday-session lifecycle, fixed cash risk, or ATR stop. Those are
disclosed QM falsification choices, and no source performance transfers.

The canonical dedup checker scanned 4,513 registry rows and 609 root cards
without an exact or fuzzy match. Manual review separated every-Friday
252-D1-state and unconditional Friday builds, rolling 20-D1 reversal,
cross-commodity ranked reversal, first-Wednesday prior-month momentum, and
two-day oscillator variants. The mechanic identity is the first genuine
Friday plus exact negative completed calendar-month state plus Friday close.

Direct WTI supplies crude-oil exposure outside the certified XAU, SP500, NDX,
and XNG book. That establishes carrier and mechanic novelty, not realized
decorrelation, certification, or portfolio admission. Q09 alone may establish
correlation if the candidate survives the earlier gates.

## Approval, Allocation, And Build

- Source approval:
  `5b0bd760373c3d93bc1cad0f6eac8c78a11e6adb`.
- Deterministic allocation of `QM5_41026`:
  `6bfeffee307fbf39952c6be54319b0385758cd2d`.
- Strategy Card and OWNER G0 approval:
  `1a83f147d7e16da13b2931f7283e2f2a2bf34e46`.
- Magic registration and resolver regeneration:
  `dd0319ad3b131142cf0c193f1fa1ef1414fdb1ab`.
- V5 implementation and Q01 seal:
  `0bb0e9a19b15d06dc14e28aac94a92e347d598a6`.
- Magic tuple:
  `41026,wti-1fri-rev1,0,XTIUSD.DWX,410260000`.
- All three Strategy Card copies are byte-identical and pass schema/ML lint.

## Fixed-Risk Q01 Evidence

- Backtest preset:
  `framework/EAs/QM5_41026_wti-1fri-rev1/sets/QM5_41026_wti-1fri-rev1_XTIUSD.DWX_D1_backtest.set`.
- Locked risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; news axes OFF; Friday close enabled at broker
  hour 21.
- Reference suite: eight tests PASS for exact first-Friday/no-shift identity,
  zero-or-one-day energy-label normalization, 180-minute attachment,
  consecutive completed-month endpoints, negative-only long direction, and
  later-D1/four-day repair.
- Strict MetaEditor compile: PASS, 0 errors, 0 warnings. Log:
  `framework/build/compile/20260816_161212/QM5_41026_wti-1fri-rev1.compile.log`.
- Latest targeted strict build check: PASS, 0 failures, 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260816_161258.json`.
- Static P1: PASS:
  `D:/QM/reports/pipeline/QM5_41026/P1/P1_QM5_41026_result.json`.

Artifact integrity after the capacity-status update:

| Artifact | SHA-256 |
|---|---|
| source approval | `abf8356a1e30d21d1c86b936cf1ecab5e60c1ef59260a8a0b5c22d562ef1b126` |
| G0 decision | `b912a048964e91905d3a70953950c69cc9421efc95ab8e8f9fee7bd54c45beec` |
| governed source packet | `b48320de1b536601e8170ce9f9c7ecd26017717d9f37640146bb18cd535e9ad2` |
| each of three synchronized cards | `7f4edf32d8aa8db07520f335e75c2d026c78222e19329ecf135782b22a5eca23` |
| MQ5 source | `8609bcade115fe10f883325a21859b2818c4fe1a1cc308d64535b7c4fc9e8902` |
| compiled EX5 | `27bf4f8812501ef3792a402a07ae253cdb38f692ff8eaf3b1ce6f82862eea1a7` |
| fixed-risk setfile | `1b19e070e960e73c27b70a28cb02f979ebb0181426d55bb6849f0eb04f013216` |
| reference test | `ab31d502de67d169eda626ce5e2ab3e0b46f8c39009c13ce0c589e3ff5f6db03` |
| strict build-check report | `e27c79373cd82429ccb2ce4cf85703d2e7815daeb5078b3a9e477fa762d18fed` |
| static P1 result | `d4e03cbf3ea276dcc9a8a5726aec98175d3302fe267adc7ecda010251c9eee47` |

## Binding Capacity Gate

The first path-anchored read-only sample at
`2026-08-16T16:14:39.0391856Z` counted only `terminal64.exe` processes
under exact `D:/QM/mt5/T1..T10/` roots and explicitly excluded
`T_Live`:

| Terminal | PID |
|---|---:|
| T1 | 3272 |
| T3 | 19336 |
| T4 | 13856 |
| T5 | 9744 |
| T7 | 16060 |
| T8 | 12564 |
| T9 | 15408 |
| T10 | 13536 |

Eight factory terminals were running against the seven-terminal ceiling. Per
the mission stop condition, neither the target-only queue dry run nor its
apply command was invoked. Read-only
`farmctl work-items --ea QM5_41026` returned `count=0` immediately
afterward. No Q02 work item exists from this handoff.

## Safety And Handoff

No queue apply, dispatcher tick, manual tester run, pipeline phase runner,
terminal start/stop, reservation, worker mutation, AutoTrading action,
`T_Live` access, live/demo/shadow/stress preset, portfolio-gate edit,
portfolio admission, deploy manifest, or T_Live-manifest edit occurred.

The next authorized action is a target-only paced Q02 enqueue only after a
fresh path-anchored T1-T10 sample is below seven. This receipt records a
capacity stop, not a Q02 verdict, certification, profitability result,
decorrelation finding, or portfolio admission.

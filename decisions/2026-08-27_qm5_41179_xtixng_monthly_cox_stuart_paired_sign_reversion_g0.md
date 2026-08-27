# QM5_41179 XTI/XNG Monthly Cox-Stuart Paired-Sign Reversion — G0 Decision

Date: 2026-08-27

Decision: `APPROVED` for one branch-only V5 build, strict non-live Q01, and one
paced logical-basket Q02 enqueue under the current OWNER commodity/energy
portfolio mission. This decision does not authorize a manual tester,
subsequent pipeline phase, live artifact, portfolio admission, or correlation
waiver.

The source gate was approved and committed first at
`decisions/2026-08-27_xtixng_monthly_cox_stuart_paired_sign_reversion_source_approval.md`.

## Deterministic Identity

- EA: `QM5_41179`
- slug: `xtixng-mcoxstuart-rv`
- strategy ID: `VILLAR-COX-STUART-XTIXNG-MPAIRSIGN-RV-2026_S01`
- source ID: `VILLAR-COX-STUART-XTIXNG-MPAIRSIGN-RV-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1, intended magic `411790000`
- companion/traded slot 1: `XNGUSD.DWX`, D1, intended magic `411790001`
- logical tester symbol: `QM5_41179_XTI_XNG_MCOXSTUART_RV_D1`
- approved card:
  `strategy-seeds/cards/approved/QM5_41179_xtixng-mcoxstuart-rv_card.md`

After source approval, canonical dedup, an in-review card draft, deterministic
schema/ML lint `OK`, and OWNER R1-R4 review, the atomic command
`farmctl reserve-ea-ids` returned `reserved:true`, `count:1`, and EA ID 41179.
The allocator selected the ID; it was not predicted or handwritten into the
registry. Registry slug and strategy ID match this card exactly. Magic
allocation remains a separate governed build prerequisite.

## Approved Source And Claim Boundary

The governed source packet
`strategy-seeds/sources/VILLAR-COX-STUART-XTIXNG-MPAIRSIGN-RV-2026/source.md`,
SHA-256 `A8D709E17729474ACF1FA220D0FA0C73FD8DC8F2A555C740DBEC8BFE8061BF38`,
was committed as `184c3536b` before card extraction. It binds:

- the complete Villar-Joutz U.S. EIA oil/gas relationship report;
- the complete Ramberg-Parsons peer-reviewed weak-tie article and its adverse
  regime evidence;
- the named peer-reviewed Cox-Stuart method record; and
- the complete official NIST even-sample pairing algorithm.

The original Cox-Stuart paper body is paywalled and is not claimed completely
read. No cited source tests this exact XTI/XNG 5-of-7 contrarian package or
transfers performance, significance, density, cost, hedge, neutrality, CFD,
decorrelation, or portfolio claims.

## Locked Hypothesis

At the first synchronized executable tick of a genuine new broker month,
consume that month before any fallible gate. Reconstruct exactly fourteen
immediately prior consecutive synchronized completed month-end XTI/XNG close
pairs and form chronological `s[i]=ln(XTI[i])-ln(XNG[i])`.

For `i=0..6`, compare only `d[i]=s[i+7]-s[i]`. Every difference must be finite
and nonzero. At least five positive signs open SELL XTI / BUY XNG; at least
five negative signs open BUY XTI / SELL XNG; a 4/3 split consumes the month
flat. Difference magnitude never changes direction or risk.

One aggregate `RISK_FIXED=1000` budget is split equally across a two-leg
equal-target-absolute-USD-notional package. Each leg receives a frozen
`3.5*ATR(20,D1)` hard stop and no target. Final mismatch may not exceed 20%.
The package renews only at the next month, repairs stale at forty calendar
days, and flattens immediately on any integrity defect.

## R1-R4 Gate

| Gate | Verdict | Basis |
|---|---|---|
| R1 reputable source | PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK | Complete government and peer-reviewed oil/gas evidence including adverse findings, named peer-reviewed Cox-Stuart record, complete official NIST method; exact conjunction disclosed untested. |
| R2 mechanical | PASS | Exact clock, synchronized sample, ratio orientation, seven fixed pairs, tie rule, threshold, sides, durable attempt, aggregate risk, stops, atomicity, and exits. |
| R3 data | PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK | Registered native XTI/XNG D1 histories plus MT5 execution state provide every runtime input; synchronization/roll/basis risks remain binding. |
| R4 deterministic/no ML | PASS | Timestamps, logarithms, strict comparisons, integer counts, ATR risk controls, and execution state only; no trained output, banned signal indicator, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Non-Duplicate Adjudication

The fail-closed receipt
`artifacts/qm5_xtixng_mcoxstuart_rv_preallocation_dedup_20260827.json`, SHA-256
`E75E18D836E67A898CE5B6EFC6E3D8FC545862DBC5E21F1B01D954F7118DF429`,
authenticated 4,678 registry rows, 1,329 cards, and 45 Company Reference Wiki
nodes and returned `CLEAN` with no exact or fuzzy match.

Manual functional review finds no duplicate:

- `QM5_41167` applies Cox-Stuart to outright WTI and follows the sign; this
  card fades an oil/gas ratio and owns an atomic opposite-leg package.
- `QM5_41168` applies Cox-Stuart to a precious-metal carrier; this card has no
  metal leg and targets energy-relative-value exposure different from the
  directional index/metal/XNG book.
- `QM5_41175` searches thirteen ranks for a unique Pettitt split, while
  `QM5_41178` compares all 36 members of two fixed six-observation blocks.
  This card uses seven disjoint lag-seven comparisons and discards magnitude.
- Locked rank paths in the source packet prove candidate-only and
  candidate-flat disagreements with both XTI/XNG rank-sum neighbors.
- Certified `QM5_12567` is a two-day long-only XNG cumulative-RSI pullback,
  not a monthly energy-relative-value paired-sign basket.

Verdict:
`CLEAN_XTIXNG_MONTHLY_COX_STUART_SEVEN_PAIR_FIVE_SIGN_RATIO_REVERSION`.

## Build And Queue Contract

Development may:

1. create only `framework/EAs/QM5_41179_xtixng-mcoxstuart-rv/` and its
   card-of-record, source, test, SPEC, basket manifest, and backtest setfiles;
2. allocate slots 0/1 through the governed magic allocator after the EA
   directory exists and verify resolver survival;
3. implement only the card-authorized four-module logic;
4. compile with `compile_one.ps1 -Strict`, run static/reference tests and Q01;
5. create only `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1` backtest setfiles; and
6. enqueue exactly one non-live logical-basket Q02 row after current strict
   compile and review PASS, without dispatching it if the CPU ceiling binds.

## Kill And Protected Boundary

Pre-result density is five to eight completed packages per full post-warm-up
year. Q02 retires below five/year, at zero trades, with nonpositive governed
economics, or on any synchronization, ratio, pair, tie, threshold, side,
attempt, risk, atomicity, lifecycle, or determinism defect. Q09 alone may
measure realized portfolio overlap.

Forbidden: manual backtest; live/demo/shadow/stress/optimization setfile;
AutoTrading; `T_Live`; terminal start/stop/reservation/reaping; deploy or
T_Live manifest; portfolio gate/KPI/admission mutation; correlation waiver;
external runtime input; threshold/direction/sample/carrier/risk rescue; a
second queue row; or any claim of profitability, certification, neutrality,
or decorrelation before the unchanged downstream gates.

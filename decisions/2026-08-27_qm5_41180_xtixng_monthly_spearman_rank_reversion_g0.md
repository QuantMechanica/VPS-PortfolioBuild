# QM5_41180 XTI/XNG Monthly Spearman Ratio-Rank Reversion — G0 Decision

Date: 2026-08-27

Decision: `APPROVED` for one branch-only V5 build, strict non-live Q01, and one
paced logical-basket Q02 enqueue under the current OWNER commodity/energy
portfolio mission. This decision does not authorize a manual tester,
subsequent pipeline phase, live artifact, portfolio admission, or correlation
waiver.

The source gate was approved and committed first at
`decisions/2026-08-27_xtixng_monthly_spearman_rank_reversion_source_approval.md`.

## Deterministic Identity

- EA: `QM5_41180`
- slug: `xtixng-mspearman-rv`
- strategy ID: `VILLAR-SPEARMAN-XTIXNG-MRANK-RV-2026_S01`
- source ID: `VILLAR-SPEARMAN-XTIXNG-MRANK-RV-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1, intended magic `411800000`
- companion/traded slot 1: `XNGUSD.DWX`, D1, intended magic `411800001`
- logical tester symbol: `QM5_41180_XTI_XNG_MSPEARMAN_RV_D1`
- approved card:
  `strategy-seeds/cards/approved/QM5_41180_xtixng-mspearman-rv_card.md`

After source approval, canonical dedup, and deterministic schema/ML lint, the
atomic command `farmctl reserve-ea-ids` returned `reserved:true`, `count:1`,
and EA ID 41180. The allocator selected the ID; it was not predicted or
handwritten into the registry. Registry slug and strategy ID match this card
exactly. Magic allocation remains a separate governed build prerequisite.

## Approved Source And Claim Boundary

The governed source packet
`strategy-seeds/sources/VILLAR-SPEARMAN-XTIXNG-MRANK-RV-2026/source.md`,
SHA-256 `57B1D693D67E74B6629591D18981C517AEC3D7BF624F8E6064EA6CA884791BE2`,
was committed as `0f841c028` before card extraction. It binds:

- the complete Villar-Joutz U.S. EIA oil/gas relationship report;
- the complete Ramberg-Parsons peer-reviewed weak-tie article and its adverse
  regime evidence;
- the named Spearman method record; and
- the complete pinned R Core rank-correlation implementation and manual.

The original Spearman paper body is not represented as completely read. No
cited source tests this exact XTI/XNG contrarian package or transfers
performance, significance, density, cost, hedge, neutrality, CFD,
decorrelation, or portfolio claims.

## Locked Hypothesis

At the first synchronized executable tick of a genuine new broker month,
consume that month before any fallible gate. Reconstruct exactly thirteen
immediately prior consecutive synchronized completed month-end XTI/XNG close
pairs and form chronological `s[i]=ln(XTI[i])-ln(XNG[i])`.

Reject ratio ties. Assign strict ranks `R[i]`, calculate
`D=sum((R[i]-(i+1))^2)` and `T=364-D`, and prove permutation, range, and parity
invariants. `T>=104` opens SELL XTI / BUY XNG; `T<=-104` opens BUY XTI / SELL
XNG; the interior consumes the month flat. Signal magnitude never changes
direction or risk.

One aggregate `RISK_FIXED=1000` budget is split equally across a two-leg
equal-target-absolute-USD-notional package. Each leg receives a frozen
`3.5*ATR(20,D1)` hard stop and no target. Final mismatch may not exceed 20%.
The package renews only at the next month, repairs stale at forty calendar
days, and flattens immediately on any integrity defect.

## R1-R4 Gate

| Gate | Verdict | Basis |
|---|---|---|
| R1 reputable source | PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK | Complete government and peer-reviewed oil/gas evidence including adverse findings, named Spearman record, and complete pinned R Core method; exact conjunction disclosed untested. |
| R2 mechanical | PASS | Exact clock, synchronized sample, ratio orientation, strict ranks, D/T identities, threshold, sides, durable attempt, aggregate risk, stops, atomicity, and exits. |
| R3 data | PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK | Registered native XTI/XNG D1 histories plus MT5 execution state provide every runtime input; synchronization/roll/basis risks remain binding. |
| R4 deterministic/no ML | PASS | Timestamps, logarithms, strict ranks, integer arithmetic, ATR risk controls, and execution state only; no trained output, banned signal indicator, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Non-Duplicate Adjudication

The fail-closed receipt
`artifacts/qm5_xtixng_mspearman_rv_preallocation_dedup_20260827.json`, SHA-256
`A4FF1F602456C41BC719B6357629E68388515AF4DDDE281F9A62C9AC0B668AC8`,
authenticated 4,679 registry rows, 1,330 cards, and 45 Company Reference Wiki
nodes and returned `CLEAN` with no exact or fuzzy match.

Manual functional review finds no duplicate:

- `QM5_41173` follows the statistic on outright WTI; this card fades an
  oil/gas ratio and owns an atomic opposite-leg package.
- `QM5_41174` uses the same method on a precious-metal ratio; this card has no
  metal or index leg and targets paired-energy relative-value exposure.
- `QM5_41175`, `QM5_41178`, and `QM5_41179` use a searched change point, all
  cross-block comparisons, and seven fixed paired signs respectively. This
  card uses every ratio's displacement from its absolute calendar rank and
  never searches or splits the path.
- `QM5_20237` fits a daily OLS residual and z-score; this card estimates no
  coefficient, center, scale, or residual.
- Certified `QM5_12567` is a two-day long-only XNG cumulative-RSI pullback,
  not a monthly paired-energy rank basket.

Verdict:
`CLEAN_XTIXNG_MONTHLY_SPEARMAN_TIME_RATIO_RANK_T104_CONTRARIAN_BASKET`.

## Build And Queue Contract

Development may:

1. create only `framework/EAs/QM5_41180_xtixng-mspearman-rv/` and its
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

Q02 retires below five completed packages per full post-warm-up year, at zero
trades, with nonpositive governed economics, or on any synchronization, ratio,
rank, parity, threshold, side, attempt, risk, atomicity, lifecycle, or
determinism defect. Q09 alone may measure realized portfolio overlap.

Forbidden: manual backtest; live/demo/shadow/stress/optimization setfile;
AutoTrading; `T_Live`; terminal start/stop/reservation/reaping; deploy or live
manifest; portfolio gate/KPI/admission mutation; correlation waiver; external
runtime input; threshold/direction/sample/carrier/risk rescue; a second queue
row; or any claim of profitability, certification, neutrality, or
decorrelation before unchanged downstream gates.

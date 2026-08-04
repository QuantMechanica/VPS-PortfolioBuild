# QM5_20213 WTI Summer / One-Month Momentum Build And Q02 Enqueue

Date: 2026-08-04 (Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

One new structural, low-frequency commodity candidate was researched, carded,
allocated, built, strictly validated, committed, and handed to the paced Q02
fleet:

- EA: `QM5_20213_wti-summer-mom1`.
- Strategy ID: `BURAKOV-MOP-WTI-SUMMER-MOM1-2026_S01`.
- Carrier: `XTIUSD.DWX`, D1, magic `202130000`.
- Q01: PASS.
- Q02: exactly one priority-track work item,
  `c8ece439-4efe-43e2-a09e-18fae81c162d`; inserted pending at attempt 0 and
  later claimed active by T2 without a verdict at final observation.

This is directional WTI exposure, a physical crude-oil carrier absent from the
certified XAU/SP500/NDX/XNG book. Different economic exposure does not prove
realized decorrelation; the unchanged downstream portfolio gate remains the
only authority for that claim.

## Frozen Edge

On the first tradable `XTIUSD.DWX` D1 bar of each June-October broker month:

1. Reconstruct the two latest distinct, consecutive completed broker-month
   closes.
2. Compute the exact prior-month log return.
3. Buy WTI after a positive return and short WTI after a negative return.
4. Consume the month and remain flat after equality, malformed endpoints, or a
   blocked/rejected attempt.
5. Close before the next monthly renewal and force flat November through May.

Every position has a frozen `3.5 * ATR(20,D1)` hard stop and a forty-day stale
guard. Friday close and both news axes are OFF because the source hold spans a
full month and requires no event feed. The active-month attempt is persisted
before fallible gates. There is no current-month leakage, fallback trade,
parameter sweep, take-profit, trail, partial close, scale-in, grid, martingale,
pyramid, external runtime feed, or trained model.

The active-month helper explicitly distinguishes contiguous from year-wrapped
month ranges. June-October uses inclusive `AND` bounds; the inherited
November-May pattern uses inclusive `OR` bounds. This prevents an accidental
all-year summer carrier.

## Source And Approval

The governed composite packet is
`strategy-seeds/sources/BURAKOV-MOP-WTI-SUMMER-MOM1-2026/source.md`. Its two
fully reviewed peer-reviewed parents are:

- Burakov, Freidin, and Solovyev (2018), “The Halloween Effect on Energy
  Markets: An Empirical Study,” *International Journal of Energy Economics and
  Policy* 8(2), 121-126. It supplies the fixed end-May through end-October WTI
  summer interval and adverse negative-summer-mean evidence.
- Moskowitz, Ooi, and Pedersen (2012), “Time Series Momentum,” *Journal of
  Financial Economics* 104(2), 228-250, DOI
  `10.1016/j.jfineco.2011.11.003`. It supplies the source-declared one-month
  own-return sign and one-month hold commodity family.

The negative summer mean is not imported as an unconditional short. Neither
paper tests this conjunction, a WTI-only one-month result, the Darwinex
continuous CFD, fixed cash risk, the ATR stop, restart state, or the QM
portfolio. No source PF, return, drawdown, cost, or correlation statistic
transfers.

Durable G0 authorization:
`decisions/2026-08-04_qm5_20213_wti_summer_mom1_g0.md`. Source/card approval
commit: `90e78f907`.

The deterministic public-source router classified a fresh read of the Mighri
gold/silver PDF as `DEFERRED:SOURCE_POLICY`; that unverified alternative was
rejected and contributed no rule or claim to this card.

## Non-Duplicate Evidence

Before allocation, `framework/scripts/research_dedup_check.py check` scanned
4,269 EA registry rows and 387 cards and returned `CLEAN`. Manual semantic
review fixed the closest boundaries:

- `QM5_20093_wti-summer-short` is unconditionally short in June-October.
- `QM5_20141_wti-sumtrend` is weekly, July-November, and short-only under a
  negative completed 252-D1 return.
- `QM5_20187_wti-tsmom1m` trades the exact one-month sign year-round.
- `QM5_20209_wti-winter-mom1` uses the same sign state only in the disjoint
  November-May regime.
- `QM5_20046_wti-halloween-ls` maps calendar season directly to direction.
- `QM5_20205_wti-calmom1` requires a recurring same-calendar estimate to agree
  with the prior-month sign.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback.

The exact prior completed month, symmetric sign mapping, June-October gate,
November-May flat state, and monthly renewal are jointly load-bearing.

## Deterministic Allocation

- EA registry: `20213,wti-summer-mom1`.
- Magic slot 0: `XTIUSD.DWX` / `202130000`.
- Allocation/resolver commit: `2aad10e25`.
- Resolver rows after generation: 15,476; dropped rows: 0.
- Resolver-declared registry SHA-256:
  `575B6FF32D80DAB1361F1D4B8A9A42CF652B08B0DD7A5457028A929C014E73E8`.
- Resolver tests: 4 passed.

The EA directory existed before the CSV rows were appended. The canonical
resolver generator ran with `--keep-obsolete`, retained every row, and the
targeted registry check verified exactly one EA row, one slot-0 magic row, and
the generated `202130000` resolver entry.

## Q01 Build Evidence

- Build commit: `20fbb2e42`.
- Strategy-card schema lint: PASS; no missing section or ML-ban hit.
- G0 card lint: PASS.
- Seven-section SPEC validation: PASS.
- Symbol-scope validation: `SINGLE_SYMBOL_OK`, zero violations.
- MetaEditor strict compile: PASS, 0 errors and 0 warnings.
- Compile summary: `D:/QM/reports/compile/20260804_131527/summary.csv`.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260804_131527/QM5_20213_wti-summer-mom1.compile.log`.
- Full strict V5 build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260804_131632.json`.
- Canonical setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; no live/demo/shadow setfile exists.

Artifact SHA-256 values at enqueue:

| Artifact | SHA-256 |
|---|---|
| Source packet | `5cdae2163432cd595a228736db4e4f02422a0ee672d7d1cd2629712323e336b7` |
| MQ5 | `85423d584797089460eba674930b985e7216e0f390f7f48b1854ca10020bcfce` |
| EX5 | `388108671afa0b9cffedbd155727555687ab87b0d0682789b4cd19b7ea75796e` |
| SPEC | `42b290204b7763ac667f1a85f14de120fa5475d2b9706cd80010cbc600fcfe64` |
| Approved/build card | `ed7de8273e6be720f1238e4e80cde17b6713d7c2d7c015b11c854ce09ec06b85` |
| Backtest setfile | `4be43e015d94e588e3508cade3dab453117c78dd7ec1f20ab9245b8dbf8d4e8f` |
| Magic resolver file | `02435dc64ae5a212440e5948e63a8e9127d6fd41be36939be8d78aa0e4ba969f` |

## Paced Q02 Handoff

The exact no-mutation dry-run scope was:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20213 --symbols XTIUSD.DWX --max-part2-per-run 0
```

It selected exactly one never-tested priority-track row, no stranded retry,
and no deferred promotion. The apply plan began with 1,678 pending rows against
the 7,000-row ceiling. The first apply observed the global factory mutation
lock and made no mutation. The lock then released normally; the second exact,
guarded apply inserted one row without bypassing or deleting the lock:

- Work item: `c8ece439-4efe-43e2-a09e-18fae81c162d`.
- Created: `2026-08-04T13:19:56+00:00`.
- Phase/kind: Q02 / backtest.
- Symbol/timeframe: `XTIUSD.DWX` / D1.
- Setfile:
  `QM5_20213_wti-summer-mom1_XTIUSD.DWX_D1_backtest.set`.
- Payload: `priority_track=true`; host `XTIUSD.DWX` D1.
- Initial state: pending, attempt 0, unclaimed.
- Final observation: active on T2, attempt 0, no verdict.

The pre-enqueue and final path-anchored scans each counted four active factory
terminals (`T3`, `T4`, `T9`, and `T10`), below the seven-terminal CPU ceiling.
The controller claimed the new row for T2 during the observation interval; its
terminal process had not yet appeared in the final process scan. `T_Live` and
FTMO were observed separately and excluded from the factory count. This
session did not manually launch, reserve, stop, or alter any terminal.

## Safety Boundary

- No manual backtest or downstream phase was launched; the paced fleet owns
  Q02 execution.
- The backtest CPU ceiling was not reached.
- No live/demo/shadow setfile or deploy artifact was created.
- AutoTrading was not toggled and `T_Live` was not accessed or changed.
- The portfolio gate and T_Live manifest were not touched.
- Q02 enqueue is not certification, profitability evidence, decorrelation
  evidence, or portfolio admission.

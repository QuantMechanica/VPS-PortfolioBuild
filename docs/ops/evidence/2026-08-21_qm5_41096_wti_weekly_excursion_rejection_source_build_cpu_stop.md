# QM5_41096 WTI Weekly Excursion-Rejection Source Build / CPU Stop

Date: 2026-08-21

Branch: `agents/board-advisor`

EA: `QM5_41096_wti-wexcursion-reject-rv`

Outcome: `SOURCE BUILD COMMITTED; Q01 PENDING_GOVERNED_COMPILE; Q02 NOT_ENQUEUED_CPU_CEILING`

## New commodity sleeve

`QM5_41096` is a low-frequency, symmetric direct-WTI failed-auction reversal
candidate on exact `XTIUSD.DWX` D1. At the first tradable bar of a normalized
Monday-anchored broker week, it aggregates the immediately completed three-to-
five-session weekly OHLC package. With `U=high-open` and `D=open-low`, it sells
only when `U > 2*D` and the final close rejects that upper excursion by closing
below the open. It buys only when `D > 2*U` and the final close rejects that
lower excursion by closing above the open. Ratio equality, close/open equality,
settlement agreement, invalid data, late attachment, and retry states remain
flat. A survivor closes at the next weekly boundary.

The state is mutually exclusive from `QM5_41095`, which trades only settlement
agreement and follows the dominant excursion. It also differs mechanically
from existing WTI body-share, two-week range-migration, close-location,
closing-channel breakout, and outside-settlement families. Certified
`QM5_12567` is a long-only two-day XNG cumulative-RSI2 pullback, not an
oscillator-free direct-WTI weekly failed-auction reversal. Diversification is
only a hypothesis; Q09 alone may establish realized portfolio correlation.

## Reputable source and governance trail

The bounded source packet uses Bianchi, Drew, and Fan (2015), "Combining
Momentum with Reversal in Commodity Futures," *Journal of Banking & Finance*
59, DOI `10.1016/j.jbankfin.2015.07.006`, as the peer-reviewed primary
lineage, plus the separately disclosed Yang, Goncu, and Pantelous commodity-
reversal working-paper lineage. The exact weekly failed-auction rule is a QM
translation; no source performance, WTI-only alpha, density, CFD equivalence,
cost, drawdown, neutrality, or correlation result transfers.

| Artifact | Commit / evidence |
|---|---|
| governed source approval | `adedf0130` |
| bounded source packet | `937360b9f` |
| deterministic EA-ID reservation | `fb14d7409` |
| G0-approved card | `60cff05b8` |
| slot-zero magic allocation and resolver | `ef37738ab` |
| source implementation, reference suite, and one D1 preset | `198006a73` |

The canonical pre-allocation duplicate check scanned 4,585 registry rows and
1,265 repository cards. Its optional Strategy-Wiki input was unavailable, so
it returned the honest `FUZZY_MATCH` result and surfaced `QM5_41095`. Manual
review fixed the disjoint agreement versus rejection states. After allocation,
the same checker returned the expected exact `QM5_41096` registry self-hit;
no second registry identity owns the slug or strategy ID.

## Source-level validation

The following target-only checks passed:

1. `python -m unittest framework/EAs/QM5_41096_wti-wexcursion-reject-rv/docs/test_week_excursion_rejection_reference.py -v`
   returned 12/12 PASS.
2. `python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_41096_wti-wexcursion-reject-rv/QM5_41096_wti-wexcursion-reject-rv.mq5`
   returned PASS with no findings.
3. `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_41096_wti-wexcursion-reject-rv`
   returned PASS.
4. `python framework/scripts/skill_card_schema_lint.py --card strategy-seeds/cards/approved/QM5_41096_wti-wexcursion-reject-rv_card.md`
   returned `status=ok`, no prohibited-token hits, and no missing sections.
5. `python framework/scripts/skill_g0_card_lint.py --card strategy-seeds/cards/approved/QM5_41096_wti-wexcursion-reject-rv_card.md`
   returned `status=ok`, with no missing fields.

The reference suite covers strict upper- and lower-excursion rejection,
three/four/five-session packages, two/six-session rejection, exact ratio
equality, close/open equality, both settlement-agreement directions flat,
invalid/nonadjacent/current-week history, duplicate dates, native and uniformly
shifted energy labels, entry grace, durable weekly attempts, year boundaries,
lifecycle, and the static fixed-risk contract.

The MQ5 SHA-256 is
`84CA1D4783B928CF548D488832403FE38A864B8E9D8919542159044E6F526240`.
The sole preset is backtest-only with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`, a frozen `3.5*ATR(20,D1)` stop, no target, and no
optimization surface. Its pre-compile byte SHA-256 is
`F0F5D5552137B08EB9264E4DB005E6E2909BABE1C303A1DC76F36BC90A5F17C8`;
`build_hash` intentionally remains `pending` until governed compile binding.

## Governed compile handoff

The direct strict compile was refused safely while `terminal64.exe` processes
were live, with reason class `INCLUDE_MIRROR_REFUSED` and detail
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`. No retry, terminal control, or include-
mirror bypass was attempted. The refusal log is
`framework/build/compile/20260821_204557/QM5_41096_wti-wexcursion-reject-rv.compile.log`.

The exact command
`python tools/strategy_farm/farmctl.py enqueue-compile QM5_41096_wti-wexcursion-reject-rv`
created compile work item
`678881b9-d266-4cb4-9b92-1bf1b85b7030`. At the final read it was `pending`
under `COMPILE_EA_WORKER_ROLLOUT_PENDING`, with no verdict, EX5, build-check
claim, or Q01 PASS. This activation hold is owned by the reviewed fleet-worker
rollout and release ceremony; it was not bypassed.

## Binding capacity stop

Read-only `farmctl mt5-slots` at `2026-08-21T20:46:55Z` reported five active
governed research terminals: T1 on Q07, T2 and T10 on Q02, T4 on Q09_NEWS,
and T6 on Q04. It reported no duplicate terminal workers and no orphaned
terminal processes. The separate `T_Live` and FTMO processes were observed
only to exclude them; neither was accessed or controlled.

Five whole-host CPU samples at four-second spacing were:

| Sample UTC | CPU |
|---|---:|
| `2026-08-21T20:46:58.749Z` | 99.41% |
| `2026-08-21T20:47:02.753Z` | 98.46% |
| `2026-08-21T20:47:06.759Z` | 100.00% |
| `2026-08-21T20:47:10.759Z` | 99.88% |
| `2026-08-21T20:47:14.767Z` | 99.44% |

Every sample crossed the explicit 97% hard ceiling. Q02 also lacks the Q01
compile prerequisite. Per the mission stop condition, no Q02 preview/apply,
dispatcher tick, smoke run, manual backtest, terminal reservation, or priority
mutation was performed.

## Safety and next deterministic action

No live/demo/shadow/stress/optimization preset, AutoTrading action, `T_Live`
access, deploy/T_Live-manifest change, portfolio-gate mutation, portfolio
admission, decorrelation claim, or correlation waiver occurred.

After the authorized fleet restart releases the compile hold, let the governed
worker consume the exact source hash. Require strict compile PASS with zero
errors/warnings, target build-check PASS, a non-empty EX5, final setfile hash,
and static Q01 artifact validation before updating Q01 to PASS. Only then, and
only after fresh target work-item/dedup checks plus CPU samples remain below
all ceilings, may one target-only Q02 row be enqueued.

Machine-readable evidence:
`artifacts/qm5_41096_compile_cpu_stop_20260821T204714Z_board_advisor.json`.

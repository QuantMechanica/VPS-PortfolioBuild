# QM5_20209 WTI Winter / One-Month Momentum Build And Q02 Enqueue

Date: 2026-08-03 (Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

One new structural, low-frequency commodity candidate was researched, carded,
allocated, built, strictly validated, committed, and handed to the paced Q02
fleet:

- EA: `QM5_20209_wti-winter-mom1`.
- Strategy ID: `BURAKOV-MOP-WTI-WINTER-MOM1-2026_S01`.
- Carrier: `XTIUSD.DWX`, D1, magic `202090000`.
- Q01: PASS.
- Q02: exactly one priority-track work item,
  `337d21e1-0ff0-4934-be26-bee74d3dda82`; pending at initial confirmation and
  later claimed active by the paced fleet on T9.

This is a directional WTI candidate with a crude-oil carrier absent from the
certified XAU/SP500/NDX/XNG book. Different economic exposure does not prove
realized decorrelation; the unchanged downstream portfolio gate remains the
only authority for that claim.

## Frozen Edge

On the first tradable `XTIUSD.DWX` D1 bar of each November-May broker month:

1. Reconstruct the two latest distinct, consecutive completed broker-month
   closes.
2. Compute the exact prior-month log return.
3. Buy WTI after a positive return and short WTI after a negative return.
4. Consume the month and remain flat after equality, malformed endpoints, or a
   blocked/rejected attempt.
5. Close before the next monthly renewal and force flat June through October.

Every position has a `3.5 * ATR(20,D1)` hard stop and a forty-day stale guard.
Friday close and both news axes are OFF because the source hold spans a full
month and requires no event feed. The active-month attempt is persisted before
fallible gates. There is no threshold fit, current-month leakage, fallback
trade, sweep, take-profit, trail, partial close, scale-in, grid, martingale,
pyramid, external runtime feed, or trained model.

## Source And Approval

The governed composite packet is
`strategy-seeds/sources/BURAKOV-MOP-WTI-WINTER-MOM1-2026/source.md`. Its two
complete peer-reviewed source reads are:

- Burakov, Freidin, and Solovyev (2018), “The Halloween Effect on Energy
  Markets: An Empirical Study,” *International Journal of Energy Economics
  and Policy* 8(2), 121-126. It supplies the fixed last-October through
  last-May WTI regime.
- Moskowitz, Ooi, and Pedersen (2012), “Time Series Momentum,” *Journal of
  Financial Economics* 104(2), 228-250, DOI
  `10.1016/j.jfineco.2011.11.003`. It supplies the source-declared one-month
  own-return sign and one-month hold commodity family.

Neither source tests their interaction, a WTI-only one-month result, the
Darwinex continuous CFD, fixed cash risk, the ATR stop, restart state, or the
QM portfolio. No source PF, return, drawdown, cost, or correlation statistic
transfers.

Durable G0 authorization:
`decisions/2026-08-03_qm5_20209_wti_winter_mom1_g0.md`. Source/card approval
commit: `9c3f97fcf`.

## Non-Duplicate Evidence

Before allocation, `framework/scripts/research_dedup_check.py check` scanned
4,265 EA registry rows and 386 cards and returned `CLEAN`. Manual semantic
review fixed the closest boundaries:

- `QM5_20135_wti-winter-trend` uses a 252-D1 return inside the same regime,
  not exact consecutive completed-month endpoints.
- `QM5_20187_wti-tsmom1m` uses the completed one-month sign year-round and has
  no winter gate or June season exit.
- `QM5_20015_wti-halloween-winter` is unconditional long-only.
- `QM5_20046_wti-halloween-ls` maps season directly to direction without a
  price state.
- `QM5_20205_wti-calmom1` uses a recurring same-calendar estimator plus sign
  agreement, absent here.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback.

The exact prior completed month, symmetric sign mapping, November-May entry
gate, June-October flat state, and monthly renewal are jointly load-bearing.

## Deterministic Allocation

- EA registry: `20209,wti-winter-mom1`.
- Magic slot 0: `XTIUSD.DWX` / `202090000`.
- Allocation/resolver commit: `74d9b09d3`.
- Resolver rows after generation: 15,469; dropped rows: 0.
- Resolver-declared registry SHA-256:
  `D3C17962AB5C58C801333D6B5672923163CBF95E395E4AEB5446408B31B3D8E4`.
- Resolver tests: 5 passed.

The strict resolver preflight would omit three legacy registered IDs whose EA
directories are absent. Exact empty untracked helper directories were present
only during successful regeneration and removed immediately afterward, so the
generated resolver preserved every prior mapping and added only `202090000`.

## Q01 Build Evidence

- Build commit: `6b472ec7c`.
- Strategy-card schema lint: PASS; no missing section or forbidden-library hit.
- G0 card lint: PASS.
- Seven-section SPEC validation: PASS.
- MetaEditor compile: PASS, 0 errors and 0 warnings.
- Compile summary: `D:/QM/reports/compile/20260803_154629/summary.csv`.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260803_154629/QM5_20209_wti-winter-mom1.compile.log`.
- Full strict V5 build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260803_154629.json`.
- P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_20209/P1/P1_QM5_20209_result.json`.
- Canonical setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; no live/demo/shadow setfile exists.

Artifact SHA-256 values at enqueue:

| Artifact | SHA-256 |
|---|---|
| Source packet | `ec2a5c11fdd76926c13cff7db484d89b247487391dbf6e58bc594709847c9e67` |
| MQ5 | `f44dc12dbe86acf83554e5104c328125c41d8a53509315a4710c4742c5b371cc` |
| EX5 | `c3ddac6c11e418e3e62a546fe4bb6cbeebf8f64b0f9452b0fa720831b53c18e3` |
| SPEC | `0474d5efd11aa0728806bf07fb1d8e2890d4f4748b3e4b4bafe8e9a4b02cdb8e` |
| Approved/build card | `892c3dd3e7f74dbec288ae6a8e28fa4322dc5406cbcbcf78fb1c5b0b67b9f9db` |
| Backtest setfile | `eae10e1cac4934b6c23ee253ff16f63762b68447518c0a5ab32004dd781f4fb0` |
| Magic resolver file | `3c593ac18d6c51a968d30288ba02a8310503e93eddc72f5ac7a57187bc736746` |

## Paced Q02 Handoff

The exact no-mutation dry-run scope was:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20209 --symbols XTIUSD.DWX --max-part2-per-run 0
```

It selected exactly one never-tested priority-track row and no stranded retry
or deferred promotion. Two apply attempts observed the global factory mutation
lock and made no mutation. A bounded guarded retry then acquired the lock and
inserted exactly one row after a fresh path-anchored process count:

- Work item: `337d21e1-0ff0-4934-be26-bee74d3dda82`.
- Created: `2026-08-03T15:50:51+00:00`.
- Phase/kind: Q02 / backtest.
- Symbol/timeframe: `XTIUSD.DWX` / D1.
- Setfile:
  `QM5_20209_wti-winter-mom1_XTIUSD.DWX_D1_backtest.set`.
- Payload: `priority_track=true`; host `XTIUSD.DWX` D1.
- Status at initial confirmation: pending, attempt 0, unclaimed.
- Final observation: active on T9, attempt count still 0, no verdict yet.
- Queue at apply: 1,756 pending against the 7,000-row ceiling.

The first canonical slot scan found three factory terminals (`T5`, `T7`,
`T9`). The successful lock-guarded precheck found two (`T5`, `T7`), below the
seven-terminal CPU ceiling. The separate `T_Live` and FTMO processes were
identified outside the factory count. This session did not manually launch,
reserve, stop, or alter any terminal.

## Safety Boundary

- No manual backtest or downstream phase was launched; the paced fleet owns
  Q02 execution.
- The backtest CPU ceiling was not reached.
- No live/demo/shadow setfile or deploy artifact was created.
- AutoTrading was not toggled and `T_Live` was not accessed or changed.
- The portfolio gate and T_Live manifest were not touched.
- Q02 enqueue is not certification, profitability evidence, decorrelation
  evidence, or portfolio admission.

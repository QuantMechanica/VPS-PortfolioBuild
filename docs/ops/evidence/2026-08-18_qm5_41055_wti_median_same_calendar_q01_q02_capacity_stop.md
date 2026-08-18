# QM5_41055 WTI Median Same-Calendar - Q01 And Q02 Capacity Stop

Date: 2026-08-18 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT ENQUEUED - CPU CEILING`

## Candidate And Claim Boundary

`QM5_41055_wti-medcal` is a low-frequency, symmetric crude-oil candidate on
exact `XTIUSD.DWX`, D1. At the first normalized D1 bar of a genuine broker
month, it reconstructs each valid completed return for that same calendar
month in years `Y-1` through `Y-10`:

```text
r(H,M) = ln(final D1 close in (H,M) / immediately prior D1 close)
```

Each historical observation requires immediate adjacent D1 bars in the
preceding and following calendar months. The EA accepts only native same-day
labels or one uniform `+1` day energy-label offset, requires five to ten valid
observations, sorts them, and uses the center observation for an odd sample or
the arithmetic mean of the two center observations for an even sample. It
buys above `+1e-12`, sells below `-1e-12`, and consumes the month flat inside
the inclusive tie band. Current-month price and volume cannot enter the
signal, and signal magnitude cannot change size.

The EA freezes a `3.5 * ATR(20,D1)` hard stop, uses no target, and ordinarily
renews at the next broker-month boundary. A 35-calendar-day guard repairs a
survivor. The sole preset is backtest-only with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; both news axes and framework Friday
close are OFF.

This handoff establishes no profitability, certification, portfolio
admission, CFD/futures equivalence, correlation result, or correlation waiver.
Q09 alone may measure realized overlap with the certified XAU/SP500/NDX/XNG
book.

## Governance And Non-Duplicate Boundary

- source approval commit: `5c51e1248`
- EA-ID allocation commit: `084ebfac5`
- active slot-0 magic allocation commit: `25c55d920`
- Strategy Card and OWNER G0 commit: `c37cb73e0`
- uniform energy-label contract amendment: `52b662b89`
- source implementation commit: `d51ed3bb5`
- Q01 binary/status commit: `aabee0efa`
- registered route: slot 0 `XTIUSD.DWX`, magic `410550000`
- source lineage: Keloharju, Linnainmaa, and Nyberg (2016), *The Journal of
  Finance* 71(4), DOI `10.1111/jofi.12398`, with complete-read evidence and
  crude oil inside the paper's commodity-futures universe
- translation boundary: the paper uses a diversified cross-sectional
  arithmetic-mean construction; the bounded median, absolute WTI sign, CFD
  carrier, stop, and lifecycle are explicit QM choices

The canonical pre-allocation checker scanned 4,542 EA rows and 625 root cards
and returned `CLEAN`. The load-bearing sample median distinguishes this card
from the arithmetic-mean `QM5_20099_wti-samecal`: one extreme historical oil
year can flip that EA's mean sign without flipping this EA's median sign.
Manual review also separated the candidate from mean-plus-state systems,
paired energy ranks, fixed favorable-month systems, and certified
`QM5_12567`, a daily long-only cumulative-RSI XNG pullback.

Manual verdict:
`CLEAN_WTI_PRIOR_TEN_YEAR_SAME_CALENDAR_RETURN_MEDIAN_SIGN_MONTHLY_RENEWAL_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Independent mechanic suite: 13 tests `PASS`. Coverage includes native and
  uniform `+1` labels, genuine versus mid-month boundaries, exact adjacent
  month endpoints, December/January wrapping, partial-month rejection,
  five-to-ten sample bounds, odd/even median arithmetic, mean/median sign
  divergence under an outlier, exact prior-year selection, the inclusive
  epsilon band, next-month renewal, and the 35-day repair.
- Both Strategy Card copies are byte-identical and pass schema, prohibited-ML,
  and G0 lint.
- Strict targeted MetaEditor compile: `PASS`, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260818_004637/QM5_41055_wti-medcal.compile.log`.
- Targeted V5 build check: `PASS`, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260818_004637.json`.
- Static P1 artifact validation: `PASS`:
  `D:/QM/reports/pipeline/QM5_41055/P1/P1_QM5_41055_result.json`.
- Factory symbol-scope validation: `SINGLE_SYMBOL_OK`, zero violations.
- MQ5 SHA-256:
  `7CF3885D98FB19A080AD23D47717AE01655F16B5FFE15083ACAA3E305AB9D080`.
- Compiled EX5 SHA-256:
  `E98EFED826EBD290A019C6DB540A8145A76347B30E1E0496077A8AE34F43AA80`.
- Backtest-set byte SHA-256:
  `A56832581213F2099F95DA4FD08DE3FF2632EB161D3C3BA0E28C89CF1B4A6336`.
- Backtest-set normalized-content build hash:
  `5b4f785298f28920751b06fef33057eeae6062ce84e595b93b0acd04e04647b6`.

No manual tester, smoke test, phase runner, dispatcher tick, or backtest was
invoked during Q01.

## Q02 Dry Run And Mandatory Capacity Stop

The target-only canonical dry run selected exactly one fresh Q02 row and no
stranded or recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41055 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

The read-only `farmctl.py mt5-slots` census at `2026-08-18T00:49:37Z` found
six active exact-path research terminals: `T2`, `T3`, `T4`, `T6`, `T9`, and
`T10`. This was below the governed seven-terminal ceiling. The census observed
`T_Live` and an unrelated FTMO terminal only to exclude them; neither was
touched. The configured `D:/QM/strategy_farm/state/launch_gate_max.txt` value
was `1`.

The binding five-sample whole-host CPU reading completed at
`2026-08-18T00:50:02Z`: `90.78`, `95.60`, `98.01`, `82.38`, and `97.29`
percent (average `92.81`, maximum `98.01`). The maximum exceeded the explicit
97% hard host-CPU ceiling.

Per the mission's stop condition, the `--apply` command was not run. The
immediate read-only work-item query returned `count=0`, confirming no Q02 row
exists for this EA.

## Safety And Handoff

No Q02 enqueue, dispatcher tick, manual backtest, terminal or worker mutation,
AutoTrading action, live/demo/shadow/stress/optimization preset, `T_Live`
change, deploy/T_Live manifest, portfolio-gate edit, portfolio admission,
decorrelation claim, or correlation waiver occurred.

The candidate is committed and Q01-clean but remains unqueued. A later paced
operator may repeat the exact target-only dry run and apply only after fresh
terminal and CPU checks both pass. Q02 must retire the identity on zero trades,
fewer than five completed positions per full post-warm-up year, nonpositive
governed economics, wrong session labels or endpoints, current-month leakage,
invalid sample count, wrong even/odd median or sign, mean fallback,
late/repeated entry, wrong monthly lifecycle, nondeterminism, invalid fixed-
risk state, or insufficient history.

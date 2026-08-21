# QM5_41099 WTI Weekly Close-Turn Compile Handoff

Date: 2026-08-22

Branch: `agents/board-advisor`

EA: `QM5_41099_wti-wclose-turn-mom`

Outcome: `SOURCE BUILD COMMITTED; Q01 PENDING_GOVERNED_COMPILE; Q02 NOT_ENQUEUED_Q01_PENDING`

## New commodity sleeve

`QM5_41099` is a low-frequency, symmetric direct-WTI continuation candidate
on exact `XTIUSD.DWX` D1. At the first tradable D1 bar of a normalized new
broker week, it loads every session close from the exact immediately
completed three-to-five-session week. It buys only when those chronological
closes strictly decrease into one interior trough, then strictly increase,
and finish above the first close. It sells the exact peak/decline mirror when
the final close finishes below the first close. Equality, no turn, multiple
turns, endpoint-only extrema, incomplete recovery, malformed or nonadjacent
history, current-week data, late attachment, and retry states consume the
week flat.

Each accepted position uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, and exact next-week closure with a
ten-day stale repair. Opens, highs, lows, path depth, and recovery magnitude
do not enter signal eligibility or size.

This direct WTI close path is mechanically different from the certified
XAU/SP500/NDX/XNG book and from the repository's WTI extreme-order,
close-sign breadth, weekly body, excursion-ratio, multiweek return-path,
overnight-flow, and Ichimoku bounce families. It is also unlike certified
`QM5_12567`, which is a long-only XNG cumulative-RSI2 pullback. These facts
make diversification plausible but do not establish decorrelation; unchanged
Q09 alone owns that verdict.

## Reputable sources and identity boundary

Bianchi, Drew, and Fan (2015), *Journal of Banking & Finance* 59, 423-444,
DOI `10.1016/j.jbankfin.2015.07.006`, supplies peer-reviewed commodity
momentum/reversal lineage and explicit WTI membership. Moskowitz, Ooi, and
Pedersen (2012), *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`, supplies peer-reviewed own-price
continuation lineage and explicit WTI membership. The exact weekly
single-turn close path and full-recovery rule are disclosed QM translations;
no paper performance transfers to this continuous-CFD build.

The pre-allocation checker examined 4,588 registry rows and 1,267 cards and
returned no exact or fuzzy identity. The post-allocation run examined 4,589
rows and returned only the expected `QM5_41099` self-hit. Its optional
Strategy Wiki input was unavailable and remained explicitly fail-closed. A
manual repository family review separated this mechanic from the families
above before identity allocation.

## Durable commit trail

- source approval: `854ef19f5`;
- bounded source packet: `89a28ed62`;
- deterministic EA-ID reservation: `ca6b87716`;
- G0-approved card and post-allocation duplicate record: `2f86bffc4`;
- governed slot-zero magic `410990000` and resolver: `0c14c4dc9`;
- source implementation, reference suite, EA-local card, SPEC, and one D1
  fixed-risk backtest preset: `701bdc873`.

The MQ5 SHA-256 is
`CEBA37A2444DD6E1A56115FF995C34412A211E3BCC7057D8911CD999FF26743B`.
The unbound pre-compile setfile SHA-256 is
`AEBA00523491F3F2770C8265A130CD9857CC39DE8A606FB242E65D6E3D836759`;
its `build_hash` correctly remains `pending` until governed compilation.

## Source-level validation

The target-only deterministic reference suite passed 11/11 checks. It covers
strict trough/full-recovery long, strict peak/full-recovery short,
three/four/five-session acceptance, two/six-session rejection, equality,
monotone endpoint-only paths, multiple turns, incomplete and equal endpoint
recovery, malformed/nonadjacent/duplicate/current-week history, native and
uniformly shifted labels, entry grace, persistent attempts, year boundaries,
next-week exit, stale repair, and fixed-risk close-only static markers.

The build prerequisite guard, V5 build guardrails, SPEC validator,
single-symbol leak validator, card schema/prohibited-ML lint, and G0 card lint
all passed. The approved card and EA-local copy are byte identical at SHA-256
`041858958E5AA78A46057F3FBF1D80AB5076B4916640C9646B0AFC849637659B`.
No compile, EX5, strict build-check, static Q01 PASS, smoke, or economic result
is claimed by these source-level checks.

## Governed compile and Q02 blocker

The direct strict compile was safely refused because research
`terminal64.exe` processes were active. The reason class was
`INCLUDE_MIRROR_REFUSED`, with detail
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; no retry, process stop, include-mirror
bypass, or terminal action was attempted. The durable summary is
`D:/QM/reports/compile/20260821_225510/summary.csv`, SHA-256
`7179CDA9A3B1B743227C2FFF7C93AB05D277BC7F19F69D6FFDB603ACDFD19B36`.

The mandated command
`python tools/strategy_farm/farmctl.py enqueue-compile QM5_41099_wti-wclose-turn-mom`
created compile utility item `b23ec578-eba6-41cf-854d-91737c4c4373`.
It is pending, unclaimed, verdict-free, and held under
`COMPILE_EA_WORKER_ROLLOUT_PENDING`. That hold is released only by the
reviewed fleet-worker restart ceremony and was not bypassed.

Therefore Q01 is not PASS. No EX5 exists, and the exact target-only Q02 sweep
preview selected zero rows. There is exactly one work item for the EA—the
compile utility item—and no Q02 row. Applying a Q02 enqueue without its EX5,
build seal, and Q01 PASS would violate the governed pipeline, so no apply was
attempted.

## Capacity observation

Read-only `farmctl mt5-slots` at `2026-08-21T22:57:10Z` reported four active
governed terminals: T1 on Q09_NEWS, T2 and T5 on Q02, and T4 on Q07. It
reported zero duplicate workers and zero orphaned processes. The separate
`T_Live` and FTMO processes were excluded and were neither accessed nor
controlled.

Five whole-host CPU samples at four-second spacing stayed below the explicit
97 percent hard ceiling:

| Sample UTC | CPU |
|---|---:|
| `2026-08-21T22:57:40.133Z` | 63.21% |
| `2026-08-21T22:57:44.137Z` | 64.53% |
| `2026-08-21T22:57:48.137Z` | 68.22% |
| `2026-08-21T22:57:52.138Z` | 76.93% |
| `2026-08-21T22:57:56.138Z` | 76.54% |

Average CPU was 69.89 percent and maximum CPU was 76.93 percent. Capacity did
not trigger the mission stop; the governed compile/Q01 hold is binding.

## Safe next action

After the authorized restart ceremony releases the compile hold, let the
governed worker consume the exact queued source. Require strict compile PASS
with zero errors/warnings, target build-check PASS, a non-empty EX5, final
setfile binding, and static Q01 artifact PASS. Then rerun the exact target-only
work-item/dedup and CPU checks and enqueue one `XTIUSD.DWX` D1 Q02 row only if
they still pass.

No manual tester, dispatcher tick, terminal reservation/control, AutoTrading
action, live/demo/shadow/stress/optimization preset, `T_Live` or deploy-
manifest change, portfolio-gate mutation, portfolio admission, decorrelation
claim, or correlation waiver occurred.

Machine-readable evidence:
`artifacts/qm5_41099_compile_handoff_20260821T225800Z_board_advisor.json`.


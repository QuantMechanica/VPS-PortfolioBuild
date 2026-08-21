# QM5_41098 WTI Weekly Extreme-Sequence Compile Handoff

Date: 2026-08-22

Branch: `agents/board-advisor`

EA: `QM5_41098_wti-wextreme-sequence-mom`

Outcome: `SOURCE BUILD COMMITTED; Q01 PENDING_GOVERNED_COMPILE; Q02 NOT_ENQUEUED_Q01_PENDING`

## New commodity sleeve

`QM5_41098` is a low-frequency, symmetric direct-WTI continuation candidate
on exact `XTIUSD.DWX` D1. At the first tradable D1 bar of a normalized new
broker week, it aggregates the exact immediately completed three-to-five-
session week. It buys only when the aggregate low and high each occur on one
unique session, the low session precedes the high session, and the final
weekly close is above the first weekly open. It sells on the inverse unique
high-before-low path with a close below the open. Repeated extremes, both
extremes on one session, close/open equality, order/settlement disagreement,
malformed packages, late attachment, and retry states consume the week flat.

Each accepted position uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, and exact next-week closure with a ten-
day stale repair. No current-week OHLC contributes to the signal.

The direct WTI carrier is different from the certified XAU/SP500/NDX/XNG
book, and the completed-week extreme-order rule differs from WTI excursion-
magnitude, excursion-rejection, body-share, day-breadth, flow, parent-week,
and current-week breakout families. It is also unrelated mechanically to
certified `QM5_12567`, a long-only XNG cumulative-RSI2 pullback. These facts
make diversification plausible but do not prove decorrelation; unchanged Q09
alone owns that verdict.

## Reputable source and non-duplicate boundary

Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`, supplies peer-reviewed own-price
continuation lineage and explicitly includes WTI futures. The exact weekly
extreme chronology, uniqueness, and settlement-agreement rule is a disclosed
QM hypothesis; no paper performance transfers to this continuous-CFD build.

The pre-allocation checker examined 4,587 registry rows and 1,266 cards and
returned no exact or fuzzy identity. Its optional Strategy Wiki input was
unavailable and therefore remained fail-closed rather than being treated as
positive evidence. A manual repository family review then separated this
mechanic from the dense existing WTI/XNG families above. The post-allocation
check preserved the same identity boundary.

## Durable commit trail

- source approval: `e45984a09`;
- bounded source packet: `2b76aa74d`;
- deterministic EA-ID reservation: `001defa79`;
- G0-approved card and post-allocation duplicate record: `87d826de8`;
- governed slot-zero magic `410980000` and resolver regeneration: `024acdd6a`;
- source implementation, reference suite, EA-local card, SPEC, and one D1
  fixed-risk backtest preset: `a4d2dc36d`.

At compile enqueue, the MQ5 SHA-256 was
`8CFF83546AD0F5FFA60D4F8B144E3B6E204A6C01A1B519E60F0D9F1DF1058866`.
The unbound pre-compile setfile SHA-256 was
`5FE9BCBE9306BD961677185D245D38A582073BFE0F1F3534F5BE39EA26F53C61`.
Its `build_hash` intentionally remains `pending` until governed compilation.

## Source-level validation

The following target-only checks passed:

1. The deterministic Python reference suite passed 13/13 tests. It covers
   unique long/short order, three/four/five-session acceptance, two/six-
   session rejection, repeated high and low, same-session extremes,
   close/open equality, both settlement disagreements, malformed,
   nonadjacent, duplicate-date and current-week history, native and uniformly
   shifted labels, entry grace, durable weekly attempt behavior, year
   boundaries, next-week exit, stale repair, and static fixed-risk markers.
2. `skill_build_ea_guard.py` returned `status=ok` for the EA registry, magic
   rows, and build directory.
3. `validate_build_guardrails.py` returned PASS with no findings.
4. `validate_spec_doc.py` returned one PASS and zero FAIL.
5. `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK` with
   zero violations.
6. Both card lints passed with no missing sections and no ML hits. The approved
   card and EA-local copy remain byte identical at SHA-256
   `20383E66101C13A394F2E69A442561F6E2EC2FDBF9733B209D04EC99F406FC3A`.

No compile, EX5, strict build-check, static P1 PASS, smoke, or economic result
is claimed by these source-level checks.

## Governed compile handoff

The direct strict compile was refused safely while research `terminal64.exe`
processes were live. The reason class was `INCLUDE_MIRROR_REFUSED`, with detail
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`. No retry, terminal control, include-
mirror bypass, or process stop was attempted. The refusal log is
`framework/build/compile/20260821_215335/QM5_41098_wti-wextreme-sequence-mom.compile.log`.

The required governed command
`python tools/strategy_farm/farmctl.py enqueue-compile QM5_41098_wti-wextreme-sequence-mom`
created utility work item `089fc9d1-dff7-4204-9a8c-70c915ec7943`. At final
read it was pending, unclaimed, and verdict-free under
`COMPILE_EA_WORKER_ROLLOUT_PENDING`. That hold is explicitly released only by
the reviewed fleet-worker restart ceremony and was not bypassed.

Therefore Q01 is not PASS. No EX5 exists, and the target-only Q02 sweep preview
admitted zero rows. `farmctl work-items --ea QM5_41098` showed exactly the one
compile utility item and no Q02 work item.

## Capacity observation

Read-only `farmctl mt5-slots` at `2026-08-22T00:00:38+02:00` reported four
active governed research terminals: T2 on Q07, T6 and T8 on Q02, and T9 on
Q09_NEWS. It reported zero duplicate workers and zero orphaned processes. The
separate `T_Live` and FTMO processes were excluded and were neither accessed
nor controlled.

Five whole-host CPU samples at four-second spacing stayed below the explicit
97 percent hard ceiling:

| Sample UTC | CPU |
|---|---:|
| `2026-08-21T21:55:19.655Z` | 81.06% |
| `2026-08-21T21:55:23.657Z` | 76.26% |
| `2026-08-21T21:55:27.658Z` | 65.41% |
| `2026-08-21T21:55:31.658Z` | 72.71% |
| `2026-08-21T21:55:35.659Z` | 81.91% |

Average CPU was 75.47 percent and maximum CPU was 81.91 percent. Capacity did
not trigger the mission stop; the missing governed compile/Q01 PASS is the
binding reason Q02 was not enqueued.

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
`artifacts/qm5_41098_compile_handoff_20260821T220038Z_board_advisor.json`.

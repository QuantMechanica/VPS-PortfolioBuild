# QM5_41100 XNG Weekly Close-Turn Build and Capacity Stop

Date: 2026-08-22

Branch: `agents/board-advisor`

EA: `QM5_41100_xng-wclose-turn-mom`

Outcome: `SOURCE BUILD COMMITTED; COMPILE QUEUED_ACTIVATION_HELD; Q01 PENDING; Q02 NOT_ENQUEUED_Q01_AND_CPU_STOP`

## New energy candidate

`QM5_41100` is a low-frequency, symmetric natural-gas continuation candidate
on exact `XNGUSD.DWX` D1. At the first tradable D1 bar of a normalized new
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

This logic is structurally different from certified `QM5_12567`, which is a
long-only two-day cumulative-RSI pullback under a slow mean and holds at most
five bars. It is also distinct from the repository's XNG close-location,
weekly-body, sign-flip, NR7 breakout, and inventory-event families. It shares
the XNG carrier with the current book, so source review does not claim
decorrelation or portfolio admission; unchanged Q09 alone owns that verdict.

## Reputable sources and identity boundary

Bianchi, Drew, and Fan (2015), *Journal of Banking & Finance* 59, 423-444,
DOI `10.1016/j.jbankfin.2015.07.006`, supplies peer-reviewed commodity
momentum/reversal lineage and explicit natural-gas membership. Moskowitz,
Ooi, and Pedersen (2012), *Journal of Financial Economics* 104(2), 228-250,
DOI `10.1016/j.jfineco.2011.11.003`, supplies peer-reviewed own-price
continuation lineage and explicit natural-gas membership. The exact weekly
single-turn close path and full-recovery rule are disclosed QM translations;
no paper performance transfers to this continuous-CFD build.

The pre-allocation checker examined 4,589 registry rows, 1,268 cards, and 45
Strategy Wiki nodes. It found no exact identity and one expected fuzzy match:
the exact WTI carrier sibling `QM5_41099`. The G0 record explicitly treats the
XNG carrier hypothesis as a separate falsifiable identity, consistent with
the repository's WTI/XNG carrier-family precedent; that boundary does not
waive later correlation testing. After allocation, the checker examined
4,590 registry rows and 1,269 cards and returned only the expected
`QM5_41100` self-hits.

## Durable commit trail

- source approval: `e0fd6935a`;
- bounded source packet: `9b4508ba8`;
- deterministic EA-ID reservation: `5df526f05`;
- G0-approved card and post-allocation duplicate record: `1cde56339`;
- governed slot-zero magic `411000000` and resolver: `df713dd70`;
- source implementation, reference suite, EA-local card, SPEC, and one D1
  fixed-risk backtest preset: `5a3efe4d0`.

The MQ5 SHA-256 is
`A21062BE279588EFB46F0A0B5F18CB83227E61F511996F4EDDA55EAD4055298C`.
The unbound pre-compile setfile SHA-256 is
`FB27EC03E061DCF23C5F5C39B6E5DE65D7C6891A6420654110A0B803AB854681`;
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
`FEC53137A996DF36A4BA78D46BC55825D4A34709D6655E79B22A3018C295803C`.
No compile, EX5, strict build-check, static Q01 PASS, smoke, or economic result
is claimed by these source-level checks.

## Governed compile and Q02 blockers

The direct strict compile was safely refused because research
`terminal64.exe` processes were active. The reason class was
`INCLUDE_MIRROR_REFUSED`, with detail
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; no retry, process stop, include-mirror
bypass, or terminal action was attempted. The durable summary is
`D:/QM/reports/compile/20260821_234709/summary.csv`, SHA-256
`7A166AD28E58161A0A2030CA870601B12ED57FC164FFEF855290314685C1E7AF`.

The mandated command
`python tools/strategy_farm/farmctl.py enqueue-compile QM5_41100_xng-wclose-turn-mom`
created compile utility item `e6a55d77-24e2-47a4-ba70-4bf55972f35c`.
It is pending, verdict-free, and held under
`COMPILE_EA_WORKER_ROLLOUT_PENDING`. That hold was not bypassed.

Therefore Q01 is not PASS and no EX5 exists. The exact target-only Q02 sweep
preview selected zero rows. Applying Q02 without its EX5, build seal, and Q01
PASS would violate the governed pipeline, so no Q02 apply was attempted.

## CPU hard stop

Read-only `farmctl mt5-slots` at `2026-08-21T23:49:01Z` reported four active
governed terminals: T1 on Q09_NEWS, T2 and T5 on Q02, and T4 on Q07. It
reported zero duplicate workers and zero orphaned processes. The separate
`T_Live` and FTMO processes were observed only by the read-only inventory and
were neither accessed nor controlled.

Five whole-host CPU samples at four-second spacing were:

| Sample UTC | CPU |
|---|---:|
| `2026-08-21T23:49:06.980Z` | 99.78% |
| `2026-08-21T23:49:10.984Z` | 95.41% |
| `2026-08-21T23:49:14.985Z` | 83.94% |
| `2026-08-21T23:49:18.985Z` | 71.65% |
| `2026-08-21T23:49:22.985Z` | 69.92% |

Average CPU was 84.14 percent and maximum CPU was 99.78 percent. The first
sample exceeded the explicit 97 percent hard ceiling, so all enqueue and
compute actions stopped. This ceiling independently forbids Q02 even after
the compile/Q01 prerequisite is resolved; capacity must be sampled again.

## Safe next action

After the authorized fleet-worker restart releases the compile hold, let the
governed worker consume the queued source. Require strict compile PASS with
zero errors/warnings, target build-check PASS, a non-empty EX5, final setfile
binding, and static Q01 artifact PASS. Only after host CPU is again below the
97 percent ceiling should the exact target-only work-item/dedup checks be
rerun and one `XNGUSD.DWX` D1 Q02 row be enqueued.

No manual tester, dispatcher tick, terminal reservation/control, AutoTrading
action, live/demo/shadow/stress/optimization preset, `T_Live` or deploy-
manifest change, portfolio-gate mutation, portfolio admission, decorrelation
claim, or correlation waiver occurred.

Machine-readable evidence:
`artifacts/qm5_41100_compile_cpu_stop_20260821T234923Z_board_advisor.json`.

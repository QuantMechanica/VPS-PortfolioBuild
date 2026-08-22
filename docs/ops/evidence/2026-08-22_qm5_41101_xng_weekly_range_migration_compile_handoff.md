# QM5_41101 XNG Weekly Range-Migration Build And Compile Handoff

Date: 2026-08-22

Branch: `agents/board-advisor`

EA: `QM5_41101_xng-wrange-migrate-mom`

Outcome: `SOURCE BUILD COMMITTED; COMPILE QUEUED_ACTIVATION_HELD; Q01 PENDING; Q02 NOT_ENQUEUED_Q01_STOP`

## New energy candidate

`QM5_41101` is a low-frequency, symmetric natural-gas trend candidate on
exact `XNGUSD.DWX` D1. At the first tradable D1 bar of a normalized new broker
week, it aggregates the exact two immediately completed consecutive broker-
week OHLC packages. It buys only when both the newest weekly high and low are
strictly above the parent endpoints, and sells only when both are strictly
below. Equality, inside, outside, mixed, malformed, nonadjacent, late, and
retry states consume the week flat.

Each accepted position uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, and exact next-week closure with a
ten-day stale repair. Weekly opens, closes, range widths, migration magnitude,
current-week prices, volume, and external data do not enter eligibility or
size.

This is structurally different from certified `QM5_12567`, which is a long-
only two-day cumulative-RSI2 pullback below a slow trend and holds at most five
bars. It shares the XNG carrier with the current book, so source review does
not claim decorrelation or portfolio admission; unchanged Q09 alone owns that
verdict.

## Reputable source and identity boundary

Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`, supplies peer-reviewed own-price
continuation lineage and explicit natural-gas membership. The governed parent
record contains an end-to-end paper read and durable PDF hash. The exact
weekly two-endpoint range state is a disclosed QM translation; no paper or
WTI-sibling performance transfers to this continuous-CFD build.

The pre-allocation checker examined 4,590 registry rows, 1,269 cards, and 45
Strategy-Wiki nodes. It found no exact identity and the expected fuzzy carrier
sibling `QM5_41089_wti-wrange-migrate-mom`. Manual review separates that WTI
test and the repository's XNG RSI2, close-location, body-dominance, NR7, and H4
high-low families. After allocation, the checker returned only the expected
`QM5_41101` self-hits.

## Durable commit trail

- source approval: `9169ec306`;
- bounded source packet: `45d597e8a`;
- deterministic EA-ID reservation: `3a094005d`;
- Q00-approved card and post-allocation duplicate receipt: `2ba24719b`;
- governed slot-zero magic `411010000` and resolver: `9ec7d4d0d`; and
- source implementation, reference suite, EA-local card, SPEC, and one D1
  fixed-risk backtest preset: `b2a34ae5f`.

The MQ5 SHA-256 is
`E6E83E3084DB7FC99DF6C3B7A6FC2AC236BBFB92550B7FD7B7B29EA8B11DBD08`.
The unbound pre-compile setfile SHA-256 is
`31FE8C9D2233FD8E7C71DA6406E476E02E85520CF8BA830FFCC6982EF28401A4`;
its `build_hash` remains `pending` until governed compilation.

## Source-level validation

The target-only deterministic reference suite passed 11/11 checks. It covers
strict long and short endpoint migration; three/four/five-session acceptance;
two/six-session rejection; equality, inside, outside, and mixed states flat;
open/close invariance; malformed, zero-range, nonconsecutive, duplicate, and
current-week rejection; native and uniformly shifted labels; entry grace;
persistent attempts; year boundaries; next-week exit; stale repair; and the
fixed-risk static contract.

The source is an exact six-substitution carrier transform of the reviewed WTI
sibling. The build prerequisite guard, V5 guardrails, SPEC validator, single-
symbol leak validator, card schema/prohibited-ML lint, and Q00 card lint all
passed. The approved card and EA-local copy are byte-identical at SHA-256
`F5B1EDCBB5A6A4FBFAAC8C75DD023A22AB0EB48EE2A3F01FCB23614731774746`.
No compile, EX5, strict build-check, Q01 PASS, smoke, or economic result is
claimed by these source-level checks.

## Governed compile and Q02 blocker

Direct strict compile failed safely because research `terminal64.exe`
processes were active. The reason class was `INCLUDE_MIRROR_REFUSED`, with
failure class `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; no retry, process stop,
include-mirror bypass, or terminal action occurred. The durable summary is
`D:/QM/reports/compile/20260822_004317/summary.csv`, SHA-256
`48B641C3B79B3C2B360712F23F3BB3A82396E54AAA5C67DCF9D54089BFF39E07`.

The mandated command
`python tools/strategy_farm/farmctl.py enqueue-compile QM5_41101_xng-wrange-migrate-mom`
created compile utility item `97095c29-b534-4e4c-baf8-aa8d382225eb`.
It is pending, verdict-free, and held under
`COMPILE_EA_WORKER_ROLLOUT_PENDING`. The documented release-on-restart
ceremony requires separate authorization and was not bypassed.

Therefore Q01 is not PASS and no EX5 exists. The exact target-only Q02 preview
selected zero rows. Applying Q02 without its EX5, build seal, and Q01 PASS
would violate the governed pipeline, so no Q02 apply was attempted.

## Capacity observation

The no-apply Q02 preview observed 2,303 pending rows against the 7,000 queue
ceiling. Read-only `farmctl mt5-slots` reported five active governed terminals
(`T1`, `T2`, `T3`, `T4`, and `T6`), with zero duplicate workers and zero
orphaned processes.

Five whole-host CPU samples at four-second spacing were 93.53%, 80.63%,
85.50%, 80.50%, and 75.83%. Average CPU was 83.20% and maximum CPU was 93.53%,
below the explicit 97% hard ceiling. Capacity was not the blocking gate at
this handoff; absent governed compile/Q01 evidence was.

## Safe next action

After the separately authorized fleet-worker restart releases the compile
hold, let the governed worker consume the queued source. Require strict
compile PASS with zero errors/warnings, target build-check PASS, a non-empty
EX5, final setfile binding, and static Q01 artifact PASS. Then repeat the
immediate capacity and target-only dedup preview and enqueue exactly one
`XNGUSD.DWX` D1 Q02 row if every gate remains open.

No manual tester, dispatcher tick, terminal reservation/control, AutoTrading
action, live/demo/shadow/optimization preset, `T_Live` or deploy-manifest
change, portfolio-gate mutation, portfolio admission, decorrelation claim, or
correlation waiver occurred.

Machine-readable evidence:
`artifacts/qm5_41101_compile_handoff_20260822T004856Z_board_advisor.json`.

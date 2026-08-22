# QM5_41102 WTI Monthly Range-Migration Build And Compile Handoff

Date: 2026-08-22

Branch: `agents/board-advisor`

EA: `QM5_41102_wti-mrange-migrate-mom`

Outcome: `SOURCE BUILD COMMITTED; COMPILE QUEUED_ACTIVATION_HELD; Q01 PENDING; Q02 NOT_ENQUEUED_Q01_STOP`

## New commodity/energy candidate

`QM5_41102` is a low-frequency, symmetric direct-WTI trend candidate on exact
`XTIUSD.DWX` D1. At the first tradable normalized D1 bar of a new broker-
calendar month, it aggregates the exact two immediately completed consecutive
monthly OHLC packages. It buys only when both the newest monthly high and low
are strictly above the parent endpoints, and sells only when both are strictly
below. Equality, inside, outside, mixed, malformed, nonadjacent, late, and
retry states consume the month flat.

Each accepted position uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, and exact next-month closure with a
forty-day stale repair. Monthly opens, closes, range widths, migration
magnitude, current-month prices, volume, and external data do not enter the
signal or size.

Direct WTI is absent from the certified XAU/SP500/NDX/XNG book and gives this
candidate a distinct crude-oil carrier. No source review or source-only build
can establish realized decorrelation; unchanged Q09 alone owns that verdict.

## Reputable source and identity boundary

Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`, supplies peer-reviewed monthly
own-price continuation lineage, one-month holding tests, and explicit WTI
membership. The governed parent record contains an end-to-end 23-page paper
read and durable PDF hash. The exact monthly two-endpoint range state is a
disclosed QM translation; no paper or sibling performance transfers to this
continuous-CFD build.

The pre-allocation checker examined 4,591 registry rows, 1,270 cards, and 45
Strategy-Wiki nodes. It found no exact identity and the expected fuzzy weekly
siblings `QM5_41089_wti-wrange-migrate-mom` and
`QM5_41101_xng-wrange-migrate-mom`. Manual review separates their weekly
formation/holding clocks and the existing monthly WTI close/return families.
After allocation, the checker returned only the expected `QM5_41102` registry
self-hits.

## Durable commit trail

- source approval: `e74e9ab06`;
- bounded source packet: `6cb14504c`;
- deterministic EA-ID reservation: `80c632b08`;
- Q00-approved card and post-allocation duplicate receipt: `bd1d41390`;
- governed slot-zero magic `411020000` and resolver: `977e16ec9`; and
- source implementation, reference suite, EA-local card, SPEC, and one D1
  fixed-risk backtest preset: `50b77acb0`.

The MQ5 SHA-256 is
`5098639D34F9FA01557A4D270710BD91023E0CBA05F545EAC1D0537B1BD9C6BD`.
The unbound pre-compile setfile SHA-256 is
`B81E60FDB8C2277B7FA1DF4BD41F10B182EC48E9BE8ED25D971C88646BFF3E2A`;
its `build_hash` remains `pending` until governed compilation.

## Source-level validation

The target-only deterministic reference suite passed 11/11 checks. It covers
strict long and short endpoint migration; 17/20/23-session acceptance;
16/24-session rejection; equality, inside, outside, and mixed states flat;
open/close invariance; malformed, zero-range, nonconsecutive, duplicate, and
current-month rejection; native and uniformly shifted labels; entry grace;
persistent attempts; year boundaries; next-month exit; stale repair; and the
fixed-risk static contract.

The build prerequisite guard, V5 guardrails, SPEC validator, single-symbol
leak validator, card schema/prohibited-ML lint, and G0 card lint all passed.
The approved card and EA-local copy are byte-identical at SHA-256
`4547BC1313556E51A4AB2CAED64143F79A83979750C1350A1CE4BA91E1729202`.
No compile, EX5, strict build-check PASS, Q01 PASS, smoke, or economic result is
claimed by these source-level checks.

## Governed compile and Q02 blocker

The ad-hoc strict build-check preflight failed safely because MT5
`terminal64.exe` processes were active. Its failure class was
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; no retry, process stop, include-mirror
bypass, or terminal action occurred.

The mandated command
`python tools/strategy_farm/farmctl.py enqueue-compile QM5_41102_wti-mrange-migrate-mom`
created compile utility item `200baa1f-8f4b-4438-807a-835734be24e9`.
It is pending, verdict-free, and held under
`COMPILE_EA_WORKER_ROLLOUT_PENDING`. The documented release-on-restart
ceremony requires separate authorization and was not bypassed.

Therefore Q01 is not PASS and no EX5 exists. The exact target-only command
`python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41102 --symbols XTIUSD.DWX --max-part2-per-run 0`
selected zero rows in no-apply mode. Applying Q02 without its EX5, build seal,
and Q01 PASS would violate the governed pipeline, so no Q02 apply was
attempted. `farmctl work-items --ea QM5_41102` confirms the sole row is the
pending compile utility item; there is no Q02 work item.

## Capacity observation

Read-only `farmctl mt5-slots` at `2026-08-22T01:54:33Z` reported six active
governed terminals: `T1`, `T2`, `T4`, `T6`, `T7`, and `T8`, with zero
duplicate terminal workers and zero orphaned processes. The separate
`T_Live` and FTMO processes were observed only by the read-only inventory and
were neither accessed nor controlled.

Five whole-host CPU samples at four-second spacing were:

| Sample UTC | CPU |
|---|---:|
| `2026-08-22T01:54:38.643Z` | 85.14% |
| `2026-08-22T01:54:42.646Z` | 78.63% |
| `2026-08-22T01:54:46.647Z` | 74.78% |
| `2026-08-22T01:54:50.647Z` | 74.61% |
| `2026-08-22T01:54:54.647Z` | 79.00% |

Average CPU was 78.43 percent and maximum CPU was 85.14 percent, below the
explicit 97 percent hard ceiling. Capacity was not the blocking gate at this
handoff; absent governed compile/Q01 evidence was.

## Safe next action

After the separately authorized fleet-worker restart releases the compile
hold, let the governed worker consume the queued source. Require strict
compile PASS with zero errors/warnings, target build-check PASS, a non-empty
EX5, final setfile binding, and static Q01 artifact PASS. Then repeat the
immediate capacity and target-only dedup preview and enqueue exactly one
`XTIUSD.DWX` D1 Q02 row if every gate remains open.

No manual tester, dispatcher tick, terminal reservation/control, AutoTrading
action, live/demo/shadow/stress/optimization preset, `T_Live` or deploy-
manifest change, portfolio-gate mutation, portfolio admission, decorrelation
claim, or correlation waiver occurred.

Machine-readable evidence:
`artifacts/qm5_41102_compile_handoff_20260822T015540Z_board_advisor.json`.

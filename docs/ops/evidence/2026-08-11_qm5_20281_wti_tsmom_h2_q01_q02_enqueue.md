# QM5_20281 WTI Twelve-Month Trend / Two-Month Hold — Q01 PASS / Q02 Enqueued

Date: 2026-08-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20281_wti-tsmom-h2` is a new low-frequency outright WTI structural-
trend candidate. It is built, Q01 is `PASS`, and exactly one current-binary
`XTIUSD.DWX` row is `Q02 pending`. The work item is
`fab14b85-52c0-4fb1-96d9-10b6c8fb9628`, attempt 0, unclaimed, and has no
verdict at immediate readback. The enqueue occurred below the path-anchored
factory CPU ceiling. No dispatch tick, smoke test, or manual backtest was run.

## Edge And Non-Duplicate Boundary

At the first processed D1 bar of each genuine odd-numbered broker month, the
EA reconstructs thirteen consecutive completed WTI month-end closes
`C[0]..C[12]`, oldest to newest. It buys when the exact endpoint return
`ln(C[12]/C[0])` is positive and sells when it is negative. Exact-zero or
invalid state consumes the bimonthly period flat. The position remains open
through the even-month transition and is closed before reconsideration at the
next odd-month boundary. A frozen `3.5 * ATR(20,D1)` hard stop, no take-
profit, and a seventy-calendar-day stale exit bound the package.

The canonical pre-allocation checker scanned 4,346 EA-registry rows and 457
cards. It found no exact identity and returned expected same-source fuzzy
matches. Manual review separated the candidate from `QM5_12603`, which uses
the same twelve-month direction but renews monthly; WTI cards with one-, two-,
three-, four-, six-, and nine-month formation horizons; monthly dual-horizon
and sign-vote rules; the bimonthly XNG two-month contrarian; and the two-leg
XTI/XNG coefficient-of-variation rank basket. The thirteen endpoints, exact
return orientation, fixed odd-month epoch, no even-month action, consumed
bimonthly attempt, and non-overlapping two-month hold are jointly load-
bearing. Verdict: `CLEAN_AFTER_EXPECTED_SHARED_SOURCE_FUZZY_REVIEW`.

The independent reference vectors prove cross-year month-key continuity;
positive, negative, and exact-zero direction; invalid input rejection;
endpoint-versus-chained-log identity; a newest-month counter-move that does
not turn the rule into a conjunction; six odd-month decisions per full year;
and even-month hold followed by odd-month rollover.

WTI is a crude-oil carrier absent from the current XAU, SP500, NDX, and XNG
book. Carrier and clock novelty do not prove low realized correlation;
unchanged downstream gates, including Q09, own that decision if the candidate
survives Q02-Q08.

## Source And G0 Record

The bounded source packet is
`strategy-seeds/sources/MOP-WTI-TSMOM-H2-2026/source.md`. Its complete-read
parent is Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*,
*Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The governed 23-page paper receipt records PDF
SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`
and explicitly includes NYMEX WTI crude in the commodity-futures universe.

The paper supports the own-price formation/holding family and WTI carrier. It
does not report a standalone non-overlapping WTI `k=12,h=2` result or
prescribe the odd-month phase, Darwinex continuous CFD, broker-month endpoint
reconstruction, fixed-dollar sizing, ATR stop, spread ceiling, restart
ledger, or lifecycle. Those are explicit pre-result QM mechanizations. No
source performance, CFD equivalence, or portfolio-correlation result is
imported. Durable G0 authorization is
`decisions/2026-08-11_qm5_20281_wti_tsmom_h2_g0.md`.

Reputable-source checks R1-R4 pass: one named peer-reviewed DOI record with a
complete governed read and durable hash; exact mechanical rules; a registered
WTI D1 route; and deterministic native arithmetic with no ML, trained output,
banned signal indicator, external runtime feed, grid, martingale, scale-in,
or pyramid.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20281` / `wti-tsmom-h2` /
  `MOP-TSMOM-2012_XTI_K12H2_S29`.
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `202810000`.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- The EA-ID row and target magic tuple each occur exactly once; there are zero
  active magic collisions. Resolver generation kept 15,872 rows and dropped
  zero. Resolver SHA-256 is
  `FD7CEC49CFA404BC21BD3D218C717A3276AAFE7AF8FEC34B3951CD6CBE33B68F`.
- Strict compile: `D:/QM/reports/compile/20260811_150844/summary.csv`, PASS
  with zero errors and zero warnings.
- Strict compile log:
  `C:/QM/repo/framework/build/compile/20260811_150844/QM5_20281_wti-tsmom-h2.compile.log`.
- Targeted build check:
  `D:/QM/reports/framework/21/build_check_20260811_150911.json`, PASS with
  zero failures and zero warnings.
- P1 artifact validation:
  `D:/QM/reports/pipeline/QM5_20281/P1/P1_QM5_20281_result.json`, PASS.
- Independent statistic/clock reference test:
  `framework/EAs/QM5_20281_wti-tsmom-h2/docs/test_tsmom_h2_reference.py`,
  PASS.
- Card schema/ML lint, G0 lint, build-prerequisite guard, SPEC validation, and
  canonical/intake/build-card identity: PASS.
- Generated setfile header build hash:
  `a594314869a2da7593b85033736f0b949a45edf880be260750a14500e6f607ef`.
- Manual smoke/backtest: none.

Artifact SHA-256 values at enqueue:

| Artifact | SHA-256 |
|---|---|
| Bounded source packet | `F3A3A80CBAB2D8900D83562A31D379D0D9545C9307A9988C879A103651FB095F` |
| Canonical/intake/build card | `B771CB9046B9655688F2EA3BF9C4D34358FEE9AD64CFF19915028B504EAB3853` |
| MQ5 | `366260FFB6E645842A776E6225FAD789618C68043F9CE43BAC9550F25C9C8669` |
| EX5 | `91537127420D2797E418F8463C73189B431756538A63F31F16C0C86EDEB5DE94` |
| SPEC | `6718E42E49E22A3723894797E1156B4C16B2B3B80242211263F017F034C93482` |
| Backtest set | `D9DD8EAB9AE243BEB32573BC6931A2B6F38FB8B25292A2096532888A6683F001` |
| Reference test | `48DABE7BA6798B00E2F3278F7059B265ABB914870518766D5791512792A6ADB7` |

## Q02 Capacity And Enqueue Evidence

The target-only non-mutating sweep selected exactly one priority-track never-
tested row for `QM5_20281 / XTIUSD.DWX`, zero stranded rows, and zero deferred
rows. The paired pre-enqueue `farmctl work-items --ea QM5_20281` readback
returned `count=0`.

The binding path-anchored process sample at
`2026-08-11T15:15:26.6767388Z` found three exact factory terminals against the
ceiling of seven:

| Terminal | PID |
|---|---:|
| T1 | 8176 |
| T5 | 6116 |
| T10 | 6272 |

Only exact executables under `D:/QM/mt5/T1..T10/terminal64.exe` counted. With
3/7 active, the bounded apply at `2026-08-11T15:15:32+00:00` enqueued exactly
one never-tested priority-track row. It observed 1,119 pending items against
the 7,000 queue ceiling. Sweep evidence is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, `apply=true`, with
SHA-256
`6374A6DA705425EDBB20F67186929E259CECBEB92283D27C8D44F9EC063FC482`.

Immediate `farmctl work-items --ea QM5_20281` readback returned:

| Field | Value |
|---|---|
| Work item | `fab14b85-52c0-4fb1-96d9-10b6c8fb9628` |
| Phase | `Q02` |
| Kind | `backtest` |
| Symbol | `XTIUSD.DWX` |
| Status | `pending` |
| Attempt | 0 |
| Claimed by | none |
| Verdict | none |

This is an enqueue handoff, not a Q02 screening verdict.

## Commits Before This Closing Evidence

- `e5677d148` — OWNER mission authorization and exact G0 decision.
- `bd4141459` — bounded source packet plus approved/intake cards.
- `36cf9a3cf` — deterministic EA-ID reservation.
- `c74d460ae` — target SPEC scaffold.
- `0ce508dfb` — slot-0 WTI magic allocation and resolver generation.
- `fb8ae8e7f` — EA source, EX5, reference test, fixed-risk setfile, and Q01
  evidence bindings.
- `c5e6c0c4d` — Q02 work-item binding in canonical/intake/build cards and SPEC.

## Safety Boundary

- No dispatch tick, manual backtest, smoke test, or downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled; `T_Live` was not accessed or changed.
- The portfolio gate and T_Live manifest were not touched.
- No efficacy, certification, decorrelation, or portfolio-admission result is
  inferred from Q01 or the Q02 enqueue.

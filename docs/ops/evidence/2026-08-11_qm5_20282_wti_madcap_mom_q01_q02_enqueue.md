# QM5_20282 WTI Median/MAD-Capped Trend — Q01 PASS / Q02 Enqueued

Date: 2026-08-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20282_wti-madcap-mom` is a new low-frequency outright WTI structural-
trend candidate. It is built, Q01 is `PASS`, and exactly one current-binary
`XTIUSD.DWX` row was enqueued to Q02. Work item
`0bf7e357-2686-4e5b-98f5-0eb8c65cf31e` was active on T5 at immediate
readback, attempt 0, with no verdict. The enqueue occurred below the path-
anchored factory CPU ceiling. This mission ran no dispatch tick or manual
backtest.

## Edge And Non-Duplicate Boundary

At the first processed D1 bar after each genuine broker-month transition, the
EA reconstructs thirteen consecutive completed WTI month-end closes and forms
twelve adjacent chronological log returns. It computes the even-sample median
and raw median absolute deviation (MAD), caps every original return
symmetrically at three raw MADs around the median, and trades the sign of the
equal-weight mean of all twelve capped returns. Nonpositive MAD, exact-zero
mean, or invalid state consumes the month flat. Every entry receives a frozen
`3.5 * ATR(20,D1)` hard stop, no take-profit, monthly renewal, and a forty-day
stale exit.

The canonical pre-allocation checker scanned 4,347 EA-registry rows and 458
cards. It found no exact identity and returned five expected same-source fuzzy
neighbors. Manual review separated this adaptive location-and-dispersion rule
from `QM5_20269` sample-median direction, `QM5_20270` fixed-count trimming,
`QM5_20277` fixed-tail Winsorization, and `QM5_20278`/`QM5_20279`
chronological weighting. The return and deviation sorts, even-sample center
indexes, raw-MAD convention, symmetric three-MAD bounds, retention of all
twelve returns, equal post-cap weights, zero-MAD rejection, and consumed
monthly attempt are jointly load-bearing. Verdict:
`CLEAN_AFTER_EXPECTED_ROBUST_LOCATION_FUZZY_REVIEW`.

Independent reference vectors cover positive and negative clusters, exact
zero, zero MAD, a case where the adaptive cap has the opposite sign from
fixed-tail trim and Winsor rules, close-to-log-return orientation, and cross-
year month continuity.

WTI is a crude-oil carrier absent from the current XAU, SP500, NDX, and XNG
book. Carrier and statistic novelty do not prove low realized correlation;
unchanged downstream gates, including Q09, own that conclusion if the
candidate survives Q02-Q08.

## Source And G0 Record

The bounded source packet is
`strategy-seeds/sources/MOP-WTI-MADCAP-2026/source.md`. Its complete-read
parent is Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*,
*Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The governed 23-page paper receipt records PDF
SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`
and explicitly includes NYMEX WTI crude in its commodity-futures universe.

The paper supports the broad monthly own-price continuation family and WTI
carrier. It does not prescribe the median/MAD cap, raw-MAD convention,
Darwinex continuous CFD, broker-month reconstruction, fixed-dollar sizing,
ATR stop, spread cap, attempt ledger, or lifecycle. These are transparent
pre-result QM mechanizations. No source performance, WTI-specific alpha, CFD
equivalence, or portfolio-correlation result is imported. Durable G0
authorization is
`decisions/2026-08-11_qm5_20282_wti_madcap_mom_g0.md`.

Reputable-source checks R1-R4 pass: a named peer-reviewed DOI source with a
complete governed read and durable hash; exact mechanical rules; a registered
WTI D1 route; and deterministic native arithmetic without ML, trained output,
banned signal indicator, external runtime feed, grid, martingale, scale-in,
or pyramid.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20282` / `wti-madcap-mom` /
  `MOP-TSMOM-2012_XTI_MADCAP12_S30`.
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `202820000`.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- The EA-ID row and target magic tuple each occur exactly once; there are zero
  active magic collision groups. Resolver generation kept 15,873 rows and
  dropped zero. Current resolver SHA-256 is
  `FE784367043D0B4E2D5A96485BA6B2F100677D515C2DD438532691BDC62656AD`.
- Strict compile: `D:/QM/reports/compile/20260811_163516/summary.csv`, PASS
  with zero errors and zero warnings.
- Strict compile log:
  `C:/QM/repo/framework/build/compile/20260811_163516/QM5_20282_wti-madcap-mom.compile.log`.
- Targeted build check:
  `D:/QM/reports/framework/21/build_check_20260811_163516.json`, PASS with
  zero failures and zero warnings.
- P1 artifact validation:
  `D:/QM/reports/pipeline/QM5_20282/P1/P1_QM5_20282_result.json`, PASS.
- Independent statistic/clock test:
  `framework/EAs/QM5_20282_wti-madcap-mom/docs/test_madcap_reference.py`,
  PASS.
- Card schema/ML lint, G0 lint, build-prerequisite guard, SPEC validation, and
  canonical/intake/build-card identity: PASS.
- Generated setfile header build hash:
  `6377c85f3a9f84b18a32653cd33925a60228a682adea6ef21ba94057ffca416f`.
- Manual smoke/backtest: none.

Artifact SHA-256 values at enqueue:

| Artifact | SHA-256 |
|---|---|
| Bounded source packet | `3038077FD9268BAAF923B0B3BE11E71126B48F92605B5726B86527D10E7D464B` |
| Canonical/intake/build card | `2433B0562CB553E09F4AA50EF845928EAE4E7311DBB4136AF6B1EF50656E1C66` |
| MQ5 | `525F6E8D4AF74DE2D7D4B60EB9C16A91F90EAC234E93B148E75324225F8684D8` |
| EX5 | `356320796590DED3143A5A7271B58B21849654A356922FA2D93F09A37E66AA46` |
| SPEC | `30D33308D0661CC2C9D11F02A4BD77C4892215E701A980D1B12A3EE6F96C3B36` |
| Backtest set | `B19BA893ACB60B57A58B3C8E4651AB37F7BC10149352F29E5FC9DA98C54A4DCB` |
| Reference test | `AD17E8A69030E96E950DC5F16F575E4CC626354D7FD1E051F2EE3C378FBD6897` |

## Q02 Capacity And Enqueue Evidence

The target-only dry run selected exactly one priority-track never-tested row
for `QM5_20282 / XTIUSD.DWX`, zero stranded rows, and zero deferred rows. The
paired pre-enqueue `farmctl work-items --ea QM5_20282` readback returned
`count=0`.

The binding path-anchored process sample at
`2026-08-11T16:38:48.9365981Z` found three exact factory terminals against the
ceiling of seven:

| Terminal | PID |
|---|---:|
| T1 | 8176 |
| T2 | 10580 |
| T3 | 4564 |

Only exact executables under `D:/QM/mt5/T1..T10/terminal64.exe` counted. With
3/7 active, the bounded apply at `2026-08-11T16:38:49+00:00` enqueued exactly
one never-tested priority-track row. It observed 1,109 pending items against
the 7,000 queue ceiling. Sweep evidence is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, `apply=true`, with
SHA-256
`07FDF997BA845EBAA006903639F7C48A41F7404EF7580B1B02E655F4DBC237E1`.

Immediate `farmctl work-items --ea QM5_20282` readback returned:

| Field | Value |
|---|---|
| Work item | `0bf7e357-2686-4e5b-98f5-0eb8c65cf31e` |
| Phase | `Q02` |
| Kind | `backtest` |
| Symbol | `XTIUSD.DWX` |
| Status | `active` |
| Attempt | 0 |
| Claimed by | T5 |
| Verdict | none |

This is an enqueue handoff, not a Q02 screening verdict. T5 claimed the row
through the already-running paced fleet; this mission did not invoke a
dispatch tick or launch a terminal.

## Commits Before This Closing Evidence

- `9b0017fa7` — OWNER mission authorization and exact G0 decision.
- `256c6da0d` — bounded source packet plus approved/intake cards.
- `b0ca8b5af` — deterministic EA-ID reservation.
- `46e7ee9c1` — target SPEC scaffold.
- `c3b84dba0` — slot-0 WTI magic allocation and resolver generation.
- `60e5f8648` — EA source, EX5, reference test, fixed-risk setfile, and Q01
  evidence bindings.
- `93b0c2f56` — Q02 work-item binding in canonical/intake/build cards and SPEC.

## Safety Boundary

- No dispatch tick, manual backtest, smoke test, or downstream phase was run
  by this mission.
- No terminal was started, stopped, reserved, reaped, or altered by this
  mission.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled; `T_Live` was not accessed or changed.
- The portfolio gate and T_Live manifest were not touched.
- No efficacy, certification, decorrelation, or portfolio-admission result is
  inferred from Q01 or the Q02 enqueue.

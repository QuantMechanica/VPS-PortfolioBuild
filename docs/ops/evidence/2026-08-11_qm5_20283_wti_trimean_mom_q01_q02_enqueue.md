# QM5_20283 WTI Quartile-Trimean Trend — Q01 PASS / Q02 Enqueued

Date: 2026-08-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20283_wti-trimean-mom` is a new low-frequency outright WTI structural-
trend candidate. It is built, Q01 is `PASS`, and exactly one current-binary
`XTIUSD.DWX` row was enqueued to Q02. Work item
`2db5b53c-82d0-4856-a2b8-83f99307bce9` was pending and unclaimed at immediate
readback, then active on T4 at the first post-final-compile follow-up, attempt
0, with no verdict. The enqueue occurred below the path-anchored factory CPU
ceiling. This mission ran no dispatch tick or manual backtest.

## Edge And Non-Duplicate Boundary

At the first processed D1 bar after each genuine broker-month transition, the
EA reconstructs thirteen consecutive completed WTI month-end closes and forms
twelve adjacent chronological log returns. It sorts the returns, estimates
the lower quartile as the mean of indexes 2 and 3, the median as the mean of
indexes 5 and 6, and the upper quartile as the mean of indexes 8 and 9. It
trades the sign of `(Q1 + 2*M + Q3) / 4`. Exact-zero or invalid state consumes
the month flat. Every entry receives a frozen `3.5 * ATR(20,D1)` hard stop, no
take-profit, monthly renewal, and a forty-day stale exit.

The canonical pre-allocation checker scanned 4,348 EA-registry rows and 459
cards. It found no exact identity and returned four expected same-source fuzzy
neighbors. Manual review separated this six-order-statistic rule from
`QM5_20269` raw-median direction, `QM5_20270` equal-weight middle-eight
trimming, `QM5_20277` fixed-tail Winsorization, and `QM5_20278` chronological
linear weighting. The sort, indexes, weights `1/8, 1/8, 1/4, 1/4, 1/8, 1/8`,
divisor, exact-zero rejection, and consumed monthly attempt are jointly load-
bearing. Verdict: `CLEAN_AFTER_ROBUST_LOCATION_FUZZY_REVIEW`.

Independent reference vectors cover positive, negative, and exact-zero
states; a vector where the trimean is positive while both the trimmed and
Winsorized means are negative; a vector where the raw median is positive while
the trimean is negative; close-to-log-return orientation; and cross-year month
continuity.

WTI is a crude-oil carrier absent from the current XAU, SP500, NDX, and XNG
book. Carrier and statistic novelty do not prove low realized correlation;
unchanged downstream gates, including Q09, own that conclusion if the
candidate survives Q02-Q08.

## Source And G0 Record

The bounded source packet is
`strategy-seeds/sources/MOP-WTI-TRIMEAN-2026/source.md`. Its complete-read
parent is Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*,
*Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The governed 23-page paper receipt records PDF
SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`
and explicitly includes NYMEX WTI crude in its commodity-futures universe.

The paper supports the broad monthly own-price continuation family and WTI
carrier. It does not prescribe the quartile trimean, exact index convention,
Darwinex continuous CFD, broker-month reconstruction, fixed-dollar sizing,
ATR stop, spread cap, attempt ledger, or lifecycle. These are transparent
pre-result QM mechanizations. No source performance, WTI-specific alpha, CFD
equivalence, or portfolio-correlation result is imported. Durable G0
authorization is
`decisions/2026-08-11_qm5_20283_wti_trimean_mom_g0.md`.

Reputable-source checks R1-R4 pass: a named peer-reviewed DOI source with a
complete governed read and durable hash; exact mechanical rules; a registered
WTI D1 route; and deterministic native arithmetic without ML, trained output,
banned signal indicator, external runtime feed, grid, martingale, scale-in,
or pyramid.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20283` / `wti-trimean-mom` /
  `MOP-TSMOM-2012_XTI_TRIMEAN12_S31`.
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `202830000`.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- The EA-ID row and target magic tuple each occur exactly once; there are zero
  active magic collision groups. Resolver generation kept 15,874 rows and
  dropped zero. Current resolver SHA-256 is
  `D189F3394F2BA4A3CB6D4E4843C7620F573C511FC6945D2A33DDC9DFF78C9C41`.
- Final strict compile: `D:/QM/reports/compile/20260811_185111/summary.csv`,
  PASS with zero errors and zero warnings.
- Final strict compile log:
  `C:/QM/repo/framework/build/compile/20260811_185111/QM5_20283_wti-trimean-mom.compile.log`.
- Targeted build check:
  `D:/QM/reports/framework/21/build_check_20260811_184440.json`, PASS with
  zero failures and zero warnings.
- P1 artifact validation:
  `D:/QM/reports/pipeline/QM5_20283/P1/P1_QM5_20283_result.json`, PASS.
- Independent statistic/clock test:
  `framework/EAs/QM5_20283_wti-trimean-mom/docs/test_trimean_reference.py`,
  PASS.
- Card schema/ML lint, G0 lint, build-prerequisite guard, SPEC validation, and
  canonical/intake/build-card identity: PASS.
- Generated setfile header build hash:
  `81b8e1ac61600fdce049d7865c74b9a8b3adae29d6c971377ae40191d4b715d3`.
- Manual smoke/backtest: none.

Final repository artifact SHA-256 values:

| Artifact | SHA-256 |
|---|---|
| Bounded source packet | `C44845663B3A12C24796E0D5337B23DB54250FF6CB0CE3AA6632BD191D5F8491` |
| Canonical/intake/build card | `0F3DE5C1F7708FC9D31C6C4DB7AE5BC8C1A5F529E517F7FE1F8AB85881398718` |
| MQ5 | `178AD85B40AE0F760233782712688FC740D71765F37FAE78668FA334AFE4E8A5` |
| EX5 | `FFC2BA85EF3C3B3C1C82DFF65BE52CFD747A27AB6D852F6822D5B610C4D19B7A` |
| SPEC | `424ACE2D229B41867C8905BCAE01FAC44206F248FA2F1377F09F2F07E1D67509` |
| Backtest set | `C220605083C0D5B03CDE200B3E3142EE17AF304E7CFC2229DF9E92B66DCAFD99` |
| Reference test | `029AF7489ECB024A3D661824C63A140006D0B2E277A0513FA1A0C6DE7FF5A3C2` |

## Q02 Capacity And Enqueue Evidence

The target-only dry run selected exactly one priority-track never-tested row
for `QM5_20283 / XTIUSD.DWX`, zero stranded rows, and zero deferred rows. The
paired pre-enqueue `farmctl work-items --ea QM5_20283` readback returned
`count=0`.

The first path-anchored sample at `2026-08-11T18:49:19.5973765Z` found three
factory terminals, but the apply correctly made no mutation because the
factory mutation lock was transiently busy. Readback still returned zero work
items. After the lock cleared, the binding sample at
`2026-08-11T18:49:37.5880233Z` again found three exact factory terminals
against the ceiling of seven:

| Terminal | PID |
|---|---:|
| T5 | 6916 |
| T8 | 3876 |
| T9 | 10236 |

Only exact executables under `D:/QM/mt5/T1..T10/terminal64.exe` counted, with
an explicit `T_Live` exclusion. With 3/7 active, the bounded apply at
`2026-08-11T18:49:37+00:00` enqueued exactly one never-tested priority-track
row. It observed 1,107 pending items against the 7,000 queue ceiling. Sweep
evidence is `D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`,
`apply=true`, with SHA-256
`D0D436769390551DED53459AF57CC543096430E53F949F67CA9AC6EC604992C7`.

Immediate `farmctl work-items --ea QM5_20283` readback returned:

| Field | Value |
|---|---|
| Work item | `2db5b53c-82d0-4856-a2b8-83f99307bce9` |
| Phase | Q02 |
| Kind | backtest |
| Symbol | `XTIUSD.DWX` |
| Status | pending |
| Attempt | 0 |
| Claimed by | none |
| Verdict | none |

The final strict binary was written while the row remained pending. The first
follow-up after that compile found the same item active on T4, attempt 0, with
no verdict. This is an enqueue handoff, not a Q02 screening verdict. T4 claimed
the row through the already-running paced fleet; this mission did not invoke a
dispatch tick or launch a terminal.

## Commits Before This Closing Evidence

- `f24a02426` — OWNER mission authorization and exact G0 decision.
- `e2fc269c3` — bounded source packet plus approved/intake cards.
- `f029479de` — deterministic EA-ID reservation.
- `d5b98d006` — target SPEC scaffold.
- `451b02315` — slot-0 WTI magic allocation and resolver generation.
- `741b25b01` — EA source, EX5, reference test, fixed-risk setfile, and Q01
  evidence bindings.
- `19bdfbf5f` — Q02 work-item binding in canonical/intake/build cards and SPEC.
- `d6cf9b029` — final strict current binary plus matching evidence references.

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

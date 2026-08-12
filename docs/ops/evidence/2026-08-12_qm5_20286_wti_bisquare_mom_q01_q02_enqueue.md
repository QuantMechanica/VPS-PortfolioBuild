# QM5_20286 WTI Bisquare Trend — Q01 PASS / Q02 Enqueued

Date: 2026-08-12 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20286_wti-bisquare-mom` is a new low-frequency outright-WTI structural
trend candidate. It is built, Q01 is `PASS`, and exactly one current-binary
`XTIUSD.DWX` row was enqueued to Q02 below the path-anchored factory CPU
ceiling. Work item `db894631-d726-4ff2-98c3-ef8ab043d0ff` was pending at
immediate readback, attempt 0, unclaimed, with no verdict. This mission issued
no dispatch tick and ran no manual backtest.

## Edge And Non-Duplicate Boundary

At the first processed D1 bar after each genuine broker-month transition, the
EA reconstructs thirteen consecutive completed WTI month-end closes and forms
twelve adjacent chronological log returns. It computes the even median and
even raw MAD, freezes `cutoff = 4.685 * 1.4826 * MAD`, initializes location at
the median, and performs exactly 32 redescending bisquare reweighted-mean
updates. For normalized residual `u`, the weight is `(1-u^2)^2` only when
`abs(u) < 1`; otherwise it is exactly zero. The final location sign selects
long or short, while exact zero and invalid states consume the month flat.
Every entry has a frozen `3.5 * ATR(20,D1)` hard stop, no take-profit, monthly
renewal, and a forty-day stale exit.

The canonical pre-card duplicate check scanned 4,351 EA-registry rows and 463
cards. It found no exact identity and one expected fuzzy neighbor,
`QM5_20285_wti-huber-mom`. Manual review separated the bisquare statistic by
its strict support boundary and zero tail influence: Huber retains positive
tail influence. One-shot cap, trim, Winsor, median, trimean, pseudomedian, and
other WTI variants use different functionals. The cutoff constants, squared
weights, exact-zero support boundary, frozen scale, and 32 updates are jointly
load-bearing. Verdict: `CLEAN_AFTER_MANUAL_HUBER_NEIGHBOR_REVIEW`.

The independent reference test includes a frozen vector where the bisquare
location is positive (`0.0005493537715735436`) while the neighboring Huber
location is negative (`-0.004477628571428571`), with two final observations
receiving zero bisquare weight. It also covers positive, negative,
symmetric-zero, zero-MAD fail-closed, exact 32-step, return-orientation, and
cross-year month-continuity cases.

WTI is a crude-oil carrier absent from the current XAU, SP500, NDX, and XNG
book. Carrier and statistic novelty do not establish realized decorrelation;
unchanged downstream gates, including Q09, own that conclusion if the
candidate survives Q02-Q08.

## Source And G0 Record

The bounded source packet is
`strategy-seeds/sources/MOP-WTI-BISQUARE-2026/source.md`. Its complete-read
parent is Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*,
*Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The governed 23-page paper receipt records PDF
SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`
and explicitly includes NYMEX WTI crude in its commodity-futures universe.
The source does not test this exact estimator, Darwinex continuous CFD,
broker-month reconstruction, lifecycle, or risk overlay; those are disclosed
pre-result QM mechanizations. Durable G0 authorization is
`decisions/2026-08-12_qm5_20286_wti_bisquare_mom_g0.md`.

R1-R4 pass: a peer-reviewed named trading source with DOI, complete governed
read and durable hash; exact mechanical rules; a registered WTI D1 route; and
deterministic native arithmetic without ML, trained output, banned signal
indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20286` / `wti-bisquare-mom` /
  `MOP-TSMOM-2012_XTI_BISQUARE12_S34`.
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `202860000`.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- The target EA-ID and magic rows each occur once. Resolver generation at
  allocation kept 15,891 rows and dropped zero. Resolver SHA-256 is
  `BF257C8B52F021712248BE52D62C48BA168CDB660EFD62360B77BF1502E6CE70`.
- Strict compile: `D:/QM/reports/compile/20260812_023008/summary.csv`, PASS
  with zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260812_023008/QM5_20286_wti-bisquare-mom.compile.log`.
- Target build check:
  `D:/QM/reports/framework/21/build_check_20260812_023034.json`, PASS with
  zero failures and zero warnings.
- P1 artifact validation:
  `D:/QM/reports/pipeline/QM5_20286/P1/P1_QM5_20286_result.json`, PASS.
- Independent statistic/clock test:
  `framework/EAs/QM5_20286_wti-bisquare-mom/docs/test_bisquare_reference.py`,
  PASS.
- Card schema/ML lint, G0 lint, build-prerequisite guard, SPEC validation, and
  canonical/intake/build-card identity: PASS.
- Setfile header build hash:
  `2f1d5b46581b2b5c203f2eea6740e9cc3b4bf3021221db43f736d8c87bba5559`.
- Manual smoke/backtest: none.

Final repository artifact SHA-256 values before this evidence file:

| Artifact | SHA-256 |
|---|---|
| G0 decision | `AFFF6FB2992F9E9815DEAAEDE56A9BB03F95674AF88D22345C496A30152C996A` |
| Bounded source packet | `5B9B8452A816309AD0B8BC93830119B9C1DFE11860CECBBC617FFF25ABCA629B` |
| Canonical/intake/build card | `767F2E253318B2974A5D084AF69E7678C062CD87E88D1F3DFA7100084D6E6394` |
| MQ5 | `6C416683A58EFF10FF18A17A4182E7EF40F530BEEC6CFD30B8D785C889555976` |
| EX5 | `46B25BF2451D7B1B95DDF9F3C4FA546A9B7CA19C2FF5FB03F4D1B926F1C3616D` |
| SPEC | `E20A94A9E7574D66BCB7CFBA3730F1CF616D3156614528E46A231F15A18FD4F1` |
| Backtest set | `D08B130EE107DB9BB09541BF87581C78F4149758899E12317E3E3A5AFAAE5D25` |
| Reference test | `44CBB563AE9F650669992E1B66CC81843E21BBFEADE89D9FA843BD2CFD23A316` |

## Q02 Capacity And Enqueue Evidence

The initial `farmctl mt5-slots` sample at `2026-08-12T02:32:02Z` found four
exact factory terminals. The paired target readback returned zero existing
work items for `QM5_20286`.

The target-only dry run selected exactly one never-tested priority-track row
for `QM5_20286 / XTIUSD.DWX`, with zero skipped, stranded, or deferred rows.
The binding sample at `2026-08-12T02:32:35Z` found five exact T1-T10 tester
processes—T1, T2, T4, T5, and T10—against the ceiling of seven. The apply
therefore proceeded and enqueued exactly one row. Its receipt reports 1,098
pending items at start against the 7,000 queue ceiling:

- `D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`
- `generated_at=2026-08-12T02:32:39+00:00`
- `apply=true`
- SHA-256
  `1EA834C7630628CB83D03177EB7281065A2439960B55B4966604740C9C7E74BF`

Immediate `farmctl work-items --ea QM5_20286` readback returned:

| Field | Value |
|---|---|
| Work item | `db894631-d726-4ff2-98c3-ef8ab043d0ff` |
| Phase | Q02 |
| Kind | backtest |
| Symbol | `XTIUSD.DWX` |
| Status | pending |
| Attempt | 0 |
| Claimed by | none |
| Verdict | none |

The item was created at `2026-08-12T02:32:39+00:00`. Q02 is enqueued, not
screened or passed.

## Commits Before This Closing Evidence

- `b96fa14fe` — OWNER mission authorization and exact G0 decision.
- `d945cc694` — bounded source packet plus approved/intake cards.
- `764732a9f` — deterministic EA-ID reservation.
- `13fed70a8` — target SPEC scaffold.
- `e5a0e4743` — slot-0 WTI magic allocation and resolver generation.
- `753812408` — EA source, EX5, reference test, fixed-risk setfile, and Q01
  evidence bindings.
- `a80bafe85` — refreshed strict-compile binary, target validation receipt,
  controlled flags, and final Q01 evidence paths.

Commits were scoped to `agents/board-advisor`; unrelated pre-existing and
concurrent worktree changes were preserved.

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

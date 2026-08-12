# QM5_20287 WTI Block-Median Trend — Q01 PASS / Q02 Enqueued

Date: 2026-08-12 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20287_wti-blockmed-mom` is a new low-frequency outright-WTI structural
trend candidate. It is built, Q01 is `PASS`, and exactly one current-binary
`XTIUSD.DWX` row was enqueued to Q02 below the path-anchored factory CPU
ceiling. Work item `1e04556a-44ce-4eca-8c19-d8e9d3f9c7ee` was pending at
immediate readback, attempt 0, unclaimed, with no verdict. This mission issued
no dispatch tick and ran no manual backtest.

## Edge And Non-Duplicate Boundary

At the first processed D1 bar after each genuine broker-month transition, the
EA reconstructs thirteen consecutive completed WTI month-end closes and forms
twelve adjacent chronological log returns. It partitions them into four fixed
non-overlapping blocks of three returns, computes each block's arithmetic
mean, sorts the four block means, and averages sorted zero-based indexes 1 and
2. The even block-median sign selects long or short, while exact zero and
invalid states consume the month flat. Every entry has a frozen
`3.5 * ATR(20,D1)` hard stop, no take-profit, monthly renewal, and a forty-day
stale exit.

The canonical pre-card duplicate check scanned 4,352 EA-registry rows and 464
cards. It found no exact identity and no fuzzy match above threshold. Manual
review separated the nearest same-family neighbors:

- `QM5_20272_wti-qtrvote-tr` uses four three-month endpoint-return signs and
  requires three-of-four consensus. The new statistic retains magnitude and
  can trade a two-positive/two-negative split from the inner two block means.
- `QM5_20269_wti-medret-mom` sorts twelve individual monthly returns and does
  not preserve chronological three-month blocks.
- `QM5_20270_wti-trimmean-mom` trims individual-return tails and never forms
  or selects block means.

The independent reference test freezes a two-versus-two vector where the
quarterly sign-vote is flat but the new block median is positive `0.005`. A
second vector produces a positive block median `0.015` while both the raw-
return median (`-0.01`) and middle-eight trimmed mean (`-0.01125`) are
negative. It also covers positive, negative, symmetric exact-zero, return-
orientation, and cross-year month-continuity cases. Verdict:
`CLEAN_AFTER_MANUAL_BLOCK_NEIGHBOR_REVIEW`.

WTI is a crude-oil carrier absent from the current XAU, SP500, NDX, and XNG
book. Carrier and statistic novelty do not establish realized decorrelation;
unchanged downstream gates, including Q09, own that conclusion if the
candidate survives Q02-Q08.

## Source And G0 Record

The bounded source packet is
`strategy-seeds/sources/MOP-WTI-BLOCKMED-2026/source.md`. Its complete-read
parent is Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*,
*Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The governed 23-page paper receipt records PDF
SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`
and explicitly includes NYMEX WTI crude in its commodity-futures universe.
The source does not test this exact estimator, Darwinex continuous CFD,
broker-month reconstruction, lifecycle, or risk overlay; those are disclosed
pre-result QM mechanizations. Durable G0 authorization is
`decisions/2026-08-12_qm5_20287_wti_blockmed_mom_g0.md`.

R1-R4 pass: a peer-reviewed named trading source with DOI, complete governed
read and durable hash; exact mechanical rules; a registered WTI D1 route; and
deterministic native arithmetic without ML, trained output, prohibited signal
indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20287` / `wti-blockmed-mom` /
  `MOP-TSMOM-2012_XTI_BLOCKMED12_S35`.
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `202870000`.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- The target EA-ID and magic rows each occur once. Resolver generation kept
  15,892 rows and dropped zero. Its embedded registry SHA-256 is
  `0EFF225E6533FA9CB719C76F6284B4994AD028E52B1AB94577ACCDC953D33FE6`.
- Strict compile: `D:/QM/reports/compile/20260812_041650/summary.csv`, PASS
  with zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260812_041650/QM5_20287_wti-blockmed-mom.compile.log`.
- Target build check:
  `D:/QM/reports/framework/21/build_check_20260812_041650.json`, PASS with
  zero failures and zero warnings.
- P1 artifact validation:
  `D:/QM/reports/pipeline/QM5_20287/P1/P1_QM5_20287_result.json`, PASS.
- Independent statistic/clock test:
  `framework/EAs/QM5_20287_wti-blockmed-mom/docs/test_blockmed_reference.py`,
  PASS.
- Card schema/ML lint, G0 lint, build-prerequisite guard, SPEC validation, and
  canonical/intake/build-card identity: PASS.
- Setfile header build hash:
  `70d7dbee4e216221fda680080d04f83e273acc11f79cffec3471c47d97a4797a`.
- The repository-wide standalone registry audit continues to report legacy
  inventory defects unrelated to this candidate. The new EA and magic rows
  are unique, mutually consistent, present in the generated resolver, and
  passed the target strict build check.
- Manual smoke/backtest: none.

Final repository artifact SHA-256 values before this evidence file:

| Artifact | SHA-256 |
|---|---|
| G0 decision | `886234B10FBB6DC58BD8F09C74E7EE59EE6F8396454475FB1027F918E2FCACFB` |
| Bounded source packet | `427CEDFC797791818811265DD5054478BCC2BBB7AB8C6D582C550D140D0BE347` |
| Canonical/intake/build card | `E3F365A88B67EC3E444D902233E8B4A0A764FB53AD0EE5894DEBD8C3BAE0D4E6` |
| MQ5 | `37CA0E831AEF5948E304A02C03C3F37CE29952193AFE3ED91F7D4BCE3D5C1DBB` |
| EX5 | `2B98FF472BE09416EA6DFBBE154E5F1FA56A3E79723DD1C5BB3BCF7CE31BF15D` |
| SPEC | `9A1BC8C4EB00ED6525AFA21DE0A294E50F47E2AADD43D96C2D11BF87F3ADE84C` |
| Backtest set | `E6B218C8ECE83B028C8074773C3F23B3DE81853116C95468A9B5B471BDBBA253` |
| Reference test | `7F3DCCA8909E0B15A9415D26F0A3580348DF337CF4A4E886E07BC1478FD4B133` |

## Q02 Capacity And Enqueue Evidence

The initial `farmctl mt5-slots` sample at `2026-08-12T04:19:28Z` found three
exact factory tester processes—T1, T3, and T5. The paired target readback
returned zero existing work items for `QM5_20287`.

The target-only dry run selected exactly one never-tested priority-track row
for `QM5_20287 / XTIUSD.DWX`, with zero skipped, stranded, or deferred rows.
The binding sample at `2026-08-12T06:20:24+02:00` again found three exact
T1-T10 tester processes against the ceiling of seven. The apply therefore
proceeded and enqueued exactly one row. Its receipt reports 1,083 pending items
at start against the 7,000 queue ceiling:

- `D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`
- `generated_at=2026-08-12T04:20:28+00:00`
- `apply=true`
- SHA-256
  `49CB3469BD8AFB70E1282CD99AF31E87CD310D7B037E9DC4EA603A89D80D0F6F`

Immediate `farmctl work-items --ea QM5_20287` readback returned:

| Field | Value |
|---|---|
| Work item | `1e04556a-44ce-4eca-8c19-d8e9d3f9c7ee` |
| Phase | Q02 |
| Kind | backtest |
| Symbol | `XTIUSD.DWX` |
| Status | pending |
| Attempt | 0 |
| Claimed by | none |
| Verdict | none |

The item was created at `2026-08-12T04:20:28+00:00`. Q02 is enqueued, not
screened or passed.

## Commits Before This Closing Evidence

- `d0638f70c` — OWNER mission authorization and exact G0 decision.
- `c67c543ef` — bounded source packet plus approved/intake cards.
- `576ece961` — deterministic EA-ID reservation.
- `022f046fa` — target SPEC scaffold.
- `bc7a6a506` — slot-0 WTI magic allocation and resolver generation.
- `4e826ab0b` — EA source, EX5, reference test, fixed-risk setfile, and Q01
  evidence bindings.

Commits were scoped to `agents/board-advisor`; unrelated pre-existing and
concurrent worktree changes were preserved.

## Safety Boundary

- No dispatch tick, manual backtest, smoke test, or downstream phase was run
  by this mission.
- No terminal was started, stopped, reserved, reaped, or altered by this
  mission.
- No live, demo, shadow, optimization, or stress setfile was created.
- No `T_Live` file, AutoTrading setting, deploy manifest, or T_Live manifest
  was changed.
- The portfolio gate was not touched.
- No efficacy, certification, decorrelation, or portfolio-admission result is
  inferred from Q01 or the Q02 enqueue.

# QM5_20272 WTI Quarterly-Block Consensus — Q01 PASS / Q02 Enqueued

Date: 2026-08-10 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20272_wti-qtrvote-tr` is a new low-frequency direct-WTI structural
candidate. It passed Q01 and has exactly one Q02 work item:
`4fe84586-d791-4bbd-84ef-82aa0de5d0f1`.

Immediate readback found the row pending, attempt 0, unclaimed, and without a
verdict. Enqueue is a screening handoff, not a profitability, certification,
decorrelation, or portfolio-admission result.

## Edge And Non-Duplicate Boundary

On the first `XTIUSD.DWX` D1 bar of a genuine broker-month transition, the EA
reconstructs thirteen consecutive completed month-end closes in chronological
order. It forms four non-overlapping three-month log returns over exact
boundary pairs `(0,3)`, `(3,6)`, `(6,9)`, and `(9,12)`. It buys when at least
three blocks are strictly positive, sells when at least three are strictly
negative, and consumes all other states flat. Exact-zero blocks are neutral.

The position renews monthly, has a forty-calendar-day stale guard, and carries
one frozen `3.5 * ATR(20,D1)` hard stop. The persistent month-attempt marker is
written before signal-history, news, spread, and order gates; owned-position
state and deal history prevent same-month re-entry.

The deterministic pre-allocation check found no exact identity across 4,332
EA-registry rows and 445 intake cards. Manual review resolved the two expected
same-paper fuzzy neighbors. `QM5_20258_wti-mom-vote` votes nested cumulative
one-, three-, and twelve-month returns sharing the latest endpoint, while this
rule partitions the prior year into four disjoint quarterly blocks. The rule
also differs from adjacent-month sign counts, OLS and rank trends, median and
trimmed return averages, and Theil-Sen slopes. Exact block boundaries and the
strict three-of-four vote are load-bearing.

Direct crude oil is a different economic carrier from the certified XAU,
SP500, NDX, and XNG book, but realized independence is not claimed. Q09 alone
may establish portfolio correlation if the candidate reaches it.

## Source And G0 Record

The bounded source packet is
`strategy-seeds/sources/MOP-WTI-QTRVOTE-2026/source.md`. Its complete-read
parent is Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*,
*Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The peer-reviewed paper includes WTI and
documents monthly own-return continuation over the first twelve lags.

The quarter-block sign vote, exact boundaries, CFD mapping, fixed-risk sizing,
stop, spread cap, and lifecycle are transparent QM mechanizations, not source
performance claims. The complete source receipt records SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
G0 authorization is
`decisions/2026-08-10_qm5_20272_wti_qtrvote_tr_g0.md`.

Reputable-source checks are R1-R4 PASS: complete peer-reviewed source with DOI
and durable retrieval hash; exact mechanical rules; registered WTI D1 data;
and deterministic native arithmetic with no ML, trained output, banned signal
indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20272` / `wti-qtrvote-tr` /
  `MOP-TSMOM-2012_XTI_QTRVOTE12_S21`.
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `202720000`.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Resolver regeneration: 15,620 rows kept and zero dropped.
- Strict compile: `D:/QM/reports/compile/20260810_153630/summary.csv`, PASS
  with zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260810_153630/QM5_20272_wti-qtrvote-tr.compile.log`.
- Target build check:
  `D:/QM/reports/framework/21/build_check_20260810_153630.json`, PASS with
  zero failures and zero warnings.
- P1 artifact validation:
  `D:/QM/reports/pipeline/QM5_20272/P1/P1_QM5_20272_result.json`, PASS.
- Card-schema/ML lint, G0 lint, build-prerequisite guard, and SPEC validation:
  PASS.
- Generated setfile header build hash:
  `a7e2111cef52a1ba022f6a693ba4438043829f6b96f938ec3adaa1656652c673`.
- Manual smoke/backtest: none.

The repository-wide legacy registry validator remains red on pre-existing
invalid legacy IDs/slugs and registry mismatches. The new target rows are
unique and formula-correct, resolver generation dropped zero rows, and the
strict target build's complete magic-collision gate passed.

Artifact SHA-256 values at handoff:

| Artifact | SHA-256 |
|---|---|
| Source packet | `F91C1DF391CD35AF9F224AEA35FD44525E31C2C4F69C616479A4AEE87036E36E` |
| Canonical/build card | `34DA76B5A3278A39CBBD22A4EEC75C114D99C817F2487BEED99696080268A2EE` |
| MQ5 | `0BB3CF55C513B8CD67D3C34CF9E49C0E02FD74EBD73BFAE634B1EE05AF281E70` |
| EX5 | `6BF36C0F5DC26778C662C312B676624ABDF9BD9BF12FD87083F5B54F1EB25003` |
| SPEC | `9D5912F959BD5CE261F9B9AAA0F1F28EDF25CF10B2E4E8B468591BF9323F148F` |
| Backtest set | `459A06E4703F3FEFA9603A5906D28CCFD6F227DE42468E34DA6022DE3506A6AD` |

## Paced Q02 Handoff

The binding pre-enqueue `farmctl mt5-slots` sample at
`2026-08-10T15:42:36+00:00` found four executing factory terminals against the
ceiling of seven: T2, T4, T5, and T7. The scan separately observed T_Live and
the FTMO terminal outside the T1-T10 factory roots; those were excluded from
the count and were not changed.

Before mutation, target readback found zero prior work items. The exact
EA-and-symbol dry run selected one never-tested priority row, no stranded
retry, and no deferred promotion. It reported 1,108 pending rows against the
queue ceiling of 7,000.

Two earlier apply attempts correctly refused a busy canonical mutation lock
and created no row. The lock belonged to a dead earlier T3 worker process; it
was left untouched and was subsequently reaped by the farm's audited
120-second PID-dead protocol. The successful single guarded apply then
enqueued one item:

- Work item: `4fe84586-d791-4bbd-84ef-82aa0de5d0f1`.
- Created: `2026-08-10T15:42:40+00:00`.
- Phase/kind: Q02 / backtest.
- Symbol/timeframe: `XTIUSD.DWX` / D1.
- Setfile:
  `QM5_20272_wti-qtrvote-tr_XTIUSD.DWX_D1_backtest.set`.
- Priority: `priority_track=true`.
- Immediate state: pending, attempt 0, unclaimed, no verdict.

## Commits Before This Closing Evidence

- `102c031a1` — OWNER mission authorization and exact G0 decision.
- `0e7d4f295` — bounded source packet plus approved/intake cards.
- `389d69137` — deterministic EA-ID reservation.
- `e39c32ddc` — WTI magic allocation, resolver generation, and SPEC.
- `14beaa324` — EA source, compiled EX5, build card, Q01 status, and fixed-risk
  set binding.

## Safety Boundary

- No manual backtest, smoke test, dispatch tick, or downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered by this
  mission.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled; T_Live was not changed.
- The portfolio gate and T_Live manifest were not touched.
- No efficacy, certification, decorrelation, or portfolio-admission result is
  inferred from enqueue.

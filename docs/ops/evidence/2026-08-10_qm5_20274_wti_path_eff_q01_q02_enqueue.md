# QM5_20274 WTI Path-Efficiency — Q01 PASS / Q02 Enqueued

Date: 2026-08-10 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20274_wti-path-eff` is a new low-frequency direct-WTI structural
candidate. It passed Q01 and has exactly one Q02 work item:
`6586fea1-87ce-4bf4-a570-f49431c50a57`.

Immediate post-insert readback found the row pending, attempt 0, unclaimed,
and without a verdict. The standing factory claimed it on T6 nine seconds
later; a subsequent read found it active, attempt 0, with no verdict. Enqueue
is a screening handoff, not an efficacy, certification, decorrelation, or
portfolio-admission result.

## Edge And Non-Duplicate Boundary

On the first `XTIUSD.DWX` D1 bar of a genuine broker-month transition, the EA
reconstructs thirteen consecutive completed month-end closes in chronological
order and forms all twelve adjacent log returns. With signed net return `N`
and absolute path length `P`, it buys when `N > 0` and `abs(N)/P >= 0.25`,
sells symmetrically, and consumes zero-path, zero-net, below-threshold,
invalid, or unavailable-history states flat.

The position renews monthly, has a forty-calendar-day stale guard, and carries
one frozen `3.5 * ATR(20,D1)` hard stop. The persistent month-attempt marker is
written before history, signal, news, spread, quote, sizing, and order gates;
owned-position state and deal history prevent same-month re-entry.

The deterministic pre-allocation check scanned 4,337 EA-registry rows and 447
cards and found no exact identity or fuzzy match above threshold. Manual
review separates the estimator from endpoint-only WTI TSMOM, sign counts and
runs, nested- and fixed-block votes, OLS/rank/Theil-Sen trends, and median or
trimmed-return aggregators. Generic efficiency-ratio EAs do not share this
exact WTI monthly carrier, twelve-return net-to-absolute-path statistic,
`0.25` threshold, persisted attempt, and renewal lifecycle.

Direct crude oil is a different economic carrier from the certified XAU,
SP500, NDX, and XNG book, but realized independence is not claimed. Q09 alone
may establish portfolio correlation if the candidate reaches it.

## Source And G0 Record

The bounded packet is
`strategy-seeds/sources/MOP-WTI-PATHEFF-2026/source.md`. Its complete-read
parent is Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*,
*Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The peer-reviewed paper includes NYMEX WTI
and documents own-return continuation over the first twelve monthly lags.

The path-efficiency statistic, threshold, CFD mapping, fixed-risk sizing,
stop, spread cap, and lifecycle are transparent QM mechanizations, not source
performance claims. The complete-paper receipt records SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
G0 authorization is
`decisions/2026-08-10_qm5_20274_wti_path_eff_g0.md`.

Reputable-source checks R1-R4 pass: named peer-reviewed source with DOI,
complete read and durable hash; exact mechanical rules; registered WTI D1
data; and deterministic native arithmetic with no ML, trained output, banned
signal indicator, external runtime feed, grid, martingale, scale-in, or
pyramid.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20274` / `wti-path-eff` /
  `MOP-TSMOM-2012_XTI_PATHEFF12_S23`.
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `202740000`.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Committed resolver generation: 15,760 rows kept, zero dropped, registry
  SHA-256 `4BFE5A8C4FB084716B7075300C331BB8F670033A7470DCCAA8E728175F1CB7E9`.
- Strict compile: `D:/QM/reports/compile/20260810_212857/summary.csv`, PASS
  with zero errors and zero warnings.
- Strict compile log:
  `C:/QM/repo/framework/build/compile/20260810_212857/QM5_20274_wti-path-eff.compile.log`.
- Target build check:
  `D:/QM/reports/framework/21/build_check_20260810_212913.json`, PASS with
  zero failures and zero warnings.
- P1 artifact validation:
  `D:/QM/reports/pipeline/QM5_20274/P1/P1_QM5_20274_result.json`, PASS.
- Card-schema/ML lint, G0 lint, build-prerequisite guard, SPEC validation,
  and canonical/build-card identity: PASS.
- Generated setfile header build hash:
  `df3012520f3f78bc3338e7926d96e7580b38f5acd0e74eba6253ddd328dc8356`.
- Manual smoke/backtest: none.

Artifact SHA-256 values at Q02 handoff:

| Artifact | SHA-256 |
|---|---|
| Source packet | `7D4F2B86DA31EEA2ECAEE7573E3CF1629883B05A575FFEB694944A99D907DBE8` |
| Canonical/build card | `50E570D9B1DFA54F1C79B5DB216C6797A2DA2DBB9701C332D6C796F44E46FA02` |
| MQ5 | `B02FD9701FCE46724D80E8AB23F04377C4D51F7E402D8963D285E99F854489CA` |
| EX5 | `C3EBCAF3AAE5E62E74DE12DA2998AADE101D2E5FEFFCED2444993EE930E96D0C` |
| SPEC | `904C3269E8A99EB5C055941B9A0BA719C33B2C732A8647AC3FA43E535171F279` |
| Backtest set | `40929BF8DDF0783D096CDE8801D547F787C5B551586700AEF81733FB702E9FBD` |

## Paced Q02 Handoff

Before mutation, target readback found zero prior work items. The exact
EA-and-symbol dry run selected one never-tested priority row, no stranded
retry, and no deferred promotion. The guarded apply began with 1,137 pending
rows against the queue ceiling of 7,000.

The binding `farmctl mt5-slots` sample at
`2026-08-10T21:32:12+00:00` found three executing T1-T10 factory terminals
against the ceiling of seven: T7, T9, and T10. T_Live and the FTMO terminal
were outside the factory count and were not changed. The CPU ceiling was not
reached.

The single guarded apply enqueued:

- Work item: `6586fea1-87ce-4bf4-a570-f49431c50a57`.
- Created: `2026-08-10T21:32:17+00:00`.
- Phase/kind: Q02 / backtest.
- Symbol/timeframe: `XTIUSD.DWX` / D1.
- Setfile:
  `QM5_20274_wti-path-eff_XTIUSD.DWX_D1_backtest.set`.
- Priority: `priority_track=true`.
- Immediate state: pending, attempt 0, unclaimed, no verdict.
- Automatic factory state at `2026-08-10T21:32:26+00:00`: active on T6,
  attempt 0, no verdict.

## Commits Before This Closing Evidence

- `e441deca7` — OWNER mission authorization and exact G0 decision.
- `88df74f8a` — bounded source packet plus approved/intake cards.
- `41ecab316` — deterministic EA-ID reservation.
- `be0173729` — WTI magic allocation.
- `dff7148d2` — resolver, EA source/binary, build card, setfile, and initial
  Q01 record.
- `d397e6c0a` — exact-resolver rebuild and final Q01 evidence binding.

## Safety Boundary

- No manual backtest, smoke test, dispatch tick, or downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered by this
  mission; the standing factory independently claimed the queued row.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled; T_Live was not changed.
- The portfolio gate and T_Live manifest were not touched.
- No efficacy, certification, decorrelation, or portfolio-admission result is
  inferred from enqueue.

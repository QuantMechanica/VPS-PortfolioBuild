# QM5_20270 WTI Trimmed-Mean Momentum — Q01 PASS / Q02 Enqueued

Date: 2026-08-10 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20270_wti-trimmean-mom` is a new low-frequency direct-WTI structural
candidate. It passed Q01 and has exactly one Q02 work item:
`7922d63b-dbb4-4269-bc4c-6fcaf7a760c1`.

Immediate readback found the row pending, attempt 0, unclaimed, and without a
verdict. Enqueue is a screening handoff, not a profitability, certification,
decorrelation, or portfolio-admission result.

## Edge And Non-Duplicate Boundary

On the first `XTIUSD.DWX` D1 bar of a genuine broker-month transition, the EA
reconstructs thirteen consecutive completed month-end closes, forms twelve
disjoint chronological log returns, and sorts them ascending. It removes exact
zero-based indexes 0, 1, 10, and 11 and calculates the arithmetic mean of
indexes 2 through 9 with divisor eight. It buys a positive trimmed mean and
sells a negative trimmed mean. Exact-zero or invalid state consumes the month
flat.

The position renews monthly, has a forty-calendar-day stale guard, and carries
one frozen `3.5 * ATR(20,D1)` hard stop. A persistent month-attempt marker,
owned-position state, and deal history prevent same-month re-entry.

The deterministic pre-allocation check found no exact or fuzzy identity across
4,327 EA-registry rows and 443 cards. Manual review separated this fixed-tail
return statistic from cumulative WTI momentum, binary sign breadth, multi-
horizon votes, pairwise month-end rank trend, log-price OLS trend, and
`QM5_20269`'s two-center median. The load-bearing distinction is deletion of
two observations per tail followed by equal weighting of all eight retained
returns.

Direct crude oil is a different carrier from the certified XAU, SP500, NDX,
and XNG book, but realized independence is not claimed. Q09 alone may
establish portfolio correlation if the candidate reaches it.

## Source And G0 Record

The bounded source packet is
`strategy-seeds/sources/MOP-WTI-TRIMMEAN-2026/source.md`. Its complete-read
parent is Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*,
*Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The peer-reviewed paper includes WTI and
documents monthly own-return continuation.

The trimmed-mean estimator, exact deletion indexes, CFD mapping, fixed-risk
sizing, stop, spread cap, and lifecycle are transparent QM mechanizations, not
source performance claims. G0 authorization is
`decisions/2026-08-10_qm5_20270_wti_trimmean_mom_g0.md`.

Reputable-source checks are R1-R4 PASS: complete peer-reviewed source with DOI
and durable retrieval hash; exact mechanical rules; registered WTI D1 data;
and deterministic native arithmetic with no ML, trained output, banned signal
indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20270` / `wti-trimmean-mom` /
  `MOP-TSMOM-2012_XTI_TRIM12_S19`.
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `202700000`.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Resolver regeneration: 15,567 rows kept, zero dropped; registry hash
  `CFE8A7D2211EE8783276ED55F89B3014AD88EC638AC82DF668414AE037C3BE21`.
- Strict compile: `D:/QM/reports/compile/20260810_093222/summary.csv`,
  PASS with zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260810_093222/QM5_20270_wti-trimmean-mom.compile.log`.
- Target build check:
  `D:/QM/reports/framework/21/build_check_20260810_093222.json`, PASS with
  zero failures and zero warnings.
- P1 artifact validation:
  `D:/QM/reports/pipeline/QM5_20270/P1/P1_QM5_20270_result.json`, PASS.
- Card-schema/ML lint, G0 lint, build-prerequisite guard, and SPEC validation:
  PASS.
- Generated setfile header build hash:
  `409f58f6b9537c64171835f155868ea7c74802db63ced3209c5d61e52b08efb2`.
- Manual smoke/backtest: none.

Artifact SHA-256 values at handoff:

| Artifact | SHA-256 |
|---|---|
| EA registry | `DC98CE770880003EA2FF0095F1233F6A2517E97DF6504A829A2D59BDD62F7C93` |
| Magic registry | `CFE8A7D2211EE8783276ED55F89B3014AD88EC638AC82DF668414AE037C3BE21` |
| Generated magic resolver | `51D13A9D94BB32BEFDC26AC45206A0064ED47BFC467C0644C04C09D4CE203B3B` |
| Source packet | `63F8C5FC06BAE2D90B50673C6B7B966FBAF5962150D70F695DD3DA8DBB221FA8` |
| Canonical/build card | `FD7B0BED3AD72770ECD5312C493C0726B42D87AF19E68B03BCAB3CB3AAFF022F` |
| MQ5 | `4F590DF17B3BC76625A463F01834EB6BBBEE46AFCE77BB428EA0076B6BFBF8C6` |
| EX5 | `8A6BE70F6E85E8E0D5A2B3E47606FE852ACD821480AA4FA011C4F1815D9FC61D` |
| SPEC | `D59D21C741D4D7E2993468B54BE3D8D9F034B7B9EAA1E3ED7BEA6E27DF60A249` |
| Backtest set | `BE5C86AAFF8EA2966900A8D208F07D95DBB8FA5F0DC57B9458B2F9CE5EB66D5F` |

## Paced Q02 Handoff

The binding pre-enqueue `farmctl mt5-slots` sample at
`2026-08-10T09:38:37+00:00` found four executing factory terminals against the
ceiling of seven. A preceding detailed sample identified T2, T3, T5, and T6.
The scan separately observed T_Live and the FTMO terminal outside the T1-T10
factory roots; those were excluded from the count and were not changed.

The target-only dry run selected one never-tested row, with 1,113 pending rows
against the queue ceiling of 7,000. The single apply run then enqueued one and
no stranded retry or deferred promotion:

- Work item: `7922d63b-dbb4-4269-bc4c-6fcaf7a760c1`.
- Created: `2026-08-10T09:38:40+00:00`.
- Phase/kind: Q02 / backtest.
- Symbol/timeframe: `XTIUSD.DWX` / D1.
- Setfile:
  `QM5_20270_wti-trimmean-mom_XTIUSD.DWX_D1_backtest.set`.
- Priority: `priority_track=true`.
- Immediate state: pending, attempt 0, unclaimed, no verdict.

## Commits Before This Closing Evidence

- `91277c50b` — OWNER mission authorization and exact G0 decision.
- `3b4ba6a60` — bounded source packet plus approved/intake cards.
- `5e290f96f` — deterministic EA-ID reservation.
- `33a474023` — WTI magic allocation, resolver generation, and SPEC.
- `bc1dd6b36` — EA source, compiled EX5, build card, Q01 status, and fixed-risk
  set binding.

## Safety Boundary

- No manual backtest, smoke test, dispatch tick, or downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled; T_Live was not changed.
- The portfolio gate and T_Live manifest were not touched.
- No efficacy, certification, decorrelation, or portfolio-admission result is
  inferred from enqueue.

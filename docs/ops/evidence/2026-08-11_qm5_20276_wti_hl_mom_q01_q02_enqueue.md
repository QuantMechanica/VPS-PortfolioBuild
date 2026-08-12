# QM5_20276 WTI Hodges-Lehmann Momentum — Q01 PASS / Q02 Enqueued

Date: 2026-08-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20276_wti-hl-mom` is a new low-frequency outright WTI structural-trend
candidate. It passed Q01 and has exactly one Q02 work item:
`dd8c4995-ea1d-4b8b-baa2-1cfbfb063b83`.

Immediate readback found the row pending, attempt 0, unclaimed, and without a
verdict. Enqueue is a screening handoff, not an efficacy, certification,
decorrelation, or portfolio-admission result.

## Edge And Non-Duplicate Boundary

At each genuine `XTIUSD.DWX` broker-month transition, the EA reconstructs
thirteen consecutive completed WTI month-end closes and forms twelve adjacent
chronological log returns. It then enumerates all 78 inclusive pairwise
averages `(r[i]+r[j])/2` for `0 <= i <= j <= 11`, sorts them, and averages
zero-based center indexes 38 and 39. A positive pseudomedian buys, a negative
pseudomedian sells, and exact-zero or invalid states consume the monthly event
flat. The position renews at the next month transition and is otherwise
protected by a frozen `3.5 * ATR(20,D1)` hard stop and a forty-day stale exit.

The deterministic pre-allocation check scanned 4,341 EA-registry rows and 451
cards and found no exact duplicate. It surfaced only the expected 0.50 fuzzy
matches to `QM5_20269_wti-medret-mom` and `QM5_20270_wti-trimmean-mom`.
Manual review separated this estimator from:

- `QM5_20269`: the raw median uses only sorted return indexes 5 and 6;
- `QM5_20270`: the trimmed mean averages direct sorted return indexes 2-9;
- `QM5_20271_wti-theilsen-tr`: 78 forward log-price slopes use `i < j` and
  divide by elapsed months; and
- `QM5_20272_wti-patheff-mom`: path-efficiency mechanics do not estimate the
  inclusive pairwise-average return location.

The exact thirteen endpoints, twelve adjacent returns, inclusive self-pairs,
78-value count, ascending sort, center indexes, direction, monthly attempt,
and renewal lifecycle are load-bearing.

WTI adds a crude-oil carrier distinct from the current XAU, SP500, NDX, and
XNG instruments, but different instrument and estimator do not prove low or
negative realized correlation. Q09 alone may establish portfolio correlation
if the candidate survives the earlier gates.

## Source And G0 Record

The bounded source packet is
`strategy-seeds/sources/MOP-WTI-HLRET-2026/source.md`. Its complete-read parent
is Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The peer-reviewed paper includes WTI in its
commodity-futures universe and supports testing monthly own-price trend.

The paper does not specify the inclusive pairwise-average pseudomedian, CFD
mapping, ATR stop, spread cap, or lifecycle. Those are explicit QM
mechanization choices. No source performance, CFD equivalence, or portfolio
correlation result is imported. G0 authorization is
`decisions/2026-08-11_qm5_20276_wti_hl_mom_g0.md`.

Reputable-source checks R1-R4 pass: one named peer-reviewed DOI record with a
complete governed read and durable hash; exact mechanical rules; a registered
WTI D1 route; and deterministic native arithmetic with no ML, trained output,
banned signal indicator, external runtime feed, grid, martingale, scale-in, or
pyramid.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20276` / `wti-hl-mom` /
  `MOP-TSMOM-2012_XTI_HLRET12_S24`.
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `202760000`.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Resolver generation: 15,850 rows kept, zero dropped; target magic
  `202760000` is present in the generated resolver.
- Strict compile: `D:/QM/reports/compile/20260811_034736/summary.csv`, PASS
  with zero errors and zero warnings.
- Strict compile log:
  `C:/QM/repo/framework/build/compile/20260811_034736/QM5_20276_wti-hl-mom.compile.log`.
- Targeted build check:
  `D:/QM/reports/framework/21/build_check_20260811_034736.json`, PASS with
  zero failures and zero warnings.
- P1 artifact validation:
  `D:/QM/reports/pipeline/QM5_20276/P1/P1_QM5_20276_result.json`, PASS.
- Independent estimator reference test: PASS for 78 pairs, indexes 38/39,
  constant-positive, constant-negative, symmetric-zero, and one-outlier robust
  cases.
- Card-schema/ML lint, build guardrails, SPEC validation, and canonical/build
  card identity: PASS.
- Generated setfile header build hash:
  `ebb694b6c758a0cb0a8f91a7bfd9f3f367957391b59499f4798bbe9779575972`.
- Manual smoke/backtest: none.

Artifact SHA-256 values at Q02 handoff:

| Artifact | SHA-256 |
|---|---|
| Bounded source packet | `E0E6CF16F7A4656B7613702C39C19657653424819EFB61EE1CEBD9CC46403D8C` |
| Canonical/build card | `42554A38449565CEC5045622F00A4E6EB3ADF6DFAA466709491D6B28C6632626` |
| MQ5 | `AF00251EE72A85624301AD568EC1BDB570464E03B80E3FEB689DB3B30AB9073C` |
| EX5 | `335AEB69FC4BF8DDB95CBFE965429DB316C766D10D8D72320C675A780D2B24CC` |
| SPEC | `28C5F305C4C57E143FF67FD0B9BD05565A55C64753D9BD8ADEDB9A7FC2450D30` |
| Backtest set | `5AF6432AC89D3E0774D7CB6B864D17FDBC94E60A7D929068E233671C4FB9768E` |

## Paced Q02 Handoff

Before mutation, target readback found zero prior work items. The exact-EA dry
run selected one never-tested priority-track WTI row, no stranded retry, and
no deferred promotion.

The binding `farmctl mt5-slots` sample at
`2026-08-11T03:50:29+00:00` found two executing T1-T10 factory terminals
against the ceiling of seven: T6 and T8. T_Live and the unrelated FTMO
terminal were outside the factory count and were not changed. The CPU ceiling
was not reached.

The first apply attempt was fail-closed because the shared mutation lock was
busy. Its `terminal_worker.claim_atomic:T2` owner PID had exited. This mission
did not bypass, alter, or delete the lock. At the canonical 120-second stale
threshold, `terminal_worker.claim_atomic:T10` reaped the dead-owner record and
wrote the audit row to `D:/QM/reports/state/mutation_lock_reaps.jsonl`. The
subsequent normal lock-guarded apply enqueued exactly one row:

- Work item: `dd8c4995-ea1d-4b8b-baa2-1cfbfb063b83`.
- Created: `2026-08-11T03:52:14+00:00`.
- Phase/kind: Q02 / backtest.
- Symbol/timeframe: `XTIUSD.DWX` / D1.
- Setfile: `QM5_20276_wti-hl-mom_XTIUSD.DWX_D1_backtest.set`.
- Priority: `priority_track=true`.
- Readback state: pending, attempt 0, unclaimed, no verdict.

## Commits Before This Closing Evidence

- `2b1c8b198` — OWNER mission authorization and exact G0 decision.
- `a65547246` — bounded source packet plus approved/intake cards.
- `e351d10e7` — deterministic EA-ID reservation.
- `78569a91c` — magic allocation and resolver generation.
- `bbcd87996` — EA source, EX5, fixed-risk setfile, and build card.

## Safety Boundary

- No manual backtest, smoke test, dispatch tick, or downstream phase was run.
- No terminal was started, stopped, reserved, or altered by this mission; the
  standing factory remains responsible for later claiming the pending row.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled; T_Live was not changed.
- The portfolio gate and T_Live manifest were not touched.
- No efficacy, certification, decorrelation, or portfolio-admission result is
  inferred from enqueue.

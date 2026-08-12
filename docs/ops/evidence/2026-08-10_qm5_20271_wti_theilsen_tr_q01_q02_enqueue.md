# QM5_20271 WTI Theil-Sen Robust Trend — Q01 PASS / Q02 Enqueued

Date: 2026-08-10 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20271_wti-theilsen-tr` is a new low-frequency direct-WTI structural
candidate. It passed Q01 and has exactly one Q02 work item:
`62f9a076-8d5a-4da4-a246-bd0def468b05`.

Immediate readback found the row pending, attempt 0, unclaimed, and without a
verdict. Enqueue is a screening handoff, not a profitability, certification,
decorrelation, or portfolio-admission result.

## Edge And Non-Duplicate Boundary

On the first `XTIUSD.DWX` D1 bar of a genuine broker-month transition, the EA
reconstructs thirteen consecutive completed month-end closes and takes their
natural logarithms. For every forward pair `(i,j)`, it calculates the
distance-normalized slope `(log_price[j]-log_price[i])/(j-i)`. It sorts all 78
slopes ascending and uses the even-sample median
`(sorted[38]+sorted[39])/2`. A positive median buys WTI and a negative median
sells WTI. Exact-zero or invalid state consumes the month flat.

The position renews monthly, has a forty-calendar-day stale guard, and carries
one frozen `3.5 * ATR(20,D1)` hard stop. A persistent month-attempt marker,
owned-position state, and deal history prevent same-month re-entry.

The deterministic pre-allocation check found no exact or fuzzy identity across
4,328 EA-registry rows and 444 intake cards. Manual review separated the rule
from cumulative WTI return horizons, multi-horizon votes, adjacent-return sign
counts, `QM5_20261` OLS slope plus `R^2`, `QM5_20264` magnitude-free ordinal
rank trend, and the adjacent-return median/trimmed-mean builds `QM5_20269` and
`QM5_20270`. The load-bearing distinction is the median of every one of the 78
overlapping multi-horizon log-price slopes with exact `j-i` normalization.

Direct crude oil is a different carrier from the certified XAU, SP500, NDX,
and XNG book, but realized independence is not claimed. Q09 alone may
establish portfolio correlation if the candidate reaches it.

## Source And G0 Record

The bounded source packet is
`strategy-seeds/sources/MOP-WTI-THEILSEN-2026/source.md`. Its complete-read
parent is Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*,
*Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The peer-reviewed paper includes WTI and
documents monthly own-return continuation.

The robust pairwise-slope estimator, exact pair and median indexes, CFD
mapping, fixed-risk sizing, stop, spread cap, and lifecycle are transparent QM
mechanizations, not source performance claims. G0 authorization is
`decisions/2026-08-10_qm5_20271_wti_theilsen_tr_g0.md`.

Reputable-source checks are R1-R4 PASS: complete peer-reviewed source with DOI
and durable retrieval hash; exact mechanical rules; registered WTI D1 data;
and deterministic native arithmetic with no ML, trained output, banned signal
indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20271` / `wti-theilsen-tr` /
  `MOP-TSMOM-2012_XTI_THEILSEN12_S20`.
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `202710000`.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Resolver regeneration: 15,568 rows kept, zero dropped; registry hash
  `2492E2A2995E3292A8B8C3A30F4CCE60AEEBA16D6946CC7090E49E44D12A962B`.
- Strict compile: `D:/QM/reports/compile/20260810_125956/summary.csv`,
  PASS with zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260810_125956/QM5_20271_wti-theilsen-tr.compile.log`.
- Target build check:
  `D:/QM/reports/framework/21/build_check_20260810_125956.json`, PASS with
  zero failures and zero warnings.
- P1 artifact validation:
  `D:/QM/reports/pipeline/QM5_20271/P1/P1_QM5_20271_result.json`, PASS.
- Card-schema/ML lint, G0 lint, build-prerequisite guard, and SPEC validation:
  PASS.
- Generated setfile header build hash:
  `cb157cf6fb36fc77c24c9f9d534ccfe73377d3f79d326d75a7ec64b8873e15f2`.
- Manual smoke/backtest: none.

The repository-wide legacy registry validator remains red on pre-existing
invalid legacy IDs/slugs and registry mismatches. The new target row itself is
unique and formula-correct, resolver generation dropped zero rows, and the
strict target build's complete magic-collision gate passed.

Artifact SHA-256 values at handoff:

| Artifact | SHA-256 |
|---|---|
| EA registry | `F038CDF64214A0714E1DB73BD64C55FFE9A84340960269DEE1BAB8956B500EA0` |
| Magic registry | `2492E2A2995E3292A8B8C3A30F4CCE60AEEBA16D6946CC7090E49E44D12A962B` |
| Generated magic resolver | `8C2D6E9648D731C58D949ADFBACADDAA50461315AA2DFD5595C0650ECF711D67` |
| Source packet | `F83880B74B1DB645F6C20A58B76825DA96787E327C461D0E798CA01CAB72535E` |
| Canonical/build card | `20C7C6B6EF85A55B26E1A47BA3953C214C11DE4A73DB772535DB7543CD4035F8` |
| MQ5 | `CC585D137F60D7F872FC7D424CAC6AFB458526E769314771553E1F988977085B` |
| EX5 | `4875F2CA9B5098B5F092C3ABB47C5A046DCE8ABF45EB7249FADB727C179A8FCD` |
| SPEC | `33F26928A35F1992C68F047A07BDE2DFDA01F589609522A4D51D69CAD414A763` |
| Backtest set | `22AE26EF2E5D30148F37955221AD154C97D988E365D1BD7E08774447B810F9EE` |

## Paced Q02 Handoff

The binding pre-enqueue `farmctl mt5-slots` sample at
`2026-08-10T13:03:22+00:00` found four executing factory terminals against the
ceiling of seven: T1, T5, T8, and T10. The scan separately observed T_Live and
the FTMO terminal outside the T1-T10 factory roots; those were excluded from
the count and were not changed.

Before mutation, target readback found zero prior work items. The exact
EA-and-symbol dry run selected one never-tested priority row, no stranded
retry, and no deferred promotion. The single guarded apply ran below the CPU
ceiling with 1,105 pending rows against the queue ceiling of 7,000, then
enqueued one item:

- Work item: `62f9a076-8d5a-4da4-a246-bd0def468b05`.
- Created: `2026-08-10T13:03:29+00:00`.
- Phase/kind: Q02 / backtest.
- Symbol/timeframe: `XTIUSD.DWX` / D1.
- Setfile:
  `QM5_20271_wti-theilsen-tr_XTIUSD.DWX_D1_backtest.set`.
- Priority: `priority_track=true`.
- Immediate state: pending, attempt 0, unclaimed, no verdict.

## Commits Before This Closing Evidence

- `f1d60ea9e` — OWNER mission authorization and exact G0 decision.
- `fa1f6cdf6` — bounded source packet plus approved/intake cards.
- `d25a9bb15` — deterministic EA-ID reservation.
- `65faee4da` — WTI magic allocation, resolver generation, and SPEC.
- `089a453ea` — EA source, compiled EX5, build card, Q01 status, and fixed-risk
  set binding.

## Safety Boundary

- No manual backtest, smoke test, dispatch tick, or downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled; T_Live was not changed.
- The portfolio gate and T_Live manifest were not touched.
- The unrelated pre-existing `QM5_11177` untracked setfile was preserved and
  excluded from every mission commit.

# QM5_41190 XTI/XNG Monthly Theil-Sen Compile Handoff

Date: 2026-08-28

Branch: `agents/board-advisor`

Outcome: `SOURCE BUILD COMMITTED; Q01 PENDING_GOVERNED_COMPILE; Q02 NOT_ENQUEUED_Q01_PENDING`

## New energy relative-value edge

`QM5_41190_xtixng-mtheilsen-rv` is a low-frequency, market-neutral-style
XTI/XNG basket. At the first synchronized D1 boundary of each broker month it
loads the last close from each of the thirteen immediately completed months,
forms `log(XTI)-log(XNG)`, enumerates all 78 forward pairwise slopes, and
averages sorted indexes 38 and 39. A positive median slope is faded with SELL
XTI / BUY XNG; a negative median slope is faded with BUY XTI / SELL XNG; exact
zero consumes the month flat.

The two legs target equal absolute USD notionals within a fixed 20% rounding
tolerance. XTI opens first and XNG second through the V5 basket-order helper,
with atomic rollback if the companion leg fails. The pair exits at the next
broker month or after a forty-day stale repair. One aggregate
`RISK_FIXED=1000` budget is split across frozen `3.5*ATR(20,D1)` stops. All
three presets are backtest-only, set `RISK_PERCENT=0`, and leave news and
Friday overrides off.

The edge is mechanically distinct from certified `QM5_12567`, a long-only
XNG cumulative-RSI2 pullback: this candidate trades an opposite-sided oil/gas
relative-value package from a monthly robust log-ratio slope. The construction
makes diversification plausible but does not claim realized decorrelation;
Q09 remains authoritative.

## Governed research and identity

Complete source records combine the peer-reviewed oil/gas linkage evidence of
Villar/Joutz and Ramberg/Parsons with the peer-reviewed time-series-momentum
lineage of Moskowitz/Ooi/Pedersen. The exact thirteen-point, 78-slope
Theil-Sen transformation is disclosed as a QM implementation rule rather than
as transferred paper performance.

The canonical preallocation duplicate checker found no exact identity. Its
only fuzzy hits were the different-carrier XAU/XAG Theil-Sen family; manual
semantic review cleared the XTI/XNG energy carrier and economic exposure as a
new strategy identity. EA ID `41190` and active magics `411900000` (XTI slot
0) and `411900001` (XNG slot 1) were allocated through the deterministic
registries.

Committed trail:

- `1c171e0ff` — reputable-source approval and preallocation dedup receipt;
- `69c44b20d` — bounded source-to-rule extraction packet;
- `035399329` — EA ID reservation, G0-approved card, and identity row; and
- `bc4406985` — V5 source, basket manifest, local card, reference suite,
  specification, fixed-risk presets, magic rows, and regenerated resolver.

The approved and EA-local cards are byte-identical at SHA-256
`5790AC6F0AC2749C6D5850572900E1949B230EFB2AE2E64A46A5FC788F3AA54E`.
The MQ5 SHA-256 is
`4CAE626A3637FCEEDBF042F0B4B558C56F6FCD890C418EA839C2113E0AC2FF0C`;
the basket-manifest SHA-256 is
`CFC182745C0C2ADD617D36F27D52749A56D7BBE887BC586F06C32FB35992083F`.

## Source-level validation

Eight deterministic reference tests pass. They cover the exact 78-slope
median arithmetic and indexes, both trade directions, the zero case, monthly
synchronization and endpoint rules, equal-notional risk balancing, two
fixtures separating Theil-Sen from the repository's repeated-median and LAD
families, and static bindings across card, manifest, source, presets, magics,
and resolver.

Card schema/prohibited-ML lint, the V5 build prerequisite guard, and SPEC
validation pass. No strict compile, EX5, Q01 verdict, smoke result, or economic
result is claimed by those source-level checks.

## Compile and Q02 disposition

The strict ad-hoc compile correctly stopped before MetaEditor execution with
`INCLUDE_MIRROR_REFUSED` / `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because live
factory terminal processes hold the include-mirror interlock. No retry,
terminal control, mirror bypass, or process interruption was attempted. The
durable compile summary is
`D:/QM/reports/compile/20260828_000030/summary.csv`, SHA-256
`1311C9A2FE1966BE9ED1248E54C9549424454A77000DA53693610063391B4358`.

The sanctioned governed lane accepted one source-bound compile item:
`5b6a9525-e988-4b0f-a7ec-b9f879adbb49`. The latest status is `pending` with
one active hold, `COMPILE_EA_WORKER_ROLLOUT_PENDING`; it has no compile
verdict, build-check result, evidence path, EX5 hash, or setfile binding.

Q02 was therefore not enqueued. Repository admission requires an exact
current `.ex5`, an admitted Q01 smoke/build record, and an
`APPROVE_FOR_BACKTEST` review predecessor before it creates the logical-basket
row. Creating a row while the compile is held would violate those fail-closed
contracts. No component-leg Q02 rows were created. A later governed pass must
consume the existing compile item, require strict zero-error/zero-warning
output and the exact source identity, bind the final preset to the produced
binary, complete Q01 review, check capacity, and enqueue exactly one logical
`QM5_41190_XTI_XNG_MTHEILSEN_RV_D1` Q02 row.

## Safety boundary

No backtest or dispatcher was started, so the backtest CPU ceiling was not
approached. No terminal was started, stopped, reserved, released, or reaped.
AutoTrading was not toggled. T_Live, its manifest, the portfolio gate, deploy
records, and portfolio-admission records were untouched. Unrelated dirty
fleet-generated setfiles and binaries were preserved and remain unstaged.

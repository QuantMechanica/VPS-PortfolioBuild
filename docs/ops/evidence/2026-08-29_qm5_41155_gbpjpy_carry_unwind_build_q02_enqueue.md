# QM5_41155 GBPJPY carry-unwind compile and Q02 enqueue

Date: 2026-08-29 UTC / 2026-08-30 Europe/Berlin

Branch: `agents/board-advisor`

Outcome: `COMPILE_OK_Q02_ENQUEUED`

## Diversity selection

`QM5_41155_gbpjpy-carry-unwind-crisis-momentum` was the highest-value
non-duplicate continuation in the diverse build lane. Its approved source,
SPEC, registry identity, and fixed-risk presets were already committed in
`c4344813a`; that wake stopped before compile because one CPU sample reached
`98.24%`, above the hard `97%` ceiling. Resuming the same atomically claimed
GBPJPY item advances a forex carrier outside the user-stated Q08 survivor
concentration in indices, metals, and energy. This is an instrument-diversity
candidate, not a certification or decorrelation claim.

The approved Tier-A lineage is Brunnermeier, Nagel, and Pedersen, *Carry
Trades and Currency Crashes* (NBER Working Paper 14473; later NBER
Macroeconomics Annual 23). The runtime card remains G0 `APPROVED` and has
SHA-256 `b5d41a26fe3f787d6fcd600553cd7b3f9fc2234805bd4b1439822cfa95b3e67c`.

The D1 rule is structural and short-only:

- require the equal-weight five-session return across AUDJPY, NZDJPY, CADJPY,
  and EURJPY to be at or below `-1%`;
- require GBPJPY to close below the prior 20-bar low;
- require 10-session realized volatility to exceed the median of the prior
  60 rolling observations;
- freeze a `2.0 * ATR(14)` hard stop at entry;
- exit after ten completed D1 bars or above the prior-channel midpoint.

AUDJPY, NZDJPY, CADJPY, and EURJPY are synchronized read-only signal inputs.
Only `GBPJPY.DWX` receives orders, magic `411550000`, or risk allocation. The
sealed presets bind `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No ML, adaptive parameter, grid, martingale, averaging,
or banned indicator is present.

## Non-duplicate farm continuation

This unit reused build task `e8e61fe1-2589-4f97-adb7-7de16892f9e4` and the
exact MQ5-SHA-bound compile item `7ea94446-82a8-4cf2-a9ee-51d5dc8e1ac1`.
Before record-build, the farm contained no QM5_41155 Q02 row. No duplicate EA
ID, build task, compile item, or queue row was created.

The compile hold release was target-only. Expected and actual MQ5 SHA-256 both
matched `355bf656e92b93298878dbd24822db76b17bc6db4c9eb5e124a37796682ed0a6`.
The mandatory pre-release database backup is
`D:/QM/strategy_farm/state/backups/farm_state_before_compile_wave_20260829T223912Z_7eb8c61b.sqlite`,
SHA-256 `d44eec5745e5976cca6610c9ae85e7739ed63bfdda7455d21264c03d67b8b9c1`.

## Governed compile

The resident T3 worker returned:

- verdict `COMPILE_OK`;
- strict compile: 0 errors, 0 warnings;
- build check: PASS, 0 failures;
- EX5 SHA-256
  `cb934fa03c537c4160aa5b7a501b4beae2b5b2fc8bd3bfd69695a3eaa2c0cbea`;
- compile-evidence SHA-256
  `73b3a5aaaa3d1532d3528788230e6d62e7acb4b68f0dcf74db936b1f9a64aec8`.

The static gate emitted one review advisory because the source retrieves swap
metadata. Inspection confirms it checks only retrieval and numeric validity;
it never requires a positive, negative, or non-zero swap. Zero-swap `.DWX`
tests therefore remain eligible. No ad-hoc compiler or tester was launched.

## Capacity and Q02 handoff

The five-sample window immediately before compile release averaged `80.96%`
and peaked at `89.95%`. The pre-Q02 window averaged `84.66%` and peaked at
`88.12%`. The post-enqueue confirmation averaged `69.59%` and peaked at
`73.95%`. None bound the hard `97%` ceiling.

Recording the successful build atomically created exactly one basket-aware
Q02 item:

- work item `93f959d9-41a7-4e6c-9e95-ca183cb973de`;
- logical symbol `QM5_41155_GBPJPY_CARRY_UNWIND_CRISIS_MOMENTUM_D1`;
- host `GBPJPY.DWX`, D1;
- read-only inputs AUDJPY/NZDJPY/CADJPY/EURJPY, with GBPJPY solely traded;
- custom-history archive admission `ACTIVE` with 540 selected rows;
- first readback `pending`, attempt 0, unclaimed.

The physical-host setfile was correctly skipped in favor of the logical
basket setfile, so the enqueue cohort size is one. The item was enqueued only;
this mission did not dispatch or backtest it.

## Safety boundary

No AutoTrading state, terminal process, T_Live environment or deploy manifest,
portfolio gate, live preset, or portfolio admission was touched. Downstream
Q02-Q09 evidence remains authoritative for frequency, robustness, and sleeve
diversification.

Machine-readable receipt:
`artifacts/qm5_41155_build_q02_enqueue_20260829.json`.

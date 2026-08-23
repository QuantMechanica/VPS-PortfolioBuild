# QM5_41132 WTI weekday-median build and CPU-ceiling handoff

Date: 2026-08-23

Branch: `agents/board-advisor`

Verdict: `SOURCE_READY_COMPILE_HELD_CPU_CEILING`

## Delivered build package

`QM5_41132_wti-mweekday-med-mom` is a new single-carrier WTI D1 sleeve under
strategy ID `MOP-MEEK-WTI-MWEEKDAY-MED-2026_S01`. It is not a copy of the
existing raw-endpoint, daily-breadth, block-vote, tail-trim, cross-month-median,
fixed-weekday, or XNG RSI families.

On the first executable bar of each normalized broker month, the EA rebuilds
the immediately completed month from 17-23 D1 sessions plus one older boundary
close. It forms every chronological return ending in the month, partitions by
normalized Monday-Friday ending weekday, requires all five buckets and 3-5
observations per bucket, computes five arithmetic means, and follows exact
sorted index two. The raw endpoint is an identity check and diagnostic only.

The package contains:

- strict V5 source with the standard framework hooks and per-tick lifecycle
  repair;
- `SPEC.md` and the approved card copy;
- one D1 `XTIUSD.DWX` backtest preset locked to `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`;
- a 17-case deterministic Python reference suite covering label conventions,
  month boundaries, session and bucket bounds, weekday assignment, exact
  means/median, endpoint agreement and disagreement, attempt persistence,
  fixed risk, and lifecycle repair.

Identity is active in both deterministic registries:

- EA ID: `41132`
- slug: `wti-mweekday-med-mom`
- symbol/slot: `XTIUSD.DWX / 0`
- magic: `411320000`

## Verification completed

- Card schema lint: PASS; no missing sections and no ML hits.
- Reference suite: PASS, 17/17.
- `validate_spec_doc.py`: PASS, 1/1.
- `validate_build_guardrails.py`: PASS, two runtime files checked, zero
  findings, maximum news staleness 336 hours.
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`, zero
  violations.
- Target rows in `ea_id_registry.csv` and `magic_numbers.csv` match exactly;
  the resolver retains 17,833 rows with zero drops and embeds the target magic.
- MQ5 SHA-256 at enqueue:
  `B53B6392D13FD0C08AF726712A99CF77B5370A7F2E47EA4FE2C215617DE3C78B`.
- Package whitespace audit: no finding outside the enqueue-bound MQ5's final
  blank line; that byte is retained deliberately so the working source remains
  identical to the governed compile-row SHA-256 above.

The repository-wide registry validator still reports the known legacy corpus
findings outside EA 41132. No target-specific finding names `41132`, and those
unrelated rows were not changed or waived.

## Compile and Q02 boundary

Direct strict compile and direct build-check both stopped at the live-factory
guard with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`. No retry bypass, terminal
start/stop, process interruption, or manual tester was attempted.

The canonical governed compile enqueue succeeded:

- work item: `690cf433-d157-49d0-aaa8-57b58431a845`
- phase: `COMPILE_EA`
- status: `pending`
- activation hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`
- source hash: the SHA-256 above

No `.ex5` exists yet, so Q01 compile PASS is not claimed and Q02 is not legally
enqueueable.

The bounded CPU sample recorded in
`artifacts/qm5_41132_cpu_ceiling_20260823.json` was
`94.3, 99.9, 99.6, 100.0, 96.5%`, averaging `98.1%`. This exceeds the factory
claim ceiling `CPU_MAX_LOAD_PERCENT=97.0` in
`tools/strategy_farm/terminal_worker.py`. The OWNER mission explicitly requires
stopping and summarizing at that ceiling, so the compile hold was not released
and no Q02 row was created.

## Governed continuation

After sustained CPU recovery, release only the exact source-fresh compile row
through the bounded compile rollout path and wait for its normal worker to
produce strict compile/build-check evidence and a bound EX5 hash. Only a
`COMPILE_OK` result permits one target-only Q02 enqueue for
`QM5_41132 / XTIUSD.DWX / D1`.

No portfolio gate, T_Live manifest, T_Live file, AutoTrading state, live/demo/
shadow preset, gate threshold, or existing strategy was touched.

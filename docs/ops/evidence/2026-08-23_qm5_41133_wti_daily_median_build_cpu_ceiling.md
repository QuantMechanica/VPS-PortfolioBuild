# QM5_41133 WTI daily-return-median build and CPU-ceiling handoff

Date: 2026-08-23

Branch: `agents/board-advisor`

Verdict: `SOURCE_READY_COMPILE_HELD_CPU_CEILING`

## Delivered commodity sleeve

`QM5_41133_wti-mdaily-median-mom` is a new single-carrier WTI D1 sleeve under
strategy ID `MOP-MEEK-WTI-MDAILY-MED-2026_S01`. It is a structural own-price
edge, not a copy of the existing raw-endpoint, cross-month median, daily-sign
breadth, daily persistence, one-tail trim, path-efficiency, RMS-coherence,
open-residence, fixed-weekday, weekday-bucket-median, or XNG RSI families.

On the first executable D1 bar of each normalized broker month, the EA rebuilds
the immediately completed month from 17-23 session closes and one older
boundary close. It forms every chronological close-to-close log return ending
in that month, sorts the complete sample without rounding, and follows the
ordinary odd/even sample median. The direct month endpoint is an arithmetic
identity check and diagnostic only; it never gates direction or size.

The implementation is fixed-risk and low-frequency:

- exact carrier and timeframe: `XTIUSD.DWX / D1`;
- one consumed attempt and at most one position per broker month;
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`;
- frozen `3.5*ATR(20,D1)` hard stop, no target, and a forty-day stale repair;
- both news axes and Friday close OFF;
- no optimization, ML, banned indicator, live, demo, shadow, or stress preset.

The source packet cites Moskowitz, Ooi, and Pedersen (2012) for WTI own-return
time-series-momentum lineage and Meek and Hoelscher (2023) for daily
close-to-close WTI log-return construction. The exact within-month ordinary
median is disclosed as an untested QM hypothesis, not a transferred paper
result.

## Identity and commits

- EA ID: `41133`
- slug: `wti-mdaily-median-mom`
- magic: `411330000`
- source approval: `37bb3f499`
- bounded source extraction: `9b0a166c8`
- G0-approved card: `c90fc3b8a`
- deterministic EA-ID reservation: `16120953d`
- governed magic allocation: `a88532b23`
- EA/spec/test/set implementation: `276ca06bb`
- MQ5 SHA-256 at enqueue:
  `7C8AEB3382BF3D8B84325661DFB699458BD115C84455E04C9A0C5A34F08DED04`

Both deterministic registry rows are active, and the generated magic resolver
contains `411330000`.

## Verification completed

- canonical research dedup before allocation: CLEAN across 4,632 registry
  identities, 1,300 cards, and 45 wiki nodes;
- post-allocation dedup: only the target's own registry/card identities match;
- card schema lint: PASS with no missing sections and no ML hits;
- deterministic Python reference suite: PASS, 16/16;
- `validate_spec_doc.py`: PASS, 1/1;
- `validate_build_guardrails.py`: PASS for the MQ5 and sole backtest setfile;
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`, zero
  violations;
- package whitespace audit: PASS;
- build-card copy and approved card had identical SHA-256 before the phase-log
  update and remain synchronized by the same update.

## Compile and Q02 boundary

Direct strict compile and direct strict build-check both stopped at the
live-factory guard with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`. No retry bypass,
terminal start/stop, process interruption, include-mirror mutation, or manual
tester was attempted.

Exactly one governed compile row was enqueued:

- work item: `1fb58c79-e46f-4d72-9af1-26eb4656e0d5`
- phase: `COMPILE_EA`
- status: `pending`
- activation hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`
- source hash: the SHA-256 above

No `.ex5` or strict build-check result exists, so Q01 PASS is not claimed and
Q02 is not legally enqueueable.

The bounded CPU observation in
`artifacts/qm5_41133_cpu_ceiling_20260823.json` recorded
`99.8, 100.0, 99.5, 93.6, 98.3%`, averaging `98.2%`. This exceeds the worker
claim ceiling `CPU_MAX_LOAD_PERCENT=97.0` in
`tools/strategy_farm/terminal_worker.py`. The mission explicitly requires
stopping and summarizing at that ceiling, so the compile hold was not released
and no Q02 row was created.

## Governed continuation

After sustained CPU recovery below the configured resume threshold, release
only the exact source-fresh compile row through the one-item governed compile
wave. Wait for its normal worker to produce strict compile/build-check evidence
and a bound EX5 hash. Only `COMPILE_OK` permits one target-only Q02 enqueue for
`QM5_41133 / XTIUSD.DWX / D1` using the committed RISK_FIXED backtest setfile.

No portfolio gate, T_Live manifest, T_Live file, AutoTrading state, live/demo/
shadow preset, gate threshold, existing EA, or terminal process was touched.

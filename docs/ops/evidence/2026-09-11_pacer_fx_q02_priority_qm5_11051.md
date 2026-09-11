# PACER forex Q02 priority — QM5_11051

## Outcome

No clean unbuilt relationship remains in the deterministic 66-relationship FX
frontier. The fallback clause was therefore used to advance one existing forex
card: `QM5_11051_pst-volatten-break` on `GBPUSD.DWX` D1. Existing Q02 work item
`97c5fffa-691b-407a-8a5f-363197037048` was marked `priority_track=true`; it
remains `pending`, unclaimed, and has no active hold.

No EA source was generated or changed, no compile was enqueued, no additional
Q02 row or date window was created, and no live, T_Live, or portfolio gate was
touched.

## Frontier and anchor decision

`docs/research/FX_COINTEGRATION_FRONTIER_DUPLICATE_GUARD_2026-07-24.md` is the
authoritative duplicate guard for the sign-aware scan. It records that all 66
relationships are represented and all seven strict survivors are already built
with terminal Q02 evidence. Creating another pair from that frozen scan would
therefore duplicate an existing relationship.

The two suggested anchors are not Q02-blocked:

- `QM5_12532` (`AUDUSD.DWX/NZDUSD.DWX`) — Q02 `PASS`, work item
  `e4890d77-6fa1-489d-ad76-4d05ba3b27fa`.
- `QM5_12533` (`EURJPY.DWX/GBPJPY.DWX`) — Q02 `PASS`, work item
  `76cb11ee-902b-477e-9a13-b28e479b2a4f`.

Other plausible fallbacks were rejected before spending MT5 capacity:

- `QM5_41141` has a stale independent REVIEW entry-gate block, so it cannot be
  truthfully promoted without a new review decision.
- `QM5_1092` already has four Q02 `FAIL` results plus one `ZERO_TRADES` result.
- `QM5_1193` is explicitly a correlated SP500/oil stress-triggered USD basket,
  contrary to this mission's diversification preference.

## Selected sleeve

`QM5_11051` is OWNER-approved from Rob Carver's public `pysystemtrade` rule and
configuration sources. It evaluates a deterministic six-horizon channel
breakout once per completed D1 bar, applies a fixed volatility-attenuation
formula, and uses a fixed ATR emergency stop. The card and source contain no ML,
grid, martingale, or adaptive PnL mechanics. There are no completed economic
failures for this EA; its only non-pending Q02 record is an infrastructure
failure on an index symbol.

The selected backtest set is fixed-risk:

- `RISK_FIXED=1000`
- `RISK_PERCENT=0`
- `qm_magic_slot_offset=1`
- host: `GBPUSD.DWX`, timeframe: `D1`

Hashes at the priority decision:

- MQ5: `c73b86f3685ba8af3929e9da2b3fbae0f87f3c888373b641499246669a0d1be6`
- EX5: `90e0d5f698125b77c67f70cdb1ddf2bad9329425a9376744b761af41ef7c5bbe`
- setfile: `6376e046f6bd2ba058f541d66c85ccf40ad09fc2f68a19da3381e70d66bf5133`

## Build guard and capacity

The exact guard path required by the mission,
`tools/strategy_farm/audit_ea_input_pinning.py`, is absent from this checkout;
the prescribed command exited 2 with `can't open file`. The repository's
available fail-closed equivalent was run against the unchanged source:

```text
python tools/strategy_farm/audit_framework_input_pins.py --check-source framework/EAs/QM5_11051_pst-volatten-break/QM5_11051_pst-volatten-break.mq5
ok=true, predicate=EA_FRAMEWORK_INPUT_PINNED, hit_count=0
```

Because the exact named guard is absent, no source-generation or compile-enqueue
path was attempted. This mission only changed the priority metadata on an
already pending Q02 row.

Immediately before that mutation, five CPU samples averaged `45.8964%` and
peaked at `53.9153%`, below the binding `97%` ceiling.

The machine-readable receipt is
`artifacts/pacer_fx_q02_priority_qm5_11051_20260911.json`.

# QM5_1426 build prerequisite review — 2026-08-22

Task: `61ccc27f-951c-47fc-a8c6-985dcf7da3b4`

Verdict: **RECYCLE / BUILD NOT AUTHORIZED**.

The `qm-build-ea-from-card` prerequisites fail closed:

- No OWNER-authorized Strategy Card exists at
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1426_classical-complex-head-shoulders-h4.md`;
  the routed payload also has `card_id: null`.
- `framework/registry/ea_id_registry.csv` has no allocated current row with
  `ea_id=1426` for this build.
- `framework/registry/magic_numbers.csv` has no current magic allocation for
  `ea_id=1426`.
- The only matching registry slug is a different, retired allocation:
  `ea_id=12192`, status `retired`. It cannot be reinterpreted as allocation 1426.

The existing MQ5 is an explicitly non-trading skeleton (`Strategy_EntrySignal`
returns false and says manual implementation is required), not an implementable
approved card. Its set defaults also violate the current backtest risk contract
(`RISK_PERCENT=0.5` instead of 0), and canonical strict hardening reports:

- D7: direct `QM_FrameworkTrackOpenPositionMae();` hook missing.
- D9: bare `QM_EntryRequest` reaches the canonical consumer uninitialized.

No source, registry, magic, setfile, or binary was changed. No compile or Q02 row
was enqueued. Upstream must supply an approved card and deterministic allocation
before this build can be retried.

# SP-C5 FTMO venue-cost filter dependency gate

Date: 2026-08-22  
Disposition: DEFER — upstream evidence and design authority are not ready

## Decision

SP-C5 cannot be implemented or accepted in this cycle without violating its own constraints.

1. SP-C5 explicitly depends on SP-C4. The SP-C4 audit in `2026-08-22_sp_c4_execution_cost_model_readiness.md` found only one measured symbol in the execution calibration and no measured session, swap, reject, or gap fields. Its disposition is `NOT_READY`; no gate changes were authorized.
2. `framework/registry/live_swap.json` does not exist. The research brief `docs/research/SWAP_RESEARCH_FTMO_DXZ_5PERS_2026-06-09.md` says venue swaps are dynamic and proposes collecting authenticated terminal values before building that registry. Substituting research examples or invented values would violate SP-C5's `keine erfundenen Swap-Werte` constraint.
3. SP-C5 assigns the rejection-criterion design to Claude and implementation to Codex. No Claude-authored, approved rejection specification was supplied with this task. Choosing the comparison basis, holding-period normalization, treatment of unknown swap rows, or rejection threshold here would cross the stated lane split.

## Focused repository checks

- `framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json`: present, but SP-C4 classified it as insufficient for venue-cost admission.
- `framework/registry/live_swap.json`: absent.
- Existing `tools/strategy_farm/portfolio/swap_scenario.py` and its synthetic tests provide swap-reconciliation machinery, but do not provide authenticated current FTMO/DXZ rates or the authorized portfolio rejection policy.
- The current `.DWX` tester evidence uses zero swap in cases documented by the research brief; it cannot prove FTMO-versus-DXZ net drift.

## Required unblock evidence

Before Codex implementation:

1. Complete SP-C4 with representative M1 execution/cost evidence and authenticated venue-specific swap inputs.
2. Publish the intended live-swap registry (including provenance, as-of time, long/short asymmetry, swap mode, conversion basis, and triple-day treatment) without invented values.
3. Supply the Claude-owned rejection specification: exact input population, reconciliation convention, missing-data fail-closed behavior, and the deterministic `negative net drift` predicate.
4. Then implement the portfolio-builder admission filter and prove both rejection and non-rejection paths with fixtures plus an evidence-backed venue example.

No portfolio-builder code or admission criterion was changed in this cycle.

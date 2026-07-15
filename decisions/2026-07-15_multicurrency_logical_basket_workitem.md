# Decision: Multicurrency logical-basket work-item — ratified

- Date: 2026-07-15
- Status: accepted
- Owner: OWNER (ratified in chat, 2026-07-15: "Multicurrency Basket Work-Item aufsetzen, ratifiziert")
- Affected: cross-sectional / rotating multicurrency basket EAs (first: `QM5_10717_edgelab-xsec-fx-momentum`,
  logical symbol `FX8_BASKET_D1`); the process-drift between
  `processes/16-backtest-execution-discipline.md` (per-symbol fan-out) and
  `docs/ops/CROSS_SECTIONAL_BASKET_PIPELINE_DESIGN_2026-05-22.md` + `docs/ops/PIPELINE_PHASE_SPEC.md`
  (logical work item).
- Trigger: Codex multicurrency survey (`docs/research/MULTICURRENCY_STRATEGY_SURVEY_2026-07-15.md`, §5)
  flagged this governance gap; two independent research lanes (Goshawk cross-sectional momentum +
  Codex FX8-XSMOM) converged on cross-sectional momentum as the top frontier candidate.

## Ratification 1 — logical-basket precedence

For cross-sectional / rotating-selection multicurrency basket EAs, the **logical basket work item is
authoritative** and takes precedence over the older per-pair symbol fan-out
(`processes/16-backtest-execution-discipline.md`, which is superseded for this EA class):

- Exactly ONE logical work item per basket EA per phase. `symbol` = the basket's `logical_symbol`
  (e.g. `FX8_BASKET_D1`); the EA attaches to `host_symbol`/`host_timeframe` (EURUSD.DWX / D1) and reads
  the full member set via `CopyRates`. Evidence = combined basket equity, net of all legs + costs.
- Per-pair Q02+ fan-out is FORBIDDEN for these EAs (each isolated per-pair run lacks the cross-section
  needed to rank currencies → the strategy cannot function; the 28 stuck per-pair `pending` Q02 items
  for 10717 from 2026-06-27 are the concrete failure mode and are cancelled by this decision).
- The basket must ship `basket_manifest.json` (logical_symbol, host_symbol, host_timeframe,
  basket_symbols, latest_full_year) and be registered in `multisymbol_eas.txt` (RAM guard: 28-symbol
  loads are the 20–44GB class — test SERIALLY, never several concurrently → launch_fault wedge).

## Ratification 2 — frequency unit for rotating baskets

The Q02 frequency floor (>=5 trades/yr) is measured at the **logical-basket level as basket-rebalance
events that change holdings** — i.e. one "trade" = one rebalance at which >=1 leg is opened or closed —
NOT as the count of individual per-leg deals (which would inflate frequency ~10-28x and make the floor
meaningless), and NOT per-symbol.

- Rationale: a weekly FX8 momentum ranker with ~52 rebalances/yr but few actual composition changes
  could otherwise either trivially pass (leg inflation) or fail (per-symbol undercount). The economic
  unit is the basket decision, so that is the frequency unit.
- Implementation note (follow-up, NOT blocking this ratification): the Q02 verdict currently counts
  trades from the q08 stream, which emits per-leg TRADE_CLOSED events. If the first FX8_BASKET_D1 Q02
  run shows leg-inflated or ambiguous counts, add a basket-rebalance-event counter (group leg deals by
  rebalance timestamp) before enforcing the floor. Observe the first run before coding.

## Concrete setup executed 2026-07-15 (this decision)

- `QM5_10717_edgelab-xsec-fx-momentum` recompiled (stale 2026-06-21 binary carried the raw-symbol
  currency-lookup defect on its JPY/CHF/CAD cross legs — see
  [[project_qm_infra_hardcore_three_causes_2026-07-14]]); fresh binary `d7e901989b6c5c0e`.
- Canonical basket set created: `..._FX8_BASKET_D1_D1_backtest.set` (= EURUSD.DWX host params;
  all 28 per-pair sets were param-identical).
- 28 stuck per-pair Q02 work items → cancelled (status=failed, documented reason).
- ONE logical FX8_BASKET_D1 Q02 work item created (host EURUSD.DWX/D1, manifest-linked).

## Scope / non-goals

- This ratifies GOVERNANCE + sets up 10717's logical work item. It does NOT green-light MC-03 (Value),
  MC-05 (Safe-Haven) or any swap/macro-vintage-dependent family (still blocked pending point-in-time data).
- "Just another FX8 ranker" without lineage reconciliation against 10717/10718 remains disallowed
  (Codex §3). The first run re-benchmarks the EXISTING 10717 lineage under the ratified contract — it is
  not a new build.
- Hard Rules unchanged: no ML, no grid/martingale, DXZ/FTMO DD limits, news blackout, deterministic EA.

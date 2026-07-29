# FTMO Book 3 — v2 producer implementation and remaining setup block

Date: 2026-07-29
Scope: source, governed set files, static tests, documentation
Runtime: none; no MT5 launch, no Factory action, no live mutation

## Outcome

QM5_20181 now produces the parts of the FTMO evidence-v2 contract that the MT5
tester can establish honestly, and explicitly blocks the part it cannot.

- `q08_trades` is rebuilt from the authoritative tester deal history as one
  schema-v2 row per fully closed position. Rows carry a shared run ID, stable
  position and entry/exit deal IDs, profit, swap, all entry/exit commissions,
  zero/non-zero fee accounting, deal-bound component-labelled balance events,
  producer version `QM5_20181_FTMO_TRACE_V2`, and the legacy fields used by Q08
  and the singleton replay comparator.
- `q08_equity` starts with `FTMO_JOINT_TRACE_META` and one
  `FTMO_JOINT_TRACE_POINT`, but that point deliberately carries
  `coverage_complete: false`. The metadata records the actual observation basis
  as `HOST_TICK_PLUS_MODEL_SECOND_TIMER_NOT_EVENT_COMPLETE` and the block reason
  `NON_HOST_SUBSECOND_TICKS_NOT_OBSERVED`.
- The legacy `EQUITY_LOW` / `EQUITY_BAR` diagnostics continue after the setup
  block. They remain useful for fidelity and diagnosis, but they cannot become
  FTMO money evidence by relabelling.
- The evidence run identity is mandatory and exact. The governed rung sets bind
  `FTMO_BOOK3_20260729_V1_J0`, `..._J1`, and `..._J2`. Empty, mismatched, or an
  impossible sleeve combination fails `OnInit`.

This is expected to produce `SETUP_DATA_MISSING` at the money adapter, never a
money-gate PASS. It does not change signals, sizing, order submission, exits,
news handling, or any other trading mechanic.

## Why event-complete MTM is not attested in the EA

The repository's measured MT5 semantics establish all of the following:

1. `OnTick` fires only for the host `USDJPY.DWX` chart.
2. `OnTimer(1)` is deterministic in model time, but has only one-second useful
   resolution.
3. XAUUSD or XTIUSD can move to a lower mark and recover entirely between two
   timer observations.
4. The current callback path therefore cannot prove the minimum account equity
   across every non-host tick in an interval.

The older plan called the residual “bounded to under one second”. Bounded does
not mean admissible: missing a short loss excursion is optimistic for the FTMO
daily- and maximum-loss gates. Setting `coverage_complete: true` would therefore
be a false safety attestation.

Source evidence:

- `docs/ops/evidence/2026-07-27_ontimer_tester_semantics.md`
- `docs/ops/evidence/2026-07-27_multisymbol_timer_ea_plan.md`, sections 5 and 7
- `tools/strategy_farm/portfolio/ftmo_joint_output_adapter.py`

## Trade lifecycle-v2 fail-closed rules

The shutdown producer prepares the full payload before the framework clears its
MAE state, lets the framework close its legacy file handle, and only then
replaces the stream. If preparation fails, the legacy stream remains and the
adapter rejects it.

Publication is refused for any of these conditions:

- a BUY/SELL deal does not belong to an exact configured `(magic, symbol)`;
- a reversal/`DEAL_ENTRY_INOUT` or orphan exit is present;
- a deal has a non-zero fee or non-cent profit/swap/commission;
- a position is still open or entry and exit volumes do not reconcile;
- entry/close time order is invalid;
- more than one exit deal exists. This last restriction preserves the current
  one-row-per-close singleton comparator cardinality; partial-close support must
  version the comparator and producer together.

Balance events are emitted in deal-history order. Every entry emits its
commission event; the exit emits profit, swap, and commission events, including
zero-valued components, so the adapter can reconcile component totals exactly.

## Remaining implementation: external event-complete replay producer

The Money Gate remains blocked until a separate post-test producer is built and
validated. The minimal implementation is:

1. Bind the tester binary, EX5, set, custom-symbol database, all three HCC/TKC
   histories, rulepack, cost files, calendar files, MT5 report, trade stream, and
   raw export files by SHA-256 in one run manifest.
2. Export complete deal and order histories (including millisecond setup/done
   times), exact symbol calculation properties, and all three tick streams for
   the tested window. Refuse gaps, duplicate/non-monotone ticks, foreign account
   events, unsupported calculation modes, or non-USD conversion paths.
3. Merge ticks and account events by `(time_msc, deterministic event order)`;
   replay open positions, pending orders, balance components, accrued swap, and
   per-member floating P&L. Calculate equity at every merged event, not merely at
   hourly endpoints.
4. Emit a contiguous UTC grid of at most 3600 seconds. Each point carries the
   true minimum over the preceding interval, endpoint position/pending state,
   opened-position count, exact member vectors, and Prague-midnight anchors.
   Closed-market gaps may be filled only after proving that all three tick
   streams and the account-event stream are empty for the gap.
5. Reconcile replayed balance/equity against independent MT5 observations at
   every available host/timer checkpoint and at every deal boundary. Any cent
   mismatch or unresolved swap/conversion timing is `SETUP_DATA_INVALID`.
6. Validate spring and autumn Prague DST transitions, sub-second non-host spike
   fixtures, entry/exit commission, swap rollover, server-side SL/TP, partial
   close, pending-order lifecycle, weekend gap, and end-flat conditions before
   the producer may emit `coverage_complete: true`.

Only the external producer may replace the setup-block point. No downstream
adapter relaxation or forward-fill is an acceptable substitute.

## Files and tests

- `framework/include/QM/modules/QM_Mod_FtmoJointTradeV2_20181.mqh`
- `framework/include/QM/modules/QM_Mod_FtmoJointEquitySampler_20180.mqh`
- `framework/EAs/QM5_20181_ftmo-joint-multisym-timer/...mq5`
- the governed J0/J1/J2 set files under that EA's `sets/`
- `tools/strategy_farm/tests/test_qm5_20181_ftmo_evidence_v2_static.py`

The root integration lane owns compile and runtime validation. This source lane
performed no compile, tester run, Factory operation, or live action.

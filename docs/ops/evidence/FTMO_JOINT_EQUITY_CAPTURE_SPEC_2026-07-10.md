# FTMO joint-equity capture specification - 2026-07-10

## Purpose

Provide the synchronized equity data required by
`tools/strategy_farm/portfolio/ftmo_joint_equity.py`. This replaces summed
lifetime trade MAE with the actual joint timing of balance, floating P/L,
commission, and swap changes.

This is an ownership-controlled CTO / Quality-Tech framework change. Development
must not implement it inside `framework/include/QM`.

## Capture contract

Capture is tester-only and opt-in. Live and demo defaults remain disabled.

Required per-sleeve fields:

| field | contract |
|---|---|
| `schema_version` | fixed integer |
| `run_id` | unique immutable baseline run ID |
| `ea_id`, `symbol`, `magic` | exact registry identity |
| `ts_utc_msc` | tester tick time in UTC milliseconds |
| `balance` | account balance after all booked deal costs |
| `equity` | balance plus current floating P/L and swap |
| `open_positions` | count owned by this EA/magic |
| `opened_positions` | number of newly opened positions at this timestamp |
| `event` | `TICK`, `DEAL_BEFORE`, `DEAL_AFTER`, `DAY_ANCHOR`, or `TEST_END_OPEN` |
| `effective_anchor_utc` | exact Prague midnight for `DAY_ANCHOR` |

Emission requirements:

1. Emit every host-symbol tick while an owned position is open. An exact Stage-2
   trace cannot be reconstructed from one lifetime MAE value or EOD snapshots.
2. Emit immediately before and after every owned deal transaction so entry and
   exit commission effects are visible.
3. Emit a Prague `DAY_ANCHOR` for every calendar day. If there is no tick at the
   exact boundary, the first later tick records the exact effective boundary and
   the balance that was in force there.
4. Emit `TEST_END_OPEN` before tester shutdown for every still-open owned
   position, including identifier, entry time, volume, and tracked MAE.
5. Buffer output in bounded chunks. Each flush appends after the first truncate;
   no unbounded MQL string and no per-row file open/close.
6. Set `g_qm_ks_trade` expert magic during kill-switch initialization so its close
   deal remains owned and reaches the normal transaction emitter.

## Provenance sidecar

The runner, not the EA, writes a sidecar containing:

- SHA-256 of `.ex5`, setfile, MT5 report, and trace.
- Model `4`, symbol, timeframe, date window, terminal, and MT5 build.
- Exact `RISK_FIXED`, commission configuration, spread, and stress mode.
- Report trade count, Net Profit, and ending balance.
- `ftmo_stream_reconciliation.py` result.
- Binary and evidence modification timestamps.

Any hash change invalidates the sidecar and all downstream Stage-2 artifacts.

## Validation gates

1. Timestamps strictly increase and carry UTC timezone/milliseconds.
2. Every report exit maps exactly once to a captured deal event.
3. Final captured balance change equals MT5 Net Profit within cent-rounding
   tolerance.
4. Entry plus exit commissions reconcile to the report's commission total.
5. A `DAY_ANCHOR` exists for every Prague date spanned by the trace; spring and
   fall DST transitions are explicit fixtures.
6. While a position is open, no host-symbol tester tick may be absent from the
   captured sequence. Compare captured tick count with a tester-side counter.
7. `TEST_END_OPEN` records pair one-to-one with MT5 `end of test` exits.
8. Missing data, stale hashes, mixed run IDs, or a non-model-4 report produce
   `INVALID`; no imputation is allowed in the decision-grade lane.

## Portfolio combination

The first decision-grade implementation uses an identical UTC grid across all
sleeves. Each sleeve contributes balance/equity delta from its own `$100,000`
tester start; the portfolio starts once at `$100,000` and sums those deltas at
the exact deployed risk.

Forward-filling a lower-resolution M1/EOD sleeve into a tick grid is prohibited.
A future sparse-tick optimization may forward-fill only after proving that every
equity-changing host tick was captured.

The joint vector is block-bootstrapped as a whole. Sleeves must never be sampled
independently because that destroys the observed co-movement the model is meant
to measure.

## FTMO rules evaluated downstream

- 2-Step Phase 1 target `$110,000`; Verification target `$105,000` on a fresh
  account.
- Daily equity floor = Prague-midnight balance minus `$5,000`.
- Static total equity floor = `$90,000`.
- At least four Prague trading days with a position opened.
- Profit target counts only while flat.

Official references:

- `https://ftmo.com/en/trading-objectives/`
- `https://academy.ftmo.com/lesson/maximum-daily-loss/`

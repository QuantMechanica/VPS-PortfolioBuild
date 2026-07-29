# FTMO Book 3 — fail-closed money-evidence adapter

Date: 2026-07-29
Scope: source/tests/documentation only; no MT5 action, no Factory action, no runtime mutation
Book identity: `201810000/USDJPY.DWX`, `201810001/XAUUSD.DWX`, `201810002/XTIUSD.DWX`

## Result

`tools/strategy_farm/portfolio/ftmo_joint_output_adapter.py` is the only
admissible conversion path from joint `q08_trades` + `q08_equity` output into
the normalized trace consumed by `ftmo_rules_engine.py`.

The previous `ftmo_joint_equity.py` remains available only to reproduce old
research. It now returns `LEGACY_RESEARCH_ONLY` instead of `PASS`, always sets
`decision_gate_eligible: false`, and its CLI always exits non-zero. A sparse
trace can therefore no longer bypass this adapter by selecting the old tool.

It has two explicit outcomes:

1. A legacy QM5_20181 stream is rejected with
   `status: SETUP_DATA_MISSING`, `money_gate_eligible: false`, and the exact
   missing-requirement list below.
2. A v2 producer stream is accepted only after exact book membership, one-read
   source hashes, a hash-bound isolated-run receipt, EX5/set/report identities,
   producer version, UTC grid, Prague anchors (including DST), per-member
   position lifecycle, all deal-bound account balance events, floating P&L,
   pending-order state, and all-symbol interval coverage reconcile. A current
   hash-bound official-rules snapshot must also match the arithmetic profile
   implemented by `ftmo_rules_engine.py`. The rules engine then evaluates the
   normalized trace; the adapter does not implement competing FTMO arithmetic
   and does not forward-fill missing intervals.

No successful historical result is a Challenge proof. The artifact always
carries `challenge_proof: false`.

## Read-only finding on the current 20181 output

Observed files:

| stream | SHA-256 | observed legacy event |
|---|---|---|
| `Common/Files/QM/q08_trades/20181_USDJPY_DWX.jsonl` | `c5f57c885728731116f381184b4cca688a00fd88d79a65b6e8a5986adce71e57` | `TRADE_CLOSED` |
| `Common/Files/QM/q08_equity/20181_USDJPY_DWX.jsonl` | `da7cc550912e68bb612065947b4d05f1f8bbe32a5c762bea725582202e029b58` | `EQUITY_LOW` / `EQUITY_BAR` |

The files are useful fidelity evidence, but not complete money evidence. The
adapter rejects them with:

```text
EQUITY_STREAM_META_MISSING
INTERVAL_MIN_EQUITY_MISSING
OPEN_POSITIONS_MISSING
OPENED_POSITIONS_MISSING
PENDING_ORDERS_MISSING
PRAGUE_DAY_ANCHOR_MISSING
ALL_SYMBOL_EVENT_COVERAGE_MISSING
COST_BASIS_ATTESTATION_MISSING
TRADE_SCHEMA_V2_MISSING
TRADE_POSITION_IDENTITY_MISSING
TRADE_BALANCE_EVENTS_MISSING
```

Why this is necessary:

- `EQUITY_LOW` is a running low observed from the host EA callback; it is not an
  interval minimum with proven tick/event completeness for XAUUSD and XTIUSD.
- `day_key` is a broker-day label. It is not an exact Europe/Prague midnight
  anchor contract, and the stream is not a continuous regular UTC grid across
  weekends, holidays, and DST transitions.
- The legacy rows do not expose endpoint open-position counts, position opens
  in the preceding interval, or pending-order state.
- The legacy trade record has no stable position/deal identity. It also cannot
  prove when entry-side and exit-side commissions changed account balance.
- Although legacy `equity`, `balance`, `fl_total`, `profit`, `swap`, and
  `commission` fields exist, their presence alone cannot prove the required
  lifecycle and between-sample accounting identities.

Consequently, no daily-loss, maximum-loss, profit-target, first-passage, or
Monte-Carlo money gate may be marked PASS from the current stream.

## Required producer contract (v2)

This is the exact additional schema needed when the frozen 20181 measurement
source is deliberately reopened. This document does not authorize or perform
that MQL change.

### 1. Equity metadata row

The first `q08_equity` JSONL row must be:

```json
{
  "event": "FTMO_JOINT_TRACE_META",
  "schema_version": 1,
  "q08_trade_schema_version": 2,
  "trace_id": "content-addressed trace identity",
  "run_id": "isolated run identity",
  "producer_version": "QM5_20181_FTMO_TRACE_V2",
  "currency": "USD",
  "grid_seconds": 3600,
  "money_decimals": 2,
  "host_symbol": "USDJPY.DWX",
  "expected_members": [
    {"magic": 201810000, "symbol": "USDJPY.DWX"},
    {"magic": 201810001, "symbol": "XAUUSD.DWX"},
    {"magic": 201810002, "symbol": "XTIUSD.DWX"}
  ],
  "balance_basis": "NET_CLOSED_TRADING_PNL_INCLUDING_COSTS_NO_EXTERNAL_CASHFLOWS",
  "equity_basis": "MARK_TO_MARKET_INCLUDING_OPEN_PNL_SWAP_COMMISSION",
  "opened_positions_basis": "RECONCILED_POSITION_FIRST_OPEN_EVENTS_IN_INTERVAL_(PREVIOUS_TS,TS]",
  "interval_min_equity_basis": "TICK_EVENT_COMPLETE_INTERVAL_MIN_EQUITY_INCLUDING_ENDPOINTS",
  "pending_orders_basis": "RECONCILED_PENDING_ORDER_STATE_AT_ENDPOINT_AND_EVENT_COMPLETE_INTERVAL",
  "coverage_basis": "TICK_EVENT_COMPLETE_ALL_BOOK_SYMBOLS_AND_ACCOUNT_EVENTS",
  "trade_net_basis": "FULL_POSITION_LIFECYCLE_PROFIT_SWAP_AND_ENTRY_EXIT_COMMISSION",
  "floating_basis": "OPEN_POSITION_PROFIT_AND_ACCRUED_SWAP_BY_MAGIC"
}
```

The shared `run_id` is exactly the isolated runner receipt's `work_item_id`; the
same ID and `producer_version` are mandatory on every point and trade row. A
producer cannot know the final stream hashes when it writes start metadata, so
no impossible prospective hash is required. The runner atomically harvests the
closed streams and records their hashes. The adapter reads each harvested stream
exactly once, hashes the same bytes it parses, and requires those hashes and
paths in the expected runner receipt. Its combined fingerprint also binds the
receipt, EX5, setfile, report, producer version, rules snapshot, run ID, and
exact expected membership.

### 2. Regular equity/coverage point

Every remaining equity row must be `FTMO_JOINT_TRACE_POINT` and include:

```json
{
  "event": "FTMO_JOINT_TRACE_POINT",
  "schema_version": 1,
  "trace_id": "content-addressed trace identity",
  "run_id": "isolated run identity",
  "producer_version": "QM5_20181_FTMO_TRACE_V2",
  "interval_sequence": 1,
  "interval_start_utc": 1774652400,
  "interval_end_utc": 1774656000,
  "t_utc": 1774656000,
  "balance": "100000.00",
  "equity": "99980.00",
  "interval_min_equity": "99950.00",
  "open_positions": 1,
  "opened_positions": 1,
  "pending_orders": 0,
  "open_positions_by_member": [
    {"magic": 201810000, "symbol": "USDJPY.DWX", "count": 0},
    {"magic": 201810001, "symbol": "XAUUSD.DWX", "count": 1},
    {"magic": 201810002, "symbol": "XTIUSD.DWX", "count": 0}
  ],
  "opened_positions_by_member": [
    {"magic": 201810000, "symbol": "USDJPY.DWX", "count": 0},
    {"magic": 201810001, "symbol": "XAUUSD.DWX", "count": 1},
    {"magic": 201810002, "symbol": "XTIUSD.DWX", "count": 0}
  ],
  "pending_orders_by_member": [
    {"magic": 201810000, "symbol": "USDJPY.DWX", "count": 0},
    {"magic": 201810001, "symbol": "XAUUSD.DWX", "count": 0},
    {"magic": 201810002, "symbol": "XTIUSD.DWX", "count": 0}
  ],
  "day_anchor": false,
  "coverage_complete": true,
  "covered_magics": [201810000, 201810001, 201810002],
  "covered_symbols": ["USDJPY.DWX", "XAUUSD.DWX", "XTIUSD.DWX"],
  "fl_total": "-20.00",
  "fl": [
    {"magic": 201810000, "symbol": "USDJPY.DWX", "f": "-20.00"},
    {"magic": 201810001, "symbol": "XAUUSD.DWX", "f": "0.00"},
    {"magic": 201810002, "symbol": "XTIUSD.DWX", "f": "0.00"}
  ]
}
```

Required semantics:

- sequence starts at zero; the first interval is zero-width;
- all following intervals are exactly `grid_seconds` and contiguous;
- first and last point are exact 00:00 Europe/Prague boundaries;
- every Prague midnight, including CET/CEST changes, has exactly one anchor;
- `interval_min_equity` is the true minimum across every relevant symbol tick
  and account event in `(interval_start_utc, interval_end_utc]`, including both
  endpoints for comparison purposes;
- `opened_positions` counts reconciled position first-open events in that
  interval; adding another deal to an already-open netting position is not a
  second FTMO Trading Day event;
- `open_positions`, `opened_positions`, and `pending_orders` have complete exact
  `(magic,symbol)` vectors whose sums equal the account totals. Open/opened
  vectors also reconcile to the closed lifecycle set;
- `coverage_complete` may be true only after USDJPY, XAUUSD, XTIUSD and account
  events are complete for the interval; polling only on host ticks is not this
  contract;
- `fl` contains every exact `(magic,symbol)` member once; `sum(fl.f) == fl_total`
  and `balance + fl_total == equity` to account precision.

Missing market intervals must be emitted by a producer that can prove complete
closed-market/account-event coverage. The adapter will not manufacture weekend
or holiday points from adjacent observations.

### 3. q08 trade lifecycle v2

There must be one complete lifecycle row per fully closed position:

```json
{
  "event": "TRADE_CLOSED",
  "schema_version": 2,
  "run_id": "run-book3-001",
  "position_fully_closed": true,
  "position_id": 12345,
  "entry_deal_ids": [30001],
  "exit_deal_ids": [30002],
  "magic": 201810001,
  "symbol": "XAUUSD.DWX",
  "entry_time": 1774654200,
  "time": 1774657800,
  "profit": "102.50",
  "swap": "-1.00",
  "commission": "-4.00",
  "fee": "0.00",
  "net": "97.50",
  "balance_events": [
    {"deal_id": 30001, "time": 1774654200, "component": "COMMISSION", "amount": "-2.00"},
    {"deal_id": 30002, "time": 1774657800, "component": "PROFIT", "amount": "102.50"},
    {"deal_id": 30002, "time": 1774657800, "component": "SWAP", "amount": "-1.00"},
    {"deal_id": 30002, "time": 1774657800, "component": "COMMISSION", "amount": "-2.00"},
    {"deal_id": 30002, "time": 1774657800, "component": "FEE", "amount": "0.00"}
  ]
}
```

The adapter enforces unique position/deal IDs, exact member identity, entry
before close, one or more balance events for every listed deal, every event's
deal membership, and exact `profit + swap + commission + fee == net` and
event-component sums. Exact per-grid-point account-balance reconciliation then
prevents entry commission, exit commission, fees, or swap from disappearing
behind a close-only summary. A genuinely zero fee still requires the explicit
`fee: "0.00"` total; a non-zero fee additionally requires deal-bound `FEE`
events whose sum is exact.

## Required trusted provenance

A v2 stream is not admitted from self-declared JSON alone. The CLI requires
operator-supplied expected SHA-256 anchors and independently verifies:

- an exact `isolated_work_item_runner.py` apply receipt (`schema_version: 1`,
  worker exit 0, the expected work item `done/PASS`);
- the receipt's governed `q08_trades` and `q08_equity` harvested paths and
  hashes against the exact single-read bytes evaluated;
- the receipt preflight's exact staged EX5 and setfile paths/hashes;
- the receipt work item's exact evidence/report path plus the expected report
  hash;
- the expected work-item ID independently against the receipt top level and
  `post_work_item.id`;
- the expected evidence-run ID independently against
  `preflight.work_item.evidence_run_id`, the single
  `qm_evidence_run_id=<id>` setfile binding, metadata, every equity point, and
  every trade row;
- the exact expected producer version in metadata, every equity point, and
  every trade row.

All of those hashes enter the normalized trace fingerprint and the decision
artifact. A computed source hash is therefore no longer mistaken for proof that
the source came from the intended run.

The official-rules receipt is a separate JSON object:

```json
{
  "schema": "qm.ftmo-official-rules-snapshot/v1",
  "retrieved_at_utc": "2026-07-29T12:00:00Z",
  "freshness_max_age_days": 7,
  "sources": [
    {
      "source_id": "ftmo_trading_objectives_official",
      "url": "https://ftmo.com/en/trading-objectives/",
      "http_status": 200,
      "response_bytes": 12345,
      "response_sha256_observation": "<sha256 of observed response bytes>"
    }
  ],
  "normalized_claims": {
    "phase1_profit_target_percent": "10",
    "verification_profit_target_percent": "5",
    "profit_target_operator": "STRICTLY_GREATER_THAN_TARGET_WHILE_FLAT",
    "maximum_daily_loss_percent_of_initial": "5",
    "maximum_daily_loss_reset_timezone": "Europe/Prague",
    "maximum_daily_loss_reset_local_time": "00:00:00",
    "maximum_daily_loss_basis": "MIDNIGHT_BALANCE_MINUS_FIXED_INITIAL_CAPITAL_AMOUNT",
    "maximum_daily_loss_breach_operator": "EQUITY_STRICTLY_BELOW_LIMIT",
    "maximum_loss_percent_of_initial": "10",
    "maximum_loss_model": "STATIC_INITIAL_CAPITAL",
    "maximum_loss_breach_operator": "EQUITY_STRICTLY_BELOW_LIMIT",
    "minimum_trading_days_per_phase": 4,
    "trading_day_qualifier": "AT_LEAST_ONE_POSITION_OPENED_DURING_PRAGUE_LOCAL_DAY",
    "maximum_trading_period_days": null
  }
}
```

The whole snapshot file has its own expected SHA-256. Retrieval in the future,
age greater than seven 24-hour periods, a missing/invalid official-source
observation, or normalized claims that differ from the executing engine yields
setup failure before any money decision. The adapter derives and records the
executing engine-profile hash; an optional snapshot-declared profile hash must
match it. `ftmo_rules_engine.RULES_AS_OF` remains the historical code profile
identifier; freshness comes only from this separately hash-bound snapshot,
never from silently changing that constant.

## FTMO boundary semantics corrected

The current local rulepack says:

- profit/pass balance operator: `STRICTLY_GREATER_THAN_TARGET`;
- Daily and Maximum Loss breach operator: `STRICTLY_BELOW_LIMIT`.

The current official FTMO wording independently uses “exceeds” for the profit
target and “drops below” for the loss limits. Therefore both Python evaluators
now use:

```text
pass target:  balance > target, while flat
loss breach:  equity < applicable floor
```

Equality with USD 110,000 / USD 105,000 is not a pass. Equality with the daily
or maximum-loss floor is not a breach. These are operator corrections, not
threshold changes; tests pin both sides of every boundary.

Official source: <https://ftmo.com/en/trading-objectives/>

## CLI

```powershell
python -m tools.strategy_farm.portfolio.ftmo_joint_output_adapter `
  --trades <harvested-q08-trades.jsonl> `
  --equity <harvested-q08-equity.jsonl> `
  --member 201810000:USDJPY.DWX `
  --member 201810001:XAUUSD.DWX `
  --member 201810002:XTIUSD.DWX `
  --phase PHASE1 `
  --runner-receipt <isolated-run-receipt.json> `
  --expected-runner-receipt-sha256 <sha256> `
  --ex5 <exact-staged-book3.ex5> `
  --expected-ex5-sha256 <sha256> `
  --setfile <exact-book3.set> `
  --expected-setfile-sha256 <sha256> `
  --report <exact-run-evidence-report> `
  --expected-report-sha256 <sha256> `
  --expected-work-item-id <receipt-work-item-id> `
  --expected-evidence-run-id <set-and-stream-evidence-run-id> `
  --expected-producer-version QM5_20181_FTMO_TRACE_V2 `
  --rules-snapshot <current-ftmo-rules-snapshot.json> `
  --expected-rules-snapshot-sha256 <sha256> `
  --out <money-evidence.json> `
  --trace-out <normalized-trace.json>
```

Exit code is zero only for `SCREEN_PASS`; all strategy failures and every setup
or evidence-contract failure return non-zero. Both output paths are mandatory,
must be new and distinct, and may not alias any input. The trace is written
exclusively before a successful decision artifact; `--trace-out` is not written
on inadmissible evidence. This prevents input overwrite, artifact/trace
collision, partial PASS publication, and stale trace reuse.

## Tests

Focused suite:

```text
python -m pytest tools/strategy_farm/tests/test_ftmo_joint_output_adapter.py tools/strategy_farm/tests/test_ftmo_rules_engine.py tools/strategy_farm/tests/test_ftmo_joint_equity.py -q
```

Current focused result: `78 passed`.

Coverage includes the real legacy refusal class, deprecation of the alternate
legacy PASS/Exit-0 route, complete Book-3 identity, spring/autumn Prague DST
anchors, missing intervals, non-host coverage omissions, per-member
position/open-event reconciliation, fee-complete deal-bound entry/exit cost
accounting, account-equity identity, duplicate JSON keys, strict profit/loss
boundaries, single-read source/hash identity, receipt/EX5/set/report/producer
bindings, stale/unbound rules-snapshot refusal, and collision/stale-output CLI
refusal.

# Account / Portfolio Governor Contract

Date: 2026-08-22

Router task: `5c02a347-e91c-44e3-b592-6dad7c6f4d81` (`SP-C1`)

Status: design implemented behind a dry-run-only boundary; not authorized for live execution

## Purpose and safety boundary

The governor reconciles the whole broker account rather than an EA registry.
Every open position and pending order is in scope; magic numbers are retained as
attribution metadata and never act as an inclusion filter. This is necessary
because T1-T10 and T_Live share the account and account-level trade rows can be
mirrors rather than incidents.

The implementation has two deliberately separate parts:

1. `QM_AccountMonitor.mq5` v1.10 is a proposed read-only snapshot producer.
   Its source emits the detailed v2 inventory described below. It contains no
   order-send, order-delete, close, sizing, AutoTrading, or terminal-control
   operation.
2. `account_portfolio_governor.py` is a dry-run-only consumer. It has no apply
   mode and no execution adapter. Every output contains `actions_executed: []`.

The v1.10 monitor source is not compiled or deployed by this change. The live
monitor remains the existing v1 binary until a separate OWNER-authorized ROT
compile/deploy step. Therefore production use of detailed reconciliation is
not claimed by this contract.

## Snapshot producer contract

Schema: `qm.account-monitor.snapshot/v2`

The producer writes one atomic account snapshot on its existing timer cadence.
It includes fresh equity, balance, margin, free margin, account login, producer
time, and the following reconciliation fields:

- `open_positions`, `reconciled_positions`, and the complete `positions` array;
- `pending_orders`, `reconciled_orders`, and the complete `orders` array;
- `reconciliation_complete`, true only when both enumerations remain stable and
  selected row counts match account totals;
- gross and net directional account-currency notional;
- remaining planned loss to actual broker stops;
- explicit unpriced-position and uncovered-stop counts.

Every position row includes ticket, identifier, magic, symbol, side, volume,
open/current price, SL/TP, P&L/swap, broker-reported currencies, and risk
calculation status. Every order row includes ticket, magic, symbol, type,
volume, requested price, and SL/TP.

Enumeration uses `PositionsTotal` / `PositionGetTicket` and `OrdersTotal` /
`OrderGetTicket` directly. There is no magic allowlist. Count drift during a
snapshot makes `reconciliation_complete` false; it is not silently ignored.

## Risk calculations

The producer uses the broker's `OrderCalcProfit` conversion, which returns
account-currency P&L with symbol contract size and conversion rules applied.

- Delta-equivalent notional is measured with a 0.1% positive price probe.
  A BUY produces positive signed notional and a SELL negative signed notional.
- Gross leverage is the sum of absolute account-currency notionals divided by
  current equity.
- Net directional leverage is the absolute sum of signed notionals divided by
  current equity.
- Currency-net buckets assign signed delta-equivalent account value to the
  broker-reported base and profit currencies, then report the largest absolute
  bucket relative to equity. These are account-value risk buckets, not claimed
  native-currency unit balances.
- Planned loss at stop is recomputed from current mark to the actual SL with
  `OrderCalcProfit`. A missing, invalid, or unpriceable stop is uncovered risk;
  no minimum-lot multiplier or synthetic stop is substituted.

The Python consumer independently recomputes the aggregates from position rows
and treats producer/consumer drift as uncertainty.

## Input validity and staged decision contract

Before thresholds are considered, the consumer requires the v2 schema, the
expected account login, an age within the configured freshness window, finite
positive equity and balance, non-negative free margin, `write_ok: true`, unique
ticket inventories, stable count reconciliation, and priceable position risk.

| Level | Trigger | Dry-run plan | Required authority |
|---|---|---|---|
| 0 `CLEAR` | Complete snapshot, valid bound policy, no breach | No action | Hash-bound OWNER policy |
| 1 `ENTRY_FREEZE_*` | Any uncertainty or no valid policy | Freeze new entries only | Fail-closed default; no thresholds invented |
| 2 `PENDING_CANCEL_AND_ENTRY_FREEZE` | A policy threshold is breached | Freeze entries and list every pending ticket that would be cancelled | Valid hash-bound OWNER policy explicitly authorizing stage 2 |
| 3 `CONTROLLED_FLATTEN_AUTHORIZED_DRY_RUN` | Stage 2 plus a separate emergency authorization | Also list every open ticket that would be flattened | Independently hash-bound, time-limited OWNER emergency policy tied to the triggering policy and an incident ID |

Stage 3 cannot be reached with the ordinary policy alone. The emergency policy
must use schema `qm.account-governor.emergency-policy/v1`, identify the account
and incident, be inside its validity window, explicitly authorize flattening,
and bind the exact SHA-256 of the triggering stage-2 policy. Even then, the
current program only reports a plan.

Thresholds are not embedded in the evaluator. Free-margin, gross-leverage,
currency-net, and planned-stop-loss limits are accepted only from a raw-file
SHA-256-bound policy with `status: OWNER_SIGNED` and matching account/validity
fields.

## Equity freshness backstop

`live_book_dd_guard.py` now reads the deployed monitor's timer-driven account
snapshot directly. It requires the expected account login and defaults to a
180-second maximum observation age. It no longer falls back to the
event-driven `live_book_pulse.json` equity value or its former 3,000-minute
tolerance.

This narrowly deployable change uses fields already present in the live v1
snapshot, so it does not depend on the v2 monitor rollout. Its 10% total-DD
threshold, high-water mark, breach latch, signal target, and behavior are
unchanged. Stale, future, invalid, or wrong-account telemetry is logged as
`BLIND`; it is never treated as fresh equity.

## Required gates before any live action

1. OWNER/ROT separately authorizes a governed compile and deployment of the
   v1.10 read-only monitor. No active terminal is manually started or changed.
2. A live v2 snapshot is observed over multiple timer intervals and reconciled
   against the broker account. Any count or aggregate drift blocks progress.
3. OWNER supplies and independently records the exact policy file hash and
   validity window. Until then, the evaluator remains at level 1.
4. Any stage-2 execution adapter is a separate ROT implementation and review;
   none exists here.
5. Any stage-3 incident requires a new, independently signed emergency policy.
   No persistent flatten authorization is permitted.
6. T_Live / AutoTrading state remains outside this component and must never be
   toggled by an agent.

Measured dry-run and scheduler evidence is in
`docs/ops/evidence/2026-08-22_account_portfolio_governor_dry_run.md`.

---
card_schema_version: 2
ea_id: QM5_<allocated-id>
slug: <slug>
status: DRAFT
g0_status: DRAFT
symbol: <SYMBOL.DWX>
timeframe: <M1|M5|M15|M30|H1|H4|H6|H8|D1|W1|MN1>
variant_id: <EXACT_VARIANT_ID>
execution_contract_ref: framework/registry/<registry>.json#ea_id=<id>
execution_contract_status: DRAFT
---

# Strategy title

## Source-defined rules

Only mechanics stated by the approved source. Cite the exact source location for
entry, exit, stop, sizing, timeframe, session and event-calendar rules.

## QM interpretations

Every deterministic threshold or proxy added by QuantMechanica. Each item needs
a variant identifier; an interpretation is not represented as a source claim.

## Framework execution overrides

Declare Friday close, news blackout, forced session flatten, kill-switch ordering
and any other framework exit. Use `none` when there is no override.

## Exit precedence

Ordered list from highest to lowest precedence, including broker SL/TP, calendar
staleness behavior, framework overrides and source-defined exits.

## Runtime data dependencies

Chart timeframe, signal/bar-gate timeframe, additional symbols, tester account
currency, DST policy, calendars and each finite dataset's `valid_through` date.

## Falsification and requalification

State which execution-contract change forces a new binary, stream reconciliation
and portfolio requalification. Unresolved ambiguity must be `BLOCKED`, not filled
in by Development.

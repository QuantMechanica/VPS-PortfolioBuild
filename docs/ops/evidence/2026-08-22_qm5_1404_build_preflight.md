# QM5_1404 build preflight

Date: 2026-08-22  
Router task: `ababc064-ebcd-4fb2-8d93-106cd2d412c0`  
EA: `QM5_1404_as-raa-unemp-canary`  
Procedure: `qm-build-ea-from-card`

## Verdict

`BLOCKED_PRE_FLIGHT` — do not build or compile the current artifact. The legacy
card carries `g0_status: APPROVED`, but it fails the current deterministic card
contract and does not specify the historical economic-data binding needed to
implement its mechanical rule. The checked-in `.mq5` is a no-trade placeholder
and also fails two strict current-build checks. Producing an `.ex5` from it would
not be a faithful Strategy Card implementation.

No EA, setfile, registry, resolver, binary, terminal, or pipeline state was
changed by this review. No compile was attempted.

## Card preflight

Approved runtime card:
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_1404_as-raa-unemp-canary.md`
(SHA-256
`3dbf827437f575303b737537af095ff5f149c70821283f3e4d92ef141a597251`).
The build-folder copy is byte-identical.

Current `farmctl` contract checks returned:

- `strategy_card_r_gate_consistency.ok = false`.
- Body R3 is `UNKNOWN`, while frontmatter `r3_data_available` is `PASS`.
- `_approval_card_contract_issues` reports
  `schema_missing_frontmatter:target_symbols`.
- The legacy frontmatter also remains marked `card_body_incomplete: true` with
  `card_body_missing: source_citation,period`. The current body-coverage parser
  now finds those prose sections, but that does not repair the R3 contradiction
  or missing structured target-symbol field.

The load-bearing rule requires a monthly, one-month-lagged US unemployment
series plus EEM and AGG multi-horizon prices. The card says these require
external data injection, but supplies no governed history artifact, schema,
timestamp/revision policy, file/common-data path, symbol binding, or missing-data
behavior. A read-only search of `D:/QM/data` and the strategy-farm artifacts
found no unemployment/UNRATE/EEM/AGG dataset for this EA. Inventing a transport,
proxy, or static input would change the approved strategy contract.

## Existing build artifact

Source:
`framework/EAs/QM5_1404_as-raa-unemp-canary/QM5_1404_as-raa-unemp-canary.mq5`
(SHA-256
`db2e06ca7aa202559707ce751b8185832343ef140d885ad52be4ece726537433`).

It is not a card implementation:

- Property description is `QM5_1404 Unknown Strategy`.
- `Strategy_EntrySignal` contains an auto-generated TODO and always returns
  `false`.
- Exit logic always returns `false`; no unemployment or canary calculation is
  present.
- No `.ex5` exists.
- Thirteen currently untracked generated setfiles exist, including FX,
  `GDAXI.DWX`, and `UK100.DWX`; the prose card names only `NDX.DWX`,
  `SP500.DWX`, `WS30.DWX`, and `XAUUSD.DWX` as target symbols. These files were
  left untouched.

`build_gate_hardening.py --ea-label QM5_1404_as-raa-unemp-canary` scanned the
source and failed:

1. `EA_Q08_MAE_HOOK_MISSING` — framework-managed `OnTick` has no direct
   `QM_FrameworkTrackOpenPositionMae()` call.
2. `EA_TRADE_REQUEST_UNINITIALIZED` — the bare `QM_EntryRequest` reaches the
   canonical entry consumer without zero-initialization or a complete
   initializer.

The generic guardrail validator passes the 336-hour stale-news ceiling and
fixed-risk setfile values, but that does not override the card-contract and
strict-hardening failures.

## Registry observations

The earlier registry blocker has been repaired independently of this review:

- `ea_id_registry.csv` now has active `1404,as-raa-unemp-canary`.
- `magic_numbers.csv` now has active slots 0–12.

Those allocations satisfy identity and magic prerequisites only. They do not
supply the missing card/data contract or turn the placeholder into a build.

## Required upstream repair

Before Development can resume, an OWNER-governed card repair must:

1. reconcile R3 body/frontmatter and add structured `target_symbols`;
2. bind a durable, historically point-in-time unemployment series and approved
   EEM/AGG proxies, including reporting lag, revisions, timestamps, and
   fail-closed missing-data behavior;
3. state the exact sleeve/proxy behavior for risk-off months and reconcile the
   target symbol set with registry/setfile allocations; and
4. return a complete Strategy Card that can be mapped mechanically without
   guessed filters or inputs.

After that repair, Development should replace the placeholder, run strict
hardening and build checks, and use only the governed compile path. Build PASS
would authorize non-live pipeline handoff only.

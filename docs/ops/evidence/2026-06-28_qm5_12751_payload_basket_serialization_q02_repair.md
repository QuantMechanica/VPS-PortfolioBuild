# QM5_12751 Payload Basket Serialization Q02 Repair - 2026-06-28

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits.

## Decision

The strict 66-pair FX cointegration scan survivors are already handled:
`QM5_12532` and `QM5_12533` both have built basket EAs and are no longer Q02
blocked. The next unbuilt positive-OOS scan pair found in the read-only scan
rerun was `USDCHF.DWX` / `USDCAD.DWX`, but it has no allocated `QM5_` registry
row or magic-number row and only a weak OOS net Sharpe of `0.13`. Per the V5
build rules, no unallocated EA was created.

This pass therefore advanced an existing FX basket already in the funnel:
`QM5_12751` (`EURUSD.DWX` / `EURAUD.DWX`), work item
`0480d11b-9754-4586-b461-e4e677fb58dc`.

## Fault

`QM5_12751` was queued as a logical-basket Q02 item, but it repeatedly returned
to `pending` after sub-second launch faults. Current queue state after the fault
cycle:

| Field | Value |
|---|---|
| Work item | `0480d11b-9754-4586-b461-e4e677fb58dc` |
| EA | `QM5_12751` |
| Logical symbol | `QM5_12751_EURUSD_EURAUD_COINTEGRATION_D1` |
| Status | `pending` |
| Payload scope | `portfolio_scope=basket`, `basket_symbol_count=2` |
| Launch faults | `11` |
| Last fast fault | `0.08` seconds |
| Cooldown until | `2026-06-28T17:27:21+00:00` |

Root cause: `tools/strategy_farm/terminal_worker.py` serialized heavy
multi-symbol Q02 claims only when the EA id appeared in
`D:/QM/strategy_farm/state/multisymbol_eas.txt`. Later EdgeLab basket payloads
already declared durable basket metadata, but the worker ignored those payload
markers. That allowed new payload-declared basket jobs to be treated as ordinary
single-symbol work until the runtime hint file was manually refreshed.

## Repair

Changed `claim_atomic()` so basket detection is payload-authoritative:

- existing runtime hint: `ea_id` in `state/multisymbol_eas.txt`
- durable payload markers: `portfolio_scope=basket`, `basket_manifest`, or
  `basket_symbol_count > 1`

The active-basket gate now scans active work item payloads, and pending Q02
claim selection applies the same helper before memory-headroom and serialization
decisions.

Runtime hint file was also refreshed for currently running workers that have
not reloaded the patched code yet:

`QM5_12624`, `QM5_12712`, `QM5_12723`, `QM5_12728`, `QM5_12731`, `QM5_12732`,
`QM5_12735`, `QM5_12739`, `QM5_12747`, `QM5_12749`, `QM5_12751`.

No duplicate Q02 row was inserted and no manual MT5 backtest was launched. The
single existing `QM5_12751` Q02 row remains pending for paced worker retry after
cooldown.

## Validation

- `python -m unittest tools.strategy_farm.tests.test_terminal_worker_atomic_claim`
  PASS (`20` tests)
- `python -m unittest tools.strategy_farm.tests.test_basket_work_items`
  PASS (`8` tests)

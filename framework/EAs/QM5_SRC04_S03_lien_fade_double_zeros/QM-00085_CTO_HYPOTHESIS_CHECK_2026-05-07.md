# QM-00085 CTO hypothesis check (2026-05-07)

## Scope
- Task: QM5_SRC04_S03 (1009) post-revert zero-trades debug per Research 5ca73c17.
- Checked hypotheses: H1 (deploy/build freshness), H2 (pending-order persistence), H3 (Friday-close cancellation side effects).

## Findings
- H1 runtime verification is blocked in this workspace:
  - `C:/QM/mt5/` contains only `T6_Live`.
  - No `T1..T5` terminals are present here, so `.ex5` mtime/hash parity and deploy-path checks cannot be executed locally.
  - No matching `QM5_SRC04_S03*.ex5` found under accessible MT5 tree.
- H2 static code review (source-level):
  - `HasOurPendingOrder()` returns true only for active `BUY_STOP`/`SELL_STOP` orders with matching symbol and magic.
  - `CancelOurPendingOrders()` exists and is called in `OnDeinit()`.
  - Pending-order stale-state bug is not disproven statically; requires runtime logs/order-lifecycle trace.
- H3 static code review (source-level):
  - Friday close is enabled by default (`qm_friday_close_enabled=true`) and `QM_FrameworkHandleFridayClose()` short-circuits `OnTick()` when active.
  - This can plausibly cancel/avoid staged orders near Friday close windows; runtime replay with Friday close OFF is required to confirm impact.

## Line anchors
- Friday close inputs: mq5 lines 28-30.
- Pending-order guard: mq5 lines 146-161 and 209-211.
- Pending cancel helper: mq5 lines 167-198.
- Friday close short-circuit in tick loop: mq5 lines 408-409.

## Required unblock action
- Owner: Pipeline-Operator / terminal host owner.
- Action:
  1. Provide accessible T1-T5 test terminals for this environment, OR
  2. Run the requested minimal verification backtest externally:
     - Symbol/TF: USDJPY M15
     - Window: 2026-04-01 to 2026-04-30
     - Override: `qm_friday_close_enabled=false`
     - With verbose logs for entry-attempt and pending-order lifecycle.

## Interim conclusion
- No definitive source-level proof yet for H2/H3 as root cause.
- Strong environment signal: deployment/runtime verification path is currently unavailable from this workspace.

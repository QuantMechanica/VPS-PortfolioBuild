# QM5_12821 T-WIN — logical 28-pair basket evaluation fix (2026-07-01)

Scope: branch `agents/board-advisor`; no T_Live, no AutoTrading, no portfolio-gate or
live-manifest edits. OWNER-directed: "T-WIN darf nicht auf einem Symbol bewertet werden,
sondern immer mit den 28 Symbolen, die auch alle geladen werden müssen."

## Root cause
T-WIN (`QM5_12821_twin-csm-basket`) is an 8-currency strength-meter cluster basket over ALL
28 major FX pairs (`QM12821_PAIRS[28]` hardcoded in the EA, `QM_BasketOrder.mqh`, DL-081 1%
basket equity-stop). It was being judged **per-leg** (28 separate single-symbol Q02/Q03/Q04
work_items). That is fundamentally wrong: a single-symbol run cannot compute the cross-sectional
currency strength (it needs all 28 loaded), and per-leg PnL captures only a fragment of the basket.

A `basket_manifest.json` existed (Codex, `logical_symbol=FX8_TWIN_CSM_BASKET_H1`) but was **missing
`host_symbol`** → `farmctl._load_basket_manifest` returns `None` when host_symbol is absent
(farmctl.py:9270) → the EA silently fell back to per-leg. Prior per-leg state: Q02 AUDUSD/EURUSD/
GBPUSD PASS (PF 1.59/1.74/1.69, ~140 tr), Q03 mixed, Q04 INFRA_FAIL (0 trades).

## Fix (matches the 10009 FX-basket pattern)
1. Added `host_symbol: "EURUSD.DWX"` to `framework/EAs/QM5_12821_twin-csm-basket/basket_manifest.json`
   → manifest now validates (`_load_basket_manifest` loads: 28 members, host EURUSD.DWX/H1).
2. Added the logical host setfile
   `sets/QM5_12821_twin-csm-basket_FX8_TWIN_CSM_BASKET_H1_H1_backtest.set` (copy of the EURUSD H1
   backtest set; the basket TP/stop params come from the EA inputs, proven by the per-leg PASSes).
3. Enqueued ONE logical-basket Q02 work_item (id 4fcc2e0c, `symbol=FX8_TWIN_CSM_BASKET_H1`,
   `portfolio_scope=basket`, `basket_symbol_count=28`, `priority_track=true`) via
   `farmctl._basket_q02_payload`.
4. Retired the 35 per-leg work_items → `verdict=SUPERSEDED_BY_LOGICAL_BASKET`.

## Safety
`terminal_worker._work_item_is_multisymbol` treats `portfolio_scope=basket` / `basket_manifest` /
`basket_symbol_count>1` as authoritative (payload markers), so the run is automatically serialized
to ≤1 active farm-wide with extra RAM headroom (no launch_fault from the 28-symbol load) — no
`multisymbol_eas.txt` edit needed.

## Verdict pending
The logical-basket Q02 runs next (priority). **#1 risk stays FX-basket commission** (7 legs ×
~$45/rt) → Q04 net-of-cost is the decisive judge, as the card flags. Files auto-committed by the
pump (8c554e8df); this doc is the governance record.

# Q08/Q11 worst-case commission model — Engineering Spec

**Date:** 2026-06-01 · **Author:** Claude · **Execution:** Codex
**Authority:** OWNER directive 2026-06-01 · **Evidence:**
`docs/ops/DXZ_COMMISSION_RESEARCH_2026-06-01.md` (DXZ) + FTMO research (this doc §Sources)

## OWNER decisions (binding)

1. **Q04 stays a flat $7/lot WORST-CASE screen — UNCHANGED.** Its only job is a
   coarse "is this strategy profitable at all" check. `COMMISSION_PER_LOT_ROUND_TRIP
   = 7.00` in `q04_walkforward.py` and the EA-side sim default stay as they are.
   **Gate-0 (DL-064) stays as-is.** Do NOT touch the Q04 path.
2. **Q08 (and the Q11 portfolio cost rule) use the realistic commission = the
   per-asset WORST CASE of {Darwinex Zero, FTMO}.** Deliberately conservative;
   refinable later if OWNER pulls the official DXZ per-asset table.
3. **Notional plumbing = the clean path:** the EA emits `notional` per closed
   trade; **the fleet is recompiled.** No approximation as the long-term answer.

## The worst-case model (round-trip, in account currency USD)

Sourced figures (cited §Sources). FX: DXZ ≈ 0.005% of notional RT (≈ $5 / EURUSD
lot); FTMO $5/lot flat RT. Indices: DXZ ≈ 5.5 / contract RT; FTMO commission-free.
Metals/commodities: both ≈ 0.005% of notional RT.

Per trade, the engine computes **`cost_rt = max(pct_rate_rt × notional_acct,
flat_per_lot_rt × volume)`** using a per-asset-class rate pair:

| Class | `pct_rate_rt` | `flat_per_lot_rt` | Rationale (worst of DXZ/FTMO) |
|---|---|---|---|
| `forex` | 0.00005 | 5.00 | DXZ %-notional vs FTMO $5/lot — `max` |
| `index` | 0.00005 | 5.50 | DXZ ~5.5/contract; FTMO $0 → DXZ dominates; pct kept as conservative floor |
| `commodity` | 0.00005 | 0.00 | both firms %-notional |

`notional_acct` = `volume × contract_size × close_price`, converted to account
currency. **This is why the EA must emit `notional`.** The figures are conservative
bounds from public research, not the account-gated table — that is intentional
(worst-case) and documented, satisfying the "no invented commission values" Hard
Rule via explicit, cited, conservative sourcing.

## Deliverables

### 1. Commission registry — `framework/registry/live_commission.json`
```json
{
  "_authority": "OWNER 2026-06-01 worst-case-of {DXZ, FTMO}; evidence docs/ops/DXZ_COMMISSION_RESEARCH_2026-06-01.md + Q08_Q11_WORSTCASE_COMMISSION_SPEC_2026-06-01.md",
  "model": "max(pct_rate_rt*notional_acct, flat_per_lot_rt*volume)",
  "account_currency": "USD",
  "classes": {
    "forex":     {"pct_rate_rt": 0.00005, "flat_per_lot_rt": 5.00},
    "index":     {"pct_rate_rt": 0.00005, "flat_per_lot_rt": 5.50},
    "commodity": {"pct_rate_rt": 0.00005, "flat_per_lot_rt": 0.00}
  },
  "symbol_class": {
    "EURUSD.DWX":"forex","GBPUSD.DWX":"forex","AUDUSD.DWX":"forex","USDCHF.DWX":"forex","USDJPY.DWX":"forex",
    "NDX.DWX":"index","SP500.DWX":"index","WS30.DWX":"index","GDAXI.DWX":"index",
    "XAUUSD.DWX":"commodity"
  },
  "default_class": "forex"
}
```
Codex completes `symbol_class` from the live symbol universe (read
`framework/registry/` / the DWX symbol list). Unknown symbol → `default_class`
with a logged warning.

### 2. Worst-case cost engine — `tools/strategy_farm/portfolio/commission.py`
- `class CommissionModel` loaded from the registry.
- `cost_round_trip(symbol: str, volume: float, notional_acct: float|None) -> float`
  returns `max(pct_rate_rt*notional, flat_per_lot_rt*volume)`. If `notional_acct`
  is None (legacy stream without notional), fall back to `flat_per_lot_rt*volume`
  only AND set a `degraded=True` flag the caller must surface in its artifact
  (so %-notional symbols are never silently under-costed on legacy data).
- Pure stdlib. Unit test `tests/test_commission.py`: forex max-logic (flat wins
  for small notional, pct wins for large), index uses 5.5 flat, commodity pure
  pct, legacy-None path flags degraded.

### 3. EA-side notional emission + fleet recompile
- In `framework/include/QM/QM_Common.mqh`, extend the `TRADE_CLOSED` JSONL event
  (the q08_trades stream) to include **`notional`** = `DEAL_VOLUME × contract_size
  × close_price` in account currency, plus **`symbol`** for robustness. Keep all
  existing fields (`net,profit,swap,commission,volume,time`) unchanged — additive
  only.
- Recompile the fleet via `framework/scripts/compile_one.ps1` (syncs include →
  terminal, then metaeditor). Verify on ≥1 EA that a fresh Q08 run emits `notional`.
- This is MT5-in-the-loop; runs in the factory (OWNER RDP session, Factory ON).
  Do NOT start `terminal64.exe` manually.

### 4. Q08 wiring — `framework/scripts/q08_davey/aggregate.py`
- Apply `commission.cost_round_trip(...)` per trade to derive net-of-realistic-cost
  P&L BEFORE the Davey sub-gates compute (PF, DD, etc.). Use emitted `notional`;
  if absent, the engine's degraded fallback applies and the verdict artifact MUST
  record `commission_basis: "worst_case_dxz_ftmo"` and `degraded_symbols: [...]`.

### 5. Q11 portfolio cost rule (corrects the held Task A)
- Replace the flat `net - 7*volume` rule in the Q11 spec with
  `commission.cost_round_trip(symbol, volume, notional)`. `portfolio_common.py`
  imports the engine. Same degraded-flag discipline.

## Sequencing
- **Task D** (registry + engine, §1–2): actionable now, foundation.
- **Task E** (EA notional emission + recompile, §3): parallel to D, MT5-in-the-loop.
- **Task F** (Q08 wiring, §4): BLOCKED on D.
- **Q11 Task A** (`3bf6a3df`, currently HOLD): cost rule re-pointed to the engine
  (§5); Claude unblocks after D lands (exact at full accuracy once E's notional flows).

## Out of scope
- Q04 / Gate-0 (unchanged, OWNER-decided).
- Official DXZ account table (OWNER will not supply now; worst-case stands).

## Sources (FTMO)
- FTMO — *Zero Commissions on Indices* https://ftmo.com/en/blog/zero-commissions-on-indices/
- FTMO — *Symbols* https://ftmo.com/en/symbols/
- FXEmpire — *FTMO Prop Firm Review 2026* https://www.fxempire.com/prop-firms/ftmo
(DXZ sources in `DXZ_COMMISSION_RESEARCH_2026-06-01.md`.)

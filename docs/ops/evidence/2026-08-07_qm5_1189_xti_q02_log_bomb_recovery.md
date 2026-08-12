# QM5_1189 XTI Q02 log-bomb recovery

## Outcome

`QM5_1189_qp-oil-posshock-pullback` was repaired without changing its approved
D1 positive-shock reversal mechanic. The current binary is compiled and bound
to one fresh `XTIUSD.DWX` Q02 work item:

- work item: `60b428c9-b31b-499e-a4be-1050b7d27f94`
- state at handoff: `pending`
- symbol / period: `XTIUSD.DWX` / `D1`
- risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`

This was the highest-value available priority-2 unit after the remaining
diversity build candidates were found blocked by unavailable DWX inputs. The
card is G0-approved with R1-R4 PASS and source lineage
`7ede58dd-d184-5099-9d48-7a65de230853` (Quantpedia). Its edge is structural,
short-only daily reversal after a positive return shock in a high-volatility
regime; it contains no ML, grid, martingale, or pyramiding.

## Coordination claim

The repair was claimed atomically in the canonical farm database before any
edit:

- agent task: `74afdc5d-7b5c-440a-b4a8-e0ea0d07a88c`
- claim key:
  `codex:agents/board-advisor:QM5_1189:XTIUSD.DWX:q02-log-bomb:20260807T101613Z`
- database backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_1189_xti_claim_20260807T101613Z.sqlite`

The claim transaction rechecked that no XTI Q02 row was pending or active and
that the bound failure row was terminal `INFRA_FAIL` before inserting the
claim. Unrelated working-tree edits were not touched.

## Bound failure and root cause

The terminal-bound Q02 row
`feafc996-df0a-4c3b-9598-54ae99f8080f` recorded:

- verdict: `INFRA_FAIL / LOG_BOMB`
- old EX5 SHA-256:
  `a5723906d06219e1019cb91a798a959eff2d8076084a83b076546dc8024476c0`
- journal size: `14.8 GB` against a `4 GB` cap
- retained report: `1,164` D1 bars, `133,793,281` real ticks, `0` trades

`XTIUSD.DWX` has validated D1 history in the DWX registry. By contrast,
`XBRUSD.DWX` is absent from `dwx_symbol_matrix.csv` and is explicitly recorded
as an availability gap in `venue_cost_model.json`.

The EA treated the preferred WTI route and alternate Brent route as if both
were mandatory basket legs. `Strategy_NoTradeFilter()` called
`Strategy_SelectSymbols()` on every XTI tick. The failed selection of the
unavailable Brent alternate therefore did two things simultaneously: it
returned no-trade for XTI and caused MetaTrader to emit an unknown-symbol
journal stream on every tick. That explains both zero trades and the 14.8 GB
log bomb.

## Repair

- Initialization now validates and selects only the active chart symbol.
- The no-trade filter no longer performs symbol selection per tick.
- XTI and XBR remain independently supported card routes with their existing
  magic slots; no universe, entry threshold, stop, sizing, or exit parameter
  changed.
- Strategy series work and the D1 hold exit are now behind the existing
  `QM_IsNewBar()` gate. This is behavior-preserving because the EA has no
  intrabar management and its D1 hold state changes only at a new daily bar.
- Setfile generation refreshed build-hash comments only. Backtest inputs remain
  fixed risk.

## Verification

- strict compile: PASS, `0` errors, `0` warnings
  - `C:/QM/repo/framework/build/compile/20260807_102043/QM5_1189_qp-oil-posshock-pullback.compile.log`
- framework build check: PASS, `0` failures, `0` warnings
  - `D:/QM/reports/framework/21/build_check_20260807_102042.json`
- build guardrails: PASS, no findings, six files checked
- current MQ5 SHA-256:
  `f7a24a04e69aa158b73183e0cc8b0fc0356e22b3535cec022b7c9a2da8d621c5`
- current EX5 SHA-256:
  `49187b3afc856ee54f9a0817990404de612b69a75c15e8a8277600c371d0af3c`
- XTI backtest set SHA-256:
  `8079fd5a40bfc176ce7220e665b6f72454bf0f52f68730c04a025c441328f070`

## Governed Q02 handoff

At `2026-08-07T12:23:52+02:00`, `farmctl.py mt5-slots` reported nine of ten
factory terminals running and `T2` free. The backtest CPU ceiling had not been
reached, so `farmctl.py seed-fresh-q02` created exactly one current-binary XTI
row. The helper used terminal pre-binding source row
`e0431b97-9f3d-4911-8a74-a15d821fbf96`, preserved every historical result,
and recorded the later bound log-bomb row in the requalification reason.

The stale `XBRUSD.DWX` pending row was not altered or duplicated. No tester was
launched manually. No `T_Live`, AutoTrading setting, deploy manifest,
portfolio gate, or live manifest was touched.

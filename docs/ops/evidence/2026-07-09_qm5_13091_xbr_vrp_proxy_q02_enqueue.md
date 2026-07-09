# QM5_13091 XBR VRP Proxy Q02 Enqueue

Date: 2026-07-09
Actor: codex-headless-board-advisor
Branch: agents/board-advisor

## Context

- Mission target: add one non-duplicate commodity/energy sleeve that is structurally different from the existing index, metal, and XNG book.
- Selected edge: `xbr-vrp-proxy`, a Brent `XBRUSD.DWX` daily realized-volatility-regime stretch-reversion proxy.
- Source lineage: `TROLLE-SCHWARTZ-ENERGY-VRP-2008` plus BIS commodity risk-premia support.
- Non-duplicate rationale: this is Brent realized-volatility proxy logic, not the existing XTI/XNG VRP proxies, Brent calendar/weekday/TOM/TSMOM/anchor/reversal variants, WTI event/calendar/inventory variants, XTI/XNG, oil-metal, XNG, index, or commodity-RSI logic.

## Changes

- Reserved `QM5_13091` for `xbr-vrp-proxy`.
- Added approved strategy card:
  `strategy-seeds/cards/approved/QM5_13091_xbr-vrp-proxy_card.md`.
- Added EA:
  `framework/EAs/QM5_13091_xbr-vrp-proxy/QM5_13091_xbr-vrp-proxy.mq5`.
- Added RISK_FIXED backtest setfile:
  `framework/EAs/QM5_13091_xbr-vrp-proxy/sets/QM5_13091_xbr-vrp-proxy_XBRUSD.DWX_D1_backtest.set`.
- Added registry and magic mappings for `QM5_13091` / `XBRUSD.DWX`.

## Validation

- `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_13091_xbr-vrp-proxy/QM5_13091_xbr-vrp-proxy.mq5 -Strict`
  - PASS, 0 errors, 0 warnings
  - `.ex5`: `framework/EAs/QM5_13091_xbr-vrp-proxy/QM5_13091_xbr-vrp-proxy.ex5`
- `framework/scripts/build_check.ps1 -EALabel QM5_13091_xbr-vrp-proxy`
  - PASS, 0 failures, 0 warnings
  - Report: `D:/QM/reports/framework/21/build_check_20260709_125420.json`
- Backtest setfile guardrails:
  - `symbol: XBRUSD.DWX`
  - `qm_ea_id=13091`
  - `RISK_FIXED=1000`
  - `RISK_PERCENT=0`
  - `PORTFOLIO_WEIGHT=1`

## Queue Action

Command:

```powershell
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_13091 --queue-ceiling 10000 --max-part2-per-run 0
```

Result:

- `part1 never_tested: enqueued=1 skipped=0`
- Work item: `a385c479-3482-4c72-9869-f31acce2f81d`
- Phase: `Q02`
- Status: `pending`
- Symbol: `XBRUSD.DWX`
- Evidence JSON: `D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`

## Guardrails

- No `T_Live` files or manifest touched.
- No AutoTrading changes.
- No portfolio admission gate files touched.
- No MT5 live dispatch was launched; Q02 was enqueued and left pending for the normal farm dispatcher.

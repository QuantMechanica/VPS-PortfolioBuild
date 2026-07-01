# QM5_12866 Brent April Premium - Q02 Enqueue Evidence

Date: 2026-07-02
Operator: Codex
Branch: `agents/board-advisor`

## Scope

Built one new structural commodity/energy sleeve:

- EA: `QM5_12866_brent-apr-prem`
- Symbol/timeframe: `XBRUSD.DWX` D1
- Edge: broker-calendar April Brent long-only calendar premium
- Source: Arendas, P., Tkacova, D. and Bukoven, J. (2018), "Seasonal patterns
  in oil prices and their implications for investors", Journal of International
  Studies, 11(2), 180-192, DOI 10.14254/2071-8330.2018/11-2/12,
  https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf

## Non-Duplicate Rationale

This build is Brent April exposure. It is distinct from `QM5_12727_wti-apr-prem`
(WTI benchmark), existing Brent weekday cards, Brent May/November/December
calendar cards, Brent TSMOM/anchor logic, WTI/Brent paired-spread logic, XTI/XNG,
XNG, XAU/XAG, gas-metal, and commodity RSI sleeves.

## Build Validation

- Card schema lint: PASS
- SPEC validation: PASS
- Symbol scope: SINGLE_SYMBOL_OK
- Build guardrails: PASS
- Compile: COMPILED, 0 errors, 0 warnings
- Strict build check: PASS, 0 failures, 16 shared-framework DWX advisory warnings
- Build check report: `D:\QM\reports\framework\21\build_check_20260701_234015.json`
- Build result artifact: `artifacts/qm5_12866_build_result.json`

## Q02 Queue

- Work item: `347cc5d0-ac86-4b99-b959-b680da56d49e`
- Queue DB: `D:\QM\strategy_farm\state\farm_state.sqlite`
- Phase: Q02
- Status after enqueue: pending
- Setfile: `framework/EAs/QM5_12866_brent-apr-prem/sets/QM5_12866_brent-apr-prem_XBRUSD.DWX_D1_backtest.set`
- Risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`

## Safety

No manual MT5 backtest was launched from this session. No `T_Live`, AutoTrading,
portfolio gate, or live manifest file was touched.

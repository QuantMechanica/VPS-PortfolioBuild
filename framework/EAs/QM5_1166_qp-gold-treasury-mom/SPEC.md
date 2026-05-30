# QM5_1166_qp-gold-treasury-mom

## Source Card

- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1166_qp-gold-treasury-mom.md`
- Status: APPROVED
- Build scope: V5 EA build only; no backtests or pipeline phases.

## Strategy Mapping

- Universe: `XAUUSD.DWX` only.
- Frequency: D1 chart, evaluated at the first D1 bar after month end.
- Entry: open/maintain long when both XAUUSD 12-month return and local Treasury-proxy 12-month return are strictly positive.
- Exit: close at the first D1 bar after month end when either return is non-positive or the Treasury proxy is unavailable/stale.
- Stop: hard ATR stop, default `5.0 * ATR(20)` on D1.
- Sizing: V5 risk contract. Backtest setfiles use `RISK_FIXED=1000`; live setfile uses `RISK_PERCENT=0.25`.

## Data Contract

The Treasury signal reads a deterministic local CSV from `strategy_treasury_csv_path`, default `IEF_total_return.csv`.

Expected CSV shape:

```text
date,total_return
YYYY-MM-DD,123.45
```

The file may be placed in the terminal Files directory or the common Files directory. The EA does not call web APIs. If the file is missing, malformed, stale, or lacks enough lookback history, the strategy emits no new entry signal and exits existing exposure on monthly rebalance.

## Framework Alignment

- No-Trade: symbol, timeframe, slot, trading status, parameter and spread guards.
- Entry: monthly joint momentum long signal.
- Management: no trailing, break-even, scale-out, or pyramiding beyond the fixed ATR stop.
- Close: monthly signal flip or missing/stale Treasury proxy.
- Magic: `QM_Magic(1166, 0)` via registry and resolver.

## Validation

Required:

```powershell
framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_1166_qp-gold-treasury-mom/QM5_1166_qp-gold-treasury-mom.mq5 -Strict
framework/scripts/build_check.ps1 -EALabel QM5_1166_qp-gold-treasury-mom -Strict
```

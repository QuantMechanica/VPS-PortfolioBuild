# Quantpedia Composite Stress SP500 Rebound

Local build copy of APPROVED card `QM5_1194_qp-stress-spx-composite`.

## Mechanics

On each completed D1 bar:

1. Compute close-to-close returns for `SP500.DWX`, `XAUUSD.DWX`, approved oil proxy, and deterministic Treasury proxy CSV.
2. Create three confirmations:
   - equity plus gold stress
   - equity plus oil stress
   - Treasury risk stress
3. If at least two confirmations are true, open long `SP500.DWX`.
4. Exit at the next D1 close, with a safety exit after two trading days.
5. Initial stop is 1.5x ATR(20) D1.

## Caveat

Runtime and backtest require the local Treasury proxy file `IEF_total_return.csv`. `SP500.DWX` remains a T6 live-promotion caveat and needs later parallel validation on a broker-routable proxy such as `NDX.DWX` or `WS30.DWX`.

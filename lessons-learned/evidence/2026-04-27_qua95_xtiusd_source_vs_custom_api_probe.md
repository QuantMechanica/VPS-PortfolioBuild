# 2026-04-27 - QUA-95 XTIUSD source-vs-custom API probe

Issue: `QUA-95`  
Symbol pair: `XTIUSD.DWX` (custom) vs `XTIUSD` (source)

## Command

```powershell
@'
import MetaTrader5 as mt5
import datetime as dt
symbols=['XTIUSD.DWX','XTIUSD']
if not mt5.initialize(path=r'D:\QM\mt5\T1\terminal64.exe', portable=True):
    print('init_failed', mt5.last_error()); raise SystemExit(2)
try:
    now=dt.datetime.utcnow()
    lo=now-dt.timedelta(days=2)
    for sym in symbols:
        mt5.symbol_select(sym, True)
        r=mt5.copy_rates_range(sym, mt5.TIMEFRAME_M1, lo, now)
        rc=0 if r is None else len(r)
        re=mt5.last_error()
        p=mt5.copy_rates_from_pos(sym, mt5.TIMEFRAME_M1, 0, 10)
        pc=0 if p is None else len(p)
        pe=mt5.last_error()
        t=mt5.copy_ticks_from(sym, int(now.timestamp())-600, 200, mt5.COPY_TICKS_ALL)
        tc=0 if t is None else len(t)
        te=mt5.last_error()
        print(f'{sym} rates_range_2d={rc} err={re}; rates_from_pos={pc} err={pe}; ticks_from_10m={tc} err={te}')
finally:
    mt5.shutdown()
'@ | python -
```

## Result

```text
XTIUSD.DWX rates_range_2d=0 err=(1, 'Success'); rates_from_pos=0 err=(-1, 'Terminal: Call failed'); ticks_from_10m=0 err=(1, 'Success')
XTIUSD rates_range_2d=257 err=(1, 'Success'); rates_from_pos=10 err=(1, 'Success'); ticks_from_10m=200 err=(1, 'Success')
```

## Interpretation

- Source symbol (`XTIUSD`) has readable M1 bars and ticks in the same terminal/session.
- Custom symbol (`XTIUSD.DWX`) fails on bars APIs (`range` and `from_pos`) even when source works.
- This narrows the failure scope to custom-symbol/runtime visibility (and verifier behavior over that state), not broker-source feed unavailability.

## Blocker impact

- `QUA-95` remains blocked.
- Unblock owner A: custom-symbol/runtime owner (restore M1 bar visibility for `XTIUSD.DWX` in T1).
- Unblock owner B: verifier implementation owner (`verify_import.py`) to harden diagnostics/fallback once symbol visibility is restored.

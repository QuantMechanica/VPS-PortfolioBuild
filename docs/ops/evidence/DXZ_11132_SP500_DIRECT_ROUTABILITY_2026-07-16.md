# DXZ 11132 SP500 direct-routability evidence

Date: 2026-07-16  
Evidence capture: 2026-07-16T08:28:34Z  
Scope: read-only inspection of `T_Live`; no terminal, EA, preset, order, or AutoTrading change

## Finding

The Darwinex-Live broker symbol `SP500` is order-routable. `SP500.DWX` is the
custom test-data symbol and must not itself be sent to the broker. The explicit
execution mapping is:

| Purpose | Exact symbol |
|---|---|
| Backtest and requalification data | `SP500.DWX` |
| Darwinex Zero live order | `SP500` |

This supersedes the 2026-05-16 assertion that the broker routes no orders on
`SP500`. An NDX/WS30 substitution is not required to solve SP500 routing. Such
a port remains optional derivative research and would need its own Strategy
Card, EA identity, and qualification.

## Local evidence bindings

| Read-only source | Bytes | Last write UTC | SHA-256 |
|---|---:|---|---|
| `C:\QM\mt5\T_Live\MT5_Base\logs\20260629.log` | 5,408 | 2026-06-29T21:12:53.3969810Z | `595bdee06807a8ccc01c44e9a251e5d0e5c1c30808e1e94adf90678c43a91e50` |
| `C:\QM\mt5\T_Live\MT5_Base\logs\20260630.log` | 6,784 | 2026-06-30T19:00:50.6827975Z | `63028cb2050e5f7334fe6031a4d300013a887e03499cc0efa4c2ddf20cc7ca64` |
| `C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\QM5_11132_ea-11132.log` | 36,365 | 2026-07-15T22:00:00.7924857Z | `c0d7fe6546c0758087012a74ebb0f524121e97f8682ed532713d72b9ec3a179a` |
| `C:\QM\mt5\T_Live\MT5_Base\Bases\Darwinex-Live\history\SP500\2025.hcc` | 14,233,830 | 2026-07-13T06:06:43.1471428Z | `0d9fd3545a5f33b2c1c8d1933ad1859cc5a9cdb1170c6102bb349dc9fb3918f9` |
| `C:\QM\mt5\T_Live\MT5_Base\Bases\Darwinex-Live\history\SP500\2026.hcc` | 11,689,029 | 2026-07-15T22:00:32.9869397Z | not claimed: the live terminal held an exclusive file lock during capture |

The locked 2026 history file is supplementary freshness evidence only. No hash
is invented or inferred for it. The accepted broker orders below are the
decisive routability evidence.

## Exact MT5 terminal-log evidence

`logs/20260629.log`:

```text
1:NN	0	00:00:01.938	Trades	'4000090541': market buy 0.34 SP500 sl: 7144.7
2:LE	0	00:00:02.004	Trades	'4000090541': accepted market buy 0.34 SP500 sl: 7144.7
4:OE	0	00:00:02.065	Trades	'4000090541': order #3162533174 buy 0.34 / 0.34 SP500 at market done in 128.974 ms
5:KK	0	00:00:02.070	Trades	'4000090541': deal #145900211 buy 0.34 SP500 at 7360.7 done (based on order #3162533174)
```

`logs/20260630.log`:

```text
1:MP	0	00:00:00.983	Trades	'4000090541': market sell 0.34 SP500, close #3162533174 buy 0.34 SP500 7360.7
2:NG	0	00:00:01.223	Trades	'4000090541': accepted market sell 0.34 SP500, close #3162533174 buy 0.34 SP500 7360.7
4:NG	0	00:00:01.318	Trades	'4000090541': order #3162770806 sell 0.34 / 0.34 SP500 at market done in 338.953 ms
5:NH	0	00:00:01.331	Trades	'4000090541': deal #146054123 sell 0.34 SP500 at 7449.1 done (based on order #3162770806)
```

## Exact EA-log correlation

`MQL5/Files/QM/QM5_11132_ea-11132.log`:

```json
{"ts_utc":"2026-06-28T09:12:45.281Z","ts_broker":"2026-06-26T23:42:33","level":"INFO","ea_id":11132,"slug":"ea-11132","symbol":"SP500","tf":"D1","magic":111320000,"event":"SYMBOL_GUARD_INIT","payload":{"mode":"single","symbol":"SP500"}}
{"ts_utc":"2026-06-28T22:00:02.828Z","ts_broker":"2026-06-29T01:00:02","level":"INFO","ea_id":11132,"slug":"ea-11132","symbol":"SP500","tf":"D1","magic":111320000,"event":"ENTRY_ACCEPTED","payload":{"ticket":3162533174,"symbol":"SP500","type":"QM_BUY","lots":0.34000000,"price":7360.00000000,"sl":7144.70000000,"tp":0.00000000,"magic":111320000,"reason":"TM_CUM_RSI2_LONG","symbol_slot":0,"retcode":10009}}
{"ts_utc":"2026-06-29T22:00:01.609Z","ts_broker":"2026-06-30T01:00:02","level":"INFO","ea_id":11132,"slug":"ea-11132","symbol":"SP500","tf":"D1","magic":111320000,"event":"TM_CLOSE","payload":{"ticket":3162533174,"symbol":"SP500","lots":0.34000000,"reason":"QM_EXIT_STRATEGY","partial":false,"ok":true,"retcode":10009,"retcode_class":"BROKER_OTHER"}}
{"ts_utc":"2026-07-15T22:00:00.484Z","ts_broker":"2026-07-16T01:00:03","level":"INFO","ea_id":11132,"slug":"ea-11132","symbol":"SP500","tf":"D1","magic":111320000,"event":"EQUITY_SNAPSHOT","payload":{"day_key":20260715,"month_key":202607,"equity":101403.68,"day_pnl":11.35,"month_pnl":58.41,"atr_regime":"normal","symbol":"SP500"}}
```

The entry and close share ticket `3162533174`; both EA events report successful
broker retcode `10009`, and the terminal log independently records the accepted
orders and resulting deals on exact symbol `SP500`.

## Official corroboration

Darwinex's current instrument page lists `SP500` as its S&P 500 index CFD. The
Darwinex Zero comparison page states that Zero has the same CFD categories,
including indices. These pages corroborate availability; the account-specific
MT5 order/deal evidence above proves the exact broker ticker was routed.

- [Darwinex: assets available](https://help.darwinex.com/assets-available)
- [Darwinex Zero versus Darwinex Classic](https://www.darwinexzero.com/docs/en/darwinex-zero-versus-darwinex-classic)

## Governance disposition

`QM5_11132_tm-cum-rsi2` remains `BLOCKED`, but not for SP500 non-routability.
The independent open gates are:

1. full requalification of the explicit `SP500.DWX` -> `SP500` mapping;
2. Friday-close override not qualified by the Strategy Card;
3. source exit semantics require Card-v2 migration;
4. remediated binary not requalified.

No Card was approved, no EA or live preset/binary was edited, no deployment was
performed, and AutoTrading was not changed.

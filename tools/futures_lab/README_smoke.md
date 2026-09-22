# Isolated futures data and accounting smoke

Run with the separately installed, hash-locked Windows Python 3.11 environment:

```powershell
& 'D:/QM/venvs/futures_lab/Scripts/python.exe' 'D:/QM/worktrees/codex-futures-pivot-20260922/tools/futures_lab/smoke_nautilus.py' --fetch
```

After the two fixtures exist, omit `--fetch` for a fully offline run. Existing files
are checked against the committed size and SHA-256 manifest, never silently
replaced. The allowlist contains two official release-tag URLs, totalling 54,362
compressed bytes. No API keys, registrations, brokerage or live node are used.

The command makes two repeated passes through these independent scenarios:

1. Decode the ESM3 instrument fixture: two definitions, USD multiplier 50,
   price increment 0.25. This definition is **not** relabelled as ESH4.
2. Feed the actual ESH4 MBO fixture into the existing Nautilus `BacktestEngine`
   with an L3 book and a passive observer. The file has 8,725 deltas but only one
   timestamp. It is a snapshot, not a historical session. No orders are placed.
3. On a separate engine, a deliberately synthetic constant bid/ask tape drives
   one market buy and one market sell. Expected loss is one ES tick ($12.50)
   plus artificial $1 fees per side: $14.50. Actual engine fills and account
   balance must match. This is an accounting test, not a strategy backtest.

Repeated results must have identical event/fill hashes. Output is
`D:/QM/reports/research/futures_pivot_20260922/nautilus_smoke/result.json`.

ESH4 uses manually constructed, explicitly labelled test metadata. The activation
date is a lab bound, not an exchange definition. The pinned upstream
`TestInstrumentProvider.es_future()` helper uses multiplier 1; this smoke uses
50 explicitly. Production ingestion must use the appropriate real definitions.

This validates decoder/engine wiring, deterministic replay, side-correct basic
market fills, fees and dollar accounting. It does not validate MES/MNQ data,
sessions, DST, rollovers, passive queue position, latency, slippage, prop rules,
historical trading performance or any source strategy. Zero engine latency and
synthetic fees are declared assumptions. The report contains no profit metric.

Sources:

- [Pinned Databento loader tests](https://github.com/nautechsystems/nautilus_trader/blob/v1.221.0/tests/integration_tests/adapters/databento/test_loaders.py)
- [Pinned Databento integration](https://github.com/nautechsystems/nautilus_trader/blob/v1.221.0/docs/integrations/databento.md)
- [Official fixture directory](https://github.com/nautechsystems/nautilus_trader/tree/v1.221.0/tests/test_data/databento)
- [Pinned helper with test-only instrument metadata](https://github.com/nautechsystems/nautilus_trader/blob/v1.221.0/nautilus_trader/test_kit/providers.py)
- [CME contract sizes](https://www.cmegroup.com/articles/faqs/frequently-asked-questions-micro-e-mini-equity-index-futures.html)

No third-party example strategy is executed. Script and manifest were prepared
under `OWNER-DEC-FUTURES-PROP-PREPARATION-20260922`; no live permission is implied.

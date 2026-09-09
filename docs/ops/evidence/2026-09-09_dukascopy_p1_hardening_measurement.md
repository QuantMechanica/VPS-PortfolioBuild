# Dukascopy P1 downloader hardening and N=300 measurement — 2026-09-09

Task: `f6d18a6e-0170-47c7-bbfd-e1b33d9d01c8`  
Decision: `OWNER-DEC-DUKASCOPY-BACKFILL-20260829`  
Disposition: **PROCEED with resumable scheduled batches; no proxy/different egress required by this sample.**

## Implementation

`tools/dukascopy/download_bi5.py` now provides:

- bounded concurrent fetching (`--concurrency`, default 6) under one shared
  5-10 request/s limiter;
- a thread-local `requests.Session` per worker for HTTP keep-alive reuse;
- standard `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` passthrough by default,
  with explicit `--no-proxy-env` opt-out (no proxy variables were set for this run);
- per-hour exponential retry backoff with independent jitter and configurable
  base/cap;
- append-only `hour_ledger.jsonl` outcomes (`done` or `failed`) alongside the
  checksum-authenticated download manifest; successful/no-data rows resume
  without another request, while failed rows remain retryable;
- `--measure N`, which bounds network work to exactly N planned hour-files and
  reports success rate, effective successful hours/minute, and projected wall
  time without authorizing or performing any terminal import.

The executor keeps at most `concurrency` futures live rather than materializing
the 300k-row workload as futures. The existing canonical symbol validation,
closed-hour planning, bi5 structural inspection, atomic file writes, hashes,
and `production_import: false` receipt remain in force.

## Command and bounded scope

```text
python tools/dukascopy/download_bi5.py \
  --out D:/QM/reports/dukascopy/measurement/20260909T191100Z_p1_hardened_n300 \
  --splice-csv D:/QM/reports/dukascopy/splice/20260909_010553/tick_tail.csv \
  --rate 5 --timeout 15 --retries 5 --concurrency 6 \
  --measure 300 --projection-hours 304621 \
  --backoff-base 1 --backoff-cap 8
```

The source was the public Dukascopy bi5 endpoint. This was a fresh measurement
root, not the signed 2017-2025 archive and not the interrupted production root.

## Result

| Metric | Result |
|---|---:|
| Requested / completed sample | 300 / 300 hour-files |
| Resolved (`downloaded` + legitimate `no_data`) | 296 |
| Downloaded | 201 |
| Legitimate no-data | 95 |
| Failed after all 5 attempts | 4 |
| Success rate | **98.6667%** |
| Elapsed wall time | **185.706939 s** |
| Effective successful throughput | **95.634552 hour-files/min** |
| Fixed projection target | 304,621 hour-files |
| Projected wall time | **191,115.654 s = 53.0877 h = 2.21199 days** |

Attempt distribution was 292 rows at attempt 1, one at attempt 2, two at
attempt 3, one at attempt 4, and four exhausted at attempt 5. The four failures
were retained as retryable ledger rows: two read timeouts, one connect timeout,
and one connection reset. They do not masquerade as no-data or success.

This reverses the prior straight-line 167-day estimate for the hardened run
shape. The sample supports **PROCEED**, using resumable scheduled batches and
normal monitoring. A proxy/different egress is not presently justified; revisit
that recommendation only if larger scheduled batches materially fall below the
measured rate.

## Durable receipts

Root: `D:\QM\reports\dukascopy\measurement\20260909T191100Z_p1_hardened_n300`

| Artifact | SHA-256 |
|---|---|
| `download_receipt.json` | `7cb621bf443ed818be8a1c801b07db4c03f22fa953499f5e4018cf01b8d710db` |
| `download_manifest.jsonl` (300 rows) | `cfe32a0d19e2dfa1e2673b0f0ae6115c850d66a6c9e9f0ea4941cf4b35087ef9` |
| `hour_ledger.jsonl` (300 rows) | `9b4e5dbf86bdaf34953e45b769cf57c401ce7e22922281975e5cbadae38af5d7` |
| `progress.json` | `81335bd3e6c0cf8397d6246c7e9fb2899e4a016965afeb8aa355a020621f2da5` |

The measurement wrote 201 raw bi5 files totaling 2,392,486 bytes only beneath
the measurement root.

## Verification and exclusions

Focused regression suite:

```text
python -m pytest tools/dukascopy/tests/test_dukascopy_backfill.py \
  tools/dukascopy/tests/test_download_bi5_hardening.py \
  tools/strategy_farm/tests/test_dwx_tick_tail_probe.py -q
32 passed
```

Coverage includes jittered retry, bounded concurrency, N-bounded measurement,
done-only resume, failed-only retry, ledger state, and the unchanged legacy
download/conversion/reconciliation paths.

No terminal process was started, stopped, or signaled. No MT5 history was
imported or mutated. No factory action, T1 import, T_Live access, AutoTrading
change, signed-archive change, verdict change, threshold change, or live-account
action occurred.

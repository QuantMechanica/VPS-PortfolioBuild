# Dukascopy backfill — P0 inventory and fail-closed boundary

Task: `bd73130a-2cbb-42fc-93b5-7529a4f5849f`; OWNER receipt #5.

## Completed in this single-pass cycle

The canonical history-range builder ran against `D:\QM\mt5` and `framework/registry/dwx_symbol_matrix.csv`. It found all **37 symbols**, skipped none, and emitted **703 symbol/derived-period rows**:

- `docs/ops/evidence/2026-09-02_dukascopy_p0_history_ranges.csv`
- `docs/ops/evidence/2026-09-02_dukascopy_p0_history_ranges.json`

The governed import components asserted by the plan do exist at `D:\QM\mt5\T1\dwx_import\prepare_import.py`, `...\verify_import.py`, and `D:\QM\mt5\T1\MQL5\Services\Import_DWX_Queue_Service.ex5`.

## Fail-closed boundary

P0 is not complete enough to authorize downloads or splicing: the range builder reports HCC year coverage, not the **last genuine tick timestamp per symbol**. The old TDM staging CSV directory is empty, and the repository has no read-only TKC-tail decoder. Obtaining the authoritative tick tail through MetaTrader would require a governed T1 probe/claim; this cycle may not manually start a terminal or interrupt factory work. Guessing “~2026-04-06” for 37 splice points would violate the plan's append-only per-symbol requirement.

Consequently P1–P4 were not started. In particular, no multi-hour downloader was detached from this headless single-pass task; no network corpus was accepted without splice anchors; no source reconciliation was bypassed; no import job was queued; no mutable 2026 history, signed 2017–2025 archive, T_Live file, or terminal process was touched.

## Required continuation

Add a governed read-only T1 tick-tail probe (or schedule the existing MQL/MT5 diagnostic under a factory claim) that writes all 37 exact last-tick milliseconds. Then P1 may download overlap plus gaps, P2 may convert, P3 may gate each symbol on M1 p95/session/DST-zero reconciliation, and only PASS symbols may enter the existing T1 import queue. This task's advertised 3–5 day / 6–12 hour download duration cannot truthfully be completed inside one scheduler single-pass invocation without a resumable worker service.

Verdict: **PARTIAL_P0 / BLOCKED_BEFORE_SPLICE**. This is a safety stop, not a completed backfill.

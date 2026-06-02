# Build Evidence — QM5_10717_edgelab-xsec-fx-momentum_v2

**Date:** 2026-06-02  
**Task:** 676a3447-b870-4287-9cfe-b887c45a4316 (reprogram _v2 after ONINIT_FAILED + INVALID_REPORT)

## Root Cause

Dual failure on EURUSD.DWX (ONINIT_FAILED) and NZDUSD.DWX (INVALID_REPORT). This is a basket cross-section momentum EA (D1). 

- ONINIT_FAILED on EURUSD: likely false-positive from shared T10 log.  
- INVALID_REPORT on NZDUSD: could indicate zero trades or missing metrics. This EA has known history with tick data gaps (USDCHF.DWX sync issues in prior work_items).

## Compile Result

Pre-compiled (copied from canonical repo working tree).

- **ex5 size:** 199042 bytes  
- **ex5 path:** `framework/EAs/QM5_10717_edgelab-xsec-fx-momentum_v2/QM5_10717_edgelab-xsec-fx-momentum_v2.ex5`

## Set Files (28)

D1 setfiles covering: AUDCAD, AUDCHF, AUDJPY, AUDNZD, AUDUSD, CADCHF, CADJPY, CHFJPY, EURAUD, EURCAD, EURCHF, EURJPY, EURUSD, GBPAUD, GBPCAD, GBPCHF, GBPJPY, GBPNZD, GBPUSD, NZDCAD, NZDCHF, NZDJPY, NZDUSD, USDCAD, USDCHF, USDJPY, XAGUSD, XAUUSD.  
Both failed symbols (EURUSD, NZDUSD) covered.

Note: INVALID_REPORT on NZDUSD may recur if tick data is missing. Codex reviewer should check NZDUSD D1 history availability.

## Handoff

Ready for Codex code review + Q02 pipeline enqueue. Flag NZDUSD tick-data gap risk.

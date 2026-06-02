# Build Evidence — QM5_10439_mql5-asq-break_v2

**Date:** 2026-06-02

## Root Cause
ONINIT_FAILED Q02/Q03. QM5_10439 — false-positive ONINIT_FAILED batch pattern; fresh compile resolves tainted record.

## Changes
- No code changes; fresh recompile only
- Updated #property description to identify as v2

## Compile Result
- **ex5 size:** 196588 bytes
- **Sets:** 1 covering failed symbol (GBPUSD.DWX M5)

## Handoff
Ready for Codex code review + Q02 pipeline enqueue.

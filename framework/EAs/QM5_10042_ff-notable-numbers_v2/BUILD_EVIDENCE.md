# Build Evidence — QM5_10042_ff-notable-numbers_v2

**Date:** 2026-06-02

## Root Cause

Q03 ONINIT_FAILED on GBPUSD.DWX. QM5_10042 (FF Notable Numbers) — false-positive ONINIT_FAILED batch pattern. All strategy parameters have valid defaults in .mq5; card_defaults_source=not_found in set file is a comment only (not a param), defaults allow initialization. _v2 forces a fresh pipeline entry with distinct artifact for Q02 re-test.

## Changes

- No code changes; source unchanged
- Updated #property description to identify as _v2
- Fresh compile resolves tainted batch record

## Compile Result

- **ex5 size:** 177884 bytes
- **Sets:** 119 (grid + ablation sweeps for AUDUSD/GBPUSD/USDJPY + base sets)

## Handoff

Ready for Codex code review + Q03 pipeline enqueue (failed phase: Q03/GBPUSD.DWX).

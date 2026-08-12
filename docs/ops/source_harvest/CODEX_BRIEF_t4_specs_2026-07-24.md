# Codex brief — Tranche 4 independent specs (STR-016, STR-024, STR-027)

Same protocol as tranches 2/3: INDEPENDENT specs from ONLY 00_source.md +
SOURCE_LEDGER.csv row. Do NOT read 01_spec_claude.md / 03_* / 04_* / prior
QM5 EA sources.

1. docs/ops/source_harvest/strategies/STR-016-asian-range-breakout/00_source.md
   (Asian-range straddle; NOTE the thread's GMT+3-server-time correction and
   the internally inconsistent order-deletion time — reason explicitly)
2. docs/ops/source_harvest/strategies/STR-024-144ema-displaced-breakout/00_source.md
   (M5 displaced-EMA breach; the author posts TWO variants — pick and justify
   the baseline; symbols are NOT source-stated — reason your cohort)
3. docs/ops/source_harvest/strategies/STR-027-vr-gap-fade/00_source.md
   (bar-open gap fade with DELAYED SL/TP attach — mind the house rule that
   positions must never be unprotected; MinGapSize/SL have NO source
   defaults — propose and flag)

Deliver: D:\QM\reports\source_harvest_build\02_spec_codex_STR-016.md / -024 /
-027. Same content requirements as before (mechanized rules, inputs,
state/restart, 5-hook mapping, ambiguity table with verbatim quotes,
compliance flags). Read-only; specs only.

# Codex brief — Tranche 3 independent specs (STR-008, STR-009, STR-012)

Same protocol as tranche 2 (brief CODEX_BRIEF_tranche2_specs_2026-07-24.md):
INDEPENDENT specs from ONLY 00_source.md + the SOURCE_LEDGER.csv row. Do NOT
read 01_spec_claude.md / 03_* / 04_* / prior QM5 EA sources.

1. docs/ops/source_harvest/strategies/STR-008-notable-number-fade/00_source.md
   (FX M5 fade at "notable number" price lattice; per-symbol source-fixed
   setups; NOTE the thread's 2023-06-23 edit: entries checked on M5 bar
   openings only)
2. docs/ops/source_harvest/strategies/STR-009-notable-number-breakout/00_source.md
   (same thread, the CADJPY "reverse setup" continuation)
3. docs/ops/source_harvest/strategies/STR-012-daily-wick-asymmetry-breakout/00_source.md
   (D1 stop-order breakout, direction by previous-candle wick asymmetry;
   exact 12-point EA restatement in post #1)

Deliver: D:\QM\reports\source_harvest_build\02_spec_codex_STR-008.md / -009 /
-012. Same content requirements as tranche 2 (mechanized rules, inputs,
state/restart, 5-hook mapping, ambiguity table with verbatim quotes,
compliance flags). Pay specific attention to:
- STR-008/009: mechanize the named sessions ("Sydney/Tokyo/London/NY",
  "London +2h" clock) — state your time-basis reasoning explicitly;
  mechanize "price reaches the level" under the M5-openings constraint;
  level-lattice definition for 2/3-digit notable numbers; per-symbol
  parameter transport (one EA + per-symbol set files vs per-symbol builds) —
  recommend one.
- STR-012: pending-order lifecycle at day roll (the source MQ4's behaviour is
  underspecified); the unstated PipsAboveHigh/PipsBelowLow defaults; SL
  anchoring (level-based, not fill-based) implications.
Constraints: read-only, specs only, no code/builds/DB writes.

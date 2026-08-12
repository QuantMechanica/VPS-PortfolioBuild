# Codex brief — Tranche 2 independent specs (STR-002, STR-003, STR-004)

Task: write an INDEPENDENT implementation spec for each of the three
strategies below. Basis: ONLY the verbatim source extract (00_source.md) and
the SOURCE_LEDGER.csv row. **Do NOT read 01_spec_claude.md, 03_*, 04_* or any
QM5_2009x/201xx EA sources — independence is the point** (two blind specs get
diffed afterwards).

For each: docs/ops/source_harvest/strategies/<dir>/00_source.md
1. STR-002-simplicity-ha-100ema-london  (FX H1: EURUSD/GBPUSD/USDCHF/USDJPY)
2. STR-003-previous-day-breakout-edge   (FX H1: EURUSD/GBPUSD)
3. STR-004-daylight-wpr-ma-trend        (Indices M15: NDX/GDAXI)

Per strategy deliver `D:\QM\reports\source_harvest_build\02_spec_codex_STR-00X.md`:
- Entry/exit/SL/TP/session/day-anchor rules, mechanized (every qualitative
  source phrase → an explicit deterministic rule; flag each such mechanization
  decision).
- Inputs with defaults (source-faithful; no invented parameters beyond what
  mechanization strictly requires).
- State/restart-safety, closed-bar discipline (shifts >=1), V5 5-hook mapping
  (Strategy_NoTradeFilter TRUE=block / EntrySignal / ManageOpenPosition /
  ExitSignal / NewsFilterHook; framework owns risk/news/Friday/KS).
- Ambiguities: list verbatim quote -> your interpretation.
- Compliance notes (magic, RISK_FIXED/PERCENT, per-trade cap 1%, no
  martingale/grid; source rules that VIOLATE house rules must be flagged, not
  silently adapted).
Constraints: read-only; no code, no builds, no DB writes. Specs only.

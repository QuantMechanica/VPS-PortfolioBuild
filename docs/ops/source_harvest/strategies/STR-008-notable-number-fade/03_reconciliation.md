# STR-008 — Spec reconciliation (claude 01 vs codex 02), 2026-07-24

## Convergent
M5 signal clock per the thread's 2023-06-23 correction; broker-D1 shifts 1..N
one-side gate with STRICT inequality; percent-OF-PRICE TP/SL (codex proved it
via the source's own pip conversions); no session-end liquidation (deliberate
difference vs QM5_10042's invented exit; 10042 also ran M15, died Q03/Q04);
one EA + per-symbol source-fixed set files; suffix-lattice on pip-normalized
integers (2-4 digits, JPY-safe); one position per symbol.

## Conflicts and resolutions
1. **Session clock.** Codex: civil city time with historical IANA DST
   (unimplementable in MQL5 without inventing a DST database — hard-rule
   conflict). Claude: broker-time hours. DECISIVE ARGUMENT: codex's own
   decomposition of "(London +2h)" — London civil +2h ≡ UTC+2 winter / UTC+3
   summer ≡ EXACTLY the NY-close broker clock year-round. The author ran MT5
   on such a broker; his named windows were observed on that clock. RESOLVED
   → ALL windows in literal BROKER hours (tie-breaks 1+3): London+2h windows
   = literal broker 14-22/15-18/17-20; named sessions fixed broker hours:
   Sydney 00:00-09:00, Tokyo open 02:00, London open 10:00 / close 19:00,
   NY open 15:00. EURUSD window = 11:00-16:00, USDCAD = 09:00-11:00,
   GBPUSD = 00:00-09:00, EURGBP = 02:00-09:00, AUDUSD = 02:00-19:00 broker.
   Tokyo/Sydney JST/AEST drift ±1h across broker DST documented, not modeled.
2. **Trigger semantics.** Claude: intrabar touch of prior bar. Codex:
   OPEN-to-OPEN crossing (only consecutive M5 opens count; gaps admitted;
   first level in travel direction on multi-level gaps). RESOLVED → codex
   (tie-break 1: "checked on M5 bars openings ONLY" verbatim; also matches
   the author's at-level entry prints).
3. **Re-entry.** Codex one-fire-per-(D1-day, direction, level) latch.
   RESOLVED → codex (claude's hysteresis idea dropped; latch is stricter and
   parameter-free).
4. **USDJPY cohort membership.** Codex keeps (source-faithful). Claude
   excludes: 15 deals/11yr ≈ 1.4/yr violates the OWNER-ratified Q02
   frequency floor (>=5/yr = RETIRE) — building a guaranteed-RETIRE symbol
   wastes factory throughput. RESOLVED → claude (tie-break 2, binding house
   economics rule). Cohort = 8 symbols; USDJPY documented as excluded row.
5. **State.** Codex's durable-state persistence → fleet convention: derive
   from replay/positions/deal history, no files (tie-break 3).
6. Hook placement: session/exposure/latch checks in EntrySignal (fleet
   convention), NoTradeFilter only for warmup/params/handles.

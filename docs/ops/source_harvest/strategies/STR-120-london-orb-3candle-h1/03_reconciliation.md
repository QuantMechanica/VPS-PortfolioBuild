# STR-120 — Spec reconciliation (Claude 01 vs Codex 02)

Date: 2026-07-25. Tie-breaks per tranche protocol.

## Agreements

H1; range = the 3 completed H1 bars before 08:00 UK-local (wicks
included), UK-DST-aware; first CLOSE strictly beyond a border after the
open → market entry next tick (wick-only ≠ signal); SL at the opposite
border; TP = 1.5R from fill; ONE trade per UK date, no re-entry after
any outcome ("I don't reenter", #68); no trailing/BE/partials; no
range-size or buffer filters (the author's "ridiculous range" and
"clearly outside" judgments are discretionary — excluded, FLAG-120-02/
03); date consumed on the first qualifying close even if the order is
gate-rejected (FLAG-120-06).

## Resolved differences

1. **Cohort.** Claude: the six posted pairs. Codex FLAG-120-05: the
   author later "dropped the 2 USD pairs" — VERIFIED verbatim
   (00_source.md:420). Primary = the retained four (EURGBP, EURUSD,
   GBPJPY, GBPUSD .DWX); six-pair = labeled variant → **codex
   adopted**.
2. **US-close cutoff.** Claude: 16:45 NY-local input (provisional).
   Codex FLAG-120-01: no value may be invented; reconciliation must
   select. RESOLUTION: 16:45 America/New_York — grounded in the
   author's own routine (post #1: he closes residual trades at his
   6:45 AM AEST morning check, which is 16:45 ET the prior day, i.e.
   "just before the US market closes" = before the 17:00 ET NY close).
   Not an invented constant but the author's own schedule mechanized;
   FLAGGED interpretation, input-exposed.
3. **Mid-range stop (#64).** Codex FLAG-120-04: ad-hoc deviation, not
   a rule → opposite-border stop retained. Agreed.

## Outcome

Final spec = codex 02 with the cutoff resolved to 16:45 ET and the
retained-4 cohort. No escalation.

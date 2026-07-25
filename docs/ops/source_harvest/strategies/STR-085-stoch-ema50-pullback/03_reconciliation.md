# STR-085 — Spec reconciliation (Claude 01 vs Codex 02)

Date: 2026-07-25. Sources of authority: 00_source.md verbatim text;
tie-breaks per the tranche protocol (1 source-verbatim, 2 risk→more
restrictive, 3 conservative/testable, 4 escalate+continue).

## Agreements (adopted without contest)

- Stoch(5,3,3, Close/Close) cross on closed bar b1 vs b2; EMA50 close;
  H4 canonical; slope = sign(EMA[1]−EMA[2]), flat = skip; entry next
  bar market; TP = 3R fixed; trailing distance = R, ratchet-only,
  never widen; one position per magic/symbol; no time/opposite-cross
  exits, no spread veto (unsourced — both specs exclude the QM5_10017
  additions per the G0_REVIEW_T6 contest deltas).

## Resolved differences

1. **Zone condition.** Claude: D[1] ≤ 20 only (flagged). Codex I-01:
   BOTH K[1] and D[1] in-zone. No verbatim answer ("crossovers that
   occur at or below 20"). Tie-break 3: both-lines is stricter and
   reproducible → **codex adopted**.
2. **Stop anchor.** Claude: min(Low[1],Low[2]) − 10 pips (flagged).
   Codex I-04: Low[1] − 10 pips (the just-closed signal bar IS the
   "previous" bar at next-bar execution). Tie-break 1 (closest to
   verbatim "previous low") → **codex adopted**.
3. **Cohort.** Claude: EURUSD/GBPUSD only. Codex: + XAUUSD/XAGUSD
   secondary. VERIFIED in source (00_source.md line 34: scanner covers
   "28 currency pairs plus Gold and Silver") → **codex adopted**:
   FX cohort EURUSD.DWX/GBPUSD.DWX + metal cohort XAUUSD.DWX/
   XAGUSD.DWX, evaluated per symbol as usual.
4. **Trail activation.** Claude "once profitable" vs codex "from entry,
   ratchet-only" — behaviorally identical (candidate ≤ initial SL until
   profitable); codex wording is the implementable one → adopted.

## Outcome

Final spec = codex 02 structure with the above confirmations; no
escalation needed. Claude's D-only zone and two-bar stop anchor are
retired (documented here, not variants).

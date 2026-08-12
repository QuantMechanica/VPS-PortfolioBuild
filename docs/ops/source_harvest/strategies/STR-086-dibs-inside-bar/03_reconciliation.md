# STR-086 — Spec reconciliation (Claude 01 vs Codex 02)

Date: 2026-07-25. Tie-breaks per tranche protocol.

## Agreements

- 06:00 UTC daily anchor via QM_BrokerToUTC (both; Peter: "0600GMT is
  always 0600GMT", ±1h DST immaterial); H1 canonical; inclusive
  inside-bar definition (High[1] ≤ High[2] AND Low[1] ≥ Low[2]);
  direction gate = trigger side vs frozen dayOpen; stop = other side of
  the IB; half out at 1R; initial stop NOT moved at the partial
  (verbatim); one live position per magic; no bar-count pending expiry;
  JPY-00:00-anchor and sub-H1 = variants only; cohort EURUSD.DWX/
  GBPUSD.DWX (non-JPY).

## Resolved differences

1. **Straddling IB.** Claude: skip (flagged open question). Codex I-07:
   trade whichever side breaks → OCO pair. VERIFIED verbatim
   (00_source.md line 81-82: "Then you take the break that occurs") →
   **codex adopted**; Claude's skip reading retired.
2. **Consecutive IBs.** Claude: unaddressed. Codex: first (largest) of
   a run only. VERIFIED verbatim (line 85) → **codex adopted**.
3. **Spread handling.** Claude: symmetric 1-pip offsets. Codex: long
   trigger and short initial stop carry + setupSpread. Source risk
   formula "IB-range + 2 + spread" (line 67) + MT5 semantics: buy stops
   trigger on ASK, charts are Bid — placing the long trigger at
   ib.high + 1 pip + spread makes the BID break the IB top by ~1 pip
   before entry, which is the source's intent. Sell side triggers on
   Bid natively (no adjustment). Tie-breaks 1+2 → **codex adopted**.
4. **Setup window.** Claude: none. Codex I-03: entries only for IBs
   closing ≤ 9h after the anchor (6/10 variants). Source: "trading
   during the active hours is key"; "first 6-9 hours" — a tendency
   statement, not a prohibition. Tie-break 2 (more restrictive) →
   **codex adopted**, FLAGGED as bounded projection (Q03 sweepable).
5. **Runner management.** Claude: initial stop only, no TP (trailing =
   discretionary variant). Codex: MA20 closed-bar ratchet trail.
   VERIFIED sourced (line 578: "I will use the 20 period moving
   average (displayed) as a trailing stop") — but the worked example
   sits on a DAILY chart; mapping MA20 to the H1 execution TF is an
   interpretation. Resolution: **codex baseline adopted** (H1 MA20
   ratchet, closed-bar, tighten-only) with the TF mapping FLAGGED;
   initial-stop-only = labeled source-supported variant.
6. **Re-entry.** Both one-position; codex rule 18 (fresh setup after a
   completed exit, inside the window, no auto-reverse) is the cleaner
   statement → adopted.

## Outcome

Final spec = codex 02 with the daily→H1 MA-mapping flag added. No
escalation needed. Netted partial-close machinery per QM5_20101/20098
precedent (initial-volume tracking + once-latch + retry pacing).

# STR-118 — Spec reconciliation (Claude 01 vs Codex 02)

Date: 2026-07-25. Tie-breaks per tranche protocol.

## Agreements

D1; Ichimoku(9,26,65) baseline (author's walk-forward claim, flagged
unverified; 52/100 = the only labeled variants, no broad sweep);
ATR(20) Wilder ("20 moving average of the ATR" — both read it as
ATR(20)); STATE entry (no fresh-cross requirement): long when
Tenkan[1] > Kijun[1] AND Close[1] > cloudTop[1] + 1×ATR (cloudTop =
max(SpanA, SpanB) causally aligned; short mirror below min − ATR);
exit on the opposite Tenkan/Kijun cross at the next bar; no Chikou;
NO scale-in (the author's 3-lot ATR add-on = stacking, house-banned);
AUD pairs excluded (author-reported); no TP; equality = no entry.

## Resolved differences

1. **Cloud buffer causality.** Claude: iIchimoku buffers at shift 1
   (assumed plot-aligned). Codex: manual 27-bar-back calculation OR
   native buffers only with a proven offset test. Resolution: native
   iIchimoku Senkou buffers at shift 1 PLUS a one-time OnInit
   self-test against the manual midpoint calculation (log + INIT_FAIL
   on mismatch) → **merged**; cheap and definitive.
2. **Initial protective stop** (both agree none is sourced; house
   projection required for V5 sizing). Claude: 4×ATR(20) catastrophic
   (QM5_20127 precedent). Codex: FROZEN signal-bar near cloud edge
   (structure-anchored; "back into the cloud = thesis dead") + rule-11
   re-arm lock. With the re-arm lock, entries occur only shortly after
   the state first turns true, so the cloud-edge distance stays near
   its 1×ATR minimum → the cloud edge is the tighter, more principled
   single projection → **codex adopted** (labeled house projection,
   InitialStopMode=FROZEN_SIGNAL_CLOUD_EDGE; gap-invalid geometry →
   skip trade).
3. **Post-stop re-arm lock.** Codex rule 11 (after a protective-stop
   close, that direction stays locked until the entry state goes false
   then true again) — prevents stop/re-entry loops inside one unchanged
   state → **codex adopted** (flagged I-07 house projection).
4. **Cohort.** Claude: USDJPY+EURUSD. Codex: the author's "4 Majors"
   (EURUSD/GBPUSD/USDJPY/USDCHF, I-01 declared interpretation).
   USDCHF.DWX history verified present. Tie-break 1 (source-faithful
   basket) → **codex adopted**: 4 majors, USDJPY flagged as the
   author's best performer.

## Prior-build delta (CL-05, QM5_10513 mql5-ichimoku — checked 2026-07-25)

Artifact check of framework/EAs/QM5_10513_mql5-ichimoku/SPEC.md:
different source (MQL5 article), fresh-CROSS event entry (not state),
close vs Senkou **Span B only** (not max/min of both spans), **no
ATR-distance cloud filter** (STR-118's defining feature), settings
9/26/52, ATR(14) hard stop + fixed 1.5R TP (STR-118: cross exit, no
TP). Materially different rule set → rebuild justified.

## Outcome

Final spec = codex 02 with the buffer self-test merge. No escalation.

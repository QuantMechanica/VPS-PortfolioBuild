---
source_id: SRC01
source_pdf: "G:\\My Drive\\QuantMechanica\\Ebook\\PDF resources\\Building Winning Algorithmic Tr - Kevin J. Davey.pdf"
extracted_section: Appendix A — Monkey Trading Example, TradeStation EasyLanguage Code
book_pages: 247-253
extraction_method: poppler `pdftotext -layout`
extracted_by: Research Agent
extracted_at: 2026-04-27
status: archive_only
v0_filter_decision: skip-as-card
purpose: V5 P2 Baseline Screening null-hypothesis reference (random-entry / random-exit baselines)
---

# Appendix A — Monkey Trading Example (random-entry baseline)

> **NOT A STRATEGY.** This is Davey's null-hypothesis baseline used in *Limited Testing* (Ch 12). Four randomized variants are presented to test whether a candidate strategy actually has an edge versus chance. **Skip-as-card per SRC01 v0-filter policy.** Archived here as raw reference for V5 P2 Baseline Screening (`docs/ops/PIPELINE_PHASE_SPEC.md`) when a similar random-comparison baseline is needed.

## Davey's purpose for this code (Ch 12, "Limited Testing")

Davey introduces "monkey testing" as a methodological check: if a real strategy can't beat a randomized version of itself, the strategy has no edge. The four variants in App A are:

1. **Strategy 1 — Baseline (No Randomness).** Deterministic 3-bar consecutive-direction momentum entry, market order, walk-forward-recalibrated `ssl1`-multiple ATR stop.
2. **Strategy 2 — Random Entry, Baseline Exit.** Random direction at random time-of-day, deterministic stop.
3. **Strategy 3 — Baseline Entry, Random Exit.** Deterministic entry, random hold time.
4. **Strategy 4 — Random Entry, Random Exit.** Both random — pure random baseline.

The methodology is: a candidate strategy must dominate Strategy 4 on PF and DD, AND dominate Strategy 2 / Strategy 3 (mixed-random) before it qualifies as having an edge in entry-side or exit-side.

## Verbatim EasyLanguage code

```
Strategy 1: Baseline Strategy (No Randomness)

input: nContracts(1);
var:ssl1(1);
var:ssl(2000);

   if date >= 1070316 and date < 1080314 then begin ssl1 = 0.75 ; end ;
   if date >= 1080314 and date < 1090311 then begin ssl1 = 0.75 ; end ;
   if date >= 1090311 and date < 1100310 then begin ssl1 = 0.75 ; end ;
   if date >= 1100310 and date < 1110309 then begin ssl1 = 0.5  ; end ;
   if date >= 1110309 and date < 1120310 then begin ssl1 = 0.5  ; end ;
   if date >= 1120310 and date < 1130308 then begin ssl1 = 1.25 ; end ;
   if date >= 1130308 and date < 1140308 then begin ssl1 = .75  ; end ;

   if date >= 1070316 then begin
      if close<close[1] and close[1]<close[2] then begin
         buy ncontracts Contracts next bar at market;
      end;
      if close>close[1] and close[1]>close[2] then begin
         SellShort ncontracts Contracts next bar at market;
      end;
      SetStopContract;
      setstoploss(minlist(ssl1*BigPointValue*avgtruerange(14),ssl));
   end;

Strategy 2: Random Entry, Baseline Exit Strategy

input:
iter(1),percentlong(.400),holdbars(2.5),exitclose(0),oddstradetoday(.47),
begindate(1070319);
var:posstradetoday(0);

posstradetoday=random(1); //random number for today's trade

If date>begindate then begin
   If posstradetoday<=oddstradetoday then begin //trade will occur today
      //enter trade
      If random(1)<percentlong then buy this bar at close
      Else sellshort this bar at close;
   end;
end;

Strategy 3: Baseline Entry, Random Exit Strategy
(same baseline 3-bar entry as Strategy 1, but the exit is random:
 if barssinceentry >= random(2*holdbars) then exit)

Strategy 4: Random Entry, Random Exit Strategy
(combines the random entry of Strategy 2 with the random hold-time exit of Strategy 3)
```

(Full verbatim with page-break artifacts is at `appA_monkey_p261-268.txt`.)

## Use as V5 P2 reference

When P2 Baseline Screening for the Davey cards (or any other source) needs a "did we beat random?" check, port one or more of these variants to MQL5 and run as a comparator EA. The framework's Strategy_EntrySignal module can be substituted to randomize entry or exit; the module pattern in `framework/V5_FRAMEWORK_DESIGN.md` makes this a small change rather than a re-implementation.

**Naming if ported.** Per `docs/ops/PIPELINE_PHASE_SPEC.md` and the V5 magic-formula registry, a baseline EA used at P2 should be ID-allocated in the sandbox range (5000-8999) and named e.g. `QM5_5XXX_random_baseline`. Specifics deferred to CTO at the time of P2 implementation.

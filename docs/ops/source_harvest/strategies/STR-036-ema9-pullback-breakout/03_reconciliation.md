# STR-036 — Reconciliation (2026-07-24)

Codex's bar-sequence model ADOPTED (richer and Q&A-supported): a CROSS
event (close crosses EMA9) opens a directional SETUP; each subsequent
closed bar is a rolling CANDIDATE — the first candidate whose extreme
stays ≥5 pips off the EMA (long: low−ema ≥ 5 pips) AND whose close exceeds
the PRIOR bar's extreme (long: close > prev high) triggers the entry at the
next bar; an opposite cross before entry invalidates and flips the setup;
a setup is consumed by its first entry (no re-entry). SL = prior bar's
extreme ∓ (1 pip + current spread) (sell-side source typo read as ABOVE
prev high; flagged verbatim); TP = 2R. Claude's minimal two-bar reading is
subsumed (it is the candidate=first-bar case). Cohort: GBPUSD.DWX only
(both). Pip = 10*_Point on 5-digit (framework helper). Overlap QM5_9705:
earlier family build — this is the faithful Feliks ruleset.

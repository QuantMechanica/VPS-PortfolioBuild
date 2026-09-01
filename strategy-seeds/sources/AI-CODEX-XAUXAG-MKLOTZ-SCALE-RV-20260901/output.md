---
source_id: AI-CODEX-XAUXAG-MKLOTZ-SCALE-RV-20260901
record_type: governed_ai_origin_output
created: 2026-09-01
created_by: Research+Development
---

# Origin Output

Use one monthly XAU/XAG opposed-leg package. At the first executable D1 tick
of a new broker month, consume the month and reconstruct thirteen synchronized
completed-month gold/silver close pairs. Form twelve adjacent changes in
`ln(XAU)-ln(XAG)`, split oldest/newest six, subtract each block's own mean,
and reject any pooled centered-residual tie.

Assign the fixed Klotz score `Phi^-1(rank/13)^2` to pooled residual ranks
1..12. Let `K_recent` be the sum for the six recent residuals. Enumerate all
924 six-rank labels with the same frozen score table. Qualify when
`K_recent >= 3.9642160041063397` within the locked relative tolerance and its
inclusive upper tail is at most 494. This is the inclusive upper half of the
frozen label space, not a p-value or efficacy threshold.

If qualified, sell XAU/buy XAG when the recent raw-change mean exceeds the old
mean; buy XAU/sell XAG when it is lower; otherwise remain flat. Target equal
absolute USD notionals under one fixed-risk package, preserve paired-order
atomicity, and hold only to the next month or forty elapsed days. Q02, later
robustness gates, and unchanged Q09 alone own activity, economics, and
decorrelation.

# STR-040 — Reconciliation (2026-07-24)

Convergent: newark18's posted MQL4 code = authoritative rules (bar2
opposite colour, bar1 engulfing via close(1) vs open(2) plus own-colour
check, close(1) vs SMA50(1) strict); stop order at bar1 extreme with SL at
the opposite extreme; no TP; SMA-cross close exit on closed bars; one
position; pending lifecycle = cancel on exit-condition/opposite setup,
refresh on new same-direction setup (both specs materially identical).
Conflicts: (1) Cohort — claude EURUSD+GBPUSD (two slots), codex
one-symbol-at-a-time caution. RESOLVED → two-slot cohort (farm slots are
independent runs anyway; codex's aggregation caveat noted in card).
(2) Hook placement per fleet convention. Overlap QM5_1117 verified
distinct (different engulfing family generation).

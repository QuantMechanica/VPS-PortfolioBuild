# STR-069 — Reconciliation (2026-07-24/25)

Convergent: BASKET class (host EURUSD.DWX, members EURUSD+GBPUSD; two
independent EAs cannot reproduce the coupling); first-H1-candle-of-day
close vs the daily open decides each member's direction independently
(equality skips); both entries at the same evaluation; per-position SL/TP
10/10; one evaluation/day.
Conflict: the Equity-Sentry combined close — claude read "both gain 10" as
combined +20; codex as combined +10 total. RESOLVED → codex (+10
combined): it gives the "additional option" distinct function (the
per-position TPs already realize the both-at-+10 case) and matches
Equity-Sentry equity-target semantics (tie-break 1 via functional
coherence). Basket close: while BOTH legs are open, combined floating
profit in pip-value terms >= +10 pips-equivalent → close both (per-tick,
once-latched, retry-paced).
Prior build QM5_10049 (uncoupled, EOD exit, spread gate) not transferable
(G0_REVIEW_T6). host_symbol REQUIRED in card/sets (basket recipe; Q08).

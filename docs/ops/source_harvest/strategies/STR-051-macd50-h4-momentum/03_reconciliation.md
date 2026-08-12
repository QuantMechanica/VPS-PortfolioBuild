# STR-051 — Reconciliation (2026-07-24)

Convergent: MACD(5,13,1) main; delta = main(1) − main(3) vs ±0.00050
absolute price (5 GBPUSD pips, NOT _Point units); flat-only entries (the
later formal plan supersedes the early reverse/hold musings); netted
campaign = half at +30 pips + BE, remainder TP +45, SL 30; 20:45 wording
treated as typo (20:00 stands); one campaign.
DECISIVE CONFLICT — the bar grid: claude approximated with the broker H4
grid; codex proved from p.8 ("Gmt(bst)+1" charts) and p.31-32 (the thread
explicitly DECLINES broker-grid equivalence) that grid alignment is
strategy-material. RESOLVED → codex (tie-break 1): custom four-hour bars
aligned to UK civil 00/04/08/12/16/20, built in-EA from M15 closed data;
evaluations only at UK 08/12/16/20 Mon-Fri; MACD = manual EMA(5)−EMA(13)
recursion over the custom-bar closes (fixed seed depth, 20103-style
determinism); skip a boundary when either needed bar is incomplete.
UK-clock mechanization: in-EA London-offset helper patterned on
QM_DSTAware's existing US-DST calendar arithmetic (last-Sunday-March/
October rule) — the established house pattern, no invented market values;
framework file untouched. Complexity flagged in the card (heaviest EA of
the run).

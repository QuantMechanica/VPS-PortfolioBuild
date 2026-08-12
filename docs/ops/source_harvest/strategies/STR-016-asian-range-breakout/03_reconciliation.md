# STR-016 — Reconciliation (2026-07-24)

Convergent: 01:00-06:00 range from completed M15 bars; both stops at range
borders, SL = opposite border, no TP; straddle keeps the opposite pending
after first fill (max 2 entries/day — both derived it from the author's
July-11 buy-loss-then-sell anecdote); cancel pendings 13:00 (both flagged
the "1.5h before NY open" inconsistency and took the explicit clock); flat
20:00; trail = previous completed M15 bar extreme, never widen; no re-arm.
Conflicts: (1) Clock basis — codex fixed-UTC vs claude broker-hours.
RESOLVED → broker hours (the author's EA runs on his GMT+3-summer server =
NY-close seasonal clock; fixed UTC drifts 1h in winter vs his actual
implementation; consistent with NNF_008_BROKERCLOCK precedent). (2) Codex's
stricter no-one-sided-straddle rule (block the date if a boundary is already
crossed or either order invalid) ADOPTED (tie-break 2). (3) Hook placement
per fleet convention. Cohort: USDJPY only (GBPUSD/NAS100 rules never given —
both specs agree). Note: QM5_9936 (H1 variant, same thread) is a LIVE
mid-pipeline candidate (Q05/Q06 PASS, Q07 INFRA_FAIL) — this M15 build is a
ledger-validated competing variant, not a rescue; Q09 challenger logic
arbitrates later.

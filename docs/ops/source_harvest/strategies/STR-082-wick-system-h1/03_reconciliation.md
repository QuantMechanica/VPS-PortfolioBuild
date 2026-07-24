# STR-082 — Reconciliation (2026-07-25)

Convergent: H1 wick comparison (lower vs upper of the previous candle,
strict; tie = nothing); entry at the new bar; TP/SL 50/50. The source's
hourly unbounded stacking is inadmissible — mechanization conflict:
claude flat-only (discards later hourly direction) vs codex
latest-signal projection (same-direction signals HOLD the position;
opposite signals CLOSE and REVERSE; none = hold). RESOLVED → codex
(minimum bounded projection preserving the source's hourly information;
labeled `single_position_latest_signal` in every result). Prior
QM5_10047 invented filters absent. Cohort EURUSD/GBPUSD.

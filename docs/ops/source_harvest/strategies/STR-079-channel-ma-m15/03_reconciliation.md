# STR-079 — Reconciliation (2026-07-25)

Convergent: EMA55(high)/EMA55(low) channel + EMA33(close) signal; strict
cross signals; NORMAL entry (price within 40 pips of the channel) at
market vs DELAYED entry (pending LIMIT at the per-bar-refreshed EMA33,
valid while the signal holds) — both specs identical on the core.
Conflicts: (1) Exit baseline — both selected the no-TP opposite-signal
mode as the only fully mechanical option; codex adds
close-AND-REVERSE with the reverse routed through the normal/delayed
entry workflow (the author's explicit "close & reverse"). RESOLVED →
codex (tie-break 1 verbatim; reverse respects the delayed rule — if the
opposite signal is delayed-class, close and arm the pending instead of
market-reversing). Fixed-40/BE and 210/session modes = documented
variants. (2) Hard stop 40 vs 50: RESOLVED → 40 (the author ties SL
geometry to the channel barrier and uses 40 as the delayed-entry
threshold — internal coherence; with RISK_FIXED sizing the choice is
risk-neutral; input [40,50]). Prior QM5_9989 deltas documented; this
build makes the exit selection explicit (its missing reconciliation was
codex's own T6 contest point).

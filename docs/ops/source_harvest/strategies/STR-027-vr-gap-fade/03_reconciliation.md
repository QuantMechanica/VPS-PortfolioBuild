# STR-027 — Reconciliation (2026-07-24)

Convergent: new-bar gap test |Close(1) − Open(0)| > min_gap (strict, the
only shift-0 read is the immutable open); down-gap → BUY / up-gap → SELL at
market; TP = gap-closure level (signal bar's Close(1)); fixed-point SL; one
position; no filters beyond house news gate. HOUSE DEVIATION (both specs,
independently): SL attaches AT ENTRY via the request (framework forbids
unprotected positions) — only the dynamic TP is deferred to Manage, with
the 20098 pattern: attained-target market close + per-bar retry pacing.
Conflicts: (1) Unsourced defaults — RESOLVED → codex's (min_gap 100 points,
SL 300 points, deviation 20), all flagged non-authorial; card requires
price-unit demonstration per symbol; Q03 = calibrator. (2) Market: D1
indices (NDX/GDAXI) per ledger — distinct from QM5_10044 (H1 FX, Q04-FAIL).
Gap-frequency floor risk on near-continuous .DWX daily bars documented.

# CODEX BRIEF — Book3 Conservative-Bound Design v2: Review R2 (Topic C)

**Ticket-Klasse:** ops_issue · **Autor:** Claude · **Reviewer:** Codex (du)
Design v2: `docs/research/FTMO_BOOK3_CONSERVATIVE_BOUND_DESIGN_V2_2026-07-31.md`
— Antwort auf dein R1 (62 %, alle 7 Akzeptanzbedingungen adressiert:
Diagnostic-Label + n_trials≥165, Fenster 2022-09-16..2025-12-30, Per-Run-
Stream-Vertrag, Cost-Snapshot `7eab3bf8…` als fixed-current-terms-
Counterfactual, CONSERVATIVE_LIFETIME_MAE_BOUND-Label + Lifecycle/CE(S)T-
Arithmetik, Bootstrap/ESS-Regeln IS-gefroren, keine Live-DB im Verdikt).

Prüfe gegen deine eigenen R1-Bedingungen und nenne die **Zustimmungs-%**.
`>= 90 %` -> implementiere im selben Ticket `tools/strategy_farm/portfolio/
book3_bound_eval.py` + `prepare-config` + Tests (Fixtures inkl. Multi-Day-
Intraday-Breach, CET/CEST-Grenzfall, SHA-Mismatch-Refusal, Missing-Swap-
Refusal, Censoring). **KEIN diagnostischer Lauf** — der erfolgt erst nach
Claudes Implementierungs-Review. `< 90 %` -> Findings, Runde 3.

Read-only-Randbedingungen wie R1 (keine Backtests/Requeues/DB-Writes/
Factory-Eingriffe; T5/T_Live/FTMO tabu).

## Deliverable

`docs/ops/evidence/2026-07-31_book3_bound_design_v2_review.md`: Zustimmungs-%,
Findings, (bei >=90 %) Implementierungs-Commits + Testlauf-Summary. Danach
`update-task <id> --state REVIEW --artifact-path <deliverable> --verdict "<kurz>"`.

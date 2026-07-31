# CODEX BRIEF — Book3 Sealed-Validation Design: Adversarial Review R1

**Ticket-Klasse:** ops_issue · **Autor:** Claude · **Reviewer:** Codex (du, Sol-Max)
**Protokoll (Ledger Topic C, `docs/ops/CONVERGENCE_LEDGER_WEEKEND_2026-07-31.md`):**
Adversarialer Review von
`docs/research/FTMO_BOOK3_SEALED_VALIDATION_DESIGN_2026-07-31.md`. Nenne eine
explizite **Zustimmungs-Prozentzahl**. `>= 90 %` -> beginne im selben Ticket mit
der Implementierung von `tools/strategy_farm/portfolio/book3_sealed_eval.py` +
Tests (KEINE Verdikt-Behauptungen — der erste versiegelte Lauf erfolgt erst nach
Claudes Implementierungs-Review). `< 90 %` -> REVIEW mit Findings, Runde 2.

## Review-Schwerpunkte

1. **Leck-Jagd:** Findet die Versiegelung wirklich statt BEVOR irgendetwas die
   Holdout-Daten sieht? Wo könnte Selektionsinformation einsickern (Multiplier-
   Quelle, Kompositionswahl — die drei Sleeves wurden aus dem Gesamtkorpus
   gewählt! Bewerte, ob das die Seal-Semantik bricht und was die ehrliche
   Konsequenz ist: n_trials-Deklaration? Composition-Neuwahl IS-only?).
2. **Statistik:** CI-Methode (Moving-Block-Bootstrap vs Newey-West), Blocklänge,
   Umgang mit überlappenden Starts (102 Starts sind NICHT unabhängig — ESS!).
   Die 07-27-Lektion: gemeinsame Fenster zählen, nie multiplizieren.
3. **Event-Trace:** pessimistische MAE-Schranke korrekt spezifiziert?
   CE(S)T-Tagesgrenzen? Multi-Day-Sichtbarkeit (challenge_final.py:110-Klasse)?
4. **Read-only-Vorprüfungen (führe sie aus, Evidenz ins Deliverable):**
   (a) `entry_time`-Abdeckung der drei Streams (9936-R0 1143, 10145-R1 291,
   13108-R2 548 Trades) — 100 % ja/nein, mit Pfaden + Zählungen;
   (b) Stream-Provenienz: durable Aggregate vs per-run-Kopien
   (Trade-Count-Match-Doktrin aus `build_joint_sim_manifest.py`);
   (c) `venue_cost_model.json`: FTMO-Kommission + Swap für USDJPY, XAUUSD,
   XTIUSD vorhanden? Fehlende Felder benennen (NICHT schätzen).
5. Beantworte die fünf offenen Fragen am Ende des Designs mit Begründung.

## Do NOT

- Keine Backtests starten, keine Requeues, keine DB-Schreibzugriffe, kein
  Factory-Eingriff, niemals T5/T_Live/FTMO-Konto.
- Keine Gate-/challenge_ready-Redefinition — die FAIL_SOFT-Frage bleibt als
  OWNER-Frage formuliert.
- Kein Lauf des versiegelten Verfahrens vor Claudes Implementierungs-Review.

## Deliverable

`docs/ops/evidence/2026-07-31_book3_sealed_validation_review.md`: Zustimmungs-%,
Findings je Schwerpunkt, Vorprüfungs-Evidenz (a-c), Antworten auf die fünf
Fragen, (bei >=90 %) Implementierungs-Commits + Testlauf-Summary. Danach
`update-task <id> --state REVIEW --artifact-path <deliverable> --verdict "<kurz>"`.

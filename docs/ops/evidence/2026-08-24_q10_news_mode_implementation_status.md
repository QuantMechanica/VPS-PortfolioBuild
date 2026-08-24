# Q10_NEWS Modus-Implementierung — Statusklärung (OWNER-Frage 2026-08-24 abends)

**Frage (OWNER):** Sind die Newsfilter-Modi (mit/ohne/FTMO, in Summe 7 Modi lt. Vault) im EA
an dieser Stelle implementiert, oder braucht es eine Neuprogrammierung? Wo wird gespeichert,
was welcher Modus bringt und ob die EA mit FTMO-Newsfilter FTMO-tauglich ist?

## Befund: vollständig framework-verankert — KEINE Neuprogrammierung nötig

1. **EA-Seite:** `framework/include/QM/QM_NewsFilter.mqh:58` — `enum QM_NewsMode` mit exakt
   7 Modi: `OFF, PAUSE, SKIP_DAY, FTMO_PAUSE, 5ERS_PAUSE, NO_NEWS, NEWS_ONLY`. Legacy-Modi
   werden datengetrieben in das 2-Achsen-Modell übersetzt:
   - **Temporal (m0–m6):** OFF, CLOSE_ALL_PRE, PRE30, PRE30_POST30, PRE60, PRE60_POST60, SKIP_DAY
   - **Compliance (c0–c3):** NONE, DXZ, FTMO, 5ERS
   Kalenderbindung testreproduzierbar über plain Inputs (`qm_news_calendar_bundle_id`,
   `..._expected_sha256`, `..._common_relative_path`); jede V5-EA erbt das über das Framework —
   die Matrix steuert die Modi pro Zelle über generierte Setfiles, ohne EA-Code-Änderung.

2. **Matrix:** `control_off__m0__c0` + `policy_on__m{0..6}__c{0..3}` = 29 Zellen (Expansion,
   `matrix_scope=7x4`) bzw. 7×1-Zielcompliance = 8 Zellen (Standard).

3. **Speicherung existiert und ist verdrahtet** (farm_state.sqlite):
   - `q09_news_tests` — 1 Zeile je (EA, Symbol)-Test: `verdict`, **`chosen_temporal`**,
     **`chosen_compliance`** (= „was davon was bringt"), `deployment_target`/`target_compliance`
     (FTMO-Tauglichkeit ablesbar aus FTMO-Compliance-Zellen bzw. chosen_compliance),
     Identitäts-/Fenster-/Bundle-Bindung. Danach Q11.
   - `q09_news_cells` — 578 Zeilen mit Selection-/Holdout-/Full-Metriken je
     Modus×Compliance×Seed (per-Modus-Performance liegt bereits vor).

## Der eigentliche Engpass ist Ausführung, nicht Implementierung

Kein Test hat je konklusiv geschlossen: Verdikt-Bestand aller Zeiten = 34× REVIEW_REQUIRED,
1× CONFIG_LOCKED, 1× INVALID_EVIDENCE; `chosen_*` überall None. Heute terminierten auch die
drei 29-Zellen-Expansions (463fa52a, e58b8c4c, 9416f0ce) REVIEW_REQUIRED (unvollständige
Zellen). Dominante Zellfehlerklasse: 81× „Q09 selection run_smoke exited with code 1 without
a fresh run_smoke summary" + 2× `qm_news_calendar_bundle_id` mismatch →
**P0-Forensik/Fix-Ticket `cb50e7c8` (P90)**. Sobald gefixt: append-only Re-Runs; die
Ergebnisse landen dann automatisch je Strategie in `q09_news_tests`.

**Codex-Betrieb:** Wochenquota erschöpft; Reset lt. OWNER 23:00. Spawner aktiv; nach Reset
paced der Quota-Governor die Beauftragung nach Wochenverbrauch (Ticket-Queue inkl. cb50e7c8
wartet korrekt priorisiert).

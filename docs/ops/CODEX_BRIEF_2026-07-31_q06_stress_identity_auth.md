# CODEX BRIEF — Q06-Stress-Identität: 13 vakuose Kandidaten authentifizieren

**Ticket-Klasse:** ops_issue · **Reviewer danach:** Claude
**Quelle:** `farmctl health` Q06-Check FAIL: 13 Kandidaten, bei denen die
10 %-Trade-Rejection-Injektion (qm_stress_reject_probability) **nichts**
verändert hat, obwohl sie es auf dieser Kohorte müsste — Verdacht: das
Stress-Seeding erreicht den Tester nicht (vakuoser Q06-PASS = wertlose
Stress-Evidenz). Provenienz-Hashes (binary_hash, ea_hash, report) sind noch
ungebunden.

## Aufgaben

1. Je Kandidat die EA/Set/Binary/Report-Hashes authentifizieren (read-only
   gegen die Run-Artefakte) — erst mit gebundener Identität ist „nichts
   geändert" ein Befund statt eines Artefakts.
2. Für authentifizierte Fälle: `qm_stress_reject_probability`-Verdrahtung
   auditieren (Setfile → Tester-INI → EA-Input → Framework-Pfad): WO versandet
   der Parameter? (Klassenverdacht: Setfile-Generation, INI-Übernahme, oder
   EA liest Input nicht — vgl. die 07-31-Setfile-Parser-Klassen.)
3. Befund je Kandidat: STRESS_WIRING_DEFECT (mit file:line) vs. legitime
   Unempfindlichkeit (begründet, z. B. zu wenige Trades im Fenster für
   messbaren Effekt — dann ist der Check-Schwellwert das Thema) vs. RETIRE.
4. Fix-Vorschlag (kein Apply an Evidenz; Code-Fix mit Tests erlaubt, wenn die
   Ursache im Generator-/Runner-Code liegt — Setfile-Bytes bestehender Evidenz
   bleiben unangetastet, vgl. Byte-Bindungs-Doktrin).

## Deliverable

`docs/ops/evidence/2026-07-31_q06_stress_identity_auth.md` mit
Authentifizierungs-Tabelle, Verdrahtungs-Audit, Fix-Commits (falls Code).
Danach REVIEW.

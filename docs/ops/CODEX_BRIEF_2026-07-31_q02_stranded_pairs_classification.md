# CODEX BRIEF — 278 Q02-stranded-exhausted-Paare: Klassifikation + governed Canary (KEIN Bulk-Requeue)

**Ticket-Klasse:** ops_issue · **Reviewer danach:** Claude
**Quelle:** `farmctl health` Check `q02_stranded_exhausted_pairs` = **FAIL**
(278 EA/Symbol-Paare ohne non-infra-Terminaldisposition, ohne Nachfolger,
≥12 INFRA_FAIL-Rows). Das ist gebundene Kapazität und verdeckte Wahrheit:
manche Paare sind ehrlich tot (Null-Trades → RETIRE per Frequency-Floor),
manche stecken in reparierbaren Evidenzfehlern. Der action_hint des Checks ist
der Auftrag:

## Aufgaben

1. **Klassifikation der Kohorte** (read-only): je Paar das row-gebundene
   Aggregat + verdict_reason auswerten → Klassen bilden, mindestens:
   (a) VALID_ZERO_TRADES (lief korrekt, 0 Trades → RETIRE-Kandidat per
   Q02-Frequency-Floor, Operating Rule), (b) INVALID/Evidenz-Defekt
   (Kalender-hart, Setfile-Klassen — inkl. der neuen Header-/Duplikat-Klassen
   aus 07-31, NO_HISTORY-Transienten, Lock-Storm), (c) UNKLAR. Verteilung +
   Top-Ursachen mit Zählern, je Klasse 3 Beleg-Beispiele (Aggregat-Pfade).
2. **Canary-Vorschlag** (OWNER-sized, NICHT ausführen): für Klasse (b) je
   Top-Ursache 2-3 Paare als governed Einzel-Requeues vorschlagen (exakte
   Row-IDs, erwartetes Ergebnis, Abbruchkriterium). Für Klasse (a):
   RETIRE-Listenentwurf (kein Vollzug — Frequency-Floor-RETIRE ist
   Operating-Rule-gedeckt, aber Vollzug erst nach Claude-Review der Liste).
3. **Kein** Bulk-Requeue, keine Wave-Mechanik, keine Status-Mutation in diesem
   Ticket. Reine Analyse + präzise Vorschläge.

## Deliverable

`docs/ops/evidence/2026-07-31_q02_stranded_pairs_classification.md` +
Klassifikations-CSV/JSON. Danach REVIEW.

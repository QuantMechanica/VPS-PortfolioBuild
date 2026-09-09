# Umsetzung der Kandidatenpriorisierung – 09.09.2026

## Autorisierung und Umfang

Entscheidungsreferenz: `OWNER-DEC-CANDIDATE-PRIORITIES-20260909`.

Quelle ist die ausdrückliche Anweisung des Users in diesem Thread: „Setze die Priorisierung dementsprechend um!“, ergänzt um „Alles umsetzen und vorantreiben!“. Dies dokumentiert die Chat-Autorisierung; es ist keine erfundene separate Unterschrift oder externe Freigabe.

Grundlage: [Priorisierung und Statusaudit](2026-09-09_candidates_pattern_balke.md).

Umsetzung über bestehende, protokollierende Factory-Controller: Reihenfolge der bestehenden Q12-Programme ändern, verifizierte obsolete Infrastruktur-Sperren exakt freigeben, vorhandene Matrix-/Walk-Forward-Programme weiterverarbeiten und sichere Prerequisites für Diversifikationskandidaten vorbereiten. Bestehende Tests werden nicht abgebrochen. Keine Live-Deployments, kein AutoTrading-Schalter, keine Gate-Abschwächung, keine Überschreibung gemessener Ergebnisse, keine zweite Balke-Matrix.

Die vorherige Rückstellung der bestehenden GBPUSD-/USDCAD-Pattern-Programme an das Queue-Ende wird durch die aktuelle User-Anweisung bezüglich der Reihenfolge ersetzt. Ökonomische Kriterien und separate Ressourcen-Sperren bleiben bestehen.

## Geplante Queue-Gruppen

1. Abschluss-/Evidenzgruppe: die tatsächlichen Matrix-Owner von QM5_10706/GBPUSD, QM5_11422/USDCAD, Original-Balke QM5_13213/USDJPY sowie QM5_41219/XAUUSD und QM5_41221/EURUSD.
2. Zusätzliche Marktabdeckung: QM5_21501/USDJPY, QM5_9641/WS30, QM5_11660/NDX und QM5_13013/NDX. NDX-RAM_WINDOW_44GB bleibt wirksam; die Priorisierung ist keine RAM-Freigabe. Die beiden Balke-Linien sind dieselbe Strategiefamilie.
3. Übrige Programme behalten untereinander ihre Reihenfolge. Nicht besitzende, doppelte Q12-Anforderungen für 10706/11422/13213 werden nach hinten gestellt; gemessene Zellen und deren Owner-Bindung bleiben unverändert.

Es werden ausschließlich die Steuerfelder für die Reihenfolge geändert. Die Zeitstempel in `queue_order_at` sind explizite Sortierschlüssel, keine vorgetäuschten Erstellungs- oder Entscheidungszeitpunkte. Die tatsächliche Änderung wird mit aktuellem UTC-Zeitstempel, vorherigem Wert und Backup im Event-Log erfasst.

## Laufende Befunde vor der Umsetzung

- Original-Balke steht bereits nominal an erster Stelle. Beide Artifact-Binding-Holds sind noch aktiv, aber die drei gebundenen Dateien (EX5, MQ5, Setfile) sind inzwischen vorhanden und stimmen jeweils bytegenau mit ihren erwarteten SHA-256-Werten überein. Kein Neuaufbau dieser Dateien erforderlich.
- Der normale Matrix-Service findet für Original-Balke trotzdem kein zugelassenes Mess-Sibling. Das wird separat anhand der bestehenden Recovery-Belege untersucht; keine Umgehung der Sibling-Authentifizierung.
- Der USDCAD-Matrix-Owner ist zur Walk-Forward-Weiterverarbeitung bereit: Dry-run projiziert vier Kombinationstests aus 595 Messungen und 490 Prescreen-Ausschlüssen.
- Die beiden bevorzugten Walk-Forward-Programme haben je vier offene Kombinationstests. Ihre tatsächliche Claim-Fähigkeit wird zusätzlich geprüft; der Driver-Status allein ist kein Fortschrittsnachweis.

## Ausführung und Verifikation

Umgesetzt; Snapshot 09.09.2026, **07:00 Uhr Wien**. Die vorangehende Statusanalyse bleibt als historischer Snapshot unverändert.

- **12 Q12-Reihenfolgeänderungen** über `set_dl089_queue_order`: fünf Abschlusskandidaten an die Spitze, vier Kandidaten für zusätzliche Marktabdeckung dahinter, drei nicht besitzende/doppelte Anforderungen ans Ende. Je Änderung existieren Event, vorheriger Sortierschlüssel und Backup-Referenz. Aktive Tests, Ergebnisse und Holds wurden vom Queue-Controller nicht verändert.
- **15 obsolete ARTIFACT_BINDING_MISSING-Sperren freigegeben** über `farmctl.release_work_item_hold`: zwei bei Balke und 13 bei GBPUSD. Balke: alle drei erwarteten Datei-Hashes stimmen exakt. GBPUSD: expliziter EX5-Pfad/Hash stimmen mit Dispatch und Registration überein; Source, Card und neutraler Basis-Setfile stimmen mit der Registration überein; jeder jährliche Setfile entspricht bytegenau dem kanonischen Rendern aus diesem versiegelten Basis-Setfile und dem deklarierten Arm. Keine Dateien neu gebaut oder umgebunden. Work-item-Zustand, Payload und Verdict blieben bei den Freigaben unverändert; Transition-Ledger-Sequenzen 3131–3145.
- **Bestehende Programme weiterverarbeitet**: der Matrix-Service bestätigt nach dem Fix Original-Balke, GBPUSD und USDCAD ohne Deferred-Fehler. Er respektiert weiter die aktiven Lane-/Zellenlimits; bestehende Messungen werden weiterverwendet. USDCAD bekam vier reguläre WF-Kombinationstests, keine neue Jahresmatrix.

### Reproduzierte und behobene Infrastrukturfehler

1. **Walk-Forward-Claim nach Prescreen:** `_dl089_declared_lane` übernahm die jährliche Prescreen-Zulassungsliste in die getrennte WF-Testliste. Das führte bei EURUSD und XAUUSD reproduzierbar zu `staged admission contains undeclared keys`. Der Fix validiert zuerst die originale jährliche Zulassung und entfernt deren Metadaten ausschließlich aus der temporären Ansicht des abgeleiteten Testzweigs. Original-Ledger und Regeln bleiben unverändert; fehlende/fremde abgeleitete Zellen werden weiter abgewiesen. Vorher ERROR, nachher `checked`, anschließend native Messungen auf dem Canary-Worker.
2. **Original-Balke-Recovery nicht im normalen Service verdrahtet:** die ältere Strategy Card besitzt nicht das neuere Sibling-Frontmatter und nennt die technische 21501-Abstammung. Der Service ignorierte deshalb den bereits separat geprüften Recovery-Vertrag für die 13213-Auswertung. Neue, read-only Authentifizierung ausschließlich für die exakte vorhandene Recovery: gepinnter Registration-Hash, freigegebener Review-Hold, Deklarations-Hash, alle Artefaktbindungen, gebundener nativer Q02 und unveränderter Digest der 486 adoptierten Alt-Messungen. Keine neue G0-Freigabe und keine Änderung der Card. Die Sidecar-Zuordnung wird nur für die Validierung projiziert; Original-Provenienz bleibt unverändert. Finale Receipts schließen die adoptierten Messungen ein. Der reguläre Service kann das bestehende Programm nun warten und nach Abschluss weiterführen.
3. **Falsche Missing-Artifact-Diagnose bei externen Matrix-Setfiles:** der Diagnose-Census leitete den EA-Ordner vom Setfile-Großelternordner ab. Bei Matrix-Dateien ist das der Programmordner. Er berücksichtigt jetzt den explizit gebundenen EX5-/MQ5-Pfad; echte Hash-Abweichungen werden weiterhin gemeldet.

Code-Commit: `71059c2c2f` (`fix(factory): unblock reviewed census and derived walk-forward lanes`).

### Beobachteter Fortschritt

| Programm | Vorheriger Snapshot 06:29 | Snapshot 07:00 |
| --- | --- | --- |
| Original-Balke / Mess-EA 41097 | 858 gemessen, 218 Prescreen-Holds, neun ungeklärt | **863 gemessen**, 218 Prescreen-Holds, vier ungeklärt einschließlich eines aktiven Tests; keine Artifact-Binding-Sperre |
| GBPUSD / 41161 | 343 gemessen; 13 Artifact-Binding-Sperren | **345 gemessen**, ein aktiver Test; alle 13 Sperren verifiziert freigegeben |
| USDCAD / 41163 | Jahresmatrix faktisch disponiert, Q12 noch wartend | **Drei von vier WF-Kombinationstests gemessen**, vierter aktiv |
| XAUUSD / 41346 | Vier WF-Kombinationstests warteten | **Drei von vier gemessen**, vierter aktiv |
| EURUSD / 41344 | Vier WF-Kombinationstests warteten | Vier noch pending; reproduzierte Zulassungsursache behoben, Priorität gesetzt |
| WS30 / 41306 | Kein materialisiertes Programm | Gestaffeltes Programm materialisiert; **erster Jahres-Basistest gemessen**, nächster bereit. Der deklarierte Umfang bleibt 1.085; gestaffelte Materialisierung ist kein Weglassen von Pflichtprüfungen. |
| Zweite Balke-Linie / 41324 | 762 gemessen | 768 gemessen; gleiche Strategiefamilie, kein unabhängiger Diversifikationszähler |

Keine dieser Zwischenzahlen ist ein vorweggenommenes PASS oder eine Renditeverbesserung. Der qualifizierte Census-Zähler bleibt zum Snapshot 16. Die Einschränkung „14 abgeschlossene Pattern-Suchen plus zwei ältere No-Search-Abschlüsse“ bleibt bestehen, bis neue finale Receipts vorliegen.

### Tests und laufender Rollout

- **138 fokussierte Tests + drei Rollout-Tests bestanden**; Python-Compile-Check und `git diff --check` bestanden. Bestehende Matrix-Fixtures isolieren jetzt ihren Full-Matrix-Vertrag vom geerbten Live-Prescreen-Environment; andernfalls prüften sie unbeabsichtigt nur zwei initial materialisierte Jahreszellen.
- T6-Factory-Worker wurde nach Prüfung auf Leerlauf und unter Mutation-Lock gezielt ersetzt: PID 25668 → 17900. Keine `terminal64.exe` beendet; temporäre Reservierung freigegeben. Er hat bereits reale WF-Ergebnisse geliefert.
- Begrenzter, versteckter Rolling-Restart für die übrigen neun exakt benannten alten Worker-PIDs läuft (Controller-PID 7356). Höchstens 60 Minuten, mindestens 150 Sekunden Abstand, ausschließlich unreservierte Leerlauf-Worker, Mutation-Lock und erneute Active-Prüfung vor jedem Stop. Fremde/recycelte PIDs werden nicht beendet. Jeder Schritt ist an den getesteten Worker-SHA gebunden; Source-Drift stoppt den Rollout. Zum Snapshot wurde zusätzlich T10 erfolgreich ersetzt: 28972 → 31956. Vollständiger Fleet-Rollout wird **noch nicht** behauptet.
- Laufprotokoll: `D:\QM\reports\state\candidate_priority_rollout_20260909.log`; Fehlerdatei gleicher Name mit `.err`.

Die beiden NDX-Anforderungen behalten ihre aktiven `RAM_WINDOW_44GB`-Holds. Reihenfolge verbessert, aber keine Freigabe außerhalb des vorgesehenen Ressourcenfensters. Keine Gate-Kriterien, Live-EAs, AutoTrading-Einstellungen oder T11/T12 verändert. Fremde Änderungen im Worktree und Git-Index blieben erhalten.

### Nachkontrolle 07:06 Uhr Wien

- USDCAD und XAUUSD haben inzwischen jeweils **alle vier WF-Kombinationstests** abgeschlossen. Der reguläre Matrix-Service hat beide bestehenden Q12-Owner anschließend mit **`NO_FILTER_CHANGE`** finalisiert: `BUY=[]`, `SELL=[]`. Die bisherigen Varianten bleiben erhalten; keine Filterverbesserung behauptet. Bei USDCAD ersetzt dieser neue Abschluss nun die zuvor fehlende vollständige Pattern-Suche. Die obige 14-plus-zwei-Einschränkung beschreibt ausschließlich den früheren Snapshot.
- EURUSD hat den ersten von vier WF-Kombinationstests gemessen; drei sind noch offen. Original-Balke steht bei **864 jährlichen Messungen** und bleibt Q12-pending; einschließlich des aktiven Tests sind noch drei Jahreszellen ungeklärt, neben den unveränderten 218 Prescreen-Holds. GBPUSD erreichte 346 jährliche Messungen.
- Der gezielte Service-Aufruf für USDCAD, XAUUSD und EURUSD endete ohne Deferred-Fehler. EURUSD wartet regulär auf die nächste Programm-Lane; kein neuer technischer Claim-Fehler.
- Zusätzlich zu T6/T10 wurden T8, T1 und T2 im Leerlauf erfolgreich ersetzt. Rollout-Controller weiterhin aktiv, Fehlerdatei leer. Kein vollständiger Abschluss der verbleibenden Worker behauptet.
- Die beiden finalen Q12-Receipts inklusive SHA-256 stehen im Nachkontrollabschnitt des JSON-Nachweises. Die Factory bleibt eingeschaltet.

Maschinenlesbare Nachweise mit Queue-Events, Hold-Freigaben, Backup-Referenzen, aktuellem Programmstatus und Rollout-Snapshot: [2026-09-09_candidate_priority_execution.json](2026-09-09_candidate_priority_execution.json).

Rollback: Reihenfolge bei Bedarf über den gleichen Controller anhand der protokollierten vorherigen Werte zurücksetzen. Infrastruktur-Code kann über einen gezielten Folgecommit zurückgenommen werden; gemessene Ergebnisse und Recovery-Adoption bleiben unverändert. Kein Gesamt-Restore der Datenbank über zwischenzeitlich hinzugekommene Factory-Arbeit.

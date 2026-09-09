# Balke: reparierte Messversion QM5_41398

Stand 09.09.2026, 15:42 Wien: **nativ COMPILE_OK / Build-Check PASS; unabhängige
Review beauftragt, noch TODO. Wirtschaftlicher Q02-/Matrixstart ausstehend.
Kein Live-Eingriff.**

## Ergebnis dieses Schrittes

- `QM5_41398_balke-pattern-repair-opt` ist eine separat registrierte Messversion
  des eingefrorenen 41097-Instruments für Original-Balke 13213 / USDJPY.DWX / H1.
  Genau eine EA-ID und ein aktiver Magic-Slot wurden ergänzt; keine retired Rows
  entfernt, keine neue Magic-Kollision. Der historische Identitätsbestand enthält
  bereits Dubletten; deren Anzahl blieb unverändert und ist kein PASS des ganzen Bestands.
- Der source-level Diff enthält nur Identität/Beschreibung und den vorhandenen
  `QM_PATTERN_PERMISSION_EA_MANAGED`-Guard vor QM_Common. Alle Strategie-Funktionen,
  Parameter, Risk-/News-/Friday-Regeln und der A1/A2-Straddle-Ablauf bleiben erhalten.
  Patternreferenz bleibt geschlossenes D1, Shift 1. Die 33/34-Reparatur kommt aus
  dem separat geprüften kanonischen Include.
- Der Build-Skill `qm-build-ea-from-card` bestimmt die Registry-, Magic-, Setfile-,
  Compile- und Review-Grenzen. Wegen des ausdrücklich identischen Vergleichsgegenstands
  wird der bestehende Balke-Body übernommen, nicht durch neue Skeleton-Mechanik ersetzt.
- Alle 28 unmittelbar im EA deklarierten Inputs sind explizit im Basis-Setfile
  gesetzt, sechs Patternslots = 0. Keine numerische Optimierung und keine neuen Symbole.

## Zusätzlicher Generatorfehler: Kartenwerte gingen verloren

`Add-DefaultsMatchingInputs` akzeptierte die veränderliche Zieltabelle als
`[hashtable]`, der Aufrufer übergab jedoch eine `[ordered]`-Tabelle. PowerShell
konvertierte diese in eine Kopie: Die hinzugefügten Kartenwerte gingen verloren.
Die spätere Source-Fallback-Schleife lieferte nur Strategy-/Patternwerte. Das
betrifft nicht nur fehlende explizite Framework-Werte: Ein Kartenwert konnte
gegenüber einem abweichenden Source-Default ignoriert werden.

Zwei unabhängige kleine Generator-Regressionen reproduzierten den Fehler sowohl
unter Windows PowerShell als auch PowerShell 7 (beide zunächst FAIL). Korrektur:
Der Zielparameter ist jetzt `System.Collections.IDictionary`, also keine Kopie.
Beide Tests beweisen die Übernahme der Framework-Werte, ein Karten-Override von
17 auf 23, genau eine Zuweisung und das Verwerfen unbekannter Inputnamen.

Die Änderung wirkt auf künftige Generierungen; **kein bestehendes wirtschaftlich
gebundenes Setfile anderer EAs wurde hier regeneriert oder umgeschrieben**. Der
alte Balke bleibt eingefroren. Der Umfang früherer Karten-/Default-Abweichungen
ist ein separater Auditpunkt, keine bewiesene pauschale Ungültigkeit alter Ergebnisse.

## Native Abnahme

Compile-Work-item: `e8e4cad7-5ec5-428b-9c61-f690e26f8089`, priorisiert, auf T9
ausgeführt **15:26:23–15:27:05 Wien**. Reale MetaEditor-Ausgabe: **0 Fehler,
0 Warnungen**. `build_check`: PASS. Kein manueller `terminal64.exe`-Start.

Die erste Analyse meldete drei Warnungen, weil der alte Card-Finder nur die
Runtime-Kartensammlung und den flachen Seed-Ordner durchsucht, nicht die neue
Repo-Artefaktkarte/Docs-Kopie. Die identische Karte wurde anschließend auch im
kanonischen Runtime-Reservoir abgelegt. Der read-only Hardening-Lauf mit dieser
eindeutig aufgelösten Karte hat **keine Fehler und keine Warnungen**. Der ursprüngliche
Compile-Report mit seinen drei Analysewarnungen bleibt unverändert erhalten.
Unentscheidbare/noch nicht automatisierte Semantikklassen sind dadurch nicht bewiesen.

| Artefakt | SHA-256 |
| --- | --- |
| Neue MQ5 | `fdbb7499f349a6bd238231e7eb3d4a6257290af650e363ba78b0f95518890540` |
| Neue EX5 | `68d37d3a6b6d5d4354e5a9aa494488d8d2809b1f662ff75fbb26440658137c01` |
| Eingefrorene alte MQ5 | `8e5cfdbf6f513bdbfd5fdcd25357907cad124497123b8a1abe133c9f2d1d6329` |
| Eingefrorene alte EX5 | `e077660cc9ac5d74a6edc8896b72249f221fb030279bbd022f7e9d7756bb3a2e` |

Vor dem Compile wurde der komplette Projekt-Include-Baum separat kopiert.
Nachkontrolle 15:29:54 Wien: **69/69 Projekt-Includes an beiden tatsächlichen
Compiler-Include-Wurzeln stimmen mit dem archivierten Baum überein**. Die
MetaTrader-Standardbibliothek gehört weiterhin zur protokollierten Compiler-Installation;
dieser Vergleich behauptet keine historische Gleichheit mit dem alten August-Build.

Artefakte: `D:/QM/reports/pattern_permission_repair/balke_41398_20260909/`

- `precompile_snapshot.json` und `include/`: archivierte Projektdateien.
- `native_compile_evidence.json`, `native_compile.log`: echte Abnahme, unverändert kopiert.
- `QM5_41398_balke-pattern-repair-opt.ex5`, `compiled_baseline.set`: gefrorene neue Artefakte.
- `postcompile_profile_verification.json`: tatsächliche Compiler-Wurzeln und Hashvergleich.
- `card_bound_hardening.json`: erneute semantische Analyse mit aufgelöster Karte.

## Keine doppelte oder verfrühte Matrix

Die Factory hatte bereits drei pending Q12-Anforderungen für 13213 mit identischem
Programmnamen angelegt, teilweise bei den wechselnden Harness-Abnahmen:

- `ed127702-3a08-59fa-888a-c3a0a20a0803` (älterer Harness);
- `0e5eff83-75b8-5c59-99d0-609f5f2fb65c` (erster, nachträglich abgelehnter Wrapper-Nachweis);
- `97908d93-3ff8-5528-9518-8968aea72342` (reparierter, akzeptierter Harness-Anker).

Alle drei wurden vor Compile geschützt mit `BALKE_PATTERN_REPAIR_REVIEW_PENDING`,
`release_on_restart=0`. Das ändert ausschließlich Holds: alle vollständigen
Work-item-Digests sind davor/danach identisch, keine Verdicts/Measurements geändert.
Beleg: `D:/QM/reports/pattern_permission_repair/balke_41398_admission_apply.json`.

Nach erfolgreicher unabhängiger Review ist **nur die letzte, korrekt gebundene
Anforderung** für den frischen Q02 und die neue Matrix vorgesehen. Ältere Duplikate
bleiben gehalten. Erst den deklarierten Harness und seine echten Hashes prüfen,
dann genau diese Hold-Freigabe und den kanonischen Matrixdienst nutzen.

Vorgesehener wirtschaftlicher Umfang: neue Q02-Basis, anschließend maximal 1.085
Jahreszellen + vier WF-Kombinationen gemäß unveränderten Kriterien und begrenzter
Factory-Parallelität. Keine Altzellenübernahme ohne nachgewiesene Build-Äquivalenz.
Vor Durchführung ist Laufzeitbudget aus tatsächlichen Jahreslaufzeiten zu berichten;
hier wurden **null wirtschaftliche Neumessungen** gestartet.

## Tests, Einschränkungen, nächste Verantwortung

**41 fokussierte Tests bestanden**: Generator, neuer Balke-Diff/alle Inputwerte,
Registry-Konsistenz, Hold-Scope, Pattern-Reparatur und native Harness-Integration.
Die zusätzliche Compile-/Hardening-/Setfile-Suite ist ebenfalls vollständig grün:
**144 PASS in 266,98 Sekunden**, einschließlich des langsamen Hardening-Scans des
gesamten EA-Bestands. Die Gruppen überlappen und dürfen nicht addiert werden.

Der Generator-/Karten-Finder-Befund wird als Folge-Audit ausdrücklich geparkt:
Zuerst Balke-Abnahme und neue Basis, danach ein read-only Vergleich alter
Kartenwerte mit den tatsächlich gebundenen Sets. Keine pauschale Neugenerierung
oder Neubewertung des historischen Factory-Bestands ist beauftragt.

Review-Fokus: echte Compile-Evidence und Include-Bindung; Source-Diff zum eingefrorenen
41097; beide Straddle-Seiten; geschlossenes D1; alle Set-Werte; alte Trials weiter
offengelegt; nur eine Q12-Anforderung freigeben. Zusätzlich erbt die Messversion
die alte OnTick-Reihenfolge, in der die News-Sperre vor Management und Exit liegt.
Das wurde für die isolierte Vergleichsmessung nicht still geändert und ist kein
Freibrief für einen späteren Trading-Deploy. Review muss diese Mess-/Deploy-Grenze
explizit beurteilen; notwendige weitere Mechanikänderungen brauchen eine neue
deklarierte Baseline, keinen Umbau des bereits kompilierten Artefakts.

Autorität: `decisions/2026-09-09_balke_pattern_recovery.md`.

## Verbindliche Übergabe

Die unabhängige Review einschließlich bedingter Q02-Übergabe ist als Router-Task
`e1358f42-c9f2-4cd2-89ce-f337b17ac84a` angelegt: `ops_issue`, Priorität 92,
entscheidungstreu auf die Claude-Lane gebunden. Aktueller Zustand: TODO, noch
nicht beansprucht. Die Lane hat drei laufende Aufgaben bei maximal drei Plätzen;
hier wurde weder eine davon abgebrochen noch die Parallelitätsgrenze erhöht.
Das ist eine beauftragte Folgearbeit, keine bereits erteilte Review-Abnahme.

Vollständiger Auftrag: `docs/ops/evidence/2026-09-09_balke_41398_review_handoff.md`.
Checkpoints: `503fb410f5` (Pattern-Reparatur/Nachweise) und `677068883e`
(separate Balke-Version, native EX5, Generator-Korrektur und Regressionen).
Vor Enqueue wurden neue MQ5-/EX5-/Set-Hashes, COMPILE_OK sowie alle drei
dauerhaften Q12-Holds erneut geprüft. Keine wirtschaftliche Messung wurde gestartet.

**Nächster Schritt: unabhängige technische Review, dann echte neutrale Q02-Messung.
Weder bessere Balke-Rendite noch Portfolio-/Live-Freigabe sind bislang belegt.**

# Kandidatenprioritäten und Balke-Status – 9. September 2026

Stand: 09.09.2026, 06:29 Uhr Wien (04:29 UTC). Portfolio-Arbeit bleibt für Sonntag, 13.09.2026, vorgesehen.

## Ergebnis

Bei keinem der aktuell gezählten 16 EA-/Symbol-Paare ist eine Pattern-Filter-Verbesserung in die finale Variante übernommen worden. Die abgeschlossenen Receipts lauten Q12 `NO_FILTER_CHANGE`, Q13 `NO_PARAMETER_CHANGE`, Q14 `KEEP_INCUMBENT`.

Wichtige Korrektur zur bisherigen Kurzform „16 vollständig qualifiziert“: 14 Paare haben einen abgeschlossenen DL089-Matrix-/Selektionsreceipt mit leerer BUY- und SELL-Filterauswahl. QM5_10706/GBPUSD und QM5_11422/USDCAD zählen über ältere Abschlüsse ohne deklarierte Filtersuche; ihre neueren Matrixprogramme sind noch offen. Der aktuelle Census zählt 16, belegt aber nicht 16 abgeschlossene neue Pattern-Suchen. Auch ein Parameter-No-Change-Receipt mit Zero-Trial-Vertrag ist kein Nachweis einer durchgemessenen Parameteroptimierung.

Das bedeutet nicht, dass nie ein Filter in einem einzelnen Zeitfenster besser aussah. Entscheidend ist, dass keine solche Verbesserung die finale Auswahl erreicht hat. Keine Filteraufnahme wird erzwungen.

## Priorisierung bis Sonntag

Dies ist eine Arbeitsrangfolge, keine Renditerangliste und keine Änderung der laufenden Queue.

| Priorität | Kandidaten / Arbeit | Begründung und Abschlussbedingung |
| --- | --- | --- |
| P0 | Evidenzstatus der 16 bereinigen: QM5_11422/USDCAD und QM5_10706/GBPUSD getrennt ausweisen | Alte No-Search-Abschlüsse nicht mit fertig gemessenen neuen Suchen gleichsetzen. 11422 hat 595 gemessene und 490 per Prescreen gesperrte Jahreszellen; Q12 ist dennoch offen. Zuerst Disposition/Weiterverarbeitung prüfen. Bei 10706 bestehen zusätzlich 13 Artifact-Binding-Holds. Das verbessert die Beleglage, erzeugt aber keinen 17. Kandidaten. |
| P1 | Original-Balke QM5_13213/USDJPY, Mess-EA QM5_41097 | Nur neun Jahreszellen ungeklärt; zwei fehlende Artefakt-Bindungen blockieren die betreffenden Testzweige. Bestehendes Programm korrekt vervollständigen und Routing abgleichen, keine zweite 1.085-Zellen-Matrix starten. Danach bleiben Walk-Forward-Auswahl und Folgegates. |
| P1 | QM5_41219/XAUUSD und QM5_41221/EURUSD | Jahreszellen bereits gemessen oder explizit ausgeschlossen; beide Driver stehen auf WF_COMBO_MEASURING. Laufbereitschaft und Abschluss der bestehenden Walk-Forward-Prüfungen haben Vorrang vor einer neuen breiten Suche. Das ist noch kein Q12-PASS. |
| P2 | Balke-Ableitung QM5_21501/USDJPY sowie QM5_9641/WS30, QM5_13013/NDX, QM5_11660/NDX | USDJPY-Lauf ist aktiv; Indexpaare sind lückenlos bis Q11. JPY und Aktienindizes fehlen im gezählten Pool. Vor weiterer Einplanung zunächst gültige Suchverträge, Artefakte und Routing bestätigen. Unterschiedliche Märkte sind nur eine Diversifikationshypothese, kein gemessener Korrelationsvorteil. |
| P3 | QM5_11294/GDAXI und weitere lange Gold-Matrizen | GDAXI steht erst bei Q10; den XAUUSD-Matrixfortschritt desselben EA-IDs nicht diesem Paar zurechnen. Weitere Goldläufe liefern zunächst weniger neue Marktabdeckung. Bereits aktive Arbeit nicht abbrechen. |
| Nicht bevorzugen | QM5_10145/XAUUSD | Aktueller Frontier ECON_FAIL. Kein Aufweichen von Kriterien, nur um den Kandidatenzähler zu erhöhen. |

Der gezählte Pool besteht aus sechs Öl-, vier Edelmetall- und sechs FX-Paaren. Zusätzliche EAs derselben Familie zählen nicht automatisch als unabhängige Diversifikation; insbesondere sind die beiden Balke-Linien nicht zwei unabhängige Strategien.

## Balke: Original noch nicht durch

Original: QM5_13213_balke-gmt3-range-breakout, USDJPY.DWX, Mess-Sibling QM5_41097. Lückenlos bis Q11; Q12 offen, Q13/Q14 nicht abgeschlossen.

Bestehendes Programm: `DL089_QM5_41097_USDJPY_DWX_2019_2025`.

| Jahreszellen | Anzahl | Bedeutung |
| --- | ---: | --- |
| Gemessen | 858 | Tatsächliche Messreceipts |
| PRESCREEN_SKIPPED-Holds | 218 | Ausgeschlossen, nicht gemessen |
| ARTIFACT_BINDING_MISSING-Holds | 2 | Zwei blockierte Vorgänger |
| Weitere offene Zellen | 7 | Nachgelagerte Jahre derselben beiden Testzweige |
| Gesamt | 1.085 | Keine Jahreszelle zum Snapshot aktiv |

Letzte Messung: 05.09.2026, 13:32 Uhr Wien. Dieser ursprüngliche Lauf macht seitdem keinen Messfortschritt.

Die beiden aktuellen Binding-Holds betreffen:

- 2019 / sell_051: `5825adc0-c5df-51bc-8f72-a4bd729a4bbe`.
- 2020 / buy_008: `e4dae175-c161-5522-960f-1dba60cdca50`.

Die Hold-Begründung nennt nicht mehr vorhandene, referenzierte Governed-Artefakte. Deren konkrete fehlende Pfade wurden in diesem Statusaudit nicht rekonstruiert. Wiederherstellung nur mit nachgewiesener Identität; Holds nicht blind lösen.

Der ältere Q12-Recovery-Review-Hold wurde laut aktueller Hold-Tabelle bereits am 01.09. freigegeben. Veraltete Payload-Texte sind hier kein Beleg für eine aktuelle Review-Sperre. Separat besteht ein neuerer generischer Q12-Eintrag für QM5_13213 mit Worker-Rollout-Hold. Das vorhandene Sibling-Programm muss mit dieser Route abgeglichen werden; ein zweites Programm wäre keine sinnvolle Abkürzung.

Die zweite Balke-Linie QM5_21501/USDJPY (Mess-EA QM5_41324) ist ebenfalls bis Q11 durch und noch in Q12. Stand Snapshot: 762 von 1.085 Jahreszellen gemessen, eine aktiv, 322 offen, keine aktiven Holds in dieser Jahresmatrix. Letzte Messung heute um 06:27 Uhr Wien. Diese Linie läuft tatsächlich weiter; auch sie ist noch nicht terminal qualifiziert.

Neun verbleibende Jahreszellen beim Original bedeuten ausdrücklich nicht „nur neun Tests bis portfoliofertig“: Walk-Forward-/Kombinationsprüfung und Q13/Q14 sind zusätzliche Schritte.

## Einzelbelege der 16

| EA | Symbol | Q12-Evidenzklasse |
| --- | --- | --- |
| QM5_10700 | XAUUSD.DWX | Matrix-/Selektionsreceipt; finale Filter leer |
| QM5_10706 | GBPUSD.DWX | Älterer Abschluss ohne deklarierte Filtersuche |
| QM5_11910 | NZDUSD.DWX | Matrix-/Selektionsreceipt; finale Filter leer |
| QM5_11708 | EURUSD.DWX | Matrix-/Selektionsreceipt; finale Filter leer |
| QM5_11421 | EURUSD.DWX | Matrix-/Selektionsreceipt; finale Filter leer |
| QM5_12710 | XTIUSD.DWX | Matrix-/Selektionsreceipt; finale Filter leer |
| QM5_11422 | USDCAD.DWX | Älterer Abschluss ohne deklarierte Filtersuche |
| QM5_20048 | XTIUSD.DWX | Matrix-/Selektionsreceipt; finale Filter leer |
| QM5_20266 | XTIUSD.DWX | Matrix-/Selektionsreceipt; finale Filter leer |
| QM5_12849 | XTIUSD.DWX | Matrix-/Selektionsreceipt; finale Filter leer |
| QM5_12855 | XTIUSD.DWX | Matrix-/Selektionsreceipt; finale Filter leer |
| QM5_13054 | XTIUSD.DWX | Matrix-/Selektionsreceipt; finale Filter leer |
| QM5_1537 | XAGUSD.DWX | Matrix-/Selektionsreceipt; finale Filter leer |
| QM5_21505 | XAGUSD.DWX | Matrix-/Selektionsreceipt; finale Filter leer |
| QM5_21507 | XAUUSD.DWX | Matrix-/Selektionsreceipt; finale Filter leer |
| QM5_11881 | GBPUSD.DWX | Matrix-/Selektionsreceipt; finale Filter leer |

## Quellen, Umfang und Grenzen

Maschinenlesbarer Snapshot: [2026-09-09_candidates_pattern_balke.json](2026-09-09_candidates_pattern_balke.json). Er enthält die Receipt-Pfade und SHA-256-Werte, Work-Item-IDs, Programm-Ledger, Zellzählungen und aktiven beziehungsweise freigegebenen Holds.

Quelle: read-only SQLite-Snapshot von `D:\QM\strategy_farm\state\farm_state.sqlite`, Auswertung mit der aktuellen Census-Logik in `tools/strategy_farm/rebaseline_census.py`, plus Receipt-/Ledger-Dateien. Die Datenbank wurde in einer Lesetransaktion betrachtet; externe Artefaktdateien sind nicht Teil derselben atomaren Transaktion.

Aktuelle Gate-Nomenklatur: Q11 Full-History-Bestätigung, Q12 Pattern-Auswahl, Q13 Parameterstufe, Q14 finale Variantenentscheidung. Historische Gate-Nummern nicht ungeprüft übertragen.

In diesem Auftrag wurden nur der Status geprüft und die Priorisierung dokumentiert. Keine Änderungen an EAs, Live-Terminals, Queue, Holds, Gate-Verträgen oder Verdicts. Keine neue Pipeline gestartet, keine dauerhafte Überwachung eingerichtet und keine Rendite- oder Bestehensgarantie abgeleitet.


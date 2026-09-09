# Pattern-Filter: Folgeanalyse der Messkette und der 16 Kandidaten

Stand: **09.09.2026, 17:19:43 Wien / 15:19:43 UTC**.
Auftrag: „ok, dann weiter mit deinen analysen“. Analyse, keine neue Produktionsänderung.
28 Programme, 44 aktuelle EA-/Kartenquellen, native Berichte und read-only DB-Snapshot.

## Kurzurteil

Die Aussage „Pattern-Filter haben bei keinem EA funktioniert“ ist zu pauschal.
Bei **sechs der 16 betrachteten Programme** existiert vor der abschließenden
Stabilitätsprüfung eine nichtleere Filterauswahl. Vier scheitern mindestens an
der Walk-Forward-Performance, zwei allein an der geforderten Auswahlstabilität.
Bei zehn ist die Auswahl im letzten Auswahlfenster leer. Kein neuer Filter wurde
terminal übernommen. Historische Suchdefekte begrenzen die Aussage zusätzlich.

Balke ist ein sinnvoller erster Reparaturfall: Die frische neutrale Messung 2019
reproduziert **alle 193 abgeschlossenen Trades** des alten Instruments exakt.
Noch liegt kein neues gefiltertes Ergebnis vor. Es gibt somit weder einen
belegten Renditevorteil noch eine belastbare allgemeine Widerlegung der Filter.

## 1. Balke: seit der letzten Übergabe tatsächlich weitergelaufen

- Unabhängige Review PASS; Auftrag `e1358f42-c9f2-4cd2-89ce-f337b17ac84a` steht
  im Router auf REVIEW, nicht mehr IN_PROGRESS. Die Review-Abnahme ist dokumentiert;
  der Auftrag wurde in dieser Analyse nicht geschlossen oder umgeroutet.
- Neuer Q02 `2fc84747-27db-5e88-9568-3fdda6c30769`: **done / PASS**, abgeschlossen
  16:06:13 Wien. Tatsächliches Fenster **02.07.2018–31.12.2022**, nicht pauschal
  „2017–2022“. 888 Trades, PF 1,12, Nettogewinn 46.636,78, MaxDD 21.852,77 im
  Testkonto bei RISK_FIXED=1000. Das ist ein Backtestergebnis, kein erzielter Payout.
- Neues Programm `DL089_QM5_13213_USDJPY_DWX_2019_2025`: **1/1.085 Jahreszellen
  MEASURED, 1.084 pending**. Die gemessene Zelle ist der neutrale 2019-Kontrollarm,
  noch kein Filterarm. Der korrekt reparierte native Harness ist gebunden.
- Genau die aktuelle Q12-Anforderung `97908d93…` wurde durch die unabhängige
  Review freigegeben. Die zwei älteren Duplikate bleiben gehalten.

### Stärkere Kontrollprüfung als ein bloßer Gewinnvergleich

Alte 2019-Zelle `356a3655-5f0a-51ea-84f3-a3d04e2ed714`, neue Zelle
`bc035c74-0000-5a7f-9c21-69a5e92b9529`: Beide Original-HTML-Berichte wurden
mit ihren Summary-Hashes abgeglichen und mit dem vorhandenen Deal-Parser gelesen.
Identisch sind Einstieg/Ausstieg, Symbol, Richtung, Volumen, Preise, Gewinn,
Swap und Ein-/Ausstiegskommission aller 193 Round-Trips. Identitätsfelder wie
EA-ID/Magic sind nicht Teil dieses ökonomischen Vergleichs.

Beide: Nettogewinn **−10.748,50**, PF **0,88**, MaxDD **18.981,05**;
tatsächliche native Kommission **−6.247,80**, Swap 0. Ein Metadatenfeld
`commission_per_lot=0` in der Summary bedeutet hier also nicht kostenfreien Handel.
Ökonomischer Stream-SHA256:
`4a758ddea3f45e4cecba5b143c748195dfd4f0e8595f2d97cf3040d92dba7a08`.

Grenzen: gleicher neutraler Kontrollarm in genau einem Jahr; keine Gleichheit
der kompletten Build-Umgebung und keine Freigabe zur Übernahme alter Filterzellen.
Der Parser etikettiert Reportzeiten intern als UTC; verglichen wurden identische
Report-Uhrzeitwerte, keine hier neu verifizierte Broker-UTC-Umrechnung.

### Laufzeit und Übergabelücke

2019 brauchte **198 Sekunden von Claim bis Verdict**, davon 166 Sekunden ab
Wrapperstart. Zuvor wartete die Zelle rund 20,5 Minuten in der Queue.
Eine rein lineare Hochrechnung mit genau diesem einen Jahreslauf ergibt
**59,67 Terminalstunden für 1.085 Jahreszellen**. Dazu kommen vier WF-Kombinationen,
andere Tickvolumina, Wiederholungen und Queue-Wartezeit. Das ist ein Szenario,
keine Fertigstellungsprognose; Parallelität reduziert nur den nutzbaren Anteil
der Kalenderzeit und ist mit anderen Programmen geteilt.

Die Übergabe verlangte einen Kostenbericht vor der vollen Matrix. Die bestehende
Automatik hat nach Q02 PASS bereits die Matrix materialisiert. In den geprüften
Balke-Übergabe-/Reviewdokumenten fand sich kein solcher vorgezogener Kostenbeleg;
die Kostenrechnung steht jetzt ausdrücklich **nachträglich** hier. Eine Textauflage
allein bildet keine technische Budget-Sperre. Keine rückwirkende Freigabe erfunden.

## 2. Die 16: echte Ablehnungsgründe statt einer Sammelaussage

Die untersuchte Kohorte sind die 16 Paare des Snapshots von 04:29 UTC, keine
neu erteilte Portfolioqualifikation. Inzwischen haben **alle 16** einen terminalen
Matrix-/Selektionsreceipt. Auch 10706 und 11422 sind nun abgeschlossen; der ältere
04:29-Stand „14 Matrixreceipts + zwei No-Search-Abschlüsse“ ist damit überholt.

| EA / Markt | Filter im letzten Auswahlfenster vor WF-Abnahme | WF-Jahre nicht schlechter | Auswahl über frühere Schritte stabil | Ablehnung |
| --- | --- | ---: | ---: | --- |
| 10700 / XAUUSD | 2 Buy + 3 Sell | 1/4 | 2/3 | Performance |
| 10706 / GBPUSD | Buy 52 | 2/4 | 3/3 | Performance |
| 11708 / EURUSD | Sell 11, 53, 79 | 3/4 | 0/3 | Auswahlstabilität |
| 12855 / XTIUSD | Sell 44, 54, 56 | 4/4 | 0/3 | Auswahlstabilität |
| 20266 / XTIUSD | Sell 3, 87 | 1/4 | 0/3 | Beide Kriterien |
| 21507 / XAUUSD | 3 Buy + 2 Sell | 2/4 | 1/3 | Beide Kriterien |

Die übrigen zehn haben im letzten Auswahlfenster keine nichtleere Auswahl.
Bei 12855 sind drei WF-Jahre identisch zur Basis; „4/4 nicht schlechter“ ist
deshalb ausdrücklich nicht „in vier Jahren durch Filter verbessert“.
Die Regeln werden weder wegen dieser Tabelle gelockert noch nachträglich angepasst.

### Vier Messversionen haben schon in der Basis wenig Filterspielraum

Native 2019-Kontrollen: 11421/41162 **3** Einstiegstage, 11910/41332 **8**,
20048/41303 **7**, 21505/41304 **1**. Der Filterarm benötigt gemäß bestehendem
Vertrag mindestens zehn Einstiegstage je Auswahljahr. Das erklärt einen Teil
der leeren Auswahl. Ein Veto kann grundsätzlich die Handelsfolge verändern;
eine monotone Trade-Abnahme wird daher nicht als ungeprüfter Beweis verwendet.
Die Aussage betrifft die konkreten Messversionen, nicht automatisch die heute
anderweitig qualifizierten oder eingesetzten Incumbent-Binaries.

### Zwei Arten ausgelassener Messungen sauber getrennt

Die 16 × 1.085 deklarierten Originalzeilen verteilen sich auf 9.919 MEASURED,
2.072 B2/B5-Prescreen-Holds, 5.366 SKIPPED_EXCLUDED und drei historische INFRA_FAIL.
Letztere können über append-only Ersatzmessungen aufgelöst sein; sie sind nicht
hier als drei offene Blocker gezählt. Terminale Receipts führen Ersatzbelege getrennt.

- **B2/B5: 2.072 ungemessene Jahreszellen** in sechs Programmen: 10706 (650),
  11422 (490), 11881 (655), 12710 (83), 20266 (146), 21507 (48).
  Der bereits bewiesene verlustbehaftete Vorfilter begrenzt diese Suchen.
- **Activity-Floor: 5.366 separate Ausschlüsse.** Je ein Receipt aus allen elf
  betroffenen Kohortenprogrammen wurde strukturell geprüft und sein auslösender
  Einstiegstagewert erneut aus dem Native-Report bestimmt: **11/11 stimmen**.
  Das ist eine gezielte Stichprobe, keine Einzelprüfung aller 5.366 Receipts.
- Die Kohorte enthält 266 historische Messungen der IDs 33/34. Diese sind vor
  einer Aussage über die reparierte Drei-Kerzen-Definition neu zu messen;
  alte Resultate werden nicht überschrieben oder als neue Filterresultate verkauft.

## 3. Setfile-Audit: Entwarnung im geprüften Teil, echte Nachweislücken

- **28/28 eingefrorene Basis-Sets** stimmen bytegenau mit ihrem Ledger-Hash überein;
  keine doppelten Zuweisungen in diesen Sets.
- Alle 196 neutralen Kontroll-Setpfade existieren. 173 besitzen zusätzlich einen
  Hash in der Work-item-Zeile; **173/173 stimmen**. Die übrigen 23 sind an dieser
  Stelle nicht hashgebunden – das ist keine erfundene Vollabnahme.
- 26 der 28 Basis-Sets lassen direkt deklarierte EA-Inputs implizit; meist neun
  Framework-Werte. Das ist eine Provenienzschwäche, nicht automatisch ein anderer
  Wert. Bei Balke zeigt der native Paritätstest gerade keinen Kontrollunterschied.
- 44 aktuelle Source-/Kartenquellen wurden mit den **echten Parserfunktionen** des
  Generators untersucht, ohne dessen Schreibteil auszuführen. 40 Karten sind auflösbar.
  Die alten 27 Messversionen liefern keine direkt nutzbaren Karten-Defaultwerte;
  viele Sibling-Karten verweisen nur auf die Elternmechanik. Prosa ist nicht
  automatisch maschinell vollständig validiert.
- Für sechs Kohorten-Elternkarten sind 42 passende numerische/typisierte Werte
  extrahierbar: **42/42 entsprechen den eingefrorenen Sibling-Basissätzen**.
  Für den neuen Balke sind 23/23 Kartenwerte explizit korrekt; fünf Identitäts-/Risk-
  Werte kommen aus dem geprüften Generator-/Registryvertrag.

Folgerung: **kein nachgewiesener numerischer Kartenwert-Verlust in diesem geprüften
Teilbestand**. Der reproduzierte Generatorfehler war real, erklärt aber nicht
pauschal sämtliche alten No-Change-Resultate. Aktuelle Kartenbytes sind zudem
nicht ohne weiteres als historische, buildgebundene Kartenversion bewiesen.

## 4. Zwei zusätzliche Risiken – dokumentiert, nicht produktiv geändert

**Generatorhärtung:** Ein isolierter Test des unveränderten aktuellen Generators
zeigt, dass eine Karte mit `RISK_FIXED=5000` neben dem generierten
`RISK_FIXED=1000` eine zweite Zuweisung erzeugt. Auch ein symbolischer
`QM_NEWS_COMPLIANCE_DXZ`-Kartenwert wird unverändert als Text ausgegeben.
Die tatsächliche MT5-Auswertung dieses synthetischen Konflikts wurde hier nicht
behauptet oder live getestet. In den 28 untersuchten Basis-Sets gibt es diesen
Doppelwert nicht; unter den extrahierten 44 Karten keine betroffenen Core-Overrides.
Das ist ein reproduzierter zukünftiger Härtungsbedarf, kein neues Balke-Problem.

**Review-Begründung präzisieren:** Die geerbte News-Sperre vor Management/Exit
ist tatsächlich in beiden Balke-Versionen gleich. Daraus folgt aber nicht allgemein,
dass sich ihr Einfluss bei Filtervergleichen „herauskürzt“: Filter verändern,
welche Positionen während einer Nachricht überhaupt offen sind. Einfaches logisches
Gegenbeispiel (keine Marktmessung): Trade A liefert mit Exit-Defekt −100, nach
Korrektur +50; Trade B immer +20. Ein Filter verwirft A. Der Filtervorteil beträgt
mit Defekt +100, ohne Defekt −50, obwohl beide Varianten denselben Exit-Code nutzen.
Die Review bleibt als historische Entscheidung unverändert. Die saubere Aussage
ist: Ergebnis gilt unter der geerbten Mechanik; Übertragbarkeit auf eine korrigierte
Trading-Version bleibt unbewiesen. Der neutrale 2019-Paritätstest löst das nicht.

## 5. Priorisierung der nächsten Analysen

1. **Balke zuerst:** neue Basisjahre und erste reparierte Filterarme beobachten,
   anschließend unveränderte WF-Abnahme. Die laufende Originalaufgabe ist bereits
   `e1358f42` zugeordnet; kein doppelter Auftrag und keine neue Matrix aus diesem Audit.
2. **Danach 11708/EURUSD:** sinnvoller FX-Reparatur-/Stabilitätsfall (3/4 WF-Jahre,
   aber 0/3 Auswahlstabilität); zunächst Prognose-/Implementierungsnachweis statt
   Schwellensenkung. Neue Builds/Messungen bleiben als Folgearbeit explizit geparkt.
3. **12855/XTIUSD als Vergleichsfall**, nicht automatisch höchste Portfolio-Priorität:
   vorhandene Ölkonzentration und drei unveränderte WF-Kontrollen begrenzen den
   Erkenntnisgewinn. Kein weiterer Öl-EA wird als neue unabhängige Diversifikation gezählt.
4. **Vor nächster breiter Build-Welle:** eindeutige Core-Inputs, Enum-Serialisierung
   und buildgebundene Karten-/Inputprofile härten. Vor einem Trading-Deploy außerdem
   die News-/Management-Reihenfolge in einer separat deklarierten Version klären.
   Diese Implementierungen sind hier ausdrücklich geparkt: Auftrag ist Analyse,
   keine Erlaubnis für eine weitere Produktionsänderung oder pauschale Neugenerierung.

## Reproduzierbarkeit und Umfang

Maschinenbeleg: `D:/QM/reports/pattern_permission_repair/measurement_lineage_handoff_20260909.json`;
aktuelle Kartenextraktion: `D:/QM/reports/pattern_permission_repair/current_card_defaults_20260909.json`.
Repo-Mirrors heißen `2026-09-09_pattern_lineage_followup.json` und
`2026-09-09_pattern_current_card_defaults.json` in diesem Ordner.

Werkzeuge: `tools/strategy_farm/session_tools/inspect_pattern_card_defaults_20260909.ps1`
und `audit_pattern_measurement_lineage_20260909.py`. 14 fokussierte Tests bestanden,
einschließlich eines ausdrücklich dokumentierenden Generator-Gegenbeispiels.
Kein EA, keine EX5, kein produktives Set, kein Gate, kein Hold, keine Queue und
kein Konto wurden in diesem Auftrag verändert. Nur Analysewerkzeuge, Tests und
Dokumentation wurden ergänzt. Kein neuer Backtest und keine dauerhafte Überwachung
wurden durch diese Analyse eingerichtet.

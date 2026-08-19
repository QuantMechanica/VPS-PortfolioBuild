# FUNNEL_DIAGNOSIS — wo die Masse stirbt

**Snapshot:** `3472a5d2e1b5` · **Stand:** 2026-08-19 · Work Order Runde 7 §2.1
**Alle Zahlen über den gesamten Bestand, nicht über die 91.**

---

## 1 · Die Überlebenskurve

**[MESSUNG]** 14.358 distinkte (EA, Symbol)-Paare, 2.934 distinkte EA-IDs, 3.722 EA-Verzeichnisse.

| Gate | erreicht | bestanden | Bestehensquote | Anteil an Q02 |
|---|---:|---:|---:|---:|
| **Q02** | 14.350 | 6.877 | 47,9 % | 100 % |
| Q03 | 1.953 | 1.779 | 91,1 % | 13,6 % |
| **Q04** | 6.855 | **626** | **9,1 %** | 47,8 % |
| Q05 | 646 | 303 | 46,9 % | 4,5 % |
| Q06 | 311 | 271 | 87,1 % | 2,2 % |
| Q07 | 271 | 191 | 70,5 % | 1,9 % |
| **Q08** | 204 | **34** | **16,7 %** | 1,4 % |
| Q09_NEWS | 46 | **0** | **0 %** | 0,3 % |
| Q09_PORTFOLIO | 109 | **0** | **0 %** | 0,8 % |
| Q10 | 35 | 34 | 97,1 % | 0,2 % |

**Zwei Engpässe, und beide sind Robustheitsgates:** Q04 (Walk-Forward) lässt **9,1 %** durch, Q08
(Nachbarschaft, PBO, Regime) **16,7 %**. Alles andere ist vergleichsweise durchlässig.

**Zwei Gates lassen null durch.** Q09_NEWS (0 von 46) und Q09_PORTFOLIO (0 von 109) sind keine
Filter, sondern **Dämme** — ihnen fehlt ein Betreiber, nicht die Qualität der Kandidaten. Das ist
dieselbe Klasse wie die Mechanismen ohne Aufrufer und gehört nicht in die Ausbeutediskussion,
sondern in `ORPHANED_MECHANISMS.md`.

**Die Ausbeute, ohne Beschönigung:** 14.350 Paare treten in Q02 ein, **34** bestehen Q08, **17**
liegen im Buch. Das sind **0,12 % bis zum Buch** — noch schlechter als die 0,5 %, gegen die diese
Runde antritt.

---

## 2 · Die 24 unter 250 Handelstagen — die wichtigste Einzeldiagnose, und sie ist eindeutig

Die Work Order vermutete zwei Ursachen: zu kurze Symbol-Historie (Datenproblem) oder zu geringe
Handelsfrequenz (Konstruktionsproblem). **[MESSUNG] Die Aufteilung ist 0 zu 24.**

| | |
|---|---|
| Datenproblem (Historie zu kurz) | **0** |
| Konstruktionsproblem (zu selten gehandelt) | **24** |

Jedes einzelne der 24 Paare hat **6 bis 8 Jahre Historie** (Spanne 2.226 bis 2.966 Kalendertage).
Keines scheitert an Daten. Alle scheitern daran, dass sie **7 bis 30 Mal pro Jahr** handeln:

| Paar | Handelstage | Trades | Spanne (d) | Trades/Jahr |
|---|---:|---:|---:|---:|
| QM5_1328:EURJPY | 52 | 58 | 2.966 | 7,1 |
| QM5_9502:SP500 | 51 | 53 | 2.676 | 7,2 |
| QM5_12623:XAUUSD | 55 | 55 | 2.800 | 7,2 |
| … *(16 weitere zwischen 7,7 und 24,9)* | | | | |
| QM5_13117:EURGBP | 104 | 208 | 2.793 | 27,2 |
| QM5_12778:AUDUSD | 105 | 210 | 2.765 | 27,7 |
| QM5_12781:USDJPY | 114 | 228 | 2.765 | 30,1 |

### Die Schwellenlücke, die daraus folgt

Zwei Kriterien im selben System, die nicht zusammenpassen:

* **Q02-Frequenzboden: ≥ 5 Trades/Jahr** (Ökonomie; darunter RETIRE)
* **Buch-Eintritt: ≥ 250 Handelstage** über die Spanne, also bei 8,2 Jahren **≥ 31 Trades/Jahr**

**Strategien im Band zwischen 5 und 31 Trades/Jahr bestehen die Gates und können anschließend nie
ins Buch.** Alle 24 liegen in diesem Band. Das ist kein Defekt einer Stufe, sondern eine Lücke
zwischen zwei Stufen — und sie ist die konkreteste Konstruktionsanweisung, die diese Runde
hervorbringt:

> **Neue Strategien brauchen ≥ 31 Trades pro Jahr und Symbol, sonst sind sie buchuntauglich,
> egal wie gut sie sind.**

Der Filter wird dabei **nicht** abgesenkt (§7 der Work Order). Er ist nicht das Problem — die
Erzeugung ist es.

---

## 3 · Die Gate-Ablehnungen — individuell, nicht systematisch

**[MESSUNG]** 38 Ablehnungen im 91-Pool (die Work Order nannte 33; die Differenz kommt daher, dass
ich das jeweils **erste** verletzte Gate zähle und Q02/Q03-Fälle mitnehme):

| Gate | Ablehnungen | betroffene Familien |
|---|---:|---|
| Q02 | 4 | 2 — `grimes` 3× |
| Q03 | 2 | 2 |
| **Q04** | **9** | **8** |
| **Q05** | **10** | **9** |
| Q06 | 3 | 3 |
| Q07 | 3 | 3 |
| **Q08** | **7** | **7** |

**Antwort auf §2.1.3: die Ablehnungen sind individuell, nicht systematisch.** Q04 verteilt 9
Ablehnungen auf 8 Familien, Q05 zehn auf neun, Q08 sieben auf sieben. Nur Q02 zeigt eine
Konzentration (`grimes` 3 von 4) — bei vier Fällen ist das kein Muster.

**Das ist ein negativer Befund mit Konsequenz:** es gibt keine Strategie-Familie, deren Reparatur
die Ausbeute hebt. Der Hebel ist generisch — Robustheit als Konstruktionsmerkmal, nicht als
Familieneigenschaft.

**Antwort auf §2.1.4, bestätigt:** **26 von 38 (68 %)** sterben an Q04, Q05 oder Q08 — Walk-Forward,
Stress, Nachbarschaft. Durchweg **Robustheit, nicht Performance**. Die Überlebenskurve in §1 sagt
dasselbe über den Gesamtbestand: die beiden schmalsten Stellen sind Q04 mit 9,1 % und Q08 mit 16,7 %.

> **Die Fabrik filtert derzeit auf Robustheit, statt sie zu erzeugen.** Das ist die Leitlinie für
> `PRODUCTION_DOCTRINE.md`.

---

## 4 · Der Befund, der nicht in der Fragestellung stand

Beim Auszählen des Bestands ist etwas aufgefallen, das die Angebotsfrage direkter berührt als alles
oben:

**[MESSUNG]** 3.361 distinkte EA-IDs haben eine kompilierte `.ex5`. **428 davon waren nie in
`work_items`** — sie sind gebaut und haben die Fabrik nie betreten.

| Baumonat | Anzahl |
|---|---:|
| 2026-06 | 355 |
| 2026-07 | 13 |
| **2026-08** | **60** |

Die 60 aus dem August sind die frisch gebauten QM5_39xxx/40xxx/41xxx — und **56 davon liegen als
`build_ea`-Tickets in REVIEW**. Damit ist der Review-Stau nicht bloß Rückstand, sondern **das
Zulaufventil der Fabrik**: solange er steht, tritt kein neu gebauter EA in Q02 ein.

Die 355 aus dem Juni sind ein eigener Posten (Familien `tv` 35, `carter` 35, `tc` 20, `robo` 19;
Schwerpunkt im ID-Bereich 11000–11999). **Warum sie nie eingereiht wurden, ist nicht geklärt.** Ein
Hinweis: Stichproben (`QM5_1003`, `QM5_10063`, `QM5_11400`) sind **nicht in der Magic-Registry** —
ohne reservierte Magic kann eine Zeile nicht dispatcht werden. Das wäre eine vollständige Erklärung,
ist aber an drei Stichproben geprüft und nicht am ganzen Satz.

**„Nie eingereiht" heißt nicht „bereit zum Einreihen".** Vor einer Freigabe gehört je EA geprüft:
Magic vorhanden, Karte gültig, nicht durch eine neuere Variante ersetzt. Das ist die
Bestandsaufnahme, die `STRATEGY_FILES_INVENTORY.md` fortsetzt — hier steht nur die Zahl.

# Audit-Antwort, Revision 3 — 2026-08-18

**Änderungsmarkierung gegenüber `AUDIT_RESPONSE_2026-08-18.md` (v1) und dessen Revision 2.**
Keine stille Korrektur: was falsch war, steht hier mit der Messung, die es widerlegt.

**Der Prüfer hat mit §1.1 recht, und der Einwand kippt die Schlussaussage.** Das ist der Ausgang, den
er in §9 als möglich benannt hat.

---

# Executive Summary (ersetzt die Fassungen aus v1 und rev2)

**Die 36 % aus rev2 waren keine Bestehenswahrscheinlichkeit.** Sie maßen den Endstand nach 60 Tagen
gegen +10 %, ohne Limitprüfung und ohne Berücksichtigung, dass die Challenge beim **Berühren** des
Ziels endet. Beide Fehler wirken gegenläufig; der erste dominiert.

**Pfadgenau, mit allen drei Bedingungen und First-Touch-Semantik:**

| Sizing | alle 50 Fenster | nur die 36 Fenster mit vollständigem Buch |
|---|---|---|
| 0,44× | 25/50 = **50 %** · Wilson [0,37 – 0,63] | 20/36 = 56 % · [0,40 – 0,70] |
| **1,00×** *(was die Flotte heute fährt)* | 39/50 = **78 %** · [0,65 – 0,87] | **29/36 = 81 %** · [0,65 – 0,90] |
| 1,10× *(Optimum)* | **40/50 = 80 %** · [0,67 – 0,89] | 28/36 = 78 % · [0,62 – 0,88] |

**Verhältniszahl nötig/zulässig — und sie hat sich aufgelöst.** rev2 nannte 0,44× als „zulässige
Obergrenze". **Das war eine Regel, die ich gesetzt habe, keine, die FTMO setzt:** sie verlangte, dass
der schlechteste gemeinsame Tag der letzten acht Jahre unter einem 3-%-Arbeitslimit bleibt, global
angewandt. FTMOs Bedingung ist **fensterweise**, und die Pfadauswertung wendet sie korrekt an. Bei
0,44× gibt es **null** Tageslimit-Verletzungen in 50 Fenstern — die Schranke war weit zu streng.

**Aktualisierte Schlussaussage: das FTMO-Buch ist nicht strukturell unmöglich.** Bei dem Sizing, das
die Flotte bereits fährt, liegt die Bestehensquote bei **78–81 %**, und das Wilson-Band enthält die
80-%-Marke. Die richtige Aussage ist damit **nicht** „nicht tragfähig", sondern:

> **Von der Zielvorgabe nicht trennbar.** Die Punktschätzung liegt an der Marke, das Konfidenzband
> ist ±12 Punkte breit, und die zwei Unsicherheiten, die es verengen könnten, sind beide messbar —
> Population und Intraday-Pfad.

Für das DZ-Buch ändert sich weiterhin nichts.

---

# R3-1 · §1.1 — Endstand statt Höchststand war der Fehler

**[MESSUNG]** Die rev2-Rechnung summierte alle Tages-P&L eines 60-Tage-Fensters und verglich die
Summe mit +10 %. Das ist der **Endstand**. Ein Fenster, das zwischenzeitlich +11 % stand und bei
+6 % endete, zählte als Fehlschlag — obwohl die Challenge in dem Moment bestanden gewesen wäre, in
dem die +10 % berührt wurden.

**Korrigierte Auswertung**, Equity-Pfad Tag für Tag, Abbruch beim ersten Berühren von +10 %:

| Fenster-Ausgang | 0,44× | 1,00× |
|---|---:|---:|
| **besteht (alle drei Bedingungen)** | **25** | **39** |
| Ziel erreicht, aber Limit gerissen | 0 | 0 |
| Tagesverlust gerissen, Ziel nicht erreicht | **0** | 6 |
| Gesamtverlust gerissen, Ziel nicht erreicht | 1 | 2 |
| Ziel nicht erreicht, kein Limit gerissen | 24 | 3 |

**Die bindende Bedingung ist eindeutig und wechselt mit dem Sizing.** Bei 0,44× scheitern 24 von 25
Fehlschlägen ausschließlich daran, dass das Ziel nicht erreicht wird — **kein einziger Tagesbruch**.
Bei 1,00× kippt es: 8 der 11 Fehlschläge sind Limitverletzungen. Das ist ein Renditeproblem bei
niedrigem und ein Risikoproblem bei hohem Sizing, mit einem Optimum dazwischen.

**Die Kategorie „Ziel erreicht, aber Limit gerissen" ist bei beiden Multiplikatoren leer.** Der vom
Prüfer vermutete Überzählungseffekt — Fenster, die +10 % erreichen und unterwegs reißen — existiert
in diesen Daten nicht. Das ist eine Stelle, an der sein Einwand nicht trägt, und sie gehört genannt.

# R3-2 · §2 — der inverse Multiplikator, und er ist nicht linear

**[MESSUNG]** Sweep über die Bestehensquote unter allen drei Bedingungen, 50 Fenster:

| Multiplikator | besteht | Tagesbruch | Gesamtbruch | Ziel verfehlt |
|---:|---:|---:|---:|---:|
| 0,30× | 11 (22 %) | 0 | 1 | 38 |
| 0,44× | 25 (50 %) | 0 | 1 | 24 |
| 0,60× | 30 (60 %) | 0 | 3 | 17 |
| 0,80× | 38 (76 %) | 1 | 5 | 6 |
| 1,00× | 39 (78 %) | 6 | 2 | 3 |
| **1,10×** | **40 (80 %)** | 7 | 2 | 1 |
| 1,20× | 36 (72 %) | 11 | 3 | 0 |
| 1,50× | 27 (54 %) | 22 | 1 | 0 |
| 3,00× | 19 (38 %) | 31 | 0 | 0 |

**Der nötige Multiplikator für 80 % ist ≈ 1,10×**, und er ist zugleich das Maximum der Kurve — über
1,10× fressen die Limitverletzungen mehr, als zusätzliche Rendite einbringt. **Kein Multiplikator im
gesamten Sweep (0,20× bis 4,00×) erreicht mehr als 40 von 50.**

**[SCHLUSS]** Die Verhältniszahl nötig/zulässig aus dem Auftrag lässt sich nicht bilden, weil der
Nenner entfallen ist: 0,44× war keine Zulässigkeitsgrenze. Die aussagekräftige Fassung lautet
stattdessen: **nötig ≈ 1,10×, gefahren 1,00×, Abstand 10 %.**

**Zur Vorabschätzung des Prüfers (0,62× für den Median):** **[MESSUNG]** nachgerechnet und
**nicht bestätigt** — 0,44 × 16,17 = 7,11, und 10/16,17 = 0,62 gilt für den *Median des Endstands*.
Unter First-Touch-Semantik ist die relevante Größe die Bestehensquote, und die erreicht bei 0,60×
bereits 60 %. Die 0,62× ist arithmetisch korrekt für die Größe, für die sie gerechnet wurde, aber
diese Größe ist nach R3-1 nicht mehr die maßgebliche.

**Zur Linearitätsanmerkung — der Prüfer hat recht:** 0,44 × 16,17 = 7,11 gegen gemessene 7,12. Die
rev2-Zahl war eine Skalierung, keine Simulation, und hätte so benannt werden müssen. Die Rechnung in
dieser Revision ist keine Skalierung mehr: Limitprüfungen und First-Touch machen sie nichtlinear,
sichtbar am Umschlagpunkt bei 1,10×.

# R3-3 · §4.1 — Kalendertage, geprüft

**[MESSUNG]** Die Fensterlänge in der Rechnung ist `timedelta(days=60)`, also **60 Kalendertage** —
dasselbe, was FTMO zählt. Der Span von 3.004 Kalendertagen ergibt korrekt 50 Fenster. Die 2.128 sind
Handelstage mit Buchaktivität und gehen nicht in die Fensterbildung ein. **Kein Fehler, keine
Korrektur nötig** — die Prüffrage war berechtigt, die Antwort ist entlastend.

# R3-4 · §4.2 — Population und Selektionsrichtung, und ein Fund im Zusatz

**[MESSUNG]** Gerechnet wurde auf **21 Sleeves mit vollständigen `entry_time`-Stempeln**, nicht auf
den 91 Kandidatenpaaren. **Die Selektionsrichtung ist benennbar und nicht neutral:** es sind die
Sleeves, deren Streams die neuere Emitter-Generation tragen, also überwiegend die kürzlich neu
gebauten oder neu gelaufenen. Ob das die gesündere oder die instabilere Teilmenge ist, ist **nicht
bekannt** — und das ist die größte verbleibende Unsicherheit der ganzen Rechnung.

**Zusatzfrage des Prüfers, und sie trifft: [MESSUNG]** nur **36 von 50 Fenstern tragen das
vollständige Buch**. Die frühen Fenster haben 7, 7, 11, 11, 13, 13, 17, 18, 18, 19 aktive Sleeves;
erst die späteren tragen alle 21.

Auf den 36 vollständigen Fenstern gerechnet **steigt** die Quote leicht statt zu fallen: 1,00× →
**29/36 = 81 %** statt 78 %. Die effektive Stichprobe sinkt damit von 50 auf 36, und das
Wilson-Band wird breiter: **[0,65 – 0,90]**. Grund 2 aus Runde 2 kommt also tatsächlich durch die
Hintertür zurück, wie der Prüfer vermutet hat — aber er verschiebt die Punktschätzung nach oben,
nicht nach unten.

# R3-5 · §3 — die Tail-Behandlung, und warum ihre Prämisse entfallen ist

Der Einwand lautete: 0,44× stammt aus einem In-Sample-Extremwert und ist als Schranke für zukünftige
Extreme zu großzügig. **Der Einwand ist methodisch richtig, seine Prämisse ist aber mit R3-1
entfallen** — 0,44× ist keine operative Schranke mehr, weil die Pfadauswertung die Limits direkt
prüft, statt sie über einen Extremwert zu approximieren.

**Was an seiner Stelle als Tail-Vorbehalt gilt: [SCHLUSS]** die Bestehensquote von 78–81 % ist
in-sample. Der schlechteste gemeinsame Tag der nächsten acht Jahre ist erwartungsgemäß schlechter als
der der letzten acht, und jede zusätzliche Verschärfung trifft die 6–7 Fenster, die bei 1,00× ohnehin
knapp an der Tagesgrenze scheitern. **Größenordnung: [NICHT ENTSCHEIDBAR]** ohne Block-Bootstrap oder
EVT auf der gemeinsamen Tagesverteilung; Kosten: Rechenzeit auf den vorhandenen Tagesreihen, keine
Fabrikzeit.

# R3-6 · §5 — Entwarnung: die Gates haben Drawdown durchgesetzt

**[MESSUNG]** `framework/scripts/q05_stress_medium.py:94` liest
`json.loads(summary_path.read_text(...))` — die Evidenzdatei direkt — und Zeile 212 zieht
`drawdown` aus dieser Zeile. **Die Gates lesen nicht `ea_metrics`.**

**[SCHLUSS]** Es liegt der erste der beiden vom Prüfer genannten Fälle vor: **es fehlt bloß ein
Index, das DD-Kriterium war wirksam.** Damit ist Grund 2 (fehlende Kennzahlenschicht) **kein
Verdikt-Integritätsproblem**, sondern ein Auswertbarkeitsproblem — es blockiert Audit-Fragen, nicht
die Gültigkeit der Gates. Q4 wird durch Indexierung beantwortbar; die Verdikte selbst bleiben, was
sie sind.

**Das entschärft Grund 2 erheblich** und ist der zweite Punkt dieser Runde, an dem die Lage besser
ist als in rev2 beschrieben.

# R3-7 · Neue Reihenfolge der Scheiter-Gründe

| neu | rev2 | Grund | Status |
|---|---|---|---|
| **1** | 3 | **Verdikt-Stabilität und Pooldefinition** — Fisher p = 0,0497, aber 0/12 lässt bis 22 % offen; 4 von 5 Verdikten ohne Hash-Bindung; 37 Verdikte auf zwei EAs unter fremder Identität | unverändert |
| **2** | 1 | **Rendite unter Sizing** — von „strukturell unmöglich" zu **„an der Marke, nicht davon trennbar"**. Nötig ≈ 1,10×, gefahren 1,00× | **stark abgeschwächt** |
| **3** | 2 | **Keine indexierte Kennzahlenschicht** — blockiert die Auswertung, nicht die Gates | **abgeschwächt** (R3-6) |

**Grund 1 rückt an die Spitze, weil die beiden anderen geschrumpft sind, nicht weil er gewachsen
ist.** Er ist jetzt der einzige, der die Gültigkeit von Verdikten selbst berührt.

# R3-8 · Was offen bleibt

| # | offen | Kosten |
|---|---|---|
| A | **Population**: die Rechnung gilt für 21 Sleeves, nicht für die 91 Paare. Wiederholung nach Abschluss von 2.3 | Rechenzeit, keine Fabrikzeit |
| B | **Intraday-Pfad**: realisierte Schlusstags-P&L unterzählt Tagesbrüche. Bei 1,00× gibt es bereits 6; mit Intraday mehr | Rekonstruktion je Sleeve |
| C | **In-Sample**: Auswahl und Bewertung auf denselben Fenstern; Wilson führt das nicht mit | Selektions-Bootstrap, Rechentage |
| D | §6 Wiederholungsmessung an den 12 C1-Paaren — freigegeben, nachrangig zu den Baskets | ~20 h Flottenzeit |

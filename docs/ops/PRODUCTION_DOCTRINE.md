# PRODUCTION_DOCTRINE — Robustheit erzeugen statt filtern

**Snapshot:** `3472a5d2e1b5` · **Stand:** 2026-08-19 · Work Order Runde 7 §4
**Jedes Prinzip gegen den eigenen Bestand geprüft. Wo die Daten widersprechen, folgen die Daten.**

---

## 0 · Die Begründung, gemessen

`FUNNEL_DIAGNOSIS.md`: Q04 lässt **9,1 %** durch, Q08 **16,7 %** — die beiden engsten Stellen des
Trichters sind Robustheitsgates, und **68 %** der Pool-Ablehnungen sterben dort. Die Generierung ist
blind für genau das Kriterium, an dem sie gemessen wird.

---

## 1 · Die Prüfung Prinzip für Prinzip

### 1.1 Einfachheit (≤ 5 freie Parameter) — **an unseren Daten widerlegt**

**[MESSUNG]** 3.695 EAs, freie Strategieparameter aus dem `.mq5` gezählt (Framework-Inputs `qm_*`,
`RISK_*`, `PORTFOLIO_*` abgezogen): Median **9**, p10 **3**, p90 **16**, Maximum 43. Echte Streuung,
also prüfbar.

| Strategieparameter | Q04-Bestehensquote | Q08-Bestehensquote |
|---|---|---|
| 0–2 | 15,0 % (n=20) | 0 % (n=1) |
| 3–4 | **6,1 %** (n=588) | 28,6 % (n=7) |
| 5–6 | 8,2 % (n=1.298) | 13,3 % (n=45) |
| 7–9 | 7,7 % (n=2.120) | 18,8 % (n=64) |
| **10+** | **10,1 %** (n=2.555) | 10,6 % (n=85) |

**Bei Q04 gibt es keinen Einfachheitsvorteil — die parameterreichste Gruppe besteht am häufigsten
(10,1 % gegen 6,1 %).** Eine Obergrenze von 5 Parametern hätte unsere Q04-Quote **gesenkt**, nicht
gehoben. Bei Q08 deutet sich die umgekehrte Richtung an (10+ bei 10,6 % gegen 18,8 % bei 7–9), aber
mit n = 85 gegen n = 64 ist das kein tragfähiger Unterschied.

**Übernahme: nein.** Keine Parameterobergrenze. Wer sie einführt, verschlechtert nach dieser Messung
das Ergebnis am Gate mit dem größten Ausschuss.

*Vorbehalt, den ich selbst anbringe:* Parameterzahl ist ein grober Stellvertreter für
Freiheitsgrade. Zwei Parameter, die über einen Optimierer gefittet wurden, sind gefährlicher als
zwölf, die aus der Kartenspezifikation stammen. Widerlegt ist das **Zählkriterium**, nicht der
Gedanke dahinter.

### 1.2 Plateau statt Peak — **richtig, aber an der falschen Stelle**

Q08 `degenerate_neighborhood` **ist** dieser Test. Er läuft als **letztes** Gate, nachdem ein
Kandidat Q02 bis Q07 durchlaufen hat — im gemessenen Batch (b) waren das je Paar **Stunden**
Fabrikzeit, bevor der Plateau-Test überhaupt startet.

**Übernahme: ja, aber als Vorfilter.** Eine Nachbarschaftsprüfung auf grobem Raster ist billig: drei
Parametervariationen à ±10 % auf einem einzigen Backtest-Fenster. Wer dort schon kippt, kippt auch
in Q08 — und kostet dann nur einen statt sieben Läufe.

### 1.3 Cross-Market-Validierung — **der stärkste Befund der Runde**

**[MESSUNG]** Dieselbe Logik mit **demselben Parametersatz** auf mehreren Symbolen:

| | |
|---|---|
| Q04: EAs, die irgendwo bestehen | 441 — davon **110 (25 %)** auf ≥ 2 Symbolen, 47 auf ≥ 3 |
| **Q08: EAs, die irgendwo bestehen** | **34 — davon 0 (0 %) auf ≥ 2 Symbolen** |
| Q08: EAs, die ≥ 2 Symbole überhaupt **erreicht** haben | **28** |

**Es ist getestet und nie erreicht worden.** 28 Strategien sind mit zwei oder mehr Symbolen bis Q08
gekommen; **keine einzige** hat es auf zweien bestanden. Im Buch selbst bestehen 8 von 20 EAs (40 %)
*irgendein* Robustheitsgate auf ≥ 2 Symbolen — aber eben nie das letzte.

**Übernahme: ja, als härtester Vorfilter.** Und die Zahl sagt, warum: unser Bestand besteht
überwiegend aus **symbolspezifischen** Strategien. Wer Cross-Market erst bei Q08 prüft, erfährt es
nach sieben Gates. Wer es als Eintrittsbedingung prüft, erfährt es in zwei Backtests.

### 1.4 Portfolio von Anfang an — **übernommen, mit vorhandenem Werkzeug**

Der Grenzbeitrag zum Bestand gehört vor die Buchkonstruktion. `sleeve_correlation.py` und
`marginal_contribution_eval.py` existieren bereits; sie laufen heute am Ende. **Übernahme: ja** — als
Rangkriterium bei der Auswahl dessen, was gebaut wird, nicht erst bei der Auswahl dessen, was ins
Buch kommt.

### 1.5 Money Management getrennt — **bereits erfüllt, nicht anfassen**

`RISK_FIXED=1000` im Backtest, `RISK_PERCENT` live, Einstiegslogik davon getrennt. Bestätigt.
**Keine Änderung.**

### 1.6 Inkubation — **übernommen, und in der Produktionsspur billiger**

Ein Zeitraum, den die Strategie nie gesehen hat. Das ist E-3 in anderem Gewand — rückwärts geschnitten
kostet es Trainingsfenster (`E3_DECISION_BRIEF.md`: 9 von 50), **vorwärts kostet es nur Wartezeit.**
Für neu gebaute Strategien ist die Vorwärtsvariante die richtige: bauen, einreihen, und das Verdikt
erst nach N Wochen echter Vorwärtszeit als bestätigt führen.

---

## 2 · Konstruktionsspezifikation — was gelten muss, **bevor** ein Kandidat in Q02 eintritt

Vier Bedingungen. Alle vier sind an vorhandenen Daten geprüft, keine erfordert eine Gate-Änderung,
und jede kostet Bruchteile eines Gate-Durchlaufs.

| # | Bedingung | Warum, mit Zahl | Kosten |
|---|---|---|---|
| **V1** | **≥ 31 Trades/Jahr und Symbol** | 24 Paare bestehen alle Gates und sind trotzdem buchuntauglich, weil sie 7–30 Mal/Jahr handeln. Der Q02-Boden (≥5) ist zu niedrig für Buchtauglichkeit. | fällt im ersten Backtest ab |
| **V2** | **Cross-Market: gleiche Parameter, ≥ 2 Symbole, beide profitabel nach Kosten** | 0 von 28 Strategien haben das bei Q08 geschafft. Der Bestand ist symbolspezifisch. | 2 Backtests |
| **V3** | **Grobe Plateau-Prüfung: ±10 % auf 3 Parametern, kein Vorzeichenwechsel im Netto** | Q08 tötet 83 % — und prüft genau das, nur sieben Gates später | 3 Backtests |
| **V4** | **Grenzbeitrag: Korrelation zum Bestandsbuch < Schwelle** | die Auszahlung sättigt bei ~12 Sleeves, die Finanzierungsrate nicht — was zählt, ist Unähnlichkeit | Rechnung, kein Backtest |

**V1 bis V3 kosten zusammen 6 Backtests je Kandidat.** Ein voller Gate-Durchlauf bis Q08 kostet
Stunden bis Tage. **Der Vorfilter ist um Größenordnungen billiger als der Trichter.**

**Ausdrücklich kein Gate.** Der Vorfilter entscheidet, was **eingereiht** wird, nicht was besteht.
Keine Schwelle im Kontrakt wird berührt (§3.3).

---

## 3 · Erwartete Wirkung auf die Ausbeute — beziffert, damit sie widerlegbar ist

Heutige Ausbeute: **0,12 %** (14.350 Q02-Eintritte → 17 Buch-Sleeves).

Die Rechnung ist bewusst grob und nach unten gerundet:

| Vorfilter | greift auf | erwartete Wirkung |
|---|---|---|
| **V2 Cross-Market** | den Anteil, der Q08 nicht übersteht | Q08 lässt 16,7 % durch; wer V2 besteht, ist per Konstruktion kein Einzelsymbol-Fit. **Erwartung: Q08-Quote steigt auf 25–35 %** |
| **V3 Plateau** | dieselbe Gruppe, früher | verschiebt Ausschuss von Q08 nach vorn — hebt die Ausbeute **nicht**, senkt aber die Kosten je Ausschuss um ~90 % |
| **V1 Frequenz** | die 24 buchuntauglichen | hebt die Buch-Konversion, nicht die Gate-Quote |

**Zusammen: Ausbeute von 0,12 % auf geschätzt 0,3–0,5 %.** Das ist ein Faktor 3–4, kein Faktor 8 —
und `SUPPLY_TARGET.md` §3 zeigt, was das wert ist: **der Kandidatenbedarf je zusätzlichem Sleeve
fällt von ~845 auf ~250.**

**Widerlegungskriterium, vorab:** wenn nach 200 mit V1–V3 vorgefilterten Kandidaten die
Q08-Bestehensquote nicht messbar über 16,7 % liegt, ist die Doktrin Folklore und wird gestrichen.

---

## 4 · Was ich ausdrücklich nicht behaupte

* **Nicht, dass Unger falsch liegt.** Sein Einfachheitsprinzip ist an *unserem* Bestand nicht
  belegbar — und unser Bestand hat einen Median von 9 Strategieparametern bei einem Framework, das
  ohnehin 23 Inputs mitbringt. Das ist womöglich eine Aussage über unser Framework, nicht über sein
  Prinzip.
* **Nicht, dass V1–V3 die Ausbeute sicher heben.** Die Erwartung in §3 ist eine Schätzung mit
  Widerlegungskriterium, keine Messung.
* **Nicht, dass Robustheitsgates zu streng sind.** Sie messen richtig. Was fehlt, ist die Erzeugung
  dessen, was sie messen.

# Audit-Antwort, Revision 4 — 2026-08-18

**Änderungsmarkierung gegenüber `audit_rev3.md`.** Diese Runde bestreitet die rev3-Aussage nicht, sie
misst deren vier Unsicherheiten. Drei davon sind jetzt beziffert, eine bleibt eine Spanne — und die
Spanne ist so breit, dass sie die Schlussaussage bestimmt.

---

# Executive Summary (ersetzt rev3)

**Die Punktschätzung von 81 % existiert nicht mehr als einzelne Zahl.** Bei 1,00× liegt die
Bestehensquote in einer Spanne von **26 % bis 78 %**, und die Breite kommt fast vollständig aus einer
einzigen ungemessenen Größe: dem Intraday-Pfad.

| Unsicherheit | Richtung | Größenordnung in Prozentpunkten |
|---|---|---|
| **Intraday** (§1) | **nach unten** | **bis −52 pp bei 1,00×; 0 pp bei 0,44×** |
| **Flip-Instabilität** (§5) | nach unten | −6 pp im Median, Band 17 pp |
| **Population** (§4) | unbekannt | Aussage gilt für 18 von 91 Pool-Paaren |
| **Selektion** (§3) | **nach oben, gemessen** | +12 pp im zeitlichen Holdout |

**Die Handlungsempfehlung folgt nicht aus der Punktschätzung, sondern aus der Spannenbreite:**

> **Bei 0,44× ist die Bestehensquote 50 % — und zwar unabhängig davon, wie der Intraday-Pfad
> ausfällt. Bei 1,00× ist sie irgendwo zwischen 26 % und 78 %.** Übersizing kostet nicht nur
> erwartete Quote, es kostet **Gewissheit**. Das ist die belastbare Fassung der Asymmetrie, die §2
> verlangt hat.

**Schlussaussage: die Trennung von der Zielvorgabe ist nicht erfolgt, aber die Frage hat sich
verschoben.** Sie lautet nicht mehr „schafft das Buch 80 %", sondern „wie groß ist der
Intraday-Abschlag" — und das ist eine Messfrage mit bekannten Kosten, keine offene Wette.

---

# R4-1 · §1 Intraday — gemessen, mit einer Schranke statt einer Schätzung

## Die M1-Rekonstruktion ist nicht machbar, und zwar aus einem anderen Grund als erwartet

**[MESSUNG]** Die Sleeve-Streams tragen je Trade `(entry_date, close_date, net, mae)` — **Datums-,
keine Zeitstempel**. Eine M1-Aggregation gleichzeitig offener Positionen ist damit aus dem
vorhandenen Bestand **nicht rekonstruierbar**: es fehlt nicht die M1-Historie (59 Einträge unter
`D:\QM\mt5\T1\Bases`), es fehlt die Zuordnung Trade → Minute.

**Kostenschätzung, wie in §1.6 verlangt:** eine echte Intraday-Rechnung verlangt einen Re-Run der
Sleeves mit Equity-Snapshots je Bar, nicht eine Auswertung vorhandener Artefakte. Das ist ein
Vollbatch in der Größenordnung von (b) — **Tage Fabrikzeit**, und der kritische Pfad hat sie nicht.

## Was stattdessen möglich war: MAE als Intraday-Boden

Die Streams tragen je Trade den **Maximum Adverse Excursion**. Das ist der schlechteste Punkt, den
der Trade durchlaufen hat — genau die Größe, die FTMO misst und der Tagesschluss verschweigt.

**[MESSUNG]**

| | Schlusskursbasis | MAE-Boden |
|---|---:|---:|
| schlechtester Tag | −6,95 % | **−9,32 %** |
| Tage ≤ −5 % | 20 | **237** (× 11,8) |
| Bestehensquote 0,44× | 50 % | **50 %** *(unverändert)* |
| Bestehensquote 1,00× | 78 % | **26 %** |
| Bestehensquote 1,10× | 80 % | **26 %** |

## Und sofort die Einschränkung — ich wiederhole hier einen Fehler, den ich schon korrigiert habe

**Der MAE-Boden summiert die MAE aller an einem Tag schließenden Trades.** Das unterstellt, dass alle
ihren schlechtesten Punkt **gleichzeitig** erreichen. Das ist exakt der „Summe der schlechtesten
Tage"-Fehler, den ich in rev2 an der Ko-Exzedenz korrigiert habe — hier in neuer Gestalt, und ich
benenne ihn, bevor jemand die 26 % als Ergebnis zitiert.

Zweiter Vorbehalt: die MAE wird dem **Schlusstag** zugerechnet, obwohl die Exkursion bei
mehrtägigen Trades an einem früheren Tag lag.

**Korrekte Fassung: 26 % und 78 % sind zwei Schranken, beide nachweislich in bekannter Richtung
falsch.**

* **78 % ist eine Obergrenze** — sie unterstellt, dass es keinerlei Intraday-Exkursion über den
  Tagesschluss hinaus gibt.
* **26 % ist eine Untergrenze** — sie unterstellt perfekte Gleichzeitigkeit aller Exkursionen.
* Die Ko-Exzedenz-Messung aus rev2 gibt den Korrekturfaktor für genau diese Annahme: die naive Summe
  überschätzte den echten gemeinsamen Tag um **Faktor 4,7**. Wendet man dieselbe Größenordnung an,
  liegt die Wahrheit deutlich näher an der Obergrenze als an der Untergrenze — **aber das ist eine
  Analogie, keine Messung**, und ich führe sie nicht als Zahl.

**Der belastbare Teil ist die Struktur, nicht die Höhe:** bei 0,44× ändert der Intraday-Boden die
Quote um **0 Punkte**, bei 1,00× um bis zu **52**. Die Unsicherheit ist vollständig eine Funktion des
Sizings.

# R4-2 · §2 — das Optimum bei 1,10× ist Rauschen, der Abgrund bei 1,20× ist es nicht

**[MESSUNG]** Feiner Sweep, beide Stichproben, Wilson-Bänder:

| Multiplikator | 50 Fenster | 36 vollständige |
|---:|---|---|
| 0,90× | 76 % [0,63–0,86] | 78 % [0,62–0,88] |
| 0,95× | 76 % [0,63–0,86] | 78 % [0,62–0,88] |
| 1,00× | 78 % [0,65–0,87] | **81 %** [0,65–0,90] |
| 1,05× | 76 % [0,63–0,86] | 78 % [0,62–0,88] |
| 1,10× | **80 %** [0,67–0,89] | 78 % [0,62–0,88] |
| 1,15× | 80 % [0,67–0,89] | 78 % [0,62–0,88] |
| **1,20×** | **72 %** [0,58–0,83] | **69 %** [0,53–0,82] |
| 1,30× | 66 % [0,52–0,78] | 61 % [0,45–0,75] |

**[MESSUNG]** Bootstrap über Fenster, 400 Ziehungen, Verteilung des Optimums:
1,10× **52,8 %** · 0,80× **22,0 %** · 1,00× **16,8 %** · 0,90× 8,5 % · **1,20× und darüber: 0,0 %**.

**[SCHLUSS] Der Prüfer hat recht: „nötig ≈ 1,10×" ist nicht haltbar.** Die belastbare Fassung:

* **Plateau 0,90× – 1,15×**, Quoten 76–81 %, sämtliche Bänder überlappend — innerhalb dieses Bereichs
  ist kein Multiplikator vom anderen unterscheidbar.
* **Kante ab 1,20×**: der Abfall ist auf beiden Stichproben konsistent, und **keine einzige** von 400
  Bootstrap-Ziehungen legt das Optimum dorthin.

**Asymmetrie, ausdrücklich:** von 1,00× auf 0,90× kostet **2 Punkte**. Von 1,15× auf 1,30× kostet
**14 Punkte**. Zusammen mit R4-1 verschärft sich das: Übersizing kostet Quote *und* Gewissheit,
Untersizing kostet wenig von beidem.

# R4-3 · §3 Selektions-Bias — gemessen, und er geht nach oben

**[MESSUNG]** Q2, die in Runde 2 nie genannte Zahl: das Selektionsuniversum umfasst
**107.446 erteilte Verdikte** über **14.358 distinkte (EA, Symbol)-Paare** und 24.822
(EA, Symbol, Phase)-Tripel, davon **74.482 allein Q02-Auswertungen**. Nicht 3.722.

**[MESSUNG]** Zeitlicher Holdout bei 1,00× — die Gates liefen auf der frühen Historie:

| Zeitraum | Quote | Wilson |
|---|---|---|
| erste Hälfte 2017–2021 *(Gate-Ära)* | 18/25 = **72 %** | [0,52 – 0,86] |
| zweite Hälfte 2021–2025 *(Holdout)* | 21/25 = **84 %** | [0,65 – 0,94] |
| vollständiges Buch, erste Hälfte | 12/18 = 67 % | [0,44 – 0,84] |
| vollständiges Buch, zweite Hälfte | 17/18 = **94 %** | [0,74 – 0,99] |

**Die vorhergesagte Optimismus-Verzerrung von 10–20 Punkten nach unten tritt nicht ein — gemessen
wird das Gegenteil, +12 Punkte nach oben.** Das sage ich so deutlich wie bei §1.1.

**[SCHLUSS] mit benanntem Konfundent:** die zweite Hälfte ist auch der Zeitraum, in dem das Buch
vollständig ist und in dem die Marktregime andere waren. Der Vergleich innerhalb der vollständigen
Fenster (67 % gegen 94 %) kontrolliert den Buchumfang teilweise, **das Regime nicht**. Ich kann
Selektionsfreiheit und günstiges Regime nicht trennen — die Messung schließt nur aus, dass ein
großer Abwärts-Bias unbemerkt vorliegt.

**Zur formalen Korrektur:** Deflated Sharpe Ratio ist nicht rechenbar — `sharpe` ist in `ea_metrics`
zu 0,1 % gefüllt (63 von 62.457). White's Reality Check und Hansen SPA verlangen die
Renditereihen **aller** getesteten Kandidaten; verfügbar sind sie für 21. **[NICHT ENTSCHEIDBAR]**,
Beschaffung = derselbe Vollbatch wie in R4-1.

# R4-4 · §4 Population — die härteste Einschränkung, und sie ist beziffert

**[MESSUNG]** Von den **91 Pool-Paaren** haben **18** eine nutzbare Tagesreihe. Die übrigen 73 sind
`UNSCORABLE`: **61 × `challenge_engine_ineligible`**, **12 × `entry_time_incomplete`**.

Die Rechnung läuft auf **21 Sleeves**, von denen also **18 im Pool liegen** und 3 außerhalb.

**Damit ist die Kennzeichnung, die §4.4 verlangt, verbindlich:** *jede Quote in diesem Bericht ist
eine Aussage über 21 Sleeves, davon 18 aus dem Kandidatenpool — nicht über den 91-Paare-Pool.*

**Kosten der Vervollständigung:** die 12 `entry_time_incomplete` brauchen einen Re-Run mit dem reichen
Emitter — das ist genau, was Batch (b) tut, und (b) hat 72 von 78 Zeilen abgeschlossen. Die 61
`challenge_engine_ineligible` sind eine andere Klasse: sie scheitern an Gate-Bedingungen, nicht an
Telemetrie, und kommen durch einen Re-Run nicht dazu.

**Erwartung, vorab formuliert wie verlangt:** mehr Sleeves senken die Ko-Exzedenz **und** erhöhen die
Zahl gleichzeitig offener Positionen. R4-1 zeigt, dass die Intraday-Amplitude der bindende Term ist —
**[VERMUTUNG]**, dass der zweite Effekt überwiegt und ein größeres Buch die Quote bei 1,00× eher
senkt als hebt. Prüfbar, sobald die 12 nachgezogen sind.

# R4-5 · §5 Flip-Sensitivität — das Band, das allein aus Verdikt-Instabilität folgt

**[MESSUNG]** 1.000 Ziehungen, jeweils 21 % der Sleeves (4 von 21) ersatzlos entfernt, 1,00×, auf den
36 vollständigen Fenstern:

| | |
|---|---:|
| Basis (alle 21) | 81 % |
| **Median unter Flip-Instabilität** | **75 %** |
| p5 / p95 | **67 % / 83 %** |
| min / max | 42 % / 89 % |
| **Band** | **17 Prozentpunkte** |

**[SCHLUSS]** Die 81 % sind der Fall „kein Sleeve fällt aus". Unter der gemessenen Flip-Rate ist der
Erwartungswert **75 %**, und das 90-%-Band reicht von 67 auf 83. **Verdikt-Instabilität kostet
6 Punkte im Median und öffnet ein 17-Punkte-Band** — das ist die Zahl, die Grund 1 quantifiziert.

*Die Variante „ersetzen statt entfernen" ist nicht gerechnet: es gibt keine Ersatzkandidaten mit
Tagesreihe (R4-4). Das ist keine Auslassung, sondern dieselbe Populationsgrenze.*

# R4-6 · §6 Tail — der Extremwert ist kein Einzelfall

**[MESSUNG]** Verteilung der gemeinsamen Tagesverluste, 2.128 Handelstage, 1.085 Verlusttage:

| Schwelle | Tage | Häufigkeit |
|---|---:|---|
| ≥ 90 % des Maximums (≤ −6,25 %) | 3 | 1 je 709 Handelstage |
| ≥ 80 % (≤ −5,56 %) | 11 | 1 je 193 |
| ≥ 70 % (≤ −4,86 %) | 27 | 1 je 79 |
| ≥ 50 % (≤ −3,47 %) | 111 | 1 je 19 |
| **≤ −5,0 % (die FTMO-Grenze)** | **20** | **≈ 2,5 je Jahr** |

**[SCHLUSS]** Der schlechteste Tag ist **kein isolierter Ausreißer** — der Tail ist dicht besetzt und
fällt glatt ab. Das entschärft den In-Sample-Extremwert-Einwand aus Runde 3 §3: die 6 Fensterbrüche
bei 1,00× stammen aus 20 solchen Tagen, nicht aus einem. Eine EVT-Extrapolation über das beobachtete
Maximum hinaus ist deshalb **nicht** der entscheidende Hebel; die Rate von ~2,5 Grenztagen pro Jahr
ist aus 8 Jahren ordentlich geschätzt.

**Erwartete Brüche in einem künftigen 8-Jahres-Zeitraum bei 1,00×:** in derselben Größenordnung wie
beobachtet, also **~20 Grenztage → ~6 Fensterbrüche**, sofern das Regime sich nicht verschiebt.
Ein Sicherheitsaufschlag ist damit vertretbar klein — **und wird von R4-1 um Größenordnungen
überstimmt**, weil dort dieselben Tage intraday tiefer laufen.

# R4-7 · Zur §7-Anmerkung des Prüfers: die leere Kategorie ist eine Definition

**Angenommen und korrigiert.** In rev3 habe ich „die Kategorie *Ziel erreicht, aber Limit gerissen*
ist leer" als Befund geführt. Unter First-Touch-Semantik ist sie **konstruktionsbedingt leer**: die
Auswertung bricht beim ersten Berühren von +10 % ab, also kann danach kein Limit mehr reißen. Das ist
eine Eigenschaft der Methode, keine Evidenz über das Buch.

# R4-8 · Reihenfolge der Scheiter-Gründe

| neu | rev3 | Grund | Änderung |
|---|---|---|---|
| **1** | *(neu)* | **Intraday ungemessen** — bestimmt allein eine 52-Punkte-Spanne bei 1,00× | neu an der Spitze |
| **2** | 1 | **Verdikt-Stabilität** — jetzt beziffert: −6 pp Median, 17 pp Band | unverändert gültig, jetzt mit Zahl |
| **3** | *(neu)* | **Population** — 18 von 91 Pool-Paaren | war Vorbehalt, ist jetzt Grund |
| — | 2 | *Rendite unter Sizing* | aufgelöst: im Plateau 0,90–1,15× nicht bindend |
| — | 3 | *Kennzahlenschicht* | bleibt Auswertbarkeitsproblem (R3-6) |

# R4-9 · Handlungsempfehlung zum Sizing

**Nicht über 1,00× gehen, und 0,90× ist die defensivere Wahl.** Begründung aus drei Messungen:

1. Im Plateau 0,90×–1,15× ist kein Multiplikator statistisch besser als ein anderer (R4-2).
2. Ab 1,20× fällt die Quote konsistent, und keine Bootstrap-Ziehung legt das Optimum dorthin (R4-2).
3. **Die Intraday-Unsicherheit wächst mit dem Sizing und verschwindet bei 0,44× vollständig**
   (R4-1). Wer nicht weiß, wie tief die Tage intraday laufen, kauft mit niedrigerem Sizing keine
   Rendite, sondern Robustheit gegen genau diese Unwissenheit.

**Die eine Messung, die diese Empfehlung ändern könnte, ist der Intraday-Pfad** — und ihre Kosten
sind bekannt: ein Vollbatch mit Equity-Snapshots, Größenordnung Tage Fabrikzeit.

# Audit-Antwort, Revision 5 — Abschluss auf der alten Basis

**Gilt für Snapshot `3472a5d2e1b5`, Stand 2026-08-18.** (`BASELINE_SNAPSHOT.md`)
**Änderungsmarkierung gegenüber `audit_rev4.md`.**
**Reproduzierbar:** `tools/strategy_farm/portfolio/audit_intraday_sizing_sweep.py` ·
Artefakt `artifacts/audit_intraday_sizing_sweep_20260818.json`

> Nach diesem Dokument wird auf dieser Datenbasis nicht mehr gerechnet (§3 der Work Order Runde 5).
> Was offen bleibt, steht in `OPEN_QUESTIONS.md` mit Kostenschätzung — nicht als nächste Messung.

---

## Vorbemerkung: rev2 bis rev4 waren nicht reproduzierbar

Alle Zahlen der Revisionen 2 bis 4 entstanden inline. Sie waren belegt, aber nicht nachrechenbar —
und das ist genau die Eigenschaft, die §5 für tragende Aussagen ausschließt. Diese Revision steht
auf einem eingecheckten Harness, der die rev4-Anker **selbst prüft** und die Ausgabe verweigert,
wenn sie nicht stimmen.

**Reproduziert, exakt:** 21 Sleeves · 2.128 Handelstage · Spanne 3.004 Kalendertage · schlechtester
Tag −6,95 % (Schluss) und −9,32 % (MAE) · 20 bzw. 237 Tage ≤ −5 % · 39/50 = 78 % und 29/36 = 81 %
bei 1,00× · 18/25 = 72 % und 21/25 = 84 % über die Kalenderhälften.

**Ein Anker reproduziert nicht, und das steht hier statt versteckt zu bleiben:** rev4 nennt für den
MAE-Boden bei 1,00× **26 %**, der Harness rechnet **28 %** (14 statt 13 von 50 Fenstern). Jede
Schlusskurs-Zahl stimmt fensterscharf, die Abweichung sitzt also allein in der Boden-Variante und
beträgt ein Fenster von fünfzig. Sie ändert keine Aussage — beide Lesarten sagen dasselbe — aber
**rev5 führt 28 %, weil 28 % die nachrechenbare Zahl ist.**

---

# Executive Summary (ersetzt rev4)

**Die Empfehlung 0,90× fällt. Die verteidigbare Größe ist 0,60×, und dort liegt die Bestehensquote
bei 60 %.**

Das ist die Kernzahl, die §1.3 verlangt hat: der größte Multiplikator, bei dem beide Messverfahren
noch beieinander liegen — der Punkt, bis zu dem die Aussage **unabhängig davon ist, welches Verfahren
recht hat.**

| | Schlusskursbasis | MAE-Boden | Differenz |
|---|---:|---:|---:|
| 0,44× | 50 % | 50 % | 0 pp |
| **0,60×** | **60 %** [0,46–0,72] | **58 %** [0,44–0,71] | **2 pp** |
| 0,65× | 66 % | 58 % | 8 pp |
| 0,90× | 76 % | 36 % | **40 pp** |
| 1,00× | 78 % | 28 % | **50 pp** |

**Die Schlussaussage in einem Satz:**

> **Es gibt keinen Multiplikator, bei dem das Buch die 80 % nachweislich erreicht, ohne dass die
> Aussage von einer ungemessenen Größe abhängt.** Wo sie nicht abhängt, liegt die Quote bei 60 %.
> Wo sie 80 % erreicht, ist sie eine Wette auf das Messverfahren.

Damit ist die Frage aus rev4 — „wie groß ist der Intraday-Abschlag" — nicht kleiner geworden,
sondern präziser: sie beginnt **bei 0,65×**, nicht irgendwo unterhalb von 1,00×.

## Die vier Unsicherheiten, endgültige Fassung

| Unsicherheit | Richtung | Größenordnung | ohne neue Daten schließbar? |
|---|---|---|---|
| **Intraday** (R5-1) | **nach unten** | 0 pp bis 0,60× · 8 pp bei 0,65× · 40 pp bei 0,90× · 50 pp bei 1,00× | **nein** — verlangt Equity-Snapshots im Lauf |
| **Population** (rev4 R4-4) | unbekannt | Aussage gilt für 18 von 91 Pool-Paaren | **nein** — verlangt Läufe mit dem reichen Emitter |
| **Flip-Instabilität** (rev4 R4-5) | nach unten | −6 pp Median, 17 pp Band **bei 1,00×** | teilweise — der Wert bei 0,60× ist **nicht gemessen** (OQ-6) |
| **Selektion** (R5-2) | **korrigiert: nicht unterscheidbar von null** | rev4 las +12 pp; bei konstanter Buchvollständigkeit **+3 pp** mit überlappenden Bändern | **nein** — verlangt ein echtes Holdout (E-3) |

**Drei von vier sind Datenmangel.** Sie schließen sich durch kein weiteres Verfahren auf denselben
3.004 Tagen — das ist die Begründung für den Rechenstopp und zugleich die für den vereinten Batch.

---

# R5-1 · §1 Die Sweep-Lücke — der Einwand trifft, und er trifft härter als erwartet

## Was rev4 behauptet hat und was daran nicht gedeckt war

rev4 empfahl 0,90× mit zwei Begründungen. Die erste — Untersizing kostet im Plateau 2 Punkte —
steht. Die zweite — 0,90× „neutralisiert die gesamte Intraday-Unsicherheit" — war eine
**Interpolation zwischen zwei Stützstellen** (0 pp bei 0,44×, 52 pp bei 1,00×) durch einen Bereich,
in dem die Funktion nachweislich steil verläuft. Der Einwand ist berechtigt.

## Beide Kurven über das volle Raster

**[MESSUNG]** 50 Fenster (alle) und 36 Fenster (vollständiges Buch), Schlusskursbasis gegen
MAE-Boden:

| Multiplikator | Schluss 50 | MAE 50 | Diff | Schluss 36 | MAE 36 | Diff |
|---:|---:|---:|---:|---:|---:|---:|
| 0,44 | 50 % | 50 % | **0** | 56 % | 56 % | **0** |
| 0,50 | 56 % | 56 % | **0** | 61 % | 61 % | **0** |
| 0,55 | 56 % | 56 % | **0** | 61 % | 61 % | **0** |
| **0,60** | **60 %** | **58 %** | **2** | 64 % | 61 % | 3 |
| 0,65 | 66 % | 58 % | 8 | 69 % | 58 % | 11 |
| 0,70 | 76 % | 60 % | 16 | 78 % | 56 % | 22 |
| 0,75 | 74 % | 56 % | 18 | 75 % | 50 % | 25 |
| 0,80 | 76 % | 46 % | 30 | 78 % | 36 % | 42 |
| 0,85 | 78 % | 42 % | 36 | 81 % | 31 % | 50 |
| **0,90** | 76 % | 36 % | **40** | 78 % | 28 % | **50** |
| 0,95 | 76 % | 24 % | 52 | 78 % | 14 % | 64 |
| 1,00 | 78 % | 28 % | 50 | 81 % | 19 % | 61 |
| 1,10 | 80 % | 24 % | 56 | 78 % | 14 % | 64 |
| 1,20 | 70 % | 16 % | 54 | 67 % | 6 % | 61 |
| 1,30 | 62 % | 14 % | 48 | 56 % | 3 % | 53 |

## Die Kernzahl

**[MESSUNG] Der größte Multiplikator, bei dem beide Kurven innerhalb von 5 Punkten liegen: 0,60×.
Die erste Divergenz liegt bei 0,65× (8 Punkte).**

Und die Zahl ist **robust gegen die Wahl der Schwelle** — das ist wichtig, weil die 5 Punkte gesetzt
und nicht abgeleitet sind:

| Schwelle | größter übereinstimmender Multiplikator |
|---|---|
| 2 pp | 0,55× |
| **5 pp** | **0,60×** |
| 10 pp | 0,65× |
| 15 pp | 0,65× |

Von 2 bis 15 Punkten bewegt sich die Antwort zwischen 0,55× und 0,65×. **Kein Kriterium führt in die
Nähe von 0,90×.**

*Zur Konstruktion:* gezählt wird als Lauf von unten, nicht als Maximum über das Raster. Ein Gitterpunkt
oberhalb einer Divergenz, der zufällig wieder übereinstimmt (1,00× mit 50 gegen 0,95× mit 52), ist
kein Beleg, dass der Bereich sicher ist.

## Was das für die Bestehensquote heißt — unbequem, wie verlangt

**Bei 0,60× liegt die Quote bei 60 %** [Wilson 0,46–0,72] auf 50 Fenstern, 64 % auf den 36
vollständigen. Das ist **20 Punkte unter der Zielvorgabe von 80 %**, und das obere Ende des
Konfidenzbandes reicht nicht an sie heran.

Damit ist die Lage sauber beschrieben, und sie ist eine Entscheidung, keine Rechnung:

* **0,60× sizen** ⇒ ~60 % Bestehensquote, und diese Zahl hängt **nicht** davon ab, wie tief die Tage
  intraday laufen. Ziel verfehlt, aber gewusst.
* **0,90× sizen** ⇒ die wahre Quote liegt **irgendwo zwischen 36 % und 76 %**. Die Obergrenze
  erreicht das Ziel nicht, und die Unterschärfe ist eine Größenordnung.
* Ein Sizing, das 80 % erreicht und dabei messverfahrensunabhängig ist, **existiert im Raster
  nicht.**

## Die Einschränkung, die auch für diese Runde gilt

Der MAE-Boden bleibt, was rev4 über ihn gesagt hat: **eine Untergrenze, die perfekte
Gleichzeitigkeit aller Exkursionen unterstellt** und mehrtägige Exkursionen dem Schlusstag zurechnet.
Die Ko-Exzedenz-Messung aus rev2 legt nahe, dass die Wahrheit näher an der Schlusskurskurve liegt —
**Analogie, keine Messung**, und sie wird auch hier nicht als Zahl geführt.

**Aber der Schluss dieses Abschnitts hängt nicht daran.** Der Grenz-Multiplikator ist genau der
Punkt, an dem es **egal ist**, welche der beiden Kurven näher an der Wahrheit liegt. Das ist die
Eigenschaft, die ihn zur belastbaren Empfehlung macht — und der Grund, warum diese Aussage stärker
ist als jede Punktschätzung aus rev4.

## Handlungsempfehlung, ersetzt R4-9

> **0,60× als verteidigbares Sizing.** Nicht weil es die Quote maximiert — das tut es nicht —,
> sondern weil es die einzige Größe ist, bei der die Quote nicht vom ungemessenen Intraday-Pfad
> abhängt. Wer höher geht, kauft eine Quote, deren Herkunft er nicht kennt.
>
> **Die eine Messung, die diese Empfehlung ändern kann, ist unverändert der Intraday-Pfad** — und
> ihre Kosten stehen jetzt in `BATCH_SPEC_MERGED.md`, statt als „Größenordnung Tage" geschätzt zu
> werden.

---

# R5-2 · §2 Die Konfundierung im Holdout — rev4 hat zwei Effekte unter einem Namen geführt

## Der Konstruktionsfehler

rev4 las 67 % gegen 94 % als „erste gegen zweite Hälfte des vollständigen Buches". Diese Teilung
erfolgte **nach Position in der Liste der vollständigen Fenster**, nicht nach Kalenderzeit. Die
vollständigen Fenster sind die Indizes 10–14, 16–26 und 30–49 von 50. Die „erste Hälfte" dieser
Liste umfasst damit die Indizes 10 bis 31 — **und 4 ihrer 18 Fenster liegen in der zweiten
Kalenderhälfte.**

„Holdout" und „vollständiges Buch" waren nicht bloß korreliert, sie waren **teilweise dasselbe
Merkmal, zweimal benannt**. Der Einwand ist zutreffend.

## Die Kreuztabelle, wie §2.1 verlangt

**[MESSUNG]** Kalenderhälfte × Buchvollständigkeit, Schlusskursbasis, 1,00×:

| | vollständiges Buch | unvollständiges Buch |
|---|---|---|
| **erste Kalenderhälfte** (Fenster 0–24, Gate-Ära) | 11/14 = **79 %** [0,52–0,92] | 7/11 = 64 % [0,35–0,85] |
| **zweite Kalenderhälfte** (Fenster 25–49, Holdout) | 18/22 = **82 %** [0,61–0,93] | 3/3 = 100 % [0,44–1,00] |

**Überlappung beziffert:** 22 von 36 vollständigen Fenstern (61 %) liegen in der zweiten
Kalenderhälfte. Alle 10 Fenster vor Index 10 sind unvollständig.

## Und die Antwort auf §2.2 ist gut: die erste Hälfte hat vollständige Fenster

**Ja — 14 davon.** Die beiden Effekte sind daher **teilweise trennbar**, und das Ergebnis stellt den
rev4-Befund auf den Kopf:

> **Bei konstanter Buchvollständigkeit schrumpft der Kalendereffekt von +27 Punkten (67 % → 94 %)
> auf +3 Punkte (79 % → 82 %), mit weitgehend deckungsgleichen Konfidenzbändern.**

Der gemessene „+12-Punkte-Holdout-Gewinn" aus rev4 war **überwiegend der Buchvollständigkeitseffekt
mit einem Zeit-Etikett.** Das sage ich so deutlich wie rev4 die ursprüngliche Zahl gesagt hat.

## Was der Befund jetzt noch sagt — und was nicht

**Er sagt weiterhin:** ein großer Abwärts-Bias aus Selektion tritt in diesen Daten nicht zutage. Die
vorhergesagten −10 bis −20 Punkte sind nicht zu sehen, weder mit noch ohne Kontrolle.

**Er sagt nicht mehr:** dass Out-of-Sample ein Gewinn eintritt. +3 Punkte bei n = 14 gegen n = 22 mit
Bändern von [0,52–0,92] und [0,61–0,93] sind **nicht von null unterscheidbar**.

**Die 94 % sind hiermit gekennzeichnet:** sie sind der Wert einer nach Listenposition gebildeten
Teilmenge, nicht die Quote der zweiten Kalenderhälfte. Die Zahl, die diese Rolle korrekt ausfüllt,
ist **82 %** — und ihr Gegenstück in der ersten Hälfte ist **79 %**, nicht 67 %.

**Der Regime-Konfundent bleibt.** Er war schon in rev4 benannt und ist durch keine Aufteilung
vorhandener Fenster entfernbar. Genau das ist die Lücke, die E-3 schließen würde — und der Grund,
warum der zeitliche Holdout aus rev4 §3 kein Ersatz für ein echtes Holdout ist.

---

# R5-3 · Was aus rev4 unverändert weitergilt

Nicht erneut gerechnet, nicht erneut bestritten — hier nur zusammengeführt, damit rev5 allein
lesbar ist:

* **R4-2 Sizing-Plateau (0,90×–1,15×) und Kante ab 1,20×.** Steht. Wird durch R5-1 nicht
  aufgehoben, sondern **überstimmt**: das Plateau ist auf der Schlusskurskurve real, aber die
  Schlusskurskurve ist im Plateau nicht mehr die verlässliche Kurve.
* **R4-5 Flip-Instabilität**: −6 pp Median, 17 pp Band. Gemessen **bei 1,00×**. Bei 0,60× nicht
  gemessen → OQ-6.
* **R4-6 Tail**: ~2,5 Grenztage/Jahr, dicht besetzter Tail, keine EVT-Extrapolation nötig.
* **R4-4 Population**: 18 von 91 Pool-Paaren mit nutzbarer Reihe, 61 × `challenge_engine_ineligible`,
  12 × `entry_time_incomplete`.
* **R4-7** Die leere Kategorie „Ziel erreicht, aber Limit gerissen" ist konstruktionsbedingt leer.
* **Deflated Sharpe, White, Hansen SPA**: **NICHT ENTSCHEIDBAR**, und E-2 ändert daran nichts —
  `sharpe` ist kein Extraktionsfehler, sondern ein **nie erhobenes Feld**
  (`EXTRACTOR_FIX_REPORT.md` §1-E). Nur ein Emitter-Wechsel im Lauf macht es verfügbar.

# R5-4 · Reihenfolge der Scheiter-Gründe

| neu | rev4 | Grund | Änderung |
|---|---|---|---|
| **1** | 1 | **Intraday ungemessen** — bestimmt die Aussage bereits **ab 0,65×**, nicht erst im Plateau | verschärft |
| **2** | 3 | **Population** — 18 von 91 | unverändert |
| **3** | 2 | **Verdikt-Stabilität** — −6 pp Median bei 1,00× | unverändert, aber am neuen Sizing ungemessen |
| **4** | — | **Selektion** — rev4 führte sie als *Entlastung* (+12 pp); nach Kontrolle ist sie **neutral** | von Entlastung zu offen |

Die Umsortierung ist keine neue Messung, sondern die Folge von R5-2: ein Punkt, der als Gutschrift
geführt wurde, ist keine mehr.

# R5-5 · Frage 4 des Prüfdokuments

**Status unverändert: NICHT ENTSCHEIDBAR.** Der Grund hat sich präzisiert und ist jetzt belegt statt
vermutet: die DD-Werte des Prüfdokuments können nicht aus `ea_metrics` stammen, weil der Extraktor
für Q04 und Q08 `drawdown_money` und `drawdown_pct` **als Konstante `None` schreibt** und Q14/Q15
gar nicht kennt (`unknown_phase`).

**Nach der Regenerierung wird sie beantwortbar** — und billiger als angenommen: der Q08-Drawdown
steht in der `aggregate.json`, die der Extraktor nie öffnet, und **81 von 91 Pool-Paaren** haben
diese Datei noch. `INVALIDATION_MATRIX.md` §2.

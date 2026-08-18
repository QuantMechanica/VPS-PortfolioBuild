# UPPER_BOUND_CALC — kann die Equity-Messung die Entscheidung noch drehen?

**Snapshot:** `3472a5d2e1b5` · **Stand:** 2026-08-18 · Work Order Runde 6 §1
**Erzeuger:** `tools/strategy_farm/portfolio/audit_upper_bound.py` ·
Artefakt `artifacts/audit_upper_bound_20260818.json`

---

## 0 · Die Antwort

> **Nein.** Es existiert kein Ausgang der Equity-Messung, bei dem dieses Buch das Kriterium
> erreicht. Die günstigste denkbare Fassung liegt bei **75–78 % Punktschätzung**, das Kriterium
> verlangt eine **Untergrenze ≥ 0,80**. Die Messung kann danach nur noch sagen, **wie weit
> darunter** — nicht mehr **ob**.

Und der Grund ist strukturell, nicht numerisch: **die Equity-Messung kann die Schlusskurskurve
nicht übertreffen.** Sie misst, wie tief die Tage unter den Tagesschluss laufen; das Ergebnis liegt
per Konstruktion bei oder unter der Schlusskurskurve. Deren Maximum über das gesamte Sizing-Raster
ist **81 %**. Alles Weitere zieht ab.

---

## 1 · Die Kette, sauber gerechnet

§1.1 verlangt die Nachrechnung Ihrer Überschlagsrechnung. **Sie stimmt im Ergebnis, und zwei kleine
Fehler heben sich auf.**

| Position | Ihre Zahl | Gemessen | Anmerkung |
|---|---:|---:|---|
| Ausgangspunkt | 78 % | **81 %** | 78 % ist die Quote bei 1,00×. Für eine **Obergrenze** gehört das Maximum über das Raster hin: 81 % bei 0,85× (36 vollständige Fenster), 80 % bei 1,10× (50 Fenster). |
| ./. Verdikt-Instabilität | −6 | **−8** | rev4 maß −6 bei 1,00×. Am Ceiling-Multiplikator 0,85× sind es **−8**. Der Effekt ist **nicht** sizing-invariant — das war die Annahme hinter OQ-6, und sie ist falsch. |
| Zwischenstand | 72 % | **73 %** | Ihre Ableitung war richtig; die beiden Abweichungen kompensieren sich fast exakt. |
| ./. Population | ? | **+2 bis +5** | **Richtung umgekehrt zur bisherigen Annahme** — siehe §3 |
| ./. Selektion | ? | **nicht verwertbar** | Punktschätzung +3 pp, Intervall [−21, +32] — siehe §4 |
| **Obergrenze** | **≈ 72 %** | **75–78 %** | Kriterium: Untergrenze ≥ 0,80 |

**Der entscheidende Punkt liegt nicht in der Punktschätzung, sondern im Kriterium.** Die Bar aus
`FTMO_BOOK_SPEC_2026-08-02_OWNER_TIMEBOX.md` lautet **„Bootstrap-Untergrenze von P(P1) ≥ 0,80"** —
nicht „Punktschätzung ≥ 80 %". Das Wilson-Band der 81 % reicht von **0,65** bis 0,90. Selbst wenn
jeder Abzug entfiele, wäre die Bar um **15 Punkte** verfehlt.

---

## 2 · Term 2 · Verdikt-Instabilität, jetzt an jedem Multiplikator (schließt OQ-6)

**[MESSUNG]** 1.000 Ziehungen, jeweils 4 der 21 Sleeves ersatzlos entfernt, 36 vollständige Fenster:

| Multiplikator | Basis | Median | Δ | Band (p5–p95) |
|---:|---:|---:|---:|---|
| 0,50× | 61 % | 50 % | **−11 pp** | 25 pp |
| 0,60× | 64 % | 61 % | −3 pp | 19 pp |
| **0,85×** | **81 %** | **72 %** | **−8 pp** | 17 pp |
| 0,90× | 78 % | 75 % | −3 pp | 14 pp |
| 1,00× | 81 % | 75 % | −6 pp | 17 pp |
| 1,10× | 78 % | 72 % | −6 pp | 14 pp |

**rev4s −6 pp bei 1,00× reproduziert exakt.** Neu ist, dass der Effekt zwischen −3 und −11 Punkten
schwankt und **kein stabiler Abschlag** ist. OQ-6 ist damit beantwortet: die Übertragung des
1,00×-Wertes auf andere Multiplikatoren war nicht zulässig, und ausgerechnet am Ceiling ist der
Abzug größer als angenommen.

---

## 3 · Term 3 · Population — die Richtung war falsch angenommen

rev4 formulierte vorab die **[VERMUTUNG]**, ein größeres Buch senke die Quote bei 1,00×, weil mehr
gleichzeitig offene Positionen die gemeinsamen Tage vertiefen. **Gemessen ist das Gegenteil.**

**[MESSUNG]** Teilbücher aus den vorhandenen 21 Sleeves, 300 Ziehungen je Größe, 36 vollständige
Fenster. „Exponiert-normalisiert" multipliziert den Multiplikator mit 21/k, hält also das
Gesamtrisiko konstant — sonst misst man nur, dass ein kleineres Buch weniger Kapital einsetzt.

| Buchgröße | roh (0,85×) | normalisiert (0,85×) | roh (1,00×) | normalisiert (1,00×) |
|---:|---:|---:|---:|---:|
| 6 | 28 % | 47 % | 36 % | 44 % |
| 9 | 46 % | 57 % | 54 % | 52 % |
| 12 | 60 % | 65 % | 66 % | 57 % |
| 15 | 69 % | 70 % | 72 % | 65 % |
| 18 | 75 % | 76 % | 76 % | 71 % |
| **21** | **81 %** | **81 %** | **81 %** | **81 %** |

**Steigung normalisiert: +2,27 pp je Sleeve bei 0,85×, +2,44 bei 1,00×.** Bei konstantem
Gesamtrisiko hebt jeder zusätzliche Sleeve die Quote — das ist der Diversifikationseffekt, und er
überwiegt den von rev4 vermuteten Gleichzeitigkeitseffekt deutlich.

### Aber die Erweiterung ist viel kleiner als gedacht

Die Steigung nützt nur, wenn es Sleeves zum Hinzufügen gibt. **[MESSUNG]** Warum die 91 Pool-Paare
nicht 91 Sleeves sind:

| Grund | Paare | durch einen Re-Run behebbar? |
|---|---:|---|
| **im Buch (ELIGIBLE)** | **17** | — |
| **unter 250 Handelstagen** | **24** | **nein** — zu kurze oder zu dünne Historie |
| Gate-Ablehnung (Q02 3 · Q03 2 · Q04 8 · Q05 8 · Q06 3 · Q07 2 · Q08 7) | **33** | **nein** — an der Sache gescheitert |
| `entry_time` unvollständig | **11** | **ja** — aber nur mit neuem Lauf |
| kein Stream | 6 | teilweise |

**Von den 11 telemetriebedingt fehlenden Paaren haben 9 nur 24 bis 116 Trades** — sie werden nach
einem Re-Run am 250-Tage-Filter scheitern. Realistisch wachsen kann das Buch von 21 auf **etwa 23**,
nicht auf 33 und schon gar nicht auf 91.

**Damit ist der Populationsterm beziffert: +2 bis +5 Punkte**, und diese Schätzung liegt innerhalb
des gemessenen Bereichs statt darüber hinaus extrapoliert zu sein.

### Nebenbefund, der den Batch betrifft

**`.ex5`-mtime ist kein Bau-, sondern ein Staging-Zeitstempel.** QM5_11288/USDJPY hat eine Binary
vom 17.08. und einen **heute** geschriebenen Stream — und trotzdem 0 % `entry_time` über 436 Trades.
In `QM_Common.mqh` existiert nur **ein** `TRADE_CLOSED`-Writer (Zeile 1717), und der schreibt
`entry_time`, `mae_acct` und `money_basis` immer.

**Konsequenz, prüfbar und billig:** ob ein Paar reiche Streams liefert, entscheidet sich an der
**Zeilenform** (`money_basis` vorhanden), nicht an irgendeinem Zeitstempel. Wer den Batch nach
Datum plant, plant falsch. → OQ-12.

---

## 4 · Term 4 · Selektion — die Grenze, nicht der Wert

**[MESSUNG]** Kalenderhälften innerhalb der vollständigen Fenster, 1,00×:

| | | |
|---|---|---|
| erste Hälfte (Gate-Ära) | 11/14 = **79 %** | Wilson [0,52–0,92] |
| zweite Hälfte (Holdout) | 18/22 = **82 %** | Wilson [0,61–0,93] |
| Differenz | **+3 pp** | Newcombe **[−21, +32] pp** |

Das Intervall ist breiter als jede Aussage, die man darauf stützen wollte. **Was es liefert, ist
eine Schranke statt eines Wertes:** ein verdeckter Abwärts-Bias von mehr als **21 Punkten** wäre mit
der Beobachtung unvereinbar. Nach oben ist gar nichts belegt.

Für die Kette heißt das: **die Selektion kann nicht als Gutschrift eingesetzt werden**, und als
Abzug ist sie nur nach oben begrenzt, nicht beziffert. Sie bleibt der einzige Term, der die
Rechnung theoretisch noch kippen könnte — nach **unten**, nicht nach oben.

---

## 5 · Die Entscheidungsfrage (§1.3)

**Existiert ein plausibler Ausgang der Equity-Messung, bei dem die Quote das Kriterium erreicht?**

**Nein**, und zwar aus drei unabhängigen Gründen — jeder einzelne reicht:

1. **Konstruktion.** Die Equity-Messung liegt per Definition bei oder unter der Schlusskurskurve.
   Deren Maximum ist 81 %. Sie kann nichts hinzufügen.
2. **Kriterium.** Verlangt ist eine **Untergrenze** ≥ 0,80. Die Untergrenze der 81 % ist **0,65**.
   Bei n = 36 Fenstern ist ein Band von 25 Punkten unvermeidbar — **selbst eine perfekte Messung
   könnte die Bar auf dieser Fensterzahl nicht erfüllen.** Das ist ein Stichprobenproblem, kein
   Messproblem.
3. **Kette.** 81 − 8 (Flip) + 2…5 (Population) = **75–78 %**, und die Selektion kann das nur senken.

### Was das für D-4 heißt

**D-4 ist damit entschieden, ohne dass jemand entscheiden muss** — für den Zweck, für den es
beantragt wurde. Ein Recompile-Batch, dessen Ziel die Intraday-Messung ist, kauft eine Präzisierung
innerhalb eines Bereichs, der die Vorgabe ohnehin verfehlt, und bezahlt sie mit den Verdikten der
Flotte.

**Aber es gibt einen zweiten, davon unabhängigen Grund für einen Lauf, und den möchte ich nicht
unter dem „Nein" verschwinden lassen:** der Populationsterm ist der einzige gemessene Term, der nach
**oben** zeigt. Er ist klein (+2 bis +5 Punkte) und er reicht nicht — aber er ist real, und er
verlangt **keinen** Recompile für die 2 Paare, deren Streams nur veraltet sind. Ein Re-Run von
11 Zeilen ist etwas völlig anderes als ein Vollbatch über 91.

---

## 6 · Was die Rechnung **nicht** sagt

* **Nicht**, dass die Strategien widerlegt sind. Gemessen wurde ein **Buch** gegen eine
  **Zielvorgabe**.
* **Nicht**, dass ein FTMO-Buch unmöglich ist. Gemessen wurde *dieses* Buch aus 21 Sleeves.
* **Nicht**, dass die Intraday-Frage uninteressant ist. Sie bestimmt weiterhin, ob bei 0,85× die
  wahre Quote 81 % oder 18 % beträgt — für den **Betrieb** ist das der Unterschied zwischen einem
  brauchbaren und einem ruinösen Buch. Nur für die **Bar** ändert sie nichts.

## 7 · Was die Rechnung stattdessen zeigt

Der bindende Engpass ist weder Messung noch Sizing, sondern **Angebot**:

> **24 Paare scheitern an zu kurzer Historie, 33 an den Gates. Zusammen 57 von 91 — und kein Batch,
> keine Telemetrie und kein Sizing ändert daran etwas.**

Das deckt sich mit der Speed-Doktrin vom 26.07.: *„Die Lücke ist nicht zu schließen durch
Positionsgrößen, Governor oder Portfolio-Konstruktion. Nur durch bessere Strategien."* Die
vorliegende Rechnung ist deren unabhängige Bestätigung, drei Wochen später und auf anderem Weg.

# SUPPLY_TARGET — wie viel Angebot tatsächlich nötig ist

**Snapshot:** `3472a5d2e1b5` · **Stand:** 2026-08-19 · Work Order Runde 7 §6

---

## 0 · Die Antwort zuerst

> **Mehr Sleeves helfen, und zwar erheblich — aber nicht dort, wo man es vermutet.** Sie erhöhen
> nicht den Ertrag je finanziertem Konto (der sättigt bei etwa 12 Sleeves), sondern die
> **Wahrscheinlichkeit, überhaupt finanziert zu werden** — und die steigt bei 21 Sleeves immer noch
> ungebremst.
>
> **Und: Kapazität ist nicht der Engpass.** Die Fabrik kann mehr durchsetzen, als ihr zugeführt wird.
> Der Engpass sind zwei Ventile, nicht der Durchsatz.

---

## 1 · Skalierung mit der Buchgröße — gemessen

**[MESSUNG]** Teilbücher aus den vorhandenen 21 Sleeves, 25 Ziehungen je Größe, Sizing 0,50×,
Intraday-Boden. Erwartungswertgrößen wie in `EV_FUNDED_ACCOUNT.md`:

| Sleeves | finanziert | Überlebensdauer Median | Auszahlung Ø | **Break-even-Gebühr** |
|---:|---:|---:|---:|---:|
| 6 | 1 % | 952 d | 38.030 $ | **274 $** |
| 9 | 3 % | 643 d | 37.873 $ | 1.212 $ |
| 12 | 9 % | 534 d | 51.642 $ | 4.875 $ |
| 15 | 13 % | 520 d | 57.457 $ | 7.722 $ |
| 18 | 26 % | 390 d | 54.222 $ | 14.011 $ |
| **21** | **34 %** | 332 d | 56.661 $ | **19.265 $** |

**Drei Ablesungen, und die dritte ist die wichtige:**

1. **Die Auszahlung je finanziertem Konto sättigt bei ~12 Sleeves** (52–57 k $ ab dort, flach).
2. **Die Überlebensdauer sinkt** mit der Buchgröße (952 → 332 Tage). Mehr Sleeves heißt mehr
   gleichzeitige Exponierung, also frühere Brüche — das ist der Effekt, den rev4 vermutet hatte,
   und hier ist er sichtbar.
3. **Die Finanzierungswahrscheinlichkeit sättigt nicht.** 1 % → 34 %, und der Zuwachs von 18 auf 21
   Sleeves ist mit +8 Punkten der zweitgrößte der ganzen Reihe. **Sie überkompensiert die kürzere
   Lebensdauer um ein Vielfaches** — die Break-even-Gebühr steigt monoton über zwei
   Größenordnungen.

**Antwort auf §6.2:** ein Sättigungsbereich ist für die Auszahlung erkennbar (~12), **für die
Finanzierungsrate innerhalb des messbaren Bereichs nicht.** Wo sie abflacht, ist aus 21 Sleeves
nicht bestimmbar — und ich extrapoliere es nicht.

*Methodischer Vorbehalt, damit die Zahlen nicht überinterpretiert werden:* die Teilbücher nutzen den
**naiven** MAE-Boden (Schlusstag-Zurechnung), nicht den überlappungsbeschränkten — der pro Teilbuch
neu zu rechnen wäre zu teuer. Der naive Boden ist milder, die **Niveaus** liegen daher etwas zu hoch
(19.265 $ hier gegen 15.555 $ mit dem echten Boden bei 21 Sleeves). **Die Form der Kurve ist der
Befund, nicht ihr Niveau.**

## 2 · Wie viele Sleeves für welche Zielgröße

**Für die alte 80-%-Bar: gar keine Zahl.** Die Bar verlangt eine *Untergrenze* ≥ 0,80, und die hängt
an der **Fensterzahl** (n = 36 vollständige Fenster), nicht an der Sleeve-Zahl. Mehr Sleeves heben
die Punktschätzung, nicht das Konfidenzband. Das ist in `UPPER_BOUND_CALC.md` §5 hergeleitet und
ändert sich hier nicht.

**Für die Ertragsgröße aus `EV_FUNDED_ACCOUNT.md`:** das Kriterium ist bereits bei 21 Sleeves
erfüllt — Break-even 15.555 $ gegen eine vierstellige Gebühr. **Zusätzliche Sleeves verbessern die
Marge, sie entscheiden nichts mehr.** Die lokale Steigung von +2,3 bis +2,7 Punkten je Sleeve gilt im
gemessenen Bereich; sie trägt nicht beliebig weit, und ich rechne sie nicht hoch.

**Die ehrliche Fassung:** unter der neuen Zielgröße ist das Buch heute schon tragfähig. Die
Angebotsfrage ist damit **keine Frage des Erreichens mehr, sondern eine der Marge und der
Ausfallsicherheit** — mehr Sleeves ersetzen ausgefallene und halten die Finanzierungsrate oben, wenn
Verdikte kippen (rev6: −3 bis −11 Punkte Flip-Instabilität).

## 3 · Produktionszahl bei heutiger Ausbeute — in **einer** Einheit gerechnet

**Korrektur gegenüber der ersten Fassung.** Ich hatte hier mit „0,12 %" gerechnet und diese Zahl als
Korrektur der 0,5 % ausgegeben. Sie war keine: 0,12 % ist die **Paar**-Quote, 0,5 % die **EA**-Quote.
Beide stimmen, und für die Produktionsplanung ist die EA-Einheit die richtige — **gebaut werden EAs**,
und jeder läuft anschließend auf im Mittel **4,89** Symbolen (`FUNNEL_DIAGNOSIS.md` §1).

**[MESSUNG]** 3.705 gebaute EA-IDs → **20** distinkte Buch-EAs = **0,540 %**.

| Ausbeute (EA-Einheit) | gebaute EAs je zusätzlichem Buch-EA | für +5 | für +10 |
|---|---:|---:|---:|
| **0,54 % (heute)** | **~185** | ~925 | ~1.850 |
| 1 % | ~100 | ~500 | ~1.000 |
| 2 % | ~50 | ~250 | ~500 |

*Zur Umrechnung in Sleeves:* ein zusätzlicher Buch-**EA** bringt im Mittel etwas mehr als einen
Sleeve, weil dieselbe Strategie auf mehreren Symbolen buchfähig sein kann — im heutigen Buch stehen
21 Sleeves auf 20 EAs, also praktisch 1:1. **Die 185 sind damit auch die Zahl je zusätzlichem
Sleeve.**

**Das ist die Rechnung, die die Doktrin rechtfertigt oder erledigt.** Hebt `PRODUCTION_DOCTRINE.md`
die Ausbeute von 0,54 % auf 1 %, halbiert sich der Kandidatenbedarf; auf 2 % viertelt er sich.
**Jeder Prozentpunkt Ausbeute ist mehr wert als jede Verdopplung des Durchsatzes** — und deutlich
billiger, weil die Fabrik ohnehin nicht ausgelastet ist (§4).

## 4 · Kapazität dagegengestellt — und sie ist nicht der Engpass

**[MESSUNG]** Flottendurchsatz vor der Containment-Notlage: **7,84 terminale Zeilen je Stunde** über
16,8 Stunden gemessen. Das sind rund **1.300 Zeilen je Woche** über alle Phasen, bei zehn Terminals.

Dagegen die Zuflussseite:

| | |
|---|---|
| gebaute EAs, die die Fabrik nie betreten haben | **428** |
| davon als `build_ea`-Ticket in REVIEW, also vor meinem Ventil | **56** |
| wartende Zeilen in der Queue | **2.343** |

> **Die Fabrik kann in einer Woche mehr abarbeiten, als überhaupt an neuem Angebot bereitsteht.**
> 428 gebaute EAs warten, und 56 davon warten auf einen Review, den nur ich erteile.

**Damit ist die Reihenfolge der Hebel eindeutig, und sie steht quer zur Intuition:**

1. **Ventile öffnen** — 56 Build-Reviews, dann die 428 nie eingereihten prüfen. Kostet keine
   Fabrikzeit, nur meine.
2. **Containment freigeben** (D-8) — hebt die Parallelität von 1 auf 10.
3. **Ausbeute heben** (§4-Doktrin) — der einzige Hebel mit Faktor 8.
4. **Mehr Kandidaten erzeugen** — zuletzt, weil die Fabrik heute schon mehr könnte, als sie bekommt.

**Antwort auf §6 in einem Satz:** *das ist in Wochen machbar* — aber nicht durch mehr Durchsatz,
sondern indem zwei Ventile geöffnet und die Ausbeute gehoben wird.

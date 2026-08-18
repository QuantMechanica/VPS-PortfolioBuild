# LIVETEST_OPTION — eine FTMO-Challenge als Vergleichsgröße

**Snapshot:** `3472a5d2e1b5` · **Stand:** 2026-08-18 · Work Order Runde 5 §9
**Charakter: Vergleichsgröße, ausdrücklich keine Empfehlung.** Spezifiziert wird, was *stattdessen*
möglich wäre, damit die Kosten des Vollbatches einen Bezugspunkt haben.

---

## 0 · Der Vorbehalt gehört an den Anfang, nicht ans Ende

**Die stehende Doktrin verbietet genau das.** `FTMO_BOOK_SPEC_2026-08-02_OWNER_TIMEBOX.md` setzt die
Bar auf **Bootstrap-Untergrenze von P(Phase 1) ≥ 0,80**, und die Regel dazu lautet: **kein
Challenge-Konto, bevor die Bar erreicht ist.**

Nach rev5 ist die Bar auf keiner Lesart erreicht:

| Sizing | Quote | Wilson-Untergrenze |
|---|---|---|
| 0,60× (verteidigbar) | 60 % | **0,46** |
| 0,90× | 76 % Schluss / 36 % MAE | 0,63 / 0,24 |
| 1,00× | 78 % Schluss / 28 % MAE | 0,65 / 0,17 |

**Keine Untergrenze kommt in die Nähe von 0,80.** Ein Livetest wäre deshalb keine Fortsetzung des
Plans, sondern eine **bewusste Ausnahme von ihm** — und zugleich eine Kaufentscheidung, also
OWNER-Fenster. Das ist der Rahmen; das Folgende beschreibt, was man dafür bekäme.

---

## 1 · Kosten gegen Kosten des Vollbatches

| | Vollbatch (§7) | Livetest, ein Konto |
|---|---|---|
| Fabrikzeit | 1–2 Tage, Baskets bestimmen | **null** |
| Kalenderzeit bis zur Antwort | 1–2 Tage + Auswertung | **bis zu 60 Tage** für Phase 1, weitere 30 für Phase 2 |
| verschobener kritischer Pfad | Baskets/2.3 → siehe §7 §5.2 | **keiner** — läuft nebenher |
| Geld | keines | Challenge-Gebühr nach FTMO-Preisliste. **Aus lokalen Quellen nicht belegbar; vor einem Beschluss zu verifizieren** — hier wird kein Betrag erfunden. |
| Aufmerksamkeit | Auswertung, einmalig | laufende Überwachung über Wochen; das Konto ist real und kann jederzeit reißen |

**Die Asymmetrie ist die eigentliche Aussage:** der Vollbatch kostet Fabrikzeit und liefert in Tagen.
Der Livetest kostet Kalenderzeit und liefert in Monaten. **Sie sind keine Alternativen im gleichen
Zeitraster** — wer 3.4 abschließen will, kann nicht auf einen Livetest warten.

---

## 2 · Was der Livetest beantwortet, das der Backtest nicht kann

Genau die Größen, die im Backtest **modelliert statt gemessen** werden:

| Größe | Im Backtest | Im Livetest |
|---|---|---|
| **Intraday-Messung des Tageslimits** | modelliert; rev5 zeigt, dass allein diese Modellierung eine 50-Punkte-Spanne erzeugt | **FTMO misst selbst**, mit seiner eigenen Definition und seinem eigenen Zeitraster |
| **Ausführung** | Tester-Fills zum Modellpreis | reale Fills, reale Ablehnungen, reales Requote-Verhalten |
| **Slippage** | über das Kostenmodell angesetzt (`reference_venue_cost_model`) | beobachtet |
| **Feed-Differenz** | Darwinex-`.DWX`-Historie | **FTMO-Feed**, ein anderer Preisstrom mit anderen Spreads und anderen Tageshochs/-tiefs |
| **Regelauslegung** | unsere Lesart der Regeln, inklusive der 30-Tage-Dormanz, die **OWNER-bestätigt, aber nicht offiziell publiziert** ist | FTMOs eigene Auslegung, verbindlich |

**Der erste und der letzte Punkt sind die wertvollen.** Das Intraday-Limit ist die Unsicherheit, die
rev5 an die Spitze setzt — und ein Livetest misst sie nicht bloß genauer, er misst sie **mit der
Definition der Gegenseite**. Kein Backtest kann das, weil FTMOs Messvorschrift nicht vollständig
öffentlich ist.

---

## 3 · Was er nicht beantwortet — und das ist der härtere Teil

**n = 1.**

* Ein bestandenes Konto belegt **keine** 80 %. Bei einer wahren Quote von 60 % besteht ein einzelnes
  Konto mit 60 % Wahrscheinlichkeit — ein Erfolg ist unter *jeder* diskutierten Hypothese der
  wahrscheinlichere Ausgang und trennt sie deshalb nicht.
* Ein gescheitertes Konto belegt ebenso wenig das Gegenteil. Bei 78 % scheitert eines mit 22 %.
* **Ein einzelnes Konto kann zwischen 60 % und 80 % nicht unterscheiden.** Das ist keine
  Design-Schwäche, das ist Arithmetik: die beiden Hypothesen sagen für n = 1 fast dasselbe voraus.

Was ein einzelnes Konto **sehr wohl** kann: eine **grobe** Fehlannahme aufdecken. Reißt das Konto in
Woche 1 an einem Tageslimit, das der Backtest an derselben Stelle nicht gerissen hätte, ist das ein
Befund über das Intraday-Modell — kein statistischer, sondern ein **qualitativer**, und deshalb schon
mit n = 1 aussagekräftig.

**Genau darauf sollte er ausgelegt werden**, wenn er stattfindet: nicht als Quotenschätzung, sondern
als **Modellprüfung**.

---

## 4 · Vorab festzulegen, damit er auswertbar bleibt

Ohne diese Festlegungen **vor** dem Start ist der Test nachträglich interpretierbar und damit
wertlos. Alles hier ist ein Vorschlag, keine Setzung.

### Aufbau
* **Sizing 0,60×** — die verteidigbare Größe aus rev5. Nicht 0,90×, nicht 1,00×: der Test soll die
  Modellunsicherheit messen, nicht ihr ausgeliefert sein.
* **Ein Konto.** Zwei Konten kosten doppelt und lösen das n-Problem nicht.
* **Sleeve-Auswahl und Gewichte eingefroren** vor dem Start, aus dem Buch, unverändert bis zum Ende.
* **Kein Eingriff während des Laufs.** Ein manuell geretteter Test misst den Eingriff.

### Erfolgs- und Abbruchkriterien, vorab
| Ereignis | Bedeutung, vorab festgelegt |
|---|---|
| Phase 1 in ≤ 60 Tagen bestanden | Modell nicht widerlegt. **Keine** Bestätigung der 80 %. |
| Tageslimit gerissen an einem Tag, den der Backtest als unkritisch führt | **Der wertvollste Ausgang.** Belegt, dass der Schlusskurs-Pfad die Intraday-Tiefe unterschätzt — die Frage aus rev5 §1, mit FTMOs eigener Messung beantwortet. |
| Gesamtlimit gerissen | Modell in der Kumulierung falsch; die Ko-Exzedenz-Annahme aus rev2 fällt |
| 60 Tage abgelaufen ohne Ziel | häufigster Ausgang unter jeder Hypothese; **trägt fast keine Information** |
| **Abbruch von unserer Seite** | nur bei belegtem Infrastrukturfehler (Feed-Ausfall, falsches Setfile, falsche Magic). Nie wegen des Zwischenstands. |

### Auswertung
Vorab schriftlich, welche Zahl aus dem Test **in welches Dokument** eingeht, und welche
ausdrücklich nicht. Sonst wird aus n = 1 rückblickend ein Beleg.

---

## 5 · Zusammenfassung für die Gegenüberstellung

| | Vollbatch | Livetest |
|---|---|---|
| beantwortet | Intraday-Amplitude im Modell, Population, Binary-Bindung, Recompile-Effekt | Intraday-Messung **der Gegenseite**, Ausführung, Feed, Regelauslegung |
| Auflösung | 91 Paare, 50 Fenster | **n = 1** |
| liefert in | Tagen | Monaten |
| kostet | Fabrikzeit, verschiebt 2.3/3.4 | Geld, Kalenderzeit, Aufmerksamkeit |
| Verhältnis zur stehenden Doktrin | im Plan | **Ausnahme von der Bar** |

**Sie schließen einander nicht aus, und sie ersetzen einander nicht.** Der Batch verengt die Spanne;
der Livetest prüft, ob das Modell, das die Spanne erzeugt, überhaupt die richtige Form hat. Wer nur
eines finanzieren kann und eine Zahl braucht, nimmt den Batch. Wer eine **Modellprüfung** braucht,
nimmt den Livetest — und muss akzeptieren, dass er drei Monate dauert und keine Quote liefert.

# BATCH_SPEC_MERGED — Regenerierung und Vollbatch als ein Lauf

**Snapshot der Ausgangslage:** `3472a5d2e1b5` · **Stand:** 2026-08-18 · Work Order Runde 5 §7
**Charakter:** Spezifikation und Bepreisung. **Nichts hiervon ist gestartet.** Zwei Punkte verlangen
ausdrücklich eine OWNER-Entscheidung, bevor irgendetwas läuft (§5 dieses Dokuments).

---

## 0 · Zuerst: drei der vier Zusatzgrößen kosten nichts, weil sie schon da sind

§7 listet vier Zusatzgrößen, die „nebenbei abfallen" sollen, wenn ohnehin neu gelaufen wird. Geprüft,
und das Ergebnis ändert die Rechnung erheblich:

| Zusatzgröße | Status | Kosten |
|---|---|---|
| **Zeitstempel je Trade** | **liegt bereits vor** — die Streams führen `time` und `entry_time` als Epoch-Sekunden, minutengenau (`entry_time 1531390500` = 2018-07-12 10:15:00) | **null** |
| **`.ex5`-Hash je Lauf** | **liegt bereits vor** — `baseline_ex5_sha256` + `baseline_setfile_sha256` in **51 von 58** lesbaren Q08-Aggregaten (88 %) | **null** für den Lauf; braucht E-2, nicht einen Backtest |
| **Abdeckung Richtung 91 Paare** | das ist der Batch selbst | siehe §2 |
| **Equity-Snapshots** | **fehlt wirklich** — und ist die einzige der vier, die einen neuen Lauf braucht | siehe §1 |

### Die Korrektur an rev4, die hier fällig ist

rev4 schrieb: *„Die Sleeve-Streams tragen je Trade `(entry_date, close_date, net, mae)` — Datums-,
keine Zeitstempel."* **Das war eine Aussage über die Engine, nicht über die Daten.**
`challenge_book_60d.py:157` ruft `.date()` auf beide Zeitstempel; die Streams selbst sind
minutengenau.

**Folge:** Die Überlappung gleichzeitig offener Positionen ist aus dem **vorhandenen** Bestand
rekonstruierbar. Nicht rekonstruierbar bleibt, **wann innerhalb der Überlappung** die jeweilige MAE
eintrat. Damit ist die Annahme „perfekte Gleichzeitigkeit", auf der die 28-%-Untergrenze steht, ohne
einen einzigen Backtest deutlich enger zu fassen: zwei Trades können nur dann gemeinsam exzedieren,
wenn ihre Offen-Intervalle sich überschneiden — und viele tun das nicht.

**Ich habe diese Rechnung NICHT ausgeführt.** §3 der Work Order verbietet weitere Messungen auf dem
alten Bestand. Sie steht als **OQ-5** in `OPEN_QUESTIONS.md` und ist dort als die eine Ausnahme
markiert, für die ich eine Freigabe empfehle: Kosten unter einer Stunde, ohne Fabrikzeit, und sie
verengt genau die Spanne, die rev5 als handlungsbestimmend ausweist.

---

## 1 · Die eine echte Zusatzgröße: Intraday-Equity

### Was der Tester tatsächlich hergibt — gemessen, nicht angenommen

**Der ausgelieferte Emitter reicht nicht.** `framework/include/QM/QM_EquityStream.mqh` schreibt
**einen** `EQUITY_SNAPSHOT` **pro Tag**, beim Tageswechsel:

```
if(day_key == g_qm_eqstream_last_day_key)
   return;  // same day, no snapshot needed
```

Die 2.021 Snapshots in einem Q08-Aggregat sind 2.021 **Tage**, keine Intraday-Auflösung. Für die
FTMO-Frage ist das exakt die Größe, die schon vorliegt und nichts beantwortet.

**Aber das Primitiv existiert bereits, gebaut und adversarial geprüft.**
`framework/include/QM/modules/QM_Mod_FtmoJointEquitySampler_20180.mqh` schreibt zwei Zeilentypen:

* `EQUITY_BAR` — je geschlossenem H1-Bar des Host-Symbols, mit Floating-P&L je Sleeve
* `EQUITY_LOW` — **bei jedem neuen Intraday-Tief der Kontoequity**, plus ein Ankerdatensatz je
  Broker-Tag-Wechsel

Der Modulkopf sagt selbst, warum er existiert: *„The shipped emitter QM_EquityStreamOnNewBar emits
ONE snapshot per DAY at the day CLOSE — it captures neither observed intraday equity nor observed
lows."*

**Zur Auflösungsfrage aus §7:** M1 ist **nicht** die richtige Antwort und wäre schlechter. `EQUITY_LOW`
ist **tick-ereignisgenau** unter dem Tickmodell des Testers — das beobachtete Tief, nicht ein aus
M1-OHLC interpoliertes. Das ist feiner als der Anspruch und zugleich ehrlicher, weil es nichts
interpoliert.

**Vollständigkeitsgrenze, aus dem Modul übernommen:** die Zeilen sind FTMO-vollständig **nur** wenn
jede offene Position auf dem Host-Symbol liegt. Für die 21 Sleeves gilt das (alle einsymbolig). Für
die **Basket-Zeilen gilt es nicht** — das Modul schreibt dort selbst `coverage_complete=false`. Ein
Basket-Buch bekäme also diagnostische, keine beweisführenden Zeilen.

### Was der Einbau verlangt

1. Modul aus dem 20180/20181-Kontext in den Standard-Sleeve-Bau ziehen (Aufruf in `OnTick` +
   `OnDeinit`-Flush, Konfiguration über die Magic-Liste des Sleeves).
2. **Recompile jeder EA im Batch.**
3. Ein Setfile-Schalter, damit die Telemetrie im Live-Bau abschaltbar bleibt.

**Punkt 2 ist der Haken, und er ist nicht meiner:** Work Order Runde 1 §3.3 nennt „Recompile einer
Binary im aktiven Bestand" ausdrücklich nicht-autonom. Siehe §5.

### Kosten des Einbaus im Lauf

Aus dem Modulkopf (adversarial-review M3): der Per-Tick-Pfad liest `ACCOUNT_EQUITY` und macht einen
Vergleich; der `O(PositionsTotal)`-Scan läuft **nur beim tatsächlichen Emittieren**. Laufzeitaufschlag
daher gering, aber **nicht null und nicht gemessen** — die ehrliche Antwort ist: unbekannt, mit
begründeter Erwartung im niedrigen einstelligen Prozentbereich. **Das ist die erste Zahl, die der
Pilot in §4 liefern muss.**

Speicher: `EQUITY_BAR` je H1-Bar über 8 Jahre ≈ 50.000 Zeilen je Sleeve, ~200 Byte → **~10 MB je
Sleeve, ~1 GB für 91 Paare**. Gegen 156 GB freies D: irrelevant.

---

## 2 · Rechenzeit, gemessen an Batch (b)

**[MESSUNG]** Batch (b), 72 gewöhnliche Zeilen abgeschlossen, 2026-08-17T21:49 → 2026-08-18T14:09:

| | |
|---|---|
| Abschlüsse je Stunde | **Mittel 4,5** · Maximum 10 · über 16 aktive Stunden |
| gewöhnliche Q08-Zeile, Wanduhr | **Median 0,35 h** · p90 1,75 h · Maximum 3,98 h (n = 398) |

**Hochrechnung für 91 gewöhnliche Zeilen: ~20 Stunden.**

### Baskets dominieren, und ihre Laufzeit ist nicht sauber instrumentiert

Von 21 Basket-Q08-Zeilen sind 15 abgeschlossen (9 FAIL_HARD, 6 FAIL_SOFT) — aber **keine** trägt
`started_at_iso`, ihre Laufzeit ist also nicht aus der Datenbank rekonstruierbar. Direkt beobachtet
ist zweierlei: ein Lauf über **6,6 h**, und bei QM5_12712 heute eine Baseline-Stufe von **16 min**
(14:44 → 15:00 UTC), gefolgt vom Neighborhood-Sweep.

**Belastbare Spanne: 1–7 h je Basket.**

### KORREKTUR 16:05 UTC — ein Basket blockiert nicht seine Spur, sondern die ganze Fabrik

Die erste Fassung dieses Abschnitts sagte, Baskets liefen **parallel** zu den gewöhnlichen Zeilen,
weil `terminal_worker.py:1911` nur multisym gegen multisym serialisiert. **Das ist falsch, und die
Monitoring-Runde hat es gemessen.**

Der bindende Mechanismus ist der **globale Custom-History-Lease**. `terminal_worker.py:4467` holt ihn
**vor** `claim_atomic` und gibt ihn erst im `finally` **nach dem vollständigen Lauf** frei
(`_run_claimed_item` liegt dazwischen). Solange eine Zeile läuft, kann **kein anderes Terminal
überhaupt einen Anspruch versuchen**.

**[MESSUNG] Lease-Haltedauern heute:** Median **1,1 min**, p90 **12,3 min**, Maximum **54,8 min** —
und das Maximum ist der Basket QM5_12712, freigegeben in dem Moment, in dem der Reaper ihn tötete.

**[MESSUNG] Lease-Busy je Terminal und Stunde:** rund **50 pro Stunde** — jedes Terminal fragt einmal
je Minute an und wird praktisch jedes Mal abgewiesen, durchgehend über 13:00, 14:00 und 15:00 UTC.

**[MESSUNG] Letzter Anspruch je Terminal, 16:01 UTC:** T9 vor 29 min — **alle übrigen neun zwischen
153 und 429 Minuten**. Bei 2.300 wartenden Zeilen (Q04 1.497, Q02 690) und 10 lebenden Workern.

**Bei Median 1,1 min ist der Lease für gewöhnliche Zeilen unschädlich.** Bei einem Basket, der ihn
Stunden hält, steht die Fabrik.

### Gesamt, korrigiert

| Variante | Wanduhr | Kosten |
|---|---|---|
| gewöhnliche Zeilen allein | ~20 h | Fabrik ausgelastet |
| **6 Baskets seriell** | **6–42 h** | **Fabrik steht — 10 Terminals, nicht eines** |
| **vereinter Batch** | ~1 bis 2 Tage | dominiert vom Basket-Anteil, und zwar exklusiv |

**Ob der Lease über den ganzen Lauf gehalten werden muss, ist eine offene Frage** (OQ-11): die
Copy-on-Claim-Privatisierung kopiert die Historie in das terminaleigene `Bases\Custom`, danach liest
der Lauf nur noch private Dateien. Was der globale Lease **während** des Laufs noch schützt, ist
nicht ersichtlich. Er ist Teil der OWNER-ratifizierten Variante-A-Containment und wird deshalb
**nicht** von mir geändert — aber die Frage gehört gestellt, weil an ihr 6 bis 42 Fabrikstunden
hängen.

---

## 3 · Speicher und Lease-Konflikte

**[MESSUNG] Stand heute:**

| | |
|---|---|
| RAM frei | 34,0 GB von 63,1 |
| Commit frei | 92,7 GB von 122,6 |
| D: frei | 156,4 GB von 953,9 |
| C: frei | 46,7 GB (9,8 %) |
| terminal64-Prozesse | 3 |

Gegen die Schwellen: `MULTISYMBOL_COMMIT_MIN_FREE_GB = 48` und `MULTISYMBOL_RAM_MIN_FREE_GB = 12`
sind beide deutlich erfüllt. Die Basket-Reservierung liegt bei 32–44 GB je Zeile — **daher die
Serialisierung, und daher bleibt sie**.

**Custom-History-Lease:** globaler Lease, Copy-on-Claim privatisiert je Anspruch. Ein Basket kopiert
216 Dateien (gemessen an QM5_12712). Kein Konflikt zu erwarten, solange multisym seriell bleibt;
die Lease-Ereignisse tragen seit v11 §7.9 Zeitstempel, ein Konflikt wäre also sichtbar.

**C: mit 9,8 % ist die einzige Enge**, aber sie wächst nicht durch diesen Batch: Reports gehen nach
D:. P2, keine Maßnahme.

---

## 4 · Machbarkeit je Paar — für wie viele der 91 geht es überhaupt?

**[MESSUNG]**

| | |
|---|---|
| EA-Verzeichnis vorhanden | **91 von 91** |
| Setfile vorhanden | **91 von 91** |
| keine Work-Item-Zeile bisher | 3 (alle C3) |
| kein lesbares Q08-Aggregat | 33 (Auswertung, kein Laufhindernis) |

**Kein Paar fällt aus fehlendem Setfile oder fehlender EA-Definition aus.** Die Zahl, die §7.3
verlangt, lautet damit: **91 machbar**, mit einer Einschränkung, die vor dem Batch geklärt sein muss —
für die 3 Paare ohne jede Historie ist es ein **Erstlauf**, kein Re-Run, und ihr Ergebnis hat keinen
Vergleichspunkt.

---

## 5 · Was OWNER entscheiden muss, bevor irgendetwas läuft

### 5.1 · Der Recompile

Die Equity-Telemetrie verlangt einen Recompile jeder EA im Batch. Runde 1 §3.3 stellt das
ausdrücklich unter Vorbehalt, mit dem belegten Grund: **8 von 39 Verdikten kippten allein durch
Recompile, ein Stream verlor 13 % seiner Trades.**

Genau deshalb ist der Batch aber auch die **billigste** Gelegenheit: es wird ohnehin für 53 C3-Paare
neu gebaut und für alle 91 neu gelaufen. Ein späterer Beschluss kostet einen zweiten Vollbatch.

**Zu entscheiden: Recompile für den vereinten Batch freigeben — ja oder nein.** Ohne Freigabe
entfällt die Equity-Telemetrie, und damit die einzige Größe, die rev5 als handlungsbestimmend
ausweist.

**Das Recompile-Experiment (§7.1 des kritischen Pfads) fällt dabei ab**, ohne Zusatzkosten: dieselben
Paare, geänderte Binary, kontrolliert gemessen — statt der retrospektiven Kohortenzuordnung mit
n = 12, deren Clopper-Pearson-Obergrenze bei 22,1 % liegt. **Ich plane es in denselben Batch ein und
melde keine Kollision** — es ist derselbe Lauf.

### 5.2 · Die Kollision, die §7.5 verlangt — und sie ist unangenehm

**OWNER hat entschieden: alle fünf Baskets durchlaufen lassen, kein Abschluss von 2.3 ohne
Basket-Anteil. §10 verbietet, die Regenerierung davor einzusortieren.**

Zugleich sagt die Invalidierungs-Matrix in ihrer ersten Zeile: eine geänderte Binary invalidiert
Q02–Q10 vollständig. **Wenn der vereinte Batch mit Equity-Telemetrie kommt, sind die Ergebnisse der
fünf Baskets in dem Moment ungültig, in dem sie fertig werden** — 6 bis 42 Stunden serielle
Fabrikzeit, deren Verdikte die Matrix selbst verwirft.

Drei Auswege, keinen davon wähle ich allein:

| | Weg | Preis |
|---|---|---|
| **A** | Baskets laufen wie beschlossen, Batch danach mit Recompile | 6–42 h **Stillstand der gesamten Fabrik** (Lease-Befund oben), deren Verdikte danach verworfen werden. 2.3 schließt mit Basket-Anteil — aber mit einem, der überschrieben wird. |
| **B** | Baskets **jetzt** anhalten, Batch mit Recompile, Baskets darin | spart die 6–42 h; **widerspricht der ausdrücklichen OWNER-Entscheidung** und verzögert 2.3 um die Batch-Vorbereitung |
| **C** | Baskets laufen, Batch **ohne** Recompile und ohne Equity-Telemetrie | keine Invalidierung, kein Konflikt — aber die Hauptunsicherheit aus rev5 bleibt ungemessen, und ein späterer Beschluss kostet einen zweiten Vollbatch |

**Empfehlung, nach dem Lease-Befund geändert.** Vor der Messung empfahl ich A: die fünf Baskets
liefern den einzigen Basket-Anteil, den 2.3 je hatte, und ihr Wert liegt im **Nachweis, dass der
Basket-Pfad End-to-End trägt** — der heute überhaupt erst wiederhergestellt wurde
(Copy-on-Claim-Repair, Progress-Detektor-Repair). Dieser Nachweis überlebt die Invalidierung, das
Verdikt nicht.

Der Preis ist jetzt aber ein anderer: **nicht 6–42 h einer Spur, sondern 6–42 h der ganzen Fabrik**,
bei 2.300 wartenden Zeilen. Damit kippt die Abwägung:

> **Neue Empfehlung: einen Basket zu Ende laufen lassen, dann anhalten.** Ein einziger vollständiger
> Basket-Durchlauf liefert den End-to-End-Nachweis vollständig — das ist der Teil, der die
> Invalidierung überlebt. Die restlichen vier liefern nur Verdikte, und die werden ohnehin verworfen.
> Ersparnis: geschätzt **5 bis 35 Fabrikstunden**.

Das ist eine Änderung an einer ausdrücklichen OWNER-Entscheidung und wird deshalb **vorgelegt, nicht
ausgeführt.** Bis zu einer Antwort laufen alle fünf wie beschlossen.

---

## 6 · Drei reduzierte Fassungen, wie §7.4 verlangt

| | Umfang | Rechenzeit | Was verloren geht |
|---|---|---|---|
| **R1 — nur die knappsten Fenster** | die 21 Sleeves, nur die Zeiträume der 20 Grenztage (≤ −5 %) plus je 10 Tage Rand | **~3 h** | Keine Aussage über die Quote, nur über die Tiefe. Beantwortet: „laufen die bekannten Grenztage intraday tiefer als der Schluss" — beantwortet **nicht**, ob es weitere Grenztage gibt, die der Schlusskurs verbirgt. Das ist die Frage, die 26 % von 78 % trennt, also die **halbe** Antwort zum kleinsten Preis. |
| **R2 — nur ein Sizing-Punkt** | alle 91 Paare, aber nur bei 0,60× ausgewertet | identisch zum Vollbatch (der Multiplikator ist eine Auswertung, kein Lauf) | **nichts an Rechenzeit gespart.** Aufgenommen, weil §7.4 drei Fassungen verlangt, und weil die Erwartung „ein Sizing-Punkt ist billiger" ausdrücklich **falsch** ist: gerechnet wird die Trade-Reihe, gesizt wird danach. |
| **R3 — nur die gewichtigen Paare** | die 21 Sleeves mit Tagesreihe statt aller 91 | **~5 h** ohne Baskets | Die Populationsverzerrung bleibt vollständig bestehen — die Aussage gilt weiter für 18 von 91. Löst Grund 1 (Intraday), lässt Grund 2 (Population) unberührt. |

**Wenn nur eine Fassung finanziert wird: R3.** Sie schließt die Unsicherheit, die rev5 an die Spitze
setzt, zum Bruchteil des Preises, und sie erhält genau die Sleeves, über die alle bisherigen Zahlen
tatsächlich reden. **R1 ist die Notfassung**, wenn auch die 5 Stunden nicht da sind.

---

## 7 · Reihenfolge, wenn freigegeben

1. Pilot: **ein** Sleeve mit Equity-Telemetrie, gegen seinen bestehenden Lauf gestellt. Liefert den
   Laufzeitaufschlag und den Nachweis, dass die Trade-Reihe unverändert bleibt.
2. Bleibt sie das nicht, ist das selbst ein Befund (Telemetrie ändert Verhalten) → anhalten.
3. Rebuild der 53 C3-Paare, dann alle 91 mit dem neuen Emitter.
4. Auswertung gegen **einen neuen Snapshot**, nicht gegen `3472a5d2e1b5`.

Schritt 1 ist nicht verhandelbar. Ein Vollbatch mit ungemessenem Telemetrie-Aufschlag ist derselbe
Fehler wie eine Vollextraktion mit ungeprüftem Extraktor, gegen den §4 gerichtet ist.

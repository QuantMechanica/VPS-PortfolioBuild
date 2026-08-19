# Q09_ACCELERATION — wo die 26 Stunden hingehen, und welcher Weg sie kürzt

**Stand:** 2026-08-19 · Work Order Q14–Q16 §4.3
**Grundlage:** der laufende Pilot `46409fc4` (QM5_11294/XAUUSD, DXZ, 40 Zellen), zwei
abgeschlossene Zellen mit vollständigen Fenster-Zeitstempeln

---

## 0 · Die Antworten

> **Die Zellzeit im Beharrungszustand ist 38 min 46 s, nicht 24.** 40 Zellen sind damit
> **≈26 Stunden**, nicht 16 und nicht 3,7. Meine dritte Korrektur an dieser Zahl heute — die
> Messung ersetzt jetzt die Schätzung.
>
> **Der Datumsfenster-Weg trägt nicht.** 81 % aller Kalendertage des Fensters enthalten ein
> Nachrichtenereignis, selbst nur USD-HIGH sind noch 48,8 %. Und die Fixkosten je Testerlauf
> (≈3,3 min) machen Fragmentierung teurer, nicht billiger.
>
> **Der tragfähige Weg ist ein anderer: das `full`-Fenster ist die Vereinigung der beiden
> anderen** und kostet allein **46 % der Zellzeit.**

---

## 1 · Die Zerlegung — §4.3.1 und §4.3.2

**[MESSUNG]** Zelle `control_off__m0__c0__s17`, sauberer Beharrungszustand (die Vorgängerzelle
endete 18:23:05, alle Zeiten lokal):

| Fenster | Zeitraum | fertig um | Dauer |
|---|---|---|---:|
| `selection` | 2019-01-01 … 2023-12-31 (1.825 d) | 18:36:28 | **13 min 23 s** |
| `holdout` | 2024-01-01 … 2025-12-31 (730 d) | 18:43:56 | **7 min 28 s** |
| `full` | 2019-01-01 … 2025-12-31 (2.556 d) | 19:01:51 | **17 min 55 s** |
| **Zelle gesamt** | | | **38 min 46 s** |

Zum Vergleich Zelle `s42` (die erste, mit History-Synchronisation): selection 15 min, holdout
5 min 55 s, full 24 min 3 s — **die erste Zelle ist ~17 % teurer**, der Unterschied ist nicht
dominant.

**Das Kostenmodell, aus den drei Fenstern angepasst** (`t = a + b·Tage`):

| | |
|---|---|
| **Fixkosten je Testerlauf** | **a ≈ 197 s (3,3 min)** |
| **variable Kosten** | **b ≈ 0,343 s je Kalendertag** |

Kontrolle: 1.825 d → 197 + 626 = 823 s gegen gemessene 803 s. Die Anpassung trägt.

**Antwort auf §4.3.2:** je Zelle sind **9,9 min Fixkosten** (drei Läufe) und **29 min variabel**
(5.111 Kalendertage über drei Fenster). Nur der variable Teil lässt sich durch kürzere Zeiträume
senken — und der ist mit 75 % der Löwenanteil.

## 2 · Das `full`-Fenster rechnet dieselbe Zeit zweimal — §4.3.3

**[MESSUNG]**

```
selection : 2019-01-01 .. 2023-12-31
holdout   : 2024-01-01 .. 2025-12-31
full      : 2019-01-01 .. 2025-12-31
```

**`selection` ∪ `holdout` = `full`, exakt und lückenlos** (die Naht liegt zwischen 2023-12-31 und
2024-01-01). Von den 5.111 gerechneten Kalendertagen je Zelle sind **2.556 eine Wiederholung.**

**Kosten des `full`-Fensters: 197 s + 0,343 × 2.556 = 1.074 s = 17,9 min je Zelle — 46 % der
Zellzeit.** Über 40 Zellen sind das **11,9 Stunden von 25,8.**

**Ist es entbehrlich?** Nicht ganz, und das gehört dazu:

* **Additive Größen** (Trades, Netto-P&L, blockierte Einstiege) sind aus den beiden Teilfenstern
  exakt rekonstruierbar.
* **Der maximale Drawdown ist es nicht.** Ein Drawdown, der über die Jahresnaht läuft, ist in
  keinem der Teilfenster vollständig enthalten. Auch Profitfaktor und Sharpe über den Gesamtzeitraum
  sind aus den Hälften nur näherungsweise zusammensetzbar.
* Der Kontrakt verlangt alle drei (`q09_news_runner.py:1043`).

> **Der Verlust ist also präzise benennbar: es geht die Naht verloren, nicht das Fenster.** Für die
> Frage, die Q09 beantwortet — *ist dieser EA mit oder ohne News-Filter besser* — ist ein
> Drawdown, der über den 31.12.2023 läuft, kaum entscheidungsrelevant; er betrifft beide Arme
> gleich.

## 3 · Warum der Datumsfenster-Weg nicht trägt

Die Vermutung der Work Order war, die Information stecke in den Stunden um Nachrichtentermine und
nicht in der vollen Historie. **Gemessen am Kalenderbündel `q09cal-20150101-20260809` (48.245
Ereignisse):**

| Auswahl | Tage im Fenster 2019–2025 | Anteil der 2.556 |
|---|---:|---:|
| irgendein Ereignis | 2.072 | **81,1 %** |
| nur HIGH impact | 1.824 | 71,4 % |
| nur USD | 1.723 | 67,4 % |
| **nur USD + HIGH** | **1.248** | **48,8 %** |
| nur NFP | 177 | 6,9 % |

> **Selbst die schärfste sinnvolle Auswahl — USD und HIGH — deckt noch die Hälfte aller
> Kalendertage.** Der Nachrichtenkalender ist dicht; es gibt keine langen ereignisfreien Strecken,
> die man weglassen könnte.

**Und die Kostenstruktur macht es schlimmer:** 1.248 Tage aus 2.556 sind nicht zusammenhängend. Sie
zerfallen in mehrere hundert Blöcke, und **jeder Block kostet 197 s Fixkosten.** Schon bei
100 Blöcken wären das 5,5 Stunden je Fenster gegen heute 17,9 Minuten. **Die Fragmentierung kostet
mehr, als die Kürzung spart** — der Weg ist nicht knapp gescheitert, er ist um eine Größenordnung
falsch.

**Damit ist die Einschätzung der Work Order widerlegt**, und zwar aus einem Grund, der vorher nicht
sichtbar war: nicht weil die Information über die Historie verteilt wäre, sondern weil der
Tester pro Lauf eine feste Anlaufzeit hat und Nachrichtentage fast überall liegen.

## 4 · Die Wege, bewertet — §4.3.2

| Weg | Ersparnis | Aussageverlust | Aufwand |
|---|---:|---|---|
| **A · `full` streichen** | **46 % (11,9 h von 25,8)** | der über die Naht laufende Drawdown; PF/Sharpe gesamt nur approximierbar | Kontraktänderung (`WINDOW_NAMES`, Metrikprüfung) — **nicht autonom** |
| **B · Zellzahl senken: 3 statt 5 Seeds** | **40 % (3+21=24 statt 40 Zellen)** | Seed-Streuung schwächer belegt; Q07 prüft Seed-Stabilität aber bereits separat | Kontraktänderung, `SEEDS` ist kanonisch |
| **C · Zweistufige Temporalsuche** | bis 60 % | grobe Stufe kann ein Optimum zwischen den Rastern verfehlen | Kontrakt + neue Ablauflogik |
| **D · Zellen parallelisieren** | **0 real** | keiner | — |
| **E · Datumsfenster** | **negativ** | — | — |

**Zu D, weil es die verlockendste Idee ist:** die Zellen sind untereinander unabhängig und ließen
sich auf mehrere Terminals verteilen. **Es bringt trotzdem nichts.** Die Flotte regelt seit Stunden
gegen die 90-%-CPU-Schwelle; zusätzliche Q09-Zellen laufen nicht *zusätzlich*, sondern **verdrängen
Gate-Läufe**. Parallelisierung verwandelt 26 Stunden Wanduhrzeit in 26 Stunden verdrängter
Fabrikarbeit — das ist keine Ersparnis, sondern eine Umbuchung.

**Damit ist auch §4.3 Punkt 3 der Frageliste beantwortet: Q09 läuft heute auf einem Slot, also
seriell — aber die 26 Stunden sind Fabrikzeit *und* Wanduhrzeit zugleich, weil der Slot währenddessen
nichts anderes tut.**

## 5 · Empfehlung

**A und B zusammen, in dieser Reihenfolge.** Sie sind unabhängig und multiplizieren sich:

| Stufe | Zellen | Fenster je Zelle | Zeit je Zeile |
|---|---:|---:|---:|
| heute | 40 | 3 | **25,8 h** |
| nur A (`full` weg) | 40 | 2 | **13,9 h** |
| A + B (3 Seeds) | 24 | 2 | **8,3 h** |

> **A + B senken die Q09-Kosten je Zeile von 26 auf gut 8 Stunden — Faktor 3.** Für 21 Zeilen sind
> das 175 statt 542 Stunden.

**Was ich dagegen sage, damit die Empfehlung ehrlich bleibt:** B schwächt die Seed-Streuung, und
gerade diese Serie hat mehrfach erlebt, dass zu kleine Stichproben Scheinbefunde erzeugen. Die
kanonischen fünf Seeds sind auch anderswo verankert. **Wenn nur eines von beiden kommt, dann A** —
es kostet nur die Naht und spart fast die Hälfte.

**Beides sind Änderungen am Gate-Kontrakt und damit nicht autonom (§3.3).** Vorgelegt, nicht
ausgeführt. Der laufende Pilot bleibt unverändert auf 40 Zellen und 3 Fenstern, damit er als
Referenzmessung taugt.

## 6 · Der Schätzfehler — §4.5

| Quelle | Zellzeit |
|---|---:|
| `2026-08-17_phase1_1_…md`: 9.250 Zellen ≈ 865 h | **5,6 min** |
| **gemessen am Piloten** | **38,8 min** |

**Faktor 7, nicht 4** — meine Zwischenkorrektur auf 24 min war selbst zu optimistisch, weil ich sie
aus dem Abstand zweier Quittungen gebildet habe, ohne dass die zweite Zelle schon vollständig war.

**Woher die 865 Stunden stammen, konnte ich nicht klären** — das Dokument nennt sie als
„beobachtet", ohne Bezug auf konkrete Läufe. Zwei Erklärungen sind plausibel und beide würden die
Zahl senken: eine andere Fenstergröße (die 5,6 min entsprächen bei b = 0,343 s/Tag rund
780 Kalendertagen, also etwa einem `holdout`-Fenster) oder eine Zählung, die nur einen der drei
Läufe je Zelle erfasst. **Die zweite Erklärung passt fast exakt: 38,8 min / 3 Fenster ≈ 12,9 min,
und das ist immer noch mehr als 5,6.** Ich lasse es als ungeklärt stehen, statt eine Herleitung zu
konstruieren.

**§4.5.2 — hängt die Zellzeit an der Auslastung?** Beide gemessenen Zellen liefen bei 6 bis 10
aktiven Claims und CPU 97–100 %. **Damit ist die 38,8-min-Zahl eine Auslastungszahl**, nicht die
Zeit eines ungestörten Laufs, und sie gilt nur unter dieser Angabe. Ein ungestörter Lauf wäre
schneller — messbar wäre das nur bei angehaltener Flotte, und dafür ist der Preis zu hoch.

**§4.5.3 — wo sonst Wanduhrzahlen als Planungskonstanten dienen:** dieselbe Klasse wie das
Q04-Fold-Budget (`q02_full_runtime_sec × Headroom`, gemessen unter anderer Parallelität, später als
Konstante angewandt). Weitere Kandidaten, die ich noch nicht geprüft habe: `timeout_min` in den
Work-Item-Payloads (105 und 120 min beobachtet), `cell_timeout_sec = 3600` in der Q09-Bindung, und
`ACTIVE_PROGRESS_STALL_MIN = 20` im Reaper. **Alle drei sind Wanduhrgrößen in einer Fabrik, deren
Wanduhrzeit von der Parallelität abhängt.** → **OQ-24**

---

## 7 · Nachtrag: der Verkettungstest — Weg A ist fast verlustfrei

**Auftrag §1 der Folge-Work-Order.** Ergebnis: **die Naht lässt sich rekonstruieren, und der
Restfehler ist bezifferbar.**

### 7.1 Die Läufe emittieren eine Reihe — §1.1

Jedes Fenster schreibt `raw/run_01/logger_sample.jsonl` mit **täglichen
`EQUITY_SNAPSHOT`-Ereignissen** plus dem vollständigen Order-Lebenszyklus. Auflösung: ein
Snapshot je Handelstag.

**[MESSUNG] Die Ereigniszahlen addieren sich exakt:**

| Ereignis | selection | holdout | Summe | **full** |
|---|---:|---:|---:|---:|
| `EQUITY_SNAPSHOT` | 1.287 | 514 | **1.801** | **1.801** |
| `ENTRY_ACCEPTED` | 298 | 127 | **425** | **425** |
| `TM_CLOSE` | 214 | 84 | **298** | **298** |
| `FRIDAY_CLOSE` | 246 | 99 | **345** | **345** |

Der `full`-Lauf erzeugt also **exakt dieselben Ereignisse** wie die beiden Teilläufe zusammen —
kein zusätzlicher Trade, kein fehlender.

### 7.2 Der Verkettungstest — §1.2

Die Equity-Reihen wurden verkettet (Offset = Endstand `selection` − Startstand `holdout`, bei
fixem Risiko ein reiner Additionsschritt) und gegen den `full`-Lauf gestellt. **Beide fertigen
Zellen, identisches Ergebnis:**

| | verkettet | `full` gemessen | Abweichung |
|---|---:|---:|---:|
| **Max-Drawdown** | **17.072,73** | **17.072,73** | **0,00 (0,000 %)** |
| Nettogewinn | 11.410,77 | 11.344,55 | 66,22 (**0,584 %**) |
| Rendite/Drawdown | 0,6684 | 0,6645 | 0,0039 |

> **Der Max-Drawdown über die Naht ist exakt rekonstruierbar** — die Größe, um die es bei Weg A
> ging, geht nicht verloren.

**Der Restfehler ist der Nettogewinn: 66,22 von 11.410, also 0,58 %.** Er entsteht an der Naht
selbst — eine Position, die über den Jahreswechsel offen ist, wird im geteilten Lauf am Fensterende
glattgestellt und im neuen Fenster neu eröffnet. Die Trade-Zahlen bleiben gleich, der Schlusskurs
der Nahtposition unterscheidet sich.

**Antwort auf §1.3:** Weg A ist damit **nicht** „46 % sparen gegen den Verlust der Naht", sondern
**„46 % sparen gegen 0,58 % Ungenauigkeit im Nettogewinn, bei exaktem Drawdown"**. Für eine
Verhältniszahl, die auf zwei Nachkommastellen verglichen wird, ist das unerheblich — und für die
Frage, die Q09 beantwortet (mit oder ohne News-Filter), trifft der Nahtfehler **beide Arme gleich**
und hebt sich im Vergleich auf.

**Zusatzkosten für die Reihen-Emission: null.** Sie existiert bereits.

### 7.3 Was ich zur Vorsicht anmerke

Der Test lief auf **zwei Zellen desselben EA, beide `CONTROL_OFF`**. Bei einem EA, der über die
Naht deutlich mehr offene Positionen hält, wäre der 0,58-%-Fehler größer. Die saubere Fassung der
Kontraktänderung sollte den Nahtfehler deshalb **mitschreiben** statt ihn zu ignorieren: die
Differenz zwischen verkettetem und direkt gemessenem Ergebnis ist genau einmal je EA bestimmbar —
und wenn sie klein bleibt, ist die Sache erledigt.

# SEED_SENSITIVITY — der Seed ist in Q09 wirkungslos, und zwar beweisbar

**Stand:** 2026-08-19 · Work Order §2 (Weg B)
**Grundlage:** Pilot `46409fc4`, zwei fertige `CONTROL_OFF`-Zellen (Seeds 42 und 17),
Quelltext `framework/include/QM/QM_Entry.mqh`, `QM_SeedRNG.mqh`

---

## 0 · Die Antwort, und sie ist schärfer als die Frage

> **Weg B ist nicht „drei statt fünf Seeds". Es ist „ein Seed statt fünf", und es kostet keine
> Information.**
>
> In Q09-Läufen wird der Zufallsgenerator **nie gezogen**. Der Seed steht im Setfile, wirkt aber
> auf nichts. Zwei Zellen mit Seed 42 und 17 liefern identische Equity, identischen Drawdown,
> identischen Gewinn — auf den Cent.
>
> **Die 40 Zellen des Piloten sind 8 verschiedene Konfigurationen, jede fünfmal gerechnet.**

---

## 1 · Der empirische Befund — §2.1 und §2.3

**[MESSUNG]** Zellen `control_off__m0__c0__s42` und `…__s17`, alle drei Fenster:

| | Seed 42 | Seed 17 |
|---|---:|---:|
| Max-Drawdown (verkettet) | 17.072,73 | 17.072,73 |
| Max-Drawdown (`full`) | 17.072,73 | 17.072,73 |
| Nettogewinn (verkettet) | 11.410,77 | 11.410,77 |
| Nettogewinn (`full`) | 11.344,55 | 11.344,55 |
| Rendite/Drawdown | 0,6684 | 0,6684 |

**Nicht „nahe beieinander" — identisch.** Und auf Artefaktebene:

| Fenster | `report.htm` Größe s42 | Größe s17 |
|---|---:|---:|
| selection | 640.584 B | **640.584 B** |
| holdout | 291.254 B | **291.254 B** |
| full | 900.214 B | **900.214 B** |

Byteidentische Größen bei unterschiedlichen SHA-256 — die Reports unterscheiden sich nur in
eingebetteten Metadaten (Zeitstempel, Lauf-Tag, der Seed-Wert selbst), **nicht im Handel**.

**Die Setfiles unterscheiden sich in genau einer Zeile:**

```
s42: qm_rng_seed=42
s17: qm_rng_seed=17
```

## 2 · Warum — aus dem Quelltext, nicht aus der Beobachtung

`framework/include/QM/QM_Entry.mqh:333`:

```cpp
if(g_qm_entry_stress_reject_prob > 0.0 &&
   QM_RandBoolTagged("entry_reject", g_qm_entry_stress_reject_prob))
```

Der zentrale RNG (`QM_SeedRNG.mqh`, *„All randomness in V5 EAs goes through this module — no direct
MathRand/MathSrand calls"*) hat im Framework **genau einen Konsumenten**: die
Stress-Einstiegsablehnung. Und die wird nur gezogen, wenn `g_qm_entry_stress_reject_prob > 0.0`.
Der Kommentar sagt es selbst: *„Q05 MED runs with probability = 0 (this is a no-op); Q06 HARSH runs
with probability = 0.10."*

**[MESSUNG] In keiner der 40 Q09-Zellsetfiles steht `qm_stress_reject_probability`** — es gilt der
Vorgabewert `0.0` (`QM_Entry.mqh:63`). Der RNG wird also nie gezogen.

> **Damit ist die Wirkungslosigkeit nicht empirisch wahrscheinlich, sondern konstruktiv
> gesichert.** Für jeden Lauf ohne Stress-Ablehnung sind alle fünf Seeds derselbe Lauf.

## 3 · Q07 ist davon **nicht** betroffen — die Gegenprüfung

Der naheliegende Verdacht wäre, dass damit auch das Multiseed-Gate Q07 nichts misst. **Er trifft
nicht zu.** Die Q07-Setfiles sind die `q06_stress_harsh_seedNN`-Dateien, und die tragen:

```
qm_rng_seed=42
qm_stress_reject_probability=0.1000
```

**Q07 fährt die Seeds auf der HARSH-Stufe, wo der RNG aktiv ist.** Das Gate misst genau das, wofür
es gebaut wurde — Stabilität gegen zufällige Einstiegsausfälle. Kein Defekt.

Das ist zugleich die Erklärung, warum der Seed-Sweep in Q09 überhaupt existiert: er wurde aus dem
Q07-Muster übernommen, wo er trägt, in einen Kontext, wo er es nicht tut.

## 4 · Die Konsequenz für die Zellzahl

**[MESSUNG]** Alle 40 Setfiles, Seed-Zeile entfernt, dann gehasht:

| | |
|---|---:|
| Zellen | 40 |
| **verschiedene Konfigurationen** | **8** |
| Wiederholungen je Konfiguration | **5** |

Die acht: `CONTROL_OFF` plus `POLICY_ON` × 7 Temporalmodi — genau die Achse, die Q09 messen soll.

**Zusammen mit Weg A:**

| Stufe | Zellen | Fenster | Testerläufe | **Zeit je Zeile** |
|---|---:|---:|---:|---:|
| heute | 40 | 3 | 120 | **25,8 h** |
| nur A (`full` weg) | 40 | 2 | 80 | 13,9 h |
| **nur B (1 Seed)** | **8** | 3 | 24 | **5,2 h** |
| **A + B** | **8** | **2** | **16** | **2,8 h** |

> **A + B zusammen senken Q09 von 25,8 auf 2,8 Stunden je Zeile — Faktor 9 — bei einem
> Informationsverlust von 0,58 % im Nettogewinn und null beim Drawdown.**
>
> Für 21 Zeilen: **59 statt 542 Fabrikstunden.**

**Ich korrigiere damit meine eigene Empfehlung aus `Q09_ACCELERATION.md` §5.** Dort stand „wenn nur
eines von beiden, dann A", mit der Begründung, B schwäche die Seed-Streuung. **Diese Begründung war
falsch** — es gibt keine Seed-Streuung, die geschwächt werden könnte. B ist der stärkere der beiden
Wege und der einzige mit exakt null Aussageverlust.

## 5 · Was ich nicht behaupte

* **Nicht, dass Seeds allgemein wirkungslos sind.** In Q06/Q07 sind sie es nachweislich nicht.
* **Nicht, dass ein Seed für alle Gates reicht.** Die Aussage gilt für Läufe mit
  `qm_stress_reject_probability = 0`, und das ist im Q09-Kontrakt der Fall.
* **Nicht, dass es bei jedem EA so ist.** Ein EA, der den RNG über einen anderen Pfad zieht, wäre
  eine Ausnahme — im heutigen Framework existiert dieser Pfad nicht, aber ein künftiger EA könnte
  ihn schaffen.

**Die robuste Fassung der Kontraktänderung** wäre deshalb nicht „ein Seed", sondern eine
**Bedingung**: fahre einen Seed, solange `qm_stress_reject_probability = 0`; fahre fünf, sobald sie
größer null ist. Das ist prüfbar aus dem Setfile, kostet nichts, und bleibt richtig, wenn sich das
Framework ändert.

## 6 · Der Auftrag aus §2, formal beantwortet

| Frage | Antwort |
|---|---|
| Hätten drei Seeds dasselbe Verdikt ergeben? | **Ja — und ein Seed auch.** Alle fünf Läufe sind derselbe Lauf. |
| Wie weit liegen die Kennzahlen auseinander? | **Null.** Auf den Cent identisch. |
| Kostet die Auswertung Fabrikzeit? | Nein, sie lief auf vorhandenen Artefakten. |
| Reicht eine Beobachtung als Beleg? | **Hier ja** — weil der Befund nicht statistisch ist, sondern aus dem Quelltext folgt. Die zwei Zellen bestätigen ihn, sie tragen ihn nicht. |

**Nichts geändert.** Die Zellzahl und die Seed-Liste sind Kontraktgrößen; dies ist die Vorlage.
Der laufende Pilot bleibt auf 40 Zellen, damit die Referenzmessung intakt bleibt — auch wenn jetzt
feststeht, dass 32 seiner Zellen Wiederholungen sind.

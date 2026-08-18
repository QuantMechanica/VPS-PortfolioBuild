# E3_DECISION_BRIEF — ein echtes Holdout einrichten

**Snapshot:** `3472a5d2e1b5` · **Stand:** 2026-08-18 · Work Order Runde 5 §8
**Status: entscheidungsreif vorgelegt, NICHT eingerichtet.** Änderungen an
Gate-Fensterdefinitionen bleiben nicht-autonom (Runde 1 §3.3).

---

## 0 · Warum die Lage sich seit E-3 verschärft hat

Zwei Dinge sind seit der ursprünglichen Eskalation dazugekommen, und beide erhöhen den Preis des
Wartens:

1. **Der Ersatz ist schwächer geworden, nicht stärker.** rev4 führte einen zeitlichen Holdout als
   +12 Punkte. rev5 §2 zeigt: bei konstanter Buchvollständigkeit sind es **+3 Punkte** mit
   überlappenden Bändern. Der Behelf, der E-3 hätte aufschieben können, trägt nicht mehr.
2. **Es wird ohnehin bald alles neu gelaufen** (§7). Eine Änderung der Fensterdefinition ist genau
   dann am billigsten — später beschlossen kostet sie einen zweiten Vollbatch.

---

## 1 · Was konkret abgetrennt würde

**[MESSUNG]** Buchspanne 2017-10-09 bis 2025-12-26, 50 Fenster à 60 Kalendertage, davon 36 mit
vollständigem Buch:

| Endstück | Schnitt | Holdout-Fenster | davon vollständig | Trainingsfenster | davon vollständig |
|---|---|---:|---:|---:|---:|
| 12 Monate | 2024-12-26 | **6** | **6** | 44 | 30 |
| **18 Monate** | **2024-06-27** | **9** | **9** | 41 | 27 |
| 24 Monate | 2023-12-27 | 12 | 12 | 38 | 24 |

**Bemerkenswert und günstig:** in jeder Variante sind **alle** Holdout-Fenster vollständige
Buchfenster. Das Holdout ist damit frei von genau dem Konfundenten, der rev4s Selektionsbefund
zerlegt hat — es vergleicht nicht zufällig auch Buchgrößen.

**Empfehlung zur Größe: 18 Monate.** Begründung, nicht Geschmack:

* 6 Fenster (12 Monate) sind zu wenig. Ein Wilson-Band auf n = 6 ist rund 45 Punkte breit — es
  könnte die 80-%-Frage nicht entscheiden, egal wie das Ergebnis ausfällt.
* 9 Fenster geben ein Band von rund **32 Punkten**. Das ist immer noch breit, aber es kann eine
  Quote von 60 % von einer von 90 % trennen — und genau diese Trennung ist die offene Frage.
* 12 Fenster (24 Monate) wären besser, kosten aber ein Viertel der vollständigen Fenster im Training
  (27 → 24) und schneiden in den Zeitraum, aus dem der größte Teil der Buchvollständigkeit stammt.

**Kein Größenschnitt macht das Holdout entscheidungsstark.** Das gehört zur Vorlage: 9 Fenster sind
ein *Test auf grobe Fehlanpassung*, keine Bestätigung einer 80-%-Quote. Wer es für Letzteres hält,
wird es falsch verwenden.

---

## 2 · Was es jetzt kostet, was es später kostet

| | jetzt, im vereinten Batch | später, separat |
|---|---|---|
| Fabrikzeit | **null zusätzlich** — es ist eine Änderung der Auswertungs- und Gate-Fensterdefinition, kein zusätzlicher Lauf | **ein zweiter Vollbatch**, 1–2 Tage (§7 §2) |
| Aufwand | Fensterdefinition ändern, betroffene Gates neu parametrieren, dokumentieren | derselbe Aufwand **plus** der Batch |
| Risiko | die Änderung geht in denselben Snapshot ein, gegen den alles Neue gerechnet wird | zwei Snapshots, deren Zahlen nicht mischbar sind |

**Der Unterschied ist nicht graduell.** Jetzt ist es eine Definitionsänderung; später ist es eine
Definitionsänderung **plus** die Wiederbeschaffung aller Läufe, die unter der alten Definition
gemessen wurden.

---

## 3 · Was man bei Verzicht verliert — und was der rev4-Behelf beweist und was nicht

§8.3 verlangt die Bezifferung des Unterschieds **in dem, was bewiesen wird**. Er ist qualitativ, nicht
quantitativ, und das ist der Punkt:

| | zeitlicher Holdout aus rev4 §3 | echtes Holdout (E-3) |
|---|---|---|
| Konstruktion | teilt **vorhandene** Fenster in zwei Hälften | schafft einen Zeitraum, den **kein Gate je gesehen hat** |
| Was die Gates gesehen haben | **beide Hälften** — die Gate-Läufe deckten die volle Historie | nur das Training |
| Was ausgeschlossen wird | ein *grober* Abwärts-Bias fällt auf | Selektion auf dem Bewertungszeitraum ist **konstruktiv unmöglich** |
| Was **nicht** ausgeschlossen wird | Selektionseffekte, Regimewechsel, Buchvollständigkeit — nach rev5 §2 sind mindestens zwei davon nicht trennbar | Regimewechsel bleibt (unvermeidbar); Selektion entfällt |
| Aktueller Befund | +3 pp, nicht von null unterscheidbar | — |

**In einem Satz:** der rev4-Behelf kann sagen „ein großer Bias fällt nicht auf". Er kann nicht sagen
„es gibt keinen". Ein echtes Holdout kann Letzteres — für den Selektionsanteil, nicht für das Regime.

**Bei Verzicht bleibt die Selektionsunsicherheit dauerhaft offen**, und sie ist in rev5 §R5-4 von
einer Entlastung zu einem offenen Punkt geworden. Sie ließe sich dann nur noch durch echte
Vorwärtszeit schließen — also durch Warten oder durch den Livetest (`LIVETEST_OPTION.md`).

---

## 4 · Verbrauchscharakter — wofür wird es ausgegeben?

**Ein Holdout ist nach einmaliger Auswertung verbraucht.** Wer es zweimal befragt, hat es beim
zweiten Mal in Trainingsdaten verwandelt. Deshalb gehört vor die Einrichtung die Festlegung, welche
**eine** Frage es beantwortet.

**Vorschlag, verbindlich vorab zu fixieren:**

> Bei dem in rev5 empfohlenen Sizing — und **nur** bei diesem einen — wie hoch ist die
> Bestehensquote auf den 9 Holdout-Fenstern, auf Schlusskursbasis **und** auf dem Intraday-Maß,
> sofern die Equity-Telemetrie aus §7 da ist?

Nicht: „welches Sizing ist auf dem Holdout am besten" — das wäre eine Optimierung auf dem Holdout und
verbrennt es sofort. Nicht: eine Wiederholung nach jedem Buchumbau.

**Was das Ergebnis auslösen würde, ebenfalls vorab:**

* Holdout-Quote im Band des Trainings ⇒ die Trainingszahl ist die beste verfügbare Schätzung.
* Holdout deutlich darunter ⇒ Selektionsbias belegt; die gesamte Quotenschätzung fällt.
* Holdout deutlich darüber ⇒ **kein** Anlass, die Trainingszahl anzuheben — n = 9.

---

## 5 · Zur Entscheidung

| Option | |
|---|---|
| **E-3 jetzt einrichten, 18 Monate** | kostet keine zusätzliche Fabrikzeit, wenn es mit dem Batch aus §7 kommt. Verlangt eine Änderung der Gate-Fensterdefinitionen — nicht-autonom. |
| **E-3 später** | derselbe Aufwand plus ein zweiter Vollbatch |
| **E-3 verwerfen** | die Selektionsunsicherheit bleibt dauerhaft offen und ist nur noch durch Vorwärtszeit zu schließen |

**Ich richte nichts ein.** Diese Vorlage endet hier, wie §8 es verlangt.

# OPEN_QUESTIONS — Rückfragen vor Beantwortung des externen Audits

Stand 2026-08-18. Angelegt nach §5 der Work Order. Jede Zeile blockiert eine
Audit-Antwort; keine wird durch eine plausible Zahl ersetzt.

---

## OQ-1 · STOP-BEDINGUNG §9: die DD-Werte im Prüfdokument stammen nicht aus `ea_metrics`

**Was fehlt.** Die Work Order §4.2 macht `ea_metrics` zur autoritativen Quelle. Für die
Optimierungs-Kohorte, über die Audit-Frage 4 gestellt ist, enthält diese Tabelle die benötigten
Werte nicht:

| Phase | Zeilen in `ea_metrics` | `drawdown_pct` non-null | `profit_factor` non-null |
|---|---:|---:|---:|
| **Q14** | 11 | **0** | **0** |
| **Q15** | 1 | **0** | **0** |
| **Q16** | **0** | — | — |
| Q10 *(zum Kontrast)* | 41 | 41 | 41 |

*Query:* `SELECT phase,COUNT(*),SUM(drawdown_pct IS NOT NULL),SUM(profit_factor IS NOT NULL) FROM
ea_metrics WHERE phase IN ('Q14','Q15','Q16','Q10') GROUP BY phase`, gelaufen 2026-08-18T13:0xZ,
Snapshot `farm_state_20260818T130247Z.sqlite` (sha256 `35f44603…`).

**Warum es blockiert.** Die im Prüfdokument genannte Spanne 1,18 %–9,81 % Max-DD über 25 Survivor
kann aus der autoritativen Tabelle **nicht** stammen — dort steht für diese Phasen kein einziger
DD-Wert. Sie muss aus einem abgeleiteten Pfad kommen. Work Order §9 verlangt dann ausdrücklich:
*das Prüfdokument selbst ist zu korrigieren, bevor darauf geantwortet wird.*

**Was ich NICHT behaupte.** Ich habe nicht bewiesen, dass die Zahlen aus dem in §3.1.3 genannten
defekten Parser-Pfad stammen — nur, dass sie nicht aus `ea_metrics` stammen können. Der Unterschied
ist wichtig: es könnte ein dritter, intakter Pfad sein.

**Kosten der Beschaffung.** Zwei Wege:
1. *Herkunft klären* — die Quelle der 1,18–9,81 % benennen lassen (Datei, Query, Lauf-Zeitstempel).
   Kosten: eine Rückfrage, null Rechenzeit.
2. *Selbst neu erzeugen* — `drawdown_pct` für die Q14/Q15-Kohorte aus den Evidenzartefakten
   nachziehen. Kosten: Extraktionslauf über 14 Q14- und 1 Q15-work_item; keine Fabrikzeit, aber der
   Extraktor ist genau die Komponente, die §3.1.3/§3.1.4 als fehlerhaft markiert — er müsste vorher
   verifiziert werden.

**Bis dahin:** Audit-Frage 4 ist als **NICHT ENTSCHEIDBAR** ausgewiesen, nicht geschätzt.

---

## OQ-2 · `ea_metrics` ist zu 69 % leer — gilt sie trotzdem als autoritativ?

| `source` | Zeilen |
|---|---:|
| **`missing`** | **43.182** |
| `summary_runs` | 10.775 |
| `q04_folds` | 4.833 |
| `summary_runs_empty` | 1.679 |
| `q05q06_flat` | 1.071 |
| `q08_subgates` | 437 |
| `q07_seeds` | 256 |
| **`parse_error`** | **105** |

n = 62.457. Feldabdeckung: `profit_factor` 27 %, `trades` 27 %, `drawdown_pct` 19 %, `sharpe` **0 %**
(63 von 62.457).

**Warum es blockiert.** §4.2 verlangt, jede Zahl aus `ea_metrics` zu ziehen und alles andere als
unbestätigt zu markieren. Bei 69 % `missing` und 0 % Sharpe-Abdeckung hieße das, den größten Teil
der Audit-Antwort als unbestätigt zu kennzeichnen. **Insbesondere: `Q04` hat 16.490 Zeilen und
`drawdown_pct` non-null = 0; `Q08` hat 613 Zeilen und ebenfalls 0.**

**Rückfrage.** Ist `ea_metrics` als autoritativ gemeint *für die Felder, die sie führt*, mit
ausdrücklicher Kennzeichnung der Lücken — oder soll der Extraktor zuerst repariert und nachgezogen
werden, bevor das Audit beantwortet wird? Das Zweite verschiebt die Antwort um die Laufzeit einer
Vollextraktion.

**Kosten.** Eine Entscheidung, null Rechenzeit. Die Vollextraktion selbst: unbekannt, weil der
Extraktor laut §3.1.3 defekt ist — Aufwand erst nach dessen Reparatur schätzbar.

---

## OQ-3 · Audit-Frage 3 braucht Fenster-Datumsbereiche, die im Zustand nicht geführt werden

**Was fehlt.** Frage 3 verlangt je optimiertem Kandidaten die Datumsbereiche des
Optimierungsfensters und der drei Walk-Forward-Falten sowie den Overlap in Tagen. `work_items`
führt `from_date`/`to_date` je Lauf, aber die **Falten**grenzen liegen in den Evidenzartefakten,
nicht in einer abfragbaren Spalte.

**Warum es blockiert.** Ohne Faltengrenzen ist „Overlap > 0" nicht ausrechenbar, und die Frage ist
genau als Overlap-Rechnung gestellt.

**Kosten.** Ein Parserlauf über die Q04-Evidenzdateien der optimierten Kandidaten, um Faltengrenzen
zu extrahieren — keine Fabrikzeit, aber wieder derselbe Extraktionspfad wie in OQ-1. Reihenfolge:
erst OQ-1 klären, dann ist OQ-3 mit demselben Werkzeug beantwortbar.

---

## OQ-4 · Audit-Frage 7 verlangt externe Basisraten — Quellenfreigabe?

Frage 7 verlangt Basisraten für das Überleben backtest-selektierter Portfolios im Livebetrieb und
für FTMO-Phase-1-Bestehensquoten, und erlaubt externe Quellen ausdrücklich. **Im eigenen Bestand
existieren diese Basisraten nicht** — es gibt zwei eigene Trials (−8,7 %, −9,9976 %), das ist n = 2
und keine Basisrate.

**Rückfrage.** Sollen externe Quellen recherchiert und als extern gekennzeichnet werden, oder soll
die Antwort auf „wir wissen es nicht, und n = 2 aus eigenen Trials ist keine Basis" lauten? Die Work
Order erlaubt beides; §4.7 verlangt die ehrliche Variante, wenn die Recherche nicht erfolgt.

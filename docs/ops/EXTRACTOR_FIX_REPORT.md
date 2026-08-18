# EXTRACTOR_FIX_REPORT — E-2, `ea_metrics`

**Snapshot:** `3472a5d2e1b5` (`artifacts/audit_baseline_snapshot_20260818.json`)
**Stand:** 2026-08-18 · Work Order Runde 5 §4.1
**Status:** Schritt 1 (Fehlerbild) **abgeschlossen und gemessen**. Schritt 2 (Reparatur) an Codex
dispatcht. Schritte 3–5 (Verifikation, Vollextraktion, Zielzustand) folgen der Reparatur.

---

## 0 · Das Ergebnis zuerst, weil es die Entscheidung E-2 verändert

**`source='missing'` ist keine Extraktor-Störung. Es ist gelöschte Evidenz.**

| Monat des Work-Items | `missing` | gesamt | Anteil |
|---|---:|---:|---:|
| 2026-05 | 7.398 | 7.398 | **100 %** |
| 2026-06 | 31.977 | 31.994 | **100 %** |
| 2026-07 | 3.806 | 18.407 | 21 % |
| 2026-08 | 1 | 4.662 | **0 %** |

Ein Extraktor-Fehler hat kein Alter. Dieser Verlauf ist eine Aufbewahrungsgrenze, und die
Stichprobe bestätigt es direkt: von 393 zufällig gezogenen `missing`-Zeilen fehlte in **389** das
Work-Item-Verzeichnis vollständig, nicht nur die Datei. Die Pfad-Drift-Hypothese ist geprüft und
**falsifiziert**: bei **0 von 393** lag die Datei unter der jeweils anderen Wurzel
(`D:\QM\reports\work_items` ↔ `D:\QM\strategy_farm\reports\work_items`).

**Damit ist der Kern von E-2 beantwortet, und die Antwort ist unbequem:** von den 69 % erreicht eine
Extraktor-Reparatur **0 %**. Die 43.182 Zeilen sind nicht falsch ausgewertet, sie haben nichts mehr
zum Auswerten. Wer diese Felder will, muss die Läufe wiederholen — das ist §7, nicht §4.

*Nebenbefund zur Ursache, mit ausdrücklicher Einschränkung:* die beiden bekannten Aufräum-Jobs sind
es **nicht**. `prune_workitem_logs.py` und `reports_log_purge.ps1` löschen ausschließlich `*.log`
und halten `.json` explizit („KEEPS: every .htm (reports), .json (metrics), .set (configs), .ini").
Ein Job, der ganze Work-Item-Verzeichnisse entfernt, ist im Repo **nicht auffindbar** — `rmtree`
oder `Remove-Item -Recurse` gegen `reports\work_items` existiert nirgends. Die Löschung ist
gemessen, ihr Urheber ist **offen** → OQ-8.

---

## 1 · Fehlerbild, Schritt 1 — welche Felder fehlen wo, und warum

Die Frage aus §4.1.1 lautete: liest der Extraktor die falsche Quelle, kennt er das Feld nicht, oder
schreibt er nur bei bestimmten Ausgängen? Für die **19.275 Zeilen, deren Evidenz tatsächlich gelesen
wurde**, ist die Antwort feldweise verschieden. Gemessene Belegung:

| Phase | source | n | net | pf | trades | dd$ | dd% | sharpe |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| Q02 | `summary_runs` | 9.628 | 9.395 | 9.395 | 9.395 | 9.395 | 9.394 | **0** |
| Q04 | `q04_folds` | 4.833 | 3.252 | 4.359 | 4.785 | **0** | **0** | **0** |
| Q02 | `summary_runs_empty` | 1.677 | 0 | 0 | 0 | 0 | 0 | 0 |
| Q03 | `summary_runs` | 1.147 | 1.145 | 1.145 | 1.145 | 1.145 | 1.145 | **0** |
| Q05 | `q05q06_flat` | 723 | **0** | 715 | 723 | 715 | 715 | **0** |
| Q08 | `q08_subgates` | 441 | 440 | 430 | 440 | **0** | **0** | **0** |
| Q06 | `q05q06_flat` | 307 | **0** | 303 | 307 | 303 | 303 | **0** |
| Q07 | `q07_seeds` | 256 | **0** | 216 | 239 | **0** | 235 | **0** |
| Q09_PORTFOLIO | `q09_portfolio` | 65 | 64 | 63 | 64 | **0** | 63 | 63 |
| Q10 | `q05q06_flat` | 41 | **0** | 41 | 41 | 41 | 41 | **0** |
| Q09_NEWS | `unknown_phase:Q09_NEWS` | 42 | 0 | 0 | 0 | 0 | 0 | 0 |
| Q14 | `unknown_phase:Q14` | 11 | 0 | 0 | 0 | 0 | 0 | 0 |
| Q15 | `unknown_phase:Q15` | 1 | 0 | 0 | 0 | 0 | 0 | 0 |
| diverse | `parse_error` | 105 | 0 | 0 | 0 | 0 | 0 | 0 |

Daraus fünf Fehlerklassen, jede mit benannter Ursache im Code:

### A — Drawdown wird für Q04 und Q08 **nie gesucht**, nicht etwa nicht gefunden

`ea_metrics.py:_extract_q04` schreibt wörtlich `"drawdown_money": None, "drawdown_pct": None` als
Konstante. Der Extraktor sieht in den Ordner gar nicht hinein. Dasselbe in `_extract_q08`.

Und die Werte sind da:

* **Q08** trägt sie im Aggregat selbst — `mc_maxdd_p95`, `mc_maxdd_p95_pct`, `mc_shuffle_dd`,
  `mc_maxdd_p95_over_as_realized_maxdd`, dazu `baseline_run` und `summary`. **Reine
  Neuauswertung, null Rechenzeit, 441 Zeilen.**
* **Q04** trägt sie nicht im Aggregat, aber jeder Fold führt `summary_path` und
  `source_summary_path` mit `source_summary_sha256`. Diese Datei hat die `runs[]`-Form mit
  `drawdown` und `drawdown_raw` — also **eine Dateiöffnung je Fold**, ebenfalls ohne Rechenzeit,
  **4.833 Zeilen**, aber abhängig davon, ob die Fold-Summaries dem Alter entgangen sind.

**Das ist die Klasse, die E-1 trägt.** 5.274 Zeilen Drawdown ohne einen einzigen Backtest.

### B — `net_profit` für die Flat-Phasen

`_extract_q05_q06` liest `d.get("net_profit")`; die Q05/Q06/Q10-Aggregate führen den Schlüssel in
den geprüften Vintages nicht. Zu klären ist, ob eine gleichwertige Größe vorliegt (`gross_total`
minus Kosten wie bei Q04) oder ob die Größe dort schlicht nie erhoben wurde. **Nicht raten** — das
ist Schritt 5, Zielzustand.

### C — `drawdown_money` für Q07 liegt vor und wird verworfen

`per_seed_detail[]` führt **`dd_money` und `dd_pct`**. Der Extraktor liest `dd_pct` (235 von 256 →
korrekt) und setzt `drawdown_money` hart auf `None`. Einzeiler.

### D — `unknown_phase`: die Phasentabelle endet vor den neuen Gates

`_AGG_PHASES` enthält Q04–Q11. **Q09_NEWS, Q14, Q15 fehlen; Q16 hat gar keine Zeilen.** 54 Zeilen.
Genau die Phasen, aus denen das Prüfdokument seine DD-Werte bezogen haben soll (E-1) — womit
belegt ist, dass sie **nicht** aus `ea_metrics` stammen können.

### E — `sharpe` ist kein Extraktor-Fehler, sondern ein nie erhobenes Feld

`_extract_summary_runs` kommentiert es selbst: „not present in summary.json". Geprüft: `summary.json`
(`runs[]`) und die Q04/Q05/Q07/Q08-Aggregate führen **keinen** Sharpe. Nur `q09_portfolio` hat ihn,
und dort ist er zu 63 von 65 gefüllt — also **vollständig, wo er existiert**.

**Zielzustand, vorab benannt (§4.1.5): `sharpe` bleibt nach jeder Reparatur leer.** Kein Extraktor
füllt ein Feld, das der Emitter nicht schreibt. Damit bleibt **Deflated Sharpe Ratio auch nach E-2
nicht rechenbar**, und die Antwort auf Prüfdokument-Frage 3 ändert sich durch E-2 nicht. Sharpe wird
nur durch einen Emitter-Wechsel im Lauf verfügbar → §7.

---

## 2 · Auftrag an Codex (Schritt 2)

Ticket: `ops_issue`, Priorität 90, Payload verweist auf dieses Dokument.

Zu reparieren, in dieser Reihenfolge, **eine Klasse pro Commit**:

1. **A/Q08** — `_extract_q08`: `mc_maxdd_p95_pct` → `drawdown_pct`, `mc_maxdd_p95` →
   `drawdown_money`. Wenn `baseline_run`/`summary` einen realisierten DD führt, diesen bevorzugen
   und die Wahl im Code begründen; `detail_json` behält beide.
2. **A/Q04** — `_extract_q04`: je Fold `summary_path`/`source_summary_path` öffnen, `drawdown` und
   `drawdown_raw` lesen (`_dd_pct_from_raw` existiert bereits), Headline = **maximaler** Fold-DD,
   je Fold in `detail_json`. Fehlende Fold-Summary ist `None`, **kein** 0.
3. **C/Q07** — `drawdown_money` aus `per_seed_detail[].dd_money`, Aggregation wie `dd_pct` (max).
4. **D** — `Q09_NEWS`, `Q14`, `Q15`, `Q16` in die Dispatch-Tabelle; unbekannte Form weiterhin
   `unknown_phase:<phase>`, nicht stillschweigend leer.
5. **B** — Q05/Q06/Q10 `net_profit`: **erst berichten, was in den Dateien steht**, dann entscheiden.
6. **E** — nicht anfassen. `sharpe` bleibt `None` und bekommt einen Kommentar mit dem Grund.

**Verbindliche Randbedingungen:**

* **Kein Schreibzugriff auf die DB in diesem Ticket.** Die Vollextraktion ist Schritt 4 und läuft
  erst nach der Verifikation — die Reihenfolge aus §4 existiert genau dafür.
* Keine Änderung an `work_items`, an Verdikten, an Gate-Schwellen. §3.3.
* `--ea`-Modus als Prüfpfad benutzen: der ändert nur eine EA und ist rückrollbar.
* Fehlende Quelldatei ⇒ `None`. **Ein 0 statt None wäre schlimmer als die heutige Lücke** — genau
  die Verwechslung, gegen die §13 „ein voller `ea_metrics` mit falschen Werten ist schlechter als
  ein leerer" gerichtet ist.

---

## 3 · Verifikation (Schritt 3) — gegen die Quelle, die die Gates gelesen haben

§4.1.3 verlangt den Abgleich gegen das, was zur Laufzeit tatsächlich gelesen wurde, nicht gegen den
Extraktor selbst. Die Gates lesen die Evidenzdatei **direkt** — `q05_stress_medium.py:94`,
`json.loads(summary_path.read_text(...))`. Der Prüfaufbau ist deshalb:

1. Stichprobe von Läufen mit vorhandener Evidenzdatei, geschichtet nach Phase (Q04, Q05, Q07, Q08),
   mindestens 25 je Phase.
2. Für jede: Wert aus der Datei mit demselben Zugriffspfad lesen, den das Gate benutzt.
3. Gegen die Extraktor-Ausgabe stellen. **Deckungsgleich oder nicht, mit Zahl** — keine Toleranz
   außer Fließkomma.
4. Abweichung ⇒ die Vollextraktion läuft nicht.

Erst danach Schritt 4 (Vollextraktion) und Schritt 5 (Coverage-Matrix vorher/nachher, verbleibende
Lücken benannt).

---

## 4 · Was diese Reparatur für den Bestand bedeutet — und was nicht

**Für die Gültigkeit bestehender Verdikte: nichts.** rev3 hat gemessen, dass die Gates die
Evidenzdateien direkt lesen und `ea_metrics` nie konsultieren. Das DD-Kriterium war wirksam
durchgesetzt; kein Verdikt wurde je auf Basis eines leeren `ea_metrics`-Feldes erteilt. Das ist ein
**Auswertbarkeits-, kein Integritätsproblem** — die Einordnung aus rev3 steht unverändert.

**Für die Antwortfähigkeit: viel** — aber begrenzt auf die 19.275 lesbaren Zeilen, und dort vor
allem auf Drawdown. Umgerechnet auf den Pool (§6, `INVALIDATION_MATRIX.md`): **81 von 91 Paaren**
haben lesbare Q08-Evidenz, **54 von 91** lesbare Q04-Evidenz.

**Für den kritischen Pfad: nichts.** Die Reparatur ist eine Code-Änderung plus eine Neuauswertung
vorhandener Dateien. Sie beansprucht keinen MT5-Slot und hält 2.3 → 3.4 nicht an.

# DECISIONS — 2026-08-18

Jeder Eingriff während der Audit-Bearbeitung nach Work Order §3.4: Zeit, Grund, betroffene
Tabellen/IDs, Rollback-Pfad, Auswirkung auf Audit-Zahlen.

---

## D-1 · 13:01:52Z — Bestandssicherung: Repo-Bundle off-host

**Grund:** Work Order §3.2, Sofortmaßnahme vor jeder Analyse. Gemessene Exposition: **1.014 Commits
über 34 lokale Branches, von keinem Remote-Ref erreichbar** (größte: `agents/gmail-monitor` 478,
`agents/pipeline-operations-project` 452, `main` 14).

**Eingriff:** `git bundle create --all` über alle 74 lokalen Refs.

| | |
|---|---|
| Ziel | `G:\My Drive\QM_Bundles\qm_repo_all_refs_20260818T130152Z.bundle` |
| Größe | 2.324.642.634 Bytes (2.217,0 MB) |
| sha256 | `a997d0b90ecc52e1ae46aa71452351a31997f552af0d6cf88b402bf8cb13885f` |

**Warum Bundle statt Push:** 34 der betroffenen Branches haben **keinen Upstream**. Sie nach
`origin` zu pushen wäre eine nach außen wirkende Veröffentlichung von 1.014 Commits ohne Auftrag —
das Bundle sichert denselben Inhalt off-host, ohne etwas zu publizieren. Die Work Order erlaubt
ausdrücklich „Push **oder** Bundle-Export".

**Rollback:** keiner nötig — rein additiv, kein Repo-Zustand verändert.
**Auswirkung auf Audit-Zahlen:** keine.

---

## D-2 · 13:02:47Z — Snapshot der Ergebnis-DB

**Grund:** §3.2, plus §4.1 verlangt je Zahl einen Zeitstempel des Laufs. Ein eingefrorener Snapshot
macht jede Audit-Zahl reproduzierbar, auch wenn die Live-DB weiterläuft.

**Eingriff:** `sqlite3.Connection.backup()` — **nicht** Dateikopie. Eine Dateikopie einer
WAL-Datenbank liefert `database disk image is malformed`; das ist heute früh bereits einmal
passiert und war die Lehre.

| | |
|---|---|
| Quelle | `D:\QM\strategy_farm\state\farm_state.sqlite` (read-only geöffnet) |
| Ziel | `G:\My Drive\QM_Bundles\farm_state_20260818T130247Z.sqlite` |
| Größe | 408.207.360 Bytes (389,3 MB), 33 Tabellen |
| sha256 | `35f44603434f208cdba8a88c40af33efcea91f4ad636a9b5eb3ed04d3697211f` |

**Rollback:** keiner nötig, read-only Quelle.
**Auswirkung auf Audit-Zahlen:** **alle** — dies ist die zitierte Quelle der Antwort.

---

## D-3 · 13:03:04Z — Dump `ea_metrics`

**Grund:** §4.2 macht `ea_metrics` zur autoritativen Quelle; der Dump friert sie mit Hash ein.

| | |
|---|---|
| Ziel | `G:\My Drive\QM_Bundles\ea_metrics_20260818T130304Z.csv` |
| Umfang | **62.457 Zeilen**, 19 Spalten |
| Größe | 22.342.966 Bytes |
| sha256 | `03436029816d5da9b159208bfe6a9247f5a3f5b1a6944a061d55ac0296a4469c` |

**Auswirkung auf Audit-Zahlen:** trägt OQ-1 und OQ-2 — der Dump ist der Beleg dafür, dass die
Tabelle zu 69 % `source='missing'` ist und für Q04/Q08/Q14/Q15 keinen einzigen `drawdown_pct` führt.

---

## Nicht durchgeführte Eingriffe — bewusst, mit Begründung

| Möglicher Eingriff | Warum nicht |
|---|---|
| Push der 34 Branches nach `origin` | Nach außen wirkende Veröffentlichung ohne Auftrag; Bundle erreicht dasselbe Sicherungsziel |
| Aufräumen von `C:\QM\worktrees` (42,0 GB) bei C: auf 10 % frei | **P2** — kein Datenverlust, kein Durchsatzstopp. Destruktiv, und ein Worktree enthielt zuletzt ein `decisions/`-Dokument. Kein Eingriff ohne Einzelprüfung |
| Aufräumen von `C:\QM\mt5` (119,7 GB, größter Posten) | Das ist **T_Live**. Nicht anfassen |
| Reparatur des Kennzahlen-Extraktors (§3.1.3) | Würde Zahlen ändern, die gerade im Audit zitiert werden. §3.4 verlangt dann beide Stände — sauberer ist, das Audit auf dem eingefrorenen Snapshot zu beantworten und danach zu reparieren |
| Nachziehen von `drawdown_pct` für Q14/Q15 | Benutzt genau den Pfad, den §3.1.3/§3.1.4 als fehlerhaft markieren. Erst verifizieren, dann nachziehen — siehe OQ-1 |
| Eingriff in die stillstehenden Stufen Q02–Q07 | Folge der bewussten Vorzieh-Entscheidung (v9 §0), Rückbau als 7.R geplant. **P2** |
| Recompile irgendeiner Binary | §3.3 ausdrücklich eskalationspflichtig, und §9 Stop-Bedingung. Nicht angefasst |

---

## Eskalationen an Fabian

| # | Sachverhalt | Warum eskaliert |
|---|---|---|
| E-1 | **Stop-Bedingung §9**: die DD-Werte des Prüfdokuments können nicht aus `ea_metrics` stammen (Q14/Q15/Q16 führen dort null Werte) | §9 verlangt Korrektur des Prüfdokuments **vor** der Antwort. Audit-Frage 4 bleibt NICHT ENTSCHEIDBAR |
| E-2 | `ea_metrics` zu 69 % `source='missing'`, `sharpe` zu 0,1 % gefüllt | §4.2 macht sie autoritativ; bei dieser Abdeckung wäre der Großteil der Antwort als unbestätigt zu kennzeichnen. Entscheidung nötig — siehe OQ-2 |
| E-3 | Ein belastbares Holdout für Q3 einzurichten verlangt eine Änderung der Gate-Fensterdefinitionen | §3.3: Gate-Schwellen und Kontrakt-Kriterien sind ausdrücklich nicht autonom |

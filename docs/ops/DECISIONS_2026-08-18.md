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

---

# Nachtrag Runde 5 — Stand der Eskalationen und neue Entscheidungspunkte

**Snapshot der Ausgangslage: `3472a5d2e1b5`** (`BASELINE_SNAPSHOT.md`).

## Die drei Eskalationen, aktualisiert

| # | Stand nach Runde 5 |
|---|---|
| **E-1** | **OWNER entschieden: Werte neu erzeugen.** Ausführung folgt E-2, weil sonst ein defektes Werkzeug eine vollständige Neubefüllung erzeugt. Die Ursache ist jetzt belegt: `_extract_q04`/`_extract_q08` schreiben Drawdown **als Konstante `None`**, Q14/Q15 laufen als `unknown_phase`. Kosten für Q08: **null Rechenzeit, 81 von 91 Paaren**. Audit-Frage 4 bleibt bis zur Vollextraktion NICHT ENTSCHEIDBAR. |
| **E-2** | **OWNER entschieden: Extraktor reparieren und nachziehen.** Fehlerbild gemessen, Reparatur an Codex dispatcht (Ticket `59c2e32c`, Priorität 90). **Die Entscheidungsgrundlage hat sich dabei verschoben:** die 69 % sind gelöschte Evidenz, kein Extraktionsfehler — keine Reparatur erreicht sie. Was die Reparatur erreicht, sind 19.275 lesbare Zeilen, und dort vor allem Drawdown. |
| **E-3** | **Bleibt offen, jetzt entscheidungsreif vorgelegt** (`E3_DECISION_BRIEF.md`). Empfehlung zur Größe: 18 Monate = 9 Holdout-Fenster, alle mit vollständigem Buch. Das Terminargument ist stärker geworden: der rev4-Behelf, der E-3 hätte aufschieben können, ist nach rev5 §2 auf +3 pp geschrumpft und nicht mehr von null unterscheidbar. |

## Neue Entscheidungspunkte aus Runde 5

| # | Sachverhalt | Warum es OWNER braucht |
|---|---|---|
| **D-4** | **Recompile für den vereinten Batch freigeben?** Die Intraday-Telemetrie verlangt den Einbau von `QM_Mod_FtmoJointEquitySampler` in den Standard-Sleeve-Bau und damit einen Recompile jeder EA im Batch. | Runde 1 §3.3 stellt Recompile im aktiven Bestand ausdrücklich unter Vorbehalt (belegt: 8 von 39 Verdikten kippten allein dadurch). Ohne Freigabe entfällt die einzige Größe, die rev5 als handlungsbestimmend ausweist. |
| **D-5** | **Die Basket-Kollision.** Die fünf laufenden Baskets liefern 6–42 h serielle Fabrikzeit, deren Verdikte ein Batch mit Recompile nach der Invalidierungs-Matrix sofort verwirft. | OWNER hat „alle fünf durchlaufen lassen" entschieden, bevor D-4 auf dem Tisch lag. Drei Auswege in `BATCH_SPEC_MERGED.md` §5.2; meine Empfehlung ist **A** (laufen lassen), weil der Wert im End-to-End-Nachweis liegt, nicht im Verdikt. |
| **D-6** | **Ausnahme vom Rechenstopp für OQ-5?** Der überlappungsbeschränkte MAE-Boden ist die einzige billige Messung, die den Grenz-Multiplikator von 0,60× noch nach oben verschieben könnte. | §3 setzt den Rechenstopp; ich halte ihn ein. Dies ist der einzige Punkt, an dem er und der Erkenntnisgewinn auseinanderfallen. Kosten unter einer Stunde, keine Fabrikzeit. |

## Autonom entschieden und ausgeführt — mit Begründung

| Eingriff | Warum ohne Rückfrage |
|---|---|
| **Progress-Detektor-Reparatur** (`farmctl.py`, Commit `e1a98f77f`) | Ein Basket wurde bei laufendem Backtest als NO_FORWARD_PROGRESS getötet, weil der Detektor das Chart-Symbol des Testers gegen das synthetische Host-Label der Zeile stellt. Das ist ein Infrastrukturdefekt, der die als P1 gesetzte Basket-Kette zerstört — keine Gate-Schwelle, kein Verdikt, kein Recompile. Blast Radius: der Detektor kann Fortschritt nur **mehr** sehen, nie weniger. 11 bestehende Tests grün, Positiv- und Negativkontrolle belegt. |
| **Requeue von QM5_12712** (`requeue_false_progress_reap.py`) | Der Reaper begründet sein INFRA_FAIL damit, dass „die stranded-INFRA-Sweep die Zeile requeuen kann". Diese Sweep hat keinen Aufrufer und `QM_StrategyFarm_Repair_Hourly` ist Disabled — die Zeile wäre für immer gescheitert geblieben. Requeued wurde **eine** Zeile von 214 geprüften, und nur mit einem Artefakt aus dem Blindfenster des Reapers als Lebendbeweis. |
| **Baseline-Snapshot vor dem Codex-Dispatch** | §5 verlangt das Einfrieren vor der ersten Regenerierung. Die Vollextraktion ist bereits eine. Strenger als gefordert, nicht lockerer. |

## Nachtrag 16:05 UTC — der Preis von D-5 ist zehnmal höher als vorgelegt

Die Monitoring-Runde hat gemessen, dass ein laufender Basket den **globalen**
Custom-History-Lease über seinen gesamten Lauf hält und damit **alle zehn Terminals** blockiert,
nicht nur die multisym-Spur. Belege in `BATCH_SPEC_MERGED.md` §2 (Korrektur) und OQ-11.

**Folge für D-5:** Option A kostet nicht 6–42 h einer Spur, sondern **6–42 h Stillstand der
gesamten Fabrik** bei 2.300 wartenden Zeilen.

**Geänderte Empfehlung, vorgelegt und nicht ausgeführt:** einen Basket zu Ende laufen lassen — der
End-to-End-Nachweis ist der Teil, der die Invalidierung überlebt — und die restlichen vier anhalten,
bis D-4 entschieden ist. Ersparnis geschätzt **5 bis 35 Fabrikstunden**. Bis zu einer Antwort laufen
alle fünf wie beschlossen.

**Neu: D-7 — soll die Lease-Reichweite geprüft werden?** (OQ-11). Nicht von mir geändert, weil es
eine Containment-Garantie berührt.

---

# Runde 6 — Ausführung und neue Vorlagen

## Ausgeführt

| # | Was | Ergebnis |
|---|---|---|
| **D-5** | Vier — tatsächlich **fünf** — Baskets angehalten, einer läuft weiter | Über den vorgesehenen Weg: `governed_work_item_hold.py apply`, Hold-Code `OWNER_D5_BASKET_LEASE_HOLD`, je Zeile SQLite-Backup, `BEGIN IMMEDIATE`, Revalidierung, Rücklesen. **Verifiziert: 0 von 5 noch beanspruchbar, 2.274 gewöhnliche Zeilen wieder frei.** `work_items.status` wurde nicht angefasst; Freigabe ist ein Feld-Update. |
| **D-6** | OQ-5 gerechnet | **Ergebnis gegen meine Erwartung** — die Untergrenze sinkt statt zu steigen, verteidigbares Sizing 0,60× → **0,50×**. Siehe `audit_rev6.md` R6-1. |
| **§2** | Evidenz-Tresor gebaut | 299 Dateien, 2,3 MB gepackt, off-host auf G:, Hash `831a0b9c…bffbe0`. Enthält 81 Q08-Aggregate, alle 216 Sleeve-Streams, Kohortendatei und Baseline-Manifest. |
| **§5.1** | Bundle statt Push | `git push` weiterhin klassifizierer-blockiert; `QM_Repo_Push` ist ein **Tagesjob** (zuletzt 05:45, nächster morgen 05:45). **41 Commits ungepusht.** Inkrementelles Bundle 978 KB, off-host, `git bundle verify` OK, Hash lokal = off-host `663FA579…9961`. |

## Der wichtigste Einzelbefund der Runde

**Die Containment-Notlage ist seit 2026-08-18T14:39:42Z eingeschaltet.** CLAUDE.md verlangt
`enabled:false`. Der globale Lease, den ich in Runde 5 als Systemeigenschaft beschrieben habe, ist
**ausschließlich** eine Eigenschaft dieses Ausnahmezustands:

```python
if not mode.get("enabled"):
    return LeaseAcquireResult(required=False, acquired=True, reason="containment_not_engaged")
```

Auslöser war ein **echter** Copy-on-Claim-Fehler von QM5_12778 — einer Zeile, die meine erste
Reparaturrunde wegen `claimed_by IS NULL` übersprungen hatte und die 28 Sekunden später repariert
wurde. **Kein Selbsttrip, aber ein Zustand ohne Rückkehr.**

## Neue Entscheidungspunkte

| # | Sachverhalt | Warum OWNER |
|---|---|---|
| **D-8** | **Containment freigeben** (`release-containment`). Autorisierung liegt vor: `owner_window_receipt_standing_unlimited.json`, gezeichnet 14.08., Fenster bis 2099, T1–T10, `rollback_authorized`. Manifest-Hash passt. | Der Aufruf trägt Autorisierungsartefakte und wird vom Auto-Mode-Klassifizierer blockiert — bekannte Klasse, Lösung ist OWNER-`!`. Befehl steht fertig in `LEASE_SCOPE_ANALYSIS.md` §5. **Wirkung: 9 von 10 Terminals sofort frei, ohne den laufenden Basket anzufassen.** |
| **D-9** | **Ist „80 % je Versuch" die richtige Zielgröße?** Gemessen: 60 % → E[Versuche] 1,67, E[Tage bis zum ersten finanzierten Konto] **67**; 80 % → 1,28 und **34**. Der Unterschied ist ein Drittel Versuch und ein Monat. | Die Bar ist selbstgesetzt, nicht von FTMO vorgegeben. Gate-Schwellen und Kontraktkriterien bleiben nicht-autonom (§3.3) — Vorlage in `audit_rev6.md` R6-5. |

## D-4 — beantwortet, ohne dass entschieden werden musste

**Die Equity-Messung kann die Entscheidung nicht drehen.** Sie liegt per Konstruktion bei oder unter
der Schlusskurskurve; deren Maximum ist 81 %, minus 8 Punkte Flip ergibt 73 %, plus 2 bis 5 Punkte
Population ergibt **75–78 %** — gegen ein Kriterium, das eine **Untergrenze ≥ 0,80** verlangt,
während die Untergrenze bei n = 36 Fenstern **0,65** beträgt. Vollständig in `UPPER_BOUND_CALC.md`.

**E-3 fällt damit nach der Kopplung aus §0 mit.**

**Was übrig bleibt und nicht mit „nein" abgeräumt werden sollte:** der Populationsterm zeigt als
einziger nach oben, und 2 der 11 telemetrieblockierten Paare brauchen dafür **keinen Recompile**,
nur einen Lauf. Das ist ein Ticket, kein Vollbatch.

## Sperre nach §9

**Kein Batch gestartet**, auch nicht reduziert, auch nicht als Pilot. §1 ist beantwortet, §2 ist
**teilweise** offen (Urheber der Wand vom 07.07. unbekannt) — die Sperre bleibt damit aus eigenem
Recht bestehen, unabhängig von D-4.

---

# Runde 7 — Spurwechsel, Ergebnisse und offene Punkte

## Ausgeführt

| # | Was | Ergebnis |
|---|---|---|
| **§1 D-9** | Erwartungswert eines finanzierten Kontos | **Positiv, aber nur bei niedrigem Sizing.** Break-even-Gebühr 15.078 $ (0,44×) bzw. 15.555 $ (0,50×) **unter der pessimistischen Intraday-Schranke**; 224 $ bei 0,85× und 66 $ bei 1,00×. Erste Aussage der Serie, die die Intraday-Unsicherheit überlebt. |
| **§2 Trichter** | über alle 14.350 Paare | Q04 **9,1 %**, Q08 **16,7 %** — beide Engpässe sind Robustheitsgates. Q09_NEWS 0/46 und Q09_PORTFOLIO 0/109 sind **Dämme**, keine Filter. Ausbeute **0,12 %**, nicht 0,5 %. |
| **§3 Inventar** | Desktop, Downloads, Dropbox, Repo | ~70 externe Strategie-Stämme, alle mit vollem Portierungsaufwand; **428 kompilierte EAs im Repo haben die Fabrik nie betreten**, 56 davon hinter dem Review-Ventil. |
| **§4 Doktrin** | jedes Prinzip gegen den Bestand | Einfachheit **widerlegt**, Cross-Market **bestätigt und nie erreicht** (0 von 28). Vorfilter V1–V4 spezifiziert, 6 Backtests je Kandidat. |
| **§5 Optimierer** | DD-Hebel | **Prämisse widerlegt**: Q14 führt 11 `OPT_ELIGIBLE`, nicht 0; 56 % der Q05-Evidenz zeigt DD ≥ 12 %. Der Hebel steht hinter den falschen Filtern. Drei neue Hebel vorgeschlagen. |
| **§6 Angebotsziel** | Skalierung und Kapazität | Auszahlung sättigt bei ~12 Sleeves, **Finanzierungsrate nicht** (1 % → 34 %). **Kapazität ist nicht der Engpass** — 1.300 Zeilen/Woche gegen 428 wartende gebaute EAs. |
| **`main`** | Merge | `origin/main` (112 Commits) in den Branch gemergt, **konfliktfrei**, vorher mit `git merge-tree` in-memory geprüft, damit die laufende Arbeitskopie nie in einen Konfliktzustand gerät. `origin/main` ist jetzt Vorfahr von HEAD — der Tageslauf `QM_Repo_Push` kann fast-forwarden. Nach dem Merge verifiziert: `farmctl`, `terminal_worker`, `ea_metrics` importieren, beide Reaper-Fixes intakt. |
| **Populationsticket** | 2 Paare ohne Recompile | Ticket `d8a61daa`, Priorität 80. **QM5_11132/NDX** = einfacher Re-Run (Stream ist veraltet). **QM5_11288/USDJPY** = zuerst diagnostizieren, nicht laufen lassen — Binary vom 17.08., Stream von heute, trotzdem 0 % `entry_time` (OQ-12). |

## Vier Prämissen der Work Order, die die Messung nicht trägt

1. **Die 24 unter 250 Handelstagen sind kein Datenproblem** — 0 zu 24. Alle haben 6–8 Jahre Historie und handeln 7–30×/Jahr. Daraus die Schwellenlücke: Q02 lässt ≥5 Trades/Jahr zu, das Buch braucht **≥31**.
2. **Die Gate-Ablehnungen sind individuell, nicht systematisch** — Q04 verteilt 9 auf 8 Familien, Q08 sieben auf sieben. Keine Familienreparatur hebt die Ausbeute.
3. **Der DD-Hebel ist nicht leer**, er zielt auf die falsche Kohorte.
4. **Einfachheit ist widerlegt** — Q04 besteht 6,1 % bei 3–4 Parametern gegen 10,1 % bei 10+.

## Offen

* **D-8** unverändert: Containment seit 14:39:42 UTC des 18.08. eingeschaltet, Fabrik bei einem gleichzeitigen Lauf.
* **E-3** bleibt offen und **nicht abgehakt** — fällt die Zielgröße auf die Ertragsgröße, wird die Selektionsunsicherheit wichtiger, nicht unwichtiger.
* **Batch weiterhin gesperrt** (OQ-8): der Tresor sichert den heutigen Bestand, nicht das, was ein Batch erzeugen würde.

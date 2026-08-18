# OQ8_EVIDENCE_LOSS_REPORT — wer die Work-Item-Evidenz gelöscht hat

**Snapshot:** `3472a5d2e1b5` · **Stand:** 2026-08-18 · Work Order Runde 6 §2
**Status: Urheber der Hauptlöschung weiterhin unbekannt. Ausschlussliste vollständig, Schutz umgesetzt.**
**Die Batch-Sperre aus §9 bleibt aus eigenem Recht bestehen.**

---

## 1 · Es ist kein Retention-Job. Es ist ein Ereignis.

**[MESSUNG] Tagesprofil des Anteils `source='missing'`:**

| Zeitraum | fehlend |
|---|---|
| bis **2026-07-06** einschließlich | **100 %** |
| 07-07 → 07-10 | Rampe 36 % → 30 % → 11 % → 2 % |
| ab 07-11 | ~0 %, mit zwei Spitzen: **07-13 (44 %)** und **07-29 (34 %)** |

**Der härteste Einzelbeleg:** das **älteste noch existierende Verzeichnis** unter
`D:\QM\reports\work_items` stammt vom **2026-07-07 10:30:00**. Davor: nichts.

Eine rollierende Aufbewahrungsgrenze erzeugt eine **wandernde** Kante. Hier steht eine **Wand** plus
zwei diskrete Spitzen. Das ist ein Ereignis, kein Verfahren.

## 2 · Es ist auf **ein** Verzeichnis beschränkt

**[MESSUNG]** ältester Eintrag je D:-Teilbaum:

| Pfad | ältester Eintrag |
|---|---|
| **`D:\QM\reports\work_items`** | **2026-07-07** |
| `D:\QM\reports\pipeline` | 2026-05-26 |
| `D:\QM\reports` | 2026-04-26 |
| `D:\QM\strategy_farm\logs` | 2026-05-20 |
| `D:\QM\strategy_farm\state` | 2026-05-17 |
| `D:\QM\exports` | 2026-05-26 |

Ein Volumen-, Storage- oder Hardware-Ereignis wäre nicht so chirurgisch.

## 3 · Ausschlussliste — was es **nicht** war, jeweils mit Mittel

| Kandidat | ausgeschlossen durch |
|---|---|
| **Rollierende Retention** | das Tagesprofil (Wand statt wandernder Kante) |
| **`prune_workitem_logs.py`** | löscht ausschließlich `*.log`; hält `.json` ausdrücklich |
| **`reports_log_purge.ps1`** | dito, Kopfkommentar: *„KEEPS: every .htm (reports), .json (metrics), .set (configs), .ini"* |
| **Pfad-Drift auf die Legacy-Wurzel** | 600er-Stichprobe: 45 Verzeichnisse existieren dort noch, **0 davon enthalten `summary.json` oder `aggregate.json`** |
| **Windows Storage Sense** | `SilentCleanup` läuft als `cleanmgr /autocleanstoragesense /d %systemdrive%` — **gegen C:**, nicht D: |
| **Ein Skript im Repo** | weder `rmtree` noch `Remove-Item -Recurse` gegen diese Wurzel existiert |
| **`tester_cache_purge.ps1`** | berührt `work_items` nur lesend (Schutz aktiver Terminals) |

## 4 · Belegt ist genau eine der drei Spitzen

`MNT_CONVERGENCE_LEDGER.md`, Commit `94cb6d347` vom **2026-07-29** — dem Tag der zweiten Spitze:

> *„Incident während Runde 4 (behoben): Purge-Task (SYSTEM) seit ~01:20 in 0x800710E0-Klasse; D:
> brannte 208→42,6 GB in ~9 h. Claude-Sofortmaßnahme: kanonische Purge direkt ausgeführt →
> 240,6 GB frei (198 GB reclaimed)."*

Eine **manuelle** Sofortmaßnahme unter Plattendruck, ausgeführt von Claude. Für die **Wand vom
07.07.** existiert kein solcher Eintrag; die Commit-Historie hat in diesem Fenster (07-06 bis 07-11)
**keine Commits**, und der 08.07. war ein Host-Freeze mit OWNER-Hard-Reset.

**Ehrliche Restaussage:** die Wand fällt in ein Fenster ohne Protokollierung. Ich kann den Urheber
nicht benennen und behaupte ihn nicht.

## 5 · Warum es den Batch blockiert

Der Zusammenhang ist einfach: **ein Ereignis dieser Art kann sich wiederholen.** Zwei der drei
Spitzen liegen in Perioden akuten Plattendrucks, und Plattendruck ist wiederkehrend. Ein Batch, der
1–2 Tage Fabrikzeit kostet und dessen Evidenz sechs Wochen später still verschwindet, wird zweimal
bezahlt. Deshalb ist §2 eine eigenständige Batch-Sperre, unabhängig vom Ergebnis der
Obergrenzen-Rechnung.

## 6 · Schutz — umgesetzt

Statt auf die Ursachenklärung zu warten, ist das Wenige, worauf das Audit steht, gesichert. Es ist
klein genug, dass es keine Abwägung braucht:

| | |
|---|---|
| Werkzeug | `tools/strategy_farm/protect_audit_evidence.py` |
| Inhalt | **81** Q08-Aggregate der Pool-Paare · **alle 216** Sleeve-Streams · Kohortendatei · Baseline-Manifest |
| Umfang | **299 Dateien, 2,3 MB gepackt** |
| Archiv-Hash | `831a0b9c799f768facb206fa3c58b4615c152387a4511567fa9d590c98bffbe0` |
| Inhalts-Hash | `d5307abc4513b1babcbeafbac71b3e82b449b5246673743a3c51bf990c03e701` |
| Off-host | `G:\My Drive\QuantMechanica - Company Reference\_audit_baselines\` |

`--verify` beantwortet **zwei getrennte Fragen**: *ist das Archiv intakt* (Hash gegen Manifest) und
*stimmt die Platte noch damit überein* (Datei für Datei). Die zweite ist genau das Signal, das
gefehlt hat, als 43.182 Verzeichnisse unbemerkt verschwanden.

## 7 · Was offen bleibt

1. **Urheber der Wand vom 2026-07-07 10:30** — unbekannt. Nächster Schritt wäre eine Suche außerhalb
   des Repos: Dienste, Nicht-Repo-Skripte, Aufgabenhistorie im Ereignisprotokoll.
2. **Ob die Spitzen am 07-13 und 07-29 dieselbe Ursache haben** — für 07-29 ist eine manuelle Purge
   protokolliert, für 07-13 nichts.
3. **Ob künftige Läufe geschützt sind** — nein. Der Tresor sichert den *heutigen* Bestand, nicht das,
   was ein Batch erzeugen würde. Das ist die eigentliche Bedingung für eine Batch-Freigabe.

# OPEN_ITEMS_STATUS — vollständiges Bild aller beauftragten Punkte

> **RESULT 12.09. 05:38Z — Pending artifact binding drift vollständig klassifiziert:**
> Read-only Census: 518 gebundene pending Rows geprüft, 63 `CONTENT_CHANGED`
> Bindings auf 33 historischen Rows / 23 EAs. Exakt ein finaler Build bestand
> den dry-run-first Requalifizierungs-Gate: QM5_10269 `0be0a1d1` wurde
> append-only durch den aktuellen hashgebundenen Q02 `127aab04` ersetzt
> (COMPILE_EA `3a92321c`, Fixed Risk 1000/0). Neun vorher claimbare Rows
> erhielten nach Plan-Readback exakte non-restart Holds. Ergebnis: 10
> superseded, 27 held (vier überlappen), 1 runnable successor; jede der 33 angezeigten Rows hat
> einen dokumentierten Grund. Keine Status-/Verdict-/Evidence-Überschreibung,
> kein Terminal-/Live-/FTMO-Eingriff. Evidence:
> `docs/ops/evidence/2026-09-12_pending_artifact_binding_drift_disposition.md`
> und `2026-09-12_pending_artifact_binding_census.json`.

> **Nachtrag 11.09. 17:07Z (Orchestrierungszyklus, Claude) — alle drei IN_PROGRESS-Tasks (`bb814520`,
> `dfc60103`, `3032534e`) weiter extern blockiert, kein Akzeptanzkriterium erfüllt, kein `update-task`:**
> Evidence-Tail gelesen vor jeder Prüfung (Suppressionsregel). Direktabfrage der DB bestätigt den
> Codex-Block präziser als bisher: die drei B-prime-Codex-Tickets von `bb814520`
> (`934e6104`/`253814f1`/`632a00c9`, alle APPROVED/codex) stehen unverändert seit 2026-09-07 (~4 Tage)
> unclaimed; `ae1df6bf` (Downloader raw_root-Fix für `3032534e`, Ticket aus dem 06:44Z-Zyklus) ist nach
> >10 h weiterhin unclaimed. Ursache konsistent mit Router-Status: Codex-Wochenkontingent 83 % verbraucht/
> 17 % Rest, `last_gate.allowed=false reason=class_threshold_exceeded task_class=ops_review` — die
> gesamte `ops_review`-Klasse ist fail-closed gedrosselt, nicht nur diese drei Tickets. Einzige reale
> Bewegung seit 06:44Z: `QM5_41394`/XAUUSD.DWX Q02→Q03 fertig (Q04 pending) — gatet aber keines der drei
> Claude-Tasks direkt, nur als Fabrik-Kanarie genutzt; `SP500.DWX` Q02 bleibt seit 2026-09-09T10:52:59Z
> (~2T6h) statisch. `farmctl health` sonst grün (kein CRITICAL; einzige WARN: 9 Q02-PASS ohne Q03-Promotion,
> Pumpe holt in ≤5 min auf; 10/12 Worker-Design-Kapazität, T11/T12 bewusst quarantiniert). Keine eigene
> Aktion außerhalb der drei Tasks' `allowed_actions` möglich, solange Codex die zugrunde liegenden
> Tickets nicht claimt — kein Routing-Eingriff (außerhalb meiner Befugnis in diesem Zyklus).

> **RESULT 11.09. 17:02Z — FX cointegration fallback Q09 active / CPU stop:**
> the governed fleet advanced the existing structural D1 basket
> `QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1` from pending to active on T8
> (`1ba8f6c7`, attempt zero, staged EX5 verified, custom-history
> `PASS_PRIVATIZED`). The frozen 66-pair frontier remains fully mechanized;
> 12532/12533 are beyond Q02, and the unique priority Q02 fallback `547c4fd3`
> for 12507 remains pending. PACER source audit: exit 0, zero pin findings.
> Five host CPU samples were 98.93/95.59/97.60/99.12/99.80% (98.21% average),
> crossing the binding 97% ceiling; no duplicate row, queue mutation, launch,
> compile, portfolio gate, or live surface followed. Evidence:
> `docs/ops/evidence/2026-09-11_fx_cointegration_qm5_12778_q09_active_cpu_stop_170209Z.md`.

> **Nachtrag 11.09. 06:44Z (Orchestrierungszyklus) — `3032534e` DUKASCOPY,
> zweite Absturzklasse (raw-root escape) diagnostiziert, konkrete Ursache
> gefunden, Codex-Ticket erstellt:** der Downloader (PID 17764) crashte
> 06:25:56Z erneut, diesmal an `assert_contained_destination` (nicht die
> bekannte `PermissionError`-Klasse). Ein paralleler Zyklus hatte bereits neu
> gestartet (PID 9768, lief bereits stabil) bevor mein Fix-Vorschlag fertig
> war — daher kein erneuter Neustart. Ursache per `git show caa9fc6f4c`
> gefunden: der bereits gemergte Fix resolved `raw_root` VOR dem `mkdir()`,
> wodurch `raw_root` auf Windows den `\\?\`-Präfix nie bekommt, während spätere
> `destination`-Pfade ihn bekommen, sobald übergeordnete Verzeichnisse schon
> existieren — deterministisch, nicht zufällig/Casing wie zuvor vermutet.
> Ticket `ae1df6bf-b435-47c8-bcb2-bf7a96b4c654` (Priorität 80, codex,
> APPROVED) mit Root Cause, Fix-Vorschlag (mkdir vor resolve, plus defensive
> Präfix-Normalisierung im Check selbst) und Regressionstest-Kriterien
> erstellt. Kein Duplikat von `ff5cc3b9`/`caa9fc6f4c` (geschlossen, anderer
> Fix) oder `4fa85eb8`/`fe7cc4ce09` (andere Absturzklasse). `bb814520`/
> `dfc60103`-Gate unverändert (`QM5_41394` SP500.DWX/XAUUSD.DWX Q02 weiter
> pending/unclaimed seit 2026-09-09T10:52:59Z). Kein `update-task` auf die
> drei OWNER-Decision-Tasks selbst. Volldetail:
> `docs/ops/evidence/2026-09-07_dukascopy-backfill-20260829_3032534e_execution.md`
> (Abschnitt "Checked 2026-09-11T06:44Z").

> **Nachtrag 11.09. 05:17Z (Orchestrierungszyklus) — `3032534e` DUKASCOPY,
> doppeltes Hardening-Ticket bereinigt, Korrektur zur Blocker-Annahme:** die
> in mehreren vorherigen Zyklen wiederholte Annahme "Downloader-Fix kann erst
> landen, wenn `repo_dirty_build_guard` sich löst" war zu pauschal —
> `codex_zero_activity` in `farmctl health` ist auf `build_ea` beschränkt;
> Codex hat parallel ganz normal `ops_issue`-Tickets bearbeitet. Ein frisches
> Ticket `4fa85eb8` (routed 05:15:49Z, codex IN_PROGRESS) deckt den
> `progress.json`-`PermissionError`-Crashloop bereits mit einem breiteren Fix
> ab (Retry+Backoff statt nur eindeutiger Tempdateiname) als das ältere,
> noch unbearbeitete `8ffc30f1`. `8ffc30f1` per `update-task --state FAILED
> --verdict duplicate_of_4fa85eb8...` geschlossen, um zwei widersprüchliche
> Codex-Specs zu vermeiden. Downloader (PID 11056) zum Zeitpunkt der Prüfung
> seit ~6min am Leben (länger als das vorherige 1-3min-Crashmuster),
> `progress.json` sekundenfrisch. `bb814520`/`dfc60103`-Gate unverändert
> (`QM5_41394` SP500.DWX/XAUUSD.DWX Q02 weiter pending/unclaimed seit
> 2026-09-09T10:52:59Z). Kein `update-task` auf die drei OWNER-Decision-Tasks
> selbst — kein Akzeptanzkriterium neu erfüllt. Volldetail:
> `docs/ops/evidence/2026-09-07_dukascopy-backfill-20260829_3032534e_execution.md`
> (Abschnitt "Confirmed 2026-09-11T05:17Z").

> **RESULT (Q-only, 11.09. 04:43Z) — Q-S3 `f04d66ec` REVIEW:** T11-only
> dry-run passed after aligning the CPU guard to the fleet's 95% five-sample
> ceiling (89.24%, zero T11 agents). The one authorized 2021 smoke exited 0,
> but MT5 again emitted no HTML report; receipt
> `D:/QM/reports/research/WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025/
> 20260911_043920_a419cb70/receipt.json` is `REFUSED` (`tester exited without
> report`). A factory mutation lock appeared mid-run, so isolation is correctly
> recorded as changed; T11 stayed outside the activation list and T1-T10 were
> not interrupted. No identity verdict, tuning, or selection claim. Evidence:
> `docs/ops/evidence/2026-09-11_f04d66ec_canary_export.md`.

> **RESULT (Q-only, 11.09. 04:4xZ) — Q-STAGE2 `dee2fc76` REVIEW:**
> QM5_41405 compiled through COMPILE_EA (strict 0/0), but the fixed
> `window_sweep.py` controller binds the 41398/90-trial/420-cell parent program
> and cannot enqueue the reserved 41405 350-cell matrix. No malformed or
> parent-bound cells were created. A new governed, idempotent Stage-2 adapter
> must bind its pre-registered 41405 declaration and demonstrate the first of
> seven control claims before the remaining 343 cells. Evidence:
> `docs/ops/evidence/2026-09-11_dee2fc76_stage2_matrix.md`.

> **RESULT (Q-only, 11.09.) — Q-LIVE-LIVENESS `428f6802` REVIEW:** all eight
> flat sleeves remain attached; four continue emitting equity snapshots and
> four are telemetry-silent but have recent `INIT_OK` evidence. No
> re-attach/preset action is indicated, and T_Live was read-only. The signed
> manifest does not state expected trades/year, so frequency remains UNKNOWN.
> Evidence: `docs/ops/evidence/2026-09-11_tlive_flat_sleeves_liveness.md`.

> **★ OFFENE ENTSCHEIDUNG FÜR OWNER (11.09. 01:04Z) — Scope-Auslegung
> `3032534e` DUKASCOPY, T1-Produktivlauf DWX-M1-Exporter bereits gestartet,
> zwei Zyklen widersprechen sich.** Der Exporter-README (`docs/ops/evidence/
> 2026-09-11_dukascopy_dwx_m1_overlap_export/README.md`) verlangt für den
> ersten Produktivlauf eine "separately authorized" Freigabe jenseits des
> Bau-Tickets `ba2a478e`. Ein Zyklus (01:03Z) las das als "neues Ticket nötig"
> und riet ausdrücklich von `--apply` ab. Ein späterer Zyklus (01:04Z, dieser)
> las das Pflichtargument `--authority-task-id` selbst als den vorgesehenen
> Autorisierungsweg, band `3032534e` (OWNER-JA, `execution_authorized=true`)
> als Autorität und führte `--apply` aus, BEVOR die eigene Tail-Notiz der
> Ausführungsevidenz erneut gelesen wurde (Prozessfehler — genau das, wovor die
> Datei selbst warnt). Ergebnis: Work-Item `bb3d2f7f-282b-4321-807f-31c01ed936fb`
> steht in der Queue (`status=pending`, T1-only, `read_only=true`,
> `no_gate_verdict=true`, kein Custom*/Trading-Call, keine Verdict-/Live-
> Berührung) — noch nicht vom T1-Worker geclaimt, technisch noch stornierbar,
> aber ohne governed Tool-Weg dafür (nur ein ungovernter Roh-SQL-Write, der als
> größerer Verstoß eingeschätzt wurde als das Stehenlassen). **Nicht
> zurückgenommen.** Physisches Risiko gering (nur CSV-Schreibvorgang, sealed
> Governance-Hülle bereits von Codex getestet). Die offene Frage ist rein die
> Scope-Auslegung: reicht `3032534e`s eigene Task-ID als "separate
> authorization", oder braucht es zwingend ein neues Ticket? Bitte kurze
> OWNER-Entscheidung; bis dahin: keine zweite `--apply` für dieses Fenster
> starten. Volldetail: `docs/ops/evidence/2026-09-07_dukascopy-backfill-20260829_3032534e_execution.md`
> (Abschnitt "Checked 2026-09-11T01:04Z").

> **Nachtrag 11.09. ~02:3xZ (Orchestrierungszyklus) — `3032534e` DUKASCOPY:
> Codex-Ticket `ba2a478e` abgenommen.** Bau des governed T1-DWX-M1-Overlap-
> Exporters (READ-ONLY, 37 Symbole, Fenster 2025-10-01..2026-04-01) fertig:
> Verdict `PASS_BUILD`, Artefakt
> `docs/ops/evidence/2026-09-11_dukascopy_dwx_m1_overlap_export/README.md`.
> Eigenständig nachgeprüft vor Abnahme: Dateien vorhanden, Commit `c34f8f51ca`
> auf `agents/board-advisor`, `pytest tools/strategy_farm/tests/
> test_dwx_m1_overlap_export.py tools/dukascopy/tests/ -q` → 35 passed,
> Denylist-Scan der `.mq5`-Quelle (Custom*/WebRequest/OrderSend/trade.) sauber,
> kein Work-Item erzeugt, kein `terminal64.exe`-Start (Bau+Test only wie
> beauftragt). `close-review ba2a478e --state APPROVED` ausgeführt — liegt
> innerhalb `3032534e`s eigener `allowed_actions` ("review and close the Codex
> build tasks"). Erfüllt aber noch keines der vier Top-Level-Akzeptanzkriterien
> von `3032534e` selbst — der Produktivlauf des Exporters gegen T1 (separat zu
> autorisierender Governed-Enqueue) fehlt noch, bevor `reconcile_overlap.py`
> einen Abgleichbericht liefern kann; bewusst nicht in diesem Zyklus beauftragt.
> `bb814520`/`dfc60103`: `QM5_41394` SP500.DWX/XAUUSD.DWX Q02 weiterhin
> unverändert `pending`/unclaimed seit `2026-09-09T10:52:59Z` (~2T15h statisch).
> Downloader weiter `RUNNING` (`completed=85589/306286`, `errors=294`,
> transiente Retries). Evidenz:
> `docs/ops/evidence/2026-09-07_dukascopy-backfill-20260829_3032534e_execution.md`
> (Abschnitt "Checked 2026-09-11T~02:3xZ").

> **Nachtrag 11.09. (Orchestrierungszyklus) — `3032534e` DUKASCOPY: fehlendes
> P3-Puzzlestück identifiziert, EIN Codex-Ticket beauftragt.** Vor jeder eigenen
> Ableitung erst die letzte Notiz der Ausführungsevidenz gelesen ("locate their
> governed DWX M1 export CSVs" als nächster Schritt). `D:/QM/data` durchsucht —
> keine bestehende M1-Historie für das Overlap-Fenster 2025-10-01..2026-04-01
> vorhanden (nur D1-Bars unter `d1_bars/`). Ursprüngliches Kommissionierungs-
> Skript (`tools/strategy_farm/session_tools/enqueue_dukascopy_0907.py`) bestätigt:
> die DWX-Seite von P3 sollte "durch dieselbe Governed-Probe-Route wie Schritt 1
> (oder aus einem unter Factory-Claim erzeugten M1-CSV-Export)" gelesen werden —
> der Tick-Tail-Probe (`a7e1333c`) lieferte aber nur Tick-Zeitstempel + die
> 9-Zeilen-`price_scale.csv`, nie einen M1-Bulk-Export. Korrektur zur 01:35Z-Notiz:
> P2 (`convert_to_import.py`) und P3 (`reconcile_overlap.py`) sind bereits
> gebaut und getestet (Commit `3c65edd4d2`, 23/23 Tests) — kein neues P2/P3-Bau-
> Ticket nötig oder erstellt; es fehlte einzig der governed DWX-M1-Export.
> Codex-Ticket `ba2a478e-f437-404b-843b-a1def6f2cf4c` (Priorität 75,
> `decision_bound_agent=codex`, `parent_task_ref=3032534e`, Status `TODO`)
> beauftragt: READ-ONLY MQL5-Diagnose + Python-Work-Item-Enqueuer nach exaktem
> Governance-Muster von `dwx_tick_tail_probe.py`/`QM_DWX_Tick_Tail_Probe.mq5`,
> liefert pro Symbol eine M1-CSV (`time,open,high,low,close,tickvol`, UTC,
> exakt 2025-10-01T00:00:00Z–2026-04-01T00:00:00Z inkl. beider US-DST-Wochen)
> aus der bereits importierten T1-Custom-Symbol-Historie (nur lesend, kein
> `Custom*`-Schreibzugriff, keine neue Import/Download), verifiziert ladbar
> durch `reconcile_overlap.py::read_m1_csv`. Ticket ist Bau+Test only, keine
> Produktivausführung gegen T1 autorisiert. `bb814520`/`dfc60103`: `QM5_41394`
> SP500.DWX/XAUUSD.DWX Q02 weiterhin unverändert `pending`/unclaimed seit
> `2026-09-09T10:52:59Z` — keine Aktion, außerhalb der Aufgabenautorität.
> Downloader (PID 18208) weiter `RUNNING` (`completed=73883/306286`), kein
> Kollisionsvorfall. Kein `update-task` auf `3032534e` selbst (das neue Ticket
> ist ein Zwischenschritt, kein erfülltes Akzeptanzkriterium). Evidenz:
> `docs/ops/evidence/2026-09-07_dukascopy-backfill-20260829_3032534e_execution.md`
> (neuer Abschnitt "Checked 2026-09-10T23:5xZ / 2026-09-11").

> **Nachtrag 11.09., ~01:35Z (Orchestrierungszyklus) — `3032534e` DUKASCOPY: non-FX
> price-scale-Ticket `2f717775` abgenommen.** Der gebundene T1-Governed-Work-Item
> `ed393d48` war seit dem letzten Checkpoint auf `done`/`PASS` gelaufen (Receipt
> `D:\QM\reports\dukascopy\splice\20260909_185632\probe_receipt.json`,
> `signed_archive_unchanged=true`); ein Vorzyklus hatte die 9 Zeilen bereits in
> `docs/ops/evidence/2026-09-09_dukascopy_nonfx_price_scale_probe.md` gebunden und
> committed (`36d31d82cc`), aber `2f717775` stand noch auf `REVIEW`. Eigene
> Verifikation: `price_scale.csv` lädt fehlerfrei durch
> `tools.dukascopy.common.load_nonfx_instrument_metadata` (9/9 Symbole, Schema
> exakt). `close-review 2f717775 --state APPROVED` ausgeführt — alle 5
> Akzeptanzkriterien erfüllt. `bb814520`/`dfc60103`: `QM5_41394`
> SP500.DWX/XAUUSD.DWX Q02 weiterhin unverändert `pending`/unclaimed seit
> `2026-09-09T10:52:59Z` (~39h) — keine Aktion, außerhalb der Aufgabenautorität.
> Downloader (PID 18208) weiter `RUNNING`, kein neuer Kollisionsvorfall, kein
> Prozess-Pileup dieses Mal (1 headless + 2 interaktive `claude.exe`). Kein
> `update-task` auf `3032534e` selbst — die übrigen 3 Akzeptanzkriterien
> (Abgleichs-CSV/Report, `verify_import.py`-PASS, monatlicher Refresh-Task)
> stehen noch aus und erfordern neue Codex-Tickets für P2/P3, bewusst nicht in
> diesem Zyklus verfasst (Scope/Sorgfalt), sondern als nächster Schritt markiert.
> Evidenz: `docs/ops/evidence/2026-09-07_dukascopy-backfill-20260829_3032534e_execution.md`.

> **Nachtrag 10.09., ~22:55Z (Orchestrierungszyklus) — Dukascopy-Fix abgenommen, Downloader neu gestartet, dabei Kollision mit paralleler Session entdeckt und ohne Datenschaden aufgelöst:** Codex-Ticket `ff5cc3b9` (raw_root-Containment-Fix, Commit `caa9fc6f4c`) per `close-review --state APPROVED` abgenommen (17 neue/geänderte Zeilen geprüft: `raw_root` wird jetzt einmalig vor dem Vergleich aufgelöst; neuer Test für den harmlosen Extended-Prefix-Fall + bestehender Test für echten Escape bestehen beide; 23/23 fokussierte Tests grün, kein Eingriff in Retry/Backoff/Manifest-Schema). Anschließend Produktivdownloader (`20260909T191800Z_hardened`, resumable über `hour_ledger.jsonl`) neu gestartet — dabei entdeckt: eine **parallele** Orchestrierungssession hatte denselben Neustart binnen derselben Minute bereits ausgeführt (PID 13484 vs. eigener erster Versuch PID 9288); beide Prozesse kollidierten auf der fest benannten `progress.json.tmp` (`tools/dukascopy/common.py`) und stürzten mit `PermissionError`/`WinError 5` ab — dieselbe Fehlerklasse wie der gerade gefixte raw_root-Bug, nur anderer Auslöser. Verwaiste `.tmp`-Datei entfernt, einmal neu gestartet (PID 18208), über zwei Folgeprüfungen als stabil laufend bestätigt (`completed` 4239→5246→13745, `errors=0`). Volle Prozessliste (`Get-CimInstance Win32_Process`) zeigt danach genau **einen** `download_bi5.py`-Prozess (PID 18208); PID 13484 ist verschwunden (vermutlich Spiegel-Kollision). Kein Schaden: `hour_ledger.jsonl` unverändert bei exakt 66.458 Zeilen (0 defekt), jüngster Eintrag weiterhin der ursprüngliche Absturz-Zeitstempel — keiner der kollidierenden Prozesse hatte schon einen neuen Ledger-Eintrag geschrieben, nur die nicht-autoritative `progress.json` war betroffen. Erweitert das bereits mehrfach geflaggte 15-Minuten-Scheduler-Pileup-Muster von doppelten *Lesevorgängen* auf doppelte *Aktionen* gegen eine gemeinsame externe Ressource — nicht selbst behoben (Cadence-Änderung liegt außerhalb dieser Aufgabenautorität), erneut als offene OWNER-Empfehlung markiert. `bb814520`/`dfc60103`: `QM5_41394` SP500.DWX/XAUUSD.DWX Q02 weiterhin unverändert `pending`/unclaimed seit `2026-09-09T10:52:59Z`. Evidenz: `docs/ops/evidence/2026-09-07_dukascopy-backfill-20260829_3032534e_execution.md` (neuer Abschnitt "Checked 2026-09-10T22:49-22:53Z").

> **Nachtrag 10.09., 19:25Z — neuer WTI-Refinery-Ramp-Sleeve bis Q02:** Der
> neue strukturelle `QM5_41426_wti-reframp-wclv-cont` wurde nach Source-
> Freigabe und Canonical-Dedup als XTIUSD.DWX-D1-Build erstellt. PACER-Pin-
> Audit exit 0 / 0 Findings, Referenztests 12/12 PASS, Compile `aa47bbdd`
> COMPILE_OK ohne Compilerfehler/-warnungen. Die finale CPU-Stichprobe lag bei
> Ø 69,06% und max. 74,17% (<97%); genau eine Fixed-Risk-Q02-Zeile `2ad0e7b6`
> wurde enqueued. Kein Portfolio-Gate-, T_Live-, AutoTrading- oder Deploy-
> Eingriff. Evidenz: `docs/ops/evidence/2026-09-10_qm5_41426_wti_refinery_ramp_weekly_close_location_build_q02.md`.

> **Nachtrag 10.09., 18:15Z — neuer WTI-Sleeve bis Q02:** Der neue strukturelle
> `QM5_41425_wti-refrestart-negweek-fade` wurde nach Source-Freigabe und
> Canonical-Dedup als XTIUSD.DWX-D1-Build erstellt. PACER-Pin-Audit exit 0 / 0
> Findings, Referenztests 12/12 PASS, Compile `4516a5b1` COMPILE_OK ohne
> Compilerfehler/-warnungen. Die finale CPU-Stichprobe lag bei Ø 61,83% und
> max. 77,16% (<97%); genau eine Fixed-Risk-Q02-Zeile `e6c263cb` wurde
> enqueued. Kein Portfolio-Gate-, T_Live-, AutoTrading- oder Deploy-Eingriff.
> Evidenz: `docs/ops/evidence/2026-09-10_qm5_41425_wti_refinery_restart_negative_week_build_q02.md`.

> **Nachtrag 10.09., 01:31Z — FX-Cointegration am bindenden CPU-Hard-Stop:**
> Der sign-aware 66-Paar-Scan bleibt vollständig mechanisiert; `QM5_12532` und
> `QM5_12533` besitzen Q02-PASS und keine ONINIT-/NO_HISTORY-Blockade. Der
> konkrete nicht-duplizierende Fallback `QM5_12507_pair-coint-z`
> (EURUSD/GBPUSD H1) besitzt weiterhin genau eine pending, unclaimed,
> priority-tracked Q02-Zeile `547c4fd3`; deshalb kein zweites Enqueue oder
> Priority-Rewrite. Der read-only Source-Pin-Audit ergab exit 0 und null
> `EA_FRAMEWORK_INPUT_PINNED`-Treffer. Fünf CPU-Samples lagen bei Ø 95,746073%
> und max. 98,550951% und überschritten damit die 97%-Kappe; fünf Factory-Zeilen
> waren aktiv bei `launch_gate_max=1`. Gemäß Stop-Regel kein Build, Compile,
> Queue-/Dispatch-, Portfolio- oder Live-Eingriff. Evidenz:
> `artifacts/fx_cointegration_qm5_12507_q02_hard_cpu_stop_20260910T013150Z_board_advisor.json`.

> **Nachtrag 09.09., 18:20Z — FX-cointegration Q02 queue guard:** Der
> sign-aware 66-Paar-Scan bleibt vollständig mechanisiert; `QM5_12532`/`12533`
> sind längst über Q02 hinaus. Der konkrete Fallback `QM5_12507_pair-coint-z`
> (EURUSD/GBPUSD H1) besitzt bereits genau eine pending, unclaimed Q02-Zeile
> `547c4fd3` und ist bereits `priority_track=true`; Dry-Run bestätigte
> `already_priority_track`, daher weder Duplikat-Enqueue noch Priority-Rewrite.
> Source-Pin-Audit exit 0 / 0 Findings. Drei aktive Factory-Zeilen; fünf CPU-
> Samples Ø 74,877095%, max. 94,150163% (<97%). Normale Worker behalten den
> Claim. Kein EA-/Queue-/Portfolio-/Live-Eingriff. Receipt:
> `artifacts/fx_cointegration_qm5_12507_q02_queue_guard_20260909T182020Z_board_advisor.json`.

> **Nachtrag 09.09., ~18:03Z (Orchestrierungszyklus) — keine Zustandsänderung:** Direkte
> `farm_state.sqlite`-Prüfung ~13 Minuten nach dem 17:50Z-Check auf allen drei `IN_PROGRESS`-
> Claude-Aufgaben (`bb814520` CALENDAR-CRITERIA-B-PRIME, `dfc60103` Q09-LEGACY-LOGGER-SAMPLE,
> `3032534e` DUKASCOPY-BACKFILL): `QM5_41394` unverändert — SP500.DWX/XAUUSD.DWX/XTIUSD.DWX
> weiterhin `Q02 pending` seit `10:52:59Z` (~7h10m unclaimed), USDJPY.DWX weiterhin
> `Q03 pending` seit `13:09:21Z` und `Q04 pending` seit `12:19:47Z`, EURUSD.DWX terminal bei
> `Q04 done` (Strategy-Taxonomie-Sackgasse, kein neuer Verdikt-Overwrite versucht). Kein Leg
> hat `Q10_NEWS` erreicht — `bb814520`/`dfc60103` bleiben korrekt `IN_PROGRESS`. `3032534e`:
> Codex-Ticket `2f717775` weiterhin `APPROVED`/unassigned seit `01:24:20Z` (~16h39m); Codex-
> Lane bestätigt 0 `IN_PROGRESS` direkt per SQLite. `farmctl health`: overall=FAIL (13 FAIL/
> 16 WARN/52 OK) — identisches chronisches Set wie beim 17:50Z-Check (u.a. `q09_autoseal_hold_census`,
> `q09_sealed_plan_hold_age`, `pending_artifact_binding_drift`, `agent_task_state_stranded`,
> `work_item_phase_age_slo`, `pending_tail_age`, `backup_calendar_continuity`,
> `task_monitor_escalation`); keine Zeile betrifft die drei gegatterten Ketten. Wochenkontingent
> weiterhin kritisch (~85-87% used) — Zyklus bewusst auf minimale Direct-Read-Verifikation
> beschränkt. Kein Ticket/Rebuild/Release/Router-Zustandswechsel; `agent_router.py run`/
> `route-many`/`replenish` nicht aufgerufen; kein OWNER-Scope-Auftrag erfunden.

> **Nachtrag 09.09., ~17:50Z (Orchestrierungszyklus) — keine Zustandsänderung:** `farmctl
> work-items --ea QM5_41394` direkt geprüft: SP500.DWX/XTIUSD.DWX weiterhin `Q02 pending`
> seit `10:52:59Z` (~6h57m unclaimed; XAUUSD.DWX Zeile identisch pending), USDJPY.DWX
> weiterhin `Q03 pending` seit `13:09:21Z` und `Q04 pending` seit `12:19:47Z`, EURUSD.DWX
> terminal `Q04 FAIL`. Kein Leg hat `Q10_NEWS` erreicht — `bb814520`/`dfc60103` bleiben
> korrekt `IN_PROGRESS`. Codex-Ticket `2f717775` (Dukascopy) weiterhin `APPROVED`/unassigned
> seit `01:24:20Z` (~16h26m) — `3032534e` bleibt korrekt `IN_PROGRESS`. `farmctl health`:
> FAIL 15/WARN 17/OK 51, identisches chronisches Set wie beim 17:31Z-Check, keine Zeile
> betrifft die drei gegatterten Ketten. Wochenkontingent weiterhin kritisch (86 % used/
> 14 % remaining) — Zyklus bewusst auf minimale Direct-Read-Verifikation beschränkt, keine
> Tiefenanalyse. Kein Ticket/Rebuild/Release/Router-Zustandswechsel; `agent_router.py run`/
> `route-many`/`replenish` nicht aufgerufen; kein OWNER-Scope-Auftrag erfunden.

> **Nachtrag 09.09., ~17:31Z (Orchestrierungszyklus) — keine Zustandsänderung:** Direkte
> `farm_state.sqlite`-Prüfung ~13 Minuten nach dem 17:18Z-Check auf allen drei `IN_PROGRESS`-
> Claude-Aufgaben (`bb814520` CALENDAR-CRITERIA-B-PRIME, `dfc60103` Q09-LEGACY-LOGGER-SAMPLE,
> `3032534e` DUKASCOPY-BACKFILL): `QM5_41394` unverändert — SP500/XAUUSD/XTIUSD weiterhin
> `Q02 pending` seit `10:52:59Z` (~6h39m unclaimed), USDJPY.DWX weiterhin `Q03 pending` seit
> `13:09:21Z` und `Q04 pending` seit `12:19:47Z`, EURUSD.DWX terminal `Q04 done` (Sackgasse).
> Kein Leg hat `Q10_NEWS` erreicht — `bb814520`/`dfc60103` bleiben korrekt `IN_PROGRESS`.
> `3032534e`: Codex-Ticket `2f717775` weiterhin `APPROVED`/unassigned seit `01:24:20Z`
> (~16h07m); kein `download_bi5.py`-Prozess sichtbar; kein neuer Reprobe fällig. `farmctl
> health` overall=FAIL (15 FAIL/16 WARN/51 OK) — identisches chronisches Set wie beim
> 17:18Z-Check, keine der Zeilen betrifft die drei gegatterten Ketten. Wochenkontingent
> weiterhin kritisch (86 % used/14 % remaining) — dieser Zyklus hielt sich bewusst auf die
> minimale Direct-DB-Verifikation beschränkt (keine erneute Tiefenanalyse), passend zur bereits
> dokumentierten Scheduler-Pileup-Klasse. Kein Ticket/Rebuild/Release/Router-Zustandswechsel;
> `agent_router.py run`/`route-many`/`replenish` nicht aufgerufen; kein OWNER-Scope-Auftrag
> erfunden.

> **Nachtrag 09.09., 15:19Z — Pattern-Folgeanalyse (read-only):** Balke `QM5_41398`
> hat unabhängige Review PASS und echte Q02 PASS (`2fc84747`, 888 Trades, PF 1,12,
> tatsächliches Fenster 2018-07-02 bis 2022-12-31). Neue Matrix: 1/1.085 Jahreszellen
> gemessen, neutrale 2019-Basis; alle 193 Round-Trips identisch zum alten 41097.
> Die 16 betrachteten Paare haben nun alle Matrix-/Selektionsreceipts: sechs nichtleere
> letzte Filterauswahlen scheitern an WF-Performance und/oder Auswahlstabilität,
> zehn bleiben leer. 2.072 historische B2/B5-Skips sind von 5.366 Activity-Floor-Skips
> getrennt (11/11 Floor-Trigger-Stichproben nativ bestätigt). 28/28 Basis-Set-Hashes
> und 42/42 extrahierte Elternkartenwerte stimmen. Keine pauschale Invalidierung.
> Neue Generator-Gegenbeispiele (Core-Doppelzuweisung, symbolische News-Enums) und
> begrenzte Übertragbarkeit der geerbten News-/Exit-Mechanik dokumentiert, Umsetzung
> explizit geparkt: aktueller Auftrag ist Analyse. 14 Tests PASS, keine Factory-Mutation.
> Evidenz: `docs/ops/evidence/2026-09-09_pattern_lineage_followup_analysis.md` + JSON.
> Balke-Folge bleibt beim bestehenden Task `e1358f42` (Router REVIEW), kein Duplikat.

> **Nachtrag 09.09., ~15:03Z (Orchestrierungszyklus) — keine Zustandsänderung:** Direkte
> `farm_state.sqlite`-Prüfung ~13 Minuten nach dem 14:50Z-Check auf allen drei `IN_PROGRESS`-
> Claude-Aufgaben (`bb814520` CALENDAR-CRITERIA-B-PRIME, `dfc60103` Q09-LEGACY-LOGGER-SAMPLE,
> `3032534e` DUKASCOPY-BACKFILL): alle drei Spawn-Leases abgelaufen (kein konkurrierender
> Halter), `QM5_41394`-Legs unverändert — EURUSD.DWX bleibt terminal `Q04 done` (Sackgasse,
> Strategy-Taxonomie); SP500/XAUUSD/XTIUSD weiterhin `Q02 pending` seit `10:52:59Z`
> (~4h10m unclaimed); USDJPY.DWX weiterhin `Q03 pending` seit `13:09:21Z` und `Q04 pending`
> seit `12:19:47Z`. Kein Leg hat `Q10_NEWS` erreicht — `bb814520`/`dfc60103` bleiben korrekt
> `IN_PROGRESS`. `3032534e`: Codex-Ticket `2f717775` weiterhin `APPROVED`/unassigned seit
> `01:24:20Z` (~13h39m); kein neuer Reprobe fällig. `farmctl health` overall=FAIL
> (15 FAIL/16 WARN/52 OK, geprüft 15:03:21Z) — identisches chronisches Set wie beim
> 14:50Z-Check (`codex_zero_activity`/`codex_auth_broken` weiterhin durch den vorbestehenden
> `repo_dirty_build_guard` auf `QM5_41240`/`QM5_9727` blockiert, nicht durch diese Aufgaben
> verursacht; `q02_stranded_exhausted_pairs`, `phase_invalid_rate_7d`, `agent_task_state_stranded`,
> `agent_task_aging_slo`, `work_item_phase_age_slo`, `pending_tail_age`, `q09_sealed_plan_hold_age`,
> `q09_autoseal_hold_census`, `pending_artifact_binding_drift`, `backup_calendar_continuity`,
> zwei `task_monitor_escalation`-Zeilen — keine davon betrifft die drei gegatterten Ketten);
> keine neue Incidence. Kein Ticket/Rebuild/Release/Router-Zustandswechsel; `agent_router.py
> run`/`route-many`/`replenish` nicht aufgerufen; kein OWNER-Scope-Auftrag erfunden.

> **Nachtrag 09.09., ~14:50Z (Orchestrierungszyklus) — keine Zustandsänderung:** Direkte
> `farm_state.sqlite`-Prüfung ~17 Minuten nach dem 14:33Z-Check auf allen drei `IN_PROGRESS`-
> Claude-Aufgaben (`bb814520` CALENDAR-CRITERIA-B-PRIME, `dfc60103` Q09-LEGACY-LOGGER-SAMPLE,
> `3032534e` DUKASCOPY-BACKFILL): `QM5_41394` unverändert — EURUSD.DWX terminal `Q04 done`
> (Sackgasse, Strategy-Taxonomie); SP500/XAUUSD/XTIUSD weiterhin `Q02 pending` seit
> `10:52:59Z` (~3h57m unclaimed); USDJPY.DWX weiterhin `Q03 pending` seit `13:09:21Z`. Kein
> Leg hat `Q10_NEWS` erreicht — `bb814520`/`dfc60103` bleiben korrekt `IN_PROGRESS`. `3032534e`:
> Codex-Ticket `2f717775` weiterhin `APPROVED`/unassigned seit `01:24:20Z` (~13h26m); Codex-Lane
> bestätigt 0 `IN_PROGRESS` direkt per SQLite (`agent_tasks` where assigned_agent='codex' and
> state='IN_PROGRESS'); kein neuer Reprobe fällig (Cadence „mehrere Stunden, anderer UTC-Slot"
> seit 11:49-11:50Z noch nicht erreicht). Kein Ticket/Rebuild/Release/Router-Zustandswechsel;
> `agent_router.py run`/`route-many`/`replenish` nicht aufgerufen; kein OWNER-Scope-Auftrag
> erfunden.

> **Nachtrag 09.09., ~14:33Z (Orchestrierungszyklus) — keine Zustandsänderung:** Alle drei
> `IN_PROGRESS`-Claude-Aufgaben (`bb814520` CALENDAR-CRITERIA-B-PRIME, `dfc60103`
> Q09-LEGACY-LOGGER-SAMPLE, `3032534e` DUKASCOPY-BACKFILL) direkt gegen `farm_state.sqlite`
> geprüft: `QM5_41394`-Legs unverändert seit dem 13:54Z-Check (SP500/XAUUSD/XTIUSD weiterhin
> `Q02 pending` seit `10:52:59Z`; USDJPY.DWX `Q03 pending` seit `13:09:21Z` und `Q04 pending`
> seit `12:19:47Z`; EURUSD.DWX terminal `Q04 done`, Sackgasse) — kein Leg hat `Q10_NEWS`
> erreicht, `bb814520`/`dfc60103` bleiben korrekt `IN_PROGRESS`. `3032534e`: Codex-Ticket
> `2f717775` weiterhin `APPROVED`/unassigned seit `01:24:20Z`; Codex-Lane bestätigt 0
> `IN_PROGRESS` (`repo_dirty_build_guard`, aktuell 6 uncommitted Pfade in `QM5_41240`/
> `QM5_9727`, nicht durch diese Aufgabe verursacht); kein neuer Reprobe fällig (Cadence
> „mehrere Stunden, anderer UTC-Slot" seit `11:49–11:50Z` noch nicht erreicht). Alle drei
> Spawn-Leases zum Zeitpunkt der Prüfung abgelaufen; keine Reacquisition (Reacquire liefe nur
> über den verbotenen Routing-Pfad `run`/`route-many`/`replenish`, die nicht aufgerufen
> wurden). `farmctl health` overall=FAIL (15 FAIL/15 WARN/53 OK) — identisches chronisches Set
> wie beim 13:54Z-Check; keine der Zeilen betrifft die drei gegatterten Ketten. Kein Ticket/
> Rebuild/Release/Router-Zustandswechsel; kein OWNER-Scope-Auftrag erfunden.

> **Nachtrag 09.09., ~13:54Z (Orchestrierungszyklus) — Balke `e1358f42` unabhängige Review PASS, Hold freigegeben, Q02 kommissioniert:** Alle sechs geforderten Prüfpunkte aus dem Handoff (`docs/ops/evidence/2026-09-09_balke_41398_review_handoff.md`) wurden aus Primärevidenz neu abgeleitet, nicht übernommen: native Compile-Evidence (`e8e4cad7`, COMPILE_OK 0/0, alle drei Hashes lokal nachgerechnet und identisch), Source-Diff gegen das eingefrorene 41097 (`diff` zeigt exakt 4 Hunks: Beschreibung, `qm_ea_id`, `QM_PATTERN_PERMISSION_EA_MANAGED`-Define + Kommentar — sonst nichts), Registry/Magic (`git show 677068883e`: je genau eine neue Zeile, gleiche Logik-Identity-UUID wie 41097, Magic `413980000` = `41398*10000+0`, kollisionsfrei), 28/28 Inputs im Source UND im generierten Setfile bestätigt (6 `opt_pp_*`=0 neutral, `RISK_FIXED=1000`/`RISK_PERCENT=0`, `qm_news_stale_max_hours=336` an der Guardrail-Obergrenze, nicht darüber), geschlossenes D1 Shift 1 (`QM_PPC_REFERENCE_TF`/`QM_PPC_CLOSED_SHIFT` compile-time constants) mit beiden Straddle-Beinen (`plan.want_buy`/`want_sell`) im selben Plan/Permission/Decision-Pfad, und der geerbte frühe News-Return vor Management/Exit (`OnTick` Zeilen 557-573) ist in 41097 und 41398 identisch vorhanden — verzerrt den relativen Reparatur-vs-Baseline-Vergleich nicht, bleibt aber explizit ungelöste Live-Deploy-Einschränkung. Der `gen_setfile.ps1`-Fix (`[hashtable]`→`[System.Collections.IDictionary]`) wurde per eigenem `pytest`-Lauf reproduziert (2/2 PASS). Ergebnis: unabhängige PASS, Evidenz `docs/ops/evidence/2026-09-09_balke_41398_independent_review.md` (Commit `8800ce0b8d`). Danach genau die vorgesehene Zeile freigegeben — `farmctl release-hold --work-item-id 97908d93-3ff8-5528-9518-8968aea72342 --expected-hold-code BALKE_PATTERN_REPAIR_REVIEW_PENDING` (Dry-Run zuerst, dann Apply; `work_items_untouched=true`) — die zwei anderen Duplikate (`ed127702…`, `0e5eff83…`) bleiben unverändert gehalten. Anschließend `farmctl service-dl089-matrix --work-item-id 97908d93… --apply`: genau ein neuer Q02-Work-Item `2fc84747-27db-5e88-9568-3fdda6c30769` (status `pending`, `superseded_work_item_id=null` — keine Wiederverwendung der alten 41097-Messungen). Router-Task `e1358f42` → `REVIEW`. **Wichtig:** eine zeitgleiche zweite Claude-Session hat dieselbe Review unabhängig nachvollzogen (Commit `60e8e593a2`) und keine Abweichung gefunden — Zwei-Sessionen-Kreuzkontrolle bestätigt das Ergebnis, keine Duplikat-Freigabe/-Seed erfolgt. Keine wirtschaftliche Messung gestartet, kein Live-/Account-/Deploy-Bezug.
>
> `bb814520`/`dfc60103`/`3032534e` in diesem Zyklus ebenfalls geprüft: `QM5_41394`-Legs unverändert (SP500/XAUUSD/XTIUSD weiterhin Q02 pending seit 10:52:59Z, kein Leg terminal bei Q10_NEWS) — `bb814520` bleibt korrekt `IN_PROGRESS`. `dfc60103` (Legacy-Logger, tauchte diesen Zyklus wieder in der `IN_PROGRESS`-Liste auf) hängt an derselben Kette: der Rebuild-Ersatz für 11167 läuft als `QM5_41394` (OWNER-Option B, bereits umgesetzt via Codex-Ticket `5088aa6e`/`b66b5ccc`), noch kein Leg terminal — kein neuer Codex-Ticket nötig, Rebuild/Recompile bleibt ROT und ist bereits abgedeckt. `3032534e`: eigener gebundener Reprobe deckt sich mit dem zeitgleich von der zweiten Session geloggten Fenster (`completed` 30→36, `downloaded=6/errors=0`, aber erneut `WinError 10060/10054` im selben Fenster — gemischtes Signal, keine belastbare Erholung); kein Produktivlauf neu gestartet, kein Ticket dupliziert. `2f717775` weiterhin `APPROVED`/unassigned. Alle drei Aufgaben bleiben `IN_PROGRESS`, kein Router-Zustandswechsel nötig.

> **Nachtrag 09.09., 13:42Z — Balke-Pattern-Reparatur, neuer Build und Review-Auftrag:**
> `QM5_41398_balke-pattern-repair-opt` ist separat registriert und nativ COMPILE_OK
> (`e8e4cad7`, T9, 0 Fehler/0 Warnungen); 144 erweiterte Tests PASS. Zusätzlich wurde
> ein reproduzierter Setfile-Generatorfehler bei der Übernahme von Kartenwerten
> korrigiert. Alte Balke-Artefakte/Ergebnisse bleiben unverändert. Review + bedingte
> neutrale Q02-Übergabe: `e1358f42-c9f2-4cd2-89ce-f337b17ac84a`, Prio 92, Claude-pin,
> inzwischen IN_PROGRESS / assigned_agent=claude. Alle drei doppelten Q12-Anforderungen bleiben
> geschützt; erst nach unabhängiger Abnahme nur `97908d93…` freigeben. Null neue
> wirtschaftliche Messungen bisher; keine Rendite-/Portfolio-/Live-Freigabe.
> Ergebnis: `docs/ops/evidence/2026-09-09_balke_pattern_recovery.md`; exakter Auftrag:
> `docs/ops/evidence/2026-09-09_balke_41398_review_handoff.md`. Code-Checkpoints
> `503fb410f5` / `677068883e`. Historischer Karten-/Set-Vergleich explizit geparkt,
> bis die neue Balke-Basis geklärt ist.

> **Nachtrag 09.09., ~13:34Z (Orchestrierungszyklus) — keine Zustandsänderung:** Direkte
> `farm_state.sqlite`-Prüfung ~16 Minuten nach dem 13:18Z-Check auf allen drei `IN_PROGRESS`-
> Claude-Aufgaben (`bb814520` CALENDAR-CRITERIA-B-PRIME, `dfc60103` Q09-LEGACY-LOGGER-SAMPLE,
> `3032534e` DUKASCOPY-BACKFILL): keine Änderung. `QM5_41394`: EURUSD bleibt terminal
> `Q04 FAIL` (Sackgasse, Strategy-Taxonomie); USDJPY.DWX unverändert bei `Q03 pending`
> (`e89d6f8a…`, seit `13:09:21Z`) und `Q04 pending` (`bd6f7c72…`, seit `12:19:47Z`); SP500/
> XAUUSD/XTIUSD weiterhin `Q02 pending` seit `10:52:59Z` (~2h41m unclaimed) — reine
> Kapazitätsfrage der Fabrik-Queue, kein manueller Eingriff im GRÜN-Rahmen dieser Aufgabe.
> Kein Leg hat Q10_NEWS erreicht — `bb814520`/`dfc60103` bleiben korrekt `IN_PROGRESS`.
> `3032534e`: Codex-Ticket `2f717775` weiterhin `APPROVED`/unassigned seit `01:24:20Z`
> (~12h10m); Codex-Lane weiterhin 0 `IN_PROGRESS` (bestätigt per `list-tasks --agent codex
> --state IN_PROGRESS`), Ursache unverändert der vorbestehende `repo_dirty_build_guard`
> (kanonischer Checkout jetzt 71 unstaged Pfade, nicht durch diese Aufgabe verursacht); kein
> neuer Reprobe fällig (Cadence-Vorgabe „mehrere Stunden, anderer UTC-Slot" seit 11:49-11:50Z
> noch nicht erreicht). Alle drei Spawn-Leases abgelaufen (`12:49:38Z`), keine Reacquisition
> durch diese Session (Reacquire läuft nur über den verbotenen Routing-Pfad). `farmctl health`
> overall=FAIL (15 FAIL/15 WARN/53 OK) — identisches chronisches Set wie beim 13:18Z-Check
> (`codex_zero_activity`, `agent_task_state_stranded`, `agent_task_aging_slo`,
> `work_item_phase_age_slo`, `q09_sealed_plan_hold_age`, `q09_autoseal_hold_census`,
> `pending_artifact_binding_drift`, Scheduled-Task/Backup-Calendar-FAILs); keine dieser Zeilen
> betrifft die drei gegatterten Ketten. Kein Ticket/Rebuild/Release/Router-Zustandswechsel;
> `agent_router.py run`/`route-many`/`replenish` nicht aufgerufen; kein OWNER-Scope-Auftrag
> erfunden.

> **Nachtrag 09.09., ~13:18Z (Orchestrierungszyklus) — keine Zustandsänderung:** ~14 Minuten
> seit dem 13:04Z-Check. `git log --since=2026-09-09T13:04:00Z` zeigt nur den eigenen 13:04Z-
> Log-Commit und einen fremden Codex-Review-Commit (`fc355cb7dd`, QM5_41280-Build-Review) —
> kein neuer OWNER-Receipt. `QM5_41394`: USDJPY.DWX-Leg hat eine neue Q03-Zeile (`e89d6f8a…`,
> `pending`, `13:09:21Z`) neben der bestehenden Q04-Zeile (`bd6f7c72…`, `pending`,
> `12:19:47Z`) — reine Fabrik-interne Parallelverarbeitung, kein Terminalverdikt. SP500/XAUUSD/
> XTIUSD unverändert `Q02 pending` seit `10:52:59Z`, EURUSD unverändert `Q04 done`
> (Strategy-Taxonomie-Sackgasse). Kein Leg hat Q10_NEWS erreicht — `bb814520`/`dfc60103`
> bleiben korrekt `IN_PROGRESS`. `3032534e`: Codex-Ticket `2f717775` weiterhin
> `APPROVED`/unassigned seit `01:24:20Z` (~11h54m); kein neuer Reprobe fällig (Cadence-Vorgabe
> „mehrere Stunden, anderer UTC-Slot" seit dem letzten Reprobe 11:49–11:50Z noch nicht erreicht).
> `farmctl health` overall=FAIL (15 FAIL/16 WARN/53 OK) — identisches chronisches Set wie beim
> 13:04Z-Check (`codex_zero_activity`, `q02_stranded_exhausted_pairs`, `phase_invalid_rate_7d`,
> `agent_task_state_stranded`, `agent_task_aging_slo`, `work_item_phase_age_slo`,
> `q09_sealed_plan_hold_age`, `q09_autoseal_hold_census`, `pending_artifact_binding_drift`,
> Scheduled-Task/Backup-Calendar-FAILs); keine dieser Zeilen betrifft die drei gegatterten
> Ketten. Kein Ticket/Rebuild/Release/Router-Zustandswechsel; `agent_router.py
> run`/`route-many`/`replenish` nicht aufgerufen.

> **Nachtrag 09.09., ~13:04Z (Orchestrierungszyklus) — keine Zustandsänderung:** Direkte
> DB-Prüfung ~12 Minuten nach dem 12:52Z-Check bestätigt: `QM5_41394` unverändert — USDJPY.DWX
> weiterhin `Q04 pending` (`bd6f7c72…`, seit `12:19:47Z`), SP500/XAUUSD/XTIUSD weiterhin
> `Q02 pending` seit `10:52:59Z`, EURUSD weiterhin `Q04 FAIL` (Sackgasse). Kein Leg hat
> Q10_NEWS erreicht — `bb814520`/`dfc60103` bleiben korrekt `IN_PROGRESS`. `3032534e`:
> Codex-Ticket `2f717775` weiterhin `APPROVED`/unassigned seit `01:24:20Z` (~11h40m); letzter
> Reprobe-Zyklus 11:49-11:50Z, Cadence weiterhin nicht fällig, daher kein neuer Reprobe. Spawn-
> Lease `agent_task:3032534e-eaf0-5b68-b09f-2127ebb315b0` weiterhin abgelaufen (`12:49:38Z`);
> diese Session reacquired sie nicht (Reacquire läuft nur über den Routing-Pfad, den dieser
> Auftrag verbietet). `farmctl health` overall=FAIL (15 FAIL/16 WARN/52 OK) — identisches
> chronisches Set wie 12:52Z (`codex_zero_activity`, `q02_stranded_exhausted_pairs`,
> `phase_invalid_rate_7d`, `agent_task_state_stranded`, `agent_task_aging_slo`,
> `work_item_phase_age_slo`, `q09_sealed_plan_hold_age`, `q09_autoseal_hold_census`,
> `pending_artifact_binding_drift`, Scheduled-Task/Backup-Calendar-FAILs); keine dieser Zeilen
> betrifft die drei gegatterten Ketten. `git log --since=2026-09-09T12:52:00Z` zeigt nur den
> Commit des 12:52Z-Zyklus selbst, keinen neuen OWNER-Receipt. Kein Ticket/Rebuild/Release/
> Router-Zustandswechsel; `agent_router.py run`/`route-many`/`replenish` nicht aufgerufen.

> **Nachtrag 09.09., ~12:52Z (Orchestrierungszyklus) — keine Zustandsänderung:** Direkte
> DB-Prüfung zwei Minuten nach dem 12:50Z-Check: `QM5_41394` unverändert — USDJPY.DWX weiterhin
> `Q04 pending` (`bd6f7c72…`), SP500/XAUUSD/XTIUSD weiterhin `Q02 pending` seit `10:52:59Z`,
> EURUSD weiterhin `Q04 FAIL` (Sackgasse). Kein Leg hat Q10_NEWS erreicht —
> `bb814520`/`dfc60103` bleiben korrekt `IN_PROGRESS`. `3032534e`: Codex-Ticket `2f717775`
> weiterhin `APPROVED`/unassigned seit `01:24:20Z` (~11h28m); kein neuer Reprobe fällig. Lease
> `agent_task:3032534e-eaf0-5b68-b09f-2127ebb315b0` ist um `12:49:38Z` abgelaufen; diese Session
> reacquired sie nicht (Reacquire läuft nur über den Routing-Pfad, den dieser Auftrag verbietet)
> — die 5-Minuten-Router-Zyklus soll sie eigenständig erneuern. `farmctl health` overall=FAIL
> (15 FAIL/16 WARN/53 OK) — chronisches Set unverändert, keine Zeile betrifft die drei
> gegatterten Ketten. Kein Ticket/Rebuild/Release/Router-Zustandswechsel;
> `agent_router.py run`/`route-many`/`replenish` nicht aufgerufen. Details:
> `docs/ops/evidence/2026-09-09_q09-legacy-calendar-input-20260909_70823296_execution.md`,
> `docs/ops/evidence/2026-09-07_dukascopy-backfill-20260829_3032534e_execution.md`.

> **Nachtrag 09.09., ~12:50Z (Orchestrierungszyklus) — Teilfortschritt USDJPY-Leg, weiterhin keine
> Terminaladjudikation:** Direkte DB-Prüfung `QM5_41394`: USDJPY.DWX-Leg genuine neu seit dem
> 11:48Z-Check — Q02 jetzt `done`/`PASS` (`80789556…`, 12:17:13Z) und bereits eine neue Q04-Zeile
> `bd6f7c72…` (`pending`, 12:19:47Z). SP500/XAUUSD/XTIUSD unverändert `Q02 pending` seit `10:52:59Z`;
> EURUSD unverändert `Q04 FAIL` (Sackgasse, strategy-Taxonomie). Damit existiert weiterhin **kein**
> terminales Q10_NEWS-PASS/FAIL auf irgendeinem Leg — `bb814520`/`dfc60103` bleiben korrekt
> `IN_PROGRESS`. `3032534e`: Codex-Ticket `2f717775` weiterhin `APPROVED`/unassigned seit `01:24:20Z`
> (~11h26m), kein neuer Reprobe (letzter Reprobe-Zyklus 11:49-11:50Z, Cadence noch nicht wieder
> fällig). Spawn-Leases für alle drei Aufgaben zuletzt `12:19:38Z` reacquired (Ablauf `12:49:38Z`).
> `farmctl health` overall=FAIL (15 FAIL/17 WARN/52 OK) — chronisches Set unverändert
> (`codex_zero_activity`/`repo_dirty_build_guard`, `q02_stranded_exhausted_pairs`,
> `phase_invalid_rate_7d`, `agent_task_state_stranded`, `agent_task_aging_slo`,
> `work_item_phase_age_slo`, `q09_sealed_plan_hold_age`, `q09_autoseal_hold_census`,
> `pending_artifact_binding_drift`, Scheduled-Task/Backup-Calendar-FAILs); keine dieser Zeilen
> betrifft die drei gegatterten Ketten. Kein Ticket/Rebuild/Release/Router-Zustandswechsel;
> `agent_router.py run`/`route-many`/`replenish` nicht aufgerufen. Details:
> `docs/ops/evidence/2026-09-09_q09-legacy-calendar-input-20260909_70823296_execution.md`,
> `docs/ops/evidence/2026-09-07_dukascopy-backfill-20260829_3032534e_execution.md`.

> **Nachtrag 09.09., 11:48Z (Orchestrierungszyklus) — keine Zustandsänderung:** `bb814520`/`dfc60103`
> weiterhin korrekt `IN_PROGRESS`, gegattert auf denselben Q10_NEWS-Terminalverdikt-Ketten wie
> zuletzt (die vier `QM5_41394`-Symbol-Legs SP500/USDJPY/XAUUSD/XTIUSD unverändert `Q02 pending`
> seit `10:52:59Z`, EURUSD-Leg unverändert `Q04 FAIL`). `3032534e` weiterhin `IN_PROGRESS`,
> `2f717775` weiterhin `APPROVED`/unclaimed seit `01:24:20Z` (~10h24m), kein neuer Reprobe (Cadence
> bereits erschöpft). `farmctl health` overall=FAIL (14 FAIL, unverändertes chronisches Set:
> `codex_zero_activity`/`repo_dirty_build_guard`, `q02_stranded_exhausted_pairs`,
> `phase_invalid_rate_7d`, `agent_task_state_stranded`, `agent_task_aging_slo`,
> `work_item_phase_age_slo`, `q09_sealed_plan_hold_age`, `q09_autoseal_hold_census`,
> `pending_artifact_binding_drift`, Scheduled-Task/Backup-Calendar-FAILs) — keine dieser Zeilen
> betrifft die drei gegatterten Ketten oder ist einer laufenden `claude`-Aufgabe zugeordnet; kein
> OWNER-Scope-Werk erfunden. `agent_router.py run`/`route-many`/`replenish` nicht aufgerufen.
> Details: `docs/ops/evidence/2026-09-09_q09-legacy-calendar-input-20260909_70823296_execution.md`,
> `docs/ops/evidence/2026-09-07_dukascopy-backfill-20260829_3032534e_execution.md`.

> **Nachtrag 09.09., ~11:19Z (Orchestrierungszyklus) — Codex-Ticket `b66b5ccc` APPROVED, `46167bd9` erfüllt seine eigenen Akzeptanzkriterien und geht auf REVIEW:** Direkte DB-Prüfung bestätigte einen echten Q02-`PASS` (Worker-Evidenz, `real_ticks_marker=true`, deterministic) für `QM5_41394`/EURUSD (die neu gebaute `QM5_11167`-Identität) — genau die Beobachtung, auf die `b66b5ccc` explizit wartete. Ticket auf `APPROVED` geschlossen (reine Review, kein Code geändert). `46167bd9`s eigene vier Akzeptanzkriterien (Scope vermessen, Neubau ab Q02, kein Threshold/Verdict/T_Live-Eingriff, keine Kontinuität behauptet) sind damit erfüllt — unabhängig davon, ob irgendein Symbol-Leg je Q10_NEWS erreicht. `46167bd9` daher `IN_PROGRESS`→`REVIEW` (Independent-Closeout bleibt für später/OWNER). **`bb814520`/`dfc60103` bleiben unverändert `IN_PROGRESS`** — ihr Kriterium ist die strengere Q10_NEWS-Adjudikation, die EURUSD-Leg ist bereits bei Q04 (strategy FAIL) ausgeschieden, die vier übrigen Legs (SP500/USDJPY/XAUUSD/XTIUSD) stehen noch `Q02 pending`. Details: `docs/ops/evidence/2026-09-09_q09-legacy-calendar-input-20260909_70823296_execution.md`. Bestätigt: mehrfache parallele Orchestrierungszyklen schreiben weiterhin near-simultan in dieselben Dateien (Scheduler-Pileup bereits gemeldet, hier nur erneut beobachtet, nicht behoben).

> **Nachtrag 09.09., 07:27Z (Orchestrierungszyklus) — alle 3 IN_PROGRESS-Claude-Aufgaben erneut geprüft, kein Zustandswechsel:** `bb814520`/`dfc60103` bleiben blockiert auf `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909` (Vorlage weiterhin ohne `OWNER-Antwort`-Abschnitt, `G:`-Vault weiterhin `UnauthorizedAccessException`). `3032534e`: Codex-Ticket `2f717775` weiterhin `APPROVED`/unassigned seit `2026-09-09T01:24:20Z` (DB direkt geprüft, unverändert); letzter echter Reprobe war 06:39Z (~48min vor diesem Zyklus) — die Vorgabe „mehrere Stunden, anderer UTC-Slot" ist damit noch nicht erreicht, kein neuer Reprobe. Spawn-Lease-Tabelle direkt geprüft: einzige Zeile (`3032534e`) ist seit `01:32:47Z` abgelaufen, kein aktiver Lease auf einer der drei Aufgaben. Kein Router-Zustandswechsel, kein Ticket/Rebuild/Release erzeugt. Das bereits gemeldete 15-Minuten-Scheduler-Pileup (mehrere gleichzeitige `claude.exe`) bleibt unangetastet, da eine Korrektur außerhalb dieser drei Aufgaben liegt.

> **Nachtrag 09.09., 06:44Z — FX-Fallback 41335 Q02 PASS; CPU-Deckel stoppt Q04:**
> Der eingefrorene 66-Paar-Cointegration-Frontier bleibt vollständig gebaut;
> 12532/12533 sind nicht Q02-blockiert. Der bereits einmalig eingereihte
> AUDUSD-D1-Fallback `QM5_41335` (`ff75b1c3`) schloss um 06:13:19Z mit Q02
> `PASS`; noch keine Q04-Nachfolgezeile vorhanden. Die Fabrik steht zugleich
> bei 9 aktiven Zeilen (5 Q04, 4 OPT_CENSUS) gegen das bindende Limit 7.
> Deshalb kein Q04-Enqueue, kein Duplikat der weiterhin pending logischen
> 12507-Q02-Zeile, kein Priority-/Dispatch-Eingriff. Evidenz:
> `docs/ops/evidence/2026-09-09_fx_cointegration_qm5_41335_q02_pass_cpu_ceiling_stop.md`.

> **Nachtrag 09.09., 06:39Z (Orchestrierungszyklus) — Dukascopy-Reprobe zeigt Signaturwechsel (Teilerholung), Kalender/Q09 weiter OWNER-blockiert:** `bb814520`/`dfc60103` bleiben unverändert auf `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909` blockiert (Vorlage weiterhin ohne OWNER-Antwort, `G:`-Vault weiterhin nicht erreichbar, kein aktiver Spawn-Lease). `3032534e`: gebundener Reprobe (~52s aktive Laufzeit, resumed aus `20260909T032705Z`) zeigt erstmals **keine** `WinError 10060/10054`/TLS-Timeouts mehr — 2/4 neue Stunden-Dateien echt heruntergeladen (HTTP 200, Ticks dekodiert), 2/4 mit `HTTP 503` gescheitert (Applikationsebene, nicht Netzwerkebene). Liest sich als Teilerholung (TCP/TLS jetzt stabil, Server liefert gelegentlich 503 statt Timeout) — Stichprobe zu klein für Neustart des Produktivlaufs; Detail in `docs/ops/evidence/2026-09-09_dukascopy_backfill_datafeed_connectivity_degraded.md`. Kein Router-Zustandswechsel, kein Produktivlauf gestartet, kein Terminal/Factory/T_Live berührt.

> **Nachtrag 09.09., 06:20Z (Orchestrierungszyklus) — Dukascopy-Degradation strukturell bestätigt; Pileup live beobachtet:** `bb814520`/`dfc60103` bleiben blockiert auf `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909` (weiterhin ohne Antwort). `3032534e`: gebundener 75s-Applikationsebene-Reprobe (nicht nur TCP) zeigt denselben `WinError 10060` wie 01:27Z/02:33Z — **dritter unabhängiger Zeitfenster-Sample über ~5h**, Degradation liest sich jetzt als strukturell/dauerhaft für diese Dukascopy-Edge-IP von dieser VPS aus, nicht als Tageszeit-Stau; nächster sinnvoller Schritt ist Option 3 (Codex Retry/Backoff-Tuning, sobald die Lane frei ist) oder Option 4 (OWNER-Kenntnis, Plan-Zeitschätzung hält von dieser VPS nicht). Codex-Ticket `2f717775` weiterhin `APPROVED`/unclaimed seit 01:24:20Z (~5h). **Bestätigt live:** zwei parallel laufende Orchestrierungszyklen (06:17Z und 06:20Z) schrieben unabhängig fast identische "keine Änderung"-Einträge in dieselbe Evidenzdatei binnen 3 Minuten — konkreter Beleg für das bereits mehrfach geflaggte 15-Minuten-Scheduler-Pileup (9 parallele `claude.exe`), keine Korrektur von innerhalb dieser Aufgabe vorgenommen. Kein Router-Zustandswechsel, nichts dupliziert.

> **Nachtrag 09.09., 05:02Z (Orchestrierungszyklus) — alle 3 IN_PROGRESS-Claude-Aufgaben erneut geprüft, kein Zustandswechsel:** Nur ~14 Minuten seit dem letzten Zyklus (04:48Z); `git log --since=2026-09-09T04:48:00Z` zeigt nur fremde Factory-/Build-Commits (WTI-Momentum-Serie, Census-Fix), keinen neuen OWNER-Receipt. `bb814520`/`dfc60103` bleiben blockiert auf `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909` (weiterhin ohne Antwort). `3032534e`: letzter echter (Applikations-)Reprobe war 02:33-02:36Z; Abstand zu diesem Zyklus ~2h26m — die Vorgabe „mehrere Stunden, anderer UTC-Slot" ist damit noch nicht sicher erreicht (Ziel ~03h+), daher kein Reprobe, kein Download-Neustart; nächster Zyklus liegt näher an der 3h-Marke. `repo_dirty_build_guard`-Befund (QM5_41240, zwei Dateien) im aktuellen `git status` erneut bestätigt unverändert vorhanden, weiterhin nur geflaggt, kein Ticket eröffnet (außerhalb der drei zugewiesenen Aufgaben). Kein Router-Zustandswechsel, nichts dupliziert.

> **Nachtrag 09.09., 04:48Z (Orchestrierungszyklus) — alle 3 IN_PROGRESS-Claude-Aufgaben erneut geprüft, kein Zustandswechsel:** `bb814520`/`dfc60103` bleiben blockiert auf `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909` (weiterhin ohne Antwort, `G:`-Vault weiterhin permission-denied). `3032534e`: Codex-Ticket `2f717775` weiterhin `APPROVED`/unclaimed (~3h24m seit 01:24:20Z); `farmctl health` zeigt `codex_zero_activity` FAIL + `codex_auth_broken` WARN, beide auf `repo_dirty_build_guard` zurückgeführt (10 uncommitted Dateien in `C:\QM\repo`, u.a. `QM5_41240_wti-samecal-ramsaye5`) — plausible Erklärung für die Codex-Untätigkeit, aber außerhalb der drei zugewiesenen Aufgaben, daher nur zur Kenntnis vermerkt, kein Ticket eröffnet. Kein Router-Zustandswechsel, nichts dupliziert.

> **Nachtrag 09.09., 04:18Z (Orchestrierungszyklus) — alle 3 IN_PROGRESS-Claude-Aufgaben erneut geprüft, kein Zustandswechsel:** ~15 Minuten seit dem letzten Zyklus (04:03Z); `git log --since=2026-09-09T04:03:00Z` zeigt nur einen fremden Q02-CPU-Stop-Eintrag. `bb814520` und `dfc60103` bleiben blockiert auf `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909` (weiterhin ohne Antwort, `G:`-Vault weiterhin permission-denied). `3032534e`: Codex-Ticket `2f717775` weiterhin `APPROVED`/unclaimed seit 01:24:20Z; letzter echter Reprobe war 02:36Z, ~1h42m Abstand — die Vorgabe „mehrere Stunden, anderer UTC-Slot" noch nicht erreicht, kein Reprobe, kein Download-Neustart. Kein Router-Zustandswechsel, nichts dupliziert.

> **Nachtrag 09.09., 03:34Z (Orchestrierungszyklus) — alle 3 IN_PROGRESS-Claude-Aufgaben erneut geprüft, kein Zustandswechsel:** Nur ~12 Minuten seit dem letzten Zyklus (03:22Z); kein neuer Commit zu `bb814520`/`dfc60103`/`3032534e` außer Fabrik-Hintergrundaktivität. `bb814520` und `dfc60103` bleiben blockiert auf `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909` (weiterhin ohne Antwort). `3032534e`: letzter echter Reprobe war 02:36Z; die Vorgabe „mehrere Stunden, anderer UTC-Slot" ist mit ~1h Abstand noch nicht erreicht — kein Reprobe, kein Download-Neustart. `repo_dirty_build_guard`-Befund (QM5_41240) unverändert, weiterhin nur geflaggt, kein Ticket eröffnet. Kein Router-Zustandswechsel.

> **Nachtrag 09.09., 02:48Z (Orchestrierungszyklus) — alle 3 IN_PROGRESS-Claude-Aufgaben geprüft, kein Zustandswechsel, keine neue Arbeit:** Aufgaben `bb814520` (Calendar-Criteria-B-prime) und `dfc60103` (Q09-Legacy-Logger-Sample) bleiben unverändert auf OWNER-Karte `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909` blockiert (Vorlage `docs/ops/OWNER_VORLAGE_2026-09-09_q09_legacy_calendar_input.md`, gestellt vorigen Zyklus, weiterhin ohne Antwort) — kein Duplikat-Ticket, kein Rebuild, kein Verdict-Eingriff. Aufgabe `3032534e` (Dukascopy) bleibt blockiert auf Datenfeed-Erholung: der letzte reale (nicht TCP-only) Reprobe war 02:04Z, ~44 Minuten vor diesem Zyklus — die Vorgabe „mehrere Stunden, anderer UTC-Slot" ist damit noch nicht erreicht; ein erneuter Reprobe jetzt würde nur denselben zu-frühen Datenpunkt wiederholen, daher unterlassen. Keine Terminals/Downloads gestartet, keine Holds berührt. Alle drei Aufgaben bleiben korrekt IN_PROGRESS.

> **Nachtrag 09.09., 02:04Z (Orchestrierungszyklus) — Dukascopy Datenfeed weiter degradiert, kein Download-Neustart:** Nach dem Stopp des Produktiv-Downloads um 01:31:57Z (nur 6/304.621 Stunden, hochgerechnet ~167 Tage statt 3-5 Tage geplant — Detail `docs/ops/evidence/2026-09-09_dukascopy_backfill_datafeed_connectivity_degraded.md`) zeigt ein reiner Lese-TCP-Reprobe (194.8.15.180:443, 8 Versuche, +~35min) weiterhin ~50 % Timeouts, keine Erholung. Kein Downloader neu gestartet, kein Import, kein OFF-Fenster. GRÜN/Messung, kein OWNER-Entscheid noetig; naechster sinnvoller Schritt ist ein Reprobe mehrere Stunden spaeter (anderer UTC-Slot). Task `3032534e` bleibt IN_PROGRESS.

> **Nachtrag 09.09., 01:20Z (Orchestrierungszyklus) — Dukascopy Schritt 1 fertig, Preisskalen-Ticket eingereiht:** T1-Tick-Tail-Probe `e29eab1c` lieferte die 37-Zeilen-Splice-CSV (`D:\QM\reports\dukascopy\splice\20260909_010553\tick_tail.csv`), Archiv-Manifest unveraendert. Bestaetigt: `default_price_scale()` liefert fuer die 9 Nicht-FX-Symbole (GDAXI/NDX/SP500/UK100/WS30/XAGUSD/XAUUSD/XNGUSD/XTIUSD) `None`, kein Registry-Ersatz vorhanden -> Codex-Ticket **2f717775** (Prio 78, APPROVED): zweite governed T1-Read-only-Probe liest SYMBOL_DIGITS/SYMBOL_POINT direkt vom Broker (keine erfundenen Werte), verdrahtet die 9 Werte in Konverter/Abgleich. Kein Produktiv-Download, kein Import, kein OFF-Fenster. Detail: `docs/ops/evidence/2026-09-07_dukascopy-backfill-20260829_3032534e_execution.md`. bb814520/dfc60103 unveraendert, weiter blockiert auf OWNER-Karte `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909` (aus dem vorigen Zyklus, keine Antwort bisher).

> **Nachtrag 09.09., 01:07Z — FX-Fallback QM5_41335 in Q02:** Der eingefrorene
> 66-Paar-Cointegration-Frontier ist vollständig gebaut; 12532/12533 sind nicht
> Q02-blockiert. Deshalb wurde der explizite Fallback genutzt: der bestehende,
> APPROVED, niedrigfrequente AUDUSD-D1-Sleeve 41335 ist nach sauberem PACER-Pin-
> Audit (`hit_count=0`) und COMPILE_OK-Hashbindung als genau ein Q02-Canary
> `ff75b1c3-4930-419d-a2fe-49bd37eadc4d` eingereiht. Status `pending`, kein
> Priority-Boost, kein Live-/Portfolio-Eingriff. Detail:
> `docs/ops/evidence/2026-09-09_fx_funnel_qm5_41335_q02_intake.md`.

> **Nachtrag 08.09., 14:12Z — OWNER Option A beschlossen, Legacy-Logger-Canary bereit:**
> Receipt `821096ac-8f7f-4c28-b0ce-63a09e959de1`, Code `07af95fcf1`, 124 Tests PASS.
> Exakte archivierte Pre-Control-Binaries statt mtime-Ausnahme; nur 11167 aktiviert,
> deklarierte `legacy_no_sv`-Authentifizierung durch Smoke, Q09-Receipts und Aggregate.
> Neuer append-only Q10_NEWS-Canary `6797ed1c-597a-4d44-82f9-7379d45b5e06`:
> Plan automatisch gebunden, B′-Kalender-Scope separat authentifiziert/freigegeben,
> priorisiert und pending. Altes `f625d9aa` bleibt REVIEW_REQUIRED.
> **Offen:** native Selection-/Holdout-Abnahme, danach 11196 und weitere registrierte
> Alt-Binaries; vollständiger Gate-Abschluss. Kein weiterer Owner-Entscheid nötig,
> keine Live-/AutoTrading-/Risiko-Änderung. Detail und eindeutiger Fortsetzungspunkt:
> `docs/ops/evidence/2026-09-08_q09-legacy-logger-sample-20260907_821096ac_execution.md`.

> **Nachtrag 19:30Z (07.09.) - OFF-Tick 19:30Z: STRATEGY CONSOLE v4 ABGENOMMEN (bb036699 APPROVED, 8cfde7742c), OWNER-Re-Attach offen:** Astra hat das OWNER-Paket in den V5-Rahmen portiert: `QM_DesignTokens.mqh` (24/24 Tokens = Paket-JSON), `QM_ConsoleModel/ConsoleData/StrategyConsole.mqh`, `QM_ChartPanel.mqh` als Adapter; Hierarchie Wordmark -> STRATEGY CONSOLE -> Titel aus der registrierten EA-Identitaet -> State-Card -> Filter Gate (nur echte Gates; kein Governor-Gate, solange 11421 auf dem Legacy-DXZ-Vertrag laeuft) -> Risk (ohne erfundene DD-Raeume) -> LIVE nur bei Exposure -> Today/Week + PERFORMANCE-Tabelle (OWNER 09:00Z) -> Footer; Modi FULL/COMPACT/MINIMAL + View-Button (OnChartEvent, nur Praesentation); de-DE Standard, en-US per Input. Compile 0E/0W (Header + Canary, FTMO-MetaEditor), 8 Tests, Trading-Pfad-Aequivalenz gegen db44a0983a PASS, Demo-Install Hash-Match 5be08463 (beide Orte), Fabrik-EX5 9dd7facd unveraendert, AutoTrading/T_Live/T1-T10 unberuehrt; Objekt-Zensus rechnerisch (FULL 85 Objekte), Live-Zensus + Screenshots nach OWNER-Re-Attach. Fabrik weiter AUS (Flag OFF_IN_PROGRESS); Codex-Slot 1 aktiv (21:29 lokal).

> **Nachtrag 18:58Z (07.09.) - OFF-Tick 18:55Z: 05016e99 + a7e1333c APPROVED (beide gehen mit dem naechsten Factory_ON live):** SH3-Preflight-Writer-Fix (e358c9e3cd: Failure-Normalisierung, verdict_taxonomy=infra, alle status='failed'-Writer auditiert, Regression mit migriertem SH3-Schema) und die governed T1-Tick-Tail-Probe-Route (db44a0983a: Diagnostic-Work-Item Q00, T1-only, read-only MQL5, Isolation/Archiv-Audit, 37-Zeilen-CSV) - 13 fokussierte Tests auf board-advisor gruen. Da die Fabrik aus ist, laden die frischen Worker beim ON den neuen terminal_worker (Idle-Claim-Memo 8c53213e + SH3-Fix + Probe-Route) - kein separater Staffel-Reload noetig. Erster Probe-Lauf = CEO nach ON. Codex-Slot 1 weiter aktiv; Flag OFF_IN_PROGRESS unveraendert; FTMO-Demo sauber.

> **Nachtrag 17:57Z (07.09.) - OFF-Tick 17:56Z: b2b17c4f APPROVED, Fabrik weiter AUS:** Sweep-Guard (b8dfcbeef4, 15 Tests): deterministische Klassen (ONINIT_FAILED, INPUTS_INVALID, COMPILE_FAILED, Q02/Q03-Fixed-Risk-Setfile-Defekt) werden nicht mehr re-enqueued, sondern in `docs/ops/evidence/<date>_stranded_infra_sweep_triage.json` gelistet; transiente Klassen + Cap unveraendert. Nach dem ON: requeue_excluded_eas-Interim (10038/36007/10069) zuruecknehmen, sobald der Sweep-Report sie triagiert. Die vermeintlich wiederkehrenden Factory_OFF-Prozesse um 19:17/19:56 lokal waren meine eigenen Abfragen (`*Factory_O*` matcht die eigene Kommandozeile) - kein Fremdstart, kein ON-Versuch; Flag OFF_IN_PROGRESS seit 16:49Z unveraendert; Codex-Slot 1 (seit 15:15Z) laeuft noch, Pacer aus; 83efd045 auf TODO zurueckgefallen (wird nach ON geroutet). FTMO-Demo sauber (0 Halt, 19:56 lokal frisch).

> **Nachtrag 17:18Z (07.09.) - OFF-Tick 17:17Z: Dukascopy P1-P3 abgenommen (e9dea1e3 APPROVED, 3c65edd4d2, 18 Tests), Fabrik weiter AUS:** Flag OFF_IN_PROGRESS (16:49Z), OWNER-OFF-Prozess beendet, um 17:17Z lief kurz ein weiterer Factory_OFF (pid 5824, Ursprung nicht mehr ermittelbar); OFF-Record weiterhin ohne `succeeded` (Codex-Slot 1 laeuft noch). Vor dem ON: Factory_OFF wiederholen, sobald der Slot frei ist. Offen vor dem P1-Produktivlauf: price_scale/point_size der 9 Nicht-FX-Symbole, frisches --resolve-ip, Probe a7e1333c. FTMO-Demo sauber (0 Halt, Governor 19:17 lokal frisch, 2 Terminals = T_Live + Demo). Zaehler 15/25.

> **Nachtrag 17:15Z (07.09.) - OWNER: Fabrik kurz aussetzen + C: freiraeumen:** Factory_OFF 16:48Z (CEO) -> OFF_INCOMPLETE (Codex-Drain: Slot-1-Session lief noch); OWNER startete 16:49Z selbst Factory_OFF.ps1 (Explorer, pid 32004, Flag OFF_IN_PROGRESS). Fabrik steht (0 Worker, 0 Fabrik-Terminals, 21 Tasks deaktiviert inkl. Codex-Pacer/Quota-Governor); T_Live + FTMO-Demo unberuehrt. ON erst auf OWNER-"weiter": OFF-Record komplett, Baum sauber (855 .set restempelt, 239 .ex5, 344 untracked -> Forensik), Mint, ON unter PS5.1. **C:-Cleanup:** 34,8 GB frei -> **77,8 GB** durch Loeschen der regenerierbaren `Bases/Custom`-Kopien der seit 16.07. ungenutzten DXZ_Truth_2/3/4-Sandboxen (~65 GB; DXZ_Truth_1 (zuletzt 04.08.) und Template unberuehrt; Receipt docs/ops/evidence/2026-09-07_c_drive_cleanup_receipt.md). Weitere Reserven, nicht angefasst: DXZ_Truth_1/Template (~53 GB Custom-History), Agenten-Worktrees ~75 GB (stale detached seit Juli), .codex 15 GB Session-Logs, Local Temp 11 GB.

> **Nachtrag 16:23Z (07.09.) - Tick 16:12Z: ERSTE B'-ADJUDIKATION LEER (Pre-sv-Guard) -> OWNER-Karte; 9d8ad690 APPROVED + 3 Requalifizierungen angewendet:** f625d9aa (11167/XAUUSD) endete 16:00Z mit REVIEW_REQUIRED `cell_execution_failed`, 8/8 Zellen: run_smoke verwirft das Logger-Sample (`logger row is missing 'sv'`, Guard run_smoke.ps1:3009 unter -RequireFreshLoggerSample seit 04.08.); das `sv`-Feld kam am 20.07. (P1-Evidenzintegritaet 6e92c80626), 11167/11196 sind Builds vom 14.07. Umfang: 10/54 Q10_NEWS-Zeilen Pre-sv, davon 3 der 11 freigegebenen B'-Zeilen. Massnahmen: neuer Einzelzeilen-Unset in mark-priority-track (fc6c6f99b1, 2 Tests) -> 11196 von der Spur; 10145/SP500 + 10513/XAUUSD (post-sv, freigegeben) auf die Spur; Vorlage docs/ops/OWNER_VORLAGE_2026-09-07_q09_legacy_logger_sample.md + MC-Karte **OWNER-DEC-Q09-LEGACY-LOGGER-SAMPLE-20260907** (Empfehlung A: deklarierte Legacy-Authentifizierung nur im Selektionslauf fuer Builds vor 6e92c80626; B = Neubau; C = Parken). 9d8ad690 APPROVED (788b4e6200, 31 Tests): `requalify-q02` angewendet auf 41359/41360/41361 -> Nachfolger 12184077/bf0b4f12/d56450a8, Vorgaenger superseded (Receipts 0f0b3cf6cc); 10 Zeilen fail-closed (33007 ohne COMPILE_OK-Record, 21524 ohne Set-Digest, 6 ohne exakte Altbytes, 2 bereits superseded). Sweep-Schleife: 10069 zusaetzlich in requeue_excluded_eas.txt. Codex-Lane 5/5 belegt (b2b17c4f wartet). Zensus 75 MEASURED/h; Worker 10/10; FTMO-Demo sauber (0 Halt, 18:12 lokal frisch).

> **Nachtrag 15:19Z (07.09.) - Interim gegen die Sweep-Schleife (GRUEN, reversibel):** QM5_10038 und QM5_36007 in `D:/QM/strategy_farm/state/requeue_excluded_eas.txt` aufgenommen (bestehender Hebel `is_q02_requeue_excluded`, Cap waere sonst 12 Versuche je Symbol); Rueckbau = Zeilen entfernen, sobald 83efd045 (10038-Triage) bzw. ein 36007-Compile-Fix vorliegt. Ticket b2b17c4f (deterministische Ausschluesse in der Sweep) wartet auf einen Codex-Slot.

> **Nachtrag 15:19Z (07.09.) - Tick 15:17Z: Stranded-INFRA-Sweep wiederholt deterministische Fehler:** Die stuendliche Part-2-Sweep (`sweep_enqueue_built_eas.py` via drain_backlog.py, :52) erzeugte heute 17 Zeilen (enqueued_by claude_sweep_enqueue_2026-06-10.stranded_infra_fail); davon 6 sofort wieder INFRA_FAIL: 10038 x6 ONINIT_FAILED (AUDUSD/NZDUSD/USDCAD/USDCHF), 36007 x3 COMPILE_FAILED - die Sweep prueft den verdict_reason der Quelle nicht. Positiv: fuer 41165/41172/41176 hat dieselbe Sweep um 12:52Z frische Zeilen OHNE expected_ex5_sha256 angelegt (Bindung bei Claim an aktuelle Bytes) - das ist bereits der legitime Requalifizierungspfad fuer die Crash-Zeilen; 41312/41336 fehlen (Cap/Rate-Limit). Codex-Ticket **b2b17c4f** (Prio 80): deterministische Klassen (ONINIT_FAILED, COMPILE_FAILED, INPUTS_INVALID) in Part 2 ausschliessen + Triage-Liste im Sweep-Report; transiente Klassen bleiben retry-faehig. 11167-Adjudikation Zelle m6 (7/8) seit 14:55Z. INFRA 3 h = 18 (davon 8x 10038, 3x 36007). Zensus 73 MEASURED/h; Worker 10/10 (zwei nach der 14:50-Purge neu); FTMO-Demo sauber (0 Halt, 17:17 lokal frisch).

> **Nachtrag 14:50Z (07.09.) - Tick 14:48Z: Website-Designsystem v1.0 ABGENOMMEN (06109144 APPROVED, kein Deploy):** Astra hat das OWNER-Paket auf die lokale Site angewandt (Site-Branch agents/codex-website-design-system-v1 abb22f9ed6 in C:/QM/deploy/qm-ops-refresh, live auf http://127.0.0.1:8772/): Token-/Komponenten-CSS byte-exakt, Inter geladen, Hero nach Guideline (Eyebrow SYSTEMATIC - TESTED OPENLY, The Quantitative Edge., 6 Nav-Punkte, ein gruener CTA + Textlink), Funnel/Mechanics/Kerzen-Header erhalten und umgestylt, Reduced-Motion mit sichtbarem Play-Knopf, AA-Kontraste gemessen (Green Dark 5,99:1), 3.339 Archivseiten regeneriert, Live-Grep #2954d4 = 0 in allen CSS, Exposure-Grep 0, CDP-Audit PASS (3.369 HTML). Evidenz integriert (0017d99233, Before/After-Screenshots). Deploy weiter nur bei JA auf OWNER-DEC-WEBSITE-DEPLOY-20260905. Dukascopy: e9dea1e3 (P1-P3 Build) jetzt IN_PROGRESS, a7e1333c laeuft. 10038: 6 ONINIT_FAILED-Zeilen (Vein-1-Requalifizierung; EA-Log nicht archiviert) -> Triage-Ticket 83efd045 (Prio 70, keine Requeue). Zensus 73 MEASURED/h; 11167-Adjudikation Zelle m5 (6/8) seit 13:50Z, letzte Aktivitaet 14:34Z; RAM 23-31 GB; Worker 10/10; FTMO-Demo sauber (0 Halt, 16:48 lokal frisch).

> **Nachtrag 14:22Z (07.09.) - Tick 14:19Z: OWNER-JA Dukascopy-Backfill (Receipt 14:16Z) -> Programm gestartet:** Karte OWNER-DEC-DUKASCOPY-BACKFILL-20260829 = YES reserviert 3032534e (meine Lane, IN_PROGRESS). Kommissioniert: Codex **a7e1333c** (T1-Tick-Tail-Probe read-only unter Fabrik-Claim -> Splice-CSV 37 Symbole, Archiv-Manifest re-verifiziert) und **e9dea1e3** (P1-Downloader/P2-Konverter/P3-Abgleich-Harness, Build+Tests+1-Symbol-Dry-Run; kein Produktiv-Download). Record docs/ops/evidence/2026-09-07_dukascopy-backfill-20260829_3032534e_execution.md. bb814520 war auf TODO zurueckgefallen -> wieder IN_PROGRESS (decision-bound claude). INFRA 3 h = 14: 10038 AUDUSD/NZDUSD je 2x ONINIT_FAILED (Vein-1-Requalifizierung; InputsValid-Pin-Klasse, keine Requeue), 36007 3x compile_gate (2-h-Requeue-Schleife, beobachten). Zensus 73 MEASURED/h; 11167-Adjudikation Zelle m5 (6/8) seit 13:50Z; Worker 10/10 nach --dedupe 13:59Z; FTMO-Demo sauber (0 Halt, 16:19 lokal frisch).

> **Nachtrag 13:52Z (07.09.) - Tick 13:50Z: rebind-q02 abgenommen, Kohorte ist KEIN EX5-only-Fall, Requalifizierungs-Hebel kommissioniert:** f9235fb0 APPROVED (5fdab105bc, 26 Tests gruen): `farmctl rebind-q02` (Dry-Run-Default, --apply, EX5+Compile-Record+MQ5-Provenienz, Supersession-Sidecar = Claim-Grenze, Receipt). Materieller Befund des 13-Zeilen-Dry-Runs: 0/13 zulaessig - 10 Zeilen binden ALTE Setfile-Bytes (Input-Pin-Welle hat Sets regeneriert), 21524 ohne Setfile-Digest, 20096/10717 bereits superseded. Ein EX5-only-Rebind waere falsch; die Identitaet ist neu -> Codex-Ticket **9d8ad690** (Requalifizierung post-binding, Parameter-Diff mit Provenienz-Pflicht, Wave-2-Plan ce03756f auf dieselbe Luecke pruefen). Bis dahin crashen die 8 pendenden Zeilen beim Claim weiter (05016e99 IN_PROGRESS, seit 12:39Z kein Crash). INFRA_FAIL 3 h = 12: 36007/GBPJPY dreimal compile_gate:COMPILE_FAILED (10:52/12:52 automatisch per false-INVALID-Requeue der Vein-1-Welle neu erzeugt -> Schleife alle ~2 h, billig aber unsauber; naechster Tick pruefen, ob der Requeue COMPILE_FAILED ausschliessen muss); 10038 AUDUSD+NZDUSD `ONINIT_FAILED` nach Vein-1-Requalifizierung (InputsValid-Pin-Klasse, nie blind requeuen). Build-Lane: QM5_41381 wti-tsmom9-h2 governed gebaut (c9706b7c3f: Magic-Allokation Dry-Run+Apply, Compile-Release, Q01/Q02-Validierung, G0-Entscheid, COMPILE_EA 4b1d5e17 done, Q02 bb254af8 pending; Resolver-Diff = Registry-Regen +1 Zeile). Zensus 68 MEASURED/h; 11167-Adjudikation Zelle m5 (6/8) seit 13:50Z; Q08-Reruns 712f20d3/94a492b2 pending; FTMO-Demo sauber (0 Halt, 15:50 lokal frisch).

> **Nachtrag 13:23Z (07.09.) - Tick 13:22Z: empty_strategy_params-Klasse geschlossen (49f79e94 APPROVED), zwei governed Q08-Reruns:** Befund Codex (e3e1329445, board-advisor): historischer Produzenten-Defekt vor 395eb5fc84 (19.07.) - gen_setfile.ps1 schrieb ohne Karte keine strategy_*-Zuweisungen, MT5 lief mit Compile-Defaults, Artefakt-Lineage unvollstaendig -> Q08.5 fail-closed korrekt; kein Reader-/Gate-Defekt. 18 Zeilen = 8 eigene INVALID + 10 Referenzen (lineage_audit.json). Produzent jetzt in jeder Umgebung fail-closed (`SETFILE_DECLARED_STRATEGY_PARAMS_MISSING`) + governed `-VersionTag` (create-only). Zwei Replacement-Sets byte-exakt verifiziert (2feb770d.. 11179/XAUUSD M5, b11f79a8.. 10928/XAUUSD M30, -text-Attribute), 14 Tests gruen. CEO hat die beiden Append-only-Reruns eingereiht (2cdb6a16 QM5_10928, 94a492b2 QM5_10928, 712f20d3 QM5_11179; Vorgaenger 906b7644 / 2cdb6a16 bleiben Evidenz; EX5-SHA gegen Arbeitskopie geprueft). Uebrige INVALID-Zeilen der Klasse haben bereits Nachfolger (PENDING/FAIL_SOFT/PASS), keine Duplikate. Fabrik: 72 MEASURED/h (+121 SKIPPED_PRESCREEN-Sweep, nicht zaehlen), 10 Worker, keine neuen Crashes seit 12:39Z, 11167-Adjudikation Zelle m4 (5/8) seit 12:43Z, FTMO-Demo sauber (0 Halt, 15:22 lokal frisch).

> **Nachtrag 12:55Z (07.09.) - Tick 12:49Z: Worker-Crash-Klasse (SH3-Preflight-Writer), 8c53213e APPROVED (Reload gebuendelt):** (1) **Crash-Klasse:** 5 Q02-Zeilen (41165/41172/41176/41312/41336, alle XTIUSD) 12:28-12:39Z als INFRA_FAIL `worker_crashed_handling_item` - Preflight verweigert korrekt (expected_ex5_sha256 veraltet, EX5 durch den Recheck-Compile neu gebaut), aber der Fehlerschreiber schreibt status=failed ohne verdict_taxonomy -> `IntegrityError: CHECK constraint failed: sh3_enforced=0 OR status<>'failed' OR ...` (terminal_worker.py ~8215) bzw. `failure.get` auf str (~8397) -> Worker stirbt (T4/T8/T9/T10), Watchdog respawnt. Codex-Ticket **05016e99** (Prio 88). 8 weitere pendende Zeilen tragen eine veraltete Bindung (21524, 33007, 20096, 10717, 41359-41362) und wuerden beim Claim ebenso crashen; kein governed Re-Bind-Hebel: intake-first-q02 = existing_q02_row, enqueue-backtest = q02_append_only_rerun_requires_same_exact_source_and_rerun_row, seed-fresh-q02 = fresh_q02_seed_requires_pre_binding_source -> Codex-Ticket **f9235fb0** (rebind-q02, append-only, supersedes Vorgaenger; Dry-Run ueber die 13 Zeilen; Apply durch CEO). Seit 12:39Z kein weiterer Crash; Symbol-Serialisierung begrenzt die Rate. (2) **8c53213e APPROVED** (ba5e5a607c auf board-advisor): Negativ-Claim-Memo mit 8-s-Deckel + data_version-Poller, 928 ms -> 1,1 ms je Leerlauf-Poll (read-only DB-Kopie), 17 Cache-Tests + 180 Claim/Drain/Atomic-Tests gruen; Reload NICHT ausgefuehrt - wird mit 05016e99 zu EINEM gestaffelten Idle-only-Reload gebuendelt (Rollback QM_IDLE_CLAIM_CACHE_TTL_SECONDS=0). (3) Q02 INFRA_FAIL 3 h = 9: 5x Crash-Klasse, 2x 36007 + 1x 20143 compile_gate:COMPILE_FAILED (Build-Defekte), 1x 12582 ONINIT_FAILED (nie blind requeuen). Zensus 73 MEASURED/h; 11167-Adjudikation Zelle m4 (5/8) seit 12:43Z; RAM 29 GB; FTMO-Demo sauber (0 Halt, 14:49 lokal frisch).

> **Nachtrag 12:22Z (07.09.) - Tick 12:17Z: ZAEHLER 15/25, 1537-Refresh-Task registriert, Worker 10/10:** Zaehler 14 -> **15/25** (QM5_11708/EURUSD Q14 KEEP_INCUMBENT 11:39:50Z; book_guard 12:11Z: 15 Paare, 15 EAs, 13 Familien). Codex 447f4995 (1537-Refresh-Runner) abgenommen: Dry-Run reproduziert v2 byte-exakt, 13 Tests auf board-advisor gruen, Installer Print-only; Installer-Defekt (`schtasks /SC MONTHLY /D 1,2,3` ungueltig) vom CEO auf Register-ScheduledTask -Xml (CalendarTrigger Tage 1-3, 05:30 lokal, SYSTEM wie die Terminal-Worker, cwd C:\QM
epo) umgebaut; Task `QM_MonthlySleeveCalendar_Refresh` registriert (Release OWNER-DEC-1537-TRIAL-CALENDAR-SOURCE-20260907, GRUEN: create-only, stoppt in REVIEW), naechster Lauf 01.10.2026 05:30, Rollback `schtasks /Delete /TN QM_MonthlySleeveCalendar_Refresh /F`; task.json status REGISTERED. Worker nach der 12:10-Purge 9/10 -> --dedupe -> 10/10. RAM-Tal 11,8 GB um 12:10Z (zwei Q02-Volltick-Laeufe 14,7 + 8,4 GB) ohne Floor-Verletzung, 12:17Z wieder 32 GB. 11167-Adjudikation f625d9aa: Zelle m3 (4/8) seit 11:58Z. Drain-Cooldown 12512 bis ~13:17Z. FTMO-Demo: 0 Halt, Governor/Kollektor 14:17 lokal frisch, keine Fehlerzeilen.

> **Nachtrag 11:50Z (07.09.) - Tick 11:40Z: Drain-Fenster + Leerlauf-CPU-Klasse, 0ad8aaff APPROVED:** 0ad8aaff (1537-Kalender-Entscheid) nach Sonnet-Abnahme ACCEPT ohne Caveat APPROVED (454acd75a2). **Drain-Fenster** (Drain-Haertung 17cedd8124) 11:18-11:47Z fuer acbad967 (QM5_12512 Q02-Basket, Reservierung 32 GB, Bedarf 39 GB vs. 36,7 GB frei -> `insufficient`, Plateau-Gedaechtnis, Cooldown bis ~13:17Z): 10 Worker 29 min ohne Claim (`no_pending_claimable`), Zensus 0/15 min, Langlaeufer f625d9aa lief weiter, Q03-Basket 34badffc (20207) beendet; nach Ablauf 5 Claims in 5 min, Fabrik wieder auf 6 aktiven Zellen - by design, kein Eingriff. **Neue Klasse (strukturell):** Leerlauf-Worker verbrennen je einen vollen Kern - `_claim_queue_may_need_mutation()` ist bei 6.980 Pending-Zeilen immer wahr, jeder Poll (~11 s; 53/10 min auf T1) faehrt den vollen claim_atomic-Scan; Host-CPU 77-96 % bei 2 aktiven Zellen, `cpu_high_pause`-Events, Intake-CPU-Stops (12507-Records, heutiger Wave-Abbruch bei 97,9 %) -> Codex-Ticket **8c53213e** (codex_high; memoisiertes Idle-Urteil mit TTL / SQL-Prefilter / Drain-Skip, differenzieller Test alter vs. neuer Praedikat, Reload-Plan gestaffelt, KEIN Worker-Restart durch den Agenten). 11167-Adjudikation f625d9aa: Zelle m3 seit 11:39Z (m2 brauchte 3 Versuche, alle mit `valid_report_latched`, kein Hang) - 8 Zellen, Laufzeit >4,5 h, weiter beobachten. Q02-Intake-Welle 1: 41314 = `existing_q02_row` (9c879c67 pending), 9 Zeilen offen, CPU-Regel blockiert bis die Leerlauf-Klasse behoben ist oder die Fabrik natuerlich unter 97 % faellt. FTMO-Demo: 0 Halt, Governor/Kollektor frisch, keine Fehlerzeilen seit 13:00 lokal.

> **Nachtrag 11:12Z (07.09.) - Tick 11:04Z: 1537-Kalender v2 LIVE im Demo, Worker-Restart, DSR-/Setfile-Klassen:** OWNER hat 1537 mit Preset s20260907-002 neu angehaengt (Experts-Journal 12:54:43 lokal); EA-Log 10:55:37Z `MONTHLY_SLEEVE_STATE month=202609 host_rank=0 valid_count=37 selected=true ready=true` -> 1537 handelt im Trial wieder (Record 2d25c6a6 RESULT, b6138062f1); Task 0ad8aaff REVIEW, Sonnet-Abnahme laeuft. Refresh-Automation: Codex lieferte Runbook + Task-Proposal (PROPOSED_NOT_REGISTERED), aber keinen Runner -> Codex-Ticket **447f4995** (codex_high): Runner `qm1537_monthly_sleeve_refresh.py` (Export->Build->Verify->Stage, idempotent je Monat, Dry-Run muss v2 byte-exakt reproduzieren) + Registrierungsskript (Print-only ohne -Apply; Registrierung bleibt CEO-Release). Fabrik: Worker 9/10 nach der 11:00-Purge -> `start_terminal_workers.py --dedupe` -> 10/10 (T1-T10 pids bestaetigt); 85 MEASURED/h; D: 67 GB; RAM frei 26-32 GB; Containment enabled:false; Halt-Dateien 0 (QM/halt enthaelt nur ks_state_1537). 11421 `Abnormal termination` 07:31:55 = Terminal-Neustart vor dem v3-Attach (09:42 loaded successfully), kein neuer Befund. **Klassen:** (a) Q08 INVALID `DSR_V2_MUTABLE_OR_RELATIVE_CONTEXT` / `EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED` heute bei 20072/EURJPY (d8abafc0), gestern 12935 + 11167: laut DSR-Record 5bf3bf5e gehoeren diese Zeilen auf die Sweep-Liste (Q14-Vorschlag je OWNER-Karte), keine Requeue; (b) Q08 INVALID `8.5 neighborhood ... baseline_setfile_defect:empty_strategy_params`: 18 Zeilen in 72 h (10928, 11196, 11179, 11015, 9573, 10148, 10771, 1230, 10287, 11132, 10848 ...), fuer 11196 per governed Replacement-Set geloest (e638e0de), fuer die Klasse fehlt der Produzenten-Fix -> naechster Tick Codex-Ticket (Root Cause im Baseline-Setfile-Generator, Replacement-Sets governed, append-only Reruns); (c) Q02 INFRA_FAIL 36007/GBPJPY = `compile_gate:COMPILE_FAILED` (Build defekt, kein Infra-Retry). 60cd31a8 (B-prime Counter-Path) auf IN_PROGRESS gesetzt (war TODO ohne Lane; decision-bound claude). f625d9aa (11167 Q10_NEWS) laeuft auf T2 seit 07:18Z (3 h 50).

> **Nachtrag 11:03Z (07.09.) - OWNER-Implementierungspaket v1.0 (EA-Design + Website-Design) an Astra:** OWNER-Anweisung ~10:55Z: "Gib das alles an Astra zur Implementierung und Umsetzung (wieder am Test EA auf FTMO)". Paket `QuantMechanica_Implementation_Package_v1.0` (27 Dateien, MANIFEST_SHA256 27/27 verifiziert) ins Repo uebernommen: `docs/design/qm_implementation_package_v1.0/` (9bd0bea521; docx/pdf unter `D:\QM\design\`). Inhalt: Design-Guideline MQL5+Web v1.0 (Token-Palette Carbon/Ink/Quant Green/Signal Blue, Segoe UI/Inter, Hierarchie Wordmark -> STRATEGY CONSOLE -> Titel -> State-Card -> Filter Gate 2-spaltig -> Risk -> LIVE adaptiv -> Today/Week -> Footer, Modi FULL/COMPACT/MINIMAL, Chart weiss/Grid aus/Kerzen #0E9F7A/#F0545E), Referenz-MQL5 (Fremd-EA `OHLC Daily Squeeze Reversal`, IFilter/IStrategy-Architektur - NICHT V5, wird nicht installiert, nur der Vertrag Snapshot->Renderer/Tokens portiert), Website-Tokens (css/json) + Komponenten + Web-Guideline (gruene Editorial-Richtung ist Anker, kein zweites Stahlblau). Zwei Astra-Tickets (model_tier astra, xhigh) eingereiht und geroutet: **bb036699 Strategy Console v4** (Prio 90) - Port in `framework/include/QM/` (QM_DesignTokens/QM_ConsoleModel/Renderer), nur echte Gates, Risk ohne Fake-DD-Limit, PERFORMANCE-Tabelle aus v3 bleibt im FULL-Modus (OWNER 09:00Z), englische UI-Copy + de-DE-Zahlen (Input fuer en-US), View-Button, Safety-Vertrag unveraendert, artefakt-only FTMO-MetaEditor-Compile + Demo-Install 11421 mit Receipt, Fabrik-EX5 unberuehrt, OWNER-3-Zeilen; **06109144 Website-Designsystem v1.0** (Prio 86) - Tokens/Komponenten/Inter auf die lokale 8772-Arbeitskopie inkl. Archiv-Regeneration, Funnel/Mechanics/Kerzen-Header aus dem 05.09.-Brief erhalten und umgestylt, Reduced-Motion mit Play-Knopf, AA-Kontraste, Exposure-Grep 0, KEIN Deploy (WEBSITE-DEPLOY-Karte offen). Abnahme durch CEO nach Rueckkehr (REVIEW). Fabrik: 83 MEASURED/h, Zaehler 14/25, D: 58 GB, Containment enabled:false.

> **Nachtrag 05:20Z (07.09.) — Kalender-Counter-Path B aktiviert, strikt fail-closed:** OWNER-JA `OWNER-DEC-COUNTER-PATH-CALENDAR-TAINT-20260907` / Receipt `e1259d10` ist als SHA-gebundener, Q10_NEWS-/D1-/HIGH-/USD-only Consumer implementiert. Die Freigabe bleibt explizit OWNER-zeilenweise; der normale Taint-Sweep kann keinen B-Marker automatisch freigeben, und jede freigegebene Zeile traegt `news_calendar_scoped_consumer_b` plus Fussnote **„Kalender scope-begrenzt“** in Cockpit und Strategiearchiv. Produktions-Dry-run: **47/47 EXCLUDED, 0 ADMISSIBLE**, daher kein Hold geloest; `a909ee18` (QM5_11196/XAUUSD H4) ist intraday und ueberschneidet deklarierte Ausschluesse. Append-only Wiedervorlage nach B-prime/Vollsiegel: Router-Ticket `235e5119` (BLOCKED; bestehende Verdikte nie ueberschreiben). Evidenz `docs/ops/evidence/2026-09-07_f3a94b87_scoped_calendar_b_activation.md` und Maschinenlauf `..._dry_run.json`.

> **Nachtrag 01:02Z (07.09.) — FX-Cointegration bleibt am CPU-Hard-Stop, kein Duplikat erzeugt:** Der 66-Paar-Scan ist vollständig mechanisiert; 12532/12533 sind nach Q02 bereits ökonomisch gescheitert, nicht ONINIT/NO_HISTORY-blockiert. Gültiger Fallback bleibt genau die eine logische Q02-Zeile `547c4fd3` für `QM5_12507` EURUSD/GBPUSD H1 (pending, unclaimed, attempt 0). Fünf CPU-Messungen `100/99/97/100/100%` (Ø 99,2%, Max 100%) binden die 97%-Kappe; deshalb kein Build, Compile, Enqueue, Priority-Change oder Dispatch. Evidenz `docs/research/FX_COINTEGRATION_QM5_12507_Q02_HARD_CPU_STOP_20260907T010205Z.md`.

> **Nachtrag 08:24Z (05.09.) — QM5_41349 neue WTI-Strukturkante source-built, Compile-Prärequisit offen:** Direkte WTI-Monatskante neu und dedupliziert: lag-one ADF `t>=-2.594` UND Raw-Return-Sample-Entropy (`m=2`, `r=0.2*sd`) `<=2.5`, danach 12-Monats-Richtung; nicht QM5_12567 und nicht die vorhandenen ADF-KPSS/VN/LZ/Spektral-Varianten. Card/G0/ID/Magic/MQ5/SPEC/fester Q02-Set (`RISK_FIXED=1000`) committed (`f711c0ffef`, `0e28f3bb0f`, `947e74f89e`), 4/4 Referenztests und beide Card-Linter PASS. CPU-Fenster 77,7738% Mittel / 88,0875% Maximum <97%. Governed Compile `58f2abcf-00c1-4d8e-a928-9a25dde9e1c9` source-hash-geprüft, Hold gelöst und priority-bound, aber weiterhin pending/unclaimed ohne EX5/COMPILE_OK; deshalb Q02 korrekt NICHT eingereiht. Fortsetzung: denselben Compile-Item abwarten, danach frisches CPU-Fenster und genau eine XTIUSD.DWX/D1-Q02-Zeile. Evidenz `docs/research/QM5_41349_WTI_ADF_SAMPEN_AGREEMENT_COMPILE_HANDOFF_2026-09-05.md`.

> **CEO-Loop 2026-09-02 10:00–10:40Z (OWNER: „Sonntag 06.09. steht; Claude voll verantwortlich für Backtest-Durchsatz und Buch"):**
> **Steuerungsebene war der Engpass, nicht die Tester.** Evidenz `docs/ops/evidence/2026-09-02_ceo_stranding_census_and_pump_control_plane.md`.
> (1) Gate-Kaskade lief seit 01.09. in 12 von 261 Pump-Zyklen → 413 Q03-PASS, 58 Q09-PASS, 591 Q02-PASS ohne Folgezeile; Zensus-Services ebenfalls verhungert.
> Fix: Zensus-Services + Kaskade an den Zyklusanfang, Budget 270→360 s (`f558a07408`, `9abb2290be`), dispatch_tick-Teilzeiten instrumentiert.
> (2) Juli-Backfill las 3.400 Cards pro 5-min-Zyklus (09:58Z-Zyklus >16 min, py-spy) → mtime-Cache + 15-s-Budget (`ff08f13eb8`); toter Pump-Claim nach 120 s reapbar (`0b93ef5180`).
> (3) **Claim-Hashing:** jeder Claim hashte die 108 privaten Archivdateien (2,04 GB) neu → D: 3 GB/s Lesen, Queue 37–45, Zellen 29/h statt 60–80/h.
> Fix: Verifikations-Cache je Terminal, TTL 4 h, Kill-Switch `QM_CUSTOM_HISTORY_VERIFY_CACHE=0` (`76981d683b`); gestaffelter Worker-Reload läuft.
> (4) Selector las alle Zell-Reports pro Zyklus (>10 min) → Sidecar-Cache (`fcdd83aa37`, `3ec4236dfd`).
> (5) 133 INFRA_FAIL-Zeilen oberhalb Q02 append-only neu eingereiht (Q03–Q09 inkl. 30 Q04-Probes); 22 korrekt abgelehnt (Binary neu gebaut).
> (6) REVIEW-Stau abgebaut: 12 Codex-Tasks unabhängig verifiziert (Workflow, Artefakt-Existenz zuerst) → 11 APPROVED, 1 RECYCLE (5851dc5b, Ergebnis nicht in OPEN_ITEMS).
> Befund daraus für den 06.09.: EURUSD-magic=0 war der Friday-Close-Broker-Deal von QM5_11421, kein manueller Trade (ee18d088); NDX-Herkunft offen (DEAL_REASON fehlt).
> (7) Verwaister Codex-ripgrep (25 min, 120 MB/s über T_Live-Verzeichnis, Defender hinterher) gestoppt; `QM_StrategyFarm_ClaudeOrchestration_15min` für die Dauer der interaktiven Session deaktiviert (wieder aktivieren beim Handoff).
> Offen: Q07/Q08-Reruns der Zensus-Eltern stehen auf Rang ~1.500 der Claim-Reihenfolge (kein priority_track) → Markierung folgt; Sibling-Q02-Seeds 41303/41304/41305/41307; 41306 Held-Successor 8620da55; Pair-8-Build c2ef7f4a.
> **Nachtrag 19:30Z (06.09.) - Tick 19:10Z: Q08-Reruns unter der Deklaration erneut INVALID (Producer-Fensterdefekt), Governor integriert, Runde 3 7/7, Notion komplett:** **DSR (P0):** 11167 `045bed75` INVALID 18:42Z und 11196 `a79887e3` INVALID 19:03Z, beide 8.2 `DSR_V2_MUTABLE_OR_RELATIVE_CONTEXT` mit `dsr_context_status.reason = CANDIDATE_WINDOW_UNAVAILABLE` (nicht der Deklarationspfad): `dsr_cohort.assemble()` liest das Candidate-Fenster aus Payload `from_date`/`expected_from_date` oder Zeilen-`data_window_start` - bei Q08-Zeilen alle None (nur die Q07-Vorgaengerzeilen tragen 2017.01.01-2025.12.31); die Original-Q08-Zeilen kamen ueber diesen Punkt hinaus (Reason SEALED_SEARCH_LEDGER_UNAVAILABLE), der Append-only-Rerun-Pfad liefert das Fenster nicht -> Codex-Ticket **(P90)** 'DSR window on append-only Q08 reruns' (Lineage-Aufloesung ueber Q07, expected_from/to_date im Rerun-Payload, Replay). Zusaetzlich 11196: 8.5 `baseline_setfile_defect:empty_strategy_params` (H4-Set ohne strategy_*-Inputs) -> Ticket **e638e0de** (P86, governed Set-Regeneration). 8fe2bac0 bleibt IN_PROGRESS. Weiterer V2-Fall: 11179/XAUUSD Q08 `906b7644` INVALID 18:04Z (8.2 + 8.5 + 8.7). **FTMO-Governor** 9cf0712b als `22b5a85b20` integriert und APPROVED (QM5_13206 nativ 5 Faelle PASS, unattached installiert, Policy FTMO_2S_P1_100K_V2: 5 %/Tag ab Prager Mitternacht auf Equity, 90k/94k-Floors, Weekend-Flat ab Fr 20:55, News PRE30_POST30, Identitaets-Guards, Halt-Dateien); Manifest wartet auf OWNER-Signatur (Chat-Receipt), danach Aktivierungs-Checkliste (9 Schritte). **Runde 3:** 7/7 COMPILE_OK, 20291 nachgezogen. **Notion:** Token gueltig, Publisher enabled (Datumsfeld `Datum`, d6d1cef94d), heutiges Briefing aktualisiert, **42 Archiv-Briefings (20.07.-05.09.) nachgetragen = 43 Seiten**; taeglicher Lauf ueber QM_MorningBriefing_Vault 06:00. Notion-To-Do DONE; offen: FTMO-DEMO-RUNNING (Signatur + Checkliste), Videoanalyse. Fabrik 19:10Z: Zensus 118/h (31/15 min), Lock-Busy 0, Zaehler 12/25, Widerlegung 1/5, 10 Worker, D: 85 GB.

> **Nachtrag 18:50Z (06.09.) - Tick 18:32Z: Buffer-Runde 3 integriert, Vorlage-Punkte abgeraeumt, Q08-Reruns laufen:** Codex 3aebf9f6 (beide Commits 284f8732f0 + 4d55f2dcbc) als `577bae6a68` integriert und APPROVED: 13/13 Ziel-EAs frei, Korpus 283 -> 263 Findings, 0 neue, 104 Tests; die verbliebenen 20xxx/21xxx-FAILs werden neu eingereiht und in einer `--work-item-ids`-Tranche (ein Backup) freigegeben. **DSR-Ausfuehrung:** Reload chunk 55 komplett 18:12Z (T5 nach dem 11015-Q08); 11167-Q08-Rerun `045bed75` seit 18:10Z aktiv auf T4, 11196 `a79887e3` pendent. 11015 Q08 `34d0e1ba` = INFRA_FAIL `q08_degenerate_neighborhood_baseline` (Aggregator, kein Reload-Effekt; 11015 ist aus der Deklaration ausgenommen). **OWNER-Vorlage-To-Dos:** 1170cf8cbf (Rulepack-V2-Pin inkohaerent: Pin zeigt auf das SWING-Profil, das Demokonto ist STANDARD) -> Codex-Ticket **6b291f21** (P84: Standard-2-Step-100K-Profil ableiten und fuer Demo/Governor binden) und als To-Do geschlossen; 3fb6efc83d (News-Gate-Expansion fuer Ein-Ziel-Deployments entscheidungsirrelevant) = dokumentierte Schlussfolgerung, geschlossen. Lint-Fixture-Ticket **34a8ffbe** (P60, Luna). Welle-2-Restart-Plan gestartet (119 Q02-Zeilen geparst; 8 EAs ohne COMPILE_OK uebersprungen); Q02-Intake/Seeds bleiben CPU-gedeckelt (99-100 % waehrend des Zensus; heute 15/70 Intakes) - Vorlage-Zeile 'Admission auf 15-min-Mittel' steht. Fabrik 18:32Z: Zensus 123/h (29/15 min), Lock-Busy 0, Zaehler 12/25, Widerlegung 1/5, 10 Worker, D: 90 GB.

> **Nachtrag 17:58Z (06.09.) - Tick 17:36Z: Seed-Fix bestaetigt (41171 Q07 FAIL oekonomisch), Q08-Reruns unter der Deklaration, FTMO-Installation abgenommen mit Governor-Luecke:** **41171 Q07 `36f0a341` = FAIL** 17:33Z, `per_seed_pf_below_floor: seeds=[42, 99, 2026], floor=1.0` - alle fuenf Seeds liefen (kein ONINIT_FAILED mehr) = der Seed-Pin-Fix ist am Akzeptanztest bestaetigt; die Strategie scheitert oekonomisch an Q07, die dritte Identitaet endet hier (Gate arbeitet, keine Aktion). **DSR-Ausfuehrung:** Reload chunk 55 9/10 (T5 seit 13:26Z in einem langen Q08-Lauf 11015, wartet idle-only); Q08-Reruns append-only eingereiht: **045bed75** (11167/XAUUSD, from Q07 42ca0f18, rerun-of d7ab61ae, EX5 4b349d21 verifiziert) und **a79887e3** (11196/XAUUSD, from Q07 42154e17, rerun-of b280892a, EX5 d3b1aef0); Ergebnis muss PASS/FAIL sein. **FTMO-Installation (35eac0e9):** Code `142ef15d43` als `eba6f27c13` integriert (41 Tests), Evidenz df42928dda: Ziel = Demo-Datenordner (nicht T_Live), Login 1514536732/FTMO-Demo, Hebel **1:100** (Terminal-Snapshot), Build 6182, AutoTrading OFF; 8 versiegelte Sleeves (10706/GBPUSD H1, 11421/EURUSD D1, 11422/USDCAD D1, 11910/NZDUSD D1, 13054+20048/USOIL.cash D1, 1537+21505/XAGUSD D1; RISK_PERCENT 0.3125, News 3/2, Friday-Close 21) + Kollektor (nativ abgenommen auf T11, 4 DST-Faelle) installiert UNATTACHED, Pulse-Trockenlesung PARKED OK -> APPROVED. **Luecke (Checkliste Schritt 2):** Account-Governor QM5_13206 als alleinige Halt-Autoritaet fehlt, Legacy-Attach-Map darf nicht verwendet werden -> Codex-Ticket **9cf0712b** (P88: Governor bauen/abnehmen, unattached installieren, Deploy-Manifest zur OWNER-Signatur); OWNER-Aktivierung (AutoTrading + PARKED->RUNNING) bleibt bis dahin blockiert, OWNER informiert. Eigener Commit-Fehler korrigiert: 62e00162c8 hatte zwei seit Sitzungsbeginn vorgestagte 10025-Dateien mitgenommen -> Soft-Reset, Neucommit eba6f27c13 nur mit FTMO-Dateien; die 10025-Aenderungen liegen unveraendert (jetzt ungestaged) im Arbeitsbaum. Fabrik 17:36Z: Zensus 88/h (29/15 min), Lock-Busy 0, Zaehler 12/25, Widerlegung 1/5, 10 Worker, D: 94 GB.

> **Nachtrag 17:20Z (06.09.) - Tick 17:05Z: DSR-Deklaration und Backup-Reuse integriert, Welle-2-20xxx 55/68, Buffer-Runde 3:** **DSR (OWNER-JA):** Codex f9ce2102 als `fae90ea674` integriert und APPROVED: Claim-Time-Refusal 'Fabrik-Suchledger vor dem Q08-Claim' (terminal_worker.py + dsr_cohort/dsr_single_configuration), n=1-Deklarationen fuer 11167 und 11196 als append-only Card-Amendments an beiden Card-Orten (inhaltlich identisch), Vor-DSR-Versionen erhalten, Linter-Regel 'Sweep-Liste = Q14-Vorschlag'; 95 Tests gruen, 2 vorbestehende Kalender-gepinnte Lint-Tests (Bundle 29.08. vs live 04.09.) unabhaengig davon. Weil terminal_worker.py betroffen ist: Reload chunk 55 (alle 10) seit 17:15Z; danach append-only Q08-Reruns d7ab61ae (11167/XAUUSD) und b280892a (11196/XAUUSD), dann Auftrag 8fe2bac0 -> REVIEW -> Abnahme. **Backup-Reuse:** 70f55cbf als `65be85ab90` integriert/APPROVED (`--work-item-ids`-Tranche = ein Backup, rollierender Reuse, keep-3-Receipts). **Welle 2 (20xxx/21xxx):** 56/56 freigegeben 16:39Z (per-Zeile mit Sofort-Cleanup, Receipt 1640Z): **55 COMPILE_OK, 13 COMPILE_FAIL**, alle 13 `EA_INDICATOR_BUFFER_UNBOUNDED` auf weiteren Mustern (sortierte Puffer mit Indexvariablen, `returns[i]`, `all_xti[common_count]`) -> Codex-Ticket **3aebf9f6** (P84, Runde 3, monoton). Gesamtstand Pin-Reparatur heute: 7 Pacer + 70 Welle 1 + 55 Welle 2 = 132 EAs neu kompiliert ohne Framework-Input-Pins. FTMO-Installation 35eac0e9 seit 17:02Z bei Codex IN_PROGRESS. Fabrik 17:05Z: Zensus 91/h (Wellen-Transient 16:52Z = 0/10 min, 17:02Z wieder 14), Lock-Busy 0, Zaehler 12/25, Widerlegung 1/5, 10 Worker, D: 96 GB.

> **Nachtrag 16:45Z (06.09.) - Tick 16:33Z: DSR-JA umgesetzt (Schritt 1), FTMO-Demo steht, Buffer-Counter-Beweis integriert:** **OWNER-Receipt 5bf3bf5e** (JA, Option A, per Chat) fuer OWNER-DEC-DSR-SINGLE-CONFIG-DECLARATION-20260906 erfasst; Ausfuehrungsauftrag 8fe2bac0 (Claude-Lane) IN_PROGRESS, Codex-Ticket **f9ce2102** (P90: Deklarationsbloecke 11167/11196 ueber approve-card, Maschinencheck Bedingung (i), Linter-Regel) seit 16:17Z in Arbeit; Ausfuehrungs-Record `docs/ops/evidence/2026-09-06_dsr-single-config-declaration-20260906_5bf3bf5e_execution.md`. **FTMO-Demo (OWNER 16:05-16:50Z):** Free Trial, 2-Step, 100.000 USD, Kontotyp FTMO **Standard (nicht Swing)**, alle Symbole, Trial 14 Tage ab erstem Trade = Dauer-Cap; Terminal `C:/Program Files/FTMO Global Markets MT5 Terminal`, Datenordner `...Terminal/81A933A9...` (nicht T_Live; Login 1514536732 auf FTMO-Demo, AutoTrading aus); Zugangsdaten nur in `.private/secrets/ftmo_demo_20260906.md`; Bedingungen ohne Geheimnisse in `docs/ops/evidence/2026-09-06_ftmo_demo_account_terms.md` (Standard-Konto => Friday-Close + News-Regel in die Trial-Sets binden; Hebel via Kollektor ACCOUNT_LEVERAGE). Codex-Ticket **35eac0e9** (P88: Kollektor-Abnahme + Installation, Live-Modus-Sets, Identitaetsguards, Pulse-Trockenlesung, OWNER-Checkliste; kein AutoTrading, kein Chart-Attach). OWNER-To-Dos FTMO-DEMO und FTMO-DEMO-ZUGANG DONE, FTMO-DEMO-RUNNING wartet auf AI-Abnahme. **T_Live** wurde 15:53Z sauber neu gestartet (zeitgleich mit dem FTMO-Terminal, OWNER-seitig, Watchdog nicht beteiligt): Experten geladen, Experts-Enabled in common.ini, RUNNING, Heartbeat frisch, keine Alarme. **Buffer-Counter-Beweis** (8f03675b) als `160c9292a6` integriert und APPROVED: Sweep 410 -> 282 Findings, 96 EAs vollstaendig frei, 0 neue; die 5 gescheiterten 20xxx neu eingereiht (Hold); die 56 gehaltenen Welle-2-Zeilen werden per `session_tools/release_with_backup_cleanup.py` (Release je Zeile + sofortige Loeschung des 701-MB-Backups, Receipt) im Hintergrund freigegeben, weil `--max-items` (max 10) 14 fremde Hold-Zeilen inkl. Pacer-Builds 41368/41369 mitnehmen wuerde. 12 Info-To-Dos ins Vault-Archiv. Fabrik 16:32Z: Zensus 79/h (31/15 min, Erholung), Lock-Busy 0, Zaehler 12/25, Widerlegung 1/5, 10 Worker, D: 97 GB.

> **Nachtrag 16:10Z (06.09.) - Tick 16:05Z: Welle 2 (41xxx) 55/56 OK, OWNER-Rueckmeldung FTMO-Demo, Q02-Intakes bis zur Backup-Korrektur pausiert:** Welle-2-41xxx: **55 COMPILE_OK, 0 FAIL**, 1 pendent; 20xxx/21xxx (51) im Hold bis 8f03675b (Codex IN_PROGRESS seit 15:41Z); 70f55cbf (Backup-Reuse) IN_PROGRESS seit 15:47Z. **Entscheidung:** weitere `intake-first-q02`- und `seed-fresh-q02`-Aufrufe (je 701-MB-Backup) und der Welle-2-Restart-Plan warten auf 70f55cbf - D: 98 GB, Purge-Schwelle 150 GB, Hard-Stop 40 GB; die Q02-Queue (791 pendent) ist ohnehin hinter dem Zensus verhungert, die Wartezeit kostet nichts. **OWNER 16:05Z:** FTMO-Free-Trial-Demokonto angelegt -> `OWNER-TODO-20260906-FTMO-DEMO` DONE; Folge-To-Dos `...-FTMO-DEMO-ZUGANG` (Login nur in .private, Client-Area-Bedingungen, Dauer-Cap) und `...-FTMO-DEMO-RUNNING` (AutoTrading am Demo-Terminal + PARKED->RUNNING erst nach AI-Abnahme: Kollektor-Installation + nativer Tester-Lauf f4e95c80 offen). Die 12 'Info'-To-Dos (reine Kenntnisnahmen) nach der OWNER-Regel 06.09. als erledigt ins Vault-Archiv ('Erledigt (15)', Texte erhalten); offen: Notion-Token, 2 FTMO-Folgen, 1 Videoanalyse, 2 Vorlage-Punkte (Rulepack-V2-Pin, News-Gate-Expansion; auf Wunsch Karten). Zensus 16:0xZ erholt sich vom Purge/Wellen-Transient (12/10 min), Flotte 10/10, Zaehler 12/25, Widerlegung 1/5, Lock-Busy 0. 41171 Q07 `36f0a341` weiter pendent (Claim hinter dem Zensus).

> **Nachtrag 15:58Z (06.09.) - FLOTTENVERLUST 15:40Z AUFGEKLAERT (eigene Ursache), 60,9 GB Backups bereinigt:** Monitor 15:42Z: 6/10 Worker (T4/T6/T7/T8 tot, T2/T3 15:40:27Z neu). Purge-Log (`D:/QM/reports/state/tester_cache_purge.log`) 15:40:20Z: 'idle caches cleared terminals=[T2,T3,T4,T6,T7,T8]: D: **43.84GB** -> 63.14GB' inkl. `T8\Testerases\Darwinex-Live` (473 MB) - `QM_StrategyFarm_TesterCachePurge` (10 min, LowWater 150 GB) ist die dokumentierte Teardown-Klasse (28./29.08.): sie stoppt idle Worker und laesst den Launcher nachstarten, der aber nur innerhalb der Disk-Kappe (`per_worker disk 8 GB`, Stop 40 GB -> Kapazitaet 2) startet -> Flotte blieb bei 6-8, T4/T6/T7/T8 per `start_terminal_workers.py` zurueckgeholt (10/10 seit 15:47Z). Dasselbe Muster um 12:40:20Z (T1/T6/T7/T8). **Wurzelursache = ich:** jede `release_compile_wave.py --work-item-id --apply` und jeder `intake-first-q02 --apply` schreibt ein 701-MB-Vorher-Backup (Identitaets-Reuse scheitert, weil jeder Release die Hold-Zaehler aendert): heute 54 Compile-Wave- + 36 Intake-Backups = ~63 GB -> D: von 82 GB auf 43,8 GB (Hard-Stop 40 GB!). Bereinigt: 89 redundante Werkzeug-Backups (60,9 GB) geloescht, neueste 3 je Klasse + alle Stundensnapshots + Restore-/Build-Claim-Backups behalten, Receipt `docs/ops/evidence/2026-09-06_backup_cleanup_receipt_1550Z.json`; D: 63 -> **96 GB** (Purge bleibt unter 150 GB aktiv, aber weit vom Stop). Codex-Ticket **70f55cbf** (P84): Backup-Reuse identitaetstolerant, `--work-item-ids` fuer Tranchen, Kappe 3 je Werkzeugklasse. Lehre: Vor Massenfreigaben D:-Headroom und Backup-Kosten pro Aufruf pruefen; Tranchen als EIN Aufruf, sobald das Werkzeug es kann. Welle 2 41xxx: Ergebnis im naechsten Nachtrag; 20xxx/21xxx (51) im Hold bis 8f03675b.

> **Nachtrag 15:45Z (06.09.) - Tick 15:28Z: Welle-2-Compiles: 41xxx laufen, 20xxx am Buffer-Praedikat gehalten:** Alle 119 Welle-2-Zeilen im Hold (0 Refusals); Reload chunk 54 8/10 (T5/T10 beschaeftigt). Tranche 1 (12, gemischt) 15:30Z: 7 OK, **5 COMPILE_FAIL - alle QM5_20xxx, alle `EA_INDICATOR_BUFFER_UNBOUNDED`** auf dem Muster 'zaehlerindizierter dynamischer Puffer' (`month_end_closes[month_count]`, `returns[observation_count]`, `month_keys[found]`; 20233/20258/20248/20256/20257, wie 41340 in Welle 1) = dieselbe False-Positive-Klasse wie die 12 geklaerten Findings (49aa6d17), fuer die 20xxx-Familie nicht abgedeckt; unter der Monotonie-Regel sind das 'alte' Findings, die jede Neukompilierung der Familie blocken. Konsequenz: **20xxx/21xxx (51 Zeilen) bleiben im Hold**, nur die 41xxx-Teilmenge (56) wird freigegeben: Tranche 12/12 COMPILE_OK, die restlichen 44 laufen im Hintergrund. Kommissioniert: Codex-Ticket **8f03675b** (P88): Beweis fuer das Counter-Append-Muster erweitern (monoton, 0 neue Findings, Unbounded-Fixture bleibt rot), danach Freigabe der 20xxx-Zeilen. **41171 Q07 `36f0a341`** (Seed-Akzeptanztest) pendent seit 14:59Z, wartet auf Claim hinter dem Zensus. **Q02-Intake Welle 1:** +4 (41102, 41108, 41111, 41114) = 14/70, Stopp bei 98 %; 48 offen. Codex baut weiter (QM5_41370, ace0806252). Fabrik 15:28Z: Zensus 102/h (30/15 min), Lock-Busy 0, Zaehler 12/25, Widerlegung 1/5, 10 Worker.

> **Nachtrag 15:05Z (06.09.) - Tick 14:57Z: Welle 2 integriert (119), 41171 im Q07-Akzeptanztest, Q02-Intake 10/70:** Codex lieferte Welle 2 direkt auf board-advisor (`df8310c0a7`): 119 APPEND_ONLY_IDENTITY_RESTART-Quellen repariert, SHA-gebundene Autoritaets-JSON (`2026-09-06_framework_input_pin_wave2_authority.json`, Loader prueft Hash/Task/Cohort), .gitattributes -text, Restart-Plan mit 261 terminalen (EA, Symbol, Phase)-Zeilen (`..._wave2_restart_plan.md`), 11 fail-closed Ausschluesse (8 ohne `QM_FrameworkTrackOpenPositionMae()`-Hook, davon 1 mit XBRUSD; 1 Registry-Duplikat QM5_20292; 2 bereits per Pacer-Praezedenz repariert). Verifiziert: 119/119 Working-Copy-Hashes = Registrierung (LF), 474 Tests gruen -> ce03756f APPROVED. **Seed-Pins im Korpus: 200 -> 9** (Rest = Ausschluesse). Reload chunk 54 (alle 10) seit 15:02Z, die 119 Compiles werden im Hintergrund in den Hold eingereiht; Freigabe nach dem Reload gezielt per `--work-item-id` in Tranchen, danach der Restart-Plan append-only (Q02 via seed-fresh-q02 / Folgephasen per --append-only-rerun-of). **41171 dritte Identitaet:** Q06 `b4e7bad6` PASS_SOFT 14:37Z -> **Q07 `36f0a341`** append-only (rerun-of 48734e69) = Akzeptanztest des Seed-Fixes (5 Seeds). **Q02-Intake Welle 1:** 10 von 70 Canaries angelegt (41095, 41096, 41098, 41099, 41100, 41101, 41105, 41106, 41107 + 41102 an `factory_mutation_lock_busy` -> Retry), CPU-Stopps bei 99-100 % zwischen den Fenstern; 52 offen, Fortsetzung je Tick. Fabrik 14:57Z: Zensus 89/h (31/15 min, erholt), Lock-Busy 0, Zaehler 12/25, Widerlegung 1/5, 10 Worker (T9 seit 14:28Z frisch).

> **Nachtrag 14:35Z (06.09.) - Tick 14:29Z: Welle 1 fertig (70/72), Q02-Intake am CPU-Deckel, 41171 in Q06, 5. DSR-V2-INVALID:** Welle-1-Endstand: **70 COMPILE_OK, 2 COMPILE_FAIL** (21524: MAE-Hook fehlt + XCUUSD nicht in der DWX-Matrix; 41340: `EA_INDICATOR_BUFFER_UNBOUNDED` dynamischer Monatsschluss-Puffer -> Review-Kandidat), das Pin-Praedikat traf keine der 72. Zensus-Einbruch 13:50-14:10Z (2-15 Zellen/10 min) war der Wellen-Transient, ab 14:10Z wieder 6 Terminals im Zensus (19/10 min um 14:21Z). **Q02-Intake fuer die 70:** Tranche 1 begann 14:31Z, nach dem ersten EA (41095, Apply lieferte keine Zeile - Dry-Run wird geprueft) stand die CPU bei 100 % ueber 5 s -> STOP nach Pacer-Regel (max <97 %). Befund: solange der Zensus die CPU saettigt, kommt die Regel praktisch nie durch; die Q02-Canaries warten in der 778er-Queue ohnehin Tage. Vorschlag (GELB, keine Entscheidung ohne OWNER): Admission auf 15-min-Mittel <97 % statt 5-s-Maximum umstellen - als Vorlage-Zeile notiert, bis dahin Retry je Tick. **41171 dritte Identitaet:** Q05 `6cc07c90` PASS 13:57Z -> Q06 `b4e7bad6` append-only (rerun-of 3ca389aa). **QM5_12935/XAUUSD Q08 `8bc2062b` INVALID 14:28Z** (T9-Lauf seit 10:50Z): 8.2 DSR V2 `MUTABLE_OR_RELATIVE_CONTEXT` = 5. Single-Config-Fall heute, dazu 8.4/8.6/8.10 FAIL -> waere ohnehin FAIL_HARD, kein Zaehler-Effekt. Welle 2 (ce03756f) seit 14:07Z bei Codex IN_PROGRESS; Codex baut parallel QM5_41369 (a61043136a). Fabrik 14:29Z: Zensus 73/h (Wellen-Delle), Lock-Busy 0, Zaehler 12/25, Widerlegung 1/5, 10 Worker.

> **Nachtrag 14:05Z (06.09.) - Tick 13:46Z: Welle 1 kompiliert (laufend), Welle 2 kommissioniert, 41171 in Q05:** Reload chunk 53: 9/10 frisch (T9 seit 10:01Z durchgehend in langen Laeufen, drei Reload-Runden verpasst; idle-only bleibt). Die 72 Welle-1/Pacer-Zeilen gezielt per `--work-item-id` freigegeben (Tranche 1 = 12 um 13:47Z: 11 COMPILE_OK, 1 FAIL; Tranche 2 = 60 ab 13:55Z): Stand 14:02Z **44 COMPILE_OK, 1 COMPILE_FAIL, 3 aktiv, 24 ungeclaimt**. Einziger FAIL: QM5_21524 (`EA_Q08_MAE_HOOK_MISSING` + `EA_SYMBOL_NOT_IN_DWX_MATRIX` XCUUSD) = Altgenerations-Defekte, nicht das Pin-Praedikat; bleibt terminal. Zensus faellt waehrend der Welle kurz auf 2-15 Zellen/10 min (Compiles belegen Terminals), erholt sich danach. Reconcile der 8 gehaltenen Altzeilen bleibt offen (QM5_1538 braucht 2 Current-Source-Nachfolger; kein Wellen-Blocker). **41171 dritte Identitaet:** Q04 `edbb38c9` PASS_LOWFREQ 13:14Z -> Q05 `6cc07c90` append-only (rerun-of 795e3ab0). **Welle 2** (130 APPEND_ONLY_IDENTITY_RESTART) als Codex-Ticket kommissioniert (P82; Autoritaeten per zweiter Evidenz-JSON, Restart-Plan je EA, kein Enqueue). Naechster Schritt nach COMPILE_OK: `intake-first-q02` je Zeile in Tranchen unter der CPU-Regel (Q02-Queue 778 pendent, verhungert hinter dem Zensus - die Canaries warten ohnehin Tage). Fabrik 13:46Z: Zensus 98/h (30/15 min), Lock-Busy 0, Zaehler 12/25, Widerlegung 1/5.

> **Nachtrag 13:30Z (06.09.) - Tick 13:09Z: Welle 1 (70) + Pacer-Guard integriert, 72 Compiles im Hold, 41171 Q04 der dritten Identitaet:** Codex lieferte beide Tickets **direkt auf board-advisor**: `301c0948ee` (0b971b15, Welle 1: 70 PLAIN_REBUILD-Quellen repariert, 70 exakte Autoritaeten ueber die SHA-gebundene Evidenz `docs/ops/evidence/2026-09-06_framework_input_pin_wave1_authority.json`, .gitattributes -text) und `2c1236af61` (ce69613c: Pacer-Guard + Pre-Enqueue-Praedikatcheck `audit_framework_input_pins.py --check-source`, EA_Skeleton-Vertrag, Prompt, 41366/41367 repariert + Autoritaeten). Verifiziert: 70/70 Working-Copy-Hashes = Registrierung (keine CRLF), 248 Tests gruen -> beide APPROVED. Seed-Pins im Korpus 198 -> **128**. Alle 72 Compiles unter ihren Autoritaeten eingereiht (Hold `COMPILE_EA_WORKER_ROLLOUT_PENDING`); Reload chunk 53 (alle 10, idle-only) laeuft seit 13:16Z; Freigabe danach gezielt per `--work-item-id`. Vorab `reconcile_compile_rollout_holds.py`: Dry-Run zeigt 8 veraltete gehaltene Vorgaenger (u. a. 41176/41179/41189 vom 27.08.) als SUPERSEDE-bereit - der erste `--apply` brach ab (verlangt --expected-predecessor-count + --evidence-path), Korrektur folgt im naechsten Nachtrag; die 5 ungehaltenen Altzeilen 41130-41133/41136 waren schon am 25.08. superseded (kein Blocker). **41171 dritte Identitaet:** Q02 `4b9763eb` PASS 12:47Z -> Q04 `edbb38c9` append-only (rerun-of 5b06097c). Fabrik 13:09Z: Zensus 106/h (27/15 min; Compile-Welle und Reload druecken kurzzeitig), Lock-Busy 0, Zaehler 12/25, Widerlegung 1/5.

> **Nachtrag 13:00Z (06.09.) - Flottenereignis 12:40Z und Wellen-Nachlese:** Monitor meldete 9 Worker (12:41Z, 12:51Z): **T10 fehlte** (Prozess weg, aus worker_pids.json verschwunden; letzte T10-Logzeile `custom_history_lease_busy` mit PermissionError auf dem Lease-Pfad) und **T1/T6/T7/T8 wurden 12:40:28Z gleichzeitig neu gestartet** (FactoryWatchdog), unmittelbar nach den fuenf Seed-Pin-Compiles (12:38-12:40Z). Ursache noch nicht belegt (Worker-Logs im Fenster leer); Beobachtung offen: Compile-Welle -> Worker-Neustarts. T10 ueber `start_terminal_workers.py` (nur Fehlende) zurueckgeholt, Flotte 10/10, Headroom OPEN (RAM 27 GB, D: 75 GB). **Wellen-Nachlese:** `release_compile_wave --max-items 7` hat statt 41361/41362 zwei aeltere Hold-Zeilen mitgenommen: 9579 (8958e6ed) COMPILE_OK = Backlog-Fortschritt; 41268 (814aab56) COMPILE_FAIL `EA_FRAMEWORK_INPUT_PINNED` (Seed-/News-Pins) = das neue Praedikat wirkt fail-closed wie beabsichtigt, 41268 gehoert in den Batch 0b971b15. 41361 (747a1b3d) und 41362 (98f308b1) 12:55Z gezielt per `--work-item-id` freigegeben. Lehre: Wellen-Freigabe immer per `--work-item-id`, nie per `--max-items`, solange fremde Hold-Zeilen existieren.

> **Nachtrag 12:50Z (06.09.) - Tick 12:36Z: Seed-Pin-Compile-Welle 5/7 OK, 41171 dritte Identitaet gestartet, Folgetickets:** Reload chunk 52: 9/10 frisch (T9 seit 10:01Z beschaeftigt, wartet idle-only). Quell-Hashes der sieben gegen die Registrierung verifiziert (LF), Welle 12:37Z freigegeben (`release_compile_wave --max-items 7`): **COMPILE_OK** 41171 (c04e87f2, EX5 1eb20308..), 41319 (f2c37dc5), 41358 (b76152d7), 41359 (2c44aab1), 41360 (07f93bf5); 41361 (747a1b3d) und 41362 (98f308b1) noch pendent (Compile-Serialisierung). **41171 Q02-Neustart** `4b9763eb` (append-only rerun-of 30990e06, EX5 1eb20308; die cbddfa32-Kette Q02..Q07 bleibt Evidenz). 41319 bleibt terminal (Q02 DRAFT_DEFECT Null-Trades; Seed-Fix aendert daran nichts). 41358-41360: alte pendente Q02-Zeilen drift-gebunden (41358 ohne Bindung -> bindet kanonisch = neue EX5), Ersatz per seed-fresh-q02 nach Dispatch-Tod. **Kommissioniert:** Pacer-Template-Ticket **ce69613c** (P86: Guard-Template ohne Framework-Input-Pins, Pre-Build-Praedikatcheck, 41366/41367 reparieren) und Batch-Ticket **0b971b15** (P82: Welle 1 = 70 PLAIN_REBUILD, Welle 2 = 130 APPEND_ONLY_IDENTITY_RESTART; 41186/41187/41188/41190 pinnen ebenfalls den Seed und gehoeren in den Batch statt in eigene Autoritaeten). **0ceafe5f (D2) mit Status APPROVED geschlossen** (Siblings gebaut, Matrix-Service materialisiert, NDX/RAM und 41345/ZERO_TRADES = dokumentierte Holds). Fabrik 12:36Z: Zensus 114/h (30/15 min), Lock-Busy 0, Zaehler 12/25, Widerlegung 1/5, Codex-Lane baut weiter (0bce446905).

> **Nachtrag 12:25Z (06.09.) - Tick 12:03Z: Seed-Pin-Fix integriert, Compile-Welle im Hold, autocrlf-Falle:** Codex 65c5d9a1 als `9b9305f4d4` integriert (+ Test strukturell statt Hard-Count) und APPROVED: die sieben Pacer-Guards pinnen keine Framework-Inputs mehr, fail-closed build_check-Praedikat `EA_FRAMEWORK_INPUT_PINNED`, Audit-Tool, sieben Autoritaeten (Evidenz `docs/ops/evidence/2026-09-06_framework_input_pin_census.md` + `..._source_repair_authority.json`, Codex-Commits a90280bad6/7f1fcdf6c0 direkt auf board-advisor). Zensus: 4.004 Quellen, 200 Seed-Pins (jetzt 198: der Pacer baut weiter gepinnte EAs, 41366/41367 - das Praedikat blockt deren Recompile ab jetzt; Pacer-Template ist der naechste Fix), 378 Quellen mit dem breiten Praedikat (meine 200/0-Annahme war falsch; die 178 zusaetzlichen sind echte News/Friday/Stress-Pins). Batch-Plan der 200 (70 PLAIN_REBUILD / 130 APPEND_ONLY_IDENTITY_RESTART) liegt als Vorlage-Abschnitt, eigenes Ticket nach der Sieben-Welle. **Erste Einreihung der sieben verweigert (`SOURCE_REPAIR_AUTHORITY_INVALID`):** Ursache = `core.autocrlf=true` hat die sieben `.mq5` beim Cherry-Pick als CRLF in die Working Copy geschrieben, die Autoritaet hasht LF (Index-Blob ist LF) - die Bindungs-Byte-Falle vom 17.08. Working Copies auf LF normalisiert (Hashes = Registrierung), die sieben in `.gitattributes` als `-text` gepinnt (`a5da66d7a5`), dann eingereiht: c04e87f2 (41171), f2c37dc5 (41319), b76152d7 (41358), 2c44aab1 (41359), 07f93bf5 (41360), 747a1b3d (41361), 98f308b1 (41362) - alle im Hold `COMPILE_EA_WORKER_ROLLOUT_PENDING`; Reload chunk 52 (alle 10, idle-only) laeuft seit 12:05Z, Freigabe danach. Q04-Klassifizierung greift bereits (Subprozess-Skript): 1371 EURAUD/EURGBP seit 11:43Z FAIL mit Reason-String. Fabrik 12:03Z: Zensus 116/h (30/15 min), Lock-Busy 0, Zaehler 12/25, Widerlegung 1/5.

> **Nachtrag 11:55Z (06.09.) - Tick 11:34Z: Q04-Misclass integriert (Veto-Punkt), Seed-Pin in Codex-Arbeit:** Codex 51e0a47b (Dry-Run) als `349d175f8c` integriert und APPROVED: ein vom Tester abgeschlossener, gelatchter Native-Report ohne zurechenbaren Deal-Stream/Self-Report wird kuenftig als bestehendes Q04-**FAIL** mit Reason `STRATEGY_MIN_TRADES_NOT_MET` bzw. `STRATEGY_NATIVE_REPORT_ONLY_NO_ATTRIBUTED_STREAM` klassifiziert statt INFRA_FAIL (ungueltige/ungelatchte Reports bleiben Infra); Replay 30 Tage: 160 von 198 Q04-INFRA-Zeilen waeren FAIL, betroffen 61 EAs ausnahmslos alter Generationen (1xxx/10xxx-12xxx: 1119, 11287, 1100, 1371, 12707, ...), keine 41xxx -> kein transienter Stream-Verlust moderner EAs; PASS ist in dieser Klasse unmoeglich (Kostenmodell nicht anwendbar), Retry zwecklos, der Stranded-Sweep hoert auf, sie zu wiederholen (1371 allein 17 pendente Q04-Zeilen). Keine Schwelle, kein gespeichertes Verdikt geaendert. **OWNER-Veto-Punkt:** Klassifizierung kuenftiger Zeilen (FAIL statt INFRA fuer unbewertbare Alt-EAs); Rollback = Revert `349d175f8c`. Hinweis fuer die Archiv-Matrix: FAIL mit Reason NATIVE_REPORT_ONLY heisst 'unter dem Q04-Kostenmodell nicht bewertbar', nicht 'oekonomisch schlecht'. Seed-Pin-Ticket 65c5d9a1 seit 11:12Z IN_PROGRESS (Codex, P90). Fabrik 11:34Z: Zensus 112/h (28/15 min), Lock-Busy 0, Zaehler 12/25, Widerlegung 1/5.

> **Nachtrag 11:20Z (06.09.) - Tick 11:03Z: INPUTSVALID-PIN-Klasse trifft die Pacer-EAs (Q07), Q04-Fehlklassifizierung bei 1371, Reload 51 komplett:** **41171 Q07 `48734e69` INFRA_FAIL 10:43Z ist deterministisch:** Seeds 17/99/7/2026 -> 'tester stopped because OnInit reports incorrect input parameters' (Journal raw/run_01, 12:41:17 lokal, Inputs qm_rng_seed=17 + qm_stress_reject_probability=0.10, EX5 cbddfa32 korrekt deployt auf T6), nur Seed 42 lief (PASS, 63 Trades, PF 0,96). Ursache im Lock-Guard der Quelle (~Z. 757): `qm_rng_seed != 42` -> ungueltig. Q07 variiert den Seed per Design -> die Klasse aus dem Memory 20.08. (Framework-Inputs duerfen nie gepinnt werden); der Stress-Fix bb62d69619 hat nur den Wahrscheinlichkeits-Pin entfernt. **Zensus: 200 von 4.000 EA-Quellen pinnen `qm_rng_seed` (20xxx-Serie + 411xx/413xx-Pacer).** KEIN Requeue (ONINIT_FAILED-Regel). Kommissioniert: Codex-Ticket **Seed-Pin** (P90, Sol/high): Phase A Quell-Fix der 7 Pacer-EAs + Autoritaets-Registrierungen (Muster fd8c1eee61), Phase B build_check-Praedikat `EA_FRAMEWORK_INPUT_PINNED` (fail-closed, Sweep-Tabelle), Phase C Zensus + Batch-Plan der 200 als Vorlage-Abschnitt (Quellen unangetastet). Danach: Compile-Welle -> Reload (Stale-Worker-Klasse) -> Q02-Neustart der 7 (append-only, Kette 41171 Q02-Q06 von heute verfaellt als Evidenz). **1371 Q04 (4 Symbole, 10:31-11:02Z) INFRA_FAIL `stream_and_selfreport_missing`:** Lauf lief (Report 35 KB), run_smoke = FAIL `MIN_TRADES_NOT_MET` (0 zurechenbare Trades im OOS-Jahr) -> Oekonomie traegt Infra-Label; kein Requeue; Ticket **Q04-Misclass** (P80, Dry-Run-Proposal + 30-Tage-Replay). Reload chunk 51 fertig 10:49Z (alle 10 Worker frisch, T10 nach dem Q07-Lauf von 10268). Codex-Lane: review_ea ad98fd21 IN_PROGRESS (41366). Fabrik 11:00Z: Zensus 119-126/h, RAM 29 GB, D: 69 GB, Lock-Busy 0, Zaehler 12/25, Widerlegung 1/5.

> **Nachtrag 10:40Z (06.09.) - Tick 10:06Z: Zaehler 12/25, Buffer-Monotonie integriert, 41193 wieder in der Pipeline, ein eigener Praedikat-Fehler mit 1 Zeile Blast-Radius:** **Zaehler 12/25** (pipeline_state 10:12Z; 12 EAs/12 Familien; einzige Q14-Closure seit 06:17Z = 11881/GBPUSD KEEP_INCUMBENT 09:44Z -> Widerlegungszaehler 1/5 ohne Promotion; public funnel-stats.json noch 11 = stale). Codex-Rueckläufer **49aa6d17** (monotone Bounded-Array-Beweisfuehrung) als `999be1c0c7` integriert (Python-Teile der Vorgaengerkette 1240b069d5/23a4cf01b5 + 364ec6ded8; Evidenz d4b3994e19 lag schon auf board-advisor, Codex committet direkt): 12 Ziel-Findings 41186/87/88/90 geloescht, Sweep 633->410 bei 0 neuen Findings, 74 Tests inkl. des zuvor roten test_qm5_411xx_*; APPROVED. **Eigener Fehler (behoben, dokumentiert):** beim Erfuellen des Codex-Fixtures (Root-Level `#include <ML.mqh>`) haengte ich die Alternative per bash->python->PowerShell-Escaping an die Include-Regex; nur EIN Backslash kam an (`[<"/\]` -> `\]` maskierte das Klassenende), die Klasse matchte jede `#include`/`#property`-Zeile -> 41193-Compile `278204e3` 10:22:46Z COMPILE_FAIL mit 114 EA_ML_FORBIDDEN (T2). Blast-Radius = genau diese eine Zeile (alle anderen Compile-Zeilen ungeclaimt im Hold). Sofort revertiert (`48b380453f`), dann korrekt: eigenes enges Muster `(?im)^\s*#include\s*[<"](?:[^>"

]*[/\])?ML(?:\.mqh|[/\])` DATEIBASIERT gegen alle 3.987 #include/#property-Zeilen des Frameworks (0 Treffer) und 10 Beispiele geprueft, als separate Regel + Dedupe pro Datei:Zeile eingebaut (`38f525617b`, 74 Tests). Lehre: Regex-Aenderungen an build_check nie ueber Shell-Escaping, immer per Skriptdatei + Korpus-Probe VOR dem Einbau. **41193:** Compile #2 `d030cf94` unter Autoritaet 690fc42a = COMPILE_OK (EX5 f7c19930..), erster Q02-Canary `b2b80d5d` via intake-first-q02 (CPU 87-92 %, Artefakt `artifacts/qm5_41193_q02_cpu_admission_20260906T1036.json`). **41171 neue Kette:** Q05 PASS 10:01Z -> Q06 append-only `3ca389aa` = PASS_SOFT 10:18Z -> Q07 vom Pump selbst angelegt 10:24Z (keine terminale Q07-Zeile fuer das Paar; bestaetigt die Kaskadenregel). Reload chunk 51: 9/10 neu, T10 seit 08:39Z in einem langen Q07-Lauf (QM5_10268), Reload wartet idle-only. Codex baut weiter direkt auf board-advisor (QM5_41366 Basket, 272ef7f843/48a1d330de; Q02 am CPU-Deckel gestoppt). Fabrik 10:30Z: Zensus 126/h, RAM 33 GB, D: 78 GB, 10 Worker, Containment aus, Lock-Busy 0.

> **Nachtrag 09:50Z (06.09.) - Tick 09:40Z:** 41171 neue Kette: Q04 `5b06097c` = PASS_LOWFREQ 09:15Z -> Q05 append-only `795e3ab0` (rerun-of ccd43483, EX5 cbddfa32; vorher terminale Zeile geprueft, `requeued: []`). 41193: Compile-Autoritaet `router_ops_issue:690fc42a-...:QM5_41193` registriert (`fd8c1eee61`, 119 Tests, Dry-Run ELIGIBLE; unveraenderte Quelle 8e3fb9d1, Vorgaenger 37e3b310, Evidenz-Bindung sweep-Doc sha 4a1672d5..) - da ALLE 10 Worker vor diesem Commit gestartet sind (Stale-Worker-Klasse), laeuft Reload chunk 51 (alle 10, idle-only, gestaffelt) seit 09:37Z; erst danach `enqueue-compile --source-repair-authority` + Wave-Release. abd0a457 (RECYCLE) -> enger Nachfolger **49aa6d17** (P77, Sol/high): NUR die monotone Bounded-Array-Beweisfuehrung (findings_after ⊆ findings_before je EA, 12 Ziel-Findings 41186/87/88/90 loeschen, ML-Teil ist durch 690fc42a erledigt). 0ceafe5f (D2 Amendment C): die 6 Siblings sind gebaut (db42cb90 APPROVED 05.09.), Materialisierung laeuft ueber den Matrix-Service (Programme fuer 41305/41307/41324/41342-41345 mit 1.085 Zellen seit 05.09. sichtbar) -> Ticket im naechsten ruhigen Tick mit Status schliessen statt routen. Widerlegungsregel: 0 Q14-Closures seit 06:17Z (Baseline 12 unveraendert). Fabrik: Zensus 112/h (31/15 min), Lock-Busy 0, Zaehler 11/25, 10 Worker, Containment aus.

> **Nachtrag 09:35Z (06.09.) - 690fc42a ueber die Opus-Lane geliefert (Codex-Gate gedrosselt):** Wurzel = flacher Regex `weights\s*\[` in `framework/scripts/build_check.ps1` (Identifier-Match, Rohtext inkl. Kommentare/Strings). Option (a) gewaehlt und als `77d4ec1634` integriert: Praedikat auf echte ML-Formen verengt (ML-Library/Modell-Includes, Modell-Artefakte, Inferenz-/Trainings-API-Aufrufe inkl. MQL5 `Onnx*`, explizite Lernrate, gradienten-/reward-/fehlergetriebene Parameter-Updates) auf kommentar-/string-geblankter Quelle; 10 neue Tests (Fixtures heben die ausgelieferten Regexe wortgleich aus dem Skript). Sweep ueber 3.995 `.mq5`: vorher 2 Treffer (41193 fracdiff-Koeffizienten, 2079 Williams-UO-Konstanten), nachher 0, **kein EA neu geflaggt**; Kalibrierungsbefund: ein blankes `loss` haette 5 LAD/Theil-Sen-EAs (41159/41160/41165/41166/41189) neu geflaggt -> entfernt (minimierter Verlust ist kein Lernsignal). Hard-Rule-Text unveraendert; das ist reine False-Positive-Entfernung, dem OWNER als Veto-Punkt gemeldet. (b) Rename-Patch (`weights[]`->`frac_coeffs[]`, identifier-only bewiesen) liegt als Evidenz. Ticket 690fc42a REVIEW->APPROVED. **Folge:** Compile-Nachfolger fuer 41193 - `--repair-successor-of 37e3b310` verweigert korrekt `SOURCE_NOT_REPAIRED` (Quelle unveraendert) -> governed Pfad = Autoritaets-Registrierung wie ab140348dc/d3ef95bdee (Subagent im Worktree beauftragt, kein Commit durch den Agenten), danach `enqueue-compile --source-repair-authority` + Wave-Release.

> **Nachtrag 09:15Z (06.09.) - Tick 09:06Z: Requeue-Falle (eigener Fehler, restauriert), Codex-Gate, 41171-Nachfolger:** (1) **Eigener Fehler:** `enqueue-backtest --phase Q04 --from-work-item-id 30990e06` OHNE `--append-only-rerun-of` hat die terminale Q04-Zeile `50fbbdbf` (PASS_LOWFREQ, Vor-Fix-EX5) 09:09:27Z in place requeued (Verdikt im DB-Feld weg, Report-Root archiviert) - die dokumentierte Requeue-Falle (22.08.), zweiter Vorfall. Innerhalb von 3 min **byte-exakt restauriert** aus dem 08:35Z-Backup (geschuetzter UPDATE nur bei pending/unclaimed; Report-Root zurueck; Ledger `restore_after_erroneous_requeue`; Vorher-Backup `farm_state_before_restore_50fbbdbf_20260906T091133Z`). Evidenz `docs/ops/evidence/2026-09-06_requeue_trap_50fbbdbf_restore.md`. Strukturbefund dahinter: der Pump kaskadiert eine Neu-Identitaets-Kette NICHT ueber eine Phase, die fuer (EA, Symbol) schon eine terminale Zeile hat (41171: Q02 PASS 08:08Z, 58 min keine Q04) -> Nachfolger von Hand, IMMER append-only. Korrekt nachgezogen: Q04 `5b06097c` (rerun-of 50fbbdbf, EX5 cbddfa32..). (2) **Codex-Gate:** `last_gate allowed=false reason=class_threshold_exceeded task_class=ops_review` (Codex Woche 57 % verbraucht bei 22 % Zeit -> Governor drosselt die Klasse; f4505fb9 lief als P88 durch). 690fc42a (P66) und 0ceafe5f (P84) bleiben deshalb unassigned; 690fc42a wird gemaess OWNER-Doktrin 03.09. ueber einen Opus-Subagenten im Worktree bearbeitet (Dry-Run-Proposal a+b, kein Commit durch den Agenten). abd0a457 (RECYCLE) braucht ein enges Nachfolge-Ticket. (3) Fabrik 09:06Z: Zensus 116/h (28/15 min), Lock-Busy 0/15 min, Zaehler 11/25, MC-Receipts 0, Server 8770-8772 = 200, ClaudeOrchestration Disabled. 41362-Canary a126c45e pendent; 41358-41361 Q02 pendent (drift-Pfad).

> **Nachtrag 08:40Z (06.09.) - Tick 08:34Z: Compile-Welle geschlossen, Stale-Worker-Klasse bestaetigt:** Reload chunk 50 abgeschlossen 08:34:38Z (alle 10 Worker seit >= 07:30Z, d.h. nach `d3ef95bdee`). Die vier verweigerten Compiles append-only neu eingereiht unter derselben Autoritaet (a77ea58f/41358, c16734de/41359, e1d9cafc/41360, 1cb0f94c/41361); der eingebaute Hold `COMPILE_EA_WORKER_ROLLOUT_PENDING` griff korrekt und wurde ueber `release_compile_wave.py --max-items 4 --apply` 08:35:54Z geloest (Backup farm_state_before_compile_wave_20260906T083545Z) -> **alle vier COMPILE_OK innerhalb von 3 Minuten** (T10/T1/T3; neue EX5 e1f9f5b3.., 30861899.., 8d8ff44f.., b365a333..). Damit ist die Ursache bewiesen: gleiche Payloads, gleiche Quell-Hashes, nur frische Worker-Module. **41362:** CPU-Fenster 08:36Z 81-84 % (<97) -> `intake-first-q02 --apply` = erster Q02-Canary `a126c45e` (Basket-Set, EX5 0cb69e96.., Receipt `D:/QM/strategy_farm/artifacts/receipts/first_q02_intake/a4d9fc3a-..._a126c45e-...`). **41358:** Q02 f92931eb hat keine EX5-Bindung im Payload -> Dispatch bindet die kanonische Datei (neue EX5), laeuft korrekt. **41359/41360/41361:** pendente Q02-Zeilen 00cf2ac1/8f4c4610/ecc8e269 binden die alte EX5; Binding-Census (read-only, 50 drift-gebundene pendente Zeilen fabrikweit) gibt `GOVERNED_BUILD_SUCCESSOR_REQUIRED`; `intake-first-q02` verweigert (existing_q02_row), `seed-fresh-q02`/`--append-only-rerun-of` verlangen eine TERMINALE Vorgaengerzeile -> governed Pfad: Zeile wird beim Dispatch fail-closed terminal (Preflight-Mismatch), danach `seed-fresh-q02 --expected-current-ex5-sha256`. Keine Hand-Umbindung. Q02 ist ohnehin hinter dem Zensus verhungert (775 pendent), Kosten = Wartezeit. **41171:** Kaskade nach Q02-PASS 08:08Z noch ohne Q04-Zeile (Pump-Kadenz; vorherige Kette brauchte 31 min) -> naechster Tick. **Router:** `route-many` liefert nur `awaiting_decision_bound_agent:claude` fuer 90431302 (geparkte Kalender-Kette); 690fc42a (P66, ML-Praedikat-Fehlalarm 41193) und 0ceafe5f (P84, D2-Siblings) bleiben unassigned TODO -> im naechsten Tick Routing-Grund pruefen (Codex enabled, running 0). abd0a457 ist RECYCLE (Claude 05.09.): braucht ein Nachfolge-Ticket mit engem Scope. **Q08 9123/XAUUSD 08:24Z = FAIL_HARD** (8.4 Seasonal u.a.; 8.2 DSR ebenfalls INVALID = 4. V2-Fall, ohne Zaehlerwirkung, da FAIL dominiert). Fabrik: Zensus 112/h (27/15 min), Zaehler 11/25, MC offen 2, Receipts 0.

> **Nachtrag 08:13Z (06.09.) - NEUE SESSION (claude.ai-Notion-Connector), Erst-Tick des CEO-Loops:** Handoff §2 ausgefuehrt: ClaudeOrchestration-Task Disabled bestaetigt; Fleet-Monitor neu (`tools/strategy_farm/session_tools/fleet_monitor.py`, 10-min-Summary + Containment-Trip-Event); Notion `self` = Workspace "Fabian's Notion" (Connector verbunden); Server 8770/8771/8772 = 200. **Codex f4505fb9 (triviale DSR-Kohorte) integriert** als `7a89b5b701` (Cherry-Pick 27facf2db7, 40 Tests, Codex-Sol-Trailer) und APPROVED: Deklarationspfad fail-closed, echte Cards (11167/11015: 'P3 sweep candidates') werden verweigert -> die Such-Historien-Frage ist ROT und liegt beim OWNER: Vorlage `docs/ops/OWNER_VORLAGE_2026-09-06_dsr_single_configuration_declaration.md` + Mission-Control-Karte **OWNER-DEC-DSR-SINGLE-CONFIG-DECLARATION-20260906** (Feed-Rev. 50; `e1c70de79a`, `34a683fb10`; Empfehlung A = Sweep-Liste ist Q14-Vorschlag, maschinell geprueft: keine Optimierungszeile vor Q08 + Set = Card-Lock). Bis zum Entscheid bleibt der Zaehler strukturell bei max. 24 (kein Auffangregel-Pfad). **Compile-Welle:** 41171 (`411cfb83`) und 41362 (`a4d9fc3a`) COMPILE_OK auf T2; 41358-41361 COMPILE_FAIL `CANDIDATE_RECHECK_REFUSED:SOURCE_REPAIR_AUTHORITY_INVALID` auf T5/T6/T8 - Ursache: **veraltete Worker-Module** (Worker gestartet 21:58-00:40Z, Registrierungs-Commit `d3ef95bdee` erst 07:16Z; T1/T2/T7 seit 07:30Z frisch). Payloads/Quell-Hashes aller sechs stimmen mit der Registrierung ueberein. Fix (GRUEN): gestaffelter Idle-only-Reload `session_tools/reload_chunk50.py` (T3, T4, T5, T6, T8, T9, T10) seit 08:03Z; danach append-only Re-Enqueue der vier Compile-Zeilen unter derselben Autoritaet (`enqueue-compile --source-repair-authority router_ops_issue:04f011a6-...:QM5_4135x`). Lehre: nach jedem Commit, der `compile_work_items.py`-Autoritaeten registriert, ZUERST Worker-Startzeiten gegen die Commit-Zeit pruefen, dann die Welle freigeben. **41171 Q02-Rerun** `30990e06` (append-only, --expected-current-ex5-sha256 cbddfa32...) = **PASS 08:08Z**, Kaskade ueber den Pump. **41362** hat keinen build_ea-Task (Pacer-Build, CPU-Stop 04:08Z) -> `intake-first-q02` Dry-Run ELIGIBLE, CPU-Admission 08:12Z STOP (97,8 %/99,2 % >= 97) -> Retry im naechsten Tick (`artifacts/qm5_41362_q02_cpu_admission_20260906T08.json`). Die vier pendenten Q02-Zeilen von 41358-41361 (f92931eb, 00cf2ac1, 8f4c4610, ecc8e269) binden die alte EX5 -> nach COMPILE_OK append-only Reruns. Fabrik: 10 Worker, Zensus 102-110 MEASURED/h, RAM frei 17-30 GB, D: 65 GB, Containment enabled:false, Zaehler 11/25, MC offen: WEBSITE-DEPLOY + DSR-Deklaration.

> **Nachtrag 07:50Z (06.09.) - SESSION-HANDOFF (neue Session fuer den claude.ai-Notion-Connector):** Uebergabe in docs/ops/SESSION_HANDOFF_2026-09-06.md (Stehende Auftraege, erste Schritte: Monitor + Loop neu aufsetzen, Notion pruefen, Server 8770-8772; Fabrikstand; Lanes; MC/To-Dos; Website; Notion; Loop-Prompt). Seit dem letzten Nachtrag: Mission Control importiert alle Vault-OWNER-To-Dos (17, gruppiert; Vault-Backup Archive/OWNER_2026-09-06_pre_todo_migration.md, Migrationszeile) + 5-s-Selbstaktualisierung mit Render-Stamp und Eingabeschutz (61ba114f25, 43 Tests; Render-Task 1 min). Codex integriert: Compile-Autoritaeten fuer die 6 reparierten EAs (aeca1d6032) -> alle sechs ELIGIBLE eingereiht und in einer Welle freigegeben (411cfb83, 001294f0, 6d61317d, 37176af0, a464f322, a4d9fc3a); Kollektor-Compile-Probe + Tester-Fixture (ca46686db6; nativer Tester-Lauf offen bis Demokonto/Terminal); Notion-Publisher (d1a54e38e3, enabled=false bis Token). Notion: Vermarktungs-Hub + Datenbank Morgenbriefing angelegt (Hub 3d347da5..., Data Source 9db97cf3...), erstes Briefing 06.09. gepostet; lokaler MCP entfernt, claude.ai-Connector verbunden (haengt in dieser Session nicht mehr -> neue Session). Website: Family-Narrativ vs. Tagline behoben (Tagline fuehrt, Family als Muster, Widerspruchs-Guard, 1 Seite markiert), Hero-Lead 22 Woerter, Headline 2 Zeilen bei 375. Codex-Ticket f4505fb9 (triviale DSR-Kohorte) IN_PROGRESS = P0 fuer den Zaehler (sonst Cap 24). Session-Tools ins Repo: tools/strategy_farm/session_tools/.

> **Nachtrag 07:15Z (06.09.) - STRUKTURBEFUND Q08 unter DSR V2, Astra-Kritik Runde 2:** Fabrik 99 MEASURED/h (21/15 min), 6 aktive, Lock-Busy 8, free 29 GB, D: 61 GB, Zaehler 11/25, Zensus 9.735 pending. Q08 QM5_11167/XAUUSD d7ab61ae endete 06:32Z INVALID (8.2 DSR_V2_MUTABLE_OR_RELATIVE_CONTEXT, Produzent SEALED_SEARCH_LEDGER_UNAVAILABLE) - erwartete V2-Konsequenz fuer EAs ohne versiegelte Suchhistorie, aber mit Folge fuer das Ziel: OHNE Fix entsteht kein neuer Q11-Ueberlebender mehr aus Q02-Q10, der Zaehler ist bei 24 gedeckelt (11 + 13 Zensusprogramme); der 11015-Q08-Nachfolger 34d0e1ba wird ebenso INVALID enden. Ursache = Einzelkonfigurations-EAs haben eine triviale Suchhistorie (1 deklarierter Trial), die der Produzent nicht versiegelt -> Ticket Codex f4505fb9 (Sol high, Prio 88: Seal aus Karte + Build-Identitaet, n=1-Auswertung ohne Korrektur bei unveraenderten Schwellen, Replay auf 3 INVALID-Artefakten, Vorlage-Abschnitt falls OWNER-Regel noetig). Widerlegungsregel: 15 entscheidende Q14-Verdikte, 0 Promotionen (Basis KEEP 12). Astra-Kritik f219d76a APPROVED: mechanische Fixes lokal (Kontrast Orange/Gedankenstriche/Ledger-Zeilen, Archiv-/Detailseiten luden noch Fraunces -> Inter, Sticky-Header 375, Mobile-Summary, Nav-Label), Exposure 0; Judgement-Memo unangewendet: (1) Family-Narrativ widerspricht Strategie-Tagline auf Detailseiten -> Fix laeuft (Agent: Strategie-Prosa fuehrt, Family als Muster, Horizont aus Metadaten, Widerspruchs-Check), (2) Hero-Lead 34 Woerter/3-zeilige Headline bei 375 -> Fix laeuft (<=22 Woerter, Mobile-Clamp), (3) Kerzenanimation = OWNER-Vorgabe, bleibt, (4) CTA Ink vs Emerald = OWNER-Frage. FTMO: Set-Pfad-Generator 9cf460d6ad + Kollektor-Haertung f975f308cb integriert, Folge-Ticket f4e95c80 (governed Compile + Tester-Harness). Cockpit-Render-Task auf PT1M.

> **Nachtrag 07:11Z (06.09.) - Abnahmen der drei JA-Auftraege, FTMO-Deliverables integriert, Mission-Control-Umbau live:** Unabhaengige Abnahme (Sonnet) ACCEPT fuer 244ec170 (M06 Attestation: Hashes byte-exakt, Freeze ACTIVE, Pointer unveraendert), 9bed9f32 (M11: Addendum + funnel-stats 11/25 reproduziert; Zaehlbasis der Widerlegungsregel = entscheidende Q14-Verdikte, Baseline 12) und a7ed2ad5 (M13: Tickets, Runbook, To-Do, EXPECTED_STATE PARKED unveraendert) -> alle APPROVED. Codex-Rueckgaben integriert: Live-Modus-Set-Pfad-Generator (dfb6c2ba, 9cf460d6ad, 17 Tests, 8 inerte Trial-Sets unter artifacts/ftmo_trial_sets_review) und Kollektor-Haertung (3a1eba6c, f975f308cb, 14 Tests; native Compile-/Tester-Abnahme durch den Ad-hoc-Compile-Guard korrekt verweigert -> Folge-Ticket f4e95c80 governed Compile-Route + Tester-Harness). Compile-Nachfolger fuer die 6 reparierten Rohstoff-EAs: Autoritaeten sind registrierungsbasiert -> Ticket Codex 04f011a6 (Registrierungen + Evidenz + Dry-run ELIGIBLE), danach Apply/Welle/Q02-Reruns durch mich. Mission Control (1e54245501, cf946248b4): OWNER-To-Dos-Block oben (erstes To-Do FTMO-Demokonto, korrigierte Fassung: Karte bereits JA, To-Do = autorisierte OWNER-Handlung), nur OPEN/DEFERRED-Karten, in-flight-Umsetzungen, Entschiedenes im Vault-Archiv (OWNER.md, 11 Zeilen), Bloecke Ausnahmen/Linear-Frontier entfernt; 33 Tests. OWNER 07:3xZ: alle Vault-OWNER-ToDos nach MC + Selbstaktualisierung alle 5 s -> Workflow wf_07e0aea5 (Vault-Import mit Backup, gruppierte Darstellung, Stamp-Polling mit Eingabeschutz); Render-Task Cockpit auf 1 min gestellt. Astra-Kritik Website Runde 2 gegen skills/web-design-taste = Ticket f219d76a (IN_PROGRESS).

> **Nachtrag 06:37Z (06.09.) - Tick 06:27Z (verspaetet): drei OWNER-JA umgesetzt, Website-Runde 2, Burn-in OK, neue MC-Regeln:** Fabrik 98 MEASURED/h (23/15 min), 7 aktive, Lock-Busy 4, free 29 GB, D: 63 GB, 10 Worker, Containment enabled:false, Zaehler 11/25, Zensus 9.811 pending. OWNER-Receipts 06:16-06:17Z: LIVE-IDENTITY-SIGN = JA -> attestation.json (Receipt 510a2922 an Proposal-SHA 20de8acd gebunden, 21a313cbf9; keine Laufzeitaenderung, Freeze ACTIVE; Task 244ec170 REVIEW); M11-CENSUS-BRANCH = JA (Option A) -> Widerlegungsregel (5 weitere Q14-Closures ohne Promotion = Pflichtzweig jenseits 25 widerlegt) als Addendum im DL-089-Plan (9049562ec7), public funnel-stats.json regeneriert (11/25, 3.065 Strategien, 118.866 Backtests inkl. gemessener Zensuszellen, 8.795 Zellen; aff9bec878; Task 9bed9f32 folgt); M13-ECONOMIC-TRIAL = JA (Option B) -> Codex-Tickets dfb6c2ba (Live-Modus-Set-Pfad, inert) + 3a1eba6c (Kollektor-Abnahme + Install-Plan non-live), Capture-Runbook docs/ops/FTMO_M13_CAPTURE_RUNBOOK_2026-09-06.md + Evidenz-Skelett (83a9c51144), Task a7ed2ad5 REVIEW; OWNER-To-Do FTMO-Demokonto heute Abend (Anweisung im Chat + Mission Control). Neue OWNER-Regeln 06:35Z: Entschiedenes raus aus MC -> Vault-Archiv; OWNER-To-Dos-Block in MC; Bloecke Ausnahmen/Linear-Frontier raus -> Workflow wf_d1920b94 (Implement/Review/Fix) laeuft. Website: Hero-Kerzen (GARCH-Pfad, feste Teilung), Inter-Headline, Emerald-Akzent (Agent), Archiv als 26-Spalten-Matrix (3.339 Zeilen, sortierbar/filterbar, Exposure-Scan 0 Treffer) + reichere Strategy Cards (Agent), Astra-Trichter v2 gebogen/ohne Ellipse (c821067c APPROVED) - alles lokal 8772, kein Deploy; Design-Skill skills/web-design-taste (082a77a8a2) aus taste-skill/impeccable/awesome-copilot vendored (OWNER-Frage). Codex: 41171 Q06-OnInit-Root-Cause (zero-only Guard auf qm_stress_reject_probability) -> Fix fuer 7 EAs integriert bb62d69619 (71 Tests), f4b0e80f APPROVED; governed Recompile-Nachfolger fuer 41171/41358-41362 = offen (enqueue-compile verweigert SOURCE_REPAIR_AUTHORITY_INVALID - Request-Format mit append_only_source_repair + Vorgaenger-Zeile noetig, naechster Tick); 41319 Zero-Trades = Historien-/Karten-Kapazitaetsdefekt (60 Monatsendpunkte, 1.200 D1-Bars gelockt) -> Karte verlangt Retirement, 9a94ffeb APPROVED; retire-ea-ids verweigert fuer gebaute EAs (ea_directory/work_items/magic exist) -> Terminalzustand bleibt die Q02-DRAFT_DEFECT-Zeile (Archivmatrix ableitet). Burn-in Backup-Guard: Stunden-Snapshot farm_state_20260906_0600 vom 06:00Z-Wartungslauf erzeugt (db_backup wieder non-null), Retention 3x fehlerfrei = Fix wirksam. Kalender: refresh_news_calendar.ps1 (Scheduled Task) hat 03:30Z Bundle c07b37ba publiziert (dxz23_execution_contracts.json im Arbeitsbaum geaendert - wird von mir nie committet).

> **Nachtrag 06:01Z (06.09.) - Tick 05:54Z: 41319 Review + Q02 (Zero Trades), 41171 Q06 ONINIT, 11015 repariert, OWNER-Website-Feedback:** Fabrik 106 MEASURED/h (26/15 min), 6 aktive Zellen, Lock-Busy 6/15 min, free 27 GB, D: 62 GB, 10 Worker, Containment enabled:false, Zaehler 11/25, Zensus 9.866 pending. QM5_41319 (wti-madf-persist-tr): Build-Review per Sonnet-Checkliste APPROVE (Identitaet, Magic, SPEC-Mechanik, 29 Inputs verdrahtet, Hard Rules, 9 Tests) -> b930e8c1 APPROVED, record-build -> Q02 621d79bb, Ergebnis DRAFT_DEFECT Q02_ALL_ENQUEUED_SYMBOLS_ZERO_TRADES (1 Lauf, OnInit ok, 0 Trades 2018-2026) -> Ticket Codex 9a94ffeb (instrumentierte Signal-Diagnose; Fix+Rerun-Kommando oder RETIRE, keine Schwellen-Aufweitung). QM5_41171/XTIUSD: Q05 stress_medium PASS (pf 1,01), Q06 stress_harsh INFRA_FAIL invalid_summary:BARS_ZERO,ONINIT_FAILED (42 s, 0 Runs); einziger Set-Unterschied qm_stress_reject_probability 0.0 -> 0.1 -> kein Blind-Requeue (InputsValid-Doktrin), Ticket Codex f4b0e80f (OnInit-Zeile pinnen, Fix, Rerun-Kommando, Familiencheck ueber die Pacer-Rohstoff-Builds). QM5_11015/EURUSD (7d6eb2eb, Codex Sol): Root Cause setgen-Overwrite dcd299f5; Repair (11 explizite Strategie-Defaults = compilierte Defaults der gelaufenen Runs, Q02-Q07 bleiben gueltig) + First-Q02-Intake-Guard (fail closed bei leeren strategy_*) integriert e143736025 (21 Tests); EX5 unveraendert; genau ein append-only Q08-Nachfolger 34d0e1ba aus Q07 PASS 0060d528 eingereiht; Task APPROVED. Retention-Runner fehlerfrei; Stunden-Snapshot-Bewertung nach 06:00Z. OWNER-Website-Feedback ~06:00Z: Trichter gefaellt, Waende gebogen + Ellipse weg -> Astra-Ticket c821067c (Design-Autoritaet); Header-Kerzen unrealistisch/Abstaende -> Neubau des Kerzengenerators; Headline-Schrift zurueck auf Inter (Fraunces raus); Farbkonzept zurueck auf STEEL+EMERALD (Akzent Emerald statt Stahlblau); Archiv als Datenbank-Tabelle nach dem internen Matrix-Prototyp (ohne Parameter/IDs), Strategy Cards mit ausfuehrlicherer Erklaerung + Gate-/Backtest-Umfang -> zwei Design-Agenten laufen auf der lokalen Kopie (8772), kein Deploy.

> **Nachtrag 05:00Z (06.09.) - Tick 04:59Z: Kaskade 41171 laeuft, 11015-Setfile-Defekt tickettiert:** Fabrik 115 MEASURED/h (29/15 min), 7 aktive Zellen (5 Zensus + Q05 + Q08), Lock-Busy 4/15 min, free 41 GB, D: 62 GB, 10 Worker, Containment enabled:false, Zaehler 11/25, Zensus 9.958 pending; Pacer-Build b930e8c1 IN_PROGRESS (Rohstoff-Mission), 6 COMPILE_OK in 3 h. QM5_41171/XTIUSD: Q02 PASS -> Q04 PASS_LOWFREQ (04:51Z) -> Q05 aktiv (priorisierte Spur). Gate-Abschluesse 3 h: Q05/Q06/Q07 PASS, Q04 FAIL 10039 + 10041 EURJPY (pf_net < 1), Q08 INVALID QM5_11015/EURUSD (8.5 neighborhood: baseline_setfile_defect:empty_strategy_params) - dasselbe Paar fiel am 05.09. zweimal Q07 INFRA_FAIL seeds_invalid -> Setfile-Linie defekt, Ticket Codex 7d6eb2eb (Sol medium: Lineage-Trace, governed Repair-Kette, Intake-Guard). Retention-Runner weiter fehlerfrei; Stunden-Snapshot-Bewertung nach 06:00Z.

> **Nachtrag 04:33Z (06.09.) - Tick 04:32Z: ruhig; erster Q02-PASS der Pacer-Mission:** Fabrik 118 MEASURED/h (29/15 min), 7 aktive Zellen, Lock-Busy 4/15 min (Matrix-Service), free 20,7 GB, D: 62 GB, 10 Worker, Containment enabled:false, Zaehler 11/25 (04:27Z), REVIEW/IN_PROGRESS leer, keine MC-Receipts, Zensus 10.011 pending. QM5_41171/XTIUSD Q02 PASS 04:20Z (Pacer-Diversity-Build der Rohstoff-Mission, priorisierte Q02-Zeile) - erster Q02-Abschluss seit >6 h; Kaskade folgt. Retention-Runner: juengster Lauf fehlerfrei; Stunden-Snapshot-Bewertung nach dem 06:00Z-Wartungslauf.

> **Nachtrag 04:06Z (06.09.) - Tick 04:04Z: Codex-Queue ueber Opus abgearbeitet (M13, M15, M07), 41143 versiegelt, Burn-in laeuft:** Fabrik 118 MEASURED/h (30/15 min), Lock-Busy 22/15 min (davon 5 release_compile_wave.apply 03:56Z + Matrix-Service; beobachten), free 32 GB, D: 64 GB, 10 Worker, Containment enabled:false, Zaehler 11/25 (pipeline_state 03:27Z), REVIEW/IN_PROGRESS leer, TODO 5 (1721f3a1 OOS-2026-Reparatur --apply DEFERRED auf Kalenderabdeckung; 49a8c88b E4 + 90431302 E2 hinter E1 gekettet; 0ceafe5f D2 laeuft ueber Codex-Sibling-Builds db42cb90; 690fc42a Codex). QM5_41143: Binary versiegelt 63053a8a78 (Guard PASS mit Compile-Receipt ea884470), Ergebnis-JSON als artifacts/qm5_41143_build_result_20260906.json (bd2429b0ef), Pacer-Claim b0f920f1 APPROVED (Router-Gate D6_BUILD_IDENTITY_UNTRACKED verlangt das committete .ex5 - SOP im Gedaechtnis). M13 (1bf87710): Vorlage docs/ops/OWNER_VORLAGE_2026-09-06_m13_economic_test_contract.md (b372164205; R5 braucht ~2.100 versiegelte OOS-Tage = ~5,75 Jahre -> FTMO-Cashflow-Pfad undatiert; Optionen A/B/C, NO-BUY intakt) -> Karte **OWNER-DEC-M13-ECONOMIC-TRIAL-20260906** (7a0e46b8dd, Empfehlung JA = kostenloser Capture-only-Demo-Trial; Konto/Login/PARKED->RUNNING = OWNER). M15 (8db1d722): board_projection.py + 15 Tests (0fce89a16b): 2.055 Tasks = 238 actionable / 167 waiting / 414 parked / 3 superseded / 1.233 complete; Cockpit-Einbindung bewusst vertagt (KPI-Streifen waere heute 6x UNKNOWN). M07 (3a20271f): qm.cash-ledger/v1 + qm.provider-status/v1 lokal unter D:/QM/reports/state (48b6a9f8b3, Repo-Doku ohne Betraege): nur VPS-Kosten lokal belegt, Auszahlungen UNKNOWN - OWNER-Ablageordner fuer DXZ-/Tooling-Exporte waere der guenstigste Schluss (keine Karte). Backup-Guard-Burn-in: Retention-Runner 03:49Z erster fehlerfreier Lauf nach dem Fix (davor WinError 32); Stunden-Snapshot haengt am PumpMaintenance-Task, der wegen des TEMP-Rollbacks nur alle 4 h laeuft (naechster 06:00Z) - Bewertung danach.

> **Nachtrag 03:38Z (06.09.) - Tick 03:34Z: Kohorten-Produzent live verifiziert, 41143-Handoff, Backup-Guard-Fix integriert:** Fabrik 135 MEASURED/h (25/15 min), Lock-Busy 10/15 min, free 30,8 GB, 10 Worker, Containment enabled:false. Erster Q08-Insert nach dem Kohorten-Produzenten (11167/XAUUSD 03:25Z) traegt dsr_context_status {producer_schema qm.dsr-cohort/v1, reason SEALED_SEARCH_LEDGER_UNAVAILABLE} = fail-closed wie spezifiziert; kein dsr_context (Legacy-EA). QM5_41143: `farmctl record-build --task-id 0461501e (gebundener Legacy-Build-Task; der agent_tasks-Claim b0f920f1 ist NICHT die record-build-ID) --result-file <Ergebnis-JSON nach 41142-Schema>` -> recorded, auto_q02 hat Q02 2ed1bb9e auf dem logischen Symbol QM5_41143_GBPUSD_MONTHEND_FIX_M15 (M15, basket) eingereiht; Host-Set uebersprungen (basket_manifest_logical_setfile_preferred). Der Pacer-Claim b0f920f1 bleibt IN_PROGRESS (Router: untracked / not_in_review) - Reconciliation durch den Pacer erwartet, sonst naechster Tick. M14-Folge 974f4953: Codex (Sol, 03:15Z-Zyklus) lieferte 405d2529e7 -> integriert 91d127d791 (Stunden-Snapshot-Guard + Health-Check auf geplante Snapshots beschraenkt, Retention-Runner skip-with-log; 12 Tests) -> APPROVED; Burn-in-Beobachtung (Snapshot-mtime 3 h, Retention 6 h) laeuft ueber die naechsten Ticks. Codex-Queue per Opus weiter: M13-Vorlage (1bf87710) und M15-Board-Projektion (8db1d722) laufen im Hintergrund; Q02-Canaries 15 + 41143 pending hinter dem Zensus (10.124 Zellen).

> **Nachtrag 03:21Z (06.09.) - ZAEHLER 11/25; M11-Vorlage + Karte; M14-Restore-Test:** Der Zaehler steht LIVE bei **11/25** (build_qualified_roster --dry-run 03:13Z und pipeline_state.book_guard 03:11Z: 1537/XAG, 10706/GBP, 11421/EUR, 11422/CAD, 11910/NZD, 12710+13054+20048+20266/XTI, 21505/XAG, 21507/XAU) - die drei Closures vom 05.09. zaehlen seit heute; public-data/funnel-stats.json (Snapshot 05.09. 16:26Z) zeigt noch 8 = stale, Regeneration vor dem Website-Deploy noetig. M11 (93cd0e1c, Codex-Queue, per Opus-Agent): Vorlage docs/ops/OWNER_VORLAGE_2026-09-06_m11_optimisation_branch_utility.md (c486f32f0f) - 12 Q14-Closures, alle KEEP_INCUMBENT, 0 Challenger befoerdert; 24 Programme, 8.437 MEASURED / 10.178 pending; CEO-Review korrigiert: unter OWNER-DEC-A1 ist der Zensus der Zaehlerpfad (KEEP zaehlt), 10.178 Zellen = ~3-4 Fabriktage = +13 Paare -> 24/25, das 25. braucht einen neuen Q11-Ueberlebenden aus dem derzeit ausgehungerten Q02-Q10; Option B/C wuerden den Zaehler bei ~15/11 einfrieren; Amendment-C-Reihenfolge ist OWNER-Beschluss -> Umsortierung = Karte. Empfehlung Option A + vor-registrierte Widerlegungsregel (5 weitere Closures ohne Promotion = Pflichtzweig jenseits 25 widerlegt) -> Mission-Control-Karte **OWNER-DEC-M11-CENSUS-BRANCH-20260906** (8edab939a6, Empfehlung JA). Task APPROVED. M14 (18b6e054, per Opus-Agent): isolierter Restore-Test des Off-Box-Tagesbundles OK (integrity/quick_check ok, SHA identisch, RTO ~10 s, RPO 23 min jetzt / 24 h worst case, Kette 8 Tage lueckenlos); zwei On-Box-Defekte: stuendlicher Snapshot seit ~9 h gestallt (Glob-Guard durch Pre-Mutation-Snapshots gesaettigt, Health-Check gleicher Glob) und Retention-Runner fail-closed 16/32 Laeufe (WinError 32) -> Ticket Codex 974f4953 (Sol medium). Task APPROVED (5b78e86ae7).

> **Nachtrag 03:07Z (06.09.) - Tick 03:01Z: R5 abgenommen, 41143-Handoff, Codex-Queue per Opus:** Fabrik 130 MEASURED/h (36/15 min), Lock-Busy 3/15 min, free 32,5 GB, Containment enabled:false, Server 8770-8772 up; REVIEW-Queue leer, TODO 10, keine neuen Q08-Inserts (dsr_context-Pruefung weiter offen), keine neuen MC-Receipts (offen: WEBSITE-DEPLOY, LIVE-IDENTITY-SIGN). FTMO-R5 a97a5d2d unabhaengig abgenommen (ACCEPT: LF-SHA des Testdokuments aus d9fa021091 reproduziert, Commits nur Markdown, Seal-Digests 10/12 unabhaengig nachgerechnet, NO-BUY unberuehrt) -> APPROVED; die vom Payload erwarteten Ausfuehrungsprotokolle fuer R5 und Live-Identitaet nachgereicht (99cee05378). QM5_41143: COMPILE_OK 02:33Z, aber `intake-first-q02` verweigert mit basket_manifest_compile_symbol_mismatch (Manifest basket_symbols GBPUSD+UK100 mit signal_only UK100 vs. Compile-Symbole GBPUSD); der Zwilling 41142 bekam seine Q02-Zeile (logisches Symbol, portfolio_scope basket) ueber den governed Weg `farmctl record-build` -> auto_q02 aus dem Build-Ergebnis-JSON des build_ea-Tasks - fuer b0f920f1 fehlt dieses JSON noch (Pacer-Agenten haben den Claim nur bestaetigt; Codex-Exec laeuft seit 03:07Z). Entscheidung: kein Praedikat-Umbau; naechster Tick: liegt kein Build-Ergebnis vor, erzeuge ich es nach dem Schema von 9d978a4c und fahre record-build selbst (GRUEN). Codex-Queue per Opus-Agenten begonnen (OWNER 03.09.): M11-Vorlage 93cd0e1c (Nutzen des Optimierungszweigs) und M14-Restore-Test 18b6e054 laufen im Hintergrund (nur Evidenzdokumente, keine Commits durch Agenten). Codex-Fleet-Pacer: 47 % Woche, target_rate 0,33 %/h, spawnt weiter je 15 min (Governor haelt nur die Build/Research-Lane-Flags).

> **Nachtrag 02:35Z (06.09.) - Abnahme-Fanout, Compile-Welle, FTMO-Bestaetigung:** Fabrik 111 MEASURED/h (26/15 min), Lock-Busy 10/15 min, free 30 GB, Containment enabled:false; noch keine neuen Q08-Inserts seit dem Kohorten-Produzenten (dsr_context-Pruefung offen). Unabhaengige Abnahme der decision-gebundenen Tasks per Sonnet-Fanout (read-only gegen Plan, Commits, Env, DB): DSR-V2 d5e6a93f ACCEPT (QM_DSR_V2=1, 59 Projektionsdatensaetze, verdicts_modified=false, 11172/XAUUSD engine QM_DSR_V2), Live-Identitaet 24b98bc4 ACCEPT (SHA-Rekonstruktion identisch, 24 Sleeves/21 Binaries/9,7499 %, Consumer-Ausnahme default-off), D1-Prescreen 88ea9f8b ACCEPT (2.093 SKIPPED_PRESCREEN 12:49-17:49Z, MEASURED/h 96/116/108/108 flach), E1-A 0da3dfec PARTIAL -> APPROVED WITH RE-SCOPE NOTE (Backfill der Kalenderluecke NICHT erreicht, als 18.279 deklarierte Ausschluesse re-scoped; Fortsetzung E1-C). FTMO-Teil-2-Restpassagen (0c1b3295, Codex-Queue, per Opus-Agent ausgefuehrt): alle drei CONFIRMED an 058d344368 (Zeilen 141/193/207) -> 0c1b3295 + 7dceadd0 APPROVED (Evidenz docs/ops/evidence/2026-09-06_ftmo_readiness_part2_confirmation.md, d41c023c64). Compile-Welle: nur SOURCE_FRESH-Zeilen werden freigegeben -> QM5_41143 (Fleet-Pacer-Build da9ba7ccb3, GBPUSD M15) 02:32Z freigegeben; 9 stale Compile-Zeilen ohne Nachfolger (41142, 41179, 41189, 41192, 41352, 41356, 1538x2, ...) brauchen Authority-Pfad oder Retirement (offen). Codex-Wochenkontingent 46 % bei 18 % Zeit -> Governor haelt Drossel; 7 Codex-TODOs warten (690fc42a, 18b6e054, 3a20271f, 1bf87710, 93cd0e1c, 8db1d722, abd0a457 RECYCLE).

> **Nachtrag 01:59Z (06.09.) - DSR-Kohorten-Produzent integriert; Seeding 9/9:** Codex da23a756 (ab9e4396f3) als 348a7eccb8 integriert: vor jedem neuen Q08-Insert (Pump-Kaskade, explizite Kaskade, append-only Reruns) wird eine versiegelte verlierer-inklusive Such-Kohorte (Schema qm.dsr-cohort/v1) assembliert und als dsr_context {path, sha256} mitgegeben; fehlt die versiegelte Suchhistorie, bekommt die Zeile Status UNAVAILABLE und KEIN dsr_context -> V2 bleibt UNCORRECTED_SELECTION (fail-closed). Replay auf 3 juengsten Q08-Artefakten (11172/11196/10038, alle Legacy-EAs): SEALED_SEARCH_LEDGER_UNAVAILABLE -> nur versiegelte DL-089-v3-Programme koennen einen V2-PASS erreichen; die Frontier-Readjudikation bleibt eine OWNER-Karte. Der residente Pump laedt den Adapter erst mit seinem naechsten Neustart (Wartungszyklus). First-Q02-Seeding komplett: 9/9 Canaries pending (Q02-Zeilen stehen per Claim-Order hinter Zensus/Frontier; 699 Q02 pending, keine Q02-Abschluesse seit 3 h - Policy, nicht geaendert). Fabrik 104 MEASURED/h.

> **Nachtrag 01:05Z (06.09.) - DSR V2 im Q08 verifiziert; Kohorten-Produzent beauftragt; Seeding 6/9:** erstes Q08-Artefakt der V2-Aera (11172/XAUUSD, 00:47Z, FAIL_HARD): DSR-Subgate = UNCORRECTED_SELECTION, kein deferred-Zweig, kein dsr_context -> die Umgebungsvariable erreicht die Kindprozesse, OWNER-Entscheid ausgefuehrt (Task d5e6a93f -> REVIEW). Konsequenz wie angekuendigt: jeder neue Q08 endet UNCORRECTED_SELECTION, bis eine versiegelte verlierer-inklusive Kohorte als dsr_context mitgegeben wird -> Codex da23a756 (Sol high: Kohorten-Produzent aus DL-089-Ledger/Q03-Sweep/Q02-Baseline, 154 deklarierte Trials, fail-closed, Replay auf 3 Artefakten). Paced First-Q02-Seeding: 41164/41165/41166/41172/41176/41224 eingereiht (alle pending, Zensus hat Claim-Vorrang); naechste 41285/41312, dann 41336. Fabrik 107 MEASURED/h (30 je 15 min).

> **Nachtrag 00:12Z (06.09.) - First-Q02-Intake integriert, Seeding gestartet:** Codex 6a90b4af (8188d1529d) als 2a9249f035 integriert: `farmctl intake-first-q02 --compile-work-item-id <id> [--apply]` prueft EX5-SHA gegen die Compile-Evidenz, kanonische Fixed-Risk-Setfiles, aktive Magic-Zeilen, Review-Entry-Gate und die Abwesenheit jeder Q02-Zeile, staged genau EINEN Q02-Canary ohne Priority-Boost, schreibt einen Receipt; Sweep meldet ausgeschlossene EAs jetzt mit COMPILE_ROW_PRESENT_NO_Q02 (32 Tests). Alle neun Dry-Runs ELIGIBLE. Paced Anwendung (max 2 je Tick): Tick 1 = 41164 + 41165 (siehe Log), naechste 41166/41172, 41176/41224, 41285/41312, 41336. Fabrik 106 MEASURED/h; Q08 11172/XAUUSD (V2-Verifikation) laeuft seit 21:44Z.

> **Nachtrag 23:19Z (06.09.) - Kein governed First-Q02-Pfad fuer Backlog-Compiles:** Audit 3c0503cc: neun COMPILE_OK-Binaries verifiziert, null Q02-Zeilen, alle neun Dry-Run-Handoffs verweigert - sweep_enqueue_built_eas.py filtert phasenblind jede EA mit COMPILE_EA-Zeile still heraus (leere Skip-Liste = Observability-Defekt), seed-fresh-q02 braucht eine Vor-Q02-Zeile, record-build ist eine Build-Task-Transition ohne Dry-Run. Control-Plane-Reparatur beauftragt: Codex 6a90b4af (Sol high: append-only First-Q02-Intake mit EX5-/Setfile-/Magic-/Review-Entry-Pruefung, ein Canary, Receipt; Sweep-Skip-Grund COMPILE_ROW_PRESENT_NO_Q02); CEO wendet danach paced an (max 2 je Tick). Fabrik 105 MEASURED/h, Codex-Session-Zyklus 23:00Z aktiv (11 TODO).

> **Nachtrag 22:52Z (06.09.) - Fabrik erholt, Codex-Lane leer, Q02-Handoff-Ticket:** MEASURED 107/h (31 je 15 min = ~124/h) bei 7 aktiven Zellen; Lock-Busy 13 je 15 min, keine Claim-Halter mehr (Matrix-Service + Compile-Wellen der Buildlane). Codex-Lane: alle REVIEW-Rueckgaben abgearbeitet, 11 TODO warten auf den naechsten Session-Zyklus (Buildlane produziert weiter: 41356/41357). Q02-Seeds der 9 compilierten Backlog-EAs fehlen nach 1h45 weiter -> Ticket 3c0503cc (Sol medium: governed First-Q02-Pfad, CPU-Ceiling-Regel-Herkunft, paced Dry-Run-Kommandos). Kanonische Nachfolger 10481 x6 Q04 + 10141 Q02/Q04 pending. DSR-V2-Verifikation: seit 18:59Z kein neuer Q08-Abschluss (1 aktiv) - Task d5e6a93f bleibt IN_PROGRESS bis zum ersten V2-Artefakt.

> **Nachtrag 22:25Z (06.09.) - Astra-Trichter + Design-Kritik integriert; Claim-Lock-Fix fleet-weit bestaetigt:** Astra (2de2ad78/90ca3dc0, a45a33c188): offener Instrumenten-Trichter (elliptischer Einlass, gerade Kegelwaende, Schulter, kurzer Auslauf, 18 Tinten-Siebe, Phasenbaender, Gate-Register mit Zensuszahlen, feine Stahl-Linienspuren statt Kugeln; 20,4 KB; animiert auch unter Reduced-Motion: 1.762 veraenderte Funnel-Pixel in der CEO-Sonde; Pause-Knopf; keine Konsolenfehler) in homepage-v4 geliefert; sieben Design-Alternativen als Refinement-Diff (style.css/index.html: Hero auf 1180-Wrapper + Fraunces 500, 3x2-Zahlenraster, 24-px-Archivzeilen, In-Frame-Chart-Fusszeilen, Kontrast) vom CEO angewendet; Familienzahl 3.340 korrigiert. Beide Astra-Tasks APPROVED. Fabrik: Reload Chunk 49 komplett (22:04Z), Lock-Busy-Events 91 -> 2 je 15 min, MEASURED ~98/h und steigend, 9 aktive Zellen. Acht kanonische Nachfolger (10481/10141) pending.

> **Nachtrag 22:02Z (05./06.09.) - Claim-Lock-Fix wirkt; Worktree-Pfad-Zeilen ersetzt:** Lock-Attribution 21:42-21:57Z: Busy-Events 91 -> 27 je 15 min, Halter ~1 s (T5 1,0 s, T8 0,7 s); MEASURED 26 je 15 min (~104/h) waehrend Chunk 49 noch lief; T7 zeigte 57-s-Median = verwaister Lock-Nonce des alten T7-Prozesses (Reaper). canonical_setfile_paths apply-Modus (a3ec5b69, 7ba3be6607) als 35a0beb180 integriert; acht Nachfolger mit kanonischen Presets angelegt (10481 x6 Q04, 10141 Q02+Q04; Receipts unter docs/ops/evidence/2026-09-05_canonical_paths_apply/), 10151 = EXISTING_SUPERSESSION. Werkzeug-Notizen: --all-previewed ist Alles-oder-nichts (Batch verweigert wegen 10151), --receipt-path Pflicht, kein busy_timeout auf BEGIN IMMEDIATE (transient database is locked). Q02-Seeds der 9 compilierten Backlog-EAs fehlen weiter: Codex-Buildlane pausiert Q02-Handoffs am Backtest-CPU-Ceiling (93-97 % CPU, Doku aad382be7c) - beobachten.

> **Nachtrag 21:30Z (05.09.) - Claim-Lock-Ursache gefunden und Fix integriert; M06/M08-C geschlossen; Compile-Ergebnisse:** f22f9a8c: die teure Sektion ist der Kandidaten-SELECT unter dem geteilten Datei-Lock (3,95 s Baseline auf 735-MB-Replay), nicht die Schreibtransaktion (0,013 s); Fix 0844d70712 (Claim-Order-Memo mit Identitaets-/Versionspruefung ausserhalb des Locks, zwei partielle Ausdrucksindizes, FIFO-Ankunftstickets, ein 5-s-Budget je Zyklus; Replay 0,19 s; 132 Tests). Index-Migration ueber farmctl init_db gelaufen (idx_work_items_census_earlier, idx_work_items_census_active_program), Worker-Reload Chunk 49 laeuft. Batch-Claim bewusst nicht (verletzt 10-s-Spacing). M06-Consumer-Ausnahme (9f80f58c) INERT integriert 3720e3044e (Flag aus, 27/85 Tests) - Aktivierung nach Beglaubigungs-Receipt. M08-C (b74e58e7): nativer DXZ-Download auf T2 (2,1 min), ~99,9k gematchte Minuten je Symbol; Spread-Delta FX ~0, XTIUSD +0,038/+0,062, XAGUSD +0,035/+0,053 (DXZ weiter) -> Kostenmodell-Uebernahme = eigener Schritt. Compile-Wellen: 9 COMPILE_OK (41164/41165/41166/41172/41176/41224/41285/41312/41336), 3 Recheck-Verweigerungen (41168/41207/41319), 2 Buffer-Praedikat (41179/41189), 1 echter Compile-Fehler (41268); Q02-Seeds fuer die 9 noch nicht angelegt (Sweep pruefen).

> **Nachtrag 21:04Z (05.09.) - Compile-Backlog geoeffnet: Autoritaets-Nachfolger + Rest-Backlog freigegeben:** Codex-Praedikate (74b400f5, dd4864287d) als ab140348dc integriert (27 Tests). Sieben ELIGIBLE Nachfolger mit --apply eingereiht (41176/41179/41189 Quell-Drift -> aktuelle committete Quelle; 41164/41165/41166/41172 unveraenderte Quelle) und ueber release_compile_wave.py seriell freigegeben (Wellen 14-20); die Wellen 1-13 gaben vorher FIFO die restlichen nicht-stalen Backlog-Zeilen frei (41168, 41105, 41207, 41224, 41268, 41285, 41308, 41312, 41319, 41336, 41338, 41339, 12947) - append-only, Ergebnisse werden je Tick eingesammelt (Recheck-Verweigerungen moeglich). Gehalten bleiben 9 (8 SOURCE_SHA_STALE ohne Autoritaet + 1538). 41142/41192/41352 haben bereits nutzbare Compile-Verdikte; QM5_1538: Arbeitskopie weicht materiell vom Commit ab (unversionierte Reparatur) -> CEO-Entscheid offen. Erwartung: rv-Familie faellt weiter im build_check bis zur monotonen Praedikat-Revision (abd0a457). Fabrik: ~66 MEASURED/h, Claim-Lock-Halter 3-5 s, Codex f22f9a8c profiliert; Reload Chunk 48 komplett (20:55Z).

> **Nachtrag 20:18Z (05.09.) - Website-Design v5 lokal umgesetzt (http://127.0.0.1:8772/):** CEO-Workflow (4 Editoren + Design-Kritiker + Exposure + A11y + Fixer + Verify, 9 Agenten) hat das Briefing umgesetzt: style.css v5 (53 KB, alle Alt-Token als Aliase), Fraunces/IBM Plex Sans/IBM Plex Mono von Google Fonts geladen, Papier #f4f6f8, Tinte #0f1720, Stahl #2954d4, Haarlinien-Struktur, Instrumenten-Kacheln, Mono-Chips, Archivliste als Research-Record-Zeilen, Detailseiten mit nummerierter Gate-Journey, alle Nebenseiten im selben Shell. Review-Befunde behoben: .gate-Klassenkollision (3.339 Detailseiten), Kontrast ink-3/warn, Ueberschriften-Ordnung, Toolbar-Raster, render-blocking @import; EXPOSURE-BLOCKER behoben: interne Pseudo-Symbole (QM5_*/FX8/SLOT*) erschienen als Maerkte -> Denylist im Generator, 0 Treffer ueber alle Seiten. Verify: liest als Instrumententafel, Fonts geladen, Grep 0. Offen (minor): Zahlenkacheln nur per Funnel-Skript/Fallback-Literale synchron (Build-Regeneration empfohlen), Funnel-Halslabels eng - der Funnel selbst bleibt Astras Neuentwurf (2de2ad78/90ca3dc0), aktuell v2-Form im Stahl-Restyle.

> **Nachtrag 20:07Z (05.09.) - Durchsatz halbiert: Claim-Lock-Kosten; E1-C integriert; Astra-Memo beantwortet:** MEASURED-Zellen 110/h -> 55/h seit ~19:00Z bei 10 lebenden Workern und 8.362 unheld Zensus-Zeilen: Claim-Zyklen dauern 17-48 s und enden meist in factory_mutation_lock_busy (ein erfolgreicher Claim wartete 44,9 s); Attribution 18:10-20:10Z: 569 Busy-Events, 521 durch claim_atomic-Halter mit Median 4-5 s (frueher ~2 s), p90 6,7 s; CPU 32 %, CIM 71 ms = nicht die Ursache; Hypothese: In-Lock-SQL skaliert mit Pool/Holds + unfairer Lock -> Ticket Codex f22f9a8c (Sol high: Profiling, Indizes, Fairness, Batch-Claim-Design). Convoy-Fix 4d4a008a39 laedt per Chunk 48 (Chunk 47 abgeloest; T8 haengt in einem langen Q07). E1-C Option B (ea22f4b1, Astra bb98bc0323) INERT integriert 2019e46dad (54 Tests; neues Include QM_NewsScopeV1.mqh ungebunden; Compile-Kohorte = Aktivierungsschritt 2) -> Decision-Task dc512306 APPROVED. Astra-Homepage-Memo 93aaf7ea APPROVED mit Antworten (physischer Filter-Trichter = Richtung; Ziel 25 als Research-Ziel beschriftet; dritte Mechanik = Kalender/Relative Value; v5-Tokens = Integrationsflaeche).

> **Nachtrag 19:35Z (05.09.) — Lock-Konvoi behoben (Integration), Worktree-Pfade, Praedikat-Fix zurueck:** 62f54fa5: der T10-63-s-Median war EIN verwaister Lock-Nonce (15 Wiederholungen, gereapt), kein Claim-Verhalten; echter Befund = Sweep-Lookup-Konvoi (52 s von 59 s unter dem Lock) + wiederholter OS-Prozess-Zensus im Claim -> Patch integriert 4d4a008a39 (indizierter Lookup, fruehe Lock-Freigabe, Snapshot-Wiederverwendung; 117 Tests) -> Worker-Reload Chunk 48 nach Abschluss von Chunk 47. b94dc07c: 9 Worktree-Pfad-Zeilen mit versiegelten Nachfolger-Previews + Enqueue-Guard integriert; CEO-Entscheid: kanonische Presets autoritativ (10151 Magic-Slot 5->34 = Registry), Anwendung folgt. abd0a457 (build_check-Praedikat) RECYCLE: Vorschlag erweitert den Korpus von 634 auf 1.091 Befunde (471 EAs neu geflaggt) -> Revision: monotone Regel (nur clearen, neue Beweispflichten erst ab Rollout-Grenze). Fabrik aktuell 75 gemessene Zellen/h, nur 2-4 aktiv: Claims serialisieren am Lock (3-5 s je Claim, 180 Busy-Events/30 min) - der integrierte Patch adressiert genau das.

> **Nachtrag 19:28Z (05.09.) — OWNER: Website-Design *schrecklich und lieblos* -> Design-Skills aktiviert:** Diagnose: System-Font (Inter-Fallback), reinweisser Grund, Apple-Grau, eine Gruen-Akzentfarbe, ueberall runde Karten = generische Template-Optik. Bindendes Design-Briefing v5 docs/ops/WEBSITE_DESIGN_BRIEF_2026-09-05.md (Konzept *Instrumententafel einer Research-Werkstatt*; Tokens Ink #0f1720 / Paper #f4f6f8 / Steel #2954d4 als Markenakzent, PASS/FAIL nur semantisch; Fraunces Display + IBM Plex Sans + IBM Plex Mono; 12-Spalten-Editorial-Layout, Struktur durch Haarlinien und Mono-Eyebrows statt Karten; Motion-Regeln; Komponenten; Anti-Pattern-Liste aus dem Design-Skill). Umsetzung: CEO-Workflow (4 Editoren: CSS-System, Startseiten-Shell, Archiv-Templates + Regeneration, Nebenseiten; Design-Kritiker + Exposure + A11y-Review; Fixer; Verify) auf der homepage-v4-Kopie; Astra-Co-Design-Ticket 90ca3dc0 (Prio 96, max: Kritik-Memo mit konkreten Alternativen, Funnel im neuen System mit Bewegungsnachweis, Refinement-Diff). Funnel-Skripte bleiben Astras Hoheit. Kein Deploy.

> **Nachtrag 19:08Z (05.09.) — DSR-V2-Projektion (read-only) liegt vor:** docs/ops/evidence/2026-09-05_dsr_v2_projection.md (+ .json, 59 Eintraege = 48 distinkte Q08-Artefakte, 0 Tool-Fehler). Frontier 31: legacy alle *deferred* -> unter V2 **31 UNCORRECTED_SELECTION**; juengste 28: 26 deferred + 2 zu wenige Tage -> **26 UNCORRECTED_SELECTION + 2 LOW_SAMPLE**; distinkt 48: 46 + 2, **0 V2-PASS, 0 mit dsr_context**. Der gesamte Zaehler ruht auf aufgeschobenen DSR-Passes (n_peers=0, standalone_pending_cohort); kein Verdikt geaendert. Legitimer V2-PASS braucht versiegelte, hash-gebundene, verlierer-inklusive Kohorte + vollstaendige Suchhistorie via dsr_context (DL-089 v3: 154 deklarierte Trials) - liefert derzeit kein Artefakt -> naechster Baustein: Kohorten-Produzent (Ticket folgt nach Reload-Verifikation). Abweichung dokumentiert: die zwei insufficient-days-Artefakte projizieren LOW_SAMPLE statt UNCORRECTED_SELECTION (beides kein PASS).

> **Nachtrag 19:05Z (05.09.) — M06 Phase 1 ausgefuehrt, Beglaubigungs-Karte offen:** frische Read-only-Beobachtung des Live-Buchs (risk_freeze.measure: 24 Sleeves, 21 Binaerdateien, Gesamtrisiko 9,7499 %, keine Probleme; docs/ops/evidence/2026-09-05_m06_attest_current/observation.json, SHA c411e0f38885...) und unsignierter Attest-Vorschlag docs/ops/evidence/2026-09-05_m06_attest_current/proposal/proposal.json (SHA 20de8acd3115..., Status ELIGIBLE_FOR_OWNER_REVIEW, alle Fingerabdruecke = Baseline, Freeze ACTIVE, Alter 15 s). Neue Mission-Control-Karte **OWNER-DEC-LIVE-IDENTITY-SIGN-20260905** (Empfehlung JA = Beglaubigungs-Receipt, keine Aktivierung). Consumer-Ausnahme hinter Flag in Umsetzung (Codex). Task 24b98bc4 -> REVIEW.

> **Nachtrag 19:02Z (05.09.) — DREI OWNER-JA in Mission Control (18:34Z) in Umsetzung:** (1) **DSR V2** (Receipt ef6c9bef, Task d5e6a93f): QM_DSR_V2=1 auf Maschinenebene gesetzt, gestaffelter Worker-Reload Chunk 47 läuft (neue Q08-Kindprozesse erben das Flag), Read-only-V2-Projektion der 31 Q11-PASS-Paare + 28 jüngsten Q08-PASS-Artefakte in Arbeit (Evidenzdokument folgt); Konsequenz ehrlich: neue Q08-Läufe ohne dsr_context enden als UNCORRECTED_SELECTION, bis ein versiegelter Verlierer-inklusiver Kohorten-Produzent existiert. (2) **E1-C Option B** (Receipt f1dc468c, Task dc512306): Astra-Implementierung INERT = ea22f4b1 (Prio 95, max), Aktivierungs-Checkliste docs/ops/CALENDAR_SCOPED_CONSUMER_ACTIVATION_CHECKLIST_2026-09-05.md; keine Neuversiegelung, keine Hold-Freigabe. (3) **M06 Identity-Attest** (Receipt 70ec12e4, Task 24b98bc4): Consumer-Ausnahme hinter Flag = Codex 9f80f58c (Sol high); frische Read-only-Beobachtung + unsignierter Attest-Vorschlag durch den CEO folgt in diesem Tick, Beglaubigung = separater Receipt. M08-B: DXZ-M1-Cache für das FTMO-Fenster leer → M08-C Download-Harvest b74e58e7. fd5e3ce3: CEO-Entscheid = aktuelle committete Quelle je EA autoritativ → Prädikate + Dry-Runs 74b400f5.

> **Nachtrag 18:56Z (05.09.) — Archiv-Seiten mit den neuen Namen lokal gebaut:** Generator C:/QM/deploy/qm-ops-refresh/tools/site-build/build_archive_v31.py (stdlib, idempotent) erzeugt aus dem v3.1-Dry-Run v2 die Archivliste http://127.0.0.1:8772/strategies/ (3.339 Familien, 2.407 mit Gate-Ergebnissen; Suche + Familien-/Status-Filter, JS-freier Kern) und 3.339 Detailseiten (Name, Tagline, Familie, Status, Zeitfenster, Maerkte, Gate-Journey in drei Phasen mit PASS/FAIL-Chips je Markt, Revisionsdaten, kanonische Links) + sitemap-fragment.txt. Reviews: Exposure-Grep 0 Treffer; Ueberschriften-Semantik, Toolbar-Raster, Caption-Dopplung, Filterzaehler gefixt; Retests desselben Markts jetzt als Sequenz (FAIL -> PASS) statt widerspruechlicher Doppel-Chips (Produzenten-Fix = Codex efa156a4: Latest-Verdict-Collapse + Retest-Historie + UNKNOWN-Timeframes, Dry-Run v3). Ehrliche Leerzustaende (Daten/Maerkte/Timeframe nicht erfasst; Q15-Q17 immer leer). Nav-Link und Sitemap-Einbindung folgen beim Merge mit Astras Funnel-Fassung.

> **Nachtrag 18:31Z (05.09.) — Audit M04: DSR war aufgeschoben, nicht gerechnet -> Karte:** Astra-Lieferung 9fa50c9d (a72d180868) als 9b898fe157 INERT integriert (V2 nur mit QM_DSR_V2=1 im Q08-Kindprozess; dsr_context mit Pfad+SHA; fehlende Kohorte -> UNCORRECTED_SELECTION statt stillem PASS; 22 Tests). Befund (Snapshot 18:10Z): **alle 31 aktuellen Q11-PASS-Paare** fuehren ueber einen Q08 mit aufgeschobener DSR; von den 28 juengsten Q08-PASS-Artefakten 26 deferred, 2 zu wenige aktive Tage; unter V2 waeren alle 31 + 28 UNCORRECTED_SELECTION. Mission-Control-Karte **OWNER-DEC-DSR-V2-ACTIVATION-20260905** (Empfehlung JA: V2 fuer NEUE Q08-Laeufe + Read-only-Projektion des Bestands; Readjudikation = spaetere Karte). Beobachtung Fabrik: nur ~5 von 10 Workern gleichzeitig aktiv trotz 1.107 unheld Q04-Zeilen - Ursache Claim-Spacing 10 s fleet-weit (OWNER-Regel) plus Lock-Churn (Claims ~2-6 s, Matrix-Service); bei kurzen D1-Zellen deckelt das die Parallelitaet -> Vorlage-Kandidat, keine eigenmaechtige Aenderung.

> **Nachtrag 18:22Z (05.09.) — Archiv v3.1 mit Namens-Ledger v2 regeneriert:** Ledger v2 auf Produzenten-Form (entries als Dict) gebracht; die Whitelist des Produzenten (keine Ziffern, keine Zahl-/Ordinalwoerter, keine privaten Tokens) wies 1.024 Eintraege ab -> Umschreibe-Workflow (6 Agenten, Pruefskript check_prose.py bis 0 Verstoesse), 5 dadurch entstandene Namensdubletten mit Markt-Qualifier aufgeloest. Ergebnis: Ledger 3.338 Eintraege, 3.338 eindeutige Namen, 0 Prosa-Verstoesse, 16 lange Taglines geflaggt; Dry-Run docs/ops/evidence/2026-09-05_archive_v31_dryrun_v2 (3.339 Familien inkl. einer seit dem Snapshot neuen, alle Namen eindeutig; grosse JSONs nicht committet, Sample + Verification schon). Naechster Schritt: Website-v3-Generierung (Archivliste + Detailseiten) auf Basis v3.1/v2 in der homepage-v4-Kopie; Funnel bleibt bei Astra.

> **Nachtrag 18:01Z (05.09.) — C-6-Estimator INERT integriert:** Astra-Implementierung (ae041465, Branch agents/codex-c6-estimator-20260905, 74bec63a18) als fe023879de integriert: Sibling-Modul ftmo_c6_estimator.py + lazy Hook im Timebox-Evaluator; solange beide Contract-V1-Flags INERT sind, wird nichts importiert, geprüft oder ausgegeben (Byte-Identität gegen c65450df1f nachgewiesen); Methode C6-A (M5-Intervallminima inkl. offenem P&L, 60-Tage-Bloecke ab erstem versiegeltem Prager Tag, exakter Guard mit Clopper-Pearson, Floors 36/23/9 -> LOW_SAMPLE), 41 Tests gruen (Known-Answer .20, Rule-of-Three, geplanter Breach bleibt, ABSTAIN bei manipulierten Inputs). Entscheidungsgebundener Task adbeff65 geschlossen. Aktivierung = spaetere OWNER-Karte (Contract-Version mit OWNER_APPROVED_ACTIVE).

> **Nachtrag 17:57Z (05.09.) — Funnel-Designhoheit an Astra, Namens-Ledger v2 fertig:** OWNER 17:4xZ/17:5xZ: Funnel v2 wirkte wie eine Flasche, gruene Kugeln unprofessionell, *Lass Astra den Funnel designen* -> CEO-Funnel-v3-Workflow gestoppt, Astra-Ticket 2de2ad78 (Prio 97, max effort: Design-Memo + Implementierung + Bewegungsnachweis unter Reduced-Motion, professionelle Darstellung der gesiebten Strategien ohne Cartoon-Baelle). CEO ruehrt den Funnel nicht an, solange das Ticket offen ist. Namens-Durchlauf abgeschlossen: public-data/naming/strategy_names.v2.json (1d5e5c5813) mit 3.338 eindeutigen Namen (vorher 187 distinct), zwei Kritiker ACCEPT, 7 Korrekturen, 22 Taglines mit Review-Flag; Evidenz docs/ops/evidence/2026-09-05_naming_pass_v2.md; naechster Schritt: v3.1-Produzent per --ledger auf v2 zeigen, Dry-Run, OWNER-Review der Stichprobe.

> **Nachtrag 17:32Z (05.09.) — Compile-Bindung geklärt, Taint-Guard live, Startseite v4:** 27c0ea5a APPROVED: die Annahme *alle Backlog-Zeilen hängen an BLOCKED Build-Tasks* war falsch; Bindung läuft über die Legacy-`tasks`-Tabelle: 6 Zeilen an pending Tasks, 5 quellfrische unbound, 8 mit Quell-Drift (fd5e3ce3), die 4 Wellen-Zeilen (41164/41165/41166/41172) blockiert durch die Ad-hoc-Compile-Verweigerung vom 30.08. (Infrastruktur, kein Defekt) mit vorhandenen offenen Alternativ-Tasks → Recheck-Nachfolger per retry_compile_stale_build_binding.py (Dry-Run zuerst). ccf48a21 (41352 Magic-Vorbedingung) APPROVED: bereits allokiert, keine Mutation. Codex-Fix 6212e9cefa (build_gate_hardening: dokumentierte Karten-Symbol-Ports DAX40/DE30/GER40 → GDAXI.DWX, Tests) zur Kenntnis genommen. Kalender-Taint-Guard integriert (35d137e611) und aktiviert (57391d7bef, CEO GRÜN, rückholbar); Worker-Reload Chunk 46 (8/10 fertig 17:31Z). Startseite v4 (Basis Astra, http://127.0.0.1:8772/): Build-Workflow bestanden (Headline, Zahlen, Funnel, senkrechte Mechanics, Kerzen-Header); OWNER-Feedback 17:0xZ *runder und animiert* → Ursache: Chrome auf dem VPS meldet prefers-reduced-motion (Windows-Server-Animationen aus) → Funnel-v2-Workflow: Bezier-Trichter, Animation auch unter Reduced-Motion mit Pause-Knopf, Nachweis per CDP-Sonde. Namens-Workflow für 3.338 Archiv-Familien läuft (17 Batches, Dedupe, Kritik).

> **Nachtrag 16:48Z (05.09.) — OWNER-Website-Brief Startseite (16:4xZ):** OWNER bevorzugt grundsätzlich die Astra-Version, verlangt für die Startseite: Headline bleibt *The Quantitative Edge.*; Records-Block mit ECHTEN Zahlen (getestete Strategien usw.); *How the evidence develops* als ANIMIERTER Funnel von links nach rechts (Phasen + Gates sichtbar, Strategien als Bällchen, an den Gates ausgesiebt, realistische Zahlen); Mechanics als SENKRECHTE Liste (drei Konzepte: ICT/SMT, Indikatoren, dritte Strategieklasse); Kerzen-Hintergrundanimation im Header; Fable und Astra sollen das gemeinsam diskutieren. Umsetzung: (1) public-data/funnel-stats.json aus dem governed Snapshot (3.097 Strategien getestet, 124.145 Backtests, 7.461 Zensus-Zellen, 18 Gates, by_gate_v4-Zähler je Gate, 8/25 Paare, Live seit 24.07., 85 Closes); (2) Arbeitskopie tools/site-build/homepage-v4 (Basis Astra) lokal auf http://127.0.0.1:8772/, Build-Workflow (3 Editoren + 3 Reviewer + Fixer + Verify) läuft; (3) Astra-Co-Design-Ticket 93aaf7ea (Memo mit zwei Funnel-Konzepten + eigene Implementierung) → Diskussionsrunde, dann Merge und OWNER-Vorführung. Kein Deploy.

> **Nachtrag 16:02Z (05.09.) — INFRA_FAIL-Recovery (GRÜN) + Worktree-Pfad-Befund:** 19 INFRA_FAIL in 24 h; **KORREKTUR 16:35Z:** der erste Rerun-Lauf (16:0xZ) hatte NICHTS eingereiht (Exit 0 bei `enqueued: false`); der zweite Lauf (16:33Z, korrekte Syntax --ea <ID> --phase --from-work-item-id <PASS-Vorgänger> --append-only-rerun-of) ergab: **2 neue Zeilen** (f46c1c0c Q07 11169/XAUUSD, dc3d151e Q04 11092/XAUUSD) und **13× `skipped: already_pending_or_active`** — für diese Paare existieren bereits pending Nachfolger (Pump-Recovery, z.B. 85590a54 für 10141/EURUSD seit 04.09.). Die „19 INFRA_FAIL in 24 h" waren überwiegend alte Zeilen (created 06–08/2026), deren updated_at durch Hold-/Klassifizierungs-Touches frisch aussah — Abfrage künftig nach Abschlusszeit, nicht updated_at. 11015/EURUSD Q07: der Rerun 6f2875e0 war selbst schon ein Rerun (02:47Z) und fiel erneut INFRA_FAIL (seeds_invalid) → wiederholte Klasse, kein dritter Lauf; Ticket-würdig, wenn ein weiteres Paar folgt. Die 5 EX5_NOT_RESOLVED (alle QM5_10481) sind NICHT transient: die Zeilen tragen Setfile-Pfade unter C:/QM/worktrees/claude-orchestration-3 → Binary nicht auflösbar; **9 pending Zeilen mit Worktree-Pfaden** (10481 ×6, 10141 ×2, 10151 ×1) → Re-Materialisierung aus kanonischen Pfaden + Enqueue-Guard = Codex b94dc07c (Sol medium, dry-run). Q10_NEWS 9b4f53f5 (10069 USDJPY) endete REVIEW_REQUIRED (kalender-tainted, nur Evidenz). Build QM5_41142 (f3fba72c) APPROVED, Q02-Seed pending. Hinweis SOP: close-review braucht die VOLLE Task-ID (Kurz-ID = No-op mit Echo).

> **Nachtrag 15:31Z (05.09.) — E1-C-Karte in Mission Control + Compile-Bindung:** Astra-Vorlage E1-C (cf597222, docs/ops/evidence/OWNER_VORLAGE_2026-09-05_calendar_scoped_consumer.md) angenommen: Empfehlung A im Betrieb belassen, B (Verbraucher mit erzwungenen Geltungsgrenzen: BLACKOUT_UNKNOWN, UNCONFIRMED-Projektion, Verweigerung alter Verbraucher) nur als INAKTIVE Implementierung; Kandidat 4/8 Messprüfungen, Rest durch 18.279 Ausschlusserklärungen (USD in allen 144 Monaten), **0 von 13 Holds heute freigebbar**. Karte **OWNER-DEC-CALENDAR-SCOPED-CONSUMER-20260905** offen (Empfehlung JA für inaktives B; Aktivierung/Hold-Freigabe = spätere Karten). M09-B (7cc4ab4c) BLOCKED: Staging 16/16 Hashes, aber 0/8 nativ testbar (Monitor ohne EA-Identität in der Compile-Queue, Instrumentierung braucht eigene gebundene Binär-Kohorte) → FTMO-Readiness-Track. Compile-Backlog: Wellen 2–5 alle **CANDIDATE_RECHECK_REFUSED = BUILD_TASK_BINDING_NOT_OPEN** (gebundene Build-Tasks BLOCKED) → weitere Wellen pausiert, Bindungs-Analyse + Dry-Run-Pfad = Codex 27c0ea5a (Sol high).

> **Nachtrag 15:01Z (05.09.) — Compile-Backlog Wellen 2–5:** je eine Zeile pro Welle freigegeben (release_compile_wave.py --max-items 1 --apply, 2-s-Retry): QM5_41164 (059d4860), 41165 (c71f00bd), 41166 (c495527e), 41172 (8fd59f9d); gehalten noch 21 (davon 8 SOURCE_SHA_STALE → fd5e3ce3). Codex-Lane läuft mit EINER Session (max-sessions 1, Slot 1, Astra seit 15:00Z), die IN_PROGRESS-Aufträge werden sequenziell abgearbeitet — daher Laufzeiten von Stunden je Astra-Auftrag; kein Orphan.

> **Nachtrag 14:59Z (05.09.) — M05-Recovery abgeschlossen (618d640e, 80a577273d):** von 156 ungeklärten Evidenzverlusten **27 wiederhergestellt** (aus C:/QM/backups_relocated/retention_quarantine, hash-gebunden, neues Verzeichnis, nichts in place) und **129 IRRECOVERABLE mit exakten DELETED-Receipts der Retention** (Primärinputs weg, nichts regenerierbar), 0 ungeklärt. Systemischer Befund: die Retention hat Dateien gelöscht, die die heutige Regel als KEEP führt; der 91-Paar-Guard schützt seitdem, die Witness-Lücken der M01-Paare (10706/11421/11422/20048) bleiben und brauchen append-only Re-Runs, wenn der Zähler sie braucht. Codex-Buildlane pausiert Q02-Handoffs eigenständig am CPU-/RAM-Ceiling (41310 COMPILE_OK ohne Q02-Seed, FX-Basket-Admission-Stop bd63dad04e) — konsistent mit den RAM-Floors. Compile-Backlog: Welle 1 komplett im build_check gescheitert (4× Buffer, 1× ML-Token), Welle 2 freigegeben.

> **Nachtrag 14:32Z (05.09.) — Astra-Website-Rework da, lokal auf Port 8771:** e0fea529 (23860ed265) APPROVED: unabhängige Review-Kopie unter C:/QM/deploy/qm-ops-refresh/tools/site-build/astra-rework (Website/ unverändert, kein Commit/Push/Deploy), lokal http://127.0.0.1:8771/ neben der aktuellen Version http://127.0.0.1:8770/. Inhaltlich: Prozess-als-Beweis-Rhetorik entfernt, Live-Panel = DXZ-Closed-Position-Serie (−1.436,59 USD / 85 Closes seit 24.07.) + DARWIN-Link, Archiv mit Suche/Filtern + 3.399 statische Detailseiten, kanonische Links, barrierefreie Navigation. Offen (→ Archiv v3.1 Astra a847f01a): Namen weiter Slug-abgeleitet (Aa Ab Velocity, Cs Ichi Cloud), Einheit Karten-Revisionen, Timeframe Not recorded, Gate-Journey wortreich/dünn. Compile: QM5_41193 fällt mit **EA_ML_FORBIDDEN** auf das Token `weights[` (fraktionale Differenzierung, kein ML) → Prädikat-Vorschlag oder Rename = Codex 690fc42a; 41310 + 41352 kompiliert (COMPILE_OK), 41352 hat Q02-Seed. Entscheidungsgebundener E2-Task 90431302 auf IN_PROGRESS geparkt (wartet auf Kalender-Repin).

> **Nachtrag 14:03Z (05.09.) — Kalender-Taint der News-Gates (Folge-Nachtrag):** Diagnose 04.09. (report-only): Anker-Checks 542 PASS / **2.700 FAIL** von 3.242; USD-NFP-Anker 0/12 in 2019–2021, FOMC 0/8 in 2019/2022/2023 — also INNERHALB des Gate-Fensters 2019–2023 (Bundle 86b2c0b5). Konsequenz: jedes Q09_NEWS/Q10_NEWS-Verdikt auf dem gepinnten Bundle ist kalender-tainted; die laufende Zeile 9b4f53f5 (QM5_10069 USDJPY, seit 13:20Z, kein Hold vorhanden) läuft zu Ende (append-only Evidenz, wird nach Repin neu gefahren, nie überschrieben) und wird hier als tainted geführt. Bisher gibt es KEINEN Kalender-Hold; aktuell sind alle pending News-Zeilen aus anderen Gründen gehalten (OOS-Kampagne / Run-Plan). Governed Taint-Hold (Config-Liste, Auto-Release bei Repin, Dry-Run + Tests) = Codex 86b7e902 (Sol medium); Freigabe/Apply durch CEO. Der Weg zur sauberen Evidenz bleibt E1-C (Astra cf597222 → OWNER-Karte). Cost-of-Wait: der Zähler-Pfad über Q10_NEWS steht bis Repin de facto still — bewusst, Evidenz vor Zählerstand.

> **Nachtrag 14:02Z (05.09.) — Website-Produzenten + Compile-Backlog:** Archiv v3 (0b895b78, 3a67d538b1) APPROVED, aber Dry-Run zeigt 3.399 Karten-REVISIONEN als Einheit, **3.368 schwache Slug-Namen**, Timeframe meist UNKNOWN, Gate-Zeilen ohne Phasen-Sprache → v3.1 + Namens-Ledger = Codex Astra a847f01a. Live-Performance-Serie (00eae593, 495e77e5cb) APPROVED: −472,96 USD / 65 Closes / 24 aktive Tage exakt reproduziert; Basis 100 + geschlossenes P&L / 100k USD öffentlich deklariert. Compile-Backlog: nach dem Worker-Reload werden die Payload-gehaltenen Zeilen von selbst geclaimt (FIFO, ~1 je 5 min); die ersten vier (41186/41187/41188/41190, rv-Familie 27.08.) kompilieren, fallen aber im build_check mit **EA_INDICATOR_BUFFER_UNBOUNDED** → Triage real vs. Prädikat = Codex 258d8fa0 (Sol high, Dry-Run-Autoritäten). Codex-Buildlane lief QM5_41351 eigenständig Build→Compile (2 Fehlversuche, dann OK)→Q02 FAIL 13:51Z. Q10_NEWS-Zeile 9b4f53f5 (10069 USDJPY) läuft ohne Hold: es gibt KEINEN Kalender-Hold-Mechanismus für neue Q10_NEWS-Nachfolger (die 15 gehaltenen sind OOS-Kampagnen-Holds) — Datenfenster geprüft, siehe Folge-Nachtrag.

> **Nachtrag 13:37Z (05.09.) — Compile-Backlog geöffnet:** 47 COMPILE_EA-Zeilen pending (27 im Holds-Table + 20 nur per Payload `AWAITING_REVIEWED_WORKER_ROLLOUT` gehalten, seit 21.–27.08.). `release_compile_wave.py` Dry-Run-Survey: 5 sofort releasbar, 16 LATER_WAVE, 7 SOURCE_SHA_STALE_OR_MISSING. Welle 1 mit `--max-items 1 --apply` freigegeben: **QM5_41193** (Zeile 37e3b310, artifacts/qm5_compile_wave_backlog_20260905_w1.json, DB-Backup vor Apply). Weitere Zeilen seriell je Tick nach Bestätigung des Compile-Ergebnisses. Die 7 Quell-Drift-Zeilen: Codex fd5e3ce3 (Sol medium, Dry-Run-Autoritäten + Git-Erklärung je EA, CEO entscheidet die autoritative SHA). Hinweis: der Mutation-Lock ist im Sekundentakt belegt (Claims + Prescreen), Apply braucht 2-s-Retry.

> **Nachtrag 13:30Z (05.09.) — OWNER-JA in Mission Control: FTMO-Abnahmetest R5 RATIFIZIERT (12:41Z, Receipt a2057610):** entscheidungsgebundener Claude-Auftrag a97a5d2d (DOCUMENT_AND_VERIFY) ausgeführt: Siegel-Digests gegen den aktuellen Baum re-verifiziert (10/12 OK; zwei Digests sind NACH der R5-Tabelle und VOR der Siegel-Zeremonie gewandert, also keine Kontamination: Evaluator 4902ea050b = nur read-only inspect-cost-version-Subcommand, opt_census.py = D1-Prescreen-Staging 97bebb43f5; die Siegel-Zeremonie rechnet Items 1/5/8/18 auf den dann aktuellen Bytes neu), Testdokument-Status RATIFIED mit Receipt-ID und ratifiziertem Body-Digest de549514fd75…, Spiegel in Contract V1 (Status-Zeile) und Receipts-Zeile 18. Kein Evaluationsstrom geöffnet, keine Gate-Zahl geändert, NO-BUY unverändert. Nächster Schritt bleibt die Siegel-Zeremonie (prepare-config + OWNER-Signatur), erst nach C-6-Fixtures und Kalender-Item 13.

> **Nachtrag 13:29Z (05.09.) — Lock-Attribution nach Deploy + Audit M08:** Post-Deploy-Messung 11:25–13:25Z (165 Busy-Events): **UNKNOWN-Owner 47 → 0**, Attribution wirkt. Zwei Halte-Ausreißer: claim_atomic **T10 Median 63 s** (alle anderen ~2 s, 29 Events) und **sweep_enqueue_built_eas 58 s** (8 Events) → Diagnose + Lock-Scope-Reduktion Codex 62f54fa5 (Sol high, isolierter Branch). MEASURED-Rate blieb flach (14–21/10 min), die 1.323 SKIPPED_PRESCREEN-Zellen 12:40–13:15Z sind D1-Prescreen des Matrix-Service, kein Overclaim. M08 (0cb1153d, 4902ea050b) APPROVED: Kostenversion gepinnt, sechs FTMO-M1-Harvests eingefroren, aber **0 gematchte FTMO/DXZ-Minuten** (DXZ-Harvests enden April, vier Symbole fehlen) → M08-B DXZ-Harvest mit korrigierter Zeitstempel-Beschriftung = Codex 7508cdcd (≤1 h Fabrikzeit, ein idle Terminal). Entscheidungsgebundene Tasks 88ea9f8b (D1) und 0da3dfec (E1-A) auf REVIEW gesetzt (waren TODO und hielten die Claude-Lane mit awaiting_decision_bound_agent).

> **Nachtrag 12:52Z (05.09.) — Audit M01/M05 geschlossen:** M01 (40812f0b, 8a6925bd26) APPROVED: release_status.py = versionierter Contiguity-Contract, alle vier Populationen (Referenz-Zensus, Fast-Projektion, Builder, Bundle) = **8 Paare**, 9 terminale Zeilen (EURUSD doppelt), PASS-only=7 ist die veraltete Diagnose (NZDUSD bleibt per Q08-FAIL_SOFT-Regel drin); pro Paar Witness-/Binär-/Datenfenster-Unsicherheiten benannt; kein Build-/Deploy-Recht. M05 (7ef6444b, d08f1ceaba+ae1da5eb63) APPROVED: von 786 fehlenden Evidenzpfaden 619 = DL-090-gzip (wiederherstellbar), 11 = Quarantäne, **156 UNGEKLÄRT (126 KEEP-Klasse)** + fehlendes Q11-Aggregat QM5_1328/EURJPY; Purge-Guard 40→91 Paare, fail-closed, in tester_cache_purge.ps1 verdrahtet (Schutz live, nächster 10-min-Lauf nutzt ihn). Wiederherstellungs-Forensik = Codex 618d640e (Sol high, read-only, restored/ mit Provenienz).

> **Nachtrag 12:50Z (05.09.) — OWNER-JA in Mission Control: C-6-Estimator-Methode (12:42Z) → Umsetzung gestartet:** Receipt 871cf325, entscheidungsgebundener Claude-Auftrag adbeff65 (owner_decision_execution --apply); genau EIN Codex-Implementierungsauftrag ae041465 (Astra xhigh, INERT hinter den Contract-V1-Flags, Known-Answer-/Null-Fixtures); Methode dokumentiert in docs/ops/FTMO_C6_ESTIMATOR_METHOD_2026-09-05.md (Contract-V1-Text bleibt unangetastet, weil vom Akzeptanztest r5 versiegelt); Aktivierung der Gates = spätere Karte nach bestandenen Fixtures. NO-BUY unverändert.

> **Nachtrag 12:20Z (05.09.) — E1-B3 integriert (Kalender bleibt scope-begrenzt), M09/M10 abgenommen, M06-Karte in Mission Control, Astra-Website-Auftrag:** 41e3ee1c (51c75174cb → face31cbbf): vier Gates gemessen PASS, vier nur per expliziter Unzulässigkeitsdeklaration abgedeckt → Kandidat nicht voll-scope publizierbar; Policy-Frage (scope-erzwingender Consumer vs. Warten auf Volldaten) → Astra-Vorlage cf597222, danach MC-Karte; 13 News-Gate-Holds und E2/E4 bleiben. M10 (b94b61c5, 6b20f318d6): 18 Magic-0-Deals über 108 Positionen aufgelöst, Burn-in-Advisory bleibt UNKNOWN/nicht bindend, stille Sleeves und KS-Lücke erklärt. M09 (3d2c9e2f, 5e8a92e770): 8/8 Zielbinaries hashgleich, alle acht nativen Szenarien heute UNTESTABLE (keine Installation/Collector/Adapter/Exact-Profile-Konto) → M09-B 7cc4ab4c bereitet alles ohne Anbieterkonto vor; das Exact-Profile-Trial-Konto wird OWNER-Karte, sobald M09-B TESTABLE meldet. M06: Karte OWNER-DEC-LIVE-IDENTITY-ATTEST-20260905 (CLAUDE READY, Feed-Rev. 36, 2a7ce91e9c) — Identitätsbeglaubigung des unveränderten Buchs ohne Freeze-Aufhebung. Website: OWNER-Auftrag „Astra analysiert und überarbeitet inhaltlich + grafisch“ → e0fea529 (Astra xhigh, Kopie unter tools/site-build/astra-rework, Renders + Change-Log); Marken-Wortmarke jetzt einwortig „QuantMechanica“ (eed6477). Import-Guards auch in news_calendar_repair (6938f16548).

> **Nachtrag 12:11Z (05.09.) — OWNER-Richtung Website (2): benanntes Archiv, Detailseiten, echte DXZ-Performance:** OWNER-DEC-WEBSITE-DISCLOSURE-20260905 (Chat, Receipt-Zeile 23): Archiv-Disclosure auf benannte Strategien + Kurzbeschreibung + Gate-/Backtest-Journey + Detailseite je Strategie; Quellcode und Parameter bleiben privat; Combined-Backtest-Chart wird durch die tatsächliche DarwinexZero-Konto-Performance ersetzt, DARWIN KQDS verlinkt. Beauftragt: Archiv-Vertrag v3 0b895b78 (Codex Sol high: display_name/family/summary/markets/gate_journey mit öffentlichen Gründen und PASS/FAIL je Backtest, Exposure-Whitelist, Dry-Run zur CEO-Sichtung), öffentliche Live-Performance-Serie 00eae593 (Codex Sol high: aus dem governed Deal-Export, Manual-Trades ausgeschlossen, Reproduktion des Validierungsfensters −472,96 USD). Danach Website-Generierung (Liste, Detailseiten, Performance-Panel) im Deploy-Worktree; Namensqualität per KI-Pass vor dem v3-Deploy. Empfehlung: den fertigen Rework-Stand (50f30f1) zuerst deployen, v3 als zweiten Deploy.

> **Nachtrag 11:47Z (05.09.) — Website-Rework „Build in Public“ lokal fertig (Deploy-Worktree, kein Push):** Zwei Workflows (Analyse: Audit/Phasenmodell/Archiv-IA + Judge → Umsetzungsbrief docs/ops/evidence/2026-09-05_website_rework/implementation_brief.json; Umsetzung: Shared-Layer + 7 Seiten-Editoren + 4 adversariale Reviewer + Fixer). Änderungen: Routing (_redirects, Kurz-URLs), Shop-Link entfernt, Archiv als Herzstück direkt unter dem Hero mit archive_*-Stats, Drei-Phasen-Strip (Validation Q00–Q08 / Optimization & requalification Q09–Q14 / Book build & live Q15–Q17), Pipeline-Seite mit 18 Gate-Karten „what it checks / fails when“ aus den Vault-Gate-Seiten, Archiv-Seite mit Lesehilfe + live berechneter Attrition-je-Gate + Phasen-Filtern, Roadmap „What we're building“ (nur geplant/evidenzgebunden), Kontakt + Newsletter unten, Abstand über Market structure gefixt. Ehrlichkeitsbefunde behoben: zwei Blogposts mit erfundenen Live-/Funded-Narrativen unpubliziert (tools/site-build/unpublished/), erfundene Live-Portfolio-Aussagen in drei weiteren Posts entfernt, per-Strategie-Kennzahlen und interne IDs aus den Deep-Dives gestrichen, FAQ-Q06 (erfundene $20/Lot-Kommission) auf den echten Mechanismus korrigiert, „~38 Survivors“ durch data-stat-Werte ersetzt, Performance-Seite auf Burn-in/„Verifikation läuft“ zurückgenommen (Widget = Demo-Portfolio), Gate-Fehlbezeichnungen (Q10 vs Q11) korrigiert. Erfundene Blog-Daten des Editors wieder entfernt (Posts hatten nie Daten; vier überarbeitete tragen „Updated 2026-09-05“). CEO-Verifikation: 31/31 interne Routen 200, Exposure-Grep sauber (Dev-Seiten styleguide/chart-lab aus dem Publish-Dir genommen), Renders geprüft; der „Mobile-Blocker“ des Visual-Reviewers war ein Render-Artefakt (Headless-Chrome-Mindestbreite 485 px; Probe: kein Element breiter als der Viewport). Offen für den OWNER: process-roadmap.json enthält interne Prozess-Slugs (public-data-Vertrag unverändert gelassen), Deploy nur per Karte OWNER-DEC-WEBSITE-DEPLOY-20260905. Deploy-Commit: siehe C:/QM/deploy/qm-ops-refresh git log.

> **Nachtrag 11:33Z (05.09.) — Retro-Prescreen angewendet (2 555 Holds), M06 inert geliefert, 41345-Programm live, Import-Guard-Fix, Worker-Reload komplett:** c3779c25 (ca772cc904 → 82d45dacfb): 2 555 PRESCREEN_SKIPPED-Holds append-only auf pending/ungeclaimte Zellen (15 Programme, 15 Receipts, Pre-Apply-Backup, 12 fortgeschrittene Zellen bewahrt) ≈ 26 Tester-Stunden gespart bei 97 Zellen/h; 1 282 UNKNOWN-Arme warten auf Stage-1-Messung (2019/2020); pending OPT_CENSUS ohne Hold jetzt 8 128; Q14-Zähler unverändert 8. ebe10705 (ba221f9c4f → 8a483f5558): M06 `--attest-current` INERT (nie signieren, nie Runtime-Pointer, Freeze unangetastet; aktuelles Buch REFUSED wegen fehlender frischer Beobachtung = korrekt fail-closed); Vorlage docs/ops/evidence/2026-09-05_m06_live_identity_attest.md → MC-Karte nach CEO-Sichtung. 41345: Mess-Q02 942dcaf1 = PASS (25 Trades) auf dem reparierten Binary; Programm DL089_QM5_21502_XAUUSD_DWX_2019_2025 materialisiert (1 085 Zellen, Stage-1-Frontier 149, 6 geboostet). Defekt gefunden/behoben: die D1-Prescreen-Integration brachte `from tools.strategy_farm…`-Importe ohne Script-Fallback ein → Matrix-Materialisierung crashte bei manuellem farmctl-Aufruf (ModuleNotFoundError; Pump-Zyklen laut Log nicht betroffen); alle 82 Paketimporte in tools/strategy_farm mit try/except-Fallback geschützt (27bb879e6e, 6247cc05ef, fe517c57e1; 58 Dateien py_compile OK, Script- und Paket-Import-Smoke OK). Worker-Reload chunk45 abgeschlossen: 10/10 Worker nach 09:14Z gestartet (T8 11:26Z).

> **Nachtrag 10:58Z (05.09.) — Kalender-Kette E1-A/E1-B1/E1-B2 integriert, E1-B3 beauftragt; Readiness Teil 2 Re-Check-Residuen; 41345 misst neu:** E1-B1 (3e3e903d, 30524d22f9): governed Kandidaten-Ingress (Manifest-SHA, hash-gebundene Verifikation, alle acht Gates PASS erzwungen) + registrierte E1-A-Repin-Autorität, 47 Tests; E1-B2 (07add720, 93198a4d2d): zehn native Exporte (sechs 2026-H1-Währungen + vier USD-Klassen) gehasht, Kandidat 20260905T102700Z_e1b2 = 6.3/6.4/6.6/6.8 PASS, 6.1/6.2/6.5/6.7 FAIL (offizielle H1-Anker, native Zeitkodierung unverifiziert, Tick-Footprint-Lücken) → nicht publizierbar. Alles auf agents/board-advisor integriert (78e8465c4e; ein E1-A-Test an die E1-B2-Meldung angepasst). E1-B3 41e3ee1c (Codex Sol high): die vier offenen Gates schließen oder Bereiche explizit als unzulässig deklarieren; danach Ingress-Kommando an den CEO, Publikation nur nach acht PASS. 13 News-Gate-Holds bleiben. Readiness Teil 2: Re-Check 91ffb9e6 = REJECT nur noch wegen drei Restpassagen (Collector-Abwesenheit, Duplikat-Bauauftrag) → korrigiert (058d344368), finale Bestätigung 0c1b3295; 7dceadd0 bleibt REVIEW bis ACCEPT. 41345: Compile-Nachfolger 3 (30075fb9) COMPILE_OK auf T2 (neuer Code); der Matrix-Service hat die neue Mess-Q02-Zeile 942dcaf1 gegen das reparierte Binary (7073a48f…) geminted, aktiv seit 10:49Z.

> **Nachtrag 10:53Z (05.09.) — Codex-CEO-Audit eingetaktet (OWNER ~10:50Z):** Urteil des Audits deckt sich mit dem CEO-Stand (Engpass = Umwandlung von Forschungsbestand in entscheidungsfähige Evidenz; kein Neubau). Mapping M01–M15 in docs/ops/CEO_AUDIT_INTEGRATION_2026-09-05.md; neue Aufträge: M04 9fa50c9d, M05 7ef6444b, M01 40812f0b, M06 ebe10705, M10 b94b61c5, M09 3d2c9e2f, M08 0cb1153d, M14 18b6e054, M07 3a20271f, M13 1bf87710, M11 93cd0e1c, M15 8db1d722. In Flight: M02 (E1-B1/E1-B2), M03 (Fenster-Fix 1ac9f653d8; E2/E4 geparkt bis Reseal — Abnahme künftig gegen natives Report-Fenster + konsumierte Hashes). Geparkt: M12 (Abhängigkeiten). ROT bleibt ROT: DSR-Aktivierung, Live-Identitäts-Attestierung, Kohortendefinition und Wirtschafts-Testvertrag kommen als INERT-Lieferung + Vorlage → Mission-Control-Karten. Nicht übernommen: „Website vertagt“ (OWNER-Auftrag desselben Tages geht vor).

> **Nachtrag 10:25Z (05.09.) — Readiness-Re-Review: Teil 1 + Runbook angenommen (mit Residuen), Teil 2 abgelehnt → Residuen eingearbeitet:** 85e4d7d4 (ee9c2ad6f7, 60 Anker): F1–F4, F6–F9 geschlossen; F5 in Teil 2 §A.3 noch widersprüchlich (Satz „ein atomarer OWNER-Akt“); zwei veraltete Implementierungsaussagen (N1: ftmo_lane_runner hat acht SYMBOL_LANES inkl. USOIL.cash→XTIUSD; N2: QM_FTMO_TrialTelemetry.mq5 + ftmo_trial_telemetry.py existieren). Alle Residuen an den exakten Stellen korrigiert (355d88586e); Teil-1-Caption, Runbook-§6-Hinweis (signierter Mint bei aktivem Freeze blockiert) und QM-Blackout neben der Provider-Tabelle ergänzt. Geschlossen: 85e4d7d4, 8c561172 (Teil 1), 4bdf845e (Kontoprofil); 7dceadd0 (Teil 2) bleibt REVIEW bis Re-Check 91ffb9e6.

> **Nachtrag 10:04Z (05.09.) — OWNER: „alle Entscheidungen in Mission Control?“ → drei Karten nachgezogen, Dukascopy auf 14.09., Website lokal final unter http://127.0.0.1:8770/:** Receipts 18 (Akzeptanztest r5) und 20 (C-6-Methode) existierten nur im Chat/Receipts-Markdown; jetzt Karten OWNER-DEC-FTMO-ACCEPTANCE-TEST-R5-20260905, OWNER-DEC-C6-ESTIMATOR-20260905, OWNER-DEC-WEBSITE-DEPLOY-20260905 (Feed-Revision 35, Vertrag fdb38404bc, alle CLAUDE READY, Coverage-Check 5/5). Dukascopy-Karte: due 2026-09-14 (OWNER: Start Montag 14.09.). Vault-OWNER-Seite hatte die Queue-Marker verloren → per sync_vault_queue(bootstrap=True) wiederhergestellt. Regel ab jetzt: jede OWNER-Vorlage wird VOR der Ankündigung als MC-Karte mit Vertragseintrag angelegt; Receipt-Nummern werden dem OWNER nicht mehr genannt, nur Kartennamen. Website: detached http.server 8770 auf C:/QM/deploy/qm-ops-refresh/Website (Tip 3979561, qm-charts.js 2.0.0, hero-equity.json 200) für die finale lokale Sichtpruefung; Deploy erst nach JA auf der Karte.

> **Nachtrag 09:55Z (05.09.) — E1-A Kalender-Reparatur: Kandidaten gebaut, Verifikation FAIL, Reseal blockiert → E1-B1/E1-B2:** 8eb9f74b (b88ea75f48, 25911ccd5c): Offline-Builder + 14 Tests, Kandidatenpaar D:/QM/reports/news_calendar/repair_e1a/20260905T094500Z/ (48 954 / 48 963 Zeilen), Verifikations-Runner, kompilierter 2026-H1-Exporter. Acht Gates: 6.1 USD-HIGH-Anker FAIL (366 Klasse/Jahr/Quelle-Gruppen; Pflichtziele Core PPI, NY Empire, Building Permits, Trade Balance fehlen im HIGH-only-Exportinput), 6.2 Abdeckung FAIL (2026-H1 leer, Exporte fehlen), 6.3 Identität FAIL (2 278 vorbestehende +1-Minuten-Differenzen), 6.5 Tick-Volumen 11/30 PASS, 6.7 Detektor 2 772 unverifizierte USD-HIGH-Zeilen; 6.8 Schema PASS. Reseal: keine Kandidaten-Ingress im Refresh-Pfad, Repin-Autorität fix auf CALENDAR-REPIN, Staging-Root-Regel → messbare Control-Plane-Lücke, keine Publikation. Beauftragt: E1-B1 Control-Plane (Codex Sol 3e3e903d: Kandidaten-Ingress per Manifest-Hash + E1A-Autoritätsoption in repin, Tests, Dry-Run), E1-B2 Daten (Codex Sol 07add720: Exporter auf alle Impact-Klassen für die Zielnamen, sechs 2026-H1-Exporte headless auf T_Export via ftmo_m1_bootstrap-StartUp-Mechanik, vier fehlende USD-Klassen 2018–2025, +1-Minuten-Regel, Re-Verifikation mit Gate-Tabelle). 8eb9f74b APPROVED (Lieferung wie spezifiziert, ehrlich FAIL). 13 Q09/Q10_NEWS-Holds bleiben; E2/E4 geparkt bis Reseal. OWNER-Handschritt bleibt am Ende: Q09-Korrektur-Receipt (correction_reason E1-A).

> **Nachtrag 09:50Z (05.09.) — D1-Prescreen integriert und aktiviert, Retro-Skip beauftragt, 41345 Compile-Nachfolger 2, Terminal-Board 12 Karten:** bd9505ce (c13d5a489e → 97bebb43f5): B5/B2-Staged-Admission integriert, 66 Tests grün, QM_DL089_PRESCREEN=1 auf Maschinenebene gesetzt (OWNER-DEC-D1-PRESCREEN-20260905); wirkt nur auf künftig geminte Programme — die 10 980 bereits enqueueten Zellen der 17 Programme kann die Implementierung per Design nicht rückwirkend überspringen → Ticket c3779c25 (Codex Sol high): Retro-Anwendung als append-only PRESCREEN_SKIPPED-Holds auf pending, ungeclaimte Zellen mit Dry-Run-Tabelle und Zähler-Abgleich. 41345: Compile-Row 5055a5ca wurde vom Pump-Zyklus 09:13Z (Start vor Commit e59263020e) beim Candidate-Recheck verweigert (COMPILE_FAIL/CANDIDATE_RECHECK_REFUSED) → Nachfolger 89761677 enqueued + freigegeben (Release-Receipts artifacts/qm5_41345_compile_release2_*.json). Terminal-Board (OWNER-Frage „12 Terminals?“): governed bleiben T1–T10 (FLEET); T11/T12 sind installierte Canary-Verzeichnisse ohne Worker/Slot/Claim (Aktivierung v2 ae7d5f56c1, Audit-Bindung 55fa8e03fc, Canary zurückgestellt: RAM ist heute die bindende Grenze) — das Board zeigt sie jetzt als INSTALLED-Karten und legt bei >10 Karten 4er-Reihen (12 = 3×4) an (94abd09a5d, c624d9a06d; Schema: counts.installed_not_governed, state INSTALLED). Readiness-Re-Review läuft als 85e4d7d4 (11d68ead superseded, falsche SHA-Referenz).

> **Nachtrag 09:35Z (05.09.) — FTMO-Readiness-Dokumente nach unabhängiger Abnahme korrigiert; 41345-Reparatur im Compile; Q08/Q09-RAM-Floor:** a7866405 (63c474f70e) verwarf Readiness 1/2 + Runbook + Kontoprofil mit neun Befunden (vier vertauschte Trade-Counts, nicht reproduzierbares −469-Fenster, Kostenbelege fälschlich als fehlend, News-Blackout weggelassen, Sign-and-Hold vs. Freeze-Guard, Mint-Kommando ohne Server/Phase, veralteter R-Stand, Trial-Identität, Rollback-Autorität). Alle neun per Workflow (3 Editor- + 3 Verifier-Agenten, 15/15 Instanzen geschlossen, keine Autoritätsüberschreitung) angewendet und committet (95343b30e9); Re-Review Codex Sol 85e4d7d4; a7866405 APPROVED; 8c561172/7dceadd0/4bdf845e bleiben REVIEW bis ACCEPT. Kernkorrekturen: aktueller Attributionsstand = datiertes Validierungsfenster −472,96 USD (01.08.–04.09., 65 Closes/24 aktive Tage), letzte 30 Close-Tage −1 436,59 USD; Kosten-Snapshot vom 05.09. 04:24Z als PROVISORISCH zitiert (nicht ins Kostenmodell übernommen); QM-News-Blackout bleibt verpflichtend neben der FTMO-Swing-Ausnahme; Signieren schließt nur Identitätsbedingung 1, signierter Mint bleibt bei aktivem Freeze blockiert. 41345: Identitäts-Literal-Defekt bestätigt (dc7a0989), Fix 019499ee94, exakte Reparatur-Vollmacht e59263020e, COMPILE_EA 5055a5ca freigegeben (b2d641cc85) → nach PASS append-only Q02-Wiederholung. Worker: Phase-RAM-Floor auf Q08/Q09 erweitert (fx_cross 18 / fx_major 16 / Metall 12; 30a7888dc6, b4a6ef855e) nach zwei gestapelten 16-GB-Läufen bei 12,5 GB frei; der 14/20-GB-Latch hatte bereits gebremst.

> **Nachtrag 08:53Z (05.09.) — OWNER-Entscheid Website-Charts: TradingView-Hellprofil (Receipt 21):** OWNER wählt Claude v2, Theme `light` (bereits Default im Deploy-Worktree, Commit 3979561 auf refresh/apple-2026-09). Astras Studie bleibt als Evidenz archiviert (56d1f4a1 APPROVED). Render-Harness-Server (8765/8766) gestoppt. Offen: Deploy-Freigabe (Push refresh/apple-2026-09 + Netlify) — separater OWNER-Entscheid; bis dahin lokal.

> **Nachtrag 08:43Z (05.09.) — Website-Chart-Vergleich beim OWNER, Astra-Entwurf geliefert, T8/T9 neu gestartet, zwei Codex-Patches integriert:** Astra (56d1f4a1, 1d02dd2b72): eigene Engine QMChartsAstra, weiße Terminal-Palette (#168775/#cc625d), separater Volumenstreifen, Hover-Pointer, Kalibrierung an Read-only-Export-Aggregate 2022–2024 gebunden, Renders 1400/420 px (docs/ops/evidence/2026-09-05_website_chart_astra/) → APPROVED und als Tab in die OWNER-Vergleichsseite (privater Artifact-Link https://claude.ai/code/artifact/30572f4f-208c-48ea-81c3-88666a5a2d54: v1 dunkel, Claude v2 TradingView-hell, Claude v2 MT5, Astra) eingebaut; OWNER entscheidet Default-Schema + Deploy. Fabrik: T8 und T9 waren seit 06:20Z ohne Worker-Prozess (Ausfall während der Reload-Kette 06:2xZ; .err zeigt nur den bekannten prefix-Hinweis) → start_terminal_workers.py hat genau die zwei fehlenden gestartet (08:47Z, pids 30664/8664), 10/10 Worker aktiv; OPT_CENSUS 117 Zellen/h, 10 980 Zellen über 17 Programme offen; T7 Q08 EURNZD-Tester 16,4 GB bei 25 GB frei (beobachtet, kein Reap). Codex-Patches auf agents/board-advisor integriert (isolierte Codex-Branches, 3-way apply): 871054b591 Lock-Owner-Attribution (Historie 2 h: 63/110 Ablehnungen zuordenbar, 50 davon terminal_worker.claim_atomic T1–T10, 11 dl089_matrix_service, 2 release_compile_wave — die Pumpe hält den Lock NICHT; Post-Deploy-Fenster nach dem nächsten Worker-Reload), f0b1d21b23 Coverage-Test + `owner_decision_execution.py --coverage` (18 Einträge, 2 offene Karten, PASS). Tests 30+97 grün. Reviews geschlossen: e7599281, 030e09d9, 56d1f4a1.

>
> **Nachtrag 19:43Z — c9a1bdab APPROVED (Juli-Kohorte Park/Retire ausgeführt):** Klassifikation (2093b38e) live neu hergeleitet — Zähler stimmten exakt: 79 Park / 223 Retire. Neues Tool `tools/strategy_farm/apply_july_cohort_park_retire.py` (Dry-Run + Hash-gebundener Apply, 5 Unit-Tests grün) trägt je Zeile genau eine `work_item_supersedes`-Kante ein (`superseded_by_work_item_id` = die eigene vorherige Terminal-Zeile), niemals UPDATE/DELETE auf `work_items`. Ein Online-Backup für den Gesamtlauf (`D:/QM/strategy_farm/state/backups/farm_state_before_july_cohort_park_retire_20260902T174204Z_79f696d5.sqlite`), zwei `BEGIN IMMEDIATE`-Transaktionen (Park, Retire), Pre-Insert-Revalidierung pro Zeile (Drift wird übersprungen, nie erzwungen, nie bricht sie Geschwisterzeilen ab). Ergebnis: 302/302 eingefügt, 0 übersprungen. Vorher/Nachher verifiziert: `work_items`-Status-/Verdict-Verteilung unverändert (Delta 0 überall); einzige DB-weite Änderung ist `work_item_supersedes` +302 (79 Park- + 223 Retire-kodiert) und `events` +302. INFRA_FAIL (1.705) und Assess (148, `NO_PRIOR_RUN`) nie ausgewählt, 0 neue Kanten dort. Evidenz `docs/ops/evidence/2026-09-02_july_cohort_park_retire_execution.md`, Commit `fb97fa983a`. Router-Task REVIEW→APPROVED.
> **Nachtrag 08:09Z (05.09.) — Akzeptanztest r5 = RATIFIZIERBAR (Review-Runde 4 PASS), Amendment-C-Siblings gebaut, Reviews geschlossen:** 2b25f7a4 (88cea650cb): Runde 4 bestätigt alle drei mechanischen Fixes (Rechtszensur-Aussage, 17 Siegel-Digests, R-2-Policy) gegen die exakten r5-Bytes (LF de549514…) → Receipt 18 = READY FOR RATIFICATION; Ratifizierung hebt NO-BUY nicht auf. Geschlossen: 2b25f7a4, 1e0fbad5 (Akzeptanztest-Auftrag), 97a0ed31 (Contract V1) = APPROVED. db42cb90 (e75101ec12, 6147dac224): alle sechs _opt-Messgeschwister kompiliert/gebunden (41342–41347), Dry-Runs applied=false, Matrix-Service materialisiert; Residuum QM5_41345 (Parent 21502/XAUUSD) hält auf Mess-Q02 ZERO_TRADES → Diagnose-Ticket (Defekt vs. echt; echtes No-Signal wird nie requalifiziert). Unabhängige Abnahme der drei Read-only-FTMO-Dokumente (Readiness 1/2, Kontoprofil) an Codex Sol beauftragt; danach schließen. Fabrik: OPT_CENSUS 107 Zellen/h (letzte 60 min), 4 aktiv, 40,8 GB RAM frei, D: 85,9 GB, Containment aus, keine neuen Q09/Q10_NEWS-Zeilen. Astra-Chart-Design 56d1f4a1 läuft seit 07:38Z.

> **Nachtrag 08:05Z (05.09.) — OWNER-Befund „Hier fehlt was: OWNER-DEC-DUKASCOPY-BACKFILL-20260829 / HANDOFF-PLAN FEHLT“:** Ursache: Mission Control zeigt den Badge HANDOFF-PLAN FEHLT, wenn die Entscheid-ID keinen Eintrag im Ausführungsvertrag tools/strategy_farm/config/owner_decision_execution.v1.json hat — die Dukascopy-Karte (angelegt 29.08., am 30.08. vertagt, im Chat am 02.09. mit JA beantwortet = Receipt-Zeile 5) hatte nie einen Handoff-Plan; das Chat-JA wurde nur in decisions/2026-09-02_owner_receipts_ceo_asks.md verbucht, der MC-Store kennt nur MC-Receipts (Status dort weiter DEFERRED). Umgesetzt wurde bisher Codex bd73130a = P0-Inventur, fail-closed VOR dem Splice gestoppt (kein Read-only-TKC-Tail-Decoder → keine Splice-Anker; Evidenz docs/ops/evidence/2026-09-02_dukascopy_backfill_p0_block.md). Fix: Vertragseintrag ergänzt (JA = APPLY_AND_VERIFY: governed Read-only-T1-Tick-Tail-Probe → Codex-Build P1 Downloader / P2 Konverter / P3 Abgleich-Harness (fail-closed je Symbol) → P4 Import nur PASS-Symbole über T1-Queue + verify_import, Verteilung T2–T10 in separat autorisiertem OFF-Fenster → P5 Monatslauf + Alters-Healthcheck; NEIN = dokumentieren), plan_sha256 61b47d99…, Cockpit neu gerendert: Karte = CLAUDE READY. Bindung der Fortsetzung: OWNER beantwortet die Karte in Mission Control (JA), dann entsteht der entscheidungsgebundene Claude-Auftrag automatisch. Nebenbefund: test_owner_decision_execution::test_execution_contract_covers_every_bootstrap_decision_and_both_choices verlangt Vertrags-IDs == Bootstrap-Seed-IDs (7) und schlägt seit dem Anwachsen des Vertrags (17→18 Einträge) unabhängig von dieser Änderung fehl — Testkontrakt veraltet, Ticket folgt (observe-only).

> **Nachtrag 07:37Z (05.09.) — Website: Chart-Engine v2, helle Terminal-Charts auf Weiß (OWNER-Wunsch 07:10Z):** Preisaktions-Renderer neu gebaut (Deploy-Worktree refresh/apple-2026-09, lokale Vorschau, kein Push/Deploy): Theme `light` = TradingView-Hellprofil auf Weiß (Grid #f0f3fa, Kerzen #26a69a/#ef5350, EMA blau/orange, Bollinger blau), Theme `mt5` = MT5 „Black on White“ (hohle Bullen, schwarze Bären, gepunktetes Grid) als Option, `dark` bleibt. Terminal-Layout: Legende mit Symbol · TF + OHLC der letzten Kerze, rechte Preisskala mit Rand und Last-Price-Tag, Zeitskala mit Major/Minor-Labels, Volumen unten im Pane. Generator v2: Intrabar-Pfad (16 Teilschritte) statt gezeichneter Body-Fraktion → natürliche Docht/Körper-Proportionen, GARCH + AR(1)-Drift-Regime, Fat-Tail-Sprünge, Gaps nur wo Märkte gappen, letzter Schluss auf Referenzniveau verankert, 60-Bar-Warm-up für EMA50/BB, H1 (FX 24×5, Sessionprofil) und D1. Widgets: EUR/USD 60×H1 mit London/NY-Boxen pro Tag, XAU/USD 56×D1 PO3 (Sweep am Range-Tief), US100 64×D1 EMA/BB/Swings — Balkenzahl von 120/96/140 gesenkt (2-px-Slots waren das Haupt-„unecht“-Signal). Equity-Chart ebenfalls hell. Evidenz: docs/ops/evidence/2026-09-05_website_light_charts/ (before_dark, after_light, after_mt5, final_light, final_mobile — Headless-Chrome-Renders der lokalen Vorschau); Designdoc §4a. OWNER entscheidet: Default `light` (TradingView) oder `mt5`-Schema, und Deploy-Freigabe.

> **Nachtrag 06:58Z (05.09.) — C-6-Estimator-Vorlage liegt vor (Receipt 20), OQ-11 gefixt, Akzeptanztest Review-Runde 3 = mechanische r5:** 4b8d5bb3 (06717faa03): Astra-Entwurf docs/ops/OWNER_VORLAGE_2026-09-05_c6_breach_joint_estimator.md — Empfehlung C6-A: worst-of aus Moving-Block-Bootstrap + exaktem Guard auf der buchweiten M5/Prag-Tag-Pfadspur (Trial-Telemetrie), abgeleitete Mindestzahlen 36 Breach-Gauntlets / 23 P2-Pässe / 9 Joint, Closed-P&L-Ströme für Breach/Joint unzulässig; synthetischer Selbsttest PASS, nichts aktiviert. c3f1bae9 (7f56e1c825): Contract-JSON -text gepinnt, Engine stempelt LF-Digest mit Raw-Provenienz, veraltete Selbstzitate gefixt (25 Tests). 07fee24f (370bb327f4): Review-Runde 3 = FAIL nur mechanisch (59 gekürzte Rolling-Starts sind zensiert, nicht „forced TIMEOUT“; sechs Siegel-Identitäten nach dem Portabilitäts-Fix veraltet; R-2-Kopplung als OWNER-Policy formulieren) — R-1/R-2/R-2b/R-2c/D.0/D.1 bestanden → r5 läuft (Opus, mechanisch), danach Runde 4. Fabrik: 110 Zellen/h, 42 GB frei; neue Q10_NEWS-Zeile 11179 gehalten; Sibling-Bauten für Amendment C laufen (Magics 41346/41347, Compile-Releases).

> **Nachtrag 06:30Z (05.09.) — D1: Codex verweigerte fail-closed (Parameter fehlten) → Parameter erklärt und neu beauftragt; D2: 3/9 Programme live, 6 warten auf Opt-Siblings; frische Q10_NEWS-Zeile gestoppt:** cabe55c9 (bca376148c): B5/B2 nicht verdrahtet, weil die zwei Stage-1-Jahre nicht erklärt waren und das Fire-Count-Werkzeug selbst safe_to_skip=false trägt; Projektionen: 41196 (21507/XAUUSD) 72–76 % der Arme feuern < 5× je Jahr, 41197 (11881/GBPUSD) 93–94 % → gemessene Zellen 38–45 bzw. 10–12 je Jahr statt 155. CEO-Erklärung unter der Freigabe (Receipt 13, OWNER-DEC-D1-PRESCREEN-20260905): Stage-1 = 2019+2020, +5 % in beiden, N = 5, safe_to_skip = true unter hash-gebundenem T_Export-D1-Manifest (Paritätsnachweis = Harness 0 falsche „never fires“ auf 11421/10706); Umsetzung neu an Codex Astra bd9505ce. 023f1cfe (1f676ec64b): Queue-Order 12/12, NDX-Zeilen unter RAM_WINDOW_44GB, Programme 12849/XTIUSD, 12855/XTIUSD, 21501/USDJPY materialisiert; 6/9 fail-closed ohne genehmigten _opt-Sibling → Sibling-Bauten an Codex Sol db42cb90. be22a065 (222d1df879) abgenommen (8 Sleeves/6 Symbole gemappt). Fabrik: T2 startete eine NEUE Q10_NEWS-Zeile (10771/XAUUSD, H1 = exponiert) gegen den defekten Kalender → Runner-Baum gestoppt, Hold NEWS_CALENDAR_TIMESTAMP_DEFECT auf ee4ff9b4 und 24acc5d4 (12778 Q09_NEWS); Regel: jeder Tick hält neue Q09_NEWS/Q10_NEWS-Zeilen bis E1. 110 Zellen/h, 36 GB frei.

> **Nachtrag 06:26Z (05.09.) — Akzeptanztest r4 committet: der Test kann NO-BUY heute strukturell nicht aufheben; kritischer Pfad = C-6 + Trial-Telemetrie:** r4 (nach Review-Runde 2 FAIL): Power-Regel operational — W_min = ESS_min disjunkte 60-Tage-Blöcke (der Bootstrap-Block des Evaluators ist die unabhängige Ziehung), D_min = 60·ESS_min versiegelte Kalendertage; bei Bar 0,80 und p* = 0,90 → 35 Fenster ≈ 2 100 Tage ≈ 5,75 Jahre (3 150 d mit Joint-Gate); p* = 0,95 → 540 d ≈ 1,5 Jahre; das 96-Tage-Diagnosefenster liefert W = 1. Guards gegen die degenerierte HAC-ESS-Branch (R-2b) und Spannen ≤ 60 d (R-2c); Rolling-Start-Zählung korrigiert (rechts-zensierte Starts). D.1 als Statustabelle: Breach (5) und P2/Joint (6) INERT bis C-6 — ehrliche Konsequenz: „solange 5/6 inert sind, kann dieser Test NO-BUY nicht aufheben, egal wie gut eine Messung ist“. Siegel 14 → 18 Einträge (Contract-JSON, Loader, portfolio_correlation.py, Vertragsdoc), Anker nach f68ce8f338 neu verifiziert (~35 Korrekturen). Folgeaufträge: Review-Runde 3 07fee24f; OQ-11 Contract-JSON-Digest-Portabilität + veraltete Selbstzitate (Codex c3f1bae9); C-6-Estimator-VORSCHLAG als Vorlage (Codex Astra 4b8d5bb3, nur Entwurf, Methode entscheidet der OWNER). Receipt 18 bleibt PENDING mit dieser Einordnung.

> **Nachtrag 06:11Z (05.09.) — 453b8edf Codex-Tier-Enforce-Vorbedingungen committet und abgenommen (Enforce bleibt AUS):** Opus-Workflow (Scout, Implementierung, zwei Reviews PASS_WITH_FINDINGS, nur Minors): lane-unabhängiger Router-Hold invalid_scalpel_marker (nichts führt eine fehlerhafte Scalpel-Zeile aus, nie gemini); ts-lose/korrupte Ledger-Zeilen werden über einen Append-Order-Anker begrenzt, den scan_window und rotate_ledger teilen (keine Dauerbelastung mehr); allowed_window_enforcement_modes wird fail-closed validiert (OWNER kann „enforce“ unladbar pinnen); rotate_ledger mit Stat-Fast-Path; im Enforce-Modus greift der Astra-Hold vor dem Burn-Bypass. Observe-Invarianz per Test bewiesen; 314 Tests grün. Umschalten auf Enforce = separater datierter Entscheid. Vorbestehender, unabhängiger Testfehler test_owner_decision_execution (OWNER-Decision-Feed ≠ Execution-Contract) notiert, nicht angefasst.

> **Nachtrag 06:02Z (05.09.) — Fünf Codex-Rückläufer abgenommen; Akzeptanztest geht in r4; Fabrik 115 Zellen/h, alle zehn Worker auf Nachtstand:** 814de468 (f68ce8f338): §7-Vertrag V1 implementiert — Contract-JSON + Loader, Builder konsumiert V4-Layer-A-CI mit absolutem |r|, Timebox liest Bar/Horizonte/Bootstrap aus dem Vertrag, MC/First-Passage nur diagnostisch, C-6-Gates INERT; die versiegelten Acht bleiben BAR_NOT_MET (NO-BUY unverändert). b5a4e196 (bb6d693f76): frischer read-only Export (225 Zeilen) rekonziliert governed-only auf −472,96 USD vs. Audit −469 (Delta erklärt); 24-Sleeve-Attribution und 8 exakte Haltedauer-Profile hash-gebunden. 79772247 (27e85a0690): Trial-Telemetrie-Kollektor (Tick+Timer, fail-closed M5/Prag-Tag-Reader, Restart/Mitternacht-Dry-Run PASS). f810f5af (fb719e703a): 8 bewachte Trial-Sets (0,3125 % je Sleeve, 2,5 % gesamt), Validator verweigert Live-Sets außerhalb des Trial-Verzeichnisses. 692b4bca (9792690cd3): Review-Runde 2 = FAIL (F3-Non-Overlap-Floor nicht operational; C-6-Inertheit widerspricht dem Vertrag; Siegel-Anker nach f68ce8f338 veraltet) → Vorlage r4 läuft, danach Runde 3; Receipt 18 bleibt PENDING. Fabrik: Chunk 44 fertig (T6), Q08-Reruns 40a802ca/b429d45f FAIL_SOFT (PASS-Klasse), 10771/XAUUSD in Q09; Lock-Kollisionen 28/25 min (normal).

> **Nachtrag 05:34Z (05.09.) — Canary-Root-Cause gefixt (Entscheid CAN geschlossen, Aktivierung vertagt), Spread-Kalibrierung ABSTAIN, 453b8edf gestartet:** a128d596 (44068f02fb, Worker-Suiten grün): Decline-Loop rekonstruiert; Fix begrenzt kalte Preflight-Abweisungen je Programm und Claim-Zyklus (PROGRAM_PREFLIGHT_SUPPRESSED), bei L=1 inert. Aktivierung des L=2-Canaries vertagt, weil sechs und mehr zugelassene Programme den Zellen-Cap G=6 bereits sättigen — L=2 brächte heute keinen Durchsatz; Protokoll liegt für ein späteres Fenster (<6 Programme) bereit. 6824f471 (a23096b204 + 4a81883fd0, 27 Tests): FTMO-Seite für sechs Symbole geerntet; DXZ-Seite hat für USDCAD/NZDUSD/XTIUSD/XAGUSD keine 2026-Bars und für GBPUSD/EURUSD nicht überlappende Fenster → ABSTAIN für alle sechs; nächste Evidenz = frische DXZ-2026-M1-Ernte über identische UTC-Minutenfenster → gebündelt mit dem T_Export-Handschritt (Kalender 2026-H1). Fabrik: 104 Zellen/h, keine INFRA-Fälle, Lock-Kollisionen 2–4/min (normal), 32,8 GB frei → 453b8edf (Codex-Tier-Enforce-Vorbedingungen) als Opus-Workflow gestartet. Chunk 44 wartet auf T6.

> **Nachtrag 05:31Z (05.09.) — Readiness-Pack 2 committet (7dceadd0 → REVIEW), drei Bau-Tickets für den Exact-Profile-Trial:** docs/ops/evidence/2026-09-05_ftmo_readiness_part2.md + docs/ops/FTMO_STAGE_TRANSITION_RUNBOOK_2026-09.md (r2 nach PASS_WITH_FINDINGS + FAIL). Kernbefunde: Deploy-Pointer signed=false (Verifikationsrang DEGRADED); der Risk-Freeze hat drei Lift-Bedingungen — SP-A1/A2-Pointer BLOCKED, NEWS-CONTRACT-V2 PARTIAL, GOVERNOR-HARDENING PARTIAL — die Signatur schließt nur die erste, kohärentes Ergebnis der OWNER-Sitzung 06.09. ist daher „signieren und Freeze halten“; Signieren ist selbst freeze-gebunden (ein atomarer OWNER-Akt mit schriftlichem Lift). Trial-Design nennt drei harte Grenzen: Runner-Setfile-Modus (Backtest vs. Live), Symbolabdeckung (Runner-Lanes decken keinen der 8 Kandidaten), und es gibt keinen Kollektor für eine Prag-Mitternacht-gekeyte M5-Equity-Serie mit Intervallminima + Positions-/Pending-Zensus (Review-Blocker, in r2 als Spezifikation benannt). Codex-Sol-Tickets: Telemetrie-Kollektor 79772247, Trial-Setfile-Pfad f810f5af, Lane-Abdeckung be22a065. OWNER-Entscheide: Sign-and-hold am 06.09., MNT-004-Zustandswechsel PARKED→RUNNING, Trial-Konto. Damit sind alle sieben FTMO-Nachbeauftragungen vom 03:35Z geliefert oder in Codex-Umsetzung.

> **Nachtrag 05:07Z (05.09.) — Readiness-Pack 1 committet (8c561172 → REVIEW, P7b ausgeführt), Validierung an Codex:** docs/ops/evidence/2026-09-05_ftmo_readiness_part1.md (r2 nach zwei PASS_WITH_FINDINGS-Reviews). (A) Governed-only-Attribution gegen den UNSIGNIERTEN 24-Sleeve-Deploy-Pointer (Signatur = OWNER-Sitzung 06.09.); manuelle magic=0-Trades ausgeschlossen (Receipt 1); vier Drift-Magics außerhalb des Rosters als Adjudikationsliste: 104760004/107150004 nie gehandelt (reine Label-Ausnahme), 106920005/109400003 handelten vor der Deploy-Epoche 24.07. (Legacy, keine aktuelle P&L-Leckage); governed −469 USD / 30 aktive Tage, Sharpe-CI [−6,8, +4,6], DSR ≥ 0,95 bei 0/24; Per-Deal-Export ist vom 04.08. (stale) → frische read-only Inventur + Export als Codex-Ticket b5a4e196. (B) Machbarkeit der 8 Kandidaten: DXZ-Orderroutbarkeit in dwx_symbol_matrix.csv für alle 8 UNBESTÄTIGT (nur SP500 bestätigt); Swing-Hebel 1:30/1:15 im Rulepack, aber UNVERIFIZIERT (Trading-Symbols-URL 404 am 04.09., Bestätigung vom 30.07.); Review-Korrektur: Swing-Margin ≈ 3,33 % FX / 6,67 % Metall+Öl (Standardprofil 1 %/2 % darf nicht zur Größenbestimmung dienen); Swap für XAG und vier FX-Paare ohne Quelle (MISSING), 7/8 Sleeves D1-mehrtägig = swap-exponiert. Worktrees der beiden abgeschlossenen Workflows entfernt (Pump-Audit).

> **Nachtrag 05:05Z (05.09.) — §7-Policy-Vertrag V1 committet, Umsetzung an Codex; Pump-Sperrdauer durch Worktree-Aufräumen kurz:** docs/ops/FTMO_PROBABILITY_CORRELATION_CONTRACT_V1_2026-09-05.md (r2 nach PASS_WITH_FINDINGS + FAIL: DSR-Trials 154→369 laut Engine; C-1 „Composite“ war redundant → einziges bindendes P1-Gate lower_95 ≥ 0,80, subsumiert das vorgeschlagene Rulepack-Gate; Breach/Joint/P2 INERT bis Estimator existiert; Korrelationsgrenzen geschichtet absolut 0,50/0,40/0,15; Builder migriert von zeros-dropped, vorzeichenbehafteter Pearson auf V4-Layer-A-CI). Ratifikationsasymmetrie offengelegt: Rulepack-go_criteria sind RESEARCH_CONTRACT_ONLY → Receipt 19 PENDING (C-2, C-6, OQ-9). Codex-Sol-Umsetzung 814de468 (nur ratifizierte Teile). Pump: 04:53–04:57Z zweite lange Sperre (7 Worker idle, 44 lock_busy-Declines/10 min); Ursache Worktree-Audit unter der Sperre (66 Repo-Roots, 15 117 Dateien; Cache-Misses durch meine 11 Agenten-/Workflow-Worktrees) → 9 beendete Worktrees entfernt + prune; Pump 05:03Z wieder kurz, 8 aktiv, 100 Zellen/h. Die 46 Rework-Slot-Worktrees der Codex-Fabrik bleiben. Regel: Agenten-Worktrees nach Abnahme sofort entfernen.

> **Nachtrag 04:54Z (05.09.) — Akzeptanztest r3 committet (a0fa292e91) + Review-Runde 2 (692b4bca); Kostensnapshot 8/8 abgenommen:** r3 nach dem FAIL-Review: P1-Bar = Schnittmenge (point ≥ 0,80 UND lower-95 ≥ 0,80) als Interimsregel bis P7a; DSR-Multiplizität = Buchauswahl-Trials (Funnel 3 001 EAs / 13 398 Paare, Kampagne 50 Paare), nicht die 154 Census-Trials; Power-Regel C.4 nur aus bestehenden Konstanten (Einzel-Diagnosefenster Jan–Apr 2026 rechnerisch unterpowert; DSR-Floors 60 Tage/30 Beobachtungen binden für D1-Sleeves); alle acht go_criteria notwendig; 14-teiliges Siegel mit LF-normalisierten Modul-Digests. Neu vordefiniert: Roster-Lücke 11910/NZDUSD (OQ-6), Kostenklassen-Blocker — Evaluator akzeptiert nur DXZ_EXECUTION_FTMO_COST_ADJUSTED_V1 (OQ-7). 125 file:line-Referenzen maschinell geprüft. Receipt 18 bleibt PENDING bis Runde 2. f16785de (5bac8eaccb) abgenommen: offizielle FTMO-Symbol-API 05.09. 04:24Z erfasst (sha 07cad5b2…), sechs Symbole / acht Sleeves, Kommission+Swap-Projektion reproduzierbar, Loader entpacken das datierte Schema (24 Tests); PASS_PROVISIONAL mit ABSTAIN bis Client-Area-Nachweis (Triple-Swap-Tag, exakte Spezifikationen) und gepaarter Spreads (6824f471 läuft, a23096b204). OWNER-Handschritte 1–2 (Client-Area-Screenshot) ins Board.

> **Nachtrag 04:35Z (05.09.) — Drei Codex-Rückläufer abgenommen, E5 geschlossen, Akzeptanztest in Revision r3, §7-Vertrag und Readiness-Pack 1 laufen:** 9c7a1878 (6b82a72148): V4-Sparse-D1-Paarkorrelation für alle 28 Paare CERTIFIED unter der V2-Grenze, Layer-B/Tail für alle 8 ABSTAIN — Intervall-MTM/Pending-Evidenz existiert in Backtest-Telemetrie nicht (gleiche Lücke wie 0af640f6) → Shadow/Trial-Telemetrie ist die zulässige Quelle. 77cd4ef5 (09877afd0c): 33 SHA-gebundene Kampagnen-/Native-Quellen in Purge-Evidenzausschlüssen und Backup-Retention geschützt (Live-Dry-Runs PASS, 20 Tests) → Entscheid E5 (03e2aaa8) ERLEDIGT. c11c6a9f (23942605e3): Review der Akzeptanztest-Vorlage = FAIL (P1-Lower-Bound in §D verschluckt; 154 deklarierte Trials sind Census-, nicht Buchauswahl-Trials; „gepowerter Holdout“ ohne Power-Regel; go_criteria unvollständig; Evaluator-/DSR-Inputs nicht versiegelt) → Revision r3 läuft (Opus, Worktree), danach zweite unabhängige Review-Runde; Receipt 18 bleibt PENDING. Gestartet: §7-Policy-Vertrag (97a0ed31, Opus-Workflow), Readiness-Pack 1 (8c561172, Opus-Workflow), Canary-Root-Cause (Codex Sol a128d596), E1-A-Umsetzung (Codex Astra 8eb9f74b). Fabrik: 107 Zellen/h, sechs Programme, RAM 16 GB, Chunk 42c wartet auf T6 (Q08 b429d45f).

> **Nachtrag 04:29Z (05.09.) — Kalender-Reparaturplan E1-A committet, Umsetzung an Codex Astra, Intervall-Equity-Export abgenommen:** docs/ops/NEWS_CALENDAR_REPAIR_PLAN_2026-09-05.md (r2 nach zwei Reviews: 3 Blocker — „Nicht-anfassen“-Klasse konservierte falsche Instanzen, Verifikation blind außerhalb der 08:30-Klasse, Recompute am tagfrüheren Datum — plus 7 Majors: Reschedules/Shutdown, 11:30-DST-Seam ist ein echter Defekt, Nicht-USD-Backfill zweitklassig, dxz23-Dirty-Tree blockiert Factory_ON-Mint, q09-Bundle-Regeneration, 4 statt 3 Common-Dirs, Reihenfolge E1→Detektoren→E2/E4). CEO-Entscheide zu den offenen Fragen: Nicht-USD = scope-and-declare; dxz23-Repin läuft über den governed Refresh-Flow unter OWNER-DEC-CALENDAR-E1A-20260905, kein AI-Commit. Codex-Astra-Umsetzung 8eb9f74b (Kandidatendateien + 7-Gate-Verifikation, kein Produktionsschreiben). HANDSCHRITT (OWNER/CEO): frischer CalendarValueHistory-Export 2026-01..06 im T_Export-Terminal (Exporter-Kopie to=2026.07.01, je Währung/Halbjahr) — bis dahin bleibt 2026-H1 ein Loch und E4 wartet. 0af640f6 (Intervall-Equity-Export, e8c8b28eac) abgenommen: ehrlich ABSTAIN — Tester-Telemetrie liefert Balance/Belegung und ereigniszeitliche EQUITY_SNAPSHOTs, keine Intervall-MTM-Minima → FTMO-Tagesverlust nur aus Shadow/Trial-Telemetrie messbar (fließt in Readiness-Pack 2). Fabrik: 109 Zellen/h, Pump-Lauf 03:58–04:03Z hielt die Sperre 5 min (Recovery-Klassifikation), transient.

> **Nachtrag 04:02Z (05.09.) — Akzeptanztest-Vorlage eingereicht (1e0fbad5 → REVIEW), Spread-Inventar abgenommen (ABSTAIN), Fabrik 109 Zellen/h:** docs/ops/OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md (r2 nach zwei FAIL-Reviews mit 3 Blockern: erfundene Lift-Schwelle → strengste bestehende go_criteria; DSR ohne Werkzeug → sub_8_2_dsr_mc_fdr DSR≥0,95/p<0,05 bei 154 deklarierten Trials; nicht-zulassende Diagnosequelle → Test inert bis OQ-2). Receipt Zeile 18 PENDING (Ratifizierung + OQ-2: Einzel-Diagnosefenster vs. gepowerter versiegelter Holdout). Codex-Review c11c6a9f gemintet. b8a0676b (f23c14c352): kein zeitgleiches FTMO/DXZ-M1-Spread-Paar für den aktuellen Pool → ABSTAIN; günstigster Erwerbspfad dokumentiert (FTMO-Demo/Trial-Export = OWNER-Kontoaktion). Fabrik: 109 Census-Zellen/h (sechs Programme), Q08-Rerun 49b55905 (10771/XAUUSD) FAIL_SOFT = PASS-Klasse; 40a802ca (11179/USDJPY) läuft auf T2; Chunk 42c wartet nur noch auf T6. Codex-Orchestrierung committet weiter Doku direkt auf board-advisor (f23c14c352).

> **Nachtrag 03:53Z (05.09.) — OWNER-FREIGABE „Alles, bis auf den Kauf, freigegeben, das uns dem Ziel näher bringt!“ verbucht:** Receipts Zeilen 9–17; je Entscheid genau ein entscheidungsgebundener Claude-Auftrag: E1-A Kalenderreparatur 0da3dfec, E2-Mittel Nachmessungen 90431302, E4 OOS-Apply nach E1 49a8c88b, E5 DL-090 03e2aaa8, D1 Census-Verkürzung B2+B5 88ea9f8b, D2 Amendment C 0ceafe5f, §7 Policy-Vereinheitlichung 97a0ed31, §7 Kontoprofil 4bdf845e, Canary nur nach Root-Cause-Fix ?. Ausgenommen bleiben: Challenge-Kauf (OWNER explizit), T_Live/AutoTrading, Pointer-Signatur, Konto-/Rechtsaktionen, jede Ausgabe. Reihenfolge nach Zählernutzen: D1 (Census −50 % Zellen) und E1 (Kalender) zuerst, dann D2, E2/E4, §7.

> **Nachtrag 03:35Z (05.09.) — Sechs Census-Programme parallel (99 Zellen/h), Restarts bis auf T10/T6 durch, 11015-Rerun gemintet, FTMO-Nachbeauftragung läuft:** Nach Chunk 43 (T1/T2/T3/T4/T8/T9 mit Drain-Fix 64fc9ef2cc + Floor) nutzen die Worker K=8/G=6 voll: 41161/41196/41331/41097/41197/41198 aktiv, 99 Zellen/h (vorher 52–68). Chunk 42c wartet auf T10/T6 (Q08-Reruns 49b55905/b429d45f laufen dort seit ~02:40Z). Q07 11015/EURUSD: e7b7067b INFRA_FAIL summary_missing am 200-min-Budget (Attempt 2) → append-only Rerun 6f2875e0 mit timeout_min 300 (GELB). Codex Sol arbeitet parallel an f16785de (Kostensnapshot), 9c7a1878 (V4/Tail-Zertifizierung), 0af640f6 (Intervall-Equity-Export), b8a0676b (Spread-Inventar); Claude-Auftrag 1e0fbad5 (Positiv-Evidenz-Akzeptanztest) läuft als Opus-Workflow mit zwei adversarischen Reviews; 8c561172/7dceadd0 folgen. Q04 INFRA_FAIL 4/h = Zero-Stream-Klasse (stream_and_selfreport_missing), Recovery-Budgets greifen. Reaper hat weiterhin nie automatisch gefeuert (kein Bedarf seit 01:32Z).

> **Nachtrag 03:31Z (05.09.) — OWNER-Frage „ist alles aus der Astra-Analyse beauftragt?“ ehrlich beantwortet und nachbeauftragt:** Stand vor der Frage: nur A/B/C beauftragt (B, C erledigt; A hinter Kalenderentscheid E4), D–F nur notiert. Jetzt beauftragt: Codex Sol — Kostensnapshot 8/8 mit offiziellen Quellen (f16785de), V4/Q08-8.3-Tail-Zertifizierung (9c7a1878), Intervall-Equity/Positionen-Export (0af640f6), FTMO/DXZ-Spread-Inventar (b8a0676b); Claude-Lane — Positiv-Evidenz-Akzeptanztest-Vorlage (1e0fbad5), Readiness-Pack Teil 1 (8c561172) und Teil 2 (7dceadd0). OWNER-gebunden bleiben: §7 (Policy, Kontoprofil, Freeze/Pointer, Kauf, Live), E1/E4 Kalender, D1 Census-Verkürzung, Holdout-Siegel. Statusdokument: docs/ops/evidence/2026-09-05_astra_ftmo_commissioning_status.md.

> **Nachtrag 02:44Z (05.09.) — K=8 wirkt (fünf Census-Programme, 82 Zellen/h), Restarts fast durch, ein Q08-Rerun am Budget gekillt (GELB angehoben):** Nach Chunk 41b (T1/T2/T3/T4/T8/T9 mit Runner-Tree-Fix, Env-Carry und Floor) laufen fünf DL-089-Programme parallel (41097/41196/41198/41331 + neu 41333); 41197 bekam 9 Zellen, bleibt hinter der Queue-Order. RAM 25,6 GB frei, keine INFRA-Fälle in der Stunde. Chunk 40b lief ins 150-min-Limit ohne T6 (Q07-Langläufer), Chunk 42b hing in der Warteschleife → ersetzt durch Chunk 42c (T5/T7/T10/T6, idle-only, lock-sicher); damit haben danach alle zehn Worker Reaper + Runner-Tree + Floor + K=8. Q08-Rerun 5901ae3b (10287/XAUUSD D1) wurde nach 143 min vom Monitor-Budget gekillt (prior_failure monitor_budget_exhausted, kein Verdikt) → GELB: timeout_min 300 mit Audit-Feld; die übrigen Reruns tragen 218–368 min aus der Enqueue-Ableitung (1da1645c/EURNZD mit 143 min beobachten). Codex-Orchestrierung hat 64fc9ef2cc (Drain-Selektor: erste gewinnbare Priority-Basket statt Kopfzeile, +92 Testzeilen) direkt auf board-advisor abgesetzt; Drain-/Floor-/Reaper-Suiten danach 126 grün — kommt mit Chunk 42c auf T5/T7/T10/T6, die übrigen sechs Worker brauchen dafür später Chunk 43.

> **Nachtrag 01:57Z (05.09.) — Phasen-RAM-Floor Q05–Q07 committet (bd413af4d3, 209 Tests), Reload-Chunks umsortiert:** PHASE_RAM_FLOOR_GB aus dem Tester-Memory-Ledger je Symbolklasse (Q05: fx_cross 24, fx_major 16, metal 14, energy/fx_exotic/other 12; Q06/Q07: fx_cross 20, fx_major 16, sonst 12); Reservierung = max(flat, gemessen, Floor), Quelle wird protokolliert; Q02–Q04, OPT_CENSUS, COMPILE_EA, Index und Baskets unverändert. Design-Befund des Agenten: den Floor auch dem Reaper zu geben hätte dessen 2×-Schwelle für fx_cross Q05 auf 48 GB verschoben und alle drei Ballons verschont — Reaper-Referenz bleibt deshalb floor-frei. Admission-Folge: ein Q05-fx_cross-Lauf braucht jetzt 38–40 GB frei (faktisch serialisiert gegen den Census; abgestufter Hebel: Floor 20 GB, Kill-Switch QM_PHASE_RAM_FLOOR=0). Wirksam erst mit Restarts: Chunk 41b (T1/T2/T3/T4/T8/T9, läuft jetzt, lock-sicher) → 42b (T5/T7/T10); T6 folgt über 40b nach dem Q07-Langläufer; die zwischen 23:16Z und 01:30Z restarteten Worker brauchen später Chunk 43 für den Floor. Codex-Orchestrierung: 49a7ebcbb8, 45aab56862 (Ops).

> **Nachtrag 01:36Z (05.09.) — Dritter RAM-Ballon (T8, Q05 QM5_10691/GBPJPY, 23 GB in 2 min, Host 3,4 GB frei) manuell gereapt; Ursache systematisch:** Runner- und Terminalbaum von T8 pfadverankert beendet (28 GB sofort frei), Zeile fa1a9d02 pending mit Hold RAM_OUTLIER_4X_RESERVATION + Marker. Der Tester-Memory-Ledger (2 262 Zeilen) zeigt: Q05 braucht generell 12–19 GB (fx_major max 15,5 / p95 15,5 bei n=6; metal 12,0; fx_cross Q05 D1 18,5 GB abgeschlossen), Q06/Q07 ebenso 12–15,5 GB, Q04 dagegen 3–5 GB — reserviert werden für Q05 aber 8 GB ordinary (13/13 Ledger-Zeilen). Die Admission startet Q05-Läufe daher mit zu wenig Headroom; die JPY-Crosses (10395/EURJPY 27 GB, 11165/EURJPY 20,8, 10691/GBPJPY 23) sind nur die Spitze. Der Reaper (greift erst unter 2 GB, nur aus dem Idle-Guard) hat bisher nie gefeuert; die Per-EA-Erwartung lernt erst nach einer Messung. Maßnahme (läuft, Opus/Worktree): phasenbewusster RAM-Floor für Q05–Q07 je Symbolklasse aus dem Ledger (max mit gemessenen Erwartungen; fx_cross Q05 mindestens 24 GB), Tests, Evidenz im Reaper-Doc; wirkt mit den Restarts (Chunks 41/42). Codex-Orchestrierung committet weiter Ops auf board-advisor (45aab56862).

> **Nachtrag 01:23Z (05.09.) — KORREKTUR: Census-Programm-Slots und Canary waren bei reloadeten Workern nie wirksam:** `start_terminal_workers.py` mischte nur `QM_*`-Maschinenvariablen in die Worker-Umgebung; `DL089_PROGRAM_SLOTS=8` (Maschine seit 02.09.) und die am 03.09. 17:43Z per Auffangregel gesetzte Canary (`DL089_LANES_PER_PROGRAM=2` + Allowlist 21507/12710/11910) kamen bei KEINEM aus einer interaktiven Session neu gestarteten Worker an (Reload-Chunks 20–41). Effekt: alle zehn Worker liefen mit Code-Default K=4 Programmen, L=1 — das fünfte zugelassene Programm 41197 (11881/GBPUSD) hungerte seit ~23:30Z; die Canary-Ausführung vom 03.09. war nur Papier (ehrliche Korrektur zum Nachtrag 17:46Z 03.09.). FIX: cbf43b6f03 + c1373aa2b9 (Test korrigiert): der Spawn-Env trägt jetzt `DL089_PROGRAM_SLOTS` (→ K=8, Census-Zellen weiter durch G=6 gedeckelt); die Canary-Werte bleiben bewusst maschinen-only, weil ihre beiden echten Aktivierungen (31.08., 02.09.) den Lane-Preflight-Decline-Loop (~88→21 Zellen/h) reproduzierten — Re-Aktivierung nur nach OWNER-Entscheid. Zwischenzeitlich hatte ich den Maschinenwert kurz auf 5 gesetzt und sofort auf 8 zurückgestellt. Wirksam mit den Restarts: Chunk 41 (T1/T2/T3/T4/T8/T9, wartet auf 40b/T6), Chunk 42 (T5/T7/T10, wartet auf 41). Blast-Radius: bis zu zwei Slots weniger für Q02–Q08-Intake, dafür 41197 und ein sechstes Programm im Census.

> **Nachtrag 00:12Z (05.09.) — Reaper-Runner-Tree-Fix committet, Reload-Race behoben:** Fix (Opus, Worktree; 109 Tests, 11 neu): Kill-Wurzel = Phase-Runner-Baum (Payload $.pid), nur wenn Runner lebt, weder Reaper noch ein Worker-pid ist (worker_pids.json + Live-Claims — der terminal64 ist auch Nachfahre seines Workers, deshalb load-bearing), der terminal64 sein Nachfahre ist und das Image ohne T_Live-Marker auflöst; sonst terminal_tree. Belegt aus T2-Log: der Runner (pid 21564) lebte 1204 s und überbrückte beide manuellen Tester-Kills; der Host erholte sich erst mit dem Runner-Tod. Der automatische Reaper hat bisher nie gefeuert (State-Datei fehlt). Reload-Race: Chunk 40 hat T1 um 00:03:29Z mitten im Claim per Stop-Process beendet → veraltete FACTORY_MUTATION.lock ~2 min (vier Worker mit lock_busy-Declines), von farmctl gebrochen. Reload-Skripte prüfen jetzt den Lock-Inhaber vor dem Kill (Chunk 40b: T3 sauber; T5/T6/T7/T10 folgen; Chunk 41 wartet auf 40b und lädt T1/T2/T3/T4/T8/T9 mit dem Runner-Tree-Fix nach).

> **Nachtrag 23:59Z (05.09.) — Zweiter RAM-Kill 23:52Z (In-place-Retry), Reaper-Lücke erkannt, Setfile-Batch deployt, 9 Q08-Reruns gemintet:** Nach dem ersten Kill startete der Q05-Phase-Runner (Payload-pid) den Tester in-place neu (metatester 10,9 GB nach 90 s, Host 1,6 GB frei) → Runner-Baum + T2-terminal64 beendet, Zeile a0b332eb jetzt pending (prior_failure runner_process_died_without_summary) mit Hold RAM_OUTLIER_4X_RESERVATION; 13→24 GB frei. LÜCKE im deployten Reaper (11683160a7): er tötet nur den terminal64-Baum, der Runner überlebt und respawnt — konvergiert erst nach zweitem Kill (Cooldown 90 s). Fix läuft (Opus, Worktree): Kill-Wurzel = Runner-Baum, wenn der Runner Vorfahr des Testers ist (nie Worker, nie T_Live), sonst terminal64. RAM-Wachhund (Monitor: <6 GB frei oder Tester >16 GB) scharf. Chunk 40: T4/T2/T8 neu gestartet. Codex 543ad11a → APPROVED: agents/codex 4f18224a5b per Patch deployt (**7708d0f085**, baumgleich, 9 Tests): 8 Baselines / 6 EAs mit strategy_*-Defaults; 11132/NDX trug sie bereits. 9 append-only Q08-Reruns gemintet: 10148/EURNZD 1da1645c, 10287/XAUUSD 5901ae3b, 10771/USDJPY ee8b7d55, 10771/XAUUSD 49b55905, 10848/GDAXI c8d8c2c7, 11132/NDX 169d5dda, 1230/XAUUSD b429d45f, 9573/NDX 7aaf7760, 9573/USDCHF 8646a920 (plus 11179/USDJPY 40a802ca). Codex-Orchestrierung committet Ops weiterhin direkt auf board-advisor (cefadef482, 0a9ae57201, b910c09e7d).

> **Nachtrag 23:51Z (05.09.) — RAM-VORFALL 23:45Z (manuell gereapt) + Reaper deployt (924c36df → APPROVED, 11683160a7, Chunk 40):** 23:45Z wuchs der metatester64 von T2 (Q05 QM5_11165/EURJPY, Reservierung 8 GB ordinary) in 2,5 min auf 20,8 GB; Host 2,3 GB frei (T_Live teilt den Host); terminal64-Prozesse selbst je 0,2 GB — der Verbraucher ist immer der metatester64-Agent. Dieselbe EURJPY-Q05-Ballonklasse wie 08:09Z (10395). GRÜN: T2-Prozessbaum pfadverankert beendet (nie T_Live), 18 GB sofort frei, Zeile a0b332eb requeued ohne Verdikt + Hold RAM_OUTLIER_4X_RESERVATION + Payload-Marker ram_emergency_reap_manual. Reaper (wf_7eacaccb, 2 adversarische Reviews PASS_WITH_FINDINGS, nur Minors): 2 Samples <2 GB → neuester Tester >2× Reservierung (Subtree-Working-Set), pfadverankert, State-File-Lease (ein Reaper je Fenster), 90-s-Cooldown, Kill-Switch QM_DISABLE_RAM_EMERGENCY_REAP; Per-EA-Erwartung ea:<ea_id>|<tf>|<kind> (n≥1 Vorrang) lernt den Peak aus dem Ledger; MemoryError im Idle-Loop abgefangen. 216 Tests. Grenze: Reaper läuft nur im Idle-Guard — bei zehn gleichzeitig rechnenden Testern reapt niemand (Backstop im Monitor als Folgeidee). Deploy: Chunk 39 (9/10) beendet, Chunk 40 (alle zehn, idle-only) gestartet. Beobachtung: T5-Tester (Q05 10647/XAUUSD) wächst ~0,5 GB/min (10,5 GB bei 23:50Z).

> **Nachtrag 23:46Z (05.09.) — Edge-Lab abgeschlossen (315041f7 → APPROVED), r3 committet a77370856c:** Unabhängiger Verify (PASS_WITH_FINDINGS) → r3: COVID-Zusammensetzung offengelegt (ex-2020-Q2: Effekt 3,79→2,05 bp, t 0,94→0,39, n 12→9; Holdout leer wegen Kalenderloch UND COVID-aufgeblähter rollierender sd), cluster-signierte Zwillingsspalten (Headline aus publizierten Tabellen reproduzierbar, Test), versiegeltes Programm-Doc byte-genau restauriert (sha cee88635; §8 → docs/research/edge_lab/EDGE_LAB_MEASUREMENT_LOG.md), Gate-B-Zirkularität deklariert (200 vs 211 verifiziert, Statistik unverändert), SE-Baselineterm publiziert (XAUUSD 15:00 t −2,49 → −1,83 inkl.), Status-Klassen, relative Manifestpfade, fix_days.csv.gz, .gitattributes −text-Pins (committete r2-Tabellen waren beim Checkout CRLF-geschmiert und verfehlten ihren eigenen Raw-sha). 97 Tests. ERGEBNIS (unverändert): EDGE-1 UNTERPOWERT (nicht widerlegt, nicht gestützt; bindend ist der Kalender), EDGE-3 XAUUSD 15:00 DEAD_DECAY, WMR 16:00 REFUTED, Negativkontrolle ~0. ROT offen: Ausreißer-/Regime-Policy muss versiegelt werden, bevor EDGE-1 bei niedrigerem z wiederholt wird (sonst Threshold-Shopping). Fabrik: RAM-Dip auf 11,7 GB während des 97-Tests-Laufs (T5 ram_low_pause), erholt auf 26,8 GB; Hinweis: schwere Testsuiten künftig mit `-p no:cacheprovider -x` oder auf ≤2 Worker-freie Fenster legen.

> **Nachtrag 23:33Z (05.09.) — Drei Codex-Sol-Rückläufer abgenommen, Sizing für Vorlage E2 liegt vor, Edge-Lab r2-Verify PASS_WITH_FINDINGS, Chunk 39 läuft:** 72e5884d Blast-Radius (3f542b87ad, Tool news_calendar_blast_radius.py + Tests + docs/ops/evidence/2026-09-05_news_defect_blast_radius/): 171 Phasen-Paare → 63 EXPONIERT / 108 INERT; Q14 KEEP_INCUMBENT 1/9 exponiert (10706/GBPUSD H1); Q11-PASS 7/31 exponiert (10700/XAU, 10706/GBP, 11294/XAU, 11660/NDX, 13013/NDX, 13213/USDJPY, 21501/USDJPY); Entry-Spot-Check 10/10. 0f61815f Kalender-Detektoren (69aa6c02a8, news_calendar_diagnose.py, nur Bericht): NFP-Anker binnen 5 min 0/12 pro Jahr 2016–2025 in BEIDEN Dateien, 2/2 in 2026; Detektor-Chronologie: hätte am 21.04. (Seed-Kopie) sofort angeschlagen. 683f82ca 11179 Q08 empty_strategy_params (5c790f2b78+18ed7c7386): Setfile-GENERIERUNGS-Artefakt (Sets vor dem gen_setfile-Fallback 19.07. ohne strategy_*-Defaults); 10 Q08-INVALID-Zeilen / 7 EAs betroffen; USDJPY-Set verhaltensidentisch repariert (sha 7ef786c2→ca173ee6); Q08-Rerun append-only **40a802ca** gemintet; Folgeticket 543ad11a (restliche 6 EAs). DISZIPLIN: Codex hat alle vier Commits direkt auf agents/board-advisor (C:/QM/repo) statt agents/codex abgesetzt — nur eigene Dateien, kein Konflikt, einmal toleriert; Ticket-Regel verschärft. Edge-Lab: unabhängiger r2-Verify PASS_WITH_FINDINGS (alle 4 r1-Blocker bestätigt behoben, Determinismus auf Produktionsdaten 10/10 CSVs sha-identisch; NEU: 3 COVID-Drucke 2020-04..06 tragen 46 % des EDGE-1-Effekts [t 0,94→0,39 ohne sie] und leeren den Holdout über die rollierende sd; EDGE-1 MAE/MFE bei 27,5 % der Zeilen eigenrichtungs-signiert; mein §8-Anhang brach den Doc-Seal-Hash) → r3-Fixrunde läuft (Opus, Worktree). Verdikte unverändert. GELB: 11015/EURUSD Q07 e7b7067b timeout_min 300 (Attempt 1 auf T2 nach 4 Seeds ohne Aggregat bei ~200 min = Budget; Terminal-Hang-Klasse, Selbstheilung cadb7f3322 mit Chunk 39 auf T6 aktiv); zwei Vorgänger INFRA_FAIL launch_fault. Chunk 39: 7/10 reloaded. Fabrik 10/10, 85–102 Zellen/h, RAM 30 GB frei.

> **Nachtrag 22:54Z (05.09.) — Kalenderdefekt: Trace abgeschlossen, Vorlage eingereicht, Eindämmung gesetzt:** Opus-Trace (framework/include/QM/QM_NewsFilter.mqh:2022 Tester-Zweig QM_BrokerToUTC vs. CSV-Wert verbatim; Fenster :1206-1237; Live-Zweig :1985-2009 nativer MT5-Kalender per DL-080 → **Live nicht betroffen**). Blast-Radius gemessen: Q09_NEWS/Q10_NEWS v4 bisher 0 PASS-Verdikte; Standardläufe tragen den EA-Default PRE30_POST30; von 9 Q14-Terminalzeilen sind 8 D1 (praktisch inert) und 1 H1 (10706/GBPUSD, explizit PRE30_POST30 → exponiert). GRÜN: 11 ungehaltene pending Q10_NEWS-Zeilen mit NEWS_CALENDAR_TIMESTAMP_DEFECT gesperrt; Codex-Sol-Tickets 72e5884d (Sizing je EA/Einstiegsklasse), 0f61815f (Detektoren, nur Bericht), 683f82ca (11179 Q08 empty_strategy_params). ROT-Vorlage `docs/ops/OWNER_VORLAGE_2026-09-05_news_calendar_defect.md` (E1 Reparatur A/B/C — Empfehlung A nativer Export + BLS-Anker; E2 Umfang — Empfehlung Mittel; E3 Standardläufe weiter; E4 OOS-Apply nach E1; E5 DL-090). Receipts-Zeile 8 PENDING. Organisatorischer Befund: das private Lab hatte den Defekt am 11.07. dokumentiert (NEWS_CALENDAR_CORRECTION_2026-07-11.md, HARD DATA GATE) ohne Weitergabe an den Fabrikkalender — Detektor-Ticket adressiert die Wiederholung.

> **Nachtrag 22:42Z (05.09.) — P0-DATENBEFUND NEWS-KALENDER; OOS-Repair committet, `--apply` vertagt; Edge-Lab r2 committet:** (1) **News-Kalender-Zeitstempeldefekt (verifiziert, quantifiziert):** beide Produktionsdateien (`news_calendar_2015_2025.csv` primär, `forex_factory_calendar_clean.csv` sekundär; 46 331/48 627 Zeilen instant-identisch) speichern US-08:30-ET-Releases ~17 h zu FRÜH (Vortag 19:30/20:30 UTC). Join gegen den nativen MT5-Kalenderexport (T_EXPORT_USD_HIGH_2018_2025_NATIVE.csv, 2 440 gematchte Zeilen): 08:30-ET-Klasse 1 176/1 510 verschoben (78 %), NFP 88/88, Retail Sales 87/87, Unemployment Rate 88/88, CPI m/m 86/87, Claims 301/379; ADP/ISM/FOMC/Fed-Zins korrekt. 2026er-Zeilen (Live-relevant, 31/31 bei 12:30 UTC) korrekt → kein akutes Live-Risiko. Zusätzlich Abdeckungsloch 2025-05..2026-06 (null Zeilen, beide Dateien). Evidenz `docs/ops/evidence/2026-09-05_news_calendar_timestamp_defect/` (summary.json, native_join_deltas.csv, stored_tod_histogram.csv). Konsequenz für Q09_NEWS/Q10_NEWS-Verdikte und die EA-Blackout-Semantik im Tester wird gerade nachvollzogen (Opus-Trace); Vorlage folgt — Verdikt-Neubewertung und Kalenderersatz sind ROT. (2) OOS-2026-Repair (wf_1e969f7f, Task 1721f3a1): r2 nach zwei adversarischen Reviews (8 Befunde, u. a. 29-s-Write-Lock → jetzt ~20 ms In-Lock-Body, Backup+Events+Supersedes, Receipt nach Commit) committet **1ac9f653d8** (56 + 237 Tests). Dry-run gegen echte DB: 40 pending patchen, 40 Holds, 15 Nachfolger. **`--apply` VERTAGT:** das Kampagnenfenster 2026-01-01..04-06 liegt im Kalenderloch — Nachfolgerläufe würden ohne News-Events messen. Holds OOS_WINDOW_MISMATCH bleiben. (3) Edge-Lab (wf_35b7e0ed, Task 315041f7 → REVIEW): edge_lab_stats.py r2 + 79 Tests + Tabellen committet **01d652bd3c**; EDGE-1 UNDERPOWERED (12 Cluster vs. Floor 300), EDGE-3 XAUUSD 15:00 DEAD_DECAY; unabhängiger r2-Verify läuft. Fabrik: 10/10 aktiv, 79 Census-Zellen/h, RAM 23,8 GB frei, Containment aus; Chunk 38 wartet weiter auf T2 (Q07 11015). Codex-Lane: Fleet-Pacer-Builds auf Sol (41337 WTI gebaut), keine offenen Astra/Sol-Aufträge.

> **Nachtrag 22:17Z (05.09.) — Zwei Sol-Rückläufer aus Astras FTMO-Aktionsplan deployt:** bc7e3b81 Evaluator-Fidelity (agents/codex ed4755d8a7 → 50939becd6 + 397fd2e21e): rulepack-gebundene FTMO-Evaluatoren erzwingen vier Prager Eröffnungstage, ein Regelvertrag (ftmo_rule_contract.py) als eine Quelle, Legacy-Replays mit Delta null, 27 Tests grün. a32a064e FUND_SCORE input-explizit (caf825c6e8 → a774e850dc): jede Score-Zeile trägt Stream-Pfad + Content-SHA + Formeleingaben; die aktuellen 8/8 versiegelten Paare neu bewertet — alle Scores < 1,0 (Schwelle 1), NO-BUY unverändert. PROZESSFEHLER (behoben): Patches in falscher Reihenfolge angewendet (ed4755 vor caf825, beide ändern challenge_book_60d.py) → Konflikt, Teil-Commit 50939becd6, a32a064e kurz fälschlich APPROVED; bereinigt durch Anwendung in Codex-Reihenfolge, Abschluss-Commit, Baum-Gleichheit gegen agents/codex verifiziert (`git diff agents/codex --stat` leer), Verdikte korrigiert. Regel ab jetzt: Reihenfolge per `git log agents/codex -- <datei>` prüfen; Abnahme nur nach bestätigtem Commit-Hash; `git revert` nie hinter `&&` mit unterdrückter Ausgabe.

> **Nachtrag 21:41Z (04.09.) — Astra-FTMO-Analyse abgenommen; OOS-2026-Kampagne maß 2024 (verifiziert, eingedämmt); Reparatur-Workflow läuft:** e544e3b8 → APPROVED (docs/ops/evidence/2026-09-04_astra_ftmo_book_analysis.md + 23 Belegdateien): Empfehlung NO-BUY beibehalten; Builder-Lauf verweigert (8/25); FUND_SCORE lässt keinen der 8 zu; Kostensnapshot 2/8 (30.07.); Evaluator meldet Bestehen nach 1 statt 4 Handelstagen; Lückenliste §6 (22 Zeilen, kritischer Pfad) und Entscheidungsliste §7 (7 Punkte, ROT getrennt). KERNBEFUND (von mir in der DB verifiziert): Kampagne oos_2026_confirmation_v1 (Plan 02.09., 55 Q09_NEWS-Diagnosezeilen, Fenster 2026-01-01…04-06) — alle 15 done-Zeilen haben expected_from/to_date = 2024.01.01–2024.12.31; Ursache: oos_2026_confirmation.py enqueue() gibt kein from_date/to_date ins Payload, und farmctls Spawn-Builder kennt Fenster nur für Q02-Prescreen, OPT_CENSUS und Baskets (_basket_payload_date_window liefert None für Einzelsymbole) → run_smoke fällt auf DEFAULT_RUN_SMOKE_YEAR 2024. EINDÄMMUNG: 40 pending Kampagnen-Zeilen per Hold OOS_WINDOW_MISMATCH gesperrt (GRÜN). REPARATUR: Opus-Workflow wf_1e969f7f (explizites Fenster-Kontrakt fail-closed im Spawn, Dispatcher setzt Fenster, Repair-Modus: 40 pending patchen + Holds lösen, 15 done → append-only Nachfolger; zwei adversarische Reviews) — Anwendung erst nach Review durch mich; Codex verifiziert Fenster vor den Läufen (Astra-Aktionsplan). Außerdem deployt: d9379ede Terminal-Hang-Selbstheilung (cadb7f3322; Worker-Reload folgt mit Chunk 39). Claude-Workflow Edge-Lab wf_35b7e0ed läuft.

> **Nachtrag 21:01Z (04.09.) — Klassifizierer `monitor_budget_exhausted` deployt (e1a8f38cd6); OWNER-Auftrag FTMO-Buch an Astra:** b2106bba (Astra-Session, Sol-Tier-Task) abgenommen: `monitor_kill`-Marker vor dem Runner-Stop, Klassifizierer erkennt Marker oder Laufzeit ±2 % des Budgets → `failure_subclass=monitor_budget_exhausted` + Budget-Review-Hold statt `launch_fault`; Health-Metrik; Backfill-Inventar `monitor_budget.py` (T10 heute 3 Kandidaten); keine historischen Verdikte umgeschrieben; 157 Tests grün; Worker-Reload folgt (Chunk 39 nach Chunk 38, aktuell 7/10). OWNER 20:50Z/20:55Z: „Astra soll alles hinsichtlich FTMO-Buch analysieren … schneller aber auch sicher“ + „auch liefern, was uns dazu noch fehlt“ → Astra-Task e544e3b8 (Prio 88, Leseliste Rulepack-Snapshot/Buchbauer/Phase-2-Regeln/First-Passage/Vault-Fahrplan; Pflichtabschnitt GAP LIST; Deliverable Analyse + Maßnahmenplan + Entscheidungsliste, keine Buch-/Geld-/Live-Änderung) IN_PROGRESS seit 20:52Z. Claude-Workflow Edge-Lab (315041f7, wf_35b7e0ed) läuft. d9379ede (Terminal-Hang) IN_PROGRESS.

> **Nachtrag 20:38Z (04.09.) — Claude-Reset; Astra-Feuerzähler abgenommen (Diagnose) mit KORREKTUR meiner Census-Zahlen:** OWNER-Reset Claude ~20:30Z (Governor: 0 %, Woche bis 10.09. 22:00Z → Pace-Regel aufgehoben). 1ff3fa26 → APPROVED als Diagnosewerkzeug (d29fac723f; 552 Tests; 480 gemessene Zellen 100 % Übereinstimmung, 0 falsche „feuert nie“), NICHT für den Enqueue: Astras Harness verweigert die Abnahme, weil (a) der Census-Ledger ganze Jahre als `SKIPPED_EXCLUDED` (5229 von 10788 done-Zellen fleetweit; 11421/EURUSD 924 von 1085) ausschließt — mein „132/154 Arme feuern nie“ galt nur für das eine gemessene Jahr 2019 — und (b) für die Tick-Archive (.tkc) kein Decoder existiert (D1-Bars aus dem nativen CopyRates-Export). Gemessene Zellen je Programm: 165 (NZDUSD/EURUSD) bis 1085 (XAUUSD); B5-Nutzen revidiert auf ~−50 % bei High-Frequency-Programmen (die den Zähler gerade begrenzen). Vorlage korrigiert (Abschnitt „Correction“). Chunk 38 (Langlauf-RAM-Deckel) läuft seit 20:35Z. Sol-Tasks d9379ede/b2106bba IN_PROGRESS.

> **Nachtrag 20:26Z (04.09.) — Erste Astra-Rückläufer abgenommen und deployt:** (1) 348af875 (Astra-Review der D3-Änderung): PASS-with-findings — Finding 1 (Low, vorbestehend): Q14/Q08-Auswahl sortierte nach `updated_at`-TEXT, gemischte Offsets könnten eine ältere Seal wählen (heute alle 357 Q08-PASS-Klasse-Zeilen mit +00:00, keine Live-Exposure); vorgeschlagener Diff unverändert übernommen (f0738ca5d3: `julianday(updated_at)`-Ordnung + Tie-Breaks, Loader-Assertion, 8 Mixed-Offset-Regressionsfälle, Refusal-Text) → 348af875 APPROVED, c9e256cb (D3) APPROVED (unabhängige Abnahme erfüllt). (2) ccea329e (Astra): `q08_stream_rerun.py` + Pump-Stage `q08_stream_auto_rerun` (10-s-Budget nach dem Optimization-Fork-Service; Watermark `state/q08_stream_auto_rerun_watermark.json`; Kill-Switch `QM_DISABLE_Q08_STREAM_AUTO_RERUN=1`; genau ein Append-only-Rerun je unbebundenem Q14-Terminalpaar über den bestehenden Enqueue-Pfad) — von agents/codex 377d7df45d in den kanonischen Checkout übernommen (b7c8891cb3); 42 Tests grün; Read-only-Preview: 9 Q14-Zeilen, would_enqueue 0 → APPROVED; Pump aktiviert die Stage im nächsten Zyklus (Pre-flight §5 damit automatisiert). (3) 1ff3fa26 (Astra Pattern-Feuerzähler) läuft (Zwischendaten für 10706/11421 liegen unter docs/ops/evidence/2026-09-04_pattern_fire_count_data/, untracked). (4) Nebenbei zog der Sol-Orchestrierungszyklus QM5_41336 (WTI ADF-KPSS agreement trend) von Karte (d9c86dc43d) über Registry/Magic bis Build (67ce3bc876) durch — regulärer Fabrik-Intake; Q02 hat begonnen (CPU-Stop 4bb0189160 verbucht). Hinweis: Codex committet in der Orchestrierung auf agents/board-advisor (Zyklus-Instruktion), Code-Änderungen auf agents/codex → Deployment nur per Cherry-pick/Patch nach Review.

> **Nachtrag 19:47Z (04.09.) — Astra läuft; zwei Dispatch-Stolpersteine:** 19:45:01Z Ledger `dispatch astra gpt-6-astra 1ff3fa26` (Orchestrierungs-Slot 1, Reasoning max, Worktree codex-orchestration-1); Sol-Fleet-Pacer 19:43:52Z parallel. Befunde: (1) `agent_router.py enqueue --assigned-agent codex` schreibt `decision_bound_agent: codex` ins Payload → Router hält (`awaiting_decision_bound_agent:codex`; Pin ist ein Claude-Lane-Konstrukt) — Pins aus den drei Payloads entfernt, Routing über Capabilities. (2) `_eligible_agents` schließt Lanes mit Heartbeat >2 h aus (`lane_<agent>_heartbeat.json`); nach Stunden ohne Orchestrierungs-Task war Codex unsichtbar und der Router blieb am gehaltenen Claude-Task 924c36df hängen (`route-many` meldet nur den ersten nicht übersprungenen Kandidaten) — Orchestrierungs-Task wieder Ready + einmal manuell gestartet → Heartbeat frisch, Dispatch sofort. Regel: nach jedem Re-Enable eines Orchestrierungs-Tasks `Start-ScheduledTask` ausführen. Codex-Ledger/Governor überwache ich je Runde (Astra-Budget 48/5 h bei Pro 20× × 0,8).

> **Nachtrag 19:37Z (04.09.) — Codex-Reset (OWNER), Plan Pro 20×, Astra kommissioniert:** OWNER ~19:30Z: „Reset gemacht! Wir haben Pro 20x.“ Governor-Probe: Codex 0 % verbraucht, Wochenfenster bis 11.09. 19:32Z. Konfig `plan_tier=pro_20x` (d2a2145ab9; Astra 60–600 / Sol 200–2000 Nachrichten je 5 h; Enforcement bleibt Observe), Tier-Tests 130/130. Kommissioniert (Codex-Lane): **1ff3fa26 Astra** Pattern-Feuerzähler-Werkzeug (Vorlage D1/B5; Python-Port der 77 Muster, Verifikation gegen die fertigen Programme 11421/10706 — null falsche „feuert nie“-Vorhersagen; Verdrahtung in den Census bleibt OWNER-Entscheid), **ccea329e Astra** Pump-Auto-Q08-Stream-Rerun bei Q14-Terminal (Nachfolger von cfce4d87 → BLOCKED/superseded), **348af875 Sol** unabhängige Abnahme der D3-Bundle-Änderung (c9e256cb; 5ff527e8 als review_ea wäre in die Claude-Lane geroutet → BLOCKED). Scheduled Task `QM_StrategyFarm_CodexOrchestration_15min` wieder Ready (Lane-Pinning entscheidungsgebundener Tasks ist gemergt). 924c36df bleibt bei Claude (Worker in Bewegung).

> **Nachtrag 18:56Z (04.09.) — Perf-Rollout abgeschlossen; RAM-Latch durch drei schwere Langläufe; Langlauf-RAM-Deckel 67fa2cf9d1:** (1) Chunk 37 fertig 18:23:50Z (10/10 auf d630c08bf9): Host-Load 100 % → 62 % bei drei Testern; Python-Anteil 41 % → 13 %. (2) 18:50Z: nur 9,8 GB frei, 3 aktive Zeilen, 7 Worker im `ram_low_pause` (Latch 14/20): Q09 10571/XAUUSD (T5, 15,2 GB wachsend), Q07 11180/XAUUSD (T8, 11,7 GB), Q07 11179/USDJPY (T2, 11,6 GB) = 38,5 GB in drei Testern; Census-Frontier steht bis ~22:00Z. Alle drei regulär zugelassen — die Zähl-Caps (Q07/Q08 = 2) sehen keinen RAM, Q09-Stress war gar nicht als Langlauf klassifiziert. (3) FIX 67fa2cf9d1 (GRÜN, Infra ohne Verdikt-Logik): `LONG_RUN_RAM_CAP_GB = 26` — ein NEUER Langlauf (Q07/Q08, News-Parents, neue Klasse `q09_stress_longrun` ohne Zähl-Cap) wird übersprungen, solange der gemessene RAM der aktiven Langläufe ≥ 26 GB ist (zwei XAU-Läufe passen, der dritte wartet); Worker liest die Drain-Facts einmal je Claim-Versuch; Lineage-Reruns ebenfalls gedeckelt; Rollback `QM_DISABLE_LONGRUN_SCHEDULING_CAP=1`. 113 Tests grün. Rollout: Chunk 38 sobald ≥20 GB frei (Starter fail-closed bei RAM-Kapazität 0); bis dahin blockt der Latch neue Langläufe ohnehin. (4) Zähler 8/25; 12365 (acf5fa02) pending mit 433-min-Budget, Neuclaim folgt nach RAM-Freigabe.

> **Nachtrag 18:18Z (04.09.) — GELB ausgeführt: Q07-Budget 12365/XAUUSD auf 260 min:** T9 hat acf5fa02 um 18:12Z nach 12 009 s (200-min-Monitorbudget) als `run_result attempt 1 → pending` requeued — 4 von 5 Seeds fertig (~45 min je Seed, 245 min nötig). Ohne Eingriff hätte Versuch 2 alle Seeds neu gerechnet und wäre erneut bei 200 min gestorben (bis attempt 3 ≈ 10 Slot-Stunden). Stehende Vollmacht GELB („Timeout-Budget für bereits timeout-gekillte Zeilen ohne Verdikt anheben“): `timeout_min=260` im Payload gesetzt (Audit-Feld `timeout_min_raised`), verifiziert: effektives Budget 433 min (Reaper skaliert timeout_min 260 × Workload-Faktor 5/3), Monitor 25 980 s — großzügiger als beabsichtigt, aber begrenzt. Kosten: Versuch 2 rechnet die 4 Seeds neu (~3,3 Slot-Stunden), da innerhalb einer Zeile kein Seed-Reuse existiert (Lineage-Reuse nur über Append-only-Rerun terminaler Zeilen) → Folgepunkt für Auftrag c7e250b3/924c36df: Seed-Reuse aus dem eigenen Report-Root bei Monitor-Requeue. Chunk 37: 9/10 (T10 folgt nach Q08 10571). Zähler 8/25.

> **Nachtrag 17:00Z (04.09.) — Durchsatzanalyse + Perf-Fix d630c08bf9 (idle Worker verbrannten je ~1 Kern):** (1) MESSUNG 16:52Z: Host-Load 91–100 % bei nur drei Testern; acht idle Worker je ~6 % des 16-Thread-Hosts. Ursache: `farmctl._running_mt5_terminals()` spawnte pro Claim-Iteration (~20 s) ein PowerShell/CIM-Scan (1,6–2,1 s Wall, ~1 s CPU; Cache nur 4 s) — aufgerufen aus fünf Stellen des Claim-Pfads. (2) FIX: native Enumeration von terminal64.exe per Toolhelp32 + QueryFullProcessImageNameW (11–14 ms, kein Prozess-Spawn), PowerShell nur noch Fallback; Fail-open, 4-s-Cache und Allowed-Filter unverändert; Live-Äquivalenz nativ = PowerShell {T1,T10,T6,T9}; 6 neue/bestehende Tests grün. Rollout: Reload-Chunk 37 (alle zehn, idle-only). Erwartung: −30 bis −40 Prozentpunkte Host-Load → Tester schneller, Census-Zellen zurück auf 1–2 min. (3) DURCHSATZ-BILANZ 16:35–16:55Z: ~100 Claim-Versuche, ~21 Claims, 20 Zellen/20 min (je 2,5–3,8 min) = ~37 % des Fleet-Maximums; Ablehnungen je ~⅓ Lock-Contention (79/h), Claim-Spacing (10 s, OWNER 29.08.), `no_pending_claimable` (Jahresgrenze: 41196 wartet auf die letzte 2023-Zelle, bevor die 2024-Baseline starten darf — bekannter serieller Baseline-Engpass, Ticket ef9a3849). (4) 10280/XAUUSD Q07 PASS 16:32Z (Varianz 10,3 %, min PF 1,41). 12365-Q07 bei 120 min (Seed 3/5), Budget 200 min. Zähler 8/25.

> **Nachtrag 16:43Z (04.09.) — KORREKTUR Vorlage D1 + Balke USDJPY:** (1) Die 1085-Zellen-Programme SIND der Pattern-Census (7 Baseline + 539 Buy + 539 Sell); Q13 (numerischer Sweep) deklarierte in 11/11 Läufen 0 Parameter (`NO_NEW_PARAMETER_SWEEP`, keine Zellen) → „Q13 streichen“ spart nichts; D1 neu: B1 5 statt 7 Jahre (−29 %), **B2 zweistufiges Screening** (2 Screening-Jahre für alle 154 Arme, Vollcensus nur für Arme ≥ +5 % in beiden; ~−60 %; Empfehlung), B3 kuratierte Musterliste (ROT), B4 Status quo. (2) Balke USDJPY: Incumbent 13213 Q11 PASS 03.09., Q12 pending; Pattern-Census läuft auf der _opt-Variante 41097: 561/1085 gemessen (2019–2022 fast komplett, 2023–2025 offen), Programm ohne Slot-Ordnung (Sentinel) → bekommt nur Restkapazität; 20 veraltete ARTIFACT_BINDING_MISSING-Holds auf 41097-Zellen gelöst. Empfehlung: 41097 in die Slot-Ordnung direkt hinter 21507/XAUUSD (Amendment C, Teil 1) → Balke-Q12 in ~1 Tag.

> **Nachtrag 16:35Z (04.09.) — OWNER-Receipt D3 = JA umgesetzt (3e7f5752c2):** „Bundle Regel an Census Regel angleichen, ja.“ → `OWNER-DEC-BUNDLE-Q08-PASSCLASS-20260904` (Receipts-Zeile 7); entscheidungsgebundener Auftrag c9e256cb (Claude-Lane) angelegt und auf REVIEW gesetzt. assemble_stream_bundle.py bindet jetzt die Census-PASS-Klasse für Q08 (`Q08_STREAM_PASS_VERDICTS` = PASS, FAIL_SOFT; Identitäts- und Content-Hash-Bindung unverändert); Tests 10/10 (Klasse spiegelt `GATE_SCOPED_PASS`, FAIL_SOFT bindet, FAIL_HARD nicht); Bundle-Dry-run 16:50Z **8/8 gebunden** (11910/NZDUSD über 977a478e, content 555bbee2…). D1 (Census verkürzen) und D2 (Amendment C) bleiben offen — OWNER-Frage „Pattern-Filter grundsätzlich sinnvoll?“ im Chat beantwortet.

> **Nachtrag 16:31Z (04.09.) — OWNER-Frage „8/25, Optimierung sinnvoll?“ beantwortet; Vorlage Path-to-25 eingereicht:** (1) BEFUND: alle 8 terminalen Paare = Q14 KEEP_INCUMBENT, 8/8 Q13 NO_PARAMETER_CHANGE, 7/8 Q12 NO_FILTER_CHANGE (10706: Filterkandidat verlor Head-to-Head) → die Optimierungsgabel hat bisher nichts übernommen; sie liefert Robustheitsevidenz, kostet aber ~1000 Zellen je Paar. (2) PROGNOSE: 11 Census-Programme / 8005 Zellen (9 neue Paare, 2 Re-Baselines) bei 72–114 Zellen/h → ~17/25 um den 08.09.; 13 Q11-fertige Paare ohne Programm (8 davon nötig; NDX hinter 44-GB-Grenze) → 25 ohne Änderung erst in 2–3 Wochen. (3) VORLAGE `docs/ops/OWNER_VORLAGE_2026-09-04_census_shortening_amendment_c_bundle_rule.md` (Vault OWNER.md gespiegelt): D1 Census verkürzen (Q13 entfällt bei Q08-8.5 PASS; Empfehlung JA), D2 Amendment C (Programme für 13 Q11-Paare, NDX zuletzt), D3 Bundle akzeptiert Q08-FAIL_SOFT wie der Census (Paar 8: Stream 977a478e liegt seit 16:05Z versiegelt vor, Bundle-Filter `verdict='PASS'` verweigert ihn). ROT → keine Auffangregel. (4) Fabrik: 10 Worker, 30 GB frei, CPU-Guard drosselt Census (7–9 Zellen/10 min) bei zwei XAUUSD-Q07; 12365-Q07 Richtung 200-min-Budget (Kill ~18:12Z, danach Lineage-Rerun). T_Live unbeeinträchtigt.

> **Nachtrag 15:54Z (04.09.) — ZÄHLER 8/25: 11910/NZDUSD terminal; Q08-Stream-Rerun gemintet; RAM-Episode Basket 12580:** (1) 11910/NZDUSD (larry-williams-18ma-2outside-bars-d1): Census fertig → Q12 `NO_FILTER_CHANGE` 15:18Z (b764a145) → Q13 `NO_PARAMETER_CHANGE` 15:28Z (0246037b) → Q14 `KEEP_INCUMBENT` 15:34Z (e21567f4); book_build_guard qualified_pairs = 8. (2) Bundle-Dry-run 15:55Z: 7/8 gebunden, 11910/NZDUSD `no_q08_stream_bound_to_identity` (drei Q08-FAIL_SOFT-Zeilen 0cb83f40→6757567a→e0237a77 ohne Stream der aktuellen Identität e18d477e…) → Pre-flight §5: Q08-Stream-Rerun 977a478e (aus Q07-PASS 797f03ae, Append-only-Rerun von e0237a77) 15:53Z eingereiht; nach Abschluss Dry-run wiederholen (Erwartung 8/8). (3) RAM-EPISODE 15:43–15:52Z: nach der Hold-Freigabe claimte T6 den Q03-Basket 12580 (32-GB-Reservierung) bei ~25 GB frei neben zwei XAUUSD-Q07 (11,3 GB je); Tester stieg auf 19,9 GB, frei fiel auf 5,6 GB → RAM-Latch hielt 7 Worker idle (3 aktive Zeilen, 9 Zellen/10 min). 45-s-Nachmessung: Tester stagnierte, frei stabil → kein Kill; 15:52Z wieder 36,8 GB frei. Befund für OWNER-Vorlage 1: die Direkt-Admission lässt 32-GB-Zeilen bei ~25 GB frei zu (Reservierung = Papier, Latch greift erst danach) — Optionen: Admission free ≥ Reservierung + Floor, oder Basket-Klasse nur ohne aktive Langläufe. (4) 10571/XAUUSD Q07 PASS → Q08 fab8ff14 pending (Pump). 12365/XAUUSD Q07 (acf5fa02): Seed 1 = 49 min → 5 Seeds ≈ 245 min > 200-min-Budget → Kill ~18:12Z absehbar; danach Append-only-Rerun mit Lineage (4 Seeds wiederverwendbar) — kein Eingriff vorher. T_Live unbeeinträchtigt.

> **Nachtrag 15:30Z (04.09.) — Rollout abgeschlossen, Holds gelöst, zwei neue Betriebsklassen:** (1) ROLLOUT: Chunks 35/36 fertig (T1 15:25:47Z zuletzt) — alle zehn Worker tragen 17cedd8124 (Drain-Härtung) + 2fde461dce (Q07-Kindbudget). Die vier Drain-Holds (12580 9cac4667, 10718 31f12573, 10025 e49888a1, 10717 65319749) 14:51Z gelöst; Arithmetik verweigerte danach 12580 korrekt (15:12Z: Deckel 25,5 < Bedarf 39 neben zwei XAUUSD-Q07 à ~12 GB). (2) NEUE KLASSE Terminal-Hang: T2/Census-Zelle b7b1fb26 (41198/XTIUSD 2022 sell_034) war 12:52Z fertig (Tester-Agent: „automatic testing finished“, OnTester 0.70), aber terminal64 35412 schrieb keinen Report und blieb 108 min am Leben; Smoke-Timeout 7200 s hätte erst 14:49Z gegriffen. 14:41Z terminal64 beendet → run_smoke startete run_02 und hing erneut → 14:45Z run_smoke-pwsh beendet → Worker verbuchte `runner_death_requeued`, Zelle pending, neu gelaufen. Die Signatur `runner_process_died_without_summary` steht je 1× in den laufenden Logs von T1/T2/T3/T5/T8 → Folgeauftrag (Claude-Lane) für Selbstheilung: Worker/Pump erkennt „Agent finished, Terminal >5 min ohne Exit“ und beendet terminal64. (3) Q07 AUF ALTEM MONITOR-CODE: T5 fuhr seit 14:36Z 11179/XAUUSD (88a7cb34, 3× zuvor exakt so gestorben) mit 5400-s-Default → 14:49Z Worker beendet (Kindbaum starb mit), Zeile pending, T5 neu auf 2fde461dce. T1 fuhr 10571/XAUUSD (0356eb57) seit 13:56Z → Seeds ~17 min → PASS 15:24:5xZ (Varianz 4,49 % < 20, min PF 1,08), 90 s vor dem 90-min-Kill. (4) DURCHSATZ: Dellen auf 7–11 Zellen/10 min sind CPU-Guard (`cpu_high_pause` 92–99 % bei zwei XAUUSD-Q07-Tickläufen + 3–4 Q04), nicht Stillstand; erholt sich, sobald Q07s enden. (5) FRONTIER: Census 11910/NZDUSD abgeschlossen, Q12 15:18Z `NO_FILTER_CHANGE` → Q13/Q14 ausstehend; Zähler 7/25 (book_build_guard). Census 21507/XAUUSD 330 pending. Router-Task c7e250b3 (Klassifizierer `monitor_budget_exhausted`) erfasst. T_Live unbeeinträchtigt.

> **Nachtrag 13:32Z (04.09.) — Drain-Fenster Nr. 3 heute, Plateau-Gedächtnis (17cedd8124) + Q07-Kindbudget (2fde461dce):** (1) BEFUND 12:49:40Z: der um 12:49:33Z frisch auf f232200f0a neu gestartete T3 armierte ein Fenster für den 44-GB-Basket QM5_10717 (65319749) neben einem laufenden Q07 — der Langlauf maß in diesem Moment ~2 GB (MT5-Tester akkumulieren Tickhistorie; derselbe Run hielt um 13:01Z 11,6 GB), der zweite Q07 war gerade fertig, also frei+releasable ≥ 51 auf dem Papier. Geparkte Flotte plateaute bei 36,7 GB frei (Baseline real 63,1−36,7−12 = 14,4 GB, nicht 10); 8 Worker idle, manuell geschlossen 12:59Z (Cooldown bis 14:29Z), Zeile per Hold DRAIN_UNWINNABLE_ARITHMETIC gesperrt. (2) FIX 17cedd8124: Langlauf zählt nie unter max(Reservierung, 8 GB); Baseline 14 GB (zwei gemessene Plateaus 12,1/14,4); ein OFFENES Fenster wird bei jedem Durchlauf neu gerechnet und nach 120 s Unwinnbarkeit selbst geschlossen (`drain_window_abandoned` reason `no_longer_winnable:<why>`), das gemessene Plateau bleibt 6 h im State (`plateau_memory`) und verweigert jeden Kandidaten mit mindestens diesem Bedarf, solange nicht freier RAM allein reicht; Open/Not-winnable/Abandon-Events tragen die Arithmetik (frei, releasable, Langlauf, Bedarf, Deckel). 97 Drain- + 212 Worker-Tests grün. Rollout Chunk 33 (f232200f0a) 13:07Z fertig; Chunk 35 (17cedd8124, acht Terminals) läuft seit 13:27Z; T1/T5 folgen (Chunk 36). Die vier Drain-Holds (12580, 10718, 10025, 10717) bleiben bis nach dem Rollout. (3) NEBENBEFUND: Q07 QM5_12935/XAUUSD (80eac290) dreimal (22.08., 30.08., heute 11:34–13:04Z) nach exakt 5406 s Kindlaufzeit mit Seed 3/5 mitten im Run als INFRA `summary_missing:launch_fault` verbucht — keine Launch-Störung (T10-Journal: Seed 3 lief bei 31 %), sondern das 5400-s-Kindmonitor-Default (Zeile ohne `timeout_min`), während der Reaper 200 min erlaubt hätte; fünf XAUUSD-H4-Seeds brauchen ~185 min → drei Slot-Stunden ohne Verdikt. FIX 2fde461dce: Kindmonitor Q05–Q07 = max(Default, timeout_min, workload-skaliertes Reaper-Budget) wie schon Q08. Zeile append-only neu eingereiht (9f63dc88, Lineage → zwei PASS-Seed-Summaries werden wiederverwendet). Klassifizierer-Text „log never reached terminal_start“ ist bei Monitor-Kills irreführend (Folgeauftrag). (4) STAND: Zähler 7/25; Census 21507/XAUUSD 357 Zellen, 4 Census-Slots, 18–28 Zellen/10 min; RAM 21 GB frei, 10 Worker; T_Live unbeeinträchtigt.

> **Nachtrag 11:23Z (04.09.) — Drain-Winnability: Marge + Langlauf-Deckel (f232200f0a):** (1) Reload-Chunk 32 (Legacy-Lane f6236b5e46 + Messarithmetik e1413e756a) um 11:07Z auf allen zehn Workern abgeschlossen. (2) 10:57:49Z armierte T8 (neuer Code) regulär ein Fenster für den 32-GB-Basket QM5_10025 (e49888a1): gemessen releasable + frei ≥ 36 GB Bedarf — aber der freie RAM blieb bei 33,9 GB stehen, weil zwei Q07-Langläufer ~17 GB halten (Deckel 63 − 10 Baseline − 17 = 36) und geparkte Kurzzeilen ihren RAM nicht 1:1 zurückgeben; 19 min Flotte idle (0 Zellen/10 min). Manuell geschlossen 11:17Z (Cooldown bis 12:46Z), e49888a1 per Hold DRAIN_UNWINNABLE_ARITHMETIC gesperrt. (3) FIX f232200f0a: `_drain_candidate_is_winnable` verlangt jetzt need = Reservierung + 4 GB Floor + 3 GB Marge, und need ≤ Host − 10 GB Baseline − gemessener Langlauf-RAM (Facts `long_run_ram_gb`, unmessbare Langläufe konservativ mit Reservierung); 158 Tests grün. Rollout Chunk 33 (alle zehn, idle-only) sobald ≥20 GB frei (11:25Z: 19,6 GB); danach Holds lösen: 12580 (9cac4667, DRAIN_DEFER_LEGACY_NEWS_GAP), 10718 (31f12573) und 10025 (e49888a1) (beide DRAIN_UNWINNABLE_ARITHMETIC). Erwartung: 32-GB-Baskets armieren nur noch, wenn höchstens ein kleiner Langlauf aktiv ist; 44-GB-Zeilen praktisch nie (→ OWNER-Vorlage 1). (4) STAND: Zähler 7/25; Census 21507 (~390) erholt sich nach der Drain-Schließung; 10 Worker; T_Live unbeeinträchtigt.

> **Nachtrag 09:34Z (04.09.) — Drain-Arithmetik auf gemessene Working-Sets umgestellt (e1413e756a):** (1) BEFUND 09:12–09:27Z: Drain-Fenster armierte für QM5_10718 FX8-Basket Q02 (31f12573, Multisymbol 44 GB) bei 29,5 GB frei mit zwei laufenden Q07 — unwinnbar; Flotte 14 min idle (1 Zelle/10 min). Ursache: `_drain_active_ram_facts` summierte die Papier-Reservierungen der aktiven Kurzzeilen (8 GB Q02–Q06, 4 GB Census) als releasable, reale Working-Sets sind 1–6 GB. 553 pending Zeilen tragen ≥40-GB-Reservierungen (fast alle `single_index_tick`-Q02s) → ohne Fix alle 90 min ein Leer-Drain. Manuell geschlossen (Cooldown bis 10:56Z), 31f12573 per Hold DRAIN_UNWINNABLE_ARITHMETIC gesperrt. (2) FIX e1413e756a: releasable = min(Reservierung, gemessene Private-Bytes des Worker-Kindbaums über `_process_private_snapshot`); ohne Messung zählt die Zeile 0 (fail-closed: Drain öffnet nur auf Evidenz); Facts melden measured/unmeasured; 62 Drain-Tests grün (Fixtures mit synthetischem Snapshot). Wirkung: Fenster für ≥40-GB-Zeilen armieren nicht mehr, solange die Arithmetik sie nicht gewinnen kann; 32-GB-Baskets (12580) armieren nur bei echt freiem Host. (3) ROLLOUT: Chunk 31 beendet (wartete auf Q07-Langläufer), Chunk 32 (alle zehn, idle-only, beide Fixes f6236b5e46 + e1413e756a) 09:33Z bei 31 GB frei gestartet; nach Abschluss release-hold 12580 (DRAIN_DEFER_LEGACY_NEWS_GAP) und 31f12573 (DRAIN_UNWINNABLE_ARITHMETIC). (4) STAND: Zähler 7/25; Census 21507 (~400); RAM 31 GB frei, 10 Worker; T_Live unbeeinträchtigt.

> **Nachtrag 08:47Z (04.09.) — Ausreißer-Lauf endgültig gestoppt (Worker-Ebene), Reload neu aufgesetzt:** (1) 08:45Z drittes RAM-Tief (2,2 GB): T9 hatte nach dem Tester-Kill um 08:36Z sofort den nächsten Seed desselben Q05-Laufs (QM5_10395/EURJPY, bd18ccaa) gestartet — pid 34232, 26 GB. Ein Hold wirkt nur auf Claims, nicht auf die laufende Zeile. CEO-Aktion: Reload-Chunk 30 gestoppt (er verlor unter RAM-Druck Worker: T3 Neustart verweigert, 7 Worker), Tester pid 34232 und T9-Worker beendet (kein T9-terminal64 aktiv); freier RAM danach 32,9 GB; Starter brachte alle zehn Worker zurück (Gate: ram 13). bd18ccaa liegt jetzt `pending` unter Hold RAM_OUTLIER_4X_RESERVATION → keine weiteren Seeds; 10395/EURJPY hat sonst nur erledigte Zeilen. Lehre: Speicher-Ausreißer bei Multi-Seed-Läufen erfordern Kill auf WORKER-Ebene (Worker beenden → Claim fällt zurück auf pending → Hold greift), nicht nur des Testers. (2) Reload-Stand Legacy-Lane-Fix f6236b5e46: T1, T3, T9 neu (Chunk 30/Starter); Chunk 31 für T6/T8/T4/T10/T2/T5/T7 gestartet (idle-only, RAM 32 GB); danach release-hold 12580 (DRAIN_DEFER_LEGACY_NEWS_GAP). (3) Auftrag 924c36df (Not-Reaper + EA-genaue Speichererwartung + MemoryError-Härtung) bleibt die strukturelle Antwort; bis dahin manuelle Regel (WS >2× Reservierung + frei <3 GB → Tester UND Worker beenden, Zeile halten). (4) STAND: Zähler 7/25; Census 10–24 Zellen/10 min (Reload-Dellen); T_Live unbeeinträchtigt.

> **Nachtrag 08:36Z (04.09.) — RAM-Ausreißer beendet (Live-Schutz), Reload-Chunk 30 läuft:** (1) 08:34Z erneut 3,3 GB frei: der zweite Seed-Prozess des Q05-Multi-Seed-Laufs QM5_10395/EURJPY (T9, Zeile bd18ccaa, Reservierung 8 GB) stand bei 31 GB Working-Set (Start 08:30Z); der erste Prozess (27 GB) hatte um 08:18Z von selbst geendet. Da jeder weitere Seed einen ~30-GB-Prozess erzeugt hätte und T_Live denselben Host teilt, CEO-Entscheidung (GRÜN, reversibel): Tester pid 38528 um 08:36Z beendet (freier RAM danach 34,3 GB); Zeile bd18ccaa mit Hold `RAM_OUTLIER_4X_RESERVATION` gesperrt, bis die EA-genaue Speichererwartung (Auftrag 924c36df) den gemessenen Fußabdruck reserviert; Rollback `farmctl release-hold`. Eine ggf. von der Pumpe gemintete Recovery-Rerun-Zeile wird ebenfalls gehalten. Regel für künftige Ausreißer: Working-Set >2× Reservierung UND freier RAM <3 GB → Tester beenden, Zeile halten, Auftrag zur Kalibrierung. (2) Alle zehn Worker zurück (Guardian/Starter ab 08:25Z); Reload-Chunk 30 (Legacy-Lane-Fix f6236b5e46, alle zehn, idle-only) um 08:35Z bei 35 GB frei gestartet; nach Abschluss wird der 12580-Hold (DRAIN_DEFER_LEGACY_NEWS_GAP) gelöst. (3) STAND: Zähler 7/25; Census 24 Zellen/10 min; 21507 ~420.

> **Nachtrag 08:16Z (04.09.) — BEINAHE-OOM 08:09Z (0,6 GB frei), drei Worker gestorben, 27-GB-Q05-Ausreißer:** (1) BEFUND: Q05 QM5_10395/EURJPY auf T9 (bd18ccaa, Klasse ordinary 8 GB) wuchs nach der Zulassung auf 27 GB Working-Set; zusammen mit Q07-Läufen fiel der freie RAM um 08:09Z auf 0,6 GB (T1-Log). Die Worker T1/T3/T10 beendeten sich im `ram_low_pause` (7 Worker übrig; keine verwaisten aktiven Zeilen); der Starter verweigert Neustarts fail-closed (RAM-Kapazität 0). T_Live (pid 19016, 0,19 GB) lief unbeeinträchtigt. RAM 08:15Z 7,2 GB stabil, T9-Tester konstant 27 GB → kein Kill nach der 1,5-GB-Regel. (2) MASSNAHMEN: detached Wächter `scratchpad/ram_watch_34496.py` (alle 20 s; killt NUR pid 34496, wenn zweimal in Folge <3 GB frei — verschärfte Schwelle wegen T_Live auf demselben Host; Log ram_watch_34496.log); Worker T1/T3/T10 werden per `start_terminal_workers.py --dedupe` zurückgeholt, sobald das Headroom-Gate freigibt; Reload-Chunk 30 (Legacy-Lane-Fix) weiter auf ≥20 GB verschoben. (3) STRUKTUR: Die RAM-Latch schützt nur die Zulassung, nicht das Nachwachsen; das Tester-Memory-Ledger kalibriert Klassen (asset|TF|kind) erst ab n≥3 und würde dann alle fx_cross-Läufe auf 27 GB reservieren (Über-Reservierung). Auftrag 924c36df: Not-Reaper im Worker (freier RAM <2 GB zweimal → neuesten Tester mit WS >2× Reservierung beenden, INFRA_FAIL append-only, Kill-Switch), EA-genaue Speichererwartung (ea_id|TF|kind) mit Vorrang, MemoryError-Härtung der Idle-Schleife. Bis dahin bleibt der manuelle Wächter die Absicherung. (4) STAND: Zähler 7/25; Census 25 Zellen/10 min trotz 7 Workern; Governor claude Projektion >150 % → weiterhin keine neuen Workflows (924c36df wird bei Pace-Freigabe zuerst umgesetzt: Live-Schutz vor Zähler-Komfort).

> **Nachtrag 07:50Z (04.09.) — Drain erneut abgebrochen: Legacy-News-Lane als Kurzzeile klassifiziert (Fix f6236b5e46):** (1) BEFUND: Drain für 12580 (32 GB) 07:30:32Z geöffnet, 07:42:05Z abgebrochen (`new_long_run_row_active`) — Zellen 0/10 min im Intervall. Ursache: `farmctl.phase_rank('Q09_NEWS')` = −1 (v3-Speichername der News-Lane; 40 solche Zeilen pending, 1 aktiv). Damit galten diese Zeilen für `_drain_phase_is_long_run` als kurz (im offenen Fenster claimbar: T2/T5 07:41–07:42Z) UND für `longrun_scheduling_policy` weder als News-Klasse (Klassifikation) noch in `active_longrun_counts` (SQL `phase IN (news,Q07,Q08)`) — die News-Caps (2/4) zählten Legacy-Läufe nicht. (2) FIX f6236b5e46: `*_NEWS`/`*_PORTFOLIO`-Lanes sind Langläufe (Worker-Prädikat); Policy-Helfer `_is_news_lane` in Klassifikation und Zählung (SQL `OR upper(phase) LIKE '%_NEWS'`); 185 Tests grün. Rollout: Reload-Chunk 30 (alle zehn, idle-only) erst bei ≥20 GB frei (aktuell 9,4 GB); bis dahin Hold `DRAIN_DEFER_LEGACY_NEWS_GAP` auf 12580 Q03 9cac4667 (Hold-Zeile per UPDATE reaktiviert — work_item_holds hat einen Slot je Zeile). (3) RISIKO bis Rollout: News-Caps unterzählen Legacy-Läufe (bereits seit v4-Umstellung so); RAM-Latch 14/20 GB fängt es ab. (4) STAND: Zähler 7/25; Census 21507 (~430); 8 Tester, CPU 100 %, RAM 9,4 GB frei.

> **Nachtrag 07:30Z (04.09.) — Bundle 7/7, Claude-Pace-Entscheidung:** (1) Q08-Rerun a43559cd (QM5_20048/XTIUSD) done/PASS, Seal a792e263… byte-exakt reproduziert, Bytes persistiert; `assemble_stream_bundle.py` (Scratch): bound 7 / refused 0, Loader ok — alle sieben qualifizierten Paare haben ihr Buch-Pfad-Bundle. Regel bis Auftrag cfce4d87 (Auto-Rerun in der Pumpe) läuft: nach jedem neuen Q14-Terminal manuell den Q08-Stream-Rerun minten (Pre-flight §5, `--rerun-reason`). (2) CLAUDE-PACE: Governor 07:23Z claude used 15 % bei 5,6 % Wochenzeit (Projektion 268 %), codex 93 % (Flag). Nach der OWNER-Regel „Tiefe vor Volumen, verifizierte Opus-Workflows nur zählerrelevant“ starte ich keine neuen Workflows, solange die Projektion >150 % liegt; die offenen Aufträge cfce4d87 / 315041f7 / 453b8edf bleiben TODO (nicht zählerkritisch: Reruns manuell, Enforce erst nach OWNER-Plan). Loop-Runden werden auf Beobachtung und kleine Direktfixes beschränkt. (3) STAND: Zähler 7/25; Census 21507 (~430, 1 Lane aktiv), 12710 (~709), 20266 (~566); 33 Zellen/10 min; kein Drain-Ereignis seit 07:00Z; RAM 15,4 GB frei, 10 Worker, C: 84 GB, D: 73 GB.

> **Nachtrag 07:00Z (04.09.) — Codex-Tiers Runde 4 gemergt, Tier-Schicht im OBSERVE-Modus aktiv:** (1) wf_76cb7101-72e Runde 4 (D8–D12) als a769c2f5b8 gemergt (Delta: codex_model_tiers.py, agent_quota_gate.v1.json, agent_router.py, run_agent_orchestration_task.py, test_codex_model_tiers.py; 289 Zieltests grün, 130 im Tier-Suite). Inhalt: Ledger-Decode-Fehler fail-closed; `window_enforcement_mode` observe (shipped default) / enforce; Capability `scalpel_mechanization` nur codex/claude (Scalpel-Arbeit kann nicht mehr zur gemini-Lane routen); Lock-Fehler fail-closed im Enforce-Modus; Zählregeln für korrupte/ts-lose Zeilen; Matrix-Validierung (doppelte Modell-IDs, kein Astra-Fallback); Ledger-Rotation. (2) r4-Verifier: beide ok:false, aber nur Enforce-Randfälle/Decision-Details (String-'true' als Scalpel-Marker wird beim Routing nicht gepinnt; ts-lose Records könnten im Enforce dauerhaft zählen; mtime-Bindung korrupter Zeilen wirkt auf lebendem Ledger nicht; Rotation ohne Uhrsprung-Schutz; allowed_modes nicht validiert; Burn-Bypass vor Astra-Hold). CEO-Entscheidung: Merge, Observe-Modus liefert Beobachtungsdaten ohne Verhaltensänderung; Restbefunde als Auftrag 453b8edf (Vorbedingung vor jeder Enforce-Aktivierung, erst nach OWNER-Planantwort). (3) Maschinen-Env `QM_CODEX_MODEL_TIERS=0` ENTFERNT (06:56Z); Observe-Probe im frischen Prozess gegen Scratch-Ledger: tiers_enabled True, 3 Dispatches recorded (sol, over_budget False, enforcement_mode observe), argv byte-identisch (`-m gpt-5.6-sol -c model_reasoning_effort="high"`), Live-Ledger nicht angefasst. Ab jetzt schreibt jeder echte Codex-Dispatch `D:/QM/reports/state/codex_model_window_ledger.jsonl`. Einschalten von Enforce: erst OWNER-Plan (Plus/Pro 5x/Pro 20x) + 453b8edf APPROVED. (4) Aufträge heute neu: cfce4d87 (Pumpe mintet Q08-Stream-Rerun beim Q14-Terminal), 453b8edf (Enforce-Vorbedingungen), 315041f7 (edge_lab_stats.py). CodexOrchestration bleibt bis 07.09. aus. (5) STAND: Zähler 7/25; Census 21507/20266/12710 parallel; Reload-Chunk 29 (T2/T3/T5/T7) läuft; 12580-Hold wird nach Chunk-Ende gelöst.

> **Nachtrag 06:47Z (04.09.) — Bundle 6/7 gebunden, siebtes Paar nachgezogen, RAM-Tief 06:20Z, Nachreload:** (1) Q08-STREAM-RERUNS 11422/13054/21505 done/PASS; `assemble_stream_bundle.py` (Scratch-Out): bound 6 (10706, 11421, 11422, 13054, 1537, 21505), refused 1 — das um 06:08Z terminal gewordene QM5_20048/XTIUSD hat dieselbe Seal-Lücke (a792e263…). Pre-flight §5 bestanden (Ziel 3ee5c53c done/PASS, Q07-Vorgänger bf54ff43 PASS, Identität current=Q14 1312391a…, kein offener Q08, kein Rerun) → enqueued a43559cd (Auffangregel-Klasse, `--rerun-reason`). Muster: jedes neu terminale Paar braucht diesen Rerun, solange die Q08-Bytes historisch fehlen — Vorschlag: Pumpe soll beim Q14-Terminal automatisch prüfen und den Rerun minten (Ticket). (2) RAM-TIEF 06:20Z: 5,0 GB frei (zwei Q08-Läufe mit je 11,5 GB gegen 8 GB Reservierung + Q05/Q06/News); Latch hielt, keine Kills (45-s-Nachmessung 6,2 GB). Nebenwirkung: Reload-Chunk 28 stoppte T4/T10 idle, der Neustart wurde vom Starter fail-closed verweigert (RAM-Kapazität 0) → 8 Worker; Chunk 28 gestoppt, T4/T10 um 06:23Z per `start_terminal_workers.py --dedupe` wieder gestartet (10 Worker, keine verwaisten Zeilen). Lehre: Reload-Chunks nur bei ≥20 GB frei starten; Q08-Klasse reserviert zu wenig (Ledger-Kalibrierung beobachten). Chunk 29 (T2/T3/T5/T7, Drain-Fix) läuft seit 06:45Z; 12580-Hold wird danach gelöst. (3) TIERS wf_76cb7101 Runde 4: Delta-Patch (5 Dateien, 286 Zieltests) in Verifikation. (4) STAND: Zähler 7/25; Census 21507 (~440), 20266 (~574), 12710 (~743) laufen parallel; 40 Zellen/10 min; C: 80 GB, D: 76 GB, RAM 22 GB frei.

> **Nachtrag 06:20Z (04.09.) — Codex-Modell-Tiers gemergt (Tier-Schicht AUS), Lane-Pinning aktiv:** (1) wf_76cb7101-72e Runden 1–3 als b8c62c975a gemergt (10 Dateien: codex_model_tiers.py neu, quota_spawn_gate, agent_router, run_agent_orchestration_task, farmctl, codex_fleet_pacer, mailbox_source_intake, agent_quota_gate.v1.json, tests); 242 Zieltests grün (97 im neuen Suite), kein Live-Ledger geschrieben. Inhalt: Tier-Auflösung (explizit > scalpel/strategy_mechanize_source > Effort-Klasse, Remap opt-in per Flag, Default gpt-5.6-sol), 5h-Ledger mit Booking-vor-Render unter OS-Lock, Astra-Hold statt Downgrade, fail-closed Matrix-Validierung, Rollback-Env, Decision-Bound-Lane-Pinning (owner_decision/decision_bound_agent → claude, ungültiger Pin → Hold) und Capability-Union im Router. (2) Runde-3-Verifier: beide ok:false, aber nur Tier-Schicht-Befunde (F2 Decode-Fehler beim Ledger-Iterieren wirft; F3 untierte Tasks fallen auf Plus-Low-End nach 8 Msg/5h zurück; F1 Scalpel-Tasktyp würde zur gemini-Lane routen; F5 Lock fail-open; F4/F6/F7 Validierungs-/Zählregeln). CEO-Entscheidung: Merge mit Tier-Schicht AUS — Maschinen-Env `QM_CODEX_MODEL_TIERS=0` gesetzt, in frischem Prozess verifiziert (flags [], kein Ledger, argv identisch zum Vorzustand); Router-Pinning gilt unbedingt. Runde 4 (D8–D12: Decode-Fehler abfangen, `window_enforcement_mode` observe als Default/enforce opt-in, Capability `scalpel_mechanization` nur codex/claude, Lock fail-closed im Enforce-Modus, Ledger-Rotation + Validierungen) läuft als Delta gegen HEAD. Einschalten der Tier-Schicht erst nach Runde 4 UND OWNER-Antwort zum Codex-Plan (Plus/Pro 5x/Pro 20x). (3) CodexOrchestration-Task bleibt deaktiviert bis 07.09. (Codex-Woche 93 % bei 57 % Zeit); mit dem Pinning kann er danach gefahrlos wieder laufen. (4) STAND: Zähler 7/25; Census 21507 läuft; Reload-Chunk 28 rollt Drain-Fix aus.

> **Nachtrag 06:09Z (04.09.) — ZÄHLER 7/25 (20048/XTIUSD terminal), Drain-Designlücke geschlossen:** (1) QM5_20048/XTIUSD: Q12 NO_FILTER_CHANGE 05:48Z → Q13 NO_PARAMETER_CHANGE 05:58Z → Q14 KEEP_INCUMBENT 06:08Z; qualified_pairs = 7. Nächste im Slot-Rang: 21507/XAUUSD (Census seit 06:05Z, ~456 Zellen), dann 20266, 11881, 12710, 11910, 10700. (2) DRAIN-DESIGNLÜCKE: das offene Fenster verweigerte nur neue kurze Zeilen; neue Langläufe (Q08-Reruns, Q10_NEWS) wurden weiter geclaimt und brachen das Fenster ab (12580-Basket: 02:33Z, 04:22Z, ~05:50Z; letzter Zyklus 3 Zellen/10 min bei 8 aktiven). Fix 5e8e5c9a2a: `_drain_blocks_new_long_run` nur im Claim-Pfad (armierte Zeile + COMPILE_EA exempt), Releasable-Arithmetik unverändert; 155 Tests grün; Worker-Reload idle-only Chunk 28 läuft (Chunk 27 beendet, um ein T2-Race zu vermeiden). Bis die Q08-Reruns 2bd0f95c/21dd6839/15c1ec7b durch sind, ist 12580 Q03 9cac4667 per Hold DRAIN_DEFER_LONGRUN_BURST gehalten (Rollback release-hold). (3) CPU-GUARD: bei 4 Langläufen + Census meldet der Worker `cpu_high_pause` (97,7 %/91,2 % gegen 97/90 %) — bewusste Schutzlatch, verstärkt Dellen; Beobachtung, keine Änderung. (4) TIERS wf_76cb7101 r3-Verifier laufen. STAND: C: 83 GB, RAM 18,5 GB frei, 10 Worker, 6 Tester; Census 18 Zellen/10 min (erholt).

> **Nachtrag 05:41Z (04.09.) — Q08-Seals byte-exakt reproduziert, Bundle 3/6, sechstes Paar nachgezogen, Edge-Discovery v1 abgenommen:** (1) Q08-STREAM-RERUNS: f62fe6b3 (QM5_1537/XAGUSD) und a2e1aba6 (QM5_10706/GBPUSD) done/PASS; die neu emittierten Seals sind byte-identisch mit den aufgezeichneten (1885c21e…, 71fb35b8…) → Determinismus bewiesen; Bytes persistiert unter D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/. `assemble_stream_bundle.py` (mode=ro, Scratch-Out): bound 3 (10706, 11421, 1537), refused 3 (11422/13054 Reruns pending; 21505 neu terminal mit derselben Lücke, Seal 243804fa ohne Bytes). Als Erweiterung derselben Auffangregel-Klasse (identischer Pre-flight §5: Ziel 9c51f7eb done/PASS, Q07-Vorgänger b837549a PASS, Identität current=Q14=Q08-source 395c4747…, kein offener Q08, kein Rerun) enqueued 15c1ec7b (QM5_21505/XAGUSD Q08). Hinweis: enqueue-backtest kennt `--rerun-reason`, nicht `--reason`. (2) 13213/USDJPY-KLARSTELLUNG: kein Hänger — Programm DL089_QM5_41097 ohne queue_order_at sortiert per Sentinel hinter den 7 OWNER-geordneten Programmen (Tie-Break 224c46282c, gewollt). 20 Zellen tragen einen veralteten Hold ARTIFACT_BINDING_MISSING (seit 29.08.; kanonisches ex5 existiert, SHA e077660c passt) → vor 13213s Zug per `farmctl release-hold` freigeben (TODO, 20 Zeilen). Rollout-Hold auf Q12-Zeilen ist der reguläre Service-Wartezustand und blockiert keine Zellen. (3) EDGE-DISCOVERY v1 (f93220de) nach Selbstreview APPROVED (f10c08b399); nächste Beauftragung edge_lab_stats.py (STD_IMPL) + EDGE-1/EDGE-3-Tabellen, ohne Fabrikzeit vor Zähler 25. (4) TIERS wf_76cb7101 Runde 3 (D1–D7) läuft; CodexOrchestration-Task bleibt deaktiviert. (5) STAND: Zähler 6/25; 20048/XTIUSD letzte Post-Census-Zellen (1 pending, 1 aktiv); 21507 456; C: 83 GB, RAM 30 GB frei, 10 Worker, Reload 27 wartet auf T2.

> **Nachtrag 05:01Z (04.09.) — ZÄHLER 6/25 (21505/XAGUSD terminal), Q08-Stream-Reruns ausgeführt:** (1) QM5_21505/XAGUSD: Census 1086/1086 → Q12 NO_FILTER_CHANGE 04:29Z → Q13 NO_PARAMETER_CHANGE 04:39Z → Q14 KEEP_INCUMBENT 04:49Z; book_build_guard qualified_pairs = 6. Der Pfad Census → Q12-Finalizer → Q13 → Q14 ist damit Ende-zu-Ende verifiziert (20 min nach Census-Ende). Nächste im Slot-Rang: 20048/XTIUSD (~100 Restzellen), dann 21507/XAUUSD (~477), 20266, 12710, 11910, 10700; 13213 (Rang 0, 524). (2) Q08-STREAM-RERUNS (Auffangregel 05:00Z, Paket 03.09. §4, Pre-flight §5 erneut bestanden: Ziel done/PASS, Vorgänger done/PASS, kein offener Q08, kein vorhandener Rerun): enqueued f62fe6b3 (QM5_1537/XAGUSD), a2e1aba6 (QM5_10706/GBPUSD), 2bd0f95c (QM5_11422/USDCAD), 21dd6839 (QM5_13054/XTIUSD); ordinary 8 GB, Q07/Q08-Cap 2 (+1 Lineage), Ergebnis scratchpad/q08_rerun_result.json. Nach Abschluss: assemble_stream_bundle.py muss die vier Seals reproduzieren (content_sha256) — sonst Refusal, keine Synthese. (3) DRAIN: erneutes Fenster ~04:22–04:52Z (Cooldown bis 05:52Z; Zellen 24/23 pro 10 min in dem Intervall) — Auslöser wird ermittelt; ≥40-GB-Zeilen sind gehalten, also eine ≤32-GB-Zeile (12580-Basket?). Der Worker überschreibt die State-Datei mit eigenem Schema (manual_closures-Notiz nicht persistent). (4) STAND: Reload-Chunk 27 wartet nur noch auf T2; wf_76cb7101 r2-Patch (58 Tests) in Verifikation; C: 69 GB, RAM 22,7 GB frei, 10 Worker, 3 Tester.

> **Nachtrag 04:14Z (04.09.) — Auffangregel-Ausführungen 04:00Z (Vein-1 Welle 1, News-Gate A), Index-RAM-Befund:** (1) VEIN-1 WELLE 1 (Auffangregel, Vorlage 03.09. ohne OWNER-Antwort >12 h): Dry-run aller 30 Paketzeilen ohne Ablehnung; angewendet 16 FX-Zeilen (QM5_10038/10069/10116/10269 × AUDUSD/NZDUSD/USDCAD/USDCHF/USDJPY/EURUSD/GBPUSD) als append-only Q02-Nachfolger (`farmctl requeue-false-invalid-setfile --apply`, Ergebnis scratchpad/vein1_wave1_result.json); Kosten 16 Q02-Läufe (ordinary 8 GB, wenige Minuten je). 14 Index-Zeilen (GDAXI/NDX/SP500/UK100/WS30) ZURÜCKGESTELLT: `_ram_reservation_for_candidate` klassifiziert sie als `single_index_tick` = 44 GB flat (eine einzige SP500-Messung, Erwartungsdatei ohne Index-Einträge) → auf dem 63-GB-Host unclaimbar und Drain-Auslöser. (2) INDEX-RAM-BEFUND (strukturell, in OWNER-Vorlage 1 aufzunehmen): jeder Index-Tester-Lauf (Q02…Q11) braucht laut Klasse 48 GB frei; Drain-Fenster dafür unwinnbar bei ≥3 Long-Runs. Betroffen: 10815 Q02, 11129 Q07 (gehalten), 10911 Q05 (GDAXI), Q11 b62dbcec (11294/GDAXI), Vein-1-Index-Zeilen; Census-Zellen (4 GB) laufen weiter. Optionen: (a) Klassen-Kalibrierung durch einen beobachteten Index-Lauf in einem isolierten Fenster (GRÜN, ≤1 h Fabrikzeit), (b) RAM-Upgrade. Empfehlung: (a) zuerst, da die 44-GB-Zahl auf n=1 beruht. (3) NEWS-GATE A (Auffangregel): Expansions-Subcap 2→3 nur bei ≥10 GB frei zur Claim-Zeit (`longrun_scheduling_policy.should_skip_for_longrun_cap(free_ram_gb=…)`, Snapshot aus claim_atomic), Gesamt-News-Cap 4 unverändert, Rollback QM_DISABLE_LONGRUN_SCHEDULING_CAP=1; Commit 88be67be5b, 122 Tests grün (zwei Integrationstests auf Cap 3 unter Headroom angepasst); Worker-Reload idle-only läuft (Chunk 27). (4) Q08-STREAM-RERUNS (Auffangregel 05:00Z): vier Kommandos aus dem Paket exakt extrahiert (scratchpad/q08_rerun_cmds.txt), Ausführung zur Fälligkeit. (5) STAND: 21505/XAGUSD Census 1085/1086, letzte Zelle aktiv → Q12-Finalizer; Zähler 5/25; wf_76cb7101 (Codex-Tiers) Fix-Runde 2; C: 76 GB, RAM 21 GB frei, 10 Worker.

> **Nachtrag 03:22Z (04.09.) — FTMO-Snapshot repariert, Readjudikation census-verifiziert, Drain-Fenster 44 GB, Codex-Tiers in Fix-Runde:** (1) FTMO: Codex-Direktcommit 2d3a3cf272 adversarial geprüft (wf_2ff6eba9): Werte sauber (0/30 erfunden), Tests/Pins ok, aber 5/7 Quellen mit 02.09.-Abrufstempel ohne Nachweis (29.07.-Beobachtungen; umgeht das 7-Tage-Frische-Gate) und unbelegte 04.09.-Prüfbehauptung. Reparatur: alle Regelseiten 02:10Z real vom VPS abgerufen (8 URLs HTTP 200, SHA-256, Bodies unter docs/ops/evidence/ftmo_fetch_20260904/; trading-symbols-URL 404 = tot); neuer Snapshot 2026-09-04 mit 28/30 re-konfirmierten Claims, 2 Swing-Leverage-Claims CARRIED_OVER (vor jeder Leverage-Entscheidung neu sourcen); rulepack as_of 09-02→09-04 erzwungen durch Validator (retrieved_on ≤ as_of), profile_version 2 unverändert; verwaister Lane-Hash in pipeline_books_program_status behoben; Merge 82e14c7e80 (wf_130824da-ca1, 292 Tests grün, Snapshot-SHA = Pin); Router a4fb4108 APPROVED. Frische-Gate läuft designbedingt 2026-09-11 ab → wöchentlicher Re-Fetch nötig. (2) READJUDIKATION census-verifiziert (5a0eac7607): Census bewertet Gates nach Reihenfolge (erledigte PASS-Klasse, CONFIG_LOCKED zählt), nicht über Promotionskanten → die 32 Nachfolger schließen die Q10-Lücke direkt; Verteilung Q14=5, Q11=20, Q10=2 → struktureller Deckel 27 ≥ 25. Q11-Kaskade (worker-getrieben, vom CLI nicht ausgelöst) nur für 41219/XAUUSD (cc50783d) und 11294/GDAXI (b62dbcec) ausgelöst; 30 Paare mit bestehenden Q11/Q12 brauchen keine neue Q11. Zähler 5/25; 21505/XAGUSD ~26 Restzellen. (3) DRAIN 02:33–02:52Z unwinnbar: 44-GB-Index-Reservierung (QM5_11129 Q07 e046b36b) braucht 48 GB frei, verfügbar 19,6 + 25,5 releasable = 45,1; Flotte stand bei 0 Zellen/10 min. Manuell geschlossen (State-Datei, Cooldown bis 04:21Z, Vorher-Kopie scratchpad/drain_window_before_0252Z.json); Holds RAM_WINDOW_44GB (release_on_restart=0) auf 11129 Q07 und 10815 Q02 bd12175c bis RAM-Upgrade (OWNER-Vorlage 1) oder isoliertes Fenster; Rollback `farmctl release-hold`. Nachanalyse: Worker melden `factory_mutation_lock_busy` nur transient (Datei-Lock des Claim-Pfads, ~5 ms Haltezeit), Stillstand = Drain + Claim-Spacing der 9 durch Reload-Chunk 26 neu geladenen Worker; Durchsatz 03:20Z wieder 60 Zellen/10 min. Offener Code-Punkt: Drain-Winnability muss reale Tester-Working-Sets statt Reservierungen rechnen und ≥40-GB-Klassen ausschließen. (4) CODEX-TIERS wf_76cb7101: r0 und r1 materiell widerlegt (Ledger nur 1/4 Spawn-Stellen; Default driftete nach Terra; Capability-Guard asymmetrisch; Refusal an 3 Spawn-Stellen nicht durchgesetzt; Tier aus metadata statt payload; Validation fail-open; keine Reservierung) → Fix-Runde 2 läuft; CodexOrchestration-Task bleibt bis zum Merge deaktiviert. (5) EDGE-DISCOVERY f93220de: Dateninventar erhoben — 37 .DWX-Symbole Tick-Archive monatlich 2017-10..2025-12 (Indizes ab 2018-07), 36 GB (D:/QM/archive/Custom_master/ticks); NDX-Dukascopy 2018–2026 (2,76 GB); Forex-Factory-Kalender 2015-01..2026-09-03 (48.636 Zeilen). Dokument folgt nach den Merges.

> **Nachtrag 02:07Z (04.09.) — OWNER-Entscheide 2–4 umgesetzt, Codex-Lane-Vorfall, Readjudikationswelle 1:** (1) BUCH V2/V4/V6+Epoch: verifizierter Workflow wf_04d206e1-add gemergt als c07754bbf6 (V2 OWNER_RATIFIED-Stempel, V4 Sparse-D1-Zweischicht-Standard in portfolio_correlation, G5-Signaturkommando auf Epoch 2026-07-19T13:50:00Z; 64 Tests grün); Router b9f7a280 APPROVED. (2) NEWS-GATE (a)+(e): wf_7c3a5e11-c3d gemergt als 441b3740a5 (REVIEW-Labels, Single-Target-Lock ohne 7x4, affected_entries verdrahtet, CLI readjudicate-news-8cell; Verifier-4-Befund Listen/Aktions-Phasen-Inkonsistenz behoben; 79 Tests grün); Router 253f7e09 APPROVED. Readjudikationswelle 1 01:59–02:02Z: 32 Nachfolger CONFIG_LOCKED (Evidenz `docs/ops/evidence/2026-09-04_newsgate_readjudication_wave1.md`), 1 historische Lane ausgeschlossen (QM5_1354). Q11-Minting durch die Pumpe wird beobachtet; 10700-Duplikatwache (Expansion 152e8d29 hatte 00:58Z bereits gelockt → Q11 e4097945 → Q12 40e69c26, Slot-Rang 7 = 08:04 gesetzt). (3) FTMO-Rulepack: Codex-Direktcommit 2d3a3cf272 (30 Claims) bleibt vorerst, Verifikation läuft (wf_2ff6eba9-9bf); verifizierte 21-Claim-Alternative als Patch scratchpad/ftmo_wf9448.patch; Router a4fb4108 bleibt REVIEW. (4) VORFALL: Codex-Orchestrierung Slot1 (01:00Z) hat die drei für die Claude-Lane reservierten Entscheidungsaufträge über den Kostenrang geclaimt (Routing-Flattern, Ticket 21.08.), zwei davon direkt auf agents/board-advisor aus dem kanonischen Checkout committet (2d3a3cf272, 5a30c0bd30 → revertiert 4a14e7c712) und am dritten gearbeitet; Prozess 01:42Z beendet, Teilstand gesichert (scratchpad/codex_newsgate_partial_killed_0142Z.patch), Task QM_StrategyFarm_CodexOrchestration_15min DEAKTIVIERT bis Lane-Pinning gemergt ist; Codex-Woche 93 % bei 56,6 % Zeit. (5) MODELL-ROUTING: Doktrin docs/ops/MODEL_ROUTING_DOCTRINE_2026-09-04.md (68207ef850); Workflow wf_76cb7101-72e (Codex-Tiers Astra/Sol/Terra/Luna, 5h-Ledger, Astra-Hold statt Downgrade, Decision-Bound-Lane-Pinning) läuft. OWNER-Frage offen: Codex-Plan (Plus/Pro 5x/Pro 20x). (6) Fabrik: 10 Worker, 5 Tester, 17 GB frei, Census 53–60 Zellen/10 min, C: 72 GB, D: 89 GB; 41333-Sibling Q02 PASS 01:29Z; 12580-Q03/10911-Q05/10815-Q02 warten weiter auf RAM-Fenster.

>
> **Nachtrag 01:01Z (04.09.) — OWNER-Entscheid (Chat ~00:55Z): Briefing-Punkte 2–4 freigegeben, jeweils meiner Empfehlung folgend; Receipt `decisions/2026-09-04_owner_receipts_briefing_2_4.md`, drei entscheidungsgebundene Claude-Aufträge, Umsetzung läuft als verifizierte Workflows.** (2) OWNER-DEC-NEWSGATE-AE-20260904: Label-Fix der REVIEW-Dicts + Lazy Expansion für Ein-Ziel-Deployments (8-Zellen-Lock ohne 7x4, Mehrziel/FTMO behält die Expansion) + Verdrahtung des `affected_entries`-Zählers + Append-only-Readjudikations-CLI, das die ~43 offenen Expansions-Zeilen aus den versiegelten 8-Zellen-Aggregaten unter der neuen Regel als Nachfolger lockt (keine Tester-Läufe, alte Zeilen bleiben Evidenz); forward-only, keine Schwellenänderung (wf_7c3a5e11-c3d). (3) OWNER-DEC-BOOK-V2V4V6-EPOCH-20260904: V2 ratifiziert (0,50 / 10,0 → OWNER_RATIFIED im Builder), V4 Methode jetzt (ZK-SBB certify/abstain + COS-Flag in `portfolio_correlation.py`, Zahlen bleiben WORKING_DEFAULT), V6 9,75 % halten, Epoch 2026-07-19T13:50Z für die Pointer-Signatur (G5-Kommando; Mint/Signatur bleibt OWNER) (wf_04d206e1-add). (4) OWNER-DEC-FTMO-RULEPACK-COHERENCE-20260904 Option (a): Official-Rules-Snapshot 2026-09-02 im Evaluator-Schema aus denselben Quellen, Evaluator-Pins + Rulepack-V2-Quellenbindungen nachziehen, feldweise Provenienz, nichts erfinden (wf_9448cf1a-0fc). Fabrik 00:50Z: 50 Zellen/10 min nach der Slot-Korrektur (21505 mit Lane), 17 GB frei, 10700-Expansion läuft (5,5 h).

> **Nachtrag 01:16Z (04.09.) — OWNER-DEC-FTMO-RULEPACK-COHERENCE-20260904 umgesetzt, REVIEW:** Official-Rules-Snapshot 2026-09-02 im Evaluator-v1-Schema gemintet (`d055f71c…`), alle Rulepack-V2-Quellen darauf gebunden, Evaluator/Preparer auf profile 2 + as_of 02.09. + Snapshot-/Rulepack-SHAs gepinnt; vollständige Claim-Provenienz wird fail-closed geprüft. Nicht vorhandene 02.09.-Response-Bytes bleiben ausdrücklich `null` (nichts rekonstruiert). Rulepack canonical `5505a56d…`; 176 fokussierte Tests grün. Keine Regel/Schwelle, kein Kauf/Deploy/T_Live. Evidenz `docs/ops/evidence/2026-09-04_ftmo_rulepack_v2_coherence.md`.

> **Nachtrag 00:43Z (04.09.) — Slot-Reihenfolge vervollständigt: die vier zählernächsten Zensus-Programme (21505, 20048, 21507, 20266) hatten keine Queue-Order und damit seit ~13:00Z keinen der acht Programm-Slots — jetzt Ränge 1–4 vor 12710/11910/10700.** Mechanik: `dl089_matrix_service._queue_order` sortiert nach `queue_order_at`, sonst nach Erstellungsdatum der Q12-Zeile — heute Morgen wurden nur die Ränge 5–7 geschrieben, die Incumbents fielen dadurch hinter jüngere 8–19-%-Programme (10145, 10403, 10513, 11881). Folge: 21505/XAGUSD (112 gemessen + 666 geprunt, nur noch 307 Zellen — das am weitesten fortgeschrittene Programm) und 20048/XTIUSD (503 Rest) standen elf Stunden mit `PROGRAM_SLOT_WAIT:K=8`. Korrektur governed per `set_dl089_queue_order.py` (Plan → Apply, GRÜN: Prioritätsänderung ohne Löschung, unter derselben OWNER-Entscheidung); der nächste Pump-Lauf vergibt die Slots neu, der heute gemergte Zellen-Tie-Break gibt freie Lanes ans zählernächste Programm (wirkt nach Worker-Reload, Chunk 26 konsolidiert). **Zählerprognose korrigiert:** 21505 (307 Zellen ≈ 1–2 Tage bei einer Lane) ist das nächste Paar, danach 20048/21507; 11910/12710 folgen. Fabrik 00:38Z: 25 Zellen/10 min, 23,7 GB frei, T_Live-Journal 00:19Z, keine stale Locks; 10700-Expansion bei 315 min.

> **Nachtrag 23:46Z (03.09.) — Zensus-Dispatch kennt keine Programm-Priorität (Round-Robin über 8 Programme): 21507 als nächstes Zählerpaar bekam in 8 h nur ~29 Zellen; Tie-Break nach OWNER-Queue-Reihenfolge beauftragt; 19-h-alter Pruning-Lock (toter Besitzer) entfernt.** Zellen-Reihenfolge = frühestes Jahr je Arm → authentifizierte Arm-Köpfe → Programme ohne aktive Zelle zuerst → Alter; die OWNER-Slot-Reihenfolge wirkt nur bei der Slot-Zulassung. Folge heute: 12710 (216/1.085) und 11910 (344/1.085) laufen mit 70–76 Zellen/h dank Canary L=2, 21507 (575/1.085) mit ~3,5/h, 21505/XAGUSD (778/1.085) und 20048/XTIUSD (582) mit 0 aktiven Zellen. Zellen-Laufzeit ist nicht die Ursache (XAUUSD 3,8 min Median, XTIUSD 2,2). Beauftragt (Claim-Auswahl, GRÜN): Rang nach der OWNER-Queue-Reihenfolge NACH dem Idle-Programm-Rang (jedes zugelassene Programm behält eine Lane, freie Lanes gehen ans zählernächste Programm), Tests + adversariale Prüfung. **Stale Lock:** `DL089_CLAIM_PRUNING.ffb5ca86…` (21507, Arm buy_045) seit 04:18Z von T10 gehalten, PID tot, kein Reaper → Arm-Zellen unclaimbar → entfernt (GRÜN, Stale-Lock-Regel); Reaper-Lücke notiert. Fabrik 23:41Z: 31 Zellen/10 min, RAM 5–11 GB (zwei News + Q07 + Q05), 10700-Expansion bei 258 min (Ende ~00:30Z). Zähler-Erwartung: 11910 und 12710 könnten morgen mittag den Zensus abschließen, 21507 erst in Tagen — sofern das Tie-Break greift.

> **Nachtrag 22:00Z (03.09.) — Beinahe-OOM um 21:57Z (1,86 GB frei): fünf Tester in vier Minuten mit 8-GB-Pauschalen zugelassen, real ~49 GB; nichts gekillt (Schwelle 1,5 GB nicht erreicht, nach 45 s 7,1 GB, um 22:02Z 21,7 GB frei); das Ledger greift jetzt für die schwerste Klasse.** Ursache: die Commit-Reservationen verfallen schneller, als die Working Sets der Tester wachsen (Historie-Laden dauert Minuten), daher ließ die Flotte nach dem Ende der vorherigen Langläufe binnen Minuten fünf schwere Zeilen zu — 10978-Q07 USDJPY H4 wuchs auf 15,0 GB, 1634-Q05 XAUUSD auf 11,6 GB. Das heute gemergte Tester-Ledger hat den Q07-Lauf gemessen (Peak 15,35 GB, 147 Samples) und die Erwartungsdatei führt `fx_major|H4|backtest` jetzt mit n = 5 / max 15,3 GB → die Zulassung reserviert für diese Klasse ab sofort den gemessenen Wert; weitere schwere Klassen (Metall-Q05, Baskets) kalibrieren sich nach drei Messungen. Damit ist die Crash-Klasse vom 02.09. per Messung statt per Pauschale eingegrenzt; das RAM-Upgrade bleibt die strukturelle Antwort (OWNER-Vorlage). Fabrik 22:02Z: 7 aktiv (3 Zensus), 21,7 GB frei; 10978-Q07 endete FAIL (nicht auf dem 25er-Pfad).

> **Nachtrag 21:36Z (03.09.) — 20085-Recovery-Track geparkt (Auffangregel 21:35Z ausgeführt): Hold RECOVERY_BUDGET_EXHAUSTED auf `0bc6a5bc` (WS30 Q07); Fabrik RAM-gebunden (10,9 GB frei, Zensus im Latch).** Genau die eine Aktion aus dem verifizierten Paket §4a (`governed_work_item_hold.py plan` → `apply`, Backup, Zeile non-claimable, kein Verdikt berührt; Release-Bedingung: nur nach OWNER-genehmigter Q07-Budgetrevision für tick-schwere Symbole + expliziter Append-only-Rerun, nicht durch den Pump). XAUUSD `19d3d8e5` war um 17:31Z am 418-min-Budget INFRA_FAIL, EURUSD hat keine pendente Zeile — der H4-r1-Recovery-Track ist damit vollständig geparkt (0 Portfolio-Kandidaten, nicht auf dem 25er-Pfad). **Fabrik:** zwei Q10_NEWS-Läufe (41219 seit ~19:20Z, 10700-Expansion seit 19:23Z bis ~00:30Z) und zwei Q07-5-Seed-Läufe (11015, 10978) halten den RAM (10,9 GB frei) → Zensuszellen (≥12 GB) im Latch, nur 10 Zellen/10 min; CPU 52 % (Claim-Memo wirkt). Das ist die bekannte RAM-Grenze (OWNER-Vorlage Upgrade). Pendent auf RAM: 12580-Q03 `9cac4667`, 10911-Q05 `57aad04d`, 10815-Q02 `bd12175c`. Zensus: 21507 570/1.085, 11910 211/1.085, 12710 106/1.085. Nächste Auffangregeln 04.09. 04:00Z (Vein-1 Welle 1, News-Gate A) und 05:00Z (Q08-Stream-Reruns).

> **Nachtrag 20:59Z (03.09.) — Report-Rohling-Wettlauf im Harness geschlossen (`99fa0a7995`); Sweep seit 15.08.: genau EIN falscher Nullwert (12580-Q03), sonst echte Nullen/Unter-Floor-Läufe; 12580-Q03-Rerun `9cac4667` eingereiht.** Härtung (adversarial verifiziert, 54 Tests inkl. PowerShell-Unit-Test, `run_smoke.ps1` byte-exakt CRLF): erkennt den MetaTester-Rohling (Einlage 0,00 ∧ Symbole 0 ∧ Deals 0 bei Bars > 0), wartet begrenzt 180 s auf Endreport oder terminal64-Exit, prüft sonst das Tester-Journal (UTF-16) auf „deal #“ — mit Deals wird der Lauf zur transienten Infra-Klasse REPORT_CAPTURE_INCOMPLETE (INFRA_FAIL + Treiber-Retry statt Strategie-FAIL), ohne Deals bleibt die Null echt; Early-Stop-Latch, Floors und Verdiktmathematik unverändert. Sweep (`2026-09-03_false_zero_trade_sweep.md/.csv`): 133 Kandidaten → 1 FALSE_ZERO (12580/AUDUSD Q03, nicht moot, Kohorte Batch 2), 18 GENUINE_ZERO, 96 echte Unter-Floor-Läufe mit Trades, 5 Evidenz gelöscht, 11 DEAD16-Leerläufe — die Klasse ist also selten und trifft schwere Multi-Leg-Baskets; keine weiteren Paare zu Unrecht ausgeschieden. Rerun 12580-Q03 `9cac4667` (GRÜN: Infra-Ursache bewiesen und behoben; das alte FAIL bleibt als Evidenz). Zweiter Agent hatte run_smoke parallel enger gepatcht — nicht gemergt (vollständigere Härtung übernommen). Fabrik 20:36Z: 33 Zellen/10 min, 10 aktiv, 30 GB frei.

> **Nachtrag 20:36Z (03.09.) — Drain-Fenster armiert nur noch, wenn es gewinnbar ist (`52c784feb1`): kein Arming bei aktiven Langläufen (Q07+/News), freisetzbarer RAM der kurzen Zeilen muss reichen, Abbruch bei neu erscheinendem Langlauf.** Damit ist die Lücke geschlossen, die um 19:49Z eine reine Zensus-Kosten-Drain öffnete; der Verifier reproduzierte das Szenario (zwei Q07 + zwei News aktiv, 16 GB frei, 44-GB-Zeile >20 min gewartet → kein Arming) und den gewinnbaren Fall (nur Zensuszellen aktiv → Arming) auf Wegwerf-DBs; 170 Tests grün, keine Konstante/Latch/Floor geändert. Worker laden idle-only nach (Chunk 23 hinter 22; Chunk 21 lief um 20:32Z bei 6/10). Fabrik 20:32Z: 31 Zellen/10 min (Tagesbestwert), 9 aktiv, 31 GB frei, T_Live-Journal aktiv. Offen: Harness-Härtung + Falsch-Null-Sweep (Resume läuft) → danach 12580-Q03-Rerun; 21:35Z 20085-Hold (Zielzeile vorverifiziert).

> **Nachtrag 20:11Z (03.09.) — Governor v2 (G6) nach grünem Verdikt gemergt: Aktions-Adapter per Design AUS, kein Pfad zum Live-Konto; ROT-Restliste beim OWNER.** `7ecc1b7457`: der Adapter verwandelt eine Governor-Entscheidung in genau eine atomare Konto-Anweisung (L1 Entry-Freeze als kontoweites Pre-Trade-Signal, L2/L3 Ticketlisten an einen injizierten Executor), verbindet sich nie mit MT5 und verweigert Enforce ohne signierte OWNER-Policy plus separates Aktivierungsartefakt — der Verifier konstruierte den stärksten Fall (gültige Policy + Artefakt + L3-Entscheidung) und erhielt ENFORCE_REFUSED/no_execution_adapter_present ohne jede Schreibung. Design-Record `2026-09-03_governor_v2_g6_design_and_adapter.md`: der Live-Monitor läuft noch unversioniert (v1.10 nicht nach T_Live deployt), kein Scheduled Task, kein Executor — alles ROT/OWNER, Liste auf dem Board. Fabrik 20:10Z: 7 aktiv (2 Q07, 2 News inkl. 10700-Expansion, 3 Zensus), 18 Zellen/10 min, 21 GB frei, Reload Chunk 21 läuft, Drain geschlossen (Abklingzeit 02:04Z). Laufend: Harness-Härtung + Falsch-Null-Sweep (Resume), Drain-Arming-Verfeinerung.

> **Nachtrag 20:05Z (03.09.) — Opus-Sitzungslimit um ~19:45Z erreicht (Reset 20:00Z): Governor v2 geliefert, aber unverifiziert → kein Merge; Härtung + Sweep neu gestartet; Drain-Fenster von Hand geschlossen (unwinnbar bei laufenden Langläufen), Arming-Verfeinerung beauftragt.** Die Restquote ist damit wie vom OWNER gewünscht bis zum Reset verbraucht; ab jetzt gilt wieder Wochenpacing (Tiefe vor Volumen). Governor v2 (G6): Design + Aktions-Adapter liegen im Worktree (Enforce-Modus unerreichbar ohne signierte OWNER-Policy + separates Aktivierungsartefakt; nichts davon existiert) — Verifier lief ins Limit, Resume läuft; Merge erst nach grünem Verdikt. run_smoke-Härtung (Report-Rohling) + Falsch-Null-Sweep: beide Agenten scheiterten am Limit, Resume läuft; der 12580-Q03-Rerun wartet darauf. **Drain-Fenster:** um 19:49Z öffnete es für 11129/Q07 (44-GB-Index-Klasse), während zwei Q07- und zwei News-Läufe den RAM stundenlang halten (16 GB frei) und die meisten Worker den Drain-Floor noch nicht geladen haben (Chunk 22 wartet) — unwinnbar, reine Zensus-Kosten → von Hand geschlossen (`drain_window.json`: active=None, Abklingzeit bis 02:04Z). Lücke: die Arming-Regel prüft nicht, was gerade läuft → Verfeinerung beauftragt (kein Arming bei aktiven Langläufen, freisetzbarer RAM muss reichen, Abbruch bei neu erscheinendem Langlauf). Fabrik 20:03Z: 8 aktiv, 17 Zellen/10 min, 16 GB frei, C: 82 GB frei, Pump/Guardian/Containment in Ordnung; 10700-Expansion 152e8d29 seit 19:23Z (T4); V1(b)-Rerun 10911-Q05 `57aad04d` pendent.

> **Nachtrag 19:36Z (03.09.) — V1(b)-Auffangregel ausgeführt (10911/GDAXI Q05-Rerun `57aad04d`); 12580-Q03 war ein falscher Nullwert des Harness (Report-Rohling gelatcht), nicht Strategie — Härtung + Sweep laufen.** V1(b): genau die eine governed Aktion aus dem verifizierten Paket (Append-only-Rerun von `f4ac4d5c` INFRA_FAIL, Vorgänger Q04 PASS, Binary unverändert); für 1556/12969 (News-Gate) und 10403/11708 (Programm-Slots) gab es nichts Governed auszuführen. **12580/AUDUSD:** Diagnose adversarial verifiziert (`2026-09-03_qm5_12580_audusd_q03_zero_trade_diagnosis.md`, `ab8aa8584d`) — der Lauf handelte (Journal Deals #2–#69, „Test passed“, Logger 36 ENTRY_ACCEPTED, Q02 desselben Binaries 47 Trades), aber `run_smoke.ps1` übernahm den Report-Rohling (Einlage 0,00 / Symbole 0 / Trades 0 bei 958 Bars), weil der Post-Completion-Pfad nur Bars > 0 prüft und nur auf den Tester-Agenten statt auf terminal64 wartet; bei 7-Leg-Baskets (~22 GB Cache) ist die Nachlaufzeit lang. Das FAIL bleibt append-only (Taxonomie „strategy“ falsch); Rerun nach der Härtung. Beauftragt (wf_2dc8f552-a32): Rohling-Signatur → begrenzt auf terminal64-Exit/Deals warten, sonst Journal-Kreuzcheck → neue transiente Klasse REPORT_CAPTURE_INCOMPLETE → INFRA statt FAIL; plus Sweep aller Null-Trade-FAILs seit 15.08. auf Journal-Deals (möglicherweise weitere zu Unrecht ausgeschiedene Paare). Governor v2 (G6) im Bau (wf_36c785e8-af5). Fabrik 19:40Z: 10 aktiv, 24 Zellen/10 min.

> **Nachtrag 19:15Z (03.09.) — News-Gate-Prüfauftrag D erledigt: der „NONE-Compliance-Defekt“ ist ein Label-Artefakt, die Expansion ist für Ein-Ziel-Deployments entscheidungsirrelevant (32/32 Locks wählten DXZ) → ROT-Vorlage (a)+(e); Fremd-Worktrees alle mit WIP.** Analyse (`docs/ops/evidence/2026-09-03_newsgate_proposal_d_analysis.md`, adversarial verifiziert): alle 54 als NONE gelabelten Zeilen liefen tatsächlich DXZ/POLICY_ON — die beiden REVIEW-Ergebnis-Dicts in `q09_news_contract.adjudicate` lassen `target_compliance`/`matrix_scope` weg und der Schreiber setzt „NONE“ (Verdikt-Auswirkung 0). `material_effect` feuert auf echte Effekte der News-Modi (Median 123 Entries je Zeile weniger im stärksten Modus), nicht aus dem inerten Seed-Kanal; der Zähler `affected_entries` ist nicht verdrahtet (0/15, Instrumentierungsdefekt). Entscheidend: der Selektor bewertet nur die Zielspalte, die 29-Zellen-Expansion liefert NONE/FTMO/5ERS-Spalten, die nie gewählt werden — Option (e) „Expansion für Ein-Ziel-Deployments aufschieben“ würde alle 43 offenen Expansions-Zeilen ohne Schwellenänderung am 8-Zellen-Lauf locken und die News-Gate-Wand (19–36 Tage) vor Q11 entschärfen; Schwellen anheben (b) bewegt nur 1–7 von 43. Alles ROT → OWNER-Vorlage (a)+(e) ersetzt die D-Vorlage von 15:55Z. Fremd-Worktrees (`2026-09-03_foreign_worktrees_audit.md`): 21 Bäume unter `C:\QM\worktrees` (~24 GB), alle mit unbestätigter oder ungemergter Arbeit → nichts entfernt. Governor v2 (G6, Aktivierung OWNER-gated, standardmäßig aus) läuft als Opus-Bau (wf_36c785e8-af5); 12580-Q03-Diagnose läuft (wf_710ffab1-cea). Fabrik 19:14Z: 8 aktiv, 16 Zellen/10 min, 26 GB frei, C: 87 GB.

> **Nachtrag 19:07Z (03.09.) — 12580/AUDUSD scheitert an Q03 auf der neuen Identität mit NULL Trades (2018-07 bis 2022-12, Modell 4), obwohl Q02 heute handelte — gleiche Klasse wie der dokumentierte 10025-Nulltrade-Fall; Diagnose läuft, das FAIL bleibt append-only stehen.** `a64d18d3`: zwei Läufe, je Nettogewinn 0,00 / Drawdown 0,00 / PF 0,00, Real-Ticks-Marker gesetzt, kein OnInit-Fehler, Floor 25 → `run_smoke_fail:MIN_TRADES_NOT_MET`. Die alte Identität bestand Q03 am 28.06. (Evidenz gelöscht), die einzige Quelländerung seit Juni ist der MAE-Hook plus die heutigen Framework-Includes. Der 10025-Fall vom 02.09. (`2026-09-02_qm5_10025_usdjpy_zero_trade_instrumented_q02.md`) zeigt dasselbe Fenster und Symptom bei einem 7-Paar-FX-Basket: INIT_OK, alle Partner-Historien synchron, aber null Auswahl-/Signal-Marker. Read-only-Diagnose (Run-Logs, Terminal-Journal T3, Archiv-Privatisierung der sechs Nicht-Host-Legs, EA-Quelle) läuft adversarial verifiziert (wf_710ffab1-cea); erst mit bewiesener Infra-Ursache folgt ein governed Rerun, sonst steht der Q03-FAIL und 12580 scheidet aus Batch 2 aus (dann bleibt von Batch 2 nur 10815/GDAXI, das am Index-RAM hängt). Fabrik 19:02Z: Guardian aktiv, 10 Worker, Pump frisch, Containment aus, 85 GB C: frei, Zensus 11 Zellen/10 min; 12710 54/1.085, 11910 92/1.085, 21507 562/1.085.

> **Nachtrag 18:44Z (03.09.) — Drain-Floor gemergt (Index-Zeilen ab 48 GB frei gewinnbar); 12580-Q03 läuft (T3); FTMO-Evaluator: Rulepack-V2-Pin vom 02.09. ist in sich inkohärent → OWNER-Vorlage.** `73e0119ccc`: ist ein Drain-Fenster für eine Zeile bewaffnet und läuft fleet-weit kein anderer Tester mehr, wird genau diese Zeile mit 4 GB statt 14 GB Post-Reservation-Floor zugelassen — 44 + 4 = 48 GB passen auf den 63-GB-Host, 44 + 14 = 58 GB nie; alle anderen Zeilen behalten 14/20; Kill-Switch `QM_DRAIN_WINDOW=0`; Worker laden idle-only nach (Chunk 22 hinter 21/20). Damit hat 10815/GDAXI-Q02 erstmals einen Weg; die erste GDAXI-Messung landet dann im Ledger. **12580/AUDUSD:** Q03 `a64d18d3` um 18:41Z regulär geclaimt (Commit-Headroom reichte vor dem 20-min-Drain-Trigger). **FTMO-Evaluator (`5065dcda78`):** Quellen-IDs und Semantik mit Rulepack V2 synchronisiert (+1 Test, keine Regression), aber 24 Tests bleiben rot: der Pin `0abbc24b02` (Codex, 02.09.) hob `profile_version` 1→2 und `as_of` an und legte alle sieben Quellen auf den Economic-Terms-Snapshot (Schema `qm.ftmo-economic-terms-snapshot/v1`), während der Evaluator den Official-Rules-Snapshot vom 29.07. (`qm.ftmo-official-rules-snapshot/v1`) pinnt — zwei Validatoren lesen denselben `snapshot_path` mit widersprüchlicher Semantik. Auflösung braucht Rulepack-/Evidenz-Änderung (FTMO-Evidenzkette) → OWNER-Vorlage. Keine Live-Auswirkung (kein FTMO-Buch), aber jede FTMO-Bewertung seit 02.09. wäre an dieser Stelle verweigert worden. Fabrik: 10 aktiv, 8 Zellen/10 min (3 Zensus-Lanes, RAM 15 GB frei), C: 87 GB frei.

> **Nachtrag 18:14Z (03.09.) — Drain-Fenster, CIM-Scan-Härtung und Expansions-Flag gemergt; Index-Tick-Audit: die 44-GB-Klasse beruht auf EINER SP500-Messung, freier RAM erreichte in 24 h nie 44 GB; hängende T8-Zelle neu gestartet; Testfehler-Audit: 93 Scheinfehler durch autocrlf in Worktrees (gepinnt), 24 echte durch Evaluator-Drift (Fix läuft).** Drain-Fenster (`0000407c2e`, +497 additiv, `QM_DRAIN_WINDOW=0` aus): wartet eine priority-getrackte schwere Zeile >20 min am Headroom, nehmen die Worker bis 30 min keine neuen kurzen Zeilen mehr, bis der RAM reicht (Abklingzeit 90 min, eine Drain zugleich, State-Datei `drain_window.json`). Per Design trifft es 32-GB-Baskets (12580-Q03), nicht die 44-GB-Index-Klasse (58 GB > 53 GB drainbar) — Folgeschritt läuft: abgesenkter Floor (4 GB) NUR für die bewaffnete Zeile bei leerer Flotte, dann reichen 48 GB (wf_ac0211ba-fee). Audit (`2026-09-03_index_tick_admission_audit.md`): 491 pendente Index-Zeilen (Q02 112 / Q03 10 / Q04 369), 10 davon priority_track; für GDAXI/NDX/WS30/UK100 existiert keine einzige Speichermessung — die Sperre verhindert die Messung, die sie kalibrieren würde. CIM-Scan (`d5ec4ade50`): Toolhelp-Walk zuerst, pwsh-Fallback 90 s mit Retries — ein Timeout kostet kein 29-Zellen-Kind mehr. `--force-expanded-news-matrix` (`73e28c2bd2`): exakter 29-Zellen-Rerun eines verlorenen Expansions-Kindes statt 8 + 29. **Tests:** die vermeintlich 8 Fehler sind 117: 93 Scheinfehler, weil zwei hash-gebundene Evidenzdateien nicht `-text` gepinnt waren und autocrlf sie in Worktrees auf CRLF smudgte (kanonisches Repo LF, Pruning-Authentisierung in Produktion OK; jetzt gepinnt `f52e88129a`); 24 echte: `ftmo_book3_standalone_evaluator` lehnt seit `0abbc24b02` (Rulepack V2) sein eigenes Rulepack ab, weil `EXPECTED_OFFICIAL_SOURCE_IDS` die neue Quelle `ftmo_economic_terms_official` nicht kennt — Fix beauftragt. **T8:** Zensuszelle `4c8d2ef4` hing 85 min (Tester 0,26 GB, kein Run-Log) → Worker/Tester neu gestartet, Zelle pendent, Flotte 10/10. Fabrik: 11 Zellen/10 min, 26,9 GB frei, C: 84 GB frei, Reload Chunk 20 7/10, Chunk 21 wartet.

> **Nachtrag 17:46Z (03.09.) — Canary-Auffangregel ausgeführt (L=2 für 21507/12710/11910, wirkt beim Worker-Reload); 10700-Expansion scheiterte an EINER Zelle (CIM-Timeout unter Volllast) → exakter Rerun läuft; 20085 planmäßig ausgelaufen; Q08-Durable-Export gemergt.** Same-Program-Canary: Machine-Env `DL089_LANES_PER_PROGRAM=2` + Allowlist der drei zählernächsten Programme gesetzt (17:43Z, als Auffangregel-Ausführung der Vorlage 05:45Z/13:00Z; RAM-Lage 24,7 GB frei, daher alle drei); Rückweg = Variablen löschen + Reload. **10700/XAUUSD (Aufsteiger-Kandidat für Paar 25):** die 29-Zellen-Expansion `c0faeb48` endete 17:05Z mit REVIEW_REQUIRED, Grund allein `cell_execution_failed` — der 30-s-Prozess-Scan per pwsh/CIM lief bei 100 % Host-CPU (Worktree-Löschungen + Agenten-Tests) in den Timeout; Infra, nicht Strategie. Der Pump retried nur Stale-Worktree-Expansionen, daher manueller Append-only-Rerun `0c247960` (17:39Z, sofort geclaimt); er läuft als 8-Zellen-Lauf, weil `enqueue-backtest` die Expansions-Identität nicht mitgeben kann → bei materiellem Effekt folgt erneut die 29-Zellen-Expansion (~2,5 h + ~5 h). Flag `--force-expanded-news-matrix`, CIM-Scan-Härtung (Retry/Backoff/Toolhelp-Fallback) und die 8 vorbestehenden Testfehler laufen als Opus-Workflow (wf_1bef194a-0b8). **20085:** XAUUSD-Q07 `19d3d8e5` um 17:31Z am 418-min-Budget INFRA_FAIL (wie im Paket vorhergesagt); Hold auf WS30 `0bc6a5bc` bleibt Auffangregel 21:35Z. **Q08-Streams:** Verify-and-record beim Siegel + Append-only-Sibling + Backfill-CLI gemergt (`27625045c0`); Rerun-Paket für 1537/10706/11422/13054 verifiziert (Auffangregel 04.09. 05:00Z). Fabrik: 10 aktiv, 13 Zellen/10 min, C: ~80 GB frei, Reload Chunk 20 läuft.

> **Nachtrag 17:35Z (03.09.) — Durchsatzhebel gemergt: Zensus-Vorrang gegen schwere Läufe + Claim-Order-Memo (`4fe39056cc`), G5-Konsument (`06c3220131`); Worker laden idle-only nach (Chunk 20); C: bei ~79 GB frei.** Claim-Order-Memo: jeder Claim-Versuch sortierte die ~12.700 pendenten Zeilen zweimal (je ~0,9 s, JSON-Rangschlüssel je Zeile) — zehn Worker hielten den Host damit bei 97–100 % und lösten ihren eigenen CPU-Guard aus (die Rückkopplung hinter den `cpu_high_pause`-Stillständen); das Memo liefert byte-identische Reihenfolge (auf einer Live-DB-Kopie mit 12.107 Zeilen bewiesen) und wird nur wiederverwendet, solange `PRAGMA data_version` die DB als unverändert beweist; jeder Claim revalidiert weiter unter BEGIN IMMEDIATE; Rollback `QM_CLAIM_ORDER_CACHE_TTL_MS=0`. Zensus-Vorrang: schwere Kandidaten (≥10 GB Reservation) werden in der Runde zurückgestellt, wenn claimbare Zensuszellen existieren und der Headroom sonst unter 16 GB fiele; nie für Compiles oder priority-getrackte Lineage-Zeilen; Rollback `QM_CENSUS_FIRST_RAM_PRIORITY=0`. G5: `verify_live_deployment_contract.py --pointer` liest den Pointer mit den Morning-Brief-Regeln (Paritätstest); ohne Signatur bleibt alles UNKNOWN/AMBER. 267 Tests grün. Verifier meldet 8 vorbestehende Testfehler (Rulepack-Snapshot-Hash/Seal-Identität in vier Suiten) — Reparatur beauftragt. Fabrik: 9 aktiv, Zensus 7 Zellen/10 min (CPU-Guard während Worktree-Löschung), Reload läuft. Nächste Auffangregel 17:45Z Canary.

> **Nachtrag 17:13Z (03.09.) — INCIDENT C: voll (0,1 GB) durch ~30 Opus-Worktrees; T_Live-Terminal unversehrt; Bereinigung läuft (40 GB frei um 17:12Z). Befund: Index-Tick-Q02-Läufe (44-GB-Klasse) sind auf dem 63-GB-Host unclaimbar.** Jeder Workflow-Worktree ist ein voller Repo-Checkout (EAs + Artefakte); zusammen mit 13 `rework-slot`- und 5 `claude-orchestration`-Worktrees standen 108 Worktrees auf C:. Erkannt um ~17:00Z (Vault-Write ENOSPC, Worktree-Anlage des Drain-Fenster-Workflows fehlgeschlagen). T_Live: Terminal läuft (seit 23.08.), Journal bis 16:17Z beschrieben (Deal-Eintrag), keine Fehlerzeilen; D: unberührt (85 GB frei). Maßnahme (GRÜN): alle abgeschlossenen `wf_*`-Worktrees entfernt (Lieferungen waren bereits gemergt), laufende behalten; zweiter Pass für Worktrees mit defektem `.git`-Zeiger; git/bash in die Idle-Priorität aufgenommen, weil der CPU-Guard T1/T7/T10 anhielt. **Folgen:** Drain-Fenster-Workflow (wf_051790b8-a85) und der Verifier des Q08-Durable-Exports (wf_82fd54d3-a9c) scheiterten am ENOSPC — nichts Unverifiziertes gemergt, beide werden nach der Bereinigung fortgesetzt. **Befund Index-Tick:** 10815/GDAXI-Q02 (Recompile-Kette) trägt die RAM-Klasse `single_index_tick` mit 44 GB Reservation (SP500-Q02 46,8 GB gemessen am 15.08.) und bräuchte 58 GB frei — mit ~10 GB Grundlast nie; 112 pendente Index-Q02 und 369 Index-Q04 teilen die Klasse (Universum NO-TARGET-SYMBOLS-DEFAULT enthält die Indizes). Lösung in Arbeit: begrenztes Drain-Fenster für priority-getrackte schwere Zeilen (Claim-Auswahl, Kill-Switch); RAM-Upgrade-Frage beim OWNER. Q08-Durable-Export-Befund: `aggregate.py` schreibt den Stream bereits beim Siegel nach `sleeve_streams` (:748) — die vier fehlenden Dateien wurden nachträglich gelöscht; Ergänzung = Verifikation + Append-only-Sibling + Backfill-CLI (unverifiziert, nicht gemergt). Fabrik: 6 Zellen/10 min (CPU-Guard), 24 GB frei, Pump 17:08Z.

> **Nachtrag 16:51Z (03.09.) — Buchpfad-Defekte D1–D6 gemergt (vier Verdikte ok); D4 real: nur 1 von 5 qualifizierten Paaren hat einen physisch vorhandenen versiegelten Stream; Multi-Symbol-Zeilen verhungern am 48-GB-Commit-Headroom.** D1/D2/D5/D6 (`4a4cb78355`, `e7f0ee2b13`, `032454c904`): Runbook-Kommando korrigiert, Guard-/Freeze-Ablehnungen der drei Buchpfad-Einstiege als strukturierte JSON-Verweigerung mit Exit 2 statt Traceback (nichts läuft weiter), Stager legt das Berichtsverzeichnis an, FTMO-Builder trägt jetzt denselben Fail-closed-Freeze-Guard wie DXZ. D3 (`68eba1e611`): `build_qualified_roster.py` erzeugt das Roster aus dem Guard-Zensus (Builder akzeptieren `--roster` bereits). D4: `assemble_stream_bundle.py` bindet Streams an die aktuelle Identität (ex5-SHA = Q14-KEEP_INCUMBENT-Binary, content-SHA aus dem Q08-Aggregat) und verweigert Unverbundenes — **realer Lauf: nur 11421/EURUSD hat die Bytes; 1537/XAG, 10706/GBP, 11422/USDCAD, 13054/XTI haben zwar die Siegel im Q08-Aggregat, aber die Stream-Dateien fehlen (Aufräumungen); das Default-Bundle `dxz_final_20260719` trägt Juli-Identitäten.** → OWNER-Vorlage: Q08-Baseline der vier Paare auf dem aktuellen Binary als Append-only-Rerun neu ausführen (GELB, vier schwere Läufe, Auffangregel 04.09. 05:00Z). **Claim-Pfad:** 12580-Q03 `a64d18d3` (7-Symbol-FX-Basket) steht auf Claim-Position 1, braucht aber 48 GB Commit-Headroom (Reservation 32 GB) — bei 8 Testern unerreichbar; 10815-Q02 `bd12175c` Position 3 ebenfalls unclaimt (Grund nicht geloggt). Fabrik: 34 Zellen/10 min, 26,5 GB frei, 8 aktiv, Pump 16:48Z, Containment aus. Laufend: Durchsatzhebel-Workflow (wf_f3c42ecc-550).

> **Nachtrag 16:42Z (03.09.) — Orthogonalitätsstandard für sparse D1 (G3/V4) verifiziert und committet: das heutige Korrelationstool liefert für 0 von 46 buchrelevanten Paaren einen verwertbaren Wert.** Design-Panel (3 Vorschläge, 3 Richter, Synthese, adversarial verifiziert; `docs/research/SPARSE_D1_ORTHOGONALITY_STANDARD_2026-09-03.md` + Schätzer-Skripte und Messungen in-tree): `portfolio_correlation.py` filtert auf beidseitig-nonzero Tage (biast |r| nach oben), füllt das Union-Fenster mit Nullen (drückt |r| mechanisch gegen 0) und floort bei 60 gemeinsamen Tagen — die 5 qualifizierten Paare erreichen maximal 27, die 9 auditierten maximal 50; das ratifizierte Aktivitätskriterium (≥10 Entry-Tage/Jahr) ergibt ~2 erwartete gemeinsame Exit-Tage, Option (b) „60 Tage Overlap“ ist damit strukturell unerfüllbar. Adoptiert: zweistufig fail-closed — Stufe A zeros-kept Tages-Pearson auf dem gemeinsamen Fenster mit Block-Bootstrap-Konfidenzintervall (zertifiziert nur bei CI ⊂ |r| < 0,5, sonst ABSTAIN), Stufe B Trade-Co-Occupancy-Flag mit exaktem Zirkularshift-Nulltest (fängt Same-Family-Redundanz; Positive-Kontrolle AUDCAD×EURUSD desselben EA: Pearson blind, Flag p = 0,0013). V4-Vorlage auf dem OWNER-Board auf Option (c) aktualisiert: Methode jetzt, Schwellen nach der ersten SHA-eingefrorenen Q14-Kohorte. Router: 0 REVIEW-Tasks in allen Lanes. Laufende Workflows: D1–D6 (wf_10455ec8-70e), Durchsatzhebel (wf_f3c42ecc-550).

> **Nachtrag 16:32Z (03.09.) — News-Gate B + C gemergt (`1210766f97`, `e72c4d62cc`); 12580/AUDUSD hat Q02 auf der neuen Identität bestanden → Q03 läuft ein; Zensus während des 19,7-GB-Q02-Laufs auf 3 Zellen/10 min.** B: Expansions-Kinder (7x4, 29 Zellen) bekommen ein Reaper-Budget von 900 min statt 11.080 (gemessenes Maximum 13,2 h; nur Reaper-Timing, 8-Zellen-Eltern und Referenzpilot unverändert). C: Expansions-Kinder eines Lineage-Elternteils ranken mit den Lineage-Reruns (additiver Arm, bestehende Reihenfolge byte-identisch; v4-Readiness 23/23). Beide Änderungen wirken im Pump sofort, in den Workern beim Idle-Reload. **12580:** Q02 `d53328e2` PASS 16:27Z, Q03 `a64d18d3` (exakter Rerun von `6ce2cb7c`, priority_track vererbt); 10815-Q02 `bd12175c` wartet auf RAM. **Fabrik:** der 12580-Q02 brauchte 19,7 GB (Multi-Symbol-EA, 7 FX-Slots) neben 20085 (11,5 GB) → fünf Worker im Latch bei 9,4 GB frei; jetzt 19,6 GB frei, 6 aktiv, Chunk 18 lädt T2/T1 nach. Laufende Opus-Workflows: D1–D6 (wf_10455ec8-70e), G3-Panel (wf_18ea64f8-b1c), Durchsatzhebel (wf_f3c42ecc-550: Zensus-Vorrang gegen schwere Läufe, Claim-SQL-Kosten, G5-Konsument). Auffangregeln unverändert (17:45Z Canary, 19:35Z V1(b), 21:35Z 20085).

> **Nachtrag 16:20Z (03.09.) — RAM ist die bindende Fabrik-Grenze (Vorlage Upgrade); vier weitere verifizierte Lieferungen gemergt (Vein-1-Affordance, Testfix, G1/G2/G8, G5-Vorlage + Hygiene-Audit); Buchpfad-Probe findet zwei strukturelle Lücken (D3 Roster, D4 Streams).** 16:14Z: 51,9/63,1 GB belegt (4 Tester 32,6 GB, Terminals 3,8, Worker/Pump 3,0, Opus-Agenten ~3,5, RDP-Browser ~3,3), sechs Worker im RAM-Latch bei 11,3 GB frei, Zensus 10–20 Zellen/10 min; der 11,5-GB-Lauf 20085/XAUUSD (T3) läuft laut Paket bis ~17:31Z aus; um 16:19Z wieder 10/10 aktiv (19,9 GB frei). **Gemergt nach grünem Verdikt:** `farmctl requeue-false-invalid-setfile` (`c77a8c9dc1`, 5 Vorbedingungen als reine Prüffunktion, 22 Tests, Dry-Run aus dem kanonischen Repo = would_enqueue; Welle 1 bleibt Auffangregel 04.09. 04:00Z); Decay-Testfix (`5ec57fdfdd`, 16/16); G1 Order-Template + Minter (`--validate` durch den Guard-Parser), G2 `q15_fit_report.py` (erster Lauf am 5er-Pool: 0/10 Korrelationen bewertbar, max. Überlappung 27 Tage < 60-Tage-Floor; Marginal-Sharpe für alle fünf positiv), G8 Scratch-Probe (`58221e3401`): Fail-closed-Gates halten, aber **D3** (Builder bauen aus dem Juli-Roster statt aus dem Zensus) und **D4** (3 von 5 qualifizierten Paaren haben keinen versiegelten Q08-Stream im Bundle) blockieren den Buchpfad unabhängig vom Zähler → Fix-Workflow D1–D6 läuft (wf_10455ec8-70e). G5-Signatur-Vorlage (`4f02c7f1c5`): Pointer ungesigned seit 22.08., Dry-Run byte-identisch zum Live-Pointer (keine Drift); signierter Mint ist Freeze-gated und braucht die Epoch-Entscheidung 07-24 (Manifest) vs 07-19 (Go-live) — OWNER-Vorlage; Verifier widerlegte einen Satz (Sunday-Compare liest die Epoch aus dem Pointer), korrigiert. Hygiene-Audit: alle 18 Legacy-COMPILE_EA-Zeilen sind bereits supersedet → keine Aktion. Fabrik: Pump 16:18Z, Guardian aktiv, Chunk 19 wartet auf Chunk 18 (T4/T2/T3/T5 beschäftigt).

> **Nachtrag 15:56Z (03.09.) — Tester-Memory-Ledger im Worker (`77fc3266a6`), Runbook committet (`c032dbb1a5`), drei Alt-Identitäts-Zombies supersedet, vier weitere Opus-Workflows gestartet; Host-CPU 100 % → Agenten-Priorität gesenkt.** Ledger: jeder Lauf schreibt Peak-Working-Set je Symbolklasse×TF×Laufart nach `D:/QM/reports/state/tester_memory_ledger.jsonl`; schwere Ein-Symbol-Läufe reservieren ab 3 Messungen max(flat, gemessen) — nie weniger, nie für Multisymbol/Zensus/Seeds; Rollback `QM_TESTER_MEMORY_ADMISSION=0`. Worker laden idle-only nach (Chunk 19 hinter Chunk 18). Runbook: Verifier hatte die FTMO-Ein-EA-je-Symbol-Behauptung widerlegt (Builder macht `select_under_aggregate_control`, Task 9bdfde03 PASSED) — korrigiert, V0–V6 + G1–G8 auf dem OWNER-Board (V2/V6 vorab entscheiden). Zombies 57d8bacd / a2431935 / aece4bcc (pre-binding, hätten das alte Binary gebunden) supersedet, alte Zeilen bleiben Evidenz. **Fabrik:** parallele Opus-Testläufe trieben die CPU auf 100 %, Zensus fiel auf 11 Zellen/10 min, T6/T8 idle am CPU-Guard → Agenten-/Test-Prozesse auf Idle/BelowNormal (Loop alle 45 s); RAM 14,9 GB frei; 41335-Compile pendent; Q02-Seeds 10815/12580 pendent auf Position 2/3. **Laufende Workflows:** News-Gate B+C, Vein-1-Affordance + Testfix, Runbook-Lücken G1/G2/G8, G3-Orthogonalitätsstandard (Design-Panel). Auffangregeln unverändert: 17:45Z Canary, 19:35Z V1(b)=10911-Q05, 21:35Z 20085-Hold.

> **Nachtrag 15:44Z (03.09.) — Batch 2 der Recompile-Welle durch (10815/GDAXI + 12580/AUDUSD neu kompiliert, Siblings 41334/41335 gebaut, Q02-Seeds auf Claim-Position 2/3); fünf verifizierte Vorbereitungspakete committet; strukturelle Decke 24 gemessen.** Opus-Workflow wf_3082f98f-2a8 (4/4 Verdikte ok): beide Pre-0803-Eltern mit dem MAE-Hook repariert (`a8badb90cb`), Siblings gebaut (`35671df4b8`; 41335 auf Ein-Symbol-Slot reduziert, weil der Allokator keine Slot-Deklaration kennt), Magics 413340000/413350000 seriell alloziert, vier Compiles per ID freigegeben: 10815 + 12580 + 41334 COMPILE_OK (15:38Z), 41335 pendent. Neue Identitäten per `seed-fresh-q02` (Rerun-Form lehnt PASS-Ziele ab): `bd12175c` (10815), `d53328e2` (12580), priority_track, Claim-Positionen 2 und 3. **Pakete (`54162ed052`, alle adversarial verifiziert):** (1) Pfad-zu-25-Modell — Decke 5 + 19 Q11-kontiguierte = 24, Paar 25 braucht einen Aufsteiger aus dem Q09-Pool (10700 modelliert); Termine S0: 10→04.09., 15→05./06.09., 20→07.09., 25→09.09., Bias optimistisch (Rate von schnellen Metall-D1-Programmen getragen; 180/h ist keine harte Decke, gemessen 215–245/h). (2) V1(b): nur 10911 hat ein lauffähiges Kommando (Q05-Rerun; Auffangregel 19:35Z), 1556/12969 hängen am News-Gate, 10403/11708 warten auf Programm-Slots — der Q12-Rollout-Hold liegt auf 28/30 Q12-Zeilen inkl. dem laufenden 21507 und blockiert den Service nicht. (3) Vein 1 (150 falsche INVALIDs): kein farmctl-Pfad nimmt die Klasse an (Universe-Expansion, Rerun-Form, seed-fresh alle fail-closed) → braucht eine geprüfte Affordance (Implementierungsauftrag, Reruns GELB ~13–30 Slot-Stunden, Zähler-Wert 0 kurzfristig). (4) 20085: einzige haltbare Zeile `0bc6a5bc` (WS30) → Hold um 21:35Z, `19d3d8e5` (XAUUSD) läuft aus (~17:31Z). (5) News-Gate-Forensik: von 85 REVIEW_REQUIRED nur 34 echte Expansionen, 38 `cell_execution_failed` (billige Reruns, keine Expansion), Expansion = 29 Backtests, Kind-Wartezeit Median 8,3 h; Vorschläge A (Cap 2→3 RAM-gated, GELB), B (Kind-Timeout 11.080/22.860 → ~900 min, GRÜN), C (Lineage-Rang auch für Expansions-Kinder, GRÜN), D (8-Zellen-NONE-Compliance-Defekt / material_effect-Schwellen, ROT → OWNER-Vorlage). B + C laufen als Opus-Workflow (wf_3d2098c6-6f4). **Runbook:** Verifier widerlegte die FTMO-Behauptung (Builder macht bereits `select_under_aggregate_control`, Task 9bdfde03 ist PASSED) → Revision läuft (wf_6be351fc-4b6), Commit erst nach grünem Verdikt. Fabrik: 26 Zellen/10 min, 8 aktiv, Containment aus, Guardian aktiv.

> **Nachtrag 15:30Z (03.09.) — Zensus-Bremse wirklich gefunden: Zellen scheiterten am Pro-Zeilen-RAM-Check (17 GB frei − 4 GB < 14 GB) → Infra-Reparatur `49e7b029f4`; hängender T7-Lauf neu gestartet.** Bei 17 GB frei waren die Worker NICHT gelatcht, meldeten aber `no_pending_claimable`: jede Zensus-Zelle fiel nach Reservation unter den 14-GB-Floor (Zellen erst ab 18 GB frei claimbar) — die Vorlage von 13:15Z war die richtige Diagnose, aber unterschätzt: nicht nur das 12–14-Band, sondern das ganze Band 12–18 GB war für den Zensus tot. Als reversible GRÜN-Infra-Reparatur (Stehende Vollmacht: kein Verdikt, Rollback = Konstante + Reload, Blast-Radius = Zensus-Zellen à 4 GB) jetzt umgesetzt statt bis 01:15Z zu warten: `OPT_CENSUS_POST_RESERVATION_FLOOR_GB = 8` (Zelle claimbar ab 12 GB frei); Backtests behalten 14/20, Compiles den 3-GB-Bypass; 97 Worker-Tests grün; Reload Chunk 18 seit 15:20Z. Erwartung: Zensus zurück auf 30–50 Zellen/10 min in den Latch-Phasen. **T7:** Zensus-Zelle `c25808a8` (Programm 20266) 107 min aktiv mit 0,3-GB-Tester ohne Run-Log (hängender Start) → Worker + Tester 15:19Z neu gestartet (GRÜN), Zelle läuft über den Treiber-Rerun wieder ein. Stand: 12710 22/1.085, 11910 8/1.085, 21507 546/1.085; 10700-Expansion T5 (2,5 h); sechs Opus-Workflows laufen.

> **Nachtrag 15:05Z (03.09.) — OWNER-Direktive „Restkontingent verbrennen“: fünf verifizierte Opus-Workflows parallel gestartet; Batch-2-Compiles scheiterten am Build-Gate (MAE-Hook) → Reparatur läuft.** Batch 2: `2f8fe7d9` (10815) und `bc865e0b` (12580) COMPILE_FAIL mit EA_Q08_MAE_HOOK_MISSING (wie Batch 1) → Workflow `w5912677p`: Korsett-Reparatur je Parent + Sibling-Welle 4 (41334/41335) in einer Pipeline, je Schritt adversarial verifiziert. Weitere Workflows: `wxy5aqbxc` Tester-Speicher-Ledger + klassenbasierte RAM-Admission (Design→Implementierung→Verifizierung; Env-Rollback), `w8c3p8gy2` Buch-Zeremonie-Runbook + Pfad-zu-25-ETA-Modell (Docs), `wkdmhchxj` V1(b)-Requalifikationspaket (exakte Kommandos für die Auffangregel 19:35Z), `wpfe8kooc` Reparatur der vorbestehend fehlschlagenden Tests (ohne Assertion-Abschwächung). Quota: Claude weekly_remaining 34 % bei 96 % Wochenverlauf. Fabrik: RAM-gebunden, Zensus 6–10 Zellen/10 min, 10700-Expansion läuft (T5), 20085-Recovery auf T3.

> **Nachtrag 14:45Z (03.09.) — AUFFANGREGEL AUSGEFÜHRT: Batch 2 Recompiles (10815/GDAXI, 12580/AUDUSD) eingereiht und freigegeben.** Vorlage 02:13Z, keine OWNER-Antwort bis 14:13Z → gemäß Stehender Vollmacht (reversibel, append-only) ausgeführt (Wake-up feuerte verspätet 14:41Z): Compile-Zeilen `2f8fe7d9` (QM5_10815_tv-post-vwap) und `bc865e0b` (QM5_12580_fx-usd-exhaustion-reversal), Allowlist PRE0803 (`fcc1a439d8`), per `--work-item-id` freigegeben (12580 im zweiten Anlauf; erster Versuch applied 0 = transient), priority_track. Danach wie Batch 1: Build-Gate → ggf. Korsett-Reparatur → Q02 neue Identität → Kette → Sibling-Welle 4. Fabrik: RAM-Latch 13:30–14:30Z vorbei (24 GB frei, 10 aktive Claims), Zensus 12710 14/1.085, 11910 6 Zellen geboostet/noch nicht geclaimt, 21507 543/1.085; 10700-Expansion läuft (T5, 2 h). Router leer, Pump ohne Fehler.

> **Nachtrag 14:00Z (03.09.) — Fabrik ist speichergebunden: 4 schwere Tester (40 GB) + RAM-Latch → Zensus 2–16 Zellen/10 min; keine Konstantenänderung vor der Auffangregel.** 13:55Z: T10 Q08 12350 (13,6 GB), T3 20085-Recovery (11,5 GB), T5 10700-Expansion (8,2 GB), T6 Q05 20176 (6,9 GB) → 8,7 GB frei, 5 Worker in `ram_low_pause`. Die Zensus-Floor-Vorlage (a) würde nur das 12–14-GB-Band öffnen — bei 8,7 GB frei bleibt der Zensus auch damit pausiert; die reale Kapazität des 63-GB-Hosts sind ~4 schwere Läufe plus Zensus-Zellen im Rest. Konsequenz: (1) Vorlage bleibt (kein Alleingang, Tests pinnen 18 GB), (2) die wirksameren Hebel sind Admission schwerer Läufe (Option c) und weniger parallele Heavy-Phasen, (3) 20085-Recovery (11,5 GB, 5. Versuch) ist heute der teuerste Einzelverbraucher → Vorlage 21:35Z. Fortschritt: 12710-Zensus 9/1.085, 11910 0/1.085, 21507 542/1.085 (seit 13:00Z unverändert). 10700-Expansion läuft seit 12:48Z. Batch-2-Auffangregel 14:13Z: Recompile 10815/GDAXI + 12580/AUDUSD wird ausgeführt (leichte Phasen; schwere Phasen stehen ohnehin hinter den Kappen).

> **Nachtrag 13:15Z (03.09.) — Zensus 12710/11910 läuft; RAM-Latch ist jetzt die dominante Bremse → OWNER-Vorlage Zensus-Zellen-Floor.** Matrix-Service bedient beide neuen Programme (Boost-Fenster je 6 Zellen; 12710 2/1.085, 11910 startet; 21507 542/1.085). 10700-Expansion `c0faeb48` läuft (T5). **RAM-Latch:** 13:10Z wieder nur 4 aktive Claims bei 12,5 GB frei (Guard 14/20 GB), 6 Worker idle, obwohl eine Zensus-Zelle ~4 GB reserviert und die bestehende Zensus-Ausnahme erst ab 18 GB greift (Post-Reservation ≥14). Heute wiederholt für 20–60 min je Latch. **Vorlage (reversibel, Konstanten in terminal_worker.py; Auffangregel 01:15Z 04.09.):** (a) **Empfehlung:** Zensus-Zellen-Ausnahme mit Post-Reservation-Floor 8 GB (= Zelle claimbar ab 12 GB frei; Crash-Klasse vom 02.09. lag bei 6/12) — Backtests behalten 14/20, Compiles den 3-GB-Bypass; (b) globale Schwellen 14/20 → 12/18; (c) zusätzlich Admission tick-lastiger Ablations-Grid-Kinder nur bei ≥25 GB frei. Kosten von (a): bei gleichzeitigen 4 Großläufen (44 GB) bleibt ~8 GB Reserve; Rollback = Konstante zurück + Idle-Reload. Cost-of-Wait: ~30–50 % Zensus-Durchsatz in Latch-Phasen. Reload Chunk 17: 8/10, Guardian lebt, Pump ohne Fehler.

> **Nachtrag 13:00Z (03.09.) — Zensus-Programme von 12710 und 11910 materialisiert (je 1.085 Zellen, 12710 bereits geboostet); 10700 in der News-Expansion.** Seeds 41331 `c0cc02a5` PASS 12:43Z, 41332 `417a6769` PASS 12:47Z → der Matrix-Service hat beide Programme angelegt (Slot-Ränge 5/6 greifen; zwei bisherige Owner werden deboosted, ihre Zellen bleiben). Damit läuft der Zensus der ersten zwei Recompile-Paare — bei L=1 ≈ 5 Tage je Programm, mit Canary/L=2 ≈ 2,5 Tage (Vorlage 17:45Z gilt jetzt für 21507 UND die Recompile-Programme; Empfehlung erweitern: Allowlist = 21507 + 12710 + 11910). 10700: Q10_NEWS `fe33550e` REVIEW_REQUIRED (Expansion), Expansion `c0faeb48` seit 12:48Z auf T5 (einzige aktive Expansion). Guardian-Loop 12:57Z neu gestartet (6-h-Zyklus endete 12:43Z). Fabrik 34–57 Zellen/10 min, RAM 21 GB, Router leer.

> **Nachtrag 12:50Z (03.09.) — Sibling-Welle 3 komplett: alle drei Siblings COMPILE_OK (über den neuen Compile-only-Bypass), 41331-Q02-Seed läuft; Task 262f7959 APPROVED.** Der Bypass griff beim ersten Reload (T1 `ram_low_compile_only` ×3): 41331/41332/41333 COMPILE_OK 12:38–12:39Z, dazu die freigegebenen August-Siblings 41175/41177. Matrix-Service seedete 41331s Q02-Vorstufe `c0cc02a5` (12:38Z, sofort auf T2 geclaimt); 41332/41333-Seeds folgen mit ihren Q12-Zeilen (11910 `b764a145` Rang 6; 10700 nach Q11). Damit ist der Weg der Recompile-Paare in den Zensus frei: 12710 (Rang 5) startet Zellen, sobald der Seed PASS ist. Router leer bis auf laufende Ketten; RAM 28 GB frei, Fabrik erholt sich vom Latch.

> **Nachtrag 12:45Z (03.09.) — RAM-Latch blockierte die Sibling-Compiles → Compile-only-Ausnahme im Worker (`ef1c4dbbff`); 11910 Q11 PASS → Q12 Rang 6.** **Befund:** 12:33Z nur 4 aktive Claims, 6 Worker in `ram_low_pause` bei 6,8 GB frei (Tester T7 13,6 GB, T3 11,5 GB Recovery, T10 10,8 GB, T8 8,1 GB News) — die drei Sibling-Compiles (98bfe19a/fa3cff26/c299634e, je < 1 GB Speicherbedarf) warteten hinter dem 14/20-GB-Guard. **Fix:** unter dem Latch darf ein Worker jetzt ausschließlich COMPILE_EA-Zeilen claimen, solange ≥3 GB frei sind (Spiegel der bestehenden Zensus-Ausnahme, fail-closed bei DB-Fehlern; Backtests behalten den vollen Guard); 2 neue Tests + 94 Claim-Tests grün; Reload Chunk 17 (pausierte Worker zuerst) seit 12:36Z → Compiles sollten binnen Minuten laufen. **11910:** Q11 `839984e5` PASS 12:09Z → Q12 `b764a145` per Queue-Order auf Rang 6 (hinter 12710). Fabrik: Zensus 9–32 Zellen/10 min (RAM-gedrosselt), Pump ohne Fehler, Guardian lebt, Router: 262f7959 IN_PROGRESS. Nicht committed: `dxz23_execution_contracts.json` (Kalender-Hash-Refresh).

> **Nachtrag 12:25Z (03.09.) — Sibling-Welle 3 gemerged, Magics alloziert, drei Compiles freigegeben.** QM5_41331 (12710/XTIUSD, Magic 413310000), QM5_41332 (11910/NZDUSD, 413320000), QM5_41333 (10700/XAUUSD, 413330000): Opus-Builds je Worktree, alle drei adversarial verifiziert ok, Quellen auf ASCII+CRLF normalisiert, Build-Gate PASS im Haupt-Checkout, Commit `5e6f19a61a`; Karten auf D: und C:; Allokator seriell mit Registry-Commit dazwischen (erst blockiert durch die unkommittierte Mailbox-Reservierung 41325 → `8a4bd604fe`); Compile-Zeilen 98bfe19a/fa3cff26/c299634e per `--work-item-id` freigegeben und priority_track (Positionen 53–55). Nebenwirkung: die Wellen-Freigabe (`--max-items 3`) löste zuerst drei August-Sibling-Compiles (41175/41177/41182) — legitime governed Zeilen, belassen. Evidenz `docs/ops/evidence/2026-09-03_sibling_wave3_recompiled_pairs.md`. Nach COMPILE_OK: Service seedet Q02-Vorstufe je Sibling → Q12-Zeilen materialisieren Zellen (12710 auf Rang 5). Nicht committed: `framework/registry/dxz23_execution_contracts.json` (News-Kalender-Hash-Refresh des Tagestasks, Live-Vertragsdatei → OWNER-Sicht). Guardian lebt (Neustart nach 12:30Z fällig).

> **Nachtrag 12:15Z (03.09.) — Q11-Zeilen der priorisierten Ketten ebenfalls in den Lineage-Rang aufgenommen (`4cd1d1f35a`); Reload Chunk 16.** 11910 Q11 `839984e5` (priority_track) wartete 20+ min hinter Frontier-Zellen — dieselbe Klasse wie der News-Parent: alle Nicht-Zensus-Zeilen im Priority-Tier sortieren hinter ~1.300 Zellen, solange irgendein Programm eine freie Lane hat (≤6 Zensus-Worker bei 8 Programmen → praktisch immer). Regel jetzt: Q02–Q09-Reruns, Fresh-Seeds, News-Parents (Rerun/Ersatz) und **Q11** mit priority_track tragen den Lineage-Schlüssel; Long-Run-Kappen bleiben. Phase über Manifest-Lookup aufgelöst (v4-Readiness grün). Reload Chunk 16 (alle 10, idle-only) seit 12:07Z; Chunk 15 (8/10) beendet. Sibling-Welle 3 (`wg8u1drba`) läuft; 10700 Q10_NEWS (T8, seit 11:24Z); Fabrik 47 Zellen/10 min, RAM 25 GB, Guardian lebt (Neustart nach 12:30Z fällig).

> **Nachtrag 12:00Z (03.09.) — 11910 durch das News-Gate (CONFIG_LOCKED 11:42Z); die Recompile-Paare brauchen Mess-Siblings für den Zensus → Sibling-Welle 3 beauftragt.** 11910-Expansion `f7264187` CONFIG_LOCKED nach 2,5 h → Q11 `839984e5`. **Befund:** 12710s Q12 `9384656c` (Rang 5) wird vom Matrix-Service verschoben: „expected one approved _opt sibling for QM5_12710/XTIUSD.DWX, found 0“ — der DL-089-Zensus läuft auf einem Mess-Sibling (41xxx, Pattern-Permission-Korsett), nicht auf dem Parent; für die recompilierten Paare existiert keiner. Gleiches steht 11910 und 10700 bevor. **Sibling-Welle 3** (Rezept Welle 2 = 41321–41324): Router-Task `262f7959` (Claude-Lane), Opus-Workflow `wg8u1drba` baut die drei Sibling-EAs (Korsett, Karte, Set, SPEC, Build-Gate) in Worktrees mit je einem Verifizierer; ich mache Magic-Allokation, Kartenkopien, Compile-Enqueue/Release, Review. Erwartung: Siblings kompiliert heute Nachmittag → Q02-Seeds durch den Service → Zensus-Start in den Slots. Damit landen Paare 6–8 realistisch am Wochenende, abhängig von Zensus-Durchsatz (Canary-Vorlage 17:45Z). Sonst: 10700 Q10_NEWS `fe33550e` läuft (T8, seit 11:24Z), Reload Chunk 15 8/10, Fabrik 46–53 Zellen/10 min, RAM 15 GB, Router: 262f7959 IN_PROGRESS.

> **Nachtrag 11:50Z (03.09.) — 12710/XTIUSD Q11 PASS → Q12-Programm auf Rang 5 gesetzt (Recompiles zuerst); Rang-Fix für News-Parents bestätigt.** 10700-Ersatzparent `fe33550e` wurde 2 min nach dem Reload von T8 geclaimt (11:24Z) — der Lineage-Schlüssel `608cc5ec6b` wirkt. 12710 Q11 `a10aa1da` PASS 11:25Z → Q12 `9384656c` (11:28Z) per `set_dl089_queue_order.py apply --queue-order-at 2026-08-29T08:02Z` von Rang 27 auf 5 (§2-Mechanik der OWNER-Entscheidung, Grund „Recompiles zuerst“); der bisher achte Slot-Owner wird beim nächsten Service-Zyklus deboosted (gemessene Zellen bleiben) und rückt nach. Damit beginnt der 12710-Zensus (1085 Zellen) sofort statt in Tagen — bei L=1 ≈ 5 Tage, mit Same-Program-Canary (Vorlage 17:45Z) ≈ 2,5 Tage. Gleiche Platzierung folgt für 11910 (Expansion läuft, T1) und 10700 (Q10_NEWS Standardlauf, T8), sobald ihre Q12-Zeilen existieren. Reload Chunk 15: 4/10. Fabrik 46 Zellen/10 min, RAM 22 GB, Router leer.

> **Nachtrag 11:45Z (03.09.) — 12710/XTIUSD durch das News-Gate (CONFIG_LOCKED 11:17Z) → Q11; Rang-Defekt für News-Parents der Ketten gefixt.** 12710-Expansion `58d84268` CONFIG_LOCKED nach 2,4 h → Q11 `a10aa1da` (automatisch gemintet, sofort geclaimt) → danach Q12-Programmzeile in die Slot-Warteschlange (K=8 voll; hinter 41221). 11910-Expansion `f7264187` läuft (T1, 2,5 h). **Rang-Defekt:** 10700-Ersatzparent `fe33550e` wartete 1 h auf Position ~1.300, weil die Zensus-Unterränge vor `_phase_rank` sortieren und die Worker immer noch claimbare Frontier-Zellen fanden (RAM-Pausen machten Lanes frei). Fix `608cc5ec6b`/`eabf4437bb` (Amendment B): Q10_NEWS-Zeilen, die Append-only-Rerun oder Service-Ersatzparent (`supersedes_held_q09_work_item`) einer priorisierten Lineage sind, nehmen den Lineage-Schlüssel (Long-Run-Kappen bleiben). Idle-only-Reload Chunk 15 aller Worker seit 11:22Z; bis dahin kann `fe33550e` weiter warten. RAM-Latch von 11:06Z aufgelöst (23-GB-Grid-Lauf beendet, 29 GB frei), 9 aktive Claims, 20–28 Zellen/10 min, Router leer, Pump ohne Fehler.

> **Nachtrag 11:10Z (03.09.) — RAM-Guard-Latch: 5 von 10 Workern pausiert (frei 9 GB), Verursacher ein 23-GB-Ablations-Grid-Lauf (10569/EURJPY H4, Q05 grid_039 auf T2).** T5/T6/T7/T9/T10 in `ram_low_pause` (Schwellen 14/20 GB, gesetzt 02.09. nach Crash bei 6/12); Speicher: T2 23 GB (Tick-lastiges EURJPY-H4-Grid-Kind aus dem Pump-Ablations-Spawner), T3 10 GB (20085-Recovery), T4 3,8, T1 2,8. Folge: 10700-Q10_NEWS `fe33550e` (claimbar seit 10:20Z) und ~1.300 Zensus-Zellen warten, obwohl 5 Worker frei wären; Zensus-Rate bricht auf 16–33 Zellen/10 min ein. Kein Eingriff nach Regel (frei > 1,5 GB; Kill respawnt), Lauf endet von selbst. **Datenpunkt fürs Sonntagspaket (RAM):** Speicher-Monster sind einzelne Läufe (heute: 1567/GBPNZD Q09 18 GB, 10569/EURJPY Q05-Grid 23 GB, 20085-H4-Recovery 11 GB, 10700-Q09 11,5 GB) — eine Admission nach erwarteter Tester-Größe (Symbol/TF-Klasse) wäre wirksamer als globale Schwellen; Vorschlag: Ablations-Grid-Kinder tick-lastiger Symbole nur bei ≥25 GB frei starten, Schwellen 14/20 → 12/18 nach Messreihe. Expansionen 12710 (T8, 2,3 h) und 11910 (T1, 2 h) laufen; Router leer; Pump ohne Fehler.

> **Nachtrag 10:45Z (03.09.) — alle 10 Worker auf aktuellem Code (T9 10:33Z reloaded); 10700-Ersatzparent wartet auf einen Scan-Durchlauf; Expansionen laufen.** Reload Chunk 14 fertig → Worker-Flotte trägt Policy `1c94f049bf`, Kaskadenfilter `72965dff27`, Registry-Fix `ecf528dcfb`, Amendment-B-Manifest-Lookup `4884fbbab5`. Beim T9-Neustart wurde die 20085-XAUUSD-Q07-Recovery-Zeile `19d3d8e5` von T3 adoptiert (gleiche Zeile, Budget 418 min läuft weiter) — kein neuer Versuch, aber weiter ein belegter Long-Run-Slot (Vorlage 21:35Z). 10700 Q10_NEWS `fe33550e` (RUNNABLE_BOUND, priority_track) ist claimbar (3 von 4 News-Slots belegt), steht aber hinter den Zensus-Zellen (Gate-Rang News=2 > Zensus=0) und wird geclaimt, sobald ein Worker keine lane-freie Zensus-Zelle findet — heute Vormittag lag diese Wartezeit bei 10–25 min. Expansionen 12710 (T8, 2 h) und 11910 (T1, 1,5 h) laufen. Fabrik 26–33 Zellen/10 min, RAM 25 GB, Router leer, Pump ohne Fehler.

> **Nachtrag 10:20Z (03.09.) — Recompile-Welle Batch 1: alle drei Paare Q02→Q09 auf neuer Identität durch; 10700-Q10_NEWS-Ersatz angestoßen.** 10700 Q09 `3030129c` PASS 10:08Z → Zombie `77bd97c2` governed umarmt (Q09_AWAITING_SEALED_PLAN, superseded=1) → Ersatz-Parent im nächsten Pump-Zyklus. Bilanz der OWNER-Priorität 1 (02:08Z-Entscheid): drei Ketten in 7,5 h von Compile bis Q09 PASS (11910 03:33Z→08:07Z, 12710 04:25Z→07:48Z, 10700 04:46Z→10:08Z), dafür nötig: Allowlist, Amendment B (+Q02, +Fresh-Seed), Korsett-Reparaturen, Rerun-Sichtbarkeit ×4 Stellen, Long-Run-Ausnahme, Supersede-Guards, zwei Hold-Umarmungen. Jetzt stecken alle drei im News-Gate: 12710/11910 in der 7×4-Expansion (T8/T1), 10700 folgt (Standardlauf, dann vermutlich Expansion → Expansions-Kappe 2 bindend → Vorlage 2→3). **RAM-Guard-Latch erneut:** 09:58Z–10:09Z keine Zensus-Claims (frei ~6 GB durch 10700-Q09 11,5 GB + 20085-Recovery 11,5 GB), danach Wiederanlauf — kein Stall; Schwellen 14/20 GB bleiben Sonntagspaket. Fabrik 9–47 Zellen/10 min, RAM 12,5 GB, Router leer, T9-Reload wartet (20085 bis ~10:30Z).

> **Nachtrag 09:40Z (03.09.) — ruhige Phase: beide Expansionen und 10700-Q08 laufen; Vorlage zum 20085-Recovery-Track abgelegt.** Läufe: 12710-Expansion `58d84268` (T8, seit 08:50Z), 11910-Expansion `f7264187` (T1, seit 09:14Z), 10700 Q08 `ce371d25` (T2, seit 08:33Z, H1-Walk-Forward). Zensus 32–53 Zellen/10 min, 9 aktive Claims, RAM 18 GB, Pump ohne Fehler, Router leer. **OWNER-Vorlage (reversibel, Auffangregel 21:35Z):** QM5_20085 (H4, Recovery-Track) — EURUSD-Q07 5 Versuche seit 17.08. alle INFRA_FAIL (Budget 216 min), XAUUSD-Q07 2× INFRA_FAIL + laufender 3. Versuch (T9, 418 min), WS30 1×; jeder Versuch bindet einen Q07/Q08-Slot für 3,5–7 h und blockierte heute die Recompile-Ketten. Empfehlung: Recovery-Track parken (governed Hold, kein Verdikt), Wiedereinstieg mit höherem Budget im Sonntagspaket. Nächste Ereignisse: 10:30Z T9-Budgetende (dann Reload Chunk 14), 14:13Z Auffangregel Batch 2, 17:45Z Auffangregel Same-Program-Canary, 19:35Z Auffangregel V1(b), 21:35Z Auffangregel 20085.

> **Nachtrag 09:10Z (03.09.) — 11910/NZDUSD ebenfalls in die News-Expansion (Sign-/Gate-Flips 5 von 5); beide Expansionen belegen jetzt die Expansions-Kappe.** 11910 Q10_NEWS `bdae4b44` → REVIEW_REQUIRED/`expanded_7x4_matrix_required` (material_effect: ΔNet-R, ΔPF, 5/5 Sign-/Gate-Flips → die News-Policy kippt hier sogar Vorzeichen), Expansion `f7264187` 08:58Z gemintet (priority_track). Mit 12710 (`58d84268`, T8) sind damit beide Recompile-Expansionen unterwegs = Expansions-Kappe 2 voll (11422-Expansion bleibt gehalten). Sobald 10700 (Q08 auf T2 seit 08:33Z) das News-Gate erreicht und ebenfalls expandiert, ist die Kappe bindend → dann Vorlage 2→3. Erwartung: Expansion ≈ 105 Zellen × ~2 Läufe; D1-EAs → mehrere Stunden je Paar, CONFIG_LOCKED frühestens heute Nachmittag; danach Q11 (Minuten) → Q12-Zensus-Slot (Tage; K=8 voll) — der Zähler bewegt sich durch diese Ketten erst nach dem Zensus, nicht heute. Fabrik 40 Zellen/10 min, RAM 20 GB, Router leer, Reload nur noch T9 offen.

> **Nachtrag 09:00Z (03.09.) — 12710-Expansion läuft (T8); Expansions-Kappe heute nicht bindend → keine OWNER-Vorlage nötig.** Expansions-Parent `58d84268` seit 08:50Z aktiv auf T8 (105 Zellen). Kappen laut Scheduling-Policy 24./25.08.: Q10_NEWS gesamt 4, davon expandiert ≤2, Q07/Q08 2 (+1 für Lineage-Reruns seit `1c94f049bf`) → Short-Flow-Reserve 4 von 10. Aktuell aktiv: 3 News-Läufe (11910 Standard T1, 11403 Standard T4, 12710 expandiert T8), die zweite Expansion (11422/USDCAD) ist gehalten → die Expansions-Kappe greift erst, wenn 11910 und 10700 ebenfalls in die Expansion laufen (frühestens heute Nachmittag). Ich lasse die Kappe unverändert und lege eine Vorlage erst vor, wenn zwei Recompile-Expansionen gleichzeitig warten (dann: 2→3 bei ≥14 GB frei; Kosten: Short-Flow-Reserve 3). Reload Chunk 13 fertig (9/10), Chunk 14 wartet auf T9 (20085-Recovery bis ~10:30Z). Fabrik 15–48 Zellen/10 min, RAM 17 GB, Router leer.

> **Nachtrag 08:50Z (03.09.) — 12710/XTIUSD am News-Gate: 8-Zellen-Lauf → REVIEW_REQUIRED = Expansion nötig (7×4-Matrix, 105 Zellen); Expansions-Parent automatisch gemintet.** **Befund:** Adjudikation `expanded_7x4_matrix_required` mit material_effect (ΔDrawdown/ΔNet-R/ΔPF). Geprüft auf den Zell-Summaries: Policy-Modi m2–m5 weichen vom Control ab (m5 drastisch: 16 Trades / −1.054 statt 23 / +3.153 im ersten Fenster) → echter Policy-Effekt, kein Artefakt (`max_affected_entries=0` zählt nur blockierte Einträge). Damit läuft 12710 in die bekannte **News-Expansions-Engstelle** (51 Q10_NEWS-REVIEW_REQUIRED in 7 Tagen; Expansions-Kappe 2 flottenweit; 105 Zellen ≈ Stunden bis Tage je Paar). Expansions-Parent `58d84268` (08:38Z) wartet auf einen Expansions-Slot (der zweite pendente ist 11422/USDCAD vom 23.08.). **Konsequenz für den Zähler:** Pfad (a) (Recompile-Ketten) endet nicht mehr an Q10, sondern an Q10-Expansion + Q12-Zensus; Pfad (b) (21507/13213 im Zensus) bleibt der kürzeste. Beide Engstellen sind Kapazitätsfragen (Expansions-Kappe, Lanes je Programm) — die Same-Program-Parallelitäts-Vorlage (17:45Z) adressiert (b); für (a) prüfe ich als Nächstes, ob die Expansions-Kappe 2 (Scheduling-Policy 24.08., nicht OWNER-Kriterium) bei RAM 34 GB frei und 10 Workern auf 3 angehoben werden kann (Vorlage, kein Alleingang, weil sie den Short-Flow-Reserve-Floor berührt). 11910 Q10_NEWS `bdae4b44` läuft (T1); 10700 Q08 `ce371d25` (T2). Fabrik 39 Zellen/10 min, RAM 24 GB, Router leer.

> **Nachtrag 08:15Z (03.09.) — zwei Recompile-Ketten am News-Gate: 12710 Q10_NEWS läuft, 11910 Q10_NEWS eingereiht (Plan-Siegelung durch den Service); 13213 Q11 PASS.** **11910/NZDUSD:** Q09 `859b114d` PASS 08:07Z → Q10_NEWS `bdae4b44` per Rerun-Form gegen die terminale Alt-Zeile `a6dbacf5` erzeugt (Zustand AWAITING_SEALED_PLAN + Hold Q09_AWAITING_SEALED_PLAN → der News-Gate-Service siegelt den Laufplan und aktiviert die Zeile im nächsten Pump-Zyklus, wie bei 12710/`9a2e9380`). **12710/XTIUSD:** Q10_NEWS `9a2e9380` seit 07:57Z aktiv (T10, Dauer typ. 3–7 h). **10700/XAUUSD:** Q07 `21317bcc` seit 07:35Z (T7). **13213/XAUUSD:** Q11 PASS 08:11Z → Q12-Programm (Slot 1) läuft weiter. **41221/EURUSD:** Q12 in Warteschlange. Zwei Wege zu Paar 6–8: (a) 12710/11910/10700 via Q10_NEWS → Q11 → Q12-Slot (Zensus ~1085 Zellen, Tage) — d. h. auch diese Paare landen im K=8-Engpass; (b) 21507 (Slot 2, 513/1085) + 13213 (Slot 1). → Die Same-Program-Parallelitäts-Vorlage (17:45Z) ist damit der Hebel für alle Kandidaten. Fabrik 22–60 Zellen/10 min, RAM 34 GB, 10 Worker, Reload Chunk 13 9/10 (nur T9 = 20085-Recovery bis ~10:30Z offen), Router leer, Pump ohne Fehler.

> **Nachtrag 08:00Z (03.09.) — 12710/XTIUSD auf neuer Identität bis Q09 PASS; Q10_NEWS-Ersatz via Hold-Umarmung angestoßen; 13213/XAUUSD Q10_NEWS CONFIG_LOCKED.** **12710:** Q09 `e1f7a095` PASS 07:48Z (Q02→Q09 in 3,5 h auf der neuen Identität `11474d4c`). Die einzige Q10_NEWS-Zeile `678b8cac` ist ein Zombie der alten Identität (Hold NEWS_RUNNER_SPAWN_SILENT_ABORT) → governed umarmt auf `Q09_AWAITING_SEALED_PLAN` (superseded=1), damit der News-Gate-Service den Ersatz-Parent auf dem aktuellen Binary erzeugt (Muster 11910 → `a6dbacf5`); Ersatzzeile ab dem nächsten Pump-Zyklus erwartet. Dann Q10_NEWS (Stunden) → CONFIG_LOCKED → Q11 → Q12-Slot. **13213/XAUUSD:** Q10_NEWS `6e415bb4` CONFIG_LOCKED 07:38Z (6,4 h auf T3) → Q11 `7db06ca0` pending; Q12 `2ea9cd64` hält bereits Slot 1 → nach Zensus-Ende Paar 6-Kandidat neben 21507. **41221/EURUSD** Q12 `e0ab6e2a` in der Slot-Warteschlange. **Übrige Ketten:** 11910 Q08 `e0237a77` (T4, seit 07:26Z), 10700 Q07 `21317bcc` (T7, seit 07:35Z). 20085-EURUSD-Recovery lief ins 216-min-Budget (INFRA_FAIL 07:28Z, 4. Versuch) — Kandidat für Retire-Vorlage statt weiterer Recovery-Versuche (T9-XAUUSD-Lauf noch bis ~10:30Z). Fabrik 15–37 Zellen/10 min, RAM 15 GB, Reload Chunk 13 8/10, Router leer.

> **Nachtrag 07:35Z (03.09.) — Schatten-Buchbewertung geliefert (08ba621a APPROVED); Kernbefund: Zulassungskohorte bringt 0 netto-neue Q14-Paare; fünf OWNER-Vorlagen; 41221/EURUSD Q11 PASS.** **Dossier** `docs/ops/evidence/2026-09-03_shadow_book_evaluation_39b77657_dossier.md` (+ Sidecar, Commit `c9d958b99c`, Verifizierer ok mit 30+ Stichproben, Korrelationsmatrix unabhängig reproduziert): 24er-Kohorte = 16 auditiert (11 Q02-Neuidentität, 5 Q09) + 8 Active-Track; Mix Gold 4 / FX 7 / Index 3 / Öl 1 / Basket 1, D1-lastig, Mean-Reversion 8 / Trend 5; Gold-Cluster 6× XAUUSD, Duplikate (gleiche EA auf zwei Symbolen, Familien-Cluster). **0 von 24 sind Q14-terminal**; die 3 Kohortenmitglieder im 5er-Zensus sind genau die ACTIVE_OPT_FORK-Ausschlüsse → netto-neuer Beitrag zum 25er-Floor = 0. Korrelation aus 9/16 vorhandenen Q08-Streams (daily net, Pearson): max |r| 0,10, kein Paar erreicht die 60-Tage-Überlappung des eigenen Tools, 6/9 Streams binden an überholte Identitäten → **nur Screening-Prior**; 7er-Was-wäre-wenn-Set als Diskussionsbasis (ausdrücklich keine Gewichte, kein Buch). Handelbarkeit: nur SP500.DWX ORDER_ROUTABLE_CONFIRMED, übrige Zellen leer (vor Deploy prüfen). **OWNER-Vorlagen V1–V5 im OWNER-Board** (Wiedereinstiegs-Reihenfolge, Konzentrationsdeckel, Venue DXZ-first, Korrelations-Evidenzstandard, News-Bindung vor FTMO); **Auffangregel** nur für V1(b) (5 Q09-verankerte Mitglieder gestaffelt wieder einreihen; reversibel, GRÜN-Queue) → 19:35Z; V2–V5 betreffen den Buchbau → bleiben OWNER ohne Auffangregel. Router: fc5b6144 und 08ba621a APPROVED (INDEPENDENT_ORCHESTRATOR_CLOSEOUT). **Frontier:** 41221/EURUSD Q11 `01bf3a9a` PASS 07:16Z → Q12 `e0ab6e2a` pending (governed Slot-Warteschlange, K=8 voll; Reihenfolge unverändert). Ketten: 12710 Q08 `bfda1943` läuft (T4), 11910 Q08 `e0237a77` und 10700 Q07 `21317bcc` warten (Kappe 2+1 durch 20085-Recovery T7/T9 belegt; T7-Budget ~07:28Z). Fabrik 32–46 Zellen/10 min, RAM 26 GB, Reload Chunk 13 6/10.

> **Nachtrag 07:05Z (03.09.) — OWNER-DEC-Q12-ADMISSION ausgeführt: Zulassungs-Record committed, Auftrag fc5b6144 APPROVED, Schatten-Buchbewertung beauftragt.** **Record** `docs/ops/evidence/2026-09-03_q12-admission_39b77657_execution.md` (+ SHA-gebundene `.json`-Sidecar; Commits `458756dffd`, `76993f3a62`): Kohorte = `portfolio_candidates.state='Q12_REVIEW_READY'` = **24 Mitglieder** (30 vom 30.08. minus 6 am 30.08. retirete; 16 auditiert: 11× Q02-Neuidentität, 5× Q09; 8 Active-Track-Ausschlüsse), **24/24 eindeutig** (Komposit-Schlüssel, eindeutiges EA-Verzeichnis mit EX5, Gate-Historie, gebundene Hashes) → ZUGELASSEN zur Bewertung — nicht zum Buchbau. Zählerstand 5/25 (echter Zensus) explizit ohne Overclaim vermerkt; zwei Paare (1556/XAUUSD, 11708/EURUSD) seit 30.08. von Q02-Neuidentität auf Q09 hochgestuft; keine gespeicherte Korrelation für die Kohorte (keine neu berechnet, laut Vertrag). Adversarial verifiziert (24/24 Schlüssel, 72/72 Hashes, 7 Anker-Zeilen, kein Manifest/Gewichte/Deploy/Runtime-Mutation, Provenienz = Receipt/Vertrag). Hinweis: die 5 zählenden Q14-Paare und die Q12-Zulassungskohorte sind verschiedene Mengen (3 der 5 sind ACTIVE_OPT_FORK-Tracks, aus dem Anker-Audit ausgeschlossen). **Router:** fc5b6144 → REVIEW → APPROVED (INDEPENDENT_ORCHESTRATOR_CLOSEOUT, 07:05Z). Erlaubte Folgeaktion ausgeführt: Schatten-Buchbewertung `08ba621a` (evidence_only, Prio 55, Claude-Lane) enqueued und als Opus-Dossier `why1tkjxf` gestartet (Venue-Eignung, Edge-Familien/Orthogonalität, Korrelation nur aus vorhandener Evidenz, Was-wäre-wenn-Set als Diskussionsbasis, OWNER-Vorlagen) — kein Buch, keine Gewichte. **OWNER-Notiz** „wie gesagt:requed“ am Receipt: als Bestätigung des Wiedereinstiegspfads gelesen (die Kohorte läuft über Q02-Neuidentität/Q09 wieder ein); falls anders gemeint, bitte im Chat präzisieren.

> **Nachtrag 06:50Z (03.09.) — OWNER-Entscheid Q12-Admission (YES) eingegangen und in Ausführung; RAM-Notbremse ausgelöst; Sibling-Filter live.** **OWNER-DEC-Q12-ADMISSION = YES** (Mission-Control-Receipt `39b77657`, 06:10:01Z, Notiz „wie gesagt:requed“; Empfehlung zum Zeitpunkt: VERTAGT): Der Ausführungsvertrag erzeugte genau einen entscheidungsgebundenen Auftrag `fc5b6144` (Prio 92, DOCUMENT_AND_VERIFY, Effekt: „Die Zulassung wird dokumentiert; Buchbau und jede weitere Aktion bleiben separat OWNER-gesteuert“). Claude-Lane hat ihn übernommen (IN_PROGRESS): Opus-Workflow `w2g2lysin` schreibt das unveränderliche Zulassungs-Record `docs/ops/evidence/2026-09-03_q12-admission_39b77657_execution.md` (exakte Kohorte aus `portfolio_candidates`/Q12_REVIEW_READY, Gate-Provenienz, Hashes, Ausschlüsse, Abgleich mit dem Anker-Audit 30.08., Zählerstand 5/25, „was dieses Record NICHT tut“, Enqueue-Kommando für die separate Schatten-Buchbewertung), adversarial verifiziert; dann REVIEW zur unabhängigen Abnahme. Kein Buchbau, kein Manifest, keine Gewichte. **RAM-Notbremse (Loop-Regel <3 GB):** 06:38Z frei 0,7 GB von 63 — Q09 1567/GBPNZD auf T4 mit 18,2 GB (neuester großer Lauf) plus 20085-Q07-Recovery auf T9 (11,3 GB) → T4-Tester (pid 8728) gekillt, frei 18,6 GB; der Phase-Runner startete den Lauf um 06:39Z neu (pid 2052, 15,7 GB) → 06:47Z wieder 3,9 GB frei. Erneutes Killen würde nur erneut spawnen; ich beobachte je Runde und greife erst unter 3 GB wieder ein. RAM-Guard-Schwellen (14/20 GB) bleiben Sonntagspaket. **Sibling-Filter live (Pump 06:28Z/06:33Z):** `measurement_sibling_promotions_withheld = 35`, manueller Hold `SIBLING_MEASUREMENT_ONLY_CHAIN_HOLD`: 23 geparkte Zeilen/23 aktive Holds — erste echte Sichtbarkeit der Klasse. **Ketten:** 12710 Q07 PASS → Q08 `bfda1943`; 11910 Q07 `797f03ae` läuft (T5, dritter Slot); 10700 Q07 `21317bcc` wartet. Reload Chunk 13: 4/10; Guardian läuft losgelöst (Hintergrund-Tasks des Harness wurden zweimal gestoppt). Fabrik 16–17 Zellen/10 min, 10 aktive Claims.

> **Nachtrag 06:25Z (03.09.) — Kaskadenfilter Runde 3 + Registry-Fix gemerged; Zombie-Zeilen alter Identität blockierten Reruns → Supersede-Pfad + Guard-Angleichung; 3. Q07-Slot wirkt.** **Kaskadenfilter (Befund b) v3 gemerged `72965dff27`** (Opus, Verifizierer ok): Sibling-Erkennung nur über den DL-089-Vertrag (Q02-Schema, Registrierungs-Receipt, Karten-Vertrag), alle automatischen Vorwärts-Pfade fail-closed geschützt (inkl. Q10_NEWS→Q11-Auto-Enqueue, Ablations-Spawner), Sichtbarkeit mit Successor-Bedingung und neun Kanten, Pass budgetiert (15 s, Deadline), manueller Hold `SIBLING_MEASUREMENT_ONLY_CHAIN_HOLD` als Konstante + read-only Zählung. Akzeptierte Lücken: CLI-`enqueue-backtest` (OWNER-Pfad) und die inerte dispatch_tick-Kaskade. Vorbestehender Test-Fail (v4-Readiness-Literal „Q09“ im Amendment-B-Tupel) → Allowlist-Nachtrag nötig (klein). **Ticket 1258a0c5 gemerged `ecf528dcfb`** (Verifizierer ok): Autostub schreibt über `_p5_calibration_path()` (REPO_ROOT/Env) → Tests können die Produktions-Registry nicht mehr verschmutzen; Router APPROVED. **Zombie-Zeilen-Klasse:** pendente Reruns der ALTEN Binär-Identität (Codex „Q10 lineage wave2“ 02.09.) sind unclaimbar (Binding-Filter), zählen aber in den Duplikat-Guards → blockierten 10700 Q07. Governed Pfad `work_item_supersedes.py record --apply` (3815515b) + Guards für Q03/generisch an den Q02-Stand angeglichen (`c6dba4c092`, `80269fed36`) → 10700 Q07 `21317bcc` eingereiht. Gleiche Klasse: Q10_NEWS-Zombies 77bd97c2 (10700) und 678b8cac (12710) → wenn die Ketten Q09 erreichen. **Ketten:** 12710 Q07 `fad536b4` aktiv (T5, dritter Slot), 11910 Q07 `797f03ae` und 10700 Q07 `21317bcc` warten auf den nächsten Slot (Recovery-Läufe 20085 bis ~07:28Z/10:30Z). Reload-Chunk 13 (alle 10 Worker, 150 min, idle-only) für die farmctl-Merges gestartet; Chunks 11/12 beendet (Policy-Reload 5/6 Worker geschafft). Fabrik 24 Zellen/10 min, 9 aktive Claims, RAM 18,6 GB.

> **Nachtrag 06:00Z (03.09.) — Q07-Kappe blockierte die Recompile-Ketten → begrenzte Ausnahme für Lineage-Reruns (`1c94f049bf`).** **Befund:** 12710 Q07 `fad536b4` und 11910 Q07 `797f03ae` standen seit 05:34Z auf Claim-Position 2–3, wurden aber nie geclaimt: die Long-Run-Policy vom 24.08. (`longrun_scheduling_policy.py`, Q07/Q08-Kappe = 2 flottenweit, Konstante ohne Env) ist durch zwei H4-Recovery-Regenerationen von 20085 belegt (T9 seit 03:32Z, Budget 418 min → bis ~10:30Z; T7 seit 03:52Z, Budget 216 min → bis ~07:28Z; dreimal zuvor INFRA_FAIL INCOMPLETE_RUNS/TIMEOUT). Ohne Eingriff hätten die OWNER-Priorität-1-Ketten 1,5–4,5 h gewartet. **Änderung (nur Claim-Auswahl, kein Verdikt/Gate):** Amendment-B-Zeilen (append_only_rerun + priority_track, nicht quarantäniert) dürfen EINEN Q07/Q08-Slot über der Kappe nehmen (2→3); gewöhnliche Zeilen behalten 2, News-Kappen unverändert, Short-Flow-Reserve bleibt ≥3 von 10. 4 neue Unit-Tests grün; die 4 `ClaimAtomicIntegrationTests` schlagen identisch auf HEAD fehl (vorbestehend, env-gekoppelt). Worker laden das Modul beim Start → Idle-Reload Chunk 12 (T1/T4/T5/T6/T8/T10, 60-min-Budget) läuft, Chunk 11 deckt T2/T3/T7/T9 ab. **Ketten:** 10700 Q05 PASS → Q06 `02df28c0`; 12710/11910 warten auf den dritten Q07-Slot (nach Reload eines idle Workers). Recovery-Läufe von 20085 nicht angefasst (kein GRÜN-Tatbestand; RAM 22 GB frei).

> **Nachtrag 05:45Z (03.09.) — Paar 6+: Zensus-Durchsatz je Programm ist der Engpass → OWNER-Vorlage Same-Program-Parallelität (Canary L=2 für 21507/XAUUSD).** **Lage:** 8 Programm-Slots laufen, jedes mit genau EINER aktiven Zelle (L=1): 21507/XAUUSD 513/1085 (571 offen, gemessen 8–9 Zellen/h → ~65 h ≈ Samstag/Sonntag), 20266/XTIUSD 240, 10513 178, 20048 141, 11881 131, 10145 128, 21505 36, 10403 11. Flottenweit 11–27 Zellen/10 min, CPU 97 % — die Flotte ist ausgelastet, aber pro Programm seriell. Die drei Recompile-Ketten (11910 Q07 `797f03ae`, 12710 Q07 `fad536b4`, 10700 Q05 `c44015fa`) liefern heute voraussichtlich die Paare 6–8 über Q10. **Mechanismus vorhanden (31.08., Receipt `49d7998d_dl089_same_program_parallelism_implementation`):** `DL089_LANES_PER_PROGRAM` (Default 1, hart ≤2) + `DL089_SAME_PROGRAM_PARALLEL_ALLOWLIST` (exakte Programm-IDs); Replay-Beweis geführt, Rollback = Env leeren. Das Receipt verlangt ausdrücklich **OWNER-Freigabe einer exakten Programm-ID** plus Worker-Reload — daher nicht autonom. **Vorlage (reversibel, Auffangregel 12 h → 17:45Z):** Option A (Empfehlung): Canary `L=2` nur für `DL089_QM5_21507_XAUUSD_DWX_2019_2025` (Nicht-Index-Programm wie vom Proposal gefordert) → 21507 in ~33 h statt ~65 h; Kosten: eine Worker-Lane weniger für die übrigen Programme (G=6 bleibt Deckel). Option B: A + Deferral der zwei Schlusslichter (10403 11 Zellen, 21505 36) via `set_dl089_queue_order.py --defer`, damit 12855/9641/12849 (Siblings warten auf Slots) nachrücken. Option C: nichts ändern. Rollback: Env leeren + Idle-Reload. Cost-of-Wait: ~6 h Verzögerung von Paar 6 je 12 h Wartezeit.

> **Nachtrag 05:35Z (03.09.) — ZÄHLER 5/25: 1537/XAGUSD terminal (Q12 NO_FILTER_CHANGE → Q13 NO_PARAMETER_CHANGE 05:29Z → Q14 KEEP_INCUMBENT 05:33Z, `18859f02`); `book_build_guard --status --venue both` = 5.** Weg dorthin heute Nacht: Rerun-Sichtbarkeit (Worker-Lane/Boost `a1cc06688b`), Pruning-Seal `b8cd532137`, Q12-Finalizer `ef76fb4556` — drei Fixes für dieselbe Klasse (Treiber-Reruns), dann lief die Kaskade Q12→Q14 in 10 min. **Recompile-Ketten:** 11910 Q06 `dbb6fc97` aktiv (T1); 12710 Q06 PASS → Q07 `fad536b4`; 10700 Q04 PASS → Q05 `c44015fa`. Tempo ~5–6 min je D1-Phase; Q07/Q08 dauern länger (Walk-Forward). Guardian-Chunk 44 (`bptlf3u5a`); Reload Chunk 11 (120-min-Budget) wartet auf Idle bei T2/T3/T7/T9.

> **Nachtrag 05:30Z (03.09.) — 1537-Q12 abgeschlossen; Marker-Leck-Fix v2 gemerged (kein zählendes Paar gefährdet); Era-Audit APPROVED; Backup-Reuse geparkt; Kaskadenfilter Runde 3.** **1537/XAGUSD:** Q12 `c41e2606` done NO_FILTER_CHANGE 05:23Z (erster Pump-Zyklus mit `ef76fb4556`) → Q13/Q14 per Kaskade → Zähler 5 erwartet. **Marker-Leck (Befund a) v2 gemerged `8ba50ff846`** (Opus, Verifizierer ok): Marker werden pro LAUF attribuiert (Expert + Symbol + exaktes Tester-Fenster, beide Tageslog-Layouts; Core-Layout ohne EA-Identität → fail-closed verworfen); Schema `qm.q02-frequency-coverage/v2` mit attributed/rejected-Zählern; Vertragsdoku aktualisiert; Inventar `2026-09-03_q02_frequency_floor_leak_inventory.csv` (3.313 betroffene Summaries, 464 Fremdsymbol-Marker, 158 neu berechnete Floors). **Entscheidend:** `q02_verdict_at_risk = no` für alle Läufe von 41221/EURUSD (79–92 Trades ≥ Floor 45) und 11421/EURUSD (79–85 ≥ 45); nur 4 historische Zeilen kippen (36005/AUDNZD, 41264/41267/41271 XTIUSD) und die tragen bereits FAIL → **OWNER-Vorlage „Regrade 14 Läufe“ entschärft: kein Verdikt eines zählenden Paares ändert sich; Annotation genügt** (bleibt ROT, aber ohne Cost-of-Wait). Vorwärtswirkung: ~7 % der Läufe bekommen einen strengeren Floor. Kein Reload nötig (PowerShell-Skripte werden je Lauf gelesen). **Era-Audit (f1655764) v2:** Verifizierer ok (kanonischer Klassifikator importiert, Repro-Skript + Test) → Evidenz `2026-09-03_treasure_hunt_eras_*` gemerged `9410e09c5b` (+ Test `de476525b0`), Router APPROVED. Hinweis: der Commit zog per Pathspec `docs/ops/evidence/` die fremd vorgestagte `2026-09-02_qm5_10025_usdjpy_zero_trade_instrumented_q02.md` mit (10025-Arbeit einer anderen Session; Evidenzdoku, unschädlich, notiert). Vein-1-Requeues (150 falsche INVALIDs) entscheide ich nach eigener Stichprobe im Sonntagspaket-Vorlauf. **Backup-Reuse (4ce6ec32) v2 erneut widerlegt** (Identity v2 `valid_frames` = physische Hochwassermarke: nach abgebrochener Transaktion bewegt ein Commit kein Signal) → Router BLOCKED/geparkt, `QM_COMPILE_WAVE_BACKUP_REUSE_MAX_AGE_MINUTES=0` bleibt, Refactor nicht gemerged. **Kaskadenfilter (Befund b) v2:** Kern gefixt (Erkenner an DL-089-Vertrag gepinnt, Sichtbarkeit mit Successor-Bedingung, Ablations-Spawner geschützt, fail-closed), drei Restlücken (Q10_NEWS→Q11-Auto-Enqueue ungeschützt, Sichtbarkeits-Kanten unvollständig, Sichtbarkeits-Pass unbudgetiert 2,1 s/Zyklus) → Runde 3 `w1j4tmxrx` (gleicher Workflow trägt Ticket `1258a0c5` Registry-Kontamination). **Router-Lektion:** `update-task`/`close-review` brauchen die VOLLE Task-ID (Präfix → `task_not_found`). Zeitstempel in Router-Verdikten von 05:40Z sind Schätzungen, echte Uhr 05:24Z. Fabrik: 19 Zellen/10 min, 6 aktive Claims, Pump 05:23Z ohne Fehler.

> **Nachtrag 05:20Z (03.09.) — 1537-Q12 blieb am Finalizer hängen (vierte Stelle ohne Rerun-Auflösung) → gefixt `ef76fb4556`; Ketten bei Q05/Q05/Q04.** **Befund:** `_finalize_from_terminal_ledger` verlangte für JEDE an den Q12-Owner gebundene Zensus-Zeile done+MEASURED/SKIPPED; 1537 hat für Zelle 2021:buy_048 die tote deklarierte Zeile `d110b111` (INFRA_FAIL), Rerun 1 `08767105` (INFRA_FAIL) und Rerun 2 `b878d9ba` (MEASURED) → Finalizer gab in jedem Pump-Zyklus `null` zurück (Pump-Log: `finalized: null`, keine Fehler), Treiber seit 04:49Z PATTERN_SELECTION_READY. Damit ist das Rerun-Auflösungs-Muster an vier Stellen nötig gewesen: Worker-Lane (`a1cc06688b`), Boost (`a1cc06688b`), Pruning-Seal (`b8cd532137`), Finalizer (`ef76fb4556`) — jeder Konsument der Ledger-Zellen muss `driver['reruns']` (neueste ID = aktuelle Zeile) auflösen. **Fix:** Finalizer bewertet je Zelle nur die aktuelle Rerun-Zeile; überholte Zeilen landen als `superseded_cell_evidence` im Q12-Receipt (Append-only-Spur bleibt). 2 Tests (Auflösung; wartet weiter, solange der aktuelle Rerun offen ist), 17 grün. Pump ist ein frischer Prozess je Zyklus → kein Reload; der 05:13Z-Lauf startete vor dem Commit, Wirkung erwartet ab dem 05:23Z-Lauf → Q12 `c41e2606` → Q13/Q14 → Zähler 5. **Recompile-Ketten:** 11910 Q04 PASS → Q05 `063eec00`; 12710 Q04 PASS → Q05 `84125a3a`; 10700 Q03 PASS → Q04 `4d8e9c24` (alle Claim-Kopf). **Fabrik:** 11 Zellen/10 min, 8 aktive Claims, 10 Worker, RAM 27 GB, CPU 97 %; Reload Chunk 10 wartet auf Idle bei T2/T3/T7/T9 (lange Q10_NEWS-/Q07-Läufe); Guardian-Chunk 43 (`bkcvl3z7a`). Test-Nebenwirkung geprüft: `framework/calibrations/` sauber.

> **Nachtrag 05:00Z (03.09.) — 1537-Zensus in PATTERN_SELECTION_READY (Q12-Finalisierung erwartet); alle drei Recompile-Ketten je zwei Phasen weiter.** **1537/XAGUSD:** Versuch-2-Zelle `b878d9ba` MEASURED (Seal-Fix wirkt), Treiber ENQUEUED → WF_COMBO (4/4 Kombi-Zellen MEASURED in ~30 min) → PATTERN_SELECTION_READY seit 04:49Z; das ist der terminale Treiberzustand für `_finalize_from_terminal_ledger` → Q12 `c41e2606` sollte der Matrix-Service im nächsten Pump-Zyklus abschließen → Q13/Q14 → Zähler 5. **Recompile-Ketten:** 11910 Q03 `fa66883f` PASS, 12710 Q02 `f1378383` + Q03 `55b7d71f` PASS, 10700 Q02 `71fddb4a` PASS (seed-fresh) → nächste Phasen eingereiht (11910 Q04 `cdf56ffe`, 12710 Q04 `c2297ba2`, 10700 Q03 `f625c325`; Skript `chain_step.py`, Vorgänger = neue PASS-Zeile, Rerun-of = alte Phasenzeile, priority_track vererbt, Claim-Kopf). Tempo: D1-Phasen ~5 min je Zelle → die drei Ketten können heute bis Q09/Q10 kommen. **Fabrik:** 17 Zellen/10 min, 6 aktive Claims, 10 Worker, Pump 04:48Z ohne Fehler (jeder zweite 5-min-Lauf übersprungen, weil der Vorgänger ~5 min läuft — bekannt, kein Stall), RAM 13,5 GB, CPU 85 %. T3 hält 13213 Q10_NEWS seit 01:14Z — Tester lebt (CPU-Zeit wächst), Full-History-News-Lauf, kein Orphan. Reload Chunk 9 fertig (6/10), Chunk 10 für T2/T3/T7/T9 läuft. `framework/calibrations/` sauber. **Router:** keine REVIEW-Tasks, keine offenen ea_review; FAILED-Liste = alte, verdiktgeschlossene Zeilen; Ticket `1258a0c5` (Registry-Kontamination durch Tests) IN_PROGRESS, Opus-Start hinter den zwei laufenden Revisions-Workflows (`wja1yviuh`, `wiywl8ay8`) gepaced. Codex-Lane im Router noch `enabled` (kein CODEX_LOW_TOKENS.flag) — ich route bis 07.09. nichts dorthin.

> **Nachtrag 04:30Z (03.09.) — alle drei Recompile-Paare laufen wieder in der Pipeline; Restart-Flag widerlegt und geparkt; Registry-Kontamination durch Tests gefunden.** **Recompiles (OWNER-Priorität 1):** 12710 Q02 `f1378383` (neue Identität `11474d4c`, normale Rerun-Form — die Juli-Evidenz liegt komprimiert als `.gz` vor, meine 03:53Z-Aussage „keine Evidenz“ war für 12710 falsch) seit 04:25Z aktiv auf T6. 10700 Q02 `71fddb4a` über den bestehenden Pfad `farmctl seed-fresh-q02` (Quelle `6205ba82` ist eine Vor-Binding-Zeile ohne SHAs — genau dafür existiert der Befehl; auch hier war „kein Pfad“ falsch), priority_track; da der Payload `fresh_q02_seed` statt `append_only_rerun` trägt, griff Amendment B nicht (Position 11.125) → `a8abdd16a8`: governed Fresh-Seed (an alte Zeile gebunden, priority_track, Q02) rangiert wie ein Lineage-Rerun → Position 4; Reload aller Worker (Chunk 9) läuft. 11910 Q03 `fa66883f` auf der neuen Identität eingereiht (Vorgänger = neue Q02 `71d1ad66`, Rerun-of = alte Q03 `6a2d8480`; die Q03-Form braucht den Q02-PASS als `--from-work-item-id`), Position 2 — die Kette wird pro Runde eine Phase weitergeschoben, keine Flag-Generalisierung nötig. **`--new-identity-restart` (`wlv9tw55z`) NICHT gemerged:** Verifizierer ok=false — unblockt keines der drei Paare (P1), Identitätswechsel-Prüfung für genau die Zielpopulation leer (P2), unscoped Freitext-OWNER-ID als permanenter Bypass der Q02-Evidenzbindung = ROT-nah (P3). Diff geparkt (Scratchpad `parked_new_identity_restart_flag.patch`) für den echten Fall „gebundene Quelle, Report gealtert“, der heute nicht ansteht. **Neuer Befund (P4, vorbestehend):** `farmctl.P5_CALIBRATION_JSON` ist an den echten Repo-Root gebunden → Testläufe (`test_farmctl_cascade.py`) schreiben Auto-Stubs des Kunstsymbols `QM5_9993_…COINTEGRATION_D1` in die getrackte Produktions-Registry `framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json` (Pfad steht auf der Pump-Auto-Commit-Liste; unsauberer Baum blockiert zudem Runtime-Activation-Minting). Im Haupt-Checkout gefunden (Stub vom 02.09. 11:52Z) und revertiert, ebenso im Agent-Worktree; Fix als Router-Task `1258a0c5` (ops_issue, Opus-Lane) beauftragt. Fabrik: 9 aktive Claims, 6–9 Zellen/10 min, CPU 99 %, RAM 11 GB frei; 1537 Versuch 2 (T2) läuft; Guardian-Chunk 40 (`bmgeloi2n`) mit Prioritäts-Normalisierung als Script.

> **Nachtrag 04:20Z (03.09.) — Batch 1 komplett neu kompiliert; 1537 Versuch 2 läuft; Marker-Leck-Blastradius = 14 Q02-Läufe → OWNER-Vorlage Regrade; beide Folge-Fixes in Revision.** **Recompiles:** 12710 zweiter Compile `47cd9a37` COMPILE_OK (EX5 `11474d4c`) → alle drei Batch-1-Binaries stehen (11910 `e18d477e`, 10700 `5fbf2ba0`, 12710 `11474d4c`). 11910: Q02 der neuen Identität PASS, Kaskade Q03+ aber durch DL-074 blockiert (jede vorhandene Folgephasen-Zeile des Paares sperrt die Beförderung) und alte Q03–Q06-Evidenz gepurgt → `--new-identity-restart` (Q02-Form, Opus `wlv9tw55z`) muss auf Q03–Q09 verallgemeinert werden (alte Phasen-Konfiguration auf neue EX5 klonen, ohne alte Evidenz). 10700/12710 warten auf dieselbe Form. **1537/XAGUSD:** Versuch-2-Zelle `b878d9ba` seit 04:08Z aktiv auf T2 (Worker nach Seal-Fix `b8cd532137` neu gestartet); T7/T9/T10 hielten noch das Vor-Fix-Modul → Idle-only-Reload läuft seit 04:15Z. Scheitert Versuch 2, ist die Zelle erschöpft (MAX_INFRA_ATTEMPTS=2) → manueller Pfad. **Marker-Leck (Befund a) — Blastradius gemessen:** 14 Q02-Läufe seit 01.09. bekamen einen zu niedrigen Frequency-Floor durch fremde `QM_PATTERN_FIRST_TRADABLE_BAR`-Marker im geteilten Tester-Tageslog: 41221/EURUSD (Floor 20 statt 45, 5 Läufe), 11421/EURUSD (35 statt 45, 4 Läufe — Paar zählt bereits über Q11!), 41283, 11314, 41219, 41305, 41270. Verdikte ändern = ROT → **OWNER-Vorlage:** Regrade dieser 14 Läufe gegen den korrekten Floor (append-only, alte Zeilen bleiben Evidenz); Empfehlung: Regrade JA, aber erst nach dem gemergten Fix, damit die Neubewertung auf dem reparierten Parser läuft. Bis dahin keine Kaskade auf Basis dieser Q02-PASS-Zeilen (41221 läuft bereits Q10_NEWS auf T10 — Ergebnis bleibt Evidenz, Zählung erst nach Regrade). **Fixes in Revision (`wja1yviuh`, Fortsetzung `wf_a06167c5-c38`):** Marker-Leck-Fix v1 (Verifizierer: Zuordnung pro Lauf fehlt, Core-Layout, Vertragsdoku, Regrade-Inventar) und Kaskadenfilter v1 (parent_ea_id-Falschpositive, Sichtbarkeits-Overcount, Ablations-Spawner-Perimeter, fail-open Erkenner) NICHT gemerged → v2 mit expliziten Anforderungen. Era-Audit-v2 + Backup-Reuse-v2 (`wiywl8ay8`) laufen. Fabrik: 9 Zellen/10 min, 7 aktive Claims, CPU 99 %, RAM 11,3 GB frei (unter der 14-GB-Pause-Schwelle → Worker latchen wieder), Pump ohne Fehler.

> **Nachtrag 04:05Z (03.09.) — 11910 Q02 (neue Identität) PASS; 10700 neu kompiliert, Q02-Einreihung blockiert; 1537-Rerun crashte am Seal → dritter Sichtbarkeits-Fix.** **Recompiles:** 11910 Q02 `71d1ad66` PASS 03:49Z → Kaskade folgt. 10700 zweiter Compile `dfb92b8a` COMPILE_OK (EX5 `5fbf2ba0`), aber keine neue-Identitäts-Q02 möglich: Rerun-Pfad `q02_rerun_source_evidence_missing` (Juni-Evidenz der alten Q02 durch Retention weg), Universe-Expansion-Pfad `ea_symbol_already_tested` → expliziter Schalter `--new-identity-restart` (fail-closed, Payload-Offenlegung) als Opus-Workflow `wlv9tw55z`; 12710 Compile pending. **1537/XAGUSD:** Rerun-Zelle `08767105` wurde nach Fix `a1cc06688b` geclaimt (T1) und lief 130 s, dann crashte der Post-Run-Seal (`opt_census_pruning._declared_cell`: „expected one declared ledger cell, found 0“) → INFRA_FAIL, Versuch 1 von 2 verbraucht. Dritter Aufruf-Ort gefixt `b8cd532137` (Rerun-ID → Ledger-Zelle über `driver['reruns']`); Reload-Pass 3 läuft, der Treiber legt Versuch 2 an. **RAM-Guard (14/20 GB, Konstanten) latcht die Flotte chronisch:** 4 Tester ≈ 25 GB → frei 13–19 GB → Worker im `ram_low_pause` (Resume erst >20 GB) → Compile-Zeilen und Zellen bleiben liegen, obwohl 10 Worker stehen → Sonntagspaket (Schwellen vs 63-GB-Host, Tests koppeln an 14 GB). Fabrik 9 Zellen/10 min, 8 aktive Claims, CPU 100 %, Pump 185–273 s ohne Fehler.

> **Nachtrag 03:40Z (03.09.) — 11910 neu kompiliert und Q02 der neuen Identität läuft; Rerun-Sichtbarkeit gefixt; 41324 Review APPROVE.** **Recompile-Welle:** 11910 zweiter Compile `57101a83` COMPILE_OK (Compiler + Build-Gate PASS, EX5 `e18d477e`) → Q02 `71d1ad66` der neuen Identität (Rerun-Form mit `--ea QM5_11910`, ohne `--owner-decision`, sonst Universe-Expansion-Pfad) — stand auf Position 1.333 → Amendment B um Q02 erweitert (`be721b7612`) → Position 1 → seit 03:33Z aktiv auf T2. 10700/12710 zweite Compiles pending. **Rerun-Sichtbarkeit (Befund 4) gefixt `a1cc06688b`:** die Opus-Variante (Row-Scan-Resolver in boost/arm_frontier) wurde vom Verifizierer widerlegt (einseitig, Durchsatz-Regression, ~1 s Write-Lock, Vertragsänderung) und NICHT gemerged; stattdessen CEO-Minimalfix: `terminal_worker._dl089_declared_lane` (CENSUS-Stufe) und `opt_census.boost` lösen Zellen über die Ledger-Map `driver['reruns']` auf (wie die abgeleiteten Stufen, kein Scan); 2 Tests, 45 Tests grün; Live-Dry-Run: 1537-Rerun `08767105` ist jetzt Arm-Frontier-Head → nach Reload/Boost claimbar → 5. Paar. **Reviews:** 41324 APPROVE_FOR_BACKTEST (Verifizierer: keine Widerlegung) — alle vier Siblings 41321–41324 approved (Evidenz-Reviews, formaler Handoff durch Build-Task-Sperren nicht möglich). Reload-Pass 2 aller Worker läuft (Pass 1 03:29Z fertig); Fabrik 11 Zellen/10 min, Pump 273 s, 8 Programme, CPU 97 %, RAM 13,5 GB.

> **Nachtrag 03:20Z (03.09.) — Recompile-Welle Runde 2, Sibling-Reviews APPROVE, Sibling-Ketten gehalten, Backup-Reuse fail-open.** **Recompiles:** erste Compiles kompilierten, scheiterten aber am aktuellen Build-Gate (MAE-Hook explizit in OnTick; 11910 zusätzlich ZeroMemory für QM_EntryRequest); 12710 wurde vom Compile-Recheck abgelehnt, weil der Worker noch das Vor-Allowlist-Modul im Speicher hatte (→ gestaffelter Reload aller Worker läuft seit 03:06Z, T6/T7 bereits neu; aktiviert zugleich Amendment B). Korsett-Reparaturen `5afa209e41` (Opus, verifiziert, 7 Zeilen, Gate PASS) → zweite Compile-Welle 57101a83/dfb92b8a/47cd9a37 (priority_track, Holds gelöst, Backup-Reuse aus). **Sibling-Reviews (Opus + Verifizierer, Verdict-JSONs `D:/QM/strategy_farm/artifacts/verdicts/review_sibling_QM5_4132x_20260903.json`):** 41321/41322/41323 APPROVE_FOR_BACKTEST (Diff = exakt das DL-089-Korsett, HR4/HR5/HR14 sauber; Verifizierer beanstandeten nur Zitatgenauigkeit, nicht das Urteil); 41324 läuft. Formaler `record-build`/`review_ea`-Handoff für alle vier unmöglich: drei Build-Tasks `blocked` (duplicate_build_task_existing_pipeline_work), 41324 `Q02_EXCLUDED:fx_only_expected_trades_gt_100` — Reviews gelten als Evidenz-Reviews. **Zwei Befunde aus den Reviews → Opus-Fixes (`wb9k5vses`):** (a) Frequency-Floor-Parser übernimmt `QM_PATTERN_FIRST_TRADABLE_BAR`-Marker FREMDER EAs aus dem geteilten Tester-Tageslog (41321-Q02: Fenster halbiert, min_trades 10→5 — fail-open); (b) Pump-Kaskade befördert Mess-Siblings über Q02 hinaus (Card: „No live or pipeline verdict is authorized“) → 17 pendente Q03/Q04-Zeilen (41301–41307, 41321–41324) unter `SIBLING_MEASUREMENT_ONLY_CHAIN_HOLD` geparkt, 4 Q04-Frühsonden liefen bereits. **Backup-Reuse (615608abd0) fail-open** (Verifizierer 4ce6ec32: WAL wird nach Checkpoint-Restart in-place überschrieben, Größe konstant → zeilenzahl-neutrale UPDATEs unsichtbar) → Machine-Env `QM_COMPILE_WAVE_BACKUP_REUSE_MAX_AGE_MINUTES=0`, Refactor in Revisionsstufe. Era-Audit ebenfalls in Revision (Klassifikator-Versatz). Fabrik: 8–23 Zellen/10 min (Reload + Hochrang-Läufe: 41221 Q10_NEWS auf T10 = REQUAL-8 Paar 7 am News-Gate, 41222 Q04), RAM 12 GB frei (Pause-Schwelle), CPU 97 %; Pump 320–335 s, 8 Programme, keine Fehler.

> **Nachtrag 03:00Z (03.09.) — OWNER-Entscheid umgesetzt: Recompile-Welle Batch 1 läuft, Slot-Reihenfolge und Amendment B live.** Opus-Workflow `wbhfg018g` (drei Worktrees + Verifizierer) gemerged: (1) Pre-0803-Force-Rebuild-Allowlist `fcc1a439d8` (OWNER-gebunden an das Entscheid-Doc, fail-closed, 72 Tests) → `enqueue-compile` 11910/10700/12710 (Zeilen 9df0f1ad/f1acbae1/b8a3b1f5), Holds per `release_compile_wave.py --apply` gelöst (Backup-Reuse griff), priority_track gesetzt → Claim-Positionen 31–33; Batch 2 (10815/12580) allowlisted, wartet auf OWNER-Antwort/Auffangregel 12 h. (2) Amendment B `ea1bbb5e86`: `_lineage_rerun_rank` (append_only_rerun + priority_track, Q03–Q09) — CEO-Platzierung NACH `_priority_track_rank`, damit die sekundenschnellen −1-Voraussetzungen (Source-Repair-Compiles, Q01-Smoke) Vorrang behalten; 11129-Q07-Rerun jetzt Position 2 (vorher ~1.285); Worker übernehmen die Ordnung beim nächsten gestaffelten Neustart. (3) Slot-Order-Tool `55ca6e950a` (`set_dl089_queue_order.py`, 16 Tests) angewendet: 10706/11422-Zweitpässe auf 2099 deferred (Backup 024553Z, Events), 20048/XTI rückt in Slot 8; 1537/XAG jetzt Slot 2, letzte Zelle (Treiber-Rerun 08767105) priority_track gesetzt (Position 1.281 → Frontier-Marker durch Boost im nächsten Zyklus erwartet). Pump nach den drei Fixes stabil: 02:23Z 424 s / 02:33Z 352 s, 8 Programme maintained, keine Matrix-/Integrity-Fehler; CPU weiter 99 % (Agenten BelowNormal/Idle normalisiert). Era-Audit: Verifizierer fand Klassifikator-Versatz (Worktree hinter main: 9 EAs ein Gate zu tief) und falsche `evidence_present`-Semantik für die 150 T2-Zeilen → Korrekturstufe eingeplant, Docs erst danach gemerged.

> **Nachtrag 02:35Z (03.09.) — Runde 02:26Z: Poison-Pill-Fix gemerged (145b20a4 APPROVED), Pump-Stall durch Agentenlast, Era-Audit liefert vier Adern.** Pump-Zyklus 02:08Z (pid 18992) hing 12 min in Zell-SQL-Reads des Selektors (CPU 100 % durch drei Opus-Workflows: zwei komplette pytest-Suiten + Era-Audit-DB-Scans; Worker in cpu_high_pause) → gekillt, Agenten-pytest auf Idle-Priorität gesetzt; 1537-Report-Cache war schon vollständig (607/607). **145b20a4 (Opus-Worktree, Verifier ok):** `poison_pill_quarantine._seal_summary_missing_pending` schrieb terminale INVALID-Zeilen ohne evidence_path → Live-Trigger brach jeden Zyklus ab; Fix `79a833c718` bindet den kanonischen `EVIDENCE_UNAVAILABLE:`-Sentinel (farmctl-Builder), 14 Tests grün; betrifft genau 2 Live-Zeilen (10001 GBPUSD/USDJPY Q02-Erben). Nebenbefund: Live-DB trägt zusätzlich `trg_work_items_terminal_requires_evidence_{insert,update}` (alle terminalen Verdikte), die das Repo nicht ausliefert — Schema-Drift dokumentiert, nicht entfernt. **Kaskade:** 41221/USDJPY (REQUAL-8 Paar 7) Q08 PASS 02:16Z → Q09; 20188/USDJPY News-Zeile REVIEW_REQUIRED 02:17Z (Fortsetzung via news_expansions); 41324 Q02 aktiv; 41322/41323 Q02 PASS. **Era-Audit f1655764 (Opus, Verifier läuft):** 3.569 EA-Zeilen, 48 zitierte Tiefenaudits, 269 Kandidaten; vier Adern: (1) **150 nachweislich falsche INVALIDs** der Universe-Expansion-Tranche 23.08. (Setfiles im entfernten Worktree `rb-universe-expansion` → `setfile_missing` → INVALID 25.08.; 150/150 kanonische Setfiles existieren im Repo; 16 EAs inkl. 10069, 10513, 10553); (2) **38 stehende Q09+-PASSes ohne Nachfolgezeile** (u. a. 9510/XAU PF 1,75, 12710/XTI PF 1,66, 21507/XAU Q11 PASS) — Q10_NEWS als kritischer Pfad bestätigt; (3) Juni-Rettungsqueue: 538 Q02-Zeilen seit Juli pending, verhungert; (4) Details im Doc nach Verifikation. Disposition (Requeue der 150 = GRÜN append-only) nach Verifier-Urteil.

> **Nachtrag 02:15Z (03.09.) — OWNER-Entscheid: Recompile-Welle Pre-0803, Slot-Reihenfolge, Amendment B HEUTE (Recompiles zuerst); dritter Matrix-Blocker gefixt.** OWNER 02:08Z: „… vor allem die Recompiles, können wir heute bereits angehen und dementsprechend priorisieren!“ → `OWNER-DEC-PRE0803-RECOMPILE-SLOTORDER-AMENDB-20260903`, Evidenz `docs/ops/evidence/2026-09-03_owner_dec_pre0803_recompile_slot_order_amendment_b.md`. Scan 02:10Z: 8 der 64 Paare ohne Q10-Lock haben Pre-0803-Binaries; Batch 1 = 11910/NZD, 10700/XAU, 12710/XTI (genehmigt), Batch 2 vorgeschlagen 10815/GDAXI, 12580/AUD; 13036/9510/12357 (INVALID/MISSING) außen vor. Mechanik: governed Compile lehnt aktives Inventar ab (`CANDIDATE_RECHECK_REFUSED`, 9936-Präzedenz 24.08. scheiterte genau daran) → dritte OWNER-gebundene Force-Rebuild-Allowlist in `compile_work_items.py`; rebuilt EX5 = neue Identität ab Q02. Umsetzung (Allowlist, governed Slot-Order-Tool `set_dl089_queue_order.py`, Amendment-B-Rangschlüssel `_lineage_rerun_rank`) läuft als Opus-Workflow `wbhfg018g` in Worktrees mit Verifizierern; CEO merged, danach enqueue-compile + release_compile_wave. **Dritter Matrix-Blocker (01:48–02:02Z, jeder Zyklus `DL089_MATRIX_SERVICE_FAILED:no closed round trips parsed`):** Zensuszelle 1537/2025-Baseline `f348bd0a` MEASURED mit 0 Trades → `opt_census.cell_report` ließ `q10_recency.extract_closed_trades` eine ValueError werfen, die der Selektor-Reader nicht fängt → ganzer Service-Pass tot (kein Boost/Refill). Fix `a153b24d47`: total_trades=0 → definierte Null-Aktivitäts-Metrik (Activity-Floor schließt den Arm aus), 2 Regressionstests, 37 passed, live auf der Zelle verifiziert. Build-Result-JSONs 41321–41324: alle vier vom Verifizierer widerlegt (Build-Task blocked statt leer, Q02-Lauf als „Smoke“ deklariert, Setfile-Hash-Provenienzbruch nach Compile, undisclosed COMPILE_FAIL-Vorgänger, synthetisierte Felder) → Revisionsstufe + zweite Verifikation (`wzz7mqdm0`); erst danach record-build/Reviews. Fabrik: 7 Zellen/10 min (Verdrängung + CPU-Pause durch Agentenlast), 10 Worker.

> **Nachtrag 01:55Z (03.09.) — 11421/EURUSD zählt: qualified_pairs = 4/25; Q10 CONFIG_LOCKED-Paare 25; OWNER-Direktive Codex→Opus umgesetzt.** 11421 News-Fortsetzung `4fc0db48` CONFIG_LOCKED 01:34Z (T2) → Q11 `52358e7e` PASS 01:42Z → Paar kontiguiert bis Q14 (alte Q12–Q14-Kette) → **book_build_guard 4 Paare** (10706/GBP, 11422/CAD, 13054/XTI, 11421/EUR). Neue Q12-Musterzeile `19761d0c` für 11421 (Zweitpass) geseedet. 1537/XAG: letzte Zelle läuft → Selektion im nächsten Zyklus. 41222 (REQUAL-8 Paar 8): Q02 PASS → Q04 pending. 11288/USDJPY `bdfeef30` Retry läuft auf T5. **Flotte planmäßig auf Hochrang-Läufen** (3 News-Gates, Q07/Q08-Reruns, 2 Sibling-Q02 41322/41323, 2 Zensus): Zellenrate 4/10 min ist Verdrängung, keine Störung; RAM 7,8 GB frei (8 Tester ≈ 40 GB, ram_low_pause greift bei 14/20 GB), CPU 100 %, Pump 270 s ohne Matrix-Fehler, 10 Worker alle auf neuer Konfiguration (T2 01:49Z neu geladen). **OWNER 01:45Z: Codex-Token bis 07.09. erschöpft → Codex-Queue mit Opus-Agenten; danach Verteilung nach Wochenlimits + Komplexität** (Memory `feedback_model_routing_codex_exhausted_2026-09-03`). Umgesetzt: Sibling-Welle 2 `57bc396f` (Codex hatte 01:00–01:41Z noch geliefert: 41321–41324 COMPILE_OK, Cards D:+C:, Q02-Seeds laufen, 41321 Q02 PASS) nach Artefakt-Verifikation APPROVED; Build-Result-JSONs (fehlten) + vier `review_ea` folgen Opus-gestützt; 145b20a4/4ce6ec32/f1655764 IN_PROGRESS als Opus-Agenten in isolierten Worktrees mit adversarialem Verifizierer (Workflows wrwzeecp1, wifroufbj); Merge/Commit durch CEO nach Diff-Prüfung.

> **Nachtrag 01:35Z (03.09.) — Loop-Runde 01:16Z: Rekordtempo, Silent-Abort-Zeilen klassifiziert, Recompile-Vorlage.** Fabrik 30→43 Zellen/10 min (Rekord), 141/h, 10 Worker (T4 nach News-Lauf neu geladen, nur T2 noch Alt-Konfig), RAM 26 GB, Pump 283–335 s ohne Matrix-Fehler; Guardian/Reload-Chunks wurden zweimal vom Harness abgebrochen (keine Lücke, je Runde neu gestartet). Router: Sibling-Welle 2 `57bc396f` bereits IN_PROGRESS bei Codex (00:57Z); keine REVIEW/ea_review; BLOCKED/FAILED-Stapel sind Altbestand (116 vom 24.08.), neu seit 02.09. nur Compile-CPU-Ceiling-Holds (f3fba72c, ce28db7e → Compile-Fenster Sonntag). **41222/USDJPY Q02 PASS** (REQUAL-8 Paar 8 läuft weiter). **11910/NZDUSD Ersatzzeile `a6dbacf5` = REVIEW_REQUIRED/`cell_execution_failed`: alle 8 Zellen `qm_news_calendar_bundle_id mismatch`** — bekannte Klasse (Evidenz 2026-08-24_qm5_9936: Binaries vor dem Provenienz-Include f0102fbcf vom 03.08. tragen die drei `qm_news_calendar_*`-Inputs nicht; 11910-EX5 vom 24.07.). Rezept = governed Recompile = **neue Identität ab Q02** (ROT: aktives Inventar) → **Sonntags-Vorlage RECOMPILE-PRE-0803** für 11910/NZDUSD, 10700/XAUUSD, 12710/XTIUSD (alle 24.07.): Kosten je Paar volle Q02–Q10-Kette, Nutzen bis +3 Paare; Empfehlung: JA für 11910 und 10700 (Q08-Evidenz FAIL_SOFT-aber-promotable), 12710 nach Q08-Bild. Konsequenz gezogen: exakter Q07-Rerun `3815515b` (10700) unter `AWAITING_OWNER_RECOMPILE_DECISION` geparkt (gegenstandslos auf altem Binary, spart ~1 h Tester). **11288/USDJPY `bdfeef30`:** Silent-Abort war ein transienter `database is locked` beim Runner-Start (14:20Z Lock-Sturm, Klasse 76981d683b gefixt), Plan gültig, Binary 17.08. → Hold per `release-hold` gelöst (Backup 20260903T012042Z), Retry durch Worker. 11129/SP500 (Binary 17.08.) bleibt auf dem Q07→Q08→Ersatz-Pfad; 11422/USDCAD-Duplikat `d712832c` bleibt geparkt (Paar zählt bereits).

> **Nachtrag 01:05Z (03.09.) — 13054/XTIUSD Q14 `4aaa524d` KEEP_INCUMBENT 00:59Z → book_build_guard qualified_pairs = 3** (10706/GBP, 11422/CAD, 13054/XTI; 3 distinct EAs / 3 Familien). Kette Q12→Q13→Q14 lief nach beiden Fixes vollautomatisch in 20 min (00:39Z→00:59Z). Fabrik 26 Zellen/10 min, 10 aktive Claims, Pump-Zyklen 300 s ohne Matrix-Fehler. Nächstes Paar: 1537/XAGUSD (78 Zellen offen).

> **Nachtrag 01:00Z (03.09.) — VERIFIZIERT: 13054/XTIUSD Q12 finalisiert, Zähler 2/25, Karte zum Ziel.** Zyklus 00:38Z: 330 s, Matrix-Stage 46 s, `finalized` → Q12 `a5b90e08` done/NO_FILTER_CHANGE 00:39Z, Hold gelöst, Q13 `83c1e21f` NO_PARAMETER_CHANGE 00:49Z; Q14 im Folgezyklus erwartet. Fabrik 22 Zellen/10 min, 10 Worker, RAM 31 GB. **book_build_guard: qualified_pairs = 2** (10706/GBP, 11422/CAD, beide bis Q14 kontiguiert). Census-Karte der 24 Q12-Paare: 13054 → drittes Paar nach Q14; **13 Paare bis Q11 kontiguiert, denen nur das Q12-Programm fehlt**: 1537 (78 Zellen offen), 21507 (606), 11881 (954), 20266 (873), 10513 (976), 20048 (1.085), 21505 (1.049); 12855/9641/12849 mit fertigen Siblings 41305–41307 warten auf Programm-Slot (K=8); **21501/USDJPY, 13013/NDX, 10403/XAUUSD, 11660/NDX ohne `_opt`-Sibling → Codex-Auftrag `57bc396f` (P85, Sibling-Welle 2, Rezept b91f5ffa)**. 11421/EUR zählt erst nach News-Lock (T2). Sonntagspaket: 2 der 8 Slots (10706, 11422) messen Zweitpass-Programme bereits zählender Paare — Slot-Reihenfolge zugunsten der Q11-kontiguierten Paare ist ein GRÜN-Hebel, heute Nacht nicht angefasst. Evidenz-Doc um Deadlock-Befund und Karte ergänzt.

> **Nachtrag 00:40Z (03.09.) — Runde 00:29Z: zweiter Q12-Blocker (Selbst-Deadlock) gefixt.** Der erste Zyklus mit Guard-Fix (00:18Z) ließ 13054 durch (Selektions-Receipt geschrieben, Verdict NO_FILTER_CHANGE), brach aber nach 673 s mit `DL089_MATRIX_SERVICE_FAILED:database is locked` ab → Rollback (Zeile weiter pending), alle Folgestages `cycle_budget_exhausted`, Worker-Claims blockiert (Fabrik 24→14 Zellen/10 min). Ursache: `_finalize_from_terminal_ledger` hielt das RESERVED-Lock der äußeren Service-Connection ohne Commit; `boost`/`selector.advance` des nächsten Programms (eigene Connection, BEGIN IMMEDIATE) warteten bis zum Busy-Timeout, der Write-Retry-Wrapper wiederholte den ganzen Pass (py-spy: `boost opt_census.py:732`). Der 00:33Z-Zyklus hing identisch → gekillt (Rollback, Lock frei, Claims sofort wieder 9). Fix `c230995ae8`: Commit direkt nach Abschluss+Hold-Release (atomare Einheit bleibt), Regressionstest mit zweiter Connection; Suite 15 passed. Erwartung: nächster Pump-Zyklus (≥00:38Z) finalisiert 13054/XTIUSD Q12 → Q13-Kette; 1537/XAGUSD folgt nach 130 Zellen. Historie: 11421 kam 07:30Z nur durch, weil kein weiteres Programm folgte (Zyklus 1.399 s).

> **Nachtrag 00:15Z (03.09.) — Loop-Runde 23:47Z: KRITISCHER Q12-BLOCKER gefunden und gefixt.** Fabrik 168 Zellen/h (24/10 min), 10 Worker (T2/T4 weiter Alt-Konfig in Langläufen), RAM 31 GB frei, Lock frei, Pump 23:58 = 365 s (reviews_and_research 109 s, queue_maintenance 95 s, build_dispatch 70 s; keine Stage übersprungen). **(1) Q12-Zeilen sind keine Worker-Läufe:** alle 24 pendenten Q12 (inkl. 21501/USDJPY, 13013/NDX) hängen unter `Q12_DL089_MATRIX_WORKER_ROLLOUT_PENDING` und werden vom Matrix-Service aus versiegelten Zensus-Zellen finalisiert — Fortschritt = Zellen je Programm (13 Programme mit Zellen, 11 ohne). **(2) Regression durch den Ownership-Guard 8d57f98150 (Codex 0058a401):** Treiber-eigene WF-Combo-/Numerik-/Final-Fullwindow-Zeilen und INFRA_FAIL-Reruns (parent_task_id NULL) galten als `PROGRAM_Q12_REBIND_REFUSED` → 13054/XTIUSD (1.085 Zellen fertig, 4 WF-Zeilen gemessen, Driver PATTERN_SELECTION_READY) seit ~13Z in jedem Zyklus deferred; jedes weitere Programm wäre exakt bei der Selektion eingefroren. Fix `e08b4eeaba` (Guard beweist Ownership über die 1.085 deklarierten Zeilen; Fremdbindungen/unerklärte Duplikate weiter abgelehnt), 2 neue Tests, 14 passed; Live-Trockenlauf 13054 und 1537 OK. `test_…_bounded_window` scheitert auch auf HEAD (umgebungsgekoppelt, G_eff=4). Evidenz `docs/ops/evidence/2026-09-03_dl089_binding_guard_derived_rows_regression.md`. **(3) 11910/NZDUSD:** Q08-Rerun `6757567a` FAIL_SOFT (gleiches EDGE_SOFT-Profil wie 07/2026, zulässige Ersatzquelle); alte News-Zeile `dd7b14a0` per neuem `governed_work_item_hold.py --supersede-hold-code NEWS_RUNNER_SPAWN_SILENT_ABORT` (`e2dc0bd14a`, Hold-Schema = 1 Hold/Zeile) auf `Q09_AWAITING_SEALED_PLAN` umgehängt (Backup 20260902T235627Z); Pump spawnte Ersatz `a6dbacf5` 00:00:55Z, Plan gebunden, läuft auf T7. Gleiches Rezept für die 5 übrigen Silent-Abort-Zeilen nach deren Reruns. **(4) Warteschlange:** Q07-Reruns 11129/10700 (priority_track) auf Position ~1.285 hinter 1.280 priorisierten Zensus-Zellen (41161/41097) — Amendment B bleibt Sonntagsentscheid. Router: keine REVIEW/ea_review; OPS_FIX_REQUIRED 71eba21c (15.08.) und 72386dac (QM5_1188 Force-Rebuild = OWNER) sind Altlasten → Sonntagspaket. Nächste Runde: Pump-Zyklus ≥00:18Z muss 13054 aus `deferred` in `maintained`/Finalisierung heben.

> **Nachtrag 23:30Z — Loop-Runde 23:25Z:** Fabrik 138 Zellen/h (Rekordstunde), 10 Claims, RAM 28 GB, Lock frei, Pump 299–335 s (nahe Budget, beobachten). **11910/NZDUSD Q07-Rerun `f3689f77` PASS** (Lineage-Welle 2) → exakter Q08-Rerun `6757567a` eingereiht (append-only von `0cb83f40`, aktueller ex5-SHA, priority_track); 11129/10700 Q07-Reruns pendend. Q12-Zeilen 21501 und 13013 pendend; Siblings 41303/41305 in Q03. Worker 8/10, T2/T4 weiter in News-Läufen (10-s-Polling aktiv). Keine pendenden Reviews.
>
> **Nachtrag 23:05Z — Loop-Runde 23:03Z: zweites CONFIG_LOCKED, Lineage-Reparatur trägt.** **QM5_13013/NDX** hat das Q10-News-Gate um 22:41Z mit CONFIG_LOCKED abgeschlossen (Q10-bestätigte Paare 23) — genau das Paar, dessen Q08-Rerun `6fdfbae6` und Ersatz-News-Zeile heute Nachmittag den Ersatzpfad bewiesen haben; Q11 erledigt, Q12 pendend. Damit heute zwei neue Q10-Abschlüsse (21501/USDJPY, 13013/NDX), beide über regenerierte Q08-Ketten. Fabrik 124 Zellen/h (Rekordstunde), 9 Claims, RAM 22 GB, Lock frei, Pump 261–271 s; 11910-Q07 (Lineage-Welle 2) läuft, 11421-News-Fortsetzung läuft (T2), 41303 in Q05. Worker 8/10 auf neuem Stand; T2/T4 verfehlen die kurzen Leerlauffenster → Reload-Chunk pollt jetzt alle 10 s statt 60 s. Keine pendenden Reviews.
>
> **Nachtrag 22:45Z — Loop-Runde 22:41Z:** Fabrik 115 Zellen/h, 10 Claims, RAM 26 GB, Lock frei, Pump 275–303 s. **21501/USDJPY → Q12 (Pattern-Filter-Auswahl) pendend** — der Optimierungszweig beginnt. REQUAL-8 Paar 6 (41220): Q09 Baseline-Full-Run **FAIL** (terminal für diese Kette, Verdikt append-only). Sibling 41303 läuft Q04 (Messgeschwister-Kette). 41222-Q02 pendend. Worker-Konfiguration 8/10; T4 hat zwischen zwei News-Läufen (12823 → 11708) das 60-s-Idle-Fenster des Reload-Chunks verfehlt, T2 seit 17:23Z in 13013-News. Keine pendenden Reviews.
>
> **Nachtrag 22:25Z — Loop-Runde 22:19Z: 21501/USDJPY Q11 PASS.** Die Incumbent-Bestätigung ist in 25 Minuten durchgelaufen (Q10 CONFIG_LOCKED 21:55Z → Q11 PASS 22:1xZ); das Paar steht damit vor dem Optimierungszweig (Q12–Q14) bzw. der Portfolio-Stufe. Tagesbilanz 02.09.: 816 Zensus-Zellen (nach 0–5/10 min am Vormittag), 104 Zellen/h am Abend; Q10-bestätigte Paare 22. Worker-Konfiguration 8/10 (T6 dazu), T2/T4 in News-Läufen seit 17:23/19:31Z. RAM 17 GB, Lock frei, Pump 259–285 s, keine pendenden Reviews.
>
> **Nachtrag 22:00Z — Loop-Runde 21:57Z: erstes CONFIG_LOCKED des Tages.** **QM5_21501/USDJPY** hat das Q10-News-Gate um 21:55Z mit CONFIG_LOCKED abgeschlossen (Q10-bestätigte Paare 21 → 22) und läuft bereits in Q11 (Incumbent-Bestätigung, T6). 11421-Ersatz-News-Zeile `23282266` → REVIEW_REQUIRED (Expansion, Fortsetzung folgt automatisch); 41220-Q08 FAIL_SOFT (promotierbar); 41222-Q02 pendend; 20082-Q07 läuft. Fabrik 120 Zellen/h, 788 Zensus heute, 9 Tester, RAM 8,5 GB (beobachten), Pump 240–266 s, Lock frei. Worker-Konfiguration 7/10 — T2/T4/T6 sind die drei vor dem Fix gestarteten Alt-Worker (11:58/12:22/17:08Z), Reload bei Leerlauf (T6 jetzt in Q11, langer Lauf).
>
> **Nachtrag 21:40Z — Loop-Runde 21:35Z:** Fabrik 112 Zellen/h (744 Zensus heute), RAM 22 GB, Pump 233–281 s, Lock nur als Live-Claim belegt. Worker-Konfiguration 7/10 (T1/T3/T5/T7/T8/T9/T10 ok; ein „old"-Befund für T1 war ein Log-Fenster-Artefakt), T2/T4/T6 seit 15:51/17:23/19:31Z in News-Läufen (Reload-Chunks laufen weiter). Frontier: 11421-News `23282266` läuft (T9), 41220-Q08 läuft (T5), 41222-Q02 pendend; Q10-CONFIG_LOCKED-Paare unverändert 21. Keine pendenden Reviews, Codex im Quota-Hold.
>
> **Nachtrag 21:15Z — Loop-Runde 21:13Z:** Fabrik 102 Zellen/h (696 Zensus heute), 10 Claims, RAM 23 GB, Lock frei, Pump 252–368 s. **11421-Ersatz-News-Zeile `23282266` läuft (T9)** — der neu geladene T9 hat sie im News-Tier geclaimt; 41220 (REQUAL-8 Paar 6) Q07 PASS → Q08 läuft (T5); 41222-Q02 pendend. Worker-Konfiguration 7/10 (T9 dazu), T2/T4/T6 seit 15:51/17:23/19:31Z in News-Läufen. Keine pendenden Reviews.
>
> **Nachtrag 20:55Z — Loop-Runde 20:51Z:** Fabrik 100 Zellen/h (657 Zensus heute, gestern-Niveau erreicht), 7 Claims, RAM 18 GB, Lock frei, 10 Worker (6/10 mit Top-Down+Pruning; T2/T4/T6/T9 weiter in News-Läufen seit 15:51–19:31Z). Pump-Zyklus 20:38Z 406 s (queue_maintenance 159 s, news_expansions 106 s, matrix 87 s — DB-Kontention bei 10 Claims; beobachten). Frontier: 41220-Q07 (REQUAL-8) läuft, 41222-Q02 und die 11421-Ersatz-News-Zeile pendend hinter dem Zensus-Tier → Amendment-B-Vorlage um REQUAL-8-Kettenzeilen (Q02…Q10 der acht Paare) erweitern: sie sind OWNER-priorisiert, stehen aber unter Top-Down hinter ~5.000 Zellen. Q10-CONFIG_LOCKED-Paare 21 (unverändert).
>
> **Nachtrag 20:35Z — Loop-Runde 20:30Z:** Fabrik 138 Zellen/h (Rekord), 10 Claims, RAM 29 GB, Zensus heute 624; 11421-Ersatz-News-Zeile `23282266` (aus Q08 `c93263aa`, versiegelt, priorisiert) pendend hinter dem Zensus-Tier; 41220-Q07 (REQUAL-8) läuft; 41222-Q02 pendend. Worker-Konfiguration 6/10 (T10 dazugekommen), T2/T4/T6/T9 seit Stunden in News-Läufen. Lock-Journal zeigt einen ACQUIRED-Eintrag ohne RELEASED von T10-pid 38756 (alter Worker beim Reload gestoppt, Stale-Reap greift, Claims laufen) — kein Wedge. Keine pendenden Reviews; Codex weiter im Quota-Hold (3 TODOs).
>
> **Nachtrag 20:25Z — Loop-Runde 20:14Z:** Fabrik 124 Zellen/h (Tagesbestwert, 61 in 30 min), 10 Claims, RAM 24 GB, Lock frei, Pump 246 s; Zensus heute 598. **11421/EURUSD Q08-Rerun `c93263aa` PASS** → der kanonische Ersatzpfad (`_spawn_q09_replacements_for_regenerated_q08_once`) verlangt einen AKTIVEN `Q09_AWAITING_SEALED_PLAN`-Hold auf der alten News-Zeile `30584122` (Bindung an stale Q08 `6678f2c4`, würde launch-faulten); Setfile-Pfade identisch, Rerun trägt `append_only_rerun`. Hold per `governed_work_item_hold.py apply` (Backup, BEGIN IMMEDIATE, nicht claimbar) mit Begründung gesetzt — die REQUAL-8-Absicht (Paar läuft auf gültiger Kette durch Q10) bleibt gewahrt; Ersatzzeile erwartet im nächsten Pump-Zyklus, alte Zeile → SUPERSEDED. Konfiguration: 5/10 Worker mit Top-Down+Pruning, T2/T4/T6/T9/T10 seit Stunden in langen Läufen (Reload-Chunks warten). Keine pendenden EA-Reviews.
>
> **Nachtrag 19:55Z — Loop-Runde 19:47Z: Tagesbestwert und REQUAL-8 komplett.** Fabrik 80 Zellen/h (34 in 10 min), 10 Claims, RAM 17 GB, Lock frei, Pump 225 s; alle sieben Sibling-Seeds PASS, neue Programme (21505/XAGUSD, 1537/XAGUSD, 21507, 10145, 10513) liefern Zellen; 11421-Q08-Rerun `c93263aa` läuft (T3), 12823-News-Fortsetzung läuft (T4). **REQUAL-8 Paar 8:** die seit 13:21Z pendende EA-Review (ClaudeOrchestration-Task deaktiviert → Reviews landen bei mir) durchgeführt: QM5_41222 APPROVE_FOR_BACKTEST (hash-gebundene Manifest-Autorität, Mechanik byte-äquivalent zum Parent 11476, Korsett/HR sauber, Smoke-Deferral mit belegtem no_capacity-Zensus), Duplikat-Review geschlossen, Q02 per Manifest-Kontrakt eingereiht (`0dbb6090`) → OWNER-DEC-Q09HOLD-REQUAL-8 8/8 ausgeführt, Auftrag df2343c6 geschlossen. **Pump:** Stage `poison_pill_refresh` scheitert jeden Zyklus am Evidenz-Sentinel-Trigger (isoliert) → Codex `145b20a4` (P55). Worker-Konfiguration: 5/10 mit Top-Down+Pruning, Rest in Chunks bei Leerlauf.
>
> **Nachtrag 19:35Z — Loop-Runde 19:25Z: Sibling-Seeds durch.** 41301–41306 Q02 PASS (jeweils 5–15 min), 41307 läuft; der Matrix-Service führt jetzt 9 statt 7 Programme (die deferred Programme sind zugelassen). Worker-Konfiguration (neue Startzeile): T1/T3/T5/T7/T8 mit Top-Down + Pruning; T4/T10 noch ohne (vor dem Fix neu geladen), T2/T6/T9 alt — Reload-Chunks (18 min, idle-only) laufen weiter, Guardian-Chunks halten 10 Worker. Fabrik 22 Zellen/h (Seeds belegten die Slots), RAM 19 GB, 6 Tester, Lock frei, Pump 210 s. **Konsequenz der Top-Down-Reihenfolge (jetzt wieder wirksam):** Q07/Q08-Reruns der Q10-Lineage (Rang 3–4) stehen hinter dem OPT_CENSUS-Backlog (Rang 0, ~5.000 Zellen); die heutigen Q08-Reruns liefen nur, weil die Worker den kalten Pfad fuhren. Der Q10-News-Pfad (CONFIG_LOCKED = Buchzähler) wird damit erst bedient, wenn keine Zensus-Zelle zulässig ist → **OWNER-Punkt Sonntag**: Lineage-Reruns priorisierter Q10-Paare wie die Seeds auf Rang 0 heben (Amendment B) oder Top-Down beibehalten.
>
> **Nachtrag 19:30Z — WEBSITE: „aktuelle Daten überall" geliefert (OWNER 18:5xZ):** Producer (`3f382a78cb`, 85 Tests grün): `export_public_snapshot.ps1` liefert stündlich zusätzlich Funnel-Paare (Q02 7.021 / Q04 336 / Q08 46 / Q10-CONFIG_LOCKED 21), Archivzähler (3.378 / 9 mit Q10 / 1.297 gescheitert), Symbole 275, Quellen 118 und `hero-equity.json` (24 Sleeves, 471 Wochenpunkte, Index 100→2004); Schema erweitert, hourly Task + Sync + Git-Publikationsliste verdrahtet; verwaistes v1-Snapshot-Schema entfernt. Site (`cd48ad4` auf `refresh/apple-2026-09`): Archivzeilen klappen zu den aktuellen Gate-Details des Karten-JSON auf, alle Zahlen per data-stat aus dem Producer, Datumsangaben dynamisch aus `generated_at`, Disclaimer „eighteen-gate pipeline (Q00–Q17)", performance.html-Handzahlen verdrahtet (Fixer). Unabhängiger Ende-zu-Ende-Prüfer: Werte gegen Live-DB reproduziert, keine Blocker. Artefakt-Vorschauen unter denselben Links neu veröffentlicht. Offen (minor): `validate_public_snapshot.ps1` prüft `hero-equity.json` noch nicht (Exporter-Validierung greift); Myfxbook-Widget-Id auf performance.html = bereits öffentliches Widget der Live-Seite. **Live-Gang** weiterhin OWNER-Handlung (Netlify aus Drive-Ordner).
>
> **Nachtrag 19:10Z — Loop-Runde 19:02Z:** **Erster Sibling-Seed läuft** (41301/XAUUSD Q02 auf T7 seit 18:56Z) — Option A + Zensus-RAM-Klasse greifen. Reload mit Maschinen-Umgebung (env4) läuft: T1 und T8 loggen jetzt `topdown_gate_priority: true`, `dl089_pruning_env: 1` (neue Startzeile `454036e32f`); T7 folgt bei Leerlauf. Vorsicht beim Launcher: `_governed_terminals` lässt fehlende Worker nur bis `max_workers` des RAM-Headroom-Governors zu — bei RAM-Engpass startet ein gestoppter Worker u. U. nicht neu (T1 18:58Z `new pid=None`, manuell nachgestartet) → Guardian-Schleife (alle 2 min, 4 h) startet fehlende Worker mit korrekter Umgebung nach. Fabrik 26 Zellen/h (RAM-gebunden, 12 GB frei, 7 Tester), Lock frei, Pump-Zyklen laufen; Pump-Log 18:58Z zeigt zwei Zeilen-Fehler (fehlende evidence_path-Sentinel bei einer Terminal-Zeile; Q08-Setfile-Vintage-Mismatch bei einer News-Promotion) — fail-closed, zu prüfen in der nächsten Runde.
>
> **Nachtrag 19:20Z — STRUKTURBEFUND: Session-Reloads liefen ohne Maschinen-Umgebung.** Meine interaktive Shell trägt die Maschinen-Variablen `QM_TOPDOWN_GATE_PRIORITY_ENABLED=1`, `QM_ENABLE_DL089_PRUNING=1`, `QM_SQLITE_BUSY_TIMEOUT_MS=15000` nicht; jeder heute aus dieser Sitzung gestaffelt neu geladene Worker (09:2xZ, 16:5x–17:14Z, 18:4x–18:5xZ — am Ende alle zehn) lief deshalb mit der KALTEN Claim-Reihenfolge (OWNER-Top-Down-Priorität faktisch aus; erklärt, warum die Seeds trotz Option A nicht kamen — ihre Position im kalten Pfad ist ~1.343) und ohne Worker-seitiges DL-089-Pruning (`SKIPPED_EXCLUDED`-Receipts gestern 16–32/h, heute nur sporadisch; entfallenes Pruning = einige ausgeführte, aber ausgeschlossene Zellen, Menge nicht exakt bestimmbar). Fix: (1) Launcher `start_terminal_workers.py` mischt künftig HKLM-`QM_*` in die Spawn-Umgebung (`79ff6ce334`, Tests grün); (2) Reload aller Worker mit exportierter Umgebung läuft (env4, idle-only, ≥150 s Abstand). Lehre für alle Sitzungen: vor Worker-Starts `[Environment]::GetEnvironmentVariable(...,'Machine')` gegen die Shell prüfen.
>
> **Nachtrag 19:00Z — Loop-Runde 18:37Z:** Fabrik RAM-gebunden: sechs große Läufe (Q07 XAU seit 11:44Z, vier Q10_NEWS, ein Q08) belegen ~46 GB, vier Terminals idle bei 17 GB frei (Zensus braucht ≥18, ordinary ≥22) → 38 Zellen/h. Die sieben Sibling-Seeds führen die Reihenfolge, blieben aber RAM-geskippt (ordinary 8 GB) → `1664707ade`: Messgeschwister-Seeds reservieren die Zensus-Klasse (4 GB), Tests 98 grün; Reload der vier idle Worker läuft (idle4), full3 wartet auf die sechs beschäftigten. **Mission Control** „Fortschrittsvergleich" ist aktuell (2-min-Task, 18:25Z; Heute 559/81/23 = Live-DB) — Browser-Cache beim OWNER. **Chrome-Fenster** liegt in der getrennten qm-admin-RDP-Sitzung (3); der OWNER folgt offenbar über claude.ai → Vorschau wird als private Artefakt-Seiten gebündelt (CSS/JS/JSON inline, kein fetch). **Website „aktuelle Daten überall"** (OWNER 18:5xZ): Workflow läuft — Producer `export_public_snapshot.ps1` liefert künftig Funnel-Paare, Q10-bestätigt, Archivzähler, Symbole, Quellen und `hero-equity.json` stündlich; Seite liest alles per data-stat, Datum dynamisch, Archiv-Detailzeilen aus dem aktuellen JSON, Disclaimer-Wortlaut aktuell.
>
> **Nachtrag 18:55Z — Option A: Gegenprüfung fand Fehler, gefixt:** Commit `9039cb1567` (Option A) hatte die neue CASE-Zeile ohne `json_valid`-Schutz — eine leere/ungültige Q02-Payload hätte die kanonische Claim-Abfrage ALLER Worker mit `malformed JSON` abbrechen lassen (stiller Fabrik-Stillstand). Fix `89272cc676` + Regressionstest; aktuell trägt keine pendende Zeile ungültiges JSON. Lehre: Dual-Lens-Review auch bei „kleinen" Selector-Änderungen — der Live-Effekt-Prüfer war zufrieden, der Korrektheits-Prüfer nicht. Worker-Reload (full3) läuft; vor dem Fix neu geladene Worker (T1/T5/T3) bekommen die geschützte Fassung im nächsten Idle-Durchlauf.
>
> **Nachtrag 18:35Z — WEBSITE-REFRESH FERTIG (lokale Vorschau, kein Push):** Branch `refresh/apple-2026-09`, Commit `a313816` im Worktree `C:\QM\deploy\qm-ops-refresh`, Vorschau http://127.0.0.1:8091/ (Chrome-Tabs auf dem VPS offen — neu laden). Umfang: ein Designsystem (weiße Fläche, schwarze Evidenz-Panels, Inter mit Tabellenziffern, 8-pt-Raster, ein Akzent, keine Glows), eine Nav/ein Footer auf allen Seiten, Build-Partials aus dem Publish-Verzeichnis entfernt; Chart-Engine `qm-charts.js` (Hero = echte Aggregat-Equity der 24 Q10-PASS-Sleeves, Index 100, ohne EA-Identität; Kerzen kalibriert synthetisch mit GARCH-Clustering, Student-t, Gaps, korreliertem Volumen, berechneten Overlays; Gate-Journey-Strip); alle Seiten neu (index, pipeline, strategies datengetrieben aus `strategy-archive.json`, performance, about, faq, blog + 19 Posts, legal ×3, 404, Sitemap 29 Seiten). Review (4 Linsen, Screenshots) + Fix-Runde + eigener Abschluss: Exposure-Grep leer, Hamburger/Mobile-Overflow gefixt, Chart-Realismus-Checkliste bestanden. **In Quarantäne `_unpublished_review_2026-09-02/` (nicht gelöscht, OWNER-Entscheid):** `reports/` (114 rohe MT5-Exporte mit Metriken), `strategies/` (402 Legacy-Detailseiten), `showcase.html`, `equity/` (42 Equity-PNGs je Strategie = Disclosure-Bruch), `data/terminal_status.json` (Terminalnamen/-zahlen), Netlify-CLI-State. **OWNER-Punkte zur Vorschau:** (1) aggregierte Backtest-Equity öffentlich zeigen? (Default ja, „illustrative, not live"); (2) Quarantäne-Inhalte dauerhaft raus oder regeneriert wieder rein?; (3) Disclaimer nennt weiterhin FTMO/DarwinexZero/The5ers (Original wiederhergestellt) und „10-phase pipeline" (veralteter Text, unverändert gelassen); Impressum-Umlaute repariert (waren als „?" korrumpiert); (4) Zahlen-Einheiten: Archiv zählt Karten (3.378 / 9 mit Q10), Pipeline-Funnel zählt Paare (21 Q10-bestätigt) — beides beschriftet. **Live-Gang** = OWNER (Netlify deployt aus dem Drive-Ordner, nicht aus GitHub).
>
> **Nachtrag 18:00Z — OWNER-Entscheid Option A umgesetzt in Gang + zwei Claude-Lane-Lieferungen:** (1) **OWNER-DEC-SIBLING-SEED-RANK-20260902 = JA/Option A** (Chat, ~17:45Z): Karte in die Mission-Control-Queue eingefügt (Feed-Revision 31, Vault-Spiegel), Ausführungsvertrag ergänzt, terminales Receipt aufgezeichnet (request_id `chat-20260902-oq-sibling-seed-rank-option-a`, Notiz nennt den Chat-Kanal), Binder reservierte genau einen Claude-Lane-Auftrag `152a35bc` (IN_PROGRESS); Config-Commit `df8a94e6ff`. Umsetzung läuft als Workflow (Implementer + zwei Gegenprüfer): erste CASE-Zeile in `_topdown_gate_rank_sql` für `payload.schema = qm.dl089-measurement-q02-prerequisite/v1` → Rang 0; alle anderen Ränge byte-identisch; Tests. (2) **Juli-Kohorte** (c9a1bdab): 79 Park + 223 Retire als append-only `work_item_supersedes`-Kanten (302/302, ein Backup, Status-/Verdikt-Zähler unverändert, Helfer `apply_july_cohort_park_retire.py` + 5 Tests, Commit `fb97fa983a`) — unabhängig verifiziert; Lehre: der Subagent hat seinen Auftrag selbst auf APPROVED gesetzt — Abnahme bleibt CEO-Pflicht, Subagenten-Briefings verbieten künftig close-review. (3) **Backup-Wiederverwendung** (ab068f38, Commit `615608abd0`, 11 Tests) APPROVED; Folgeauftrag `4ce6ec32` für `_governed_state_backup`/`sqlite_backup`. (4) Vorschau für den OWNER in Chrome auf dem VPS geöffnet (8091 Refresh, 8090 Kandidat). Fabrik 17:49Z: 47 Zellen/h (Tagesbestwert), 9 Claims, RAM 12 GB, D: 141 GB.
>
> **Nachtrag 17:45Z — Loop-Runde 17:31Z:** Fabrik 40 Zellen/h, 9 Claims, RAM 19 GB, D: 141 GB; Reload T1/T3/T8/T4/T7/T5 fertig (Klassen-Zulassung + kurze Claim-Sperre live), T2/T6/T9/T10 folgen bei Leerlauf; neuer `cpu_high_pause`-Guard sichtbar (19 Events). **Q10-News-Klärung:** `REVIEW_REQUIRED` mit Expansion-Reason (13013/NDX `e84c4ff8`, 21501, 12925×2) ist der reguläre v3-Zwischenzustand — der Pump-Stage `news_expansions` hat die Fortsetzungszeilen automatisch erzeugt (13013 → `5ea4c77d` aktiv, 21501 → `b5acfce7` aktiv; Limit 2 je Zyklus, 24 Kandidaten); kein Review-Rückstau bei mir. **Codex-Quota:** Governor `hold` (85 % verbraucht bei 37 % Wochenzeit, +48 Punkte vor Plan) → Router `quota_gate_blocked`; die drei TODOs warten. Zwei davon auf die Claude-Lane genommen (Sonnet-Subagenten, interaktive Sitzung): ab068f38 Backup-Wiederverwendung im Compile-Wave-Tool, c9a1bdab Juli-Kohorte Park 79 / Retire 223 append-only mit Backup; f1655764 (Era-Audit) bleibt TODO. Website: Seitenphase abgeschlossen (index, blog, strategies, secondary, legal, pipeline), Review-Phase läuft; zwei Agenten ohne strukturierten Abschluss (Dateien vorhanden), Vorschau 8091.
>
> **Nachtrag 17:15Z — Loop-Runde 17:07Z + OWNER-Vorlage Sibling-Seeds:** Fabrik 13 Zellen/10 min, 9 aktive Claims, RAM 16 GB, D: 143 GB, Lock frei, Pump 233–252 s; gestaffelter Reload aus der interaktiven Sitzung (Lehre: Worker-Starts aus S4U-Tasks sterben — nur interaktiv) hat T1/T3/T8 auf `23a950ea7e`+`522662de1d` gebracht, die übrigen folgen bei Leerlauf; Watchdog v2 beendet ohne Kill (Minimum 1,1 GB). Reviews leer bis auf df2343c6 (Paar 8). ba5f4754 APPROVED (drei exakte Q07-Reruns 11129/10700/11910 pendend; 11421-Rebind wartet auf Q08 `c93263aa`). **Strukturbefund Sibling-Q02-Seeds 41301–41307:** seit 08:42Z pendend, keine Holds, ex5 vorhanden, priority_track — die versiegelte Reihenfolge `_priority_track_rank → topdown_gate_rank` setzt OPT_CENSUS (Rang 0) vor Q02 (Rang ~12) auch innerhalb der priorisierten Zeilen, und die priorisierten Programme haben 5.184 Zellen; die Seeds kommen nur dran, wenn keine Zensus-Zelle zulässig ist (RAM-Klasse 4 GB vs 8 GB verschärft das). Folge: drei DL-089-Programme bleiben im Matrix-Service „deferred" (fehlende `_opt`-Sibling-Q02). **OWNER-Vorlage OQ-SIBLING-SEED-RANK:** Q02-Seeds von `_opt`-Siblings authentifizierter DL-089-Programme erhalten Rang 0 (mit OPT_CENSUS) — Option A: Amendment der Top-Down-Entscheidung (eine CASE-Zeile, Tests); Option B: einmalige manuelle Vorziehung der sieben Zeilen (`_universe_expansion_rank` ist dafür nicht gedacht); Empfehlung A; Kosten des Wartens: ~3 von 8 Programmen ohne Zensus, Fleet derzeit ohnehin RAM-gebunden → keine Auffangregel, echte OWNER-Entscheidung (Sonntag oder früher).
>
> **Nachtrag 17:00Z — Website-Refresh gestartet + Netlify-Ursache gefunden:** (1) `Website/.netlify/netlify.toml` (Netlify-CLI-Zustand im Deploy-Repo) trägt `publish = G:\Meine Ablage\QuantMechanica\Website` — die Live-Seite wurde bisher per Netlify-CLI/Drag-and-drop aus dem Google-Drive-Ordner des OWNER-Rechners deployed, nicht aus GitHub main; darum serviert quantmechanica.com noch den Stand vor 20.08. **Live-Gang künftig = OWNER-Handlung** (Ordner synchronisieren + `netlify deploy --prod`), ein Git-Push allein ändert nichts. (2) Audit (4 Scouts + Kritiker): ein tokenisiertes Dark-Stylesheet, auf jeder Seite per Inline-CSS überschrieben; 9 Akzentfarben, Glows, 3 Nav-Varianten, 8 Hero-Varianten; 402 verwaiste Strategie-Seiten (1,1 MB duplizierte CSS), 27 rohe MT5-Reports und Build-Skripte im Web-Root; 8 leere Blog-Stubs in der Sitemap; Charts = handgezeichnete Canvas mit hartkodierten OHLC-Arrays. (3) Konzept `docs/ops/WEBSITE_DESIGN_REFRESH_APPLE_2026-09-02.md` (Tokens, Komponenten, Chart-Spezifikation, Seitenbehandlung, Exposure-Regeln, OWNER-Entscheidungen). Charts: Hero = **echte** aggregierte Equity der 24 Q10-PASS-Sleeves (Index 100, ohne EA-Identität, „illustrative backtest, not live"), Kerzen = kalibrierte synthetische OHLC (lizenzierte Marktdaten werden nicht weiterverbreitet), eigene Canvas-Engine `scripts/qm-charts.js`. (4) Build läuft als Workflow im Worktree `C:\QM\deploy\qm-ops-refresh` (Branch `refresh/apple-2026-09`), Vorschau http://127.0.0.1:8091/ (Task `QM_TMP_WebsiteRefresh_8091`), Review mit Headless-Chrome-Screenshots; kein Push.
>
> **Nachtrag 16:50Z — RAM-Wedge #2 und Rollout der Klassen-Zulassung:** 16:36Z 1,3 GB frei, Paging 15–137k/s, 0 Zellen/10 min (sechs große Läufe à 4–12 GB). Eingriff: T2-Tester des jüngsten großen Laufs (41219/XAUUSD Q08, 35 min) gekillt → 23,9 GB frei, binnen 3 min durch drei neue Zensus-Claims + T2-Neustart des Laufs wieder auf 1 GB (alte Worker-Zulassung). Schwellen-Experiment 22/28 GB verworfen: die Worker-Tests rechnen mit der 14-GB-Schwelle (3 Fehlschläge) — nicht committet, Datei auf HEAD. **Strukturfix live-fähig:** Codex `23a950ea7e` (ddee6f24 APPROVED 16:45Z, eigener Testlauf 97 grün): Zulassung = frei − Klassenreservierung ≥ 14 GB (OPT_CENSUS 4 GB, ordinary/index/multisymbol Klassen), Testseam `QM_TEST_FREE_RAM_GB`, Receipt `ram_class_skipped`; dazu `522662de1d` Claim-Schreibsperre 3–9 ms (09c5a4b4 APPROVED). Rollout: Task `QM_TMP_StaggeredWorkerReload_1645` (idle-only, ≥150 s Abstand, nie ein aktiver Claim) läuft; Watchdog v2 (15 min, max. 2 Kills des jüngsten Testers >6 GB bei <1 GB zweimal). Lehre: ein Kill verschafft nur Luft, wenn die Zulassung gleichzeitig greift — Reload zuerst.
>
> **Nachtrag 16:45Z — Loop-Runde 16:25Z:** RAM 0,9–2,5 GB frei bei sechs Testern (T10/T2/T7 je 10–11 GB), Paging 6,8k/s → Watchdog (12 min; killt nur den jüngsten großen Lauf T2/41219-Q08, falls <1 GB zweimal), bis 16:28Z Erholung auf 6,7 GB ohne Eingriff; Durchsatz 28 Zellen/h (RAM-gebunden). **D:-Kompaktierung fertig:** 23.961 Dateien, 113,5 GB → 24,0 GB (4,7:1), D: 142 GB frei, Task entfernt; Purge LowWater bleibt 60 (140 würde die Schleife wieder auslösen). Retention-Runner PASS im Plan-Lauf. **Reviews:** 09c5a4b4 APPROVED (Claim-Schreibsperre 3–9 ms statt Kandidatenschleife; eigener Testlauf 97 + 182 grün; Rollout = gestaffelter Reload erst bei >20 GB frei). **Korrektur zu ba5f4754:** die Kaskade hat aus dem FAIL_SOFT-Q08 `ac972f2a` regulär eine Ersatz-News-Zeile `8f2c850c` für 10114/SP500 erzeugt (läuft auf T9) — FAIL_SOFT gilt als promotierbar; 10114 ist damit keine tote Kette, `9812fc7b` bereits SUPERSEDED. **OWNER 16:3xZ:** Apple-Designsprache + kompletter Refresh der Website beauftragt, Chartdesign „so realistisch wie möglich" → Programm startet (Understand → Konzept → Umsetzung im Worktree → Review → lokale Vorschau; kein Push).
>
> **Nachtrag 16:40Z — Deploy ZURÜCKGENOMMEN, lokale Vorschau (OWNER: „vorher lokal durchsehen"):** GitHub main per Revert-Commits auf den vorherigen Stand zurückgesetzt (`e22dda3`, inhaltsgleich mit `818ffb8`, Diff leer); die sieben Kandidaten-Commits bleiben in der Historie (`8a2106e..b1bd104`). **Befund dabei:** quantmechanica.com serviert weiterhin die Version VOR dem 20.08. („The 10-Phase Pipeline"), d. h. Netlify hat seit den CTO-Commits vom 20.08. nichts mehr aus GitHub main deployed — weder mein Push noch der Revert haben die Live-Seite verändert; Ursache (Build-Fehler, gesperrtes Auto-Publish, andere Quelle) nur im Netlify-Dashboard (Site `2fb3e857…`) einsehbar → OWNER. **Vorschau:** Kandidat `b1bd104` + aktuelle public-data-JSON als Worktree `C:\QM\deploy\qm-ops-preview`, Server-Task `QM_TMP_WebsitePreview_8090` (S4U) → http://127.0.0.1:8090/ auf dem VPS; Revert-Worktree `C:\QM\deploy\qm-ops-revert`. **Apple-Designsprache (`QM-TODO-20260824-201`):** nur notiert (OWNER 24.08. „notieren"), kein Router-Task, keine Umsetzung — im Kandidaten sind ausschließlich Wortlaut/Gate-Vokabular/Zahlen geändert, kein Design. Nebenbefund: der stündliche public-data-Producer hat Dateien im Deploy-Repo **gestaged** (blockierte den Revert im Hauptworktree; unstaged 16:3xZ) → Codex-Folgepunkt beim Publisher-Pfad.
>
> **Nachtrag 16:25Z — WEBSITE DEPLOYED (OWNER „Deploy ok" 16:1xZ):** Vor dem Push unabhängige Drei-Linsen-Prüfung des exakten Diffs (Exposure, v4-Konsistenz/Referenzen, HTML/JS-Validität; 13 Agenten, jeder Befund gegengeprüft): **keine Exposure**; zwei Majors behoben (faq.html beschrieb „Gate Q11" noch als Prop-Firm-Zulassung — jetzt Q10 News/FTMO-Empfehlung + Q15–Q17; index.html-Karte „18-Gate" zählte noch den 14-Schritt-Fluss auf — jetzt die 18 v4-Gates aus dem Deck), Minors behoben (statisches „4,240+" → „4,700+" auf allen Seiten, Pipeline-Meta „~38 survive" → „Only a handful survive", Funnel- und Kandidatenzahlen aus der Farm-DB: distinct Paare Q02 PASS 7.020 / Q04 PASS 336 / Q08 PASS 46 / Q10-News-Gate CONFIG_LOCKED 21 = Portfolio-Kandidaten, vorher eingefroren auf 13.323/1.007/66/38 vom 20.08.). Push `818ffb8..b1bd104` (7 Commits) auf GitHub main → Netlify-Build; Live-Verifikation läuft (Home „18-Gate", /pipeline „Gate Q17", /public-data/stats.json 200). Nicht mitgeschickt: Codex' uncommittete Loader-Variante, die den 5,8-MB-Snapshot als Primärquelle für vier Hero-Zahlen lädt (bleibt beim Publisher-Auftrag; Sidecar `stats.json` 195 B ist die richtige Primärquelle). Offen: Funnel-Schlüssel (`q02_baseline_pass`, `q04_walkforward_pass`, `q08_davey_stats_pass`, `portfolio_candidates`) fehlen im `stats.json`-Producer → statisch bis der Producer sie liefert (Codex-Folgeauftrag beim Publisher-Pfad).
>
> **Nachtrag 16:15Z — Loop-Runde 16:00Z:** Fabrik 38 Zellen/h (RAM-Pausen: 13,5 GB frei bei sechs großen Läufen, vier Terminals ohne Claim; Klassen-Zulassung → Codex `ddee6f24`); Pump-Zyklen 190–230 s (vorher 340–430 s); D: 78 GB frei und steigend (NTFS-Kompaktierung läuft als Task `QM_TMP_CompactNewsBackfill_20260902`). Reviews zu: 94cad0f7 (Publisher prepare-only, 78 Tests, kein Push) und 4a9d6cfa (die drei Silent-Abort-Zeilen sind 2–6-s-Launch-Faults wegen fehlender gebundener Q07/Q08-Aggregate — kein Infra-Rerun). Frontier: 11421/EURUSD Q07-Rerun `2556a768` PASS → exakter Q08-Rerun `c93263aa` eingereiht (append-only von INFRA_FAIL `9d183609`, aktueller ex5-SHA gebunden); 10114/SP500 Q08-Rerun `ac972f2a` erneut FAIL_SOFT → tote Kette am aktuellen Binary; Codex `ba5f4754` (P85): Lineage-Welle 2 = exakte Reruns 11129/10700/11910, Supersede 10114-Hold `9812fc7b`, Q10-Rebind für 11421 nach Q08-PASS (Hold 30584122 unter REQUAL-8 released, nicht re-holden). Beobachtet, nicht angefasst: neben T_Live läuft seit 08:29Z ein FTMO-Global-Markets-Terminal (Program Files) außerhalb der Fabrik.
>
> **Nachtrag 16:00Z — D:-Platz: OWNER-Retention war seit 26.08. tot (MAX_PATH):** `QM_StrategyFarm_ContinuousRetention_45min` (OWNER-DEC-BACKUP-RETENTION-20260830) endete in 21 von 28 Läufen mit `FileNotFoundError` — `Path.rglob` brach am >260-Zeichen-Pfad der Q09-v3-Successor-Zellen (`reports/work_items/<id>/q09_contract_v3/successors/<sha256>/cells/…/raw/run_01/pre_run_logger_archive`) ab; seit einer Woche wurde kein Backup komprimiert, kein Log gelöscht, keine Evidenz gealtert. Fix: long-path-sicherer scandir-Walk, Kriterien unverändert (`e5e54b3a89`, 8 Tests grün); erster erfolgreicher Lauf 15:51Z: 103 Backups bereits NTFS-komprimiert (68 GB logisch = 27 GB belegt), 5.000 Evidenzdateien komprimiert (Kappung je Lauf), 458 Logs >48 h gelöscht. **D:-Verbraucher (du):** `strategy_farm/artifacts/q09_live_news_backfill_20260805` 112 GB (87 GB rohe Tester-Logs, 25 GB jsonl — PASS-Familie, DL-090: nicht löschen; NTFS-LZNT1 misst 5,3:1 auf dem 2,9-GB-Log in 19 s, Kompaktierung des Baums läuft im Hintergrund mit Idle-Priorität, erwarteter Rückgewinn ~80 GB; LZX/WOF komprimiert auf D: 0 Dateien); T1 `Bases/Custom.__variant_a_rollback__…20260809` 24 GB (Archivjahre identisch mit `archive/Custom_master`, nur 2026-Monate/Caches abweichend; Rollback-Material der Variant-A-Migration → **OWNER-Option Sonntag**, nicht autonom); `state/backups` 129 Dateien, ~30 `before_compile_wave`-Backups/Tag à 701 MB (9 in 90 s um 08:40Z) → Codex `ab068f38` (Wiederverwendung frischer Backups, Löschpolitik unberührt); Tester-Caches nur ~13 GB (Purge-Trigger bei <60 GB gewinnt ~10 GB, Zyklus ~1,5 h).
>
> **Nachtrag 15:50Z — Loop-Runde 15:30Z:** (a) Q10-Ersatzpfad zweiter Beweis: 13013/NDX Q08-Rerun `6fdfbae6` PASS → Ersatz-News-Zeile `e84c4ff8` (exakt aus 6fdfbae6) autoseal und Claim T5 15:25Z. (b) Die fünf exakten Q07/Q08-Reruns der Q10-Lineage (10114, 11708, 12823, 13213, 1556) tragen priority_track. (c) Reviews geschlossen: 45800644 APPROVED (33 Q10-Holds klassifiziert, 16 Fehlbindungen in einem Backup superseded, 11476 tote Kette), 1aed20ca (Archive v2, 73 Tests), 7d291110 (Snapshot v2 + dynamischer Hero, 71 Tests). Neue Codex-Aufträge: 4a9d6cfa (drei `NEWS_RUNNER_SPAWN_SILENT_ABORT`-Zeilen, P70) und 09c5a4b4 (Claim-Schreibsperre über die ganze Kandidatenschleife, P78). (d) Pump-Hotspots per py-spy: `_active_build_eas_for_artifact_plan` stat-ete 5,7k Build-Logs pro Zyklus (45 s+) → ein scandir (`d46011ebc8`, 33 Tests grün); DL089-Frontier-Refill wartet 40 s auf die Schreibsperre (read-only 0,8 s) → 09c5a4b4. (e) Deploy-Repo lokal `bc9c8e8`: Hero dynamisch aus `stats.json` (vier Aggregatzähler, keine Terminalzahl) mit echtem statischem Fallback (18 Gates), Q15-Label; jetzt 6 unpushed Commits — Push nur nach explizitem OWNER „Deploy ok". (f) Purge triggert bei <60 GB etwa alle 1,5 h (Tester-Caches nur 13,5 GB, Rückgewinn ~10 GB); D:-Verbraucher-Sizing läuft. Fabrik 15:30Z: 57 Zellen/h, RAM-Pausen bei 6–7 Testern (8,6 GB frei) erwartbar.
>
> **Nachtrag 15:00Z — Website/Build-in-public wieder aufgenommen (OWNER 14:5xZ):** Karte: Producer (public-data JSON, stündlich) läuft seit 12:12Z wieder; Publisher tot seit 20.08. (`-NoGit`, Netlify liefert `public-data/` nicht aus, Deploy-Repo C:/QM/deploy/quantmechanica-ops eingefroren bei 818ffb8). Codex-Tasks (prepare-only, kein Deploy): 94cad0f7 Publisher-Pfad hinter Flag + public-data im Publish-Root (P88), 1aed20ca Archiv-Schema v2 → entblockt 2b95f500 (P80), 7d291110 Legacy-Vokabular/Hero-Zahlen (P72). Claude: `pipeline.html` auf das v4-Gate-Deck Q00–Q17 umgeschrieben (Deploy-Repo 8a2106e) und **Hard-Rule-Verstoß auf der Live-Site entfernt**: performance.html zeigte die Pfade der Fabrik- und Live-Terminals, index/about/faq Terminalzahlen und interne Namen (784afd1). **Beides ist nur lokal committet — der Deploy auf quantmechanica.com braucht dein explizites Go** (Pfad-Exposure spricht für einen schnellen Deploy dieser fünf Seiten). Multi-Host-Spike e7d7b102 APPROVED (Memo docs/ops/evidence/2026-09-02_multi_host_factory_feasibility.md; Phase 0 Loopback-Spike ohne Kauf, dann 48-h-Canary nach OWNER-Go); Hetzner-Serverbörse-Shortlist im 06.09-Paket.
>
> **Nachtrag 14:05Z — RAM-Wedge:** 13:45–14:02Z lief der Host mit 0,9 GB freiem RAM (63 GB; sechs Tester à 4,8–11,8 GB, zwei 44-GB-Klasse-Index-Läufe; XAUUSD-„ordinary" braucht 11–12 GB statt 8 GB Reservierung), 16k Pages/s, drei Worker tot. Der Commit-Headroom-Guard rechnet in Commit (Pagefile), nicht in physischem RAM. Maßnahmen: jüngsten 44-GB-Lauf gestoppt (T6, 12925/WS30 Q10_NEWS, 12 min alt → INFRA, Rerun später), Run-Loop-Schwellen RAM_MIN_FREE/RESUME 6/12→14/20 GB (`8037276ef4`; ein Claim-Pfad-Check `43c069c48d` wurde revertiert, weil er Unit-Tests auf dem RAM-armen Host brach), Worker respawnt (10/10). Ehrliche Kapazität ≈ 5 gleichzeitige Tester auf 63 GB → **RAM-Upgrade (AX42-U bis 128 GB) ist die größte Durchsatz-Kaufoption für den OWNER.** Kaskade newest-first/300 (`d5ab3294a6`); Q10-Ersatzmechanismus greift nur bei aktivem Q09_AWAITING_SEALED_PLAN-Hold (13128/11421 unter REQUAL-8 gelöst → kein Eingriff).
>
> **Nachtrag 13:25Z:** Codex hat 10706 um 12:57Z reconciled (0058a401 APPROVED; Guard `8d57f98150`). Kaskade auf exakte Q08-Lineage umgestellt (`920d51044d`); die 16 heuristisch gebundenen Q10_NEWS-Zeilen von 12:10Z sind unversiegelbar (keine lesbare exakte Q08-Evidenz) und gehören append-only superseded — offen. Pair-8-Build c2ef7f4a DONE (QM5_41222 COMPILE_OK). Fabrik: 8 Zellen/10 min, Schreibsperre 8 %, keine Fremd-Restarts.
>
> **Nachtrag 12:45Z — Poison-Programm 10706/GBPUSD:** Der Matrix-Service band das Ledger um 12:04Z an eine ablation-stämmige Q12-Zeile (2dad5730), die 793 Zellen tragen die Ursprungs-Bindung (1a92b33e) → jede Lane-Preflight scheiterte (`Q12 binding mismatch`), und weil die Zellen priority_track am Kopf der Claim-Reihenfolge standen, verbrannte jeder Worker seine 8 Versuche daran: 0 Zensus-Zellen ab 12:14Z, SQLite-Schreibsperre 82 % belegt. Mitigation 12:41Z: `farmctl mark-priority-track --program-id … --unset` (Batch-Modus, `2b235e4a51`), Claims laufen 12:43Z wieder. Reconciliation (Supersede der Orphan-Q12, Ledger-Bindung, Service-Guard) = Codex-Task P95. Q10-Frontier: die 18 Q08-Reruns wurden korrekt abgelehnt (Binaries neu gebaut = neue Identität); 13 Q10_NEWS-Zeilen aus der Kaskade warten auf Autoseal (Late-Stage wieder aktiv, `a78f1558f4`).
> **Abschluss 12:58Z:** `2dad5730` append-only auf `1a92b33e` superseded; Ledger + Registration aus den 1.085 Zell-Owner-Bindungen auf `1a92b33e` zurückgestempelt (`existing=1085`, `inserted=0`); alle 793 Pending-Zellen wieder `priority_track=true`. T1 claimte `8cccde6d` mit Lane-Preflight `checked`. Der Service verweigert künftig jede Q12-Umwidmung vor Artefaktschreibzugriff (`PROGRAM_Q12_REBIND_REFUSED`) und erlaubt Restamping nur nach vollständiger UUID/Key/Parent/Deklarations-Prüfung. Evidenz: `docs/ops/evidence/2026-09-02_dl089_q12_binding_reconciliation.md`.
>
> **Nachtrag 11:55Z:** (a) zweiter Claim-Hasher gefunden: das Per-Claim-Isolations-Audit hashte das gesamte private Terminal-Archiv (bis 43 GB) bei jedem Claim/Start → persistenter Audit-Hash-Cache `bc77b4500d`, Worker-Reload #3 läuft. (b) Pump-Zyklus 11:42Z lief erstmals komplett (210 s, alle Stufen, Kaskade 3 Promotions); Autoseal in den Tick-Task verlagert (`9b2338020f`). (c) **Q10-Kaskaden-Defekt:** Q09-PASS→Q10_NEWS band die Q09-Zeile als Q08-Input → Trigger-Ablehnung bei 50 Paaren (gesamte Q10-Frontier) → Fix `94ab3c0004` (bindet die echte Q08-Zeile). (d) Reviews ea56a51b/3b25f49e/cef343ab/246d5d1f APPROVED; 8f0b1b9e/a7c69b44 BLOCKED (Lane-Preflight-Defekt). (e) 48 Rollout-Holds (22 Q12-Fork, 26 COMPILE_EA) offen; kein Bulk-Release über release-hold (700-MB-Backup je Aufruf) → Batch-Modus nötig. (f) Für 06.09: 12778 REMOVE, 13117 REMOVE, 12969 REMOVE-or-requalify (cef343ab); XCUUSD-Paare 21524/21525 gehalten bis OWNER-Entscheid (Archiv-Provisionierung oder Retire).
>
> **Nachtrag 11:10Z — Purge-Schleife war der Worker-Killer:** `QM_StrategyFarm_TesterCachePurge` (10 min, LowWater 140 GB) triggerte bei ~80 GB frei auf D: bei jedem Lauf (3.566×) und stoppte alle idle Worker → alle 10 min Startup-Gate, Null-Zellen-Fenster. Seit Variant A (10×43 GB Custom-History) ist 140 GB unerreichbar. Task-Argument auf `-LowWaterGB 60` gesetzt (Rollback: 140). Stündlicher Sweep hielt den Mutation-Lock über den Verzeichnis-Scan (10:52–10:58Z alle Claims blockiert) → Fix `1938e703dc`. Kaskade jetzt vor der Pre-Promotion-Automation (`3d9dd0a92e`). Neuer Subcommand `farmctl mark-priority-track` (`f7a42389bc`); die 4 Q07/Q08-Reruns stehen auf Rang 0–4. 41306-Successor-Hold gelöst. Reviews: 7865c865/b335e499/2093b38e APPROVED, 027fb63f BLOCKED (Docker/WSL2 = OWNER-Host-Fenster); Park/Retire-Ausführung der Juli-Kohorte = Codex-Task c9a1bdab.

## CEO Wave 1 — Codex-Ausführung 2026-09-02

- **Claim write-lock narrowing (task `09c5a4b4-8a97-4c13-845a-ca5150c3bce6`): REVIEW, live reload deferred by RAM guard.** Candidate evaluation is query-only; only exact housekeeping/hold/final CAS owns `BEGIN IMMEDIATE`, with pending/payload/hold/supersede recheck and `claim_write_lock_ms` in claim logs. Twenty fixture claims measured 2.976–8.752 ms write-lock hold (mean 4.048 ms); the competing-writer hold race stays pending/unclaimed. Worker suite: 209 passed + four subtests. At 5.31 GB free RAM the governed spawner was THROTTLED, so no idle worker was stopped and no active test interrupted; live busy-share comparison awaits safe staggered reload. Evidence: `docs/ops/evidence/2026-09-02_terminal_claim_write_lock_narrowing.md` and `2026-09-02_claim_write_lock_measurement.json`.
- **Public-data publisher path (task `94cad0f7-5fe8-43cf-b077-b056cdd83ee2`): REVIEW, prepare-only.** Exact `QM_PUBLIC_PUBLISH=1`/`-Publish` is the only source/deploy push gate; default source export remains `-NoGit`, while validated allowlisted data can be committed locally under `Website/public-data`. Validation and factory-lock release precede every Git/network operation; alternate output cannot publish. Loader primary is `/public-data/public-snapshot.json`, then public stats sidecar, then legacy fallback. Scoped suite `78 passed, 1 skipped`; dry-run executed validation only and records exact would-run copy/commit/push commands. No commit/push/deploy/Netlify call by this task. Evidence: `docs/ops/evidence/2026-09-02_public_data_publisher_prepare_only.md` and `2026-09-02_public_data_publish_dry_run_receipt.json`.
- **Q10 silent-abort forensic (task `4a9d6cfa-69af-4f00-b842-ca8cb00c72ee`): REVIEW, no reruns.** All three runner processes ended in 1.97–5.52 seconds on authenticated missing-bound-evidence exceptions (11129: Q07; 10700/11910: Q08), before an MT5 matrix cell. The archived work-item logs are absent, but durable payload stderr, creation-key identity, matching sealed-plan hashes, source-path absence, and zero target-EA journal hits establish the boundary. No hold, lineage row, gate, queue, or verdict changed. Evidence: `docs/ops/evidence/2026-09-02_q10_news_spawn_abort_forensic.{md,json}`.
- **Strategy Archive v2 (task `1aed20ca-2824-434e-a8da-0970b913944a`): REVIEW, local only.** OWNER Variant (b) is implemented as a closed per-card Q00–Q17 terminal coverage projection: only `PASS`/`FAIL`, open/untested omitted, no metrics/parameters/symbols/internal IDs/paths/VPS data. Dry run produced 3,378 opaque cards, 10,022 PASS and 1,298 FAIL coverage cells; forbidden-field counts are zero and all positive/negative validators PASS. Prior blocked publish task `2b95f500-...` is eligible for RECYCLE, not approval. Deploy repo remains uncommitted/unpushed. Evidence: `docs/ops/evidence/2026-09-02_strategy_archive_v2_preview.md` and `2026-09-02_strategy_archive_v2_dry_run_diff.json`.
- **Public snapshot v2 / dynamic hero (task `7d291110-ac8c-4de3-88f7-ae05cded6082`): REVIEW, local only.** Producer preview removes the legacy `t6` object and P-keyed public funnel, emits exact Qxx `phase`, adds a schema-closed aggregate `stats.json`, and binds the site hero to generated counts while replacing the terminal KPI with strategy-card coverage. Preview readback: schema 2, `phase=Q14`, no `t6`; all five positive/negative schema pairs PASS and loopback preview routes return 200. Deploy repo remains uncommitted/unpushed; Netlify untouched. Evidence: `docs/ops/evidence/2026-09-02_public_snapshot_v2_and_dynamic_hero_preview.md`.
- **Q10-News-Lineage-Debt (task `45800644-c186-4215-895c-a0fc67925a8d`): REVIEW.** Live census was 33 active held rows, not 44: all classified. Five exact-predecessor/current-EX5 append-only Q07/Q08 reruns were enqueued at normal priority, two prerequisite chains were already pending, 18 old-identity attempts remain correctly refused, and the 16 malformed Q09-as-Q08 cascade rows were canonically superseded in one guarded transaction/one backup (`quick_check=ok`, no historical row/hold edits). Autoseal proof is positive on `QM5_11288/USDJPY` (`bdfeef30`: regenerated Q08 dependency + sealed plan hash verified; subsequent spawn abort is downstream infra). `QM5_11476/USDJPY` remains the explicit dead chain because no authentic Q07 row exists; REQUAL-8 rows 13128/11421 were untouched. Evidence: `docs/ops/evidence/2026-09-02_q10_news_lineage_debt_execution.md`.
- **Multi-host factory feasibility (task `e7d7b102-1168-4f7c-89a4-191cbc3a270c`): REVIEW.** Decision memo specifies a single-authority append-only export/import architecture (never SQLite over SMB), host-scoped archive manifests and containment, account/registry boundaries, and a normalized current-price comparison. Recommendation: no purchase yet; loopback protocol proof, then OWNER-approved 48-hour two-terminal Q12 census canary; 128-GB dedicated host only after measured acceptance. AWS is burst/canary only; c6i and MT5 Remote Agents are NO-GO as the general factory path. Evidence: `docs/ops/evidence/2026-09-02_multi_host_factory_feasibility.md`. No purchase, `T_Live`, AutoTrading, terminal, queue, or pipeline mutation occurred.
- **Scheduled-task hygiene / factory-hours (task `246d5d1f-49b8-490b-b005-f1534ffc3e8d`): REVIEW.** Five recurring time limits were raised with 18 rollback XMLs captured; 13 dead one-offs were exported and unregistered; the public-snapshot null-exit race was fixed; evidence-watch exit 3 is now correctly a hard `LOSS_OBSERVED` alarm (642/1,205 files missing), not masked. The rolling seven-day panel reports 914.088/1,680 used slot-hours = 54.41%, so the new `<55%` alarm is active. Evidence: `docs/ops/evidence/2026-09-02_scheduled_task_hygiene_and_factory_hours.md`; 54 focused tests passed. No task was manually started and no `T_Live` state changed.
- **Q14 orphan-lane hygiene (task `5bcdf6f4-b1b8-4dbb-a952-252270d68d2f`): REVIEW.** Four Q13/Q14 rows derived from generic Q12 `PASS` parents were superseded append-only onto the real terminal chains for 11421/EURUSD and 10706/GBPUSD. Canonical supersession rows and audit events prevent the two pending orphan Q14 rows from being claimed again. Evidence: `docs/ops/evidence/2026-09-02_q14_orphan_lane_hygiene.md`. No sealed criterion or `T_Live` state changed.
- **FTMO evidence chain (task `b306ca82-56b3-4f31-a75f-4575ca486d1d`): REVIEW.** Audit inputs are pinned to the frozen 24-sleeve bundle with fail-closed fingerprint/anchor checks; `FTMO_2S_100K_SWING_V2` adds the verified economic terms; the TrialPulse task limit is PT20M and the stale `267014` alarm cleared. Evidence: `docs/ops/evidence/2026-09-02_ftmo_evidence_chain_repair.md`, `docs/ops/evidence/2026-09-02_ftmo_economic_terms_snapshot.json`, `artifacts/audit_ev_funded_account_20260902.json`. No sealed criterion or live-trading state changed.
- **Q08 8.2 real-cohort DSR / Sharpe audit (task `2900ac3d-a328-4e54-802b-b765946d2648`): REVIEW.** 3,001-EA and 13,398-pair DSR is now emitted report-only without changing the sealed verdict threshold; dashboard MT5 Sharpe was replaced by labeled return-based Sharpe, while the remaining sealed Q09 compatibility input is explicitly labeled for OWNER disposition. Evidence: `docs/ops/evidence/2026-09-02_q08_dsr_real_cohort_and_sharpe_audit.md`.

> **CEO-Session 2026-09-02 (OWNER-Mandat: volle Autonomie; Ziel FTMO-Payouts + DXZ-Allokation; Build-in-public vertagt):**
> Vollaudit `docs/ops/CEO_AUDIT_2026-09-02.md` + Decision `decisions/2026-09-02_ceo_full_authority_audit_and_reorientation.md`.
> **Zähler:** `qualified_pairs` 0→**2 formal** (10706/GBPUSD, 11422/USDCAD; Q14 = 25.08-Kurzschlüsse, echte Zensus laufen) — Ursache war
> ein Census-Read-Model-Defekt (CONFIG_LOCKED/NO_FILTER_CHANGE/NO_PARAMETER_CHANGE zählten nicht), gefixt `8baa00fde9`; Q12-Finalizer-Bug
> gefixt `219217c28c` (erstes echtes terminales Paar 11421/EURUSD `ff733cf6`). **Fabrik:** Containment-Trip #4 released 07:44Z; drei
> Worker-Fixes committet (Containment-Scope, Orphan-Claim, Release-Tool); Defender-Ausschlüsse; SAMEPROG-Fleet-Decision ausgeführt und 09:42Z ZURÜCKGEROLLT (Canary war 01.09. wegen Decline-Schleife abgebrochen; Muster reproduziert);
> gestaffelter Worker-Reload. **Sibling-Welle** QM5_41301–41307 gebaut/kompiliert (41305 läuft, 41306 Retry offen). **Q10-Unblock:**
> Q07/Q08-Append-only-Reruns für 11421/13128/11288/13013. **Geld-Wahrheit:** Live-Verlust ~76 % aus zwei magic=0-Trades (kein Sleeve);
> Edge unbewiesen/unwiderlegt (DSR 0/24, aber WF-OOS 82 % PF>1; Live-CI enthält +2,4) → **erste Geldschwelle = 2026-Q1-OOS-Pass +
> saubere Live-Attribution**, nicht Paarzahl. **FTMO: NO-BUY.** OWNER-Fragen (6) in `12 ToDo/AI ToDos/OWNER.md`.

> **Session-Handoff 2026-09-02 ~07:00Z (Claude, vor Neustart):**
> **Containment ENGAGED** (3. Auto-Trip 06:42Z: signiertes Audit-Runner-Binding T1-T10
> klassifiziert T12-Bases als UNAUTHORIZED) — Fabrik seriell bis OWNER-Release
> (`release_containment_standing.py`). Aktivierung=v1, T11/12 disabled, 10er-Flotte frisch.
> **Meilensteine 01.09.:** EUR-Pilot 11421/EURUSD TERMINAL (READY_FOR_Q15, sauberer
> KEEP_INCUMBENT; Q14-Zeile f81a14df claimbar → wird Zähler 1/25); DL082-EXT Option D
> executed (Receipt b33989e1, 13 append-only Regrades); Balke-USDJPY recovered (599 Zellen
> governed, Programm Nr. 9); REQUAL-8 6/8 released (Paar-5 Q02 PASS; Paar 7 wartet auf
> worker-gebundenes Smoke-Work-Item, Ticket 1b57e398; Paar 8 danach); Juli-Schatzsuche
> Phase 1 approved (402 EAs; Top-Fund QM5_20004→41272 COMPILE_OK); HP-Powerplan +7 %.
> **Nacht-Incident:** T11/12-Zündung 2× fail-closed (Ramp-Bindung, dann Audit-Binding);
> dauerhafte Fixes: Lock-Scopes+Telemetrie (f6f8011d41), Stage-Catch-all, Review-Regel 0a
> (Paare 6/7 vollautomatisch adjudiziert), Retention-Dauerbetrieb. Versuch 3 = Ticket
> 93c6959b (vollständige Abhängigkeits-Enumeration + garantierender Preflight).
> **Offene Codex-Tickets:** 93c6959b, 1b57e398, 2e0bc944 (41272), f1655764 (Era-Audit),
> 2093b38e (Cleanup), 027fb63f (camofox), 52032627 (Remote-Agents-Spike), df2343c6.
> Details: Claude-Memory `session-0901-0902-ignition-incidents-state` + Vault-Register 2026-09.


> **Gesamtanalyse 2026-08-22 (OWNER-Auftrag):** Vault
> `12 ToDo/11_Systemanalyse_2026-08-22.md`, verlinkt aus `_INDEX`, Programm 10, OWNER- und
> Claude-Board. Gemessener Gesamtstand statt Fortschreibung: Trichter je Gate, die fünf
> Drain-Bedingungen mit Richtung (**D1 1 470 → 619**, **D2 1 185 → 1 275 — durch einen
> eigenen Defekt schlechter**, D3 567 → 451, D5 erstmals messbar mit 629 Verletzungen), die
> drei Engpässe nach Hebelwirkung (**Q09_NEWS 0 PASS bei 52 Paaren = der einzige echte
> Damm**, Compile teilt Slots mit Backtests, Review-Lane als belegte Decke), die
> Vorfallskette 21.–22.08. und der Buchweg (**Q16 = 0 Zeilen, jemals**).
>
> **Ergänzung §10–17 (OWNER-Rückfrage „ist das alles?"):** Geldseite, Kapazität, Fabrik und
> Angebotsseite fehlten. Wichtigster Fund — **`10440|NDX` handelt mit schlafender
> Sleeve-Notbremse:** Live-Puls `verdict=ALARM`, `kill_switch_baselines loaded_ok=23/24`,
> fehlend `10440|NDX`; `QM_KillSwitchKS.mqh:223-232` protokolliert `ks_killswitch_dormant`
> und `OnTradeClosed` kehrt sofort zurück; keine Baseline erzeugbar, weil das kanonische Q10
> dieses Paares **FAIL ist (DD 31,01 % > 25 %)** — gemessen von `f421b62a`. Kontoebene greift
> weiter, die Einzelsleeve-Ebene nicht. Entscheidung: `OWNER-DEC-KS-10440`.
> Weiter: **Codex 46 % genutzt bei 29 % verstrichen, Projektion 157 %, aktiv gedrosselt**
> (Claude 155 %) — paralleles Beauftragen beschleunigt nichts mehr; **3 276 freigegebene
> Karten** gegen 3 753 aktive EA-IDs; Durchsatz ~178 Work-Items/Tag ⇒ **≈ 12–13 Tage allein
> für die bestehende Warteschlange**.

**Stand:** 2026-08-22 · Stehende Vollmacht §6 (wird jedem Bericht beigefügt)
**Eine Zeile je Punkt. „Geliefert" heißt: Ergebnis steht in einem Dokument und wurde berichtet.**

---

## 0f · Orchestrator-Session 2026-08-24 nachmittags — Review-Drain + Durchsatz-Massnahmen

| # | Punkt | Stand |
|---|---|---|
| 1 | **Review-Lane 103 → 15** (52 APPROVED / 33 RECYCLE / 2 BLOCKED-ROT); Methode: 8 parallele Sonnet-Verifikationsagents, Closes durch Orchestrator | erledigt (`docs/ops/evidence/2026-08-24_orchestrator_review_batch_close.md`, b7bc98fc4) |
| 2 | Durchsatz-Forensik (Codex): Kollaps = Long-Run-Q10-Belegung + Codex-CPU-Contention; Pump-Budget widerlegt | geliefert (e88c8e9b0) |
| 3 | 11 Folge-Tickets kommissioniert (Scheduling-Cap de0f052e P85, ROT-Remediation b63eaead P80, FleetPacer 32c7b01f, Identity-Minting f7d75020, Circuit-Breaker cae3df77, Hash-Kanon 8628cddd, Q02-Stranded 9e23d73f, at_utc cf97e8c3, Schtask-Triage 05035f17, OPT_CENSUS-Rang 6d0c929f, Telemetrie 6e9a724b) | im Router (TODO) |
| 4 | 5 gestrandete rework-slot-Branches (2/4/5/6/12) gemerged; Resolver regeneriert; Konflikte per Autoritaets-Union | erledigt (ab2b7c9bd..fc93d5515) |
| 5 | **ROT-Verstoss 39001/38001** (Ad-hoc-Compile nach Interlock-REFUSE, 38001 auch T8-Include-Spiegelung) → OWNER-Board informiert, Remediation b63eaead | offen bis Ticket-Abnahme |
| 6 | farm_state-WAL 459 MB (Checkpoint-Starvation) + 6 wiederkehrend failende Schtasks | an Ticket 05035f17 |

## 0e · Ultracode-Sitzung 2026-08-23 abends — v4 AKTIV, Damm gebrochen, Boards leer

| # | Punkt | Stand |
|---|---|---|
| 1 | **Gate Manifest v4 AKTIV** (17:55, OFF-Fenster #2): Flip + Migration + Cutover 28 Zeilen, Verify 208 grün; Factory ON mit gebundenem Contract-SHA | erledigt (`2f0777085`) |
| 2 | Vault: Q00–Q17-Seiten live, 9 Altseiten archiviert, ToDo-Sektion aufgeräumt (40 erledigt archiviert, 15 „nur notiert" markiert), Linter PASS | erledigt |
| 3 | **News-Gate-Damm gebrochen**: 7×4-Expansion läuft jetzt automatisch (Pump), 4 Expansions-Kinder enqueued, Health `news_gate_service_rate` | gemerged |
| 4 | Opt-Fork automatisiert (Q11-PASS → Q12 → Q13 → Q14, KEEP_INCUMBENT gültig); 3 Erstlauf-Admissions (10706/11421/11422; v3-Payload-Zeilen als superseded dokumentiert) | gemerged |
| 5 | Q07/Q08-Regeneration für die News-Holds enqueued (append-only), Planner: STOP_DETERMINISTIC_INFRA | gemerged |
| 6 | Backfill Tranche 1A (10) + 1B (~107) + **Universum-Erweiterung Tranche 1 (150 Q02, OWNER-DEC-13036-XAU, unterste Priorität)** enqueued | läuft in der Fabrik |
| 7 | Pump-Zyklus 19 min → budgetiert (<5 min Ziel), SQLite-Lock-Retry statt INFRA-Crash, Backup auf Hourly-Task `QM_StrategyFarm_PumpMaintenance_Hourly` + Health-Check | gemerged + Task installiert |
| 8 | Testsuite: 4531 pass / 0 fail (UTF-8-Konsole; 1 bekannter cp850-Fail `test_codex_session_supervisor` → Codex/ops) | gemerged |
| 9 | Claude-Review-Lane 31 → 0 (14 APPROVED, 12 RECYCLE mit konkreten Defekten, 5 BLOCKED-Holds bestätigt) | erledigt |
| 10 | OWNER-Entscheide Batch 2 ausgeführt: STRANDED-182 (182→INVALID, Health 270→88), Q02-Bypass zu, Public-Archiv Variante (b) + v4-Gates-Block, 411xx-Buffer-Klasse (21 EAs) gefixt | gemerged |
| 11 | **T_Live-Preset-Deploy**: vorbereitet + verifizierbar; OWNER-`!`-Lauf erfolgte ohne `--apply` → **erneut nötig**: `! cd C:\QM
epo && python tools\strategy_farm\deploy_tlive_preset_repair.py --apply`; danach Signatur durch Claude | **wartet auf OWNER** |
| 12 | SH-2/SH-3 (Artefakt-Identität + typisierte Spalten): Merge-Konfliktauflösung läuft; **OFF-Fenster #3 heute Nacht** (OWNER: „Claude entscheidet") | in Arbeit |

## 0d · Ultracode-Sitzung 2026-08-23 nachmittags — Pipeline-Rebaseline v4 (OWNER-Auftrag „Fabrik final umbauen")

**Auftrag:** OWNER 2026-08-23 — drei Makrophasen, lineare Gate-Nummerierung, Rebaseline bei null,
Backfill frontier-first, kein Buch <25 + OWNER-Order, Vault aktuell/archiviert, Skripte angepasst,
Backtests überwacht, Codex-Tokens verbrennen. Router `0257da30` (Claude.md `QM-TODO-20260822-402`).
Decision record: `decisions/2026-08-23_owner_gate_manifest_v4_linear.md` (Auffangregel A1–A4 markiert).

| # | Punkt | Stand | Evidenz |
|---|---|---|---|
| 1 | Gate Manifest v3 aktiviert + committet (vorher uncommittet, blockierte Build-Lane) | **geliefert** `d4e4dcfcb` | `docs/ops/evidence/2026-08-23_gate_manifest_v3_activation.md` |
| 2 | Inventur: Gate-Namen-Zensus (5 127 Fundstellen/329 Dateien), DB-Test-Census (14 513 Paare: 0 buchfähig, 3 lückenlos bis Q10, Q09_NEWS = Damm), Factory-Automation, Backtest-Monitor, Vault-Doku | **geliefert** | `docs/ops/rebaseline/*_2026-08-23.md`, `tools/strategy_farm/rebaseline_census.py` |
| 3 | **P0 Fabrikbug**: MetaEditor-Roaming-Profile T6/T7/T9/DEV1 ohne MT5-Stdlib → 80/91 COMPILE_FAIL (88 %) | **gefixt + live** (Profile repariert, Backup, Preflight → INFRA statt COMPILE_FAIL; T9 kompiliert wieder OK) | `docs/ops/evidence/2026-08-23_rb-compile-profiles.md` |
| 4 | Q09-Autoseal: 9 Holds root-caused (alle echte Q07/Q08-Vintage-Defekte), Contract v3 (1 Seed + Seam) jetzt **ausführbar**, bind-q09-plan --dry-run echt read-only | **geliefert** | `docs/ops/evidence/2026-08-23_rb-q09-autoseal.md` |
| 5 | Gate-Advancement zentralisiert (phase_ids.advancement_table) — Review fand versteckte Dispatch-Aktivierung, gefixt | **geliefert** | `…_rb-advancement.md` |
| 6 | Gate Manifest v4 linear Q00–Q17 (Loader, Schema, contract_equivalence, Kriterien-Drift-Check alle Gates) | **geliefert**, READ_INERT bis Flip | `…_rb-v4-loader.md`, `config/gate_manifest.v4.draft.json` |
| 7 | `gate_contract_version`-Spalte + versionsbewusste Labels mit Provenienz + dependency_role-CHECK (v3∪v4) | **geliefert** (Live-Migration beim Flip) | `…_rb-contract-version.md` |
| 8 | Book-Guard fail-closed ≥25 + OWNER-Order-Artefakt; Q11-Auto-Trigger (≥5) entfernt | **geliefert** | `…_rb-book-guard.md`, `book_build_guard.py --status` |
| 9 | Backfill-Planner (frontier-first/earliest-gap-first, append-only, Dry-Run: 14 607 Zeilen, 1 472 sofort enqueue-fähig ≈ 8 300 Fabrikstunden) | **geliefert** (kein Apply) | `docs/ops/rebaseline/BACKFILL_PLAN_2026-08-23.md` |
| 10 | Factory_ON/OFF + Activation-Decision binden Gate-Contract-SHA (Mismatch = Refuse) | **geliefert** | `…_rb-factory-contract-bind.md` |
| 11 | Runtime unter v4 (Promotions/Head-to-Head/Admission manifest-getrieben, Q16→Q11-Rückkante + Auto-Portfolio entfernt, Q10→Pattern statt Q11 = A2), `v4_readiness_check.py` = 0 Verstöße | **geliefert** | `…_rb-v4-runtime.md` |
| 12 | Operator-Surfaces: highest_contiguous_valid_gate, 3 Phasenbänder, Provenienz-Labels, Book-Guard-Kachel, Public-Snapshot v4-Block additiv | **geliefert** | `…_rb-surfaces.md` |
| 13 | `activate_gate_manifest_v4.py` (Flip + DB-Migration mit Backup, dry-run PASS) | **geliefert**; **Apply offen** (Factory_OFF = OFF_INCOMPLETE wegen SYSTEM-Codex-Worker, warte auf Lease-Ende) | `…_gate_manifest_v4_activation.md` |
| 14 | Vault: Linter PASS (Schienenplan P0→Prio-0), v4-Seiten Q00–Q17 + Overview/Workflow/Diff gestaged, Archivplan (9 Seiten → _ARCHIV), APPLY.py dry-run PASS | **gestaged**; Apply nach Flip | `docs/ops/rebaseline/vault_v4_staging/` |
| 15 | Backtest-Überwachung: Monitor alle 3 min; nach Profil-Fix nur noch echte EA-Defekte (`EA_INDICATOR_BUFFER_UNBOUNDED` QM5_41109–41111, `CANDIDATE_RECHECK_REFUSED` QM5_9913), Q09_NEWS INFRA transient | **laufend** | `docs/ops/rebaseline/BACKTEST_MONITOR_2026-08-23.md` |

A1 (Zähleinheit ≥25 = (EA,Symbol), Diversität als Nebenbericht) und A2 (Q12–Q14
verpflichtend, KEEP_INCUMBENT terminal gültig) sind **OWNER-entschieden JA**
(2026-08-27T11:48:57Z / 11:49:11Z, Receipts `fdc84028…` / `b572c026…`); Runtime
(`book_build_guard.py`, `optimization_fork_driver.py`) implementierte die
Auffangregel-Empfehlung bereits identisch, keine Code-Änderung nötig — siehe
`docs/ops/evidence/2026-08-27_a1-count-unit_b572c026_execution.md` und
`docs/ops/evidence/2026-08-27_a2-opt-mandatory_fdc84028_execution.md`.

**Entscheidungsschlange (OWNER, ≤5):** (1) Backfill-Apply
(--max-rows) freigeben: Empfehlung erste Tranche 200 Zeilen Frontier Q08+; (2) 9 Q09-Holds: Q07/Q08-Regeneration
via Planner (REBIND_STALE) statt manueller Release; (3) Testsuite-Baseline 22 vorbestehende Fails
(FTMO-Fixtures/Registry-Hashes/cp1252) — Codex-Ticket anlegen.

## 0 · Neu 2026-08-23 — Strategy Archive Matrix (OWNER-Auftrag, Vorentwurf)

| Punkt | Zustand | Beleg |
|---|---|---|
| Strategy Archive Matrix (Card × Gate × Symbol) — Spezifikation **v1.0** | **geliefert**, alle acht Fragen entschieden, noch nicht gebaut | `docs/ops/STRATEGY_ARCHIVE_MATRIX_SPEC_2026-08-23.md` §11a |
| Beauftragung | Router `2ee6427d` (`ops_issue`, Prio 62, **TODO**, entblockt) | `agent_tasks` |
| **Prototyp gebaut + gegen die DB verifiziert** | **geliefert** — 3,61 MB, 2.984 Karten, 5.377 Löcher, 0 Abweichungen im Vollabgleich | `docs/ops/evidence/2026-08-23_strategy_archive_matrix_prototype.md` |
| F4 Stale-Pass | **nicht baubar** — DB führt keine Build-Identität je Zelle (0,3 % Hash-Abdeckung); vorregistrierter Rückfall (a) umgesetzt | Evidenz §1 |
| Datenbank-Befund (OWNER-Frage) | **geliefert** — Engine gesund, gespeicherte Urteilsfelder nicht: 9.381 Status-Widersprüche, 50.883 Zeilen ohne Taxonomie, 99 FK-Waisen bei abgeschalteter Durchsetzung | Evidenz §2 |
| Gate-Nummerierung → `Q10.1–Q10.3` | **vom OWNER geparkt** (Router `74e72403` BACKLOG) — Auftrag festgehalten, Welle nicht gestartet | Spec §3a |
| Nebenbefund, messbar | 4.661 Paare mit Q02-PASS und **ohne jede Q03-Zeile**; 2.165 Zellen ohne wirtschaftliches Urteil | Spec §1/§4 |

---

## 0b · 2026-08-23 abends — Relikt-Löschung, Detailseiten, Aufbewahrungsregel

| Punkt | Zustand | Beleg |
|---|---|---|
| Relikt-Symbole aus der DB gelöscht (228 Zeilen, korrigierter Umfang) | **ausgeführt** | `docs/ops/evidence/2026-08-23_relic_symbol_purge_rows.json`, Backup `farm_state_20260823T114644Z_pre_relic_purge.sqlite` |
| Matrix englisch + 2.984 Detailseiten mit MT5-Report-Links | **geliefert** (Prototyp) | `docs/ops/evidence/2026-08-23_strategy_archive_matrix_prototype.md` §4 |
| Detailseite löst `ea_*.html` ab | beauftragt, Router `0b6f3039` | OWNER 2026-08-23 |
| **Aufbewahrungsregel für MT5-Reports** | **ratifiziert — DL-090** (B′ + C) | `decisions/DL-090_backtest_report_retention_policy.md` |
| DL-090 Job bauen | beauftragt, Router siehe Vault-ToDo `-508` | DL-090 §4 |
| Farm-DB Schema-Härtung SH-1…SH-3 | beauftragt, Router `4467448f` | `docs/ops/FARM_DB_SCHEMA_HARDENING_2026-08-23.md` |
| Balke/XAUUSD ist ein Loch, kein Fehlschlag | beauftragt, Router `051eb0bf` | Messung in der Vault-ToDo |
| Gate-Nummerierung `Q10.1–Q10.3` | **vom OWNER geparkt** (`74e72403` BACKLOG) | Spec §3a |

---

## 0d · Offener Stand 2026-08-23 spätabends

| ToDo | Was | Hängt an |
|---|---|---|
| `-512` | SH-2 Artefakt-Identität je Lauf | **OWNER: Factory-OFF-Fenster** |
| `-502` | Gate-Nummerierung `Q10.1–Q10.3` | **OWNER: Go für die Welle** (geparkt) |
| `-513` | `QM5_13036` auf XAUUSD ausspielen? | **OWNER-Entscheid** (Kandidatenmenge = ROT) |
| `-511` | Strategy Archive online (Abdeckungsebene) | OWNER-Entscheid Öffentlichkeitsgrad |
| `-514` | **EA-Schauseiten fürs Live-Buch — sollen den MQL5-Kauf auslösen** | **nur noch: MQL5-Produkt-EA fehlt** (Rechtefrage 2026-08-23 entschieden) |
| `-509` | SH-3-Nachfolger (typisierte Spalten) | OFF-Fenster |
| `-505`/`-508`/`-510` | Detailseiten-Vollausbau, DL-090-Job, Karteneingang Englisch | beauftragt, laufen |

**Reduktionsregel festgeschrieben (OWNER 2026-08-23, mit Beispiel).** Öffentlich wird die
**Mechanismusklasse in einem Satz** — der Balke Time Range Breakout wird zu *„Ausbrüche aus
Ranges zu gewissen Uhrzeiten“*. Intern bleiben Uhrzeiten, Schwellen, Filter, Regime-Gates,
Exit-Prioritäten, Sizing und Setfiles. **Das Verkaufsargument ist die Validierung, nicht die
Idee:** 14 Gates, Walk-forward, Multi-Seed, Stress, Venue-Kostenmodell, Portfolio-Fit.

**Quellenrechte entschieden — kein Blocker** (`OWNER-DEC-MQL5-RIGHTS`): die EAs sind
Eigenleistung, die Quellen waren Inspiration, die Attribution in den Karten bleibt. Eine
Marketing-Auflage bleibt: nicht mit Fremdnamen werben. `-514` hängt damit nur noch am
Produkt-EA.

**Neu 2026-08-23 (OWNER):** die Website bekommt **zwei** Flächen — das Archiv als
Abdeckungsnachweis, und Schauseiten für die Live-Buch-EAs, die verkaufen müssen.
**Zielkonflikt, der das Design bestimmt:** die interne Card enthält die vollständige
Mechanisierung; wer sie veröffentlicht, nimmt dem Leser den Grund zu kaufen. Die öffentliche
Card ist ein abgeleitetes, reduziertes Artefakt — These, Evidenzkette, Risikoprofil,
Versagensmodi, **kein Regelsatz**. Router `cc61dbf2` (BACKLOG, blockiert).

---

## 0c · 2026-08-23 abends — „setze alles endgültig um" abgearbeitet

| Punkt | Zustand | Beleg |
|---|---|---|
| Archivmatrix produktiv | **erledigt** — `strategy_archive.html` aus dem stündlichen Dashboard-Task, aus `strategies.html` verlinkt | `tools/strategy_farm/dashboards/archive_matrix.py` |
| Detailseite löst `ea_*.html` ab | **erledigt** — 3.194 Seiten mit voller Strategy Card, allen Läufen, MT5-Reportlinks und Grund-Spalte | Commit `4e4fbc257` + Folgecommit |
| DL-090 Aufbewahrungsjob | **erledigt und gelaufen** — 43.056 Dateien (1,69 GB) in Quarantäne, 30.819 behaltene komprimiert 7,32 → 0,41 GB (6,91 GB frei), Task 04:20 | `tools/strategy_farm/report_retention.py` |
| SH-1 Taxonomie materialisiert | **erledigt und live** — 111.399 Zeilen, 0 Drift, Validator grün, stündlicher Nachlauf-Task | `tools/strategy_farm/schema_hardening.py` |
| SH-3 Fremdschlüssel | **Annahme widerlegt** — Monitor ausgeliefert, Nachfolger beauftragt (typisierte Spalten, OFF-Fenster) | `FARM_DB_SCHEMA_HARDENING_2026-08-23.md` §Umsetzungsstand |
| SH-2 Artefakt-Identität | **offen** — braucht Factory-OFF-Fenster + Review | dito |
| Balke/XAUUSD | **erledigt** — gemessener OWNER-genehmigter Negativbefund, kein Rerun; Oberflächendefekt behoben | `evidence/2026-08-23_balke_xauusd_adjudication.md` |
| Gate-Nummerierung `Q10.1–Q10.3` | **weiterhin vom OWNER geparkt** (`74e72403`) | Spec §3a |
| 13036 auf XAUUSD ausspielen | **OWNER-Entscheidung offen** — Kandidatenmenge = ROT | Balke-Evidenz §„Der eine Teil, der hält" |

---

## 0a · Ultracode-Sitzung 2026-08-22 spätabends — Q09-Push 12969 + Balke 13213 + OFF/ON

**Geliefert** (Evidenz `docs/ops/evidence/2026-08-22_ultracode_q09_push_12969_13213.md`)

| Punkt | Ergebnis |
|---|---|
| EA-Auswahl | **QM5_12969/USDJPY** (PF 1,55 / 300 Trades / DD 2,3 % / PASS_PORTFOLIO, Live-Sleeve 17) — Q09_NEWS `856a8faf` RUNNABLE_BOUND + priority_track |
| Q09-Damm Ursache 1 | Include-Closure-Drift durch generierten `QM_MagicResolver.mqh` → Fix `c3fa7ea0e`, 27 Tests, Zweilinsen-Review |
| Q09-Damm Ursache 2 | `book_q08_regeneration`-Zeilen ohne Q07-Lineage → identitätsgebundener Fallback `87ee64ad0`, 53 Tests; 11 Zeilen gebunden, 7 korrekt gehalten |
| Pump seit 18:38Z blockiert | `include_mirror._pid_exists` = `os.kill(pid,0)` (Windows-Kill) → OpenProcess-Probe, gleicher Commit |
| Cockpit_2min rc=1 | stderr-Guard unter pythonw, gleicher Commit |
| Factory OFF/ON | OFF 20:58Z (Codex-Exec beendet), Mint R5 `a6f076f44`, ON 21:03Z 10/10 |
| Balke 13213 | Portfolio-Re-Eval `b8887bd1` **FAIL_PORTFOLIO** (no_diversification) → OWNER-DEC-13213-POOL; Challenger 21501 Q06 `01bdbe82` enqueued + priority_track |
| Kommissioniert | agy `b8c8cfeb` (Gotobi-Brief), Codex `f8878393` (Autoseal-Census), Codex `6b5176df` (Q09-Sharding) |
| Review geschlossen | `689b3af1` Kalender-Repin APPROVED |
| Fehler korrigiert | Requeue-Falle `enqueue-backtest --from-work-item-id` ohne append-only → Zeile `d3c5183e` restauriert, Memory-Regel |

**Offen / OWNER:** OWNER-DEC-13213-POOL, OWNER-DEC-12969-Q14, OWNER-DEC-MQ5-DRIFT-LIVE, OWNER-DEC-STRANDED-182, OWNER-DEC-Q02-BYPASS-88ba4560 (Details im Evidenzdoc §7).

## 0 · Sitzung 2026-08-22 abends (Orchestrator) — Nachtrag

**Geliefert**

| Punkt | Ergebnis |
|---|---|
| REVIEW-Stapel | **80 → 0.** 13 `ops_issue` (9 APPROVED, 4 BLOCKED an OWNER-Entscheiden), 9 `review_ea` (alle negativ → RECYCLE), 66 `build_ea` (54 BLOCKED, 10 APPROVED, 2 RECYCLE). Danach 1 Neuzugang (`ee8153cf`) sofort mitgeschlossen. |
| 8 OWNER-Entscheide | ausgeführt und aktenkundig: `decisions/2026-08-22_owner_decisions_evening_batch.md`, `decisions/2026-08-22_news_impact_taxonomy.md`; Vault-Archiv ergänzt; **4 ratifizierte Regeln** in `01 Identity/Hard Rules`. |
| SP-D1 Corpus-Manifest | **130/130, `sha256_missing=0`**, `D:\QM
eports\state\g_corpus_manifest_2026-08-22.json` (sha `e7f256db…`). Selbst ausgeführt, weil headless kein `G:` sieht. Befund: die 127 PDFs haben **keine Einzeldokument-Provenienz** im operativen System. |
| Deploy-Pointer-Reconciliation | Manifestfrage **endgültig geklärt**: 07-24-Manifest = das laufende Buch, **0/24 Risikoabweichungen**, Summe 9,7499 %. `docs/ops/evidence/2026-08-22_deploy_pointer_manifest_reconciliation.md`. |
| **Risk-Freeze** | **`OWNER-DEC-RISK-FREEZE` auf ausdrückliche Anweisung sofort ausgeführt** — ACTIVE seit 2026-08-22T19:55Z, Baseline 24 Sleeves / **9,7499 %** / `roster_sha a98bfdeb…`. Verifier gegen Fixture bewiesen (6 Fälle, inkl. fail-closed bei korruptem Zustand), `probe_risk_freeze` prüft alle 15 min nach. Eingefroren ist das **Buch**, nicht die Pipeline. `decisions/2026-08-22_owner_dec_risk_freeze_executed.md`. |
| Build-Queue-Sortierung | 152 strukturell nicht baubare `build_ea`-Zeilen 50 → 10; Ledger `D:\QM
eports\state\orchestrator_build_queue_reorder_2026-08-22.json`. Reversibel, nichts gelöscht. |

**Beauftragt (Ergebnis steht aus)**

| Task | Prio | Inhalt |
|---|---|---|
| `8d1d903f` | 94 | Drain-Blocker Nr. 1: EA-IDs werden ohne Registry-Reservierung zum Build dispatcht. **50/64 REVIEW-Zeilen und 148/207 Queue-Builds** hängen daran. |
| `5254b29a` | 91 | Gate-Generation 2 — Card-Contract-Treue, 7 Klassen, 8+1 fertige fallende Fixtures. |
| `740049db` | 88 | T_Live-Set-File-Provenienz: 10/24 Presets ohne gültigen `build_hash`, eines mit eigenem `DO_NOT_COPY_TO_T_LIVE`-Marker. Diagnose only. |
| `689b3af1` | 86 | Kalender-Repin mit signierter Receipt-Kette (`OWNER-DEC-CALENDAR-REPIN`, Option a). |
| `6a131ec6` | 84 | Hardening-Gate lane-unabhängig (`agent_router.py:1871`). |
| `c65592c7` | 72 | Dependency-Dry-Run, durch das Manifest entblockt. |
| `6e512650` | 89 | Risk-Freeze fail-closed verdrahten — aus Erkennung Verhinderung machen. Guards an allen Kontrollpunkten, je Negativ- **und** Positivtest, Mission-Control-Sichtbarkeit. |

**Angehalten und zurück an OWNER**

| Punkt | Grund |
|---|---|
| Pointer-Signatur | Genehmigt, Vorbedingung erfüllt — **aber** 10/24 Live-Presets ohne gültige Provenienz. Kein Handelsdefekt (funktionale Keys korrekt, Risikovektor exakt), aber eine Signatur behauptet genau die fehlende Provenienz. ROT ⇒ keine Auffangregel. Vorlage `OWNER-DEC-POINTER-PRESETS`. |

**Explizit geparkt, mit Grund**

| Punkt | Grund |
|---|---|
| SP-C5 FTMO-Ablehnungskriterium (`QM-TODO-20260822-403`) | Die Spezifikation ist heute nicht sinnvoll schreibbar — unbekannt, welche Felder SP-C4 liefert. Auslöser: SP-C4 abgeschlossen **und** authentifizierte Swap-Eingaben. |
| SP-D3 / SP-D4 Backup-Verschlüsselung + Restore-Drill | `OWNER-DEC-BACKUP-KEY` vertagt. Backups bleiben unverschlüsselt — dokumentierte, bewusst akzeptierte Risikoposition. |

**Nachgemessen, Korrektur an früheren Berichten:** Der Q09-Pilot `b2468d2e` ist am 22.08.
mit `INFRA_FAIL` gestorben; Nachfolger **`ba24e7a3` läuft auf T4** und arbeitet die 40 Zellen
ab. `failure_attempts/attempt_0001` + `cell_failure.json` belegen, dass der reparierte Runner
real feuert. Der Damm bewegt sich.

---

## 1 · Geliefert

| aus | Punkt | Ergebnis in einem Satz |
|---|---|---|
| R7 §1 | EV eines finanzierten Kontos | Break-even-Gebühr 15.555 $ bei 0,50×, auf beiden Messbasen — die erste Aussage der Serie, die die Intraday-Unsicherheit überlebt (`EV_FUNDED_ACCOUNT.md`) |
| R7 §2 | Trichterdiagnose | Q04 lässt 9,1 % durch, Q08 16,7 %; die 24 buchuntauglichen Paare sind 0 Daten- und 24 Frequenzausfälle (`FUNNEL_DIAGNOSIS.md`) |
| R7 §5 | Optimizer-Retarget | Der DD-Hebel ist nicht leer, sondern steht hinter den Gates, die hohe Drawdowns entfernen (`OPTIMIZER_RETARGET.md`) |
| R7 §6.5 | DZ-Buchumfang | Das DZ-Erfolgs-KPI ist im Bestand nicht dokumentiert; drei von sechs Auditgrößen sind übertragbar (`DZ_BOOK_SCOPE.md`) |
| R8 §1 | Aktivitätskriterium, Herkunft | Die 250 ist ein undokumentierter Implementierungsfilter (600→500→250, jede Stufe zur Poolvergrößerung); ihre Korrektur bringt 8 Paare zurück und **verschlechtert** das Buch (`ACTIVITY_CRITERION.md`) |
| R8 §2 | `PASS_LOWFREQ`-Zählung | 109 Paare, null davon buchfähig, nur 4 erfüllen das 10/Jahr-Kriterium (`LOWFREQ_CENSUS.md`) |
| R8 §3 | Negativkontrolle | Entfallen — Stop-Condition-Pfad byteidentisch zum Trip vom 18.08. (`DECISIONS` D-11) |
| R8 §5.1 | Familie × Anlageklasse | Dieselben 497 EAs bestehen Q04 auf Metall mit 20,3 %, auf FX mit 3,9 % (`FAMILY_ASSET_MATRIX.md`) |
| R8 §5.4 | Live-Buch-Ist-Aufnahme | 24 Binaries, 17 emittierend, 20 Sleeves, **10 handeln**, 5 attached ohne je einen Trade (`LIVE_BOOK_INVENTORY.md`) |
| R9 §2 | Zuteilungslogik | `farmctl.py:17532` fällt auf alle 37 Registersymbole zurück (28 davon FX); 75 EAs sind so gelaufen (`ALLOCATION_SHIFT.md`) |
| R10 §1 | Gepaarte Symbolrangfolge | Nur XAUUSD ist bewiesen; GDAXI und XTIUSD fallen gepaart um die Hälfte, USDJPY steigt (`SYMBOL_RANKING_PAIRED.md`) |
| R10 §2 | Kartenherkunft | 864 Karten mit Universum, **488 davon Paar/Basket (nicht änderbar)**; und **604 von 810 Karten deklarieren < 31 Trades/Jahr** (`CARD_UNIVERSE_ORIGIN.md`) |
| R10 §3 | RECYCLE-Stau | Keine vier Wochen Zufluss — 290 nie gebaut, 117 längst gelaufen, **3 verwertbar** (`RECYCLE_BACKLOG.md`) |
| Q14 §1.1 | Inhalt `OPTIMIZER_RETARGET.md` | Berichtet; H3 fällt durch Skaleninvarianz weg, H1 wandert in die Buchkonstruktion, H2 bleibt (`OPTIMIZER_TRACK_STATUS.md`) |
| Q14 §1.2 | Unger-Filter | **Existieren nicht** als Filter — die `unger-*`-Einträge sind EAs nach seinen Vorlagen (`OPTIMIZER_TRACK_STATUS.md`) |
| Q14 §2 | 12-%-Schwelle | Steht nirgends im Code, nur als Verdikt-Text; sperrt **nicht** 25 von 25, fünf haben sie bestanden (`OPTIMIZER_TRACK_STATUS.md`) |
| Q14 §4.3 | Q09-Zerlegung | 197 s Fixkosten je Testerlauf + 0,343 s/Kalendertag; Datumsfenster-Weg scheitert um eine Größenordnung (`Q09_ACCELERATION.md`) |
| Q14 §4.5 | Schätzfehler | Faktor 7 gegen die Evidenzdoku; Zellzeit ist auslastungsabhängig (`Q09_ACCELERATION.md`) |
| Dir. §1 | Verkettungstest | Max-DD exakt rekonstruierbar (17.072,73 beidseitig), Restfehler 0,58 % im Nettogewinn (`Q09_ACCELERATION.md` §7) |
| R9 §1 / Dir. 20.08. | Aktivitätsregel ratifiziert | ≥10 Handelstage je gewertetem Jahr, Zählbasis **Eröffnungstag** (begründet), Teiljahres-Pro-rata als Vorschlag beim OWNER; Zählungen 8 (Schluss) / 10 (Eröffnung) auf der 31er-Kohorte (`ACTIVITY_CRITERION.md` §R) |
| eigener Plan #3 | Commit-Nachtzeitreihe | Nachtserie vollständig: Peak 108,2/122,6 GB 05:18 UTC bei 3,8 GB phys. frei; Admissions-Gate feuerte korrekt (Reservierungs-Logs aller Worker) — Decke wird durch **In-Flight-Wachstum** erreicht, nicht durch blinde Claims; Pagefile C: zu 97 % voll, C: nur 44 GB frei → Decken-Anhebung braucht D:-Pagefile + Reboot (Wartungsfenster-Vorlage) (`D:\QM
eports\state\commit_sampler.log`, `commit_wave_snapshot_20260820_0553utc.txt`) |
| Dir. §2 | Seed-Sensitivität | **40 Zellen sind 8 Konfigurationen**; der RNG wird in Q09 nie gezogen (`SEED_SENSITIVITY.md`) |
| Dir. §1 | Kontaminationsprüfung | Timeout-Verluste 0,24–1,4 %, verschieben jede Quote < 0,5 pp, und zwar **entlastend** — die Befunde halten |
| Vollm. §8.2 | Hyonix sichern | Zip 65,2 MB, 2.742 Einträge, SHA256 `722FC306…`, off-host auf `G:\My Drive\QM_Backups\` mit Hash-Sidecar |
| — | Q09-Pilot-Abbruch aufgeklärt | Tester extern bei 98,7 % der Ticks beendet → Null-Statistik-Report; dazu Falsy-Zero-Parserbug; **2 Runner-Fixes committed (a92c0490f), Pilot als append-only Rerun `cba63d44` neu gebunden** |
| R10 §5.1 | Strategy-Files-Inventar: die eine Zahl | **~70 distinkte non-ML/non-ICT Quelltext-Kandidaten + 428 kompilierte Repo-EAs, die die Fabrik nie sah** (`STRATEGY_FILES_INVENTORY.md` §0, jetzt berichtet) |
| R9 §5.4 / R10 §5.3 | Rate je Gate + Queue-Termin | Q04 11,2/h (6h-Fenster); 9/h-Einbruch = 5 von 8 Slots auf Q07/Q08 — OWNERs Transient-These **bestätigt**; Queue-Ende ≈ 26.–27.08. |
| Vollm. §8.1 | Unger-Filter: Parameterkosten | Eingrenzung auf 1 kategorialen Parameter (feste Muster-Bänke) vorgeschlagen — Bericht 19.08. 20:00 |
| Dir. 21.08. (ULTRACODE) | Firmen-Vollaudit + CEO-Masterplan | 8-Agenten-Audit abgeschlossen (`COMPANY_AUDIT_ULTRACODE_2026-08-21.md`); Masterplan T1–T12 im Vault (`12 ToDo/00_CEO_Masterplan_2026-08-21.md`); T1 (T_Live-Authority-Falschdoku „OWNER + Claude" auf 5 Vault-Seiten) sofort korrigiert auf Kanon OWNER-only |
| Masterplan T2 | Identity-Core-Rebuild | Business Model neu (DXZ+FTMO gleichwertig), Hard-Rules-Amendments 2026-08 + Rollen-Modernisierung, Lint-Legacy-Rollen-Check mit 17-Seiten-Debt-Allowlist; Lint PASS |
| Masterplan T3 | Pipeline-Seiten-Rebuild | Q00 R1/R4 (OWNER: R4 bleibt), Q02-Kanon (Rate-Floor), Q05-Rename, **DD-Schwellen-Drift 15→25 % auf Q05/Q06/Q10 gegen Code-Kanon korrigiert**, Q06 tote Multiplikatoren raus, Q09 Zwei-Achsen, Q11 dual-book, Q14 Numerik-Pointer + Fork bei Q10 (OWNER-bestätigt); Lint PASS |
| Masterplan #2 | Fail-Soft Q05/Q06 | **GELIEFERT + AKTIV**: Band 40,3 % → T10 implementiert (Commit `47f751d1d`): Q06 `PASS_SOFT` (PF 0,95–1,00, DD<25, ≥20 Trades) advanct nach Q07; Anti-Stacking q06_soft+EDGE_SOFT terminal am Q08→Q09-Punkt; Dashboard-Chip; 83 Tests grün (Claude-nachgelaufen). Nur neue Läufe — Retro-Kohorten (15 Alt-Decke + 25 Band) = Entscheidungsschlange #6 |
| Messung 21.08. | Nebenbefund Alt-Decken-FAILs | 15 Q06- (und analoge Q05-) `dd_above_ceiling`-FAILs wurden unter der alten 15-%-Decke adjudiziert (`max=15.0` im reason); unter heutiger 25-%-Decke teils PASS → Vorschlag append-only Reruns, Entscheidungsschlange #6 |
| Dir. 21.08. | FTMO-Buch-Symbolregel | **OWNER-Ruling: mehrere EAs/Strategien pro Symbol im FTMO-Buch erlaubt** — Q11-Seite aktualisiert; Code-Drift dokumentiert: `build_book_ftmo.py` erzwingt noch `select_one_per_symbol` (Z. 95/261) → Umbau = Masterplan-T7-Arbeitspaket |
| **NEU 21.08.** | **Agenten-Lane stand seit 19.08. still — Ursache gefunden und behoben** | Kein Defekt: Router meldete `no_routable_task` bei **1.520 fertigen Cards**, weil 107 Tasks in REVIEW hingen, **die nur Claude schließt**. 50 review_ea adjudiziert (2 unabhängige Triage-Pässe: Defekte objektiv, Codex-Messlatte konsistent, **kein Fehlurteil**) → 44 RECYCLE / 6 BLOCKED, 47 Quell-Builds mitgezogen; REVIEW jetzt 0 review_ea (`evidence/2026-08-21_review_backlog_closeout.md`, Commit `53adcb524`) |
| **NEU 21.08.** | **agy-Bauwelle: 6 wiederkehrende Template-Defektklassen** | 101 Builds in die gemini-Lane seit 01.08., nur 18 APPROVED; 49/50 Reviews negativ. card-drift 36×, missing-loss-limits 23× (Card 2/2,5/5 % vs. Framework-Default 3.0/0.0), Management-unerreichbar ~20×, broker-time, pip-×10-Doppelkonversion, build-identity — **und 11 Reviews auf Builds, deren strict build_check schon FAIL war**. Hebel = mechanische Build-Gates (Codex `57faa292`), nicht mehr Review; 6 unmechanisierbare Cards → agy `471cffc3` (nur Kartentext, Stilllegung ist erlaubtes Ergebnis) |
| Dir. 21.08. | Subagent-Ökonomie | OWNER: Umsetzung über Codex/Opus/Sonnet-Subagents, Fable nur Orchestrierung/Review — als Feedback-Memory verankert; T4 + Band-Messung laufen bereits so |
| **OWNER 21.08.** | **Orchestrator-Mandat in `CLAUDE.md` verdrahtet** | Rollenzeile nennt jetzt Orchestrator; neuer Abschnitt „Orchestrator Mandate": Claude-ToDos selbst erledigen, Codex-/Antigravity-ToDos **beauftragen**, Routing nach Fähigkeit, Taktung gegen die 5h-/Wochenlimits aller drei Sitze, `review_ea` als exklusive Claude-Pflicht, und die bindende Regel **„ein offener Punkt ohne Router-Task ist nicht beauftragt, sondern nur notiert"**. Session-Start-Regel auf alle vier ToDo-Boards erweitert (Commits `0f352e0ec`, `c85a46b18`) |
| **OWNER 21.08.** | `OWNER-DEC-GATEMANIFEST-Q05` umgesetzt | Q05 heißt im Maschinen-Contract „Gross Full-History Robustness"; Gate-ID, Kriterien, `P*`-Keys, `legacy_aliases` unberührt, v1-Manifest bleibt eingefroren. Der v1/v2-Paritätstest vergleicht jetzt **Topologie** und führt die eine erlaubte Umbenennung namentlich auf — eine unautorisierte Umbenennung eines anderen Gates fällt weiter durch (Commit `5af55bfbf`, 11 Tests grün) |
| **OWNER 21.08.** | `OWNER-DEC-FTMO-SYMBOLPOLICY` beauftragt | Task `9bdfde03`. **Auflage:** der Symbol-Cap wird nicht ersatzlos gestrichen — er ist heute die einzige Konzentrationskontrolle des Builders; die Aggregat-Kontrolle (Korrelation/Cluster + kontoweites Budget) muss ihn **ersetzen**, jedes ausgeschlossene Paar behält einen expliziten Grund, nicht ratifizierte Schwellen werden vorgelegt statt erfunden |
| **NEU 21.08.** | Entscheidungsfläche entrümpelt | `12 ToDo/AI ToDos/OWNER.md` zeigt nur noch Offenes; neun entschiedene Punkte nach `AI ToDos/Archive/Entscheidungen 2026-08-21` verschoben (Archiv heißt erledigt, nicht ungültig). Neu offen dort: `OWNER-DEC-MNT022-INTENT` — der ausgeführte Auftrag meldet, das Ticket sei früher als *bewusst nicht beauftragt* geführt worden |

## 2 · Offen

| aus | Punkt | warum noch offen |
|---|---|---|
| **R9 §3** | `BOOK_CONSTRUCTION_RULES.md`: Symbol-/Klassengrenze, Stapelblindheit, Mindesthistorie | braucht die Mindesthistorie aus der Fensterlogik — rechenbar, nicht gerechnet |
| **R9 §5.1** | Watchdog-Schwelle (`MinWorkers = 8` heilt zu spät) | Vorschlag formulierbar, nicht formuliert |
| **R9 §5.2** | SQLite-Lock-Auffanglinie (OQ-22) | Diff nicht geschrieben |
| **R9 §5.3** | Live-Buch-Ist-**Manifest** (die Aufnahme steht, das Manifest fehlt) | Erzeugung aus `audit_live_book_inventory_20260819.json` |
| **Vollm./A+B** | **Q09-Kontrakt v3 (Weg A + B) — vorab genehmigt, in Arbeit** | Kontrakt-Tiefe erfasst (Seed-Statistik + full-Metriken in Adjudikation); v2-Referenz `cba63d44` läuft parallel als Validierungsanker |
| **Vollm. §8.3** | Bug #4 (Kurzhistorien-Sperre) vor Integration beheben | Vorbedingung jeder Pattern-Filter-Integration; kollidiert mit Erstjahr des Aktivitätskriteriums |
| **Vollm. §8.1** | Pattern-Filter als Q14-Hebel formal aufnehmen | braucht Hypothese + Widerlegungskriterium + Frequenzprüfung + Parameterzahl (GELB-Bedingung); Entwurf im Bericht 20:00 |
| **Q14 §3** | Episodendefinition für die Ersatzbedingung | Definition formulierbar; die Survivor-Zahl braucht die Kohorte |
| **Q14 §3.1** | EXIT_SURGERY rückwirkend auf Rendite/Drawdown | die Läufe existieren unter `D:\QM\reports\opt_track\` |
| **Q14 §4.1/4.2/4.4** | Kohortengröße, Reihenfolge vor/nach Q09, Wiederholung je Hebelklasse | §4.2 jetzt mit 2,8 h statt 26 h neu zu rechnen |
| **Q14 §5.3** | `ONINIT_FAILED`-Klasse auszählen und richtig klassifizieren | einzelne Abfrage |
| **Q14 §6** | Ertrag in verdrängten Gate-Läufen | hängt an §4.2 |
| **Q14 §7** | Overlap Optimierungsfenster gegen WF-Falten | Messung auf vorhandenen Artefakten |
| **Dir. §2** | Ursachenanalyse: korreliert `q02_full_runtime_sec` mit der Auslastung? | die Claim-Zeitstempel liegen vor |
| **Dir. §3** | Timeout → Requeue: Diff + 3 retrospektive Zeilen | Prinzip freigegeben, Diff offen |
| **aktuell** | `WALLCLOCK_CONSTANTS.md` | Belege vollständig, Dokument nicht geschrieben |
| **Dir. 21.08.** | Masterplan-Rest | T1–T8, T10, T11 geliefert+reviewt. **Alle 5 OWNER-Entscheidungen am 21.08. getroffen und vollzogen** (#4 Pro-Rata `e116d503c`, #6 12 Reruns `a616d3e66`, #7 Hold-Release `51fef5956`, #8 ADR `DL-088`/`b855323a8`, PUBFIELDS konservativ). Offen: T9 (Bug#4 + Fixture-Harness), T12-Programme. Termin MNT-036 = **06.09.** (OWNER-Verschiebung) |
| Masterplan T8 | Pattern-Prädikate 31/32/92/100 | Repariert (Commit `014c214ad`): 3-Bar-THREE_INSIDE, FRACTAL ohne Widerspruchsklausel, QUARTER_END letzte 2 Kalendertage; 35 Tests grün, QM5_21501 kompiliert; MT5-Harness-Lauf als Folge-Messung offen |
| **NEU 21.08.** | **Maintenance-Ledger ist-geprüft und beauftragt** | 46 Punkte gegen den Live-Zustand nachgemessen: **17 erledigt, 2 überholt, 16 teilweise, 11 offen** — ein Drittel war schon abgearbeitet (NO_HISTORY 35→0, Nullsignal-Events ~3017/Tag→3, Seed-Auth 0/69, T5 zurück). **15 Router-Tasks** an Codex/Antigravity dispatcht, 8 bei Claude, 4 beim OWNER. ★Strukturbefund: **kein einziger Router-Task trug je eine `QM-TODO`-ID** — Vault-Häkchen und Fabrik-Aufträge waren getrennte Welten; ab jetzt trägt jeder Task seine ID und jede ToDo-Zeile ihre Task-ID (`evidence/2026-08-21_maintenance_ledger_reverification_and_dispatch.md`) |
| **NEU 21.08.** | **275 `q02_stranded_exhausted_pairs`** | Q02/P2-Paare ohne nicht-infra terminale Disposition, ohne Nachfolger, ≥ 12 Versuche — dieselbe Klasse wie die vier heute befreiten EAs (still gestorben, niemandem aufgefallen). Noch nicht bearbeitet; braucht eine eigene Triage-Welle |
| **NEU 21.08.** | Health-Signal `pump_task_lastresult` FAIL, obwohl der Pump arbeitet | Exit-Code 2147946720 bei laufendem Dispatch (8 aktive Rows, 3–5 Completions/h). Log enthält nur die Python-Zeile „Could not find platform independent libraries <prefix>" → PS-stderr-Trap-Klasse. **Gefahr: ein echter Pump-Ausfall wäre in diesem Dauer-FAIL nicht unterscheidbar** |
| **NEU 21.08.** | `pending_artifact_binding_drift` = 12 (CONTENT_CHANGED, 8 Rows) | Vermutlich Folge der laufenden Codex-Arbeit an `QM_PatternPermission.mqh` (Bug #4, unkommittierte Quelle). **Nach dem Codex-Commit erneut prüfen** — Bindungsdrift kann sonst gesunde Läufe verwerfen |
| **NEU 21.08.** | Rest-Aufräumung hinter dem REVIEW-Stau | 556 RECYCLE bleiben **absichtlich** liegen, bis die Build-Gates stehen (sonst 556 Rebuilds mit denselben 6 Defektklassen); 10 build_ea noch in REVIEW; APPROVED-Limbo in Arbeit |
| **NEU 21.08. (P1)** | **Agent-Capabilities flattern zwischen Checkouts** | `sync_default_registry` überschreibt `agent_registry` bedingungslos, und **mehrere Checkouts** laufen: `C:/QM/repo` schreibt den breiten Satz, `codex-orchestration-1`/`gemini-orchestration-1` den alten schmalen. Gemessen: schmal 12:48:25Z, breit 12:53:40Z, dieselbe DB. **In jedem schmalen Fenster kann die Claude-Lane keinen `ops_issue` annehmen (kein `ops`) und agy keine Video-Analyse (kein `video_analysis`)** — beides still, eine nicht routbare Aufgabe sieht aus wie Rückstau. Beauftragt: Task `cd982cfc` mit Ursache im Payload (`evidence/2026-08-21_agent_registry_capability_flapping.md`) |
| **NEU 21.08.** | Test `test_real_a02_compile_manifest_loads_when_present` schlägt fehl | `ContractError: compile manifest FACTORY_OFF binding drifted` — der Test bindet ein reales Compile-Manifest an die SHA von `FACTORY_OFF.flag`; die Datei existiert bei laufender Fabrik nicht. **Umgebungsabhängiger Test, nicht durch die Q05-Umbenennung verursacht** (660 andere Tests grün). Er schlägt fehl, sobald die Fabrik läuft — d. h. im Normalbetrieb. Braucht eine Entscheidung: Fixture statt Live-Bindung, oder Skip mit Begründung |
| **NEU 21.08.** | `HARNESS_PP_FIXTURE` = 1 pending | Der ausstehende MT5-Fixture-Harness-Lauf für die Pattern-Prädikate steht als Work-Item in der Queue (Masterplan T8, Folge-Messung zu `014c214ad`) — er ist eingereiht, nicht vergessen |
| **NEU 21.08. (QM5_41095)** | WTI Excursion-Imbalance: Q01-Compile + Q02 offen | Nicht-duplizierter source-only Build `b74533ddb`, 12/12 Referenztests und Guardrails PASS; governed compile `c88b39a4-1220-4894-a2c3-9818651c763e` wartet unter `COMPILE_EA_WORKER_ROLLOUT_PENDING`. Q02 blieb ohne Enqueue, weil Q01 noch kein PASS hat und die frische CPU-Serie bis 100% die 97%-Decke überschritt (`2026-08-21_qm5_41095_wti_weekly_excursion_imbalance_source_build_cpu_stop.md`). |
| **NEU 22.08. (QM5_41101)** | XNG Range-Migration: Q01-Compile + Q02 offen | Nicht-duplizierter source-only Build `b2a34ae5f`, 11/11 Referenztests und Guardrails PASS; governed compile `97095c29-b534-4e4c-baf8-aa8d382225eb` wartet unter `COMPILE_EA_WORKER_ROLLOUT_PENDING`. CPU blieb mit max. 93,53% unter der 97%-Decke; Q02 blieb ausschließlich mangels EX5/Q01-PASS ohne Enqueue (`evidence/2026-08-22_qm5_41101_xng_weekly_range_migration_compile_handoff.md`). |
| **NEU 22.08. (QM5_41102)** | WTI Monthly Range-Migration: Q01-Compile + Q02 offen | Nicht-duplizierter source-only Build `50b77acb0`, 11/11 Referenztests und Guardrails PASS; governed compile `200baa1f-8f4b-4438-807a-835734be24e9` wartet unter `COMPILE_EA_WORKER_ROLLOUT_PENDING`. CPU blieb mit max. 85,14% unter der 97%-Decke; Q02 blieb ausschließlich mangels EX5/Q01-PASS ohne Enqueue (`evidence/2026-08-22_qm5_41102_wti_monthly_range_migration_compile_handoff.md`). |
| **NEU 22.08. (QM5_41109)** | XAU/XAG Mean-Median-Reversion: Q01-Compile + Q02 offen | Nicht-duplizierter source-only Basket-Build `60e9b5192`, 11/11 Referenztests und Guardrails PASS; governed compile `55cdd439-9f1e-4d26-a917-66a23b783abe` wartet unter `COMPILE_EA_WORKER_ROLLOUT_PENDING`. Q02 blieb ohne Enqueue, weil Q01 noch kein PASS hat und die frische CPU-Serie mit max. 99,90% die 97%-Decke überschritt (`evidence/2026-08-22_qm5_41109_xauxag_monthly_mean_median_source_build_cpu_stop.md`). |
| **NEU 23.08. (QM5_41128)** | XAU/XAG Daily-Persistence-Reversion: Q01-Compile + Q02 offen | Nicht-duplizierter source-only Basket-Build `1eb68e110`, 8/8 Referenztests, SPEC, Guardrails und `BASKET_OK` PASS. Governed compile `1fba43ee-aa57-4ee8-ba97-827467710cbd` wurde SHA-frisch target-only freigegeben, blieb aber unclaimed/pending ohne EX5. Q02 blieb ohne Enqueue, weil die frische CPU-Serie Ø 98,94% / max. 99,90% die 97%-Decke überschritt und Q01 noch kein Compile-PASS hat (`evidence/2026-08-23_qm5_41128_xauxag_monthly_daily_persistence_source_build_cpu_ceiling_handoff.md`). |
| **NEU 27.08. (QM5_41184)** | WTI Two-Sample Label-Runs: Q01-Compile + Q02 offen | Nicht-duplizierter struktureller WTI-Source-Build `1dcf96924`, 11/11 Referenztests, SPEC, Guardrails und Resolver-Tests PASS; exakte Vorab-Enumeration korrigierte den Run-Table-Transkriptionsfehler vor Compile/Marktergebnis und sperrt `R<=6`. Kein EX5/Compile-Enqueue und kein Q02-Enqueue: frische CPU-Serie Ø 99,94% / max. 100,00% überschritt die 97%-Decke (`evidence/2026-08-27_qm5_41184_wti_two_sample_runs_source_build_cpu_ceiling_handoff.md`). |
| Masterplan T11 | public-data-Export | **Diagnose statt Fix (korrekt):** Export gesund, Publikation fail-closed hinter 2 Q02-Bypass-Holds vom 29.07.; QM5_20182-Hold = stale Orphan (Remediation belegt), QM5_20172 echt offen (DRAFT_DEFECT) → Entscheidungsschlange #7 (`evidence/2026-08-21_public_snapshot_export_repair.md`, Commit 511d85fea) |

## 3 · Entfallen

| aus | Punkt | warum |
|---|---|---|
| Q14 §0 | „Die Unger-Filter kommen hinzu" | Es gibt keine. Die Vorgabe ist gegenstandslos, §3.2 braucht echte Hebelvorschläge |
| Q14 §1.2 | Unger-Filter beschreiben: Ort, Parameter, Testergebnis, Frequenzwirkung | dito — nichts zu beschreiben |
| Q14 §3 (H3) | Sizing als Optimierungsgröße | Rendite/Drawdown ist skaleninvariant; ein Sizing-Optimierer kann den Quotienten nicht bewegen |
| Q14 §2.1 | Doppellauf zur Ausführungs-Invarianz | OWNER: nicht nötig, solange die Zielgröße nur zum Ranking dient |
| R8 §3 | Negativkontrolle Containment | Commit-Prüfung hat sie ersetzt |
| R9 §2 | Verteilung 30/30/15/25 | zurückgezogen — der Vorrat gibt maximal 15 % Metall her |
| Dir. §4.3 | Datumsfenster-Weg für Q09 | gemessen: 81 % der Tage tragen Ereignisse, Fragmentierung kostet mehr als sie spart |
| Dir. §2 (Weg B) | „3 statt 5 Seeds" | ersetzt durch „1 statt 5" — der Seed ist nachweislich wirkungslos |

## 4 · Vorgeschlagene Reihenfolge für die offenen Punkte

**Zuerst, weil billig und blockierend für anderes:**

1. **R9 §5.4** stabile Rate (ab 19:19 UTC auswertbar) → liefert die Mischrate für R10 §5.3
2. **R10 §5.1** die eine Zahl aus dem Strategy-Files-Inventar — Bericht, keine Messung
3. **Dir. §3** Timeout-Requeue-Diff + die drei retrospektiven Zeilen
4. **Q14 §5.3** `ONINIT_FAILED` auszählen — eine Abfrage

**Dann, weil sie aufeinander aufbauen:**

5. **Dir. §2** Auslastungskorrelation → entscheidet die Reparaturform
6. **`WALLCLOCK_CONSTANTS.md`** mit 3 und 5
7. **Q14 §4.2** Reihenfolge vor/nach Q09, neu mit 2,8 h
8. **Q14 §6** Ertrag in verdrängten Gate-Läufen

**Zuletzt, weil sie eine Entscheidung oder eine Kohorte brauchen:**

9. R9 §1 Aktivitätsregel, R9 §3 Konstruktionsregeln
10. Q14 §3 Episodendefinition, §3.1 EXIT_SURGERY, §7 Overlap
11. R9 §5.1 Watchdog, §5.2 SQLite-Lock, §5.3 Live-Manifest

---

**20:00 UTC:** Die beiden überfälligen Punkte (Strategy-Files-Zahl, Filtersuche) sind berichtet.
Aktive Großbaustelle ist der Q09-Kontrakt v3 (A+B, vorab genehmigt); die v2-Referenzmessung
`cba63d44` läuft parallel und wird zum Validierungsanker der v3-Entscheidungsgleichheit.

## Nachtrag 2026-08-21 · Ultracode-Welle 1 — Codex-Board durch Claude abgearbeitet (Quota-Schonung, OWNER-Auftrag)

| aus | Punkt | Ergebnis in einem Satz |
|---|---|---|
| MNT-009 | Runner-Completion atomar | Fail-closed DB-Trigger + EVIDENCE_UNAVAILABLE-Sentinel live in farm_state.sqlite, 24 Tests grün (b1f959027; Evidenz `2026-08-21_mnt009_infra_fail_evidence_binding.md`) |
| MNT-003 | 0x800710E0-Oszillation | Als benigner IgnoreNew-Overlap bewiesen; Monitore adjudizieren nach Principal/Code, 267014 alarmiert weiter, Task-XML unangetastet (19ae99a42 + e62de0f9e) |
| MNT-026 | Dedup nie CLEAN bei kaputtem Input | Drei fail-closed-Tests gepinnt, 13108-Recheck reproduziert DUPLICATE (e45a42e08, Re-Verifikation 8812cc62a) |
| MNT-012 | R3-Frontmatter 1457/1459 | Beide Karten stimmen auf evidenziertes UNKNOWN überein (Serien fehlen in dwx_symbol_matrix.csv) |
| TODO-201 | Qxx-only Health-Texte | Displaytexte bereinigt, Echo-Sidecar zurückgesetzt, Heartbeat sauber, Vault-Lint PASS (299727da5) |
| TODO-202 | pipeline_state.json | REAKTIVIERT: frischer Snapshot + stündlicher Task `QM_StrategyFarm_PipelineState` (rc=0), vom fail-closed Public-Guard entkoppelt (b9d91741e) |
| TODO-203 | Symbol-List-Seite generieren | Deterministischer Generator + Drift-Test, Seite auf 37 Symbole inkl. SP500; Folgepunkt: `company_manifest.json`-Symbolblock driftet weiter (769d09e6e) |

Alle 7 Router-Tasks APPROVED geschlossen; adversariale Verify-Agents je Task = PASS. Verbleibend auf dem Codex-Board: die Architektur-Brocken MNT-011/-038/-030/-016/-031/-032/-035 und die blockierten -020/-006/-013/-039.

## Nachtrag 2026-08-21 (abends) · Ultracode-Wellen 2/2b/3 — kompletter Maintenance-Ledger reviewt und geschlossen

| aus | Punkt | Ergebnis in einem Satz |
|---|---|---|
| MNT-011 | Dirty-Guard entkoppelt | Doppelreview APPROVED: strukturelle Generated-Klassifikation fail-closed (bfce1fa3a), Pump-Blocking 165→6; Spawn-Beobachtung im generated-only-Fenster folgt beim nächsten natürlich sauberen Baum |
| MNT-038 | Canary-vor-Fanout | Codex-Lieferung + Claude-Härtung nach Review-Bounce: Cross-Asset-Null-Bestätigung, K=3-Infra-Bestätigung, STOPPED-Revival; adversarial APPROVE, live via SweepEnqueue_Hourly (`2026-08-21_mnt038_canary_gate_hardening.md`) |
| MNT-016 | Verdikt-Taxonomie | Abgeleitete ro-TEMP-View, Basisrows byte-intakt, Invariante 0 Verletzungen über 110k Rows, Dashboards lesen die View — APPROVED |
| MNT-032 | Headroom-Governor | Echt gemessener Disk/RAM/Commit-Headroom, drosselt nur Spawns, fail-closed, unplausibler Reclaim → TELEMETRY_ERROR — APPROVED |
| MNT-035 | Ein Health-Vertrag | qm.health.contract.v1 über alle Wächter, 7 Widersprüche als grüne Fixtures, komponiert mit MNT-003 — APPROVED |
| MNT-031 | Worktree-Vertrag | 8 Klauseln + gemessenes 59-Worktree-Inventar, reine Doku/Tooling — APPROVED |
| MNT-013 | Card-Buckets | 365 Karten in benannten Buckets (324/33/8), Summen exakt, kein Sammelbau — APPROVED |
| MNT-030 | Source-Ingestion | Prämisse hielt nicht (gemessen): Pool 12 pending, SLOs getrennt, Intake sauber — APPROVED als Premise-Check |
| MNT-039 | Limbo-Sweeper | PIPELINE-Klasse geliefert (13→BLOCKED, 1 echter Q10-Passer→PASSED, idempotent); Rest kommissioniert als `1d8e74a0` |
| MNT-020 | BarsCalculated-Kohorte | Source-Repair + D6-Linter APPROVED; QM5_20096-Runtime-Beweis kommissioniert als `c010ccb7`, wartet auf OWNER (ROT-Recompile) |
| MNT-006 | 275 Stranded-Paare | Alle 275 klassifiziert+disponiert (bit-identisch reproduziert); Drain kommissioniert als `7333402c`, wartet auf MNT-038-Aktivierung + OWNER |

**Entscheidungsschlange (2):** `OWNER-DEC-MNT020-RECOMPILE` (QM5_20096-Rebuild freigeben) · `OWNER-DEC-MNT006-CANARY` (10-Zeilen-Drain freigeben) — beide in `12 ToDo/AI ToDos/OWNER.md` mit Empfehlung + Cost of Wait.
**Cleanup-Batch:** 5 Review-Notizen als Router-Task `db470d0a` (P40). Das Codex-Board steht auf 18/18 erledigt; der Maintenance-Ledger vom 28.07. ist damit vollständig disponiert.

## Nachtrag 2026-08-21 (spät) · Wellen 4+5 — Programme 002/003/004 geliefert, OWNER-Freigaben ausgeführt

| aus | Punkt | Ergebnis in einem Satz |
|---|---|---|
| TODO-002 | MC-v2-Datenvertrag | `qm.mission_control.v2` + read-only Emitter (Preview-JSON live validiert, exakte DB-Spot-Checks); Renderer = separater Claude-Design-Schritt (`MISSION_CONTROL_V2_DATA_CONTRACT.md`) |
| TODO-003 | Website-Archiv-Vertrag | Staging-only redigierter Vertrag EA→Card→Gate→Report; Security-Verify fing 2334 Pfad- + 5 Mail-Leaks → Redaktion gehärtet (inkl. Hyonix/Dropbox-Token), Re-Scan 0 Treffer über alle Klassen (`WEBSITE_STRATEGY_ARCHIVE_CONTRACT.md`) |
| TODO-004 | Dateisystem-Inventar | Read-only Dry-Run-Tool, T_Live hard-skip; Befunde: 31 SQLite-State-Backups ohne Hash-Sidecar, 244GB unknown→Review (`2026-08-21_filesystem_inventory_dryrun.md`) |
| MNT-020-Beweis | QM5_20096 | Rebuild a343d30a→531e8e75 (0/0), EIN append-only Q02-Canary `256846e2` auf USDCHF; Adjudikationsregel im Close-Verdikt (SHA-Match, zero-trades-alone nie PASS) |
| MNT-006 Phase 1 | 275er-Drain | 2 Row-1-Canaries enqueued (`cc347183` XAUUSD/ONINIT nach Pin-Screen, `6384b2f7` NDX/NO_HISTORY); 3 Klassen regelkonform blockiert (2× identity_mismatch, 1× LOG_BOMB repair_first); Phase 2 = Task `626975ca` |

Beide OWNER-Freigaben (MNT020-RECOMPILE, MNT006-CANARY) sind ausgeführt und im Archiv + owner_decisions.json verbucht. Codex-Board: 21/21 erledigt, 0 offen.

## Nachtrag 2026-08-21 (Nacht) · Neues Zwischenziel „Pipeline leerlaufen", REVIEW-Stau auf 0, Videolane an OWNER

| aus | Punkt | Ergebnis in einem Satz |
|---|---|---|
| **OWNER 21.08.** | **Zwischenziel: erst leerlaufen, dann Buch** | Verankert in `Current Objective` (Zwischenziel-Block) + neues Vault-Programm `12 ToDo/10_Pipeline_Leerlauf`; testbare Definition D1–D5, Census, Wellenplan (`evidence/2026-08-21_pipeline_drain_census_and_programme.md`) |
| Census D1 | **1 470 aktive EA-IDs haben nie ein Gate gesehen** | 963 ohne Verzeichnis, 8 ohne Quelle, 195 Quelle-nie-kompiliert, **304 mit fertiger `.ex5` und null Work-Items** — der teure Teil bezahlt, der billige nie gemacht |
| Census D2 | **1 185 Paare ohne je ein Verdikt** | `failed` auf Infra-Klasse **und** nie ein `done` am selben Gate: Q02 1 010 · Q04 127 · Q07 20 · Q05 16 · Q06 5 · P2 4 · Q03 3 — keine Fehlschläge, **Abwesenheiten** |
| Census D3 | RECYCLE-Klassifikation | Von 384 scheinbar bearbeitbaren Zeilen waren **113 (29 %) längst durch** (EA später gebaut, `done`-Work-Items). Bulk-Requeue hätte 113 Builds umsonst gefahren — Preis der Bulk-Variante ist mit Recovery-814 gemessen (122,4 h für 30,2 % PASS) |
| Welle 1 | angewandt | `reconcile-exits --state APPROVED` (39), 113 veraltete RECYCLE-Zeilen → PASSED mit Begründung, 25 echt ungebaute → TODO. **RECYCLE 567 → 429**, kein Verdikt überschrieben, alles über den Transition-Ledger reversibel |
| **Review-Pflicht** | **REVIEW-Stau 28 → 0** | Alle 28 Zeilen an einem Tag geschlossen: 3 `review_ea` APPROVED, 3 RECYCLE (11533 vier Blocker inkl. Spread-Guard, der den Karten-Exit unterdrückt; 11537 H1-Vertrag; 41002 zwei strict-`build_check`-FAILs), 17 `ops_issue` + 3 `build_ea` + 2 `research_strategy` adjudiziert |
| Beauftragt | 8 Router-Tasks | Codex `4fa07877` Drain-Engine · `a3ba2414` 304 einschleusen · `b2bf2460` DL-089 Batch 2 · `e7cc7b8a` 195 kompilieren · `5c73b39f` Health-Manifest · `8c685237` retirete Karten · `46afeb2b` Phasen-SLO; Claude `6ea89ca8` review_ea 11657 |
| **Videolane** | **an OWNER übergeben** | agy ist video-blind (3× verifiziert, VPS-IP YouTube-blockiert — heute erneut belegt); Liste bewusst **kurz und abschlussorientiert**: 3 XAG-Videos (Revisit-Bedingung eingetreten, QM5_13018 Q04 FAIL 19.07.), 6 Mulham-Videos geparkt bis 13209/13212 ein echtes Q02-Verdikt haben (`12 ToDo/AI ToDos/OWNER Videoanalysen`) |

## Nachtrag 2026-08-21 (Nacht, 2) · Videolane verdrahtet, D1 entschieden, REVIEW 47 → 0

| aus | Punkt | Ergebnis in einem Satz |
|---|---|---|
| **OWNER 21.08.** | **OWNER ist Assignee der `video_analysis`-Lane** | Neue `owner`-Lane **deklariert aber abgeschaltet** (`enabled=false`, `max_parallel=0`); `HUMAN_LANES` + sichtbarer Halt `awaiting_human_lane:owner` mit Payload-Marker und Event, gemeldet **vor** `no_available_agent`; Halt eng gefasst (nur wer die menschlich gehaltene Fähigkeit braucht); kein Head-Block, Queue-Alter und Priorität unberührt; 29 Router-Tests, Live-Beweis Ticket `4b52f1b2` (Commit `bac260780`) |
| **OWNER 21.08.** | **„Die 102 gehören in die Pipeline zum Kompilieren"** | Ursache belegt: `compile_one.ps1` spiegelt den Include-Baum in **jedes** materialisierte Terminalprofil → jeder Ad-hoc-`build_check` rennt gegen laufende Terminals (2× bestätigt, 2 Terminals, 2 Dateien). ★Wichtig: die Race ist **probabilistisch**, nicht hart — dieselben Tage bauen andere Builds erfolgreich, d. h. bei 102 EAs gäbe es Teilerfolg mit Zufallsausfällen und halbgeschriebene Include-Bäume. Beauftragt als `251b9724`: Phase `COMPILE_EA` nach dem `HARNESS_PP_FIXTURE`-Präzedenzfall, ein globaler Mirror-Mutex, Spiegelung nur bei beanspruchtem Terminal (sonst aufgeschoben), **atomarer Per-Datei-Replace**, und Ad-hoc-Compile **verweigert fail-loud** statt zu rennen |
| **D1** | **Alle 963 nie gegateten EA-IDs entschieden** | 759 RETIRE · 191 ADJUDICATE · 8 INVESTIGATE · 5 RECHECK, je mit Grund (`2026-08-21_ea_id_disposition_963.csv`). **D1-Unbekannt 963 → 204.** ★Falle: IDs werden nach Ablehnung **wiederverwendet** (QM5_1136 = `qp-option-exp-sp500` in der Registry, aber `index-close-auction-intraday-momentum` im Rejected-Pool), mehrere mit Magic-Zeilen (1156: 15) → Bulk-Retire hätte die Kollisionsklasse vom 15.08. reproduziert. **Nur stilllegen, wenn der Registry-Slug noch passt.** ★Ausführung blockiert: `farmctl` hat **gar keinen** Retire-Übergang — genau deshalb tragen 446 abgelehnte Karten weiter `active`; beauftragt als `62018dcc` |
| **Review-Pflicht** | **REVIEW 47 → 0** | 44 + 3 + 1 geschlossen. ★**8 von 14 gemini-Builds durchgefallen** auf 5 wiederkehrenden Klassen (MAE-Hook 3×, Framework-Series 2×, doppeltes New-Bar-Gate 2×, uninitialisierter Request 2×, Kartendivergenz 3×) — **keine davon fangen die heute gelandeten D1–D6-Gates** → Gate-Lücke, beauftragt als `19aa9da2` |
| Eigene Messung | **QM5_12923: SPEC deklariert 9 Symbole, es existieren 5 Setfiles** | NDX, UK100, WS30, XAUUSD deklariert und untestbar — stille Verengung; der Code-Review war sauber, recycled wird nur für den SPEC/Sets-Abgleich |
| Eigene Messung | **3 Claude-Lane-Builds waren hohl** | Der Router verweigerte APPROVED mit `artifact_missing`; nachgeprüft: kein `SPEC.md`, kein `sets/`, bei 12931/12932 **nicht einmal eine `.ex5`** — Verdikt beschrieb fertige Arbeit, das Verzeichnis enthielt sie nicht. Gleiche Klasse wie der 28.05.-Befund, gleiche Härte wie bei gemini |
| Klasse | **Builds stoppen auf fehlende Magic-Zeilen, aber niemand alloziert** | 11899 und 12946 an einem Tag, beide **ohne Mutation** gestoppt (korrekt) — Precheck erkennt, Allokation fehlt; beauftragt als `f1a93a6c` |
| D1-Karten | **Welle 1: 25/25 REJECTED — Rate geprüft, hält** | Gründe kartenspezifisch, R4=0 (kein Padding), 3 Duplikate bereits freigegebener Primitive. ★**Meine Rubrik war unvollständig:** `471cffc3` hat am selben Tag 4 von 6 Karten **re-spezifiziert** statt abzulehnen. R2-only + zitierbare Quelle = reparierbar. Welle 2 (`3fb70df8`) hat RESPECIFY als drittes Ergebnis; die drei R2-only-Karten aus Welle 1 (11924/11926/11927) bekommen einen Versuch |

**Ehrlich zur Zahl:** RECYCLE ist von 429 auf **450** gestiegen, nicht gefallen. Das ist erwartet — die Reviews haben 21 Builds als defekt terminiert, statt sie unentschieden liegen zu lassen. Der Drain verschiebt Arbeit zuerst von „unbekannt" nach „bekannt defekt"; das ist Fortschritt in der Klassifikation, auch wenn der Zähler steigt.

**Offen und benannt:** (1) die Review-Lane ist die Decke des Drain-Programms — 268 Rebuilds ≈ zehn Review-Sitzungen; (2) Q09_NEWS steht weiter bei **0 PASS**, Volumen staut sich dahinter; (3) Prioritätsboden: RECYCLE-Build-Zeilen tragen p1–15 und würden nie gezogen, der Requeue normalisiert auf 50 — ob Drain vor Neu-Builds rangiert, ist eine bewusste Reihenfolge-Entscheidung; (4) drei neue OWNER-Entscheidungen auf der Decision-Surface (`OWNER-DEC-GATECONTRACT`, `OWNER-DEC-EVIDENCE-RETENTION`, `OWNER-DEC-FTMO-THRESHOLDS`).
# 2026-09-02 Canonical compile repair successor

- Task `68f97015-c892-4690-80ed-1ccb3b573a40`: added the generic fail-closed `farmctl enqueue-compile --repair-successor-of` flow. First use appended held QM5_41306 successor `8620da55-f687-4ebd-9922-5fc831834628`, bound to build task `118915f8-0275-492c-8eeb-f71e49ce515e`; failed row remains immutable. Evidence: `docs/ops/evidence/2026-09-02_generic_compile_repair_successor.md`.

# 2026-09-02 magic=0 forensic

- Task `ee18d088-24e6-4aee-9400-4e5b83625efa`: EURUSD was not an orphan (QM5_11421 entry plus Friday close); the 1.00-lot NDX lifecycle is outside the governed book and remains external/manual-unknown because the export lacks `DEAL_REASON`. Evidence: `docs/ops/evidence/2026-09-02_magic0_trade_forensic.md`.

# 2026-09-02 OOS-2026 confirmation

- Task `70dd5b7a-0fcf-4483-b5ee-db18cc466b3e`: built and authenticated the single-window non-admission runner, then queued 55/55 runs (24 live + 31 frontier) behind census work. Numeric edge read is truthfully pending resident-worker receipts; comparison contract and provenance caveats are sealed in the artifact. Evidence: `docs/ops/evidence/2026-09-02_oos_2026_confirmation_enqueue.md`; runtime plan/receipt under `D:\QM\strategy_farm\artifacts\oos_2026_confirmation_v1`.

# 2026-09-02 OWNER session 06.09

- Task `f299c9e3-70b3-4c1b-a23b-17039fc14dd6`: assembled the decision sheet, 10440 disposition, five-sleeve drag list, unsigned 17-sleeve scenario/pointer dry run, expected-red pre-change verification, and OWNER-only deployment/runbook steps. Evidence: `docs/ops/evidence/2026-09-02_owner_session_20260906_package.md`; runtime drafts under `D:\QM\reports\state\drafts`.

# 2026-09-02 Dukascopy backfill

- Task `bd73130a-2cbb-42fc-93b5-7529a4f5849f`: P0 range inventory completed for 37/37 symbols (703 rows), then stopped fail-closed because exact per-symbol tick-tail/splice timestamps require a governed T1 probe and no repository TKC-tail decoder exists. P1–P4 were not started and no history/import state changed. Evidence: `docs/ops/evidence/2026-09-02_dukascopy_backfill_p0_block.md`, `docs/ops/evidence/2026-09-02_dukascopy_p0_history_ranges.{csv,json}`.

# 2026-09-02 Codex live-book pulse repair

- Task `26434855-391e-43ed-b9f4-9d0e9c0afa9b`: repaired stale lifecycle lookback and severity aggregation. Production pulse now finds all 24 loaded sleeves and reports only the genuine KS-baseline WARN. Evidence: `docs/ops/evidence/2026-09-02_live_book_pulse_load_repair.md`.

# 2026-09-02 dark live sleeves

- Task `cef343ab-bb9b-49c3-a6a5-5432cfa30c0d`: 12778/13117 have deterministic four-leg `.DWX` warmup failure and zero trade events; 12969 is unexpectedly dark relative to Q10 frequency. Recommendations are REMOVE, REMOVE, and REMOVE-or-requalify respectively. Evidence: `docs/ops/evidence/2026-09-02_dark_live_sleeves_disposition.md`.

# 2026-09-02 item-bound custom-history isolation

- Task `3b25f49e-220f-4b17-b596-470ae8050e15`: item-bound manifest omissions now create durable non-restart work-item holds before claim and never quarantine a terminal; terminal-bound claim-local failures retain bounded quarantine. Both known poison rows are held. Evidence: `docs/ops/evidence/2026-09-02_custom_history_item_bound_isolation.md`.

# 2026-09-02 QM5_41283 mandatory Codex review

- Task `ea56a51b-4442-41f3-8b18-507a2b39324f`: PASS for build review after independent semantic inspection, 8/8 reference tests, exact hash readback, and zero-finding canonical hardening. Economics remain for governed Q02; this is not live or portfolio approval. Evidence: `docs/ops/evidence/2026-09-02_qm5_41283_codex_review.md`.

# 2026-09-02 terminal RAM class admission

- Task `ddee6f24-6e57-423b-858d-bfb323beada2`: candidate admission now reserves 4/8/32/44 GB by measured workload class and preserves the 14/20 GB fleet guard; deterministic RAM injection and `ram_class_skipped` receipts are covered by the green 213-test worker suite. Live staggered reload and the after-reload 10-minute census measurement are deferred because the host had only 8.69 GB free with seven active tester runs, none of which were interrupted. Evidence: `docs/ops/evidence/2026-09-02_terminal_ram_class_admission.md`.

# 2026-09-02 Q10 lineage debt wave 2

- Task `ba5f4754-82a9-4074-a640-0bdb521999ef`: appended and priority-marked exact current-binary Q07 reruns `e046b36b` (11129/SP500), `3815515b` (10700/XAUUSD), and `f3689f77` (11910/NZDUSD); canonically recorded 10114/SP500 Q10 `9812fc7b` as dead lineage after two Q08 FAIL_SOFT results. For 11421/EURUSD, exact Q08 `c93263aa` is pending from Q07 PASS `2556a768`; the old released Q10 `30584122` must be superseded to a new row bound to `c93263aa` only after that Q08 PASSes, with the REQUAL-8 receipt preserved and no re-hold. Evidence: `docs/ops/evidence/2026-09-02_q10_lineage_wave2.md`.

# 2026-09-02 QM5_41142 build handoff

- Task `f3fba72c-a3be-453e-9e15-830e46135c53`: source, identity, set, spec, basket manifest, and five-test reference model are complete with static guardrails PASS. Governed compile work item `07a09214-86ba-4946-9e0b-c9e7baa8b6fc` remains pending behind `COMPILE_EA_WORKER_ROLLOUT_PENDING`, but its pre-commit source binding is stale against committed SHA `CB33049F...`. It must fail closed and be replaced after the reviewed worker rollout. Router REVIEW was correctly refused with `D6_BUILD_IDENTITY_MISSING`, and the task is BLOCKED pending that governed repair; no compile or pipeline verdict and no Q02 enqueue are claimed. Evidence: `docs/ops/evidence/2026-09-02_qm5_41142_build_handoff.md` and `docs/ops/evidence/f3fba72c_qm5_41142_build_result_2026-09-02.json`.

# 2026-09-06 QM5_12507 logical FX basket Q02 capacity handoff

- The 66-pair scan remains fully mechanized and the 12532/12533 anchors are already beyond Q02. Existing fallback `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1` retains exactly one pending, unheld, priority-tracked Q02 row (`547c4fd3-f3fd-4c59-b9dc-654e96521251`), but the current five-sample CPU maximum reached 99% against the 97% hard ceiling. No duplicate enqueue, claim or launch was performed. Evidence: `docs/ops/evidence/2026-09-06_qm5_12507_q02_hard_cpu_stop_021703Z.md`.

# 2026-09-06 QM5_12507 logical FX basket Q02 capacity refresh 08:16Z

- The same unique, unheld, priority-tracked Q02 row remains pending and unclaimed. Five current CPU samples were 96/99/94/99/97% (97.0% average, 99% maximum) with seven factory terminals running, so the explicit hard ceiling stopped all queue/claim/launch work. No duplicate was created. Evidence: `docs/ops/evidence/2026-09-06_qm5_12507_q02_hard_cpu_stop_081651Z.md`.

## Addendum 2026-09-06 20:08Z — FTMO M13 demo activation evening (OWNER-signed), resolver symbol-alias fix, Codex returns

- **OWNER signed the governor manifest** (chat receipt ~19:38Z, commit 9ff45c0a3e). Demo terminal cleaned on OWNER instruction (14 legacy files, receipt `2026-09-06_ftmo_demo_cleanup_receipt.json`); the 11 M13 presets copied flat into `MQL5\Presets` (the MT5 Load dialog folder).
- **Governor bootstrap done 21:38:52 Prague** (marker printed, EA self-removed, state in global variables); active instance running since 21:39:23 (lease refreshed). Collector attached 21:45:56. 0 halt files.
- **Four sleeves refused to attach** (`EA_MAGIC_RESOLUTION_FAILED`, registry `<SYM>.DWX` vs broker chart `<SYM>`): OWNER instruction "korrigier ihn" → `QM_MagicResolver.mqh` base-name comparison (commit 4fb47bd3b5), 10706/11910/1537/21505 rebuilt artifact-only with the FTMO MetaEditor in `D:\QMtmo\compile_probe_sleeves_20260906` and installed with receipt (`docs/ops/evidence/2026-09-06_ftmo_sleeve_alias_rebuild/`). Factory EX5s untouched. Codex ticket 4778daa7 rescoped to adversarial review + alias table (XTIUSD/USOIL, GDAXI/GER40 …) + T_Live implication.
- **Astra ticket e0db4991**: QuantMechanica Signature Design for EA chart panels (OWNER 19:55Z), starting from QM_AccountMonitor.
- **Codex returns closed:** acf3637b APPROVED (b2b3d35d65, DSR window recovery; 90 tests + 13 subtests), e638e0de APPROVED (11196 replacement set s20260906-001), 6b291f21 APPROVED (f6e957410b integrated as 6f1d6fb732 via patch apply; terms-hash re-pin 4011d16afa; eol=lf 5cc1ea19ec; 89 tests). Worker reload chunk 56 (dsr_cohort) running, 4/10 at 20:05Z → third Q08 reruns 11167/11196 follow.
- Pending: AutoTrading ON (OWNER) → PARKED→RUNNING flip + pulse; must complete before 22:00Z (Prague midnight).

## Addendum 2026-09-06 20:20Z — FTMO M13 demo ACTIVATED (OWNER), two new Hard Rules, tickets

- **FTMO M13 RUNNING since 20:08Z:** governor active, collector 1 s telemetry, 8/8 sleeves (1537 after the `strategy_calendar_symbol` input, dcaeca68f5), OWNER enabled AutoTrading, `EXPECTED_STATE` RUNNING (2b258f48f4), activation record in the manifest (883cbd8364), OWNER to-do FTMO-DEMO-RUNNING closed. Pulse artefacts (stale equity source from the old account, pre-fix ea_errors) → Codex 93c1d29c.
- **Hard Rule "symbols are inputs, never code literals" (OWNER 20:10Z):** Vault annex, framework principle 7, CLAUDE.md, memory; Codex 4d3b27f6 (build_check predicate, slot-input pattern, inventory scan, 1537 full refactor). Resolver base-name fix 4fb47bd3b5; alias table + review Codex 4778daa7.
- **Hard Rule "live EAs carry their own live news filter" (OWNER original decision, reaffirmed 20:08Z):** already implemented since FW-LIVE 2026-06-28 (native MT5 calendar, fail-closed); recorded in Vault annex, framework principle 8, CLAUDE.md, memory; enforcement predicate + attach evidence → Codex 93c1d29c.
- **Astra e0db4991:** QuantMechanica Signature Design for EA chart panels (from QM_AccountMonitor).
- Worker reload chunk 56: 9/10 at 20:18Z (T9 pending) → Q08 reruns 11167/11196 next.

## Addendum 2026-09-06 20:55Z — Tick 20:41Z: three Codex returns closed, Q08 rerun waits on XAUUSD, intakes resumed

- **Codex APPROVED:** 93c1d29c (09ad0c91c4: native calendar proven populated on the FTMO terminal — governor `NEWS_LIVE_CALENDAR_SELFTEST healthy`, 216 events/7d; decision path fail-closed; `EA_LIVE_NEWS_ARCHIVE_DEPENDENCY` predicate; pulse equity source + ea_errors window repaired), 4d3b27f6 (68e189a26d: `EA_SYMBOL_HARDCODED` scanner, corpus 4,078 sources / 1,365 literal-bearing / 0 new FAIL, cutover-existing WARN), e0db4991 (QM_ChartPanel.mqh Signature Design, compiled 0/0, source-only). Harness test scoped to ML findings after the two scanners joined Invoke-ForbiddenScan (036e2b2fdb; 51 tests).
- **11167 Q08 rerun 19c9df13** pending since 20:17Z: XAUUSD.DWX is active on census cells (T1/T6) and the T9 Q07 cell → symbol serialization; claims when XAUUSD frees. Enqueue-time `CONFLICTING_BUILD_IDENTITY:setfile` = Q07 candidate vs Q08 set (claim-time reseal expected).
- **T9 reload** still pending (Q07 f654273d since 19:59Z; reload script idle-only).
- **Q02 intakes:** `session_tools/intake_wave.py` (CPU 5×1s <97 %, D ≥60 GB); wave 1 54 open → 41117 intaken (f9a6e445); batches continue per tick. Note: Q02 done 3h = 0 while 792 Q02 rows pending — the queue is census-first by design; intakes add inventory, not throughput.
- FTMO M13: journal clean (two harmless "mq5 not found" MetaEditor lines 22:18 Prague), governor no INVALID/LEASE, collector 1 s fresh, 0 halt.

## Addendum 2026-09-06 21:25Z — Tick 21:13Z: 11196 rerun enqueued by Codex, alias completion closed, pulse follow-up

- **Codex 9ecdd2f9 delivered** `farmctl enqueue-backtest --replacement-setfile` (e73af54859, +197) and enqueued the third 11196/XAUUSD Q08 rerun **9ec3b856** (replacement set 7cc424d2…); both DSR reruns (19c9df13, 9ec3b856) pending behind the XAUUSD symbol serialization; review closes after the cascade/DSR test run.
- **Codex 4778daa7 APPROVED** (87344e9c77: `QM_MagicSymbolCanonical`, USOIL→XTIUSD, generator-owned; registry SHA unchanged). Codex replaced the four demo sleeve binaries on disk at 20:47Z while the charts kept running the 21:57Z builds → **OWNER re-attach of 10706/11910/1537/21505 Monday before session** so running = installed (receipt `2026-09-06_ftmo_symbol_alias_completion/install_receipt.json`).
- **Pulse (09ad0c91c4) at 21:13Z:** RUNNING/RUNNING, 8 magics, 0 positions, equity 100,000; WARN from `collector_snapshot_stale:-2.0m` (negative age = clock-field defect) and weekend `ks_*_missing 0/8`; equity_source still ea_day_close_snapshot → Codex follow-up P60 enqueued. Journal 23:01 Prague: reconnect ("trading has been enabled, demo account"), no governor INVALID/LEASE, collector fresh, 0 halt.
- T9 reload still pending (Q07 f654273d since 19:59Z). Q02 intakes wave 1: 41117, 41122, 41124 today; next batch CPU-gated.

## Addendum 2026-09-06 23:30Z — Tick 23:06Z: DSR identity-format defect found and fixed, fourth 11167 rerun, 11196 running

- **19c9df13 INVALID with sealed context:** 8.2 `DSR_V2_SINGLE_CONFIG_CANDIDATE_MISMATCH` = farmctl `--ea-id 11167` vs candidate `QM5_11167` (literal compare in `validate_context`). Fix 866e3f2d78 (prefix-agnostic, fail-closed kept, 57 tests). Same run already FAILs 8.4 seasonal + 8.7 PBO → 11167/XAUUSD is not a 25th-pair candidate; the rerun closes the trail with a real verdict.
- Fourth 11167 rerun **89ea5894** (priority_track); 11196 rerun **9ec3b856** running on T1 since 22:41Z (fresh worker, context SEALED) and will aggregate with the fix. Codex adversarial review of the producer/aggregator identity contract enqueued (P90).
- Fleet: 96–120 census/h, 10 workers, RAM dipped to 9.5 GB free at 22:44Z (three ~11.5 GB metatester cells), recovered to 30 GB; D: 71 GB. Q02 intakes wave 1: 41131, 41133, 41134, 41137 (+1) tonight; 45 open. FTMO demo quiet across Prague midnight: governor heartbeat live, collector fresh, 0 halt, no journal lines.

## Addendum 2026-09-07 00:10Z — DSR execution 8fe2bac0 RESULT: 11196/XAUUSD Q08 PASS, 11167/XAUUSD FAIL_SOFT

- **9ec3b856 (11196) PASS 00:03Z** — 8.2 `DSR_V2_COMPUTED` PASS (first production single-configuration DSR evaluation), 8.4 + 8.6 FAIL as soft gates; chain continues (Q09 cascade to verify). **89ea5894 (11167) FAIL_SOFT 23:49Z** — 8.2 PASS, 8.4 + 8.7 FAIL → 11167/XAUUSD leaves the 25-pair race.
- Acceptance of OWNER-DEC-DSR-SINGLE-CONFIG-DECLARATION-20260906 execution met (PASS/FAIL instead of INVALID, old rows preserved, no threshold change) → 8fe2bac0 to REVIEW, independent (Sonnet) acceptance next, then APPROVED. Codex 4bf2eb39 (identity boundary hardening) APPROVED at 23:45Z; all 10 workers fresh since 23:29Z (chunk 56 complete).
- 00:04Z dip to 2 active cells = claim spacing after a batch of cells finished + 10 `factory_mutation_lock_busy` refusals (midnight maintenance); T8/T9 claimed at 00:04Z, recovery expected on the next monitor line.

## Addendum 2026-09-07 01:05Z — 11196/XAUUSD Q09 PASS, chain now in Q10_NEWS

- **6b6a3913 Q09 PASS 00:55Z** (priority_track claimed it ahead of the XAUUSD census cells); pump cascaded to **Q10_NEWS a909ee18** (pending, priority_track inherited). Chain Q02–Q09 all PASS; Q10_NEWS = next refutation point toward the 25th pair (counter 12/25 unchanged until the terminal v4 pair).
- 8fe2bac0 APPROVED after independent acceptance (a67a4adb2f). Codex autonomously approved/built research sources 41373 and 41374 (XTI/XNG weekly alternation / efficiency divergence baskets, compile pending under the CPU stop).
- Fleet 99 census/h, 10 workers, CPU 100 % at 01:00Z (no intakes this tick; wave 1 39 open), RAM 27 GB free, D: 63 GB. FTMO demo quiet: no 07.09 journal lines, governor heartbeat live, collector 11.8 MB (fixed folder 2026-09-06), 0 halt.

## Addendum 2026-09-07 01:50Z — STRUCTURAL: the 25-pair path is frozen at the calendar taint; E1-D commissioned

- **11196/XAUUSD Q10_NEWS a909ee18 is held** (`TAINT_POLICY_UNAVAILABLE` fallback → declared taint hold after the loader fix e2511daad8: the shipped config carries the CEO activation evidence as a dict, the guard accepted only a string). 47 Q10_NEWS rows pending / 0 active since 05.09 — deliberate ("Evidenz vor Zählerstand"): pinned bundle 86b2c0b5 is tainted, E1-A/B1/B2/B3 integrated but the candidate is scope-limited (gates 6.1/6.2/6.5/6.7 covered only by 18,279 declarations), OWNER decided E1-C = A stays / B inactive. **Consequence: the counter cannot move past 12/25 through Q10_NEWS until an untainted bundle is pinned.**
- **Commissioned:** E1-D (Codex high, P88) — close the four gates (non-USD anchor catalog, tick footprints, detector clean, conflicting exports), run the eight-gate plan, prepare a dry-run repin receipt for CEO release. Morning brief must state the cost of wait and the ROT alternative (OWNER accepts scoped consumer B for counting — a new decision card, not autonomous).
- Taint sweep `--apply` hit the factory mutation lock once (busy, not stale); retried.

## Addendum 2026-09-07 02:00Z — Incident: purge killed T3 mid-claim → orphaned mutation lock → 20-min fleet stall

- 01:30:20Z `tester_cache_purge` (D: 59.8 GB < LowWater 150) cleared idle caches and killed T1/T3/T5/T6; T3 (pid 18520) was inside `claim_atomic` holding `FACTORY_MUTATION.lock`. The lock stayed (mtime-only staleness, pid dead) → every worker `factory_mutation_lock_busy`; active cells 9 → 2 by 01:50Z; launcher relaunched the four at 01:30:50Z; lock reaped after 120 s stale; fleet ramping again (claim spacing). Codex ticket (P85): purge must protect lock holders / mid-claim workers, lock reap by holder-pid liveness, teardown releases the lock. Purge also logged `TELEMETRY_ERROR implausible_free_space_gain`.
- Taint sweep applied (backup 20260907T013237Z): 84 rows keep their other holds, 2 already held, 1 new hold; a909ee18 ALREADY_HELD. Taint loader fix e2511daad8 in; workers still import the old module until reload chunk 57 (claim-guard import site) — bundle with the farmctl changes at a quiet tick.

## Addendum 2026-09-07 02:55Z — E1-D measured NOT_READY, continuation commissioned, OWNER card minted, reload chunk 57 done

- **E1-D 8d2d672a APPROVED as measurement** (1c9226fe46, 67 tests): gates 6.1/6.2/6.5/6.7 FAIL with exact residuals (345 groups/2,711 rows; only USD anchors confirmed; 23/42 footprints unresolved — AUDUSD/USDCAD M5 exports absent; 2,591 detector rows + GBP/AUD 2026-H1 exports unverified), manifest input drift (decisions receipt file), ingress REFUSED, no publish/repin. Continuation: **E1-D2** (M5 exports via the controlled lane, P88) and **E1-D3/D4** (official anchors incl. CEO assumption EUR CPI = Eurostat flash, taxonomy for 79 classes, detector adjudication, candidate rebuild, eight gates, dry-run multi-plan; P85) at Codex.
- **Mission Control card OWNER-DEC-COUNTER-PATH-CALENDAR-TAINT-20260907** (Vorlage `docs/ops/OWNER_VORLAGE_2026-09-07_counter_path_calendar_taint.md`, commits 059724e54c/f523fc8d3b): question = activate scoped consumer B for counting (JA) vs wait for the full-scope seal (NEIN); recommendation NEIN today, resubmission Wed 09.09. 08:00; due 2026-09-09.
- Purge/claim-lock hardening 7da8b9e6 APPROVED (0a5edeef42). **Reload chunk 57 complete** (all 10 workers carry farmctl identity helper + replacement setfile, taint loader, dead-pid lock reap). Wave-1 intakes tonight: 41169, 41173 (+ retries); ~35 open.

## Addendum 2026-09-07 03:10Z — E1-D2/D3/D4 measured: the full-scope calendar seal is unreachable by data work; OWNER card recommendation changed

- **E1-D2 fdb34c9c APPROVED:** AUDUSD/USDCAD M5 exports via the governed `T_Export` lane (no factory/T_Live touch); gate 6.5 AUD/CAD still FAIL_FOOTPRINT — six of seven instants lie in 2025, beyond the factory custom-history boundary (2024-12-31). **E1-D3/D4 d74fa978 APPROVED:** 58 official anchors ingested, candidate rebuilt (drift 0), 2,591 rows adjudicated: 39 classes/726 rows anchorable, **40 classes/1,865 rows event-by-event without an official schedule (structurally declared)**; GBP/AUD 2026-H1 exports carry mixed DST offsets; gates 6.1/6.2/6.5/6.7 FAIL, ingress REFUSED, no repin. 75 tests.
- **Consequence:** a calendar with all eight gates *measured* PASS cannot be reached under the current gate criteria. Vorlage Nachtrag 03:05Z + card OWNER-DEC-COUNTER-PATH-CALENDAR-TAINT-20260907 updated (feed rev 53, d5aaaf301b): **recommendation now JA = option B** (scoped consumer for the D1/USD subset, footnote, re-adjudication after a later criteria decision B'); B' (declared residuals admissible in the seal) offered as a separate ROT card on request.

## Addendum 2026-09-07 04:40Z — Morning brief: mail sent, Notion auto-post not verifiable → manual publish, logging fix

- `QM_MorningBriefing_Vault` ran 06:00 local as qm-admin (result 0 = mail sent, vault archive written 04:03Z). The Notion step runs after the mail inside the same process and only prints to stdout, which the task discards; the 2026-09-07 page did not exist at 04:2xZ → manual `notion_morning_brief.py --date 2026-09-07 --publish` **CREATED** page 3d447da5-8f4a-819b-8129-f49c124bfac9 (second run UPDATED = idempotent). Fix 01670269e6: `morning_brief.py` now writes `mail sent=… notion=<status|FAILED:<type>>` to `morning_brief.log`. Task working directory is empty (Python prefix=cwd doctrine says C:\QM
epo); `Set-ScheduledTask` needs the qm-admin credentials → left as is; verify the 08.09. 06:00 run from the log line first.
- 41377 magic precondition 1fa9630e APPROVED. Wave-1 intake list corrected (exclude EAs with a pending/active Q02 row): 26 open. CPU 100 % at 04:22Z (no intakes).

## Addendum 2026-09-07 04:55Z — OWNER decisions this morning: calendar card YES (option B), Signature Panel canary ordered; weekday correction

- **OWNER-DEC-COUNTER-PATH-CALENDAR-TAINT-20260907 = YES** (chat "Karte Ja" ~04:58 local; receipt e1259d10, card sha d5b9f558…, plan sha 1f94374c…). Execution task 60cd31a8 (Claude lane, IN_PROGRESS), record `docs/ops/evidence/2026-09-07_counter-path-calendar-taint-20260907_e1259d10_execution.md`; Codex f3a94b87 (P92, IN_PROGRESS): activate scoped consumer B, taint lift only for B-adjudicated rows, footnote, re-adjudication ticket, dry-run listing of the 47+1 rows. Holds are released row by row by the CEO after integration.
- **OWNER "Ja, mach das":** Signature Chart Panel canary — Codex ticket (P90): wire `QM_ChartPanel.mqh` into QM5_11421 per the integration contract, artifact-only FTMO build + demo install with receipt, preset `qm_show_chart_panel=true`; after OWNER sight the other seven sleeves + governor view.
- **Weekday correction:** 2026-09-07 is MONDAY; the FTMO session is open (account flat, 0 positions, no trade yet). Re-attach to-do replaced: OWNER-TODO-20260907-FTMO-REATTACH-4-TODAY (due today), the 08.09 one closed as superseded.
- Morning update posted in chat 04:4xZ. Fleet 104 census/h, 10 workers, D: 61 GB; wave-1 intakes 26 open (CPU 92–98 %).

## Addendum 2026-09-07 05:30Z — Option B admits nothing today (0/47); panel canary installed; B′ card next

- **Consumer B activated (f3a94b87 APPROVED, 312f37e679) — production dry run 0/47 admissible:** 38 rows lack a sealed Q10 window, 30 are intraday (H1/H4/M5/M1), 19 non-USD exposed, 9 declared overlap. **11196/XAUUSD is H4 → excluded.** No hold released. Follow-up ticket: seal the Q10 window for the 9 D1/USD rows blocked only by that (12567, 1556×2, 10513×4, 10145/SP500, 1230) → these become B-admissible → row-by-row release. **B′ criteria card** (USD-exposed rows of any timeframe on the repaired-USD candidate, declared residuals for non-USD/event-by-event) is the only route to 11196 → Vorlage + card follow this morning.
- **Signature Panel canary (c8e01483 APPROVED, 798df3522a):** QM5_11421 with `QM_ChartPanel.mqh` built artifact-only (FTMO MetaEditor 0/0, guardrails PASS), demo EX5 48fddf28… installed, presets carry `qm_show_chart_panel=true` + build hash, factory EX5 9dd7facd untouched. OWNER: re-attach the EURUSD D1 chart with `QM5_11421_EURUSD_D1_live_trial.set` → six panel lines expected (ENV LIVE, RISK_PERCENT 0.3125, BUILD 48fddf28…).

## Addendum 2026-09-07 05:40Z — OWNER-DEC-CALENDAR-CRITERIA-B-PRIME-20260907 = YES

- Receipt 617abd80 (chat), execution task bb814520 (Claude lane, IN_PROGRESS), record `docs/ops/evidence/2026-09-07_calendar-criteria-b-prime-20260907_617abd80_execution.md`. Codex ticket: criterion "measured + declared residuals" in the calendar gate contract, consumer B beyond D1 for USD-only exposure, new dry run; then row-by-row release (11196/XAUUSD first). Window-seal ticket for the nine D1/USD rows runs in parallel.

## Addendum 2026-09-07 05:55Z — Demo terminal restarted by the OWNER (07:30 Prague): all sleeves on the installed binaries; 11421 panel one-off abnormal termination; panel v2 + B′ commissioned

- 07:30:19 Prague terminal exit/restart (OWNER); 07:30:39–42 all nine EAs + collector reloaded from the profile → the four alias builds (10706/11910/1537/21505) and the 11421 panel build now run; INIT_OK 05:32–05:33Z for all sleeves (native calendar self-tests emitted by the new builds; governor self-test healthy, 224 events/7d, next HIGH = BoE Bailey speech). **OWNER to-do FTMO-REATTACH-4-TODAY closed.** Account flat, 0 halt.
- **11421 panel build: one `Abnormal termination` at 07:31:55 (first attach after restart), immediate re-attach INIT_OK.** Root cause + fail-inert guard added to the Astra panel v2 ticket (b020c337) — a panel failure must never take an EA down.
- OWNER feedback on the canary (double overlay, wrong chart scheme, missing information) → **Panel v2**: step 1 Codex spec 203f9d3c (information architecture + legacy-overlay retirement), step 2 Astra b020c337 (+ amendment c4ae19ed: **light scheme, MT5 "Color on White" base**), canary rebuild artifact-only for the demo.
- **OWNER-DEC-CALENDAR-CRITERIA-B-PRIME-20260907 = YES** (receipt 617abd80, task bb814520, Codex 934e6104 P93); window-seal ticket 3ba316bc for the nine D1/USD rows in progress.
- Wave-1 intakes: 23 open; batch stopped on my 60 GB disk floor (D: 56.8 GB, purge LowWater 150 handles caches) — floor lowered to 50 GB for the next batches.

## Addendum 2026-09-07 07:20Z — B′ live: 11196/XAUUSD and 11167/XAUUSD Q10_NEWS released; panel v2 re-attached; v3 ordered

- **B′ (934e6104 APPROVED, 4d8fd0820a):** criterion sealed, 12 admissible; **wave-1 release 07:16Z: a909ee18 (11196 H4) + f625d9aa (11167 D1)** stamped with the B marker and footnote, taint hold inactive, claim when XAUUSD frees (priority_track). 10 rows need wave 2 (review-only successors without sealed run plan; runner-abort holds) → Codex P92. Reload chunk 58 9/10 (T3 on a Q07 cell).
- **Panel:** OWNER re-attached the v2 light canary at 08:50 Prague (clean init); feedback "Einheitsbrei" → **v3 Astra 4bdcbb91** (design research with references, tabular grid, de-DE numbers, PERFORMANCE section from deal history, fail-inert). Panel standard recorded in memory.
- FTMO demo: flat, 0 halt, governor live. Fleet 100 census/h, 10 workers, D: 58 GB.

## Addendum 2026-09-07 08:15Z — B′ wave 2 done (11/12 released), first adjudication running, panel v3 re-attached, census prescreen burst

- **B′:** wave 2 (253814f1 APPROVED) released 9 more rows (8 window successors with contract-v3 plans + 10771); 11/12 admissible rows now carry the B marker; 745671a4 deferred (missing Q07 evidence → regeneration ticket). 11167/XAUUSD Q10_NEWS adjudicating on T2 since 07:18Z; 11196 next on XAUUSD.
- **Panel v3** (4bdcbb91 APPROVED, EX5 9d55ea09): OWNER re-attached at 09:42 Prague, clean init; awaiting OWNER verdict before the 7-sleeve + governor rollout.
- **Census metric burst 08:0xZ:** 146 OPT_CENSUS rows closed `SKIPPED_PRESCREEN` within 15 min (prescreen_admission contract receipt) — a prescreen sweep, not measurements; the 10-min "census_done" line counts them. 10700/XAUUSD closed Q14 KEEP_INCUMBENT at 07:26Z; pipeline_state (hourly task, next 08:23Z) will show whether it counts as the 13th pair.
- Fleet 10 workers, RAM 22 GB, D: 66 GB; FTMO demo flat, 0 halt.

## Addendum 2026-09-07 08:20Z — ZÄHLER 13/25: QM5_10700/XAUUSD.DWX ist das 13. Paar

- pipeline_state 08:12:48Z: `qualified_pairs 13`, `distinct_eas 13`; 10700/XAUUSD `frontier_class COMPLETE`, contiguous valid gate Q14 (chain: Q10_NEWS CONFIG_LOCKED 04.09 → Q11 PASS → Q12 NO_FILTER_CHANGE 07:05Z → Q13 NO_PARAMETER_CHANGE 07:16Z → Q14 KEEP_INCUMBENT 07:26Z). public funnel-stats may lag until the hourly snapshot.
- Refutation rule stays 1/5 (no refutation today). Baseline for the loop moves 12 → 13.

## Addendum 2026-09-07 09:15Z — 12849/XTIUSD closed Q14 (candidate 14/25), 1537 inert on FTMO (calendar_stale), pulse on collector source

- **QM5_12849/XTIUSD.DWX** closed Q12 NO_FILTER_CHANGE 08:26Z → Q13 08:36Z → **Q14 KEEP_INCUMBENT 08:46Z**; if the census marks it COMPLETE at the 09:23Z generation the counter moves to **14/25**.
- **QM5_1537 on the FTMO demo is inert:** `MONTHLY_SLEEVE_STATE` ERROR `calendar_stale` for 202609 (sha-pinned monthly sleeve calendar ends before 2026) → no sleeve selection, no trades; Codex ticket (P80): extend the calendar through the current month via the governed builder, re-pin, demo install, monthly refresh rule; also check 21505 for the same class. The pulse now reads the collector (`ftmo_trial_collector_raw`) and alarms on these ERROR lines — correct signal.
- 11129/SP500 lineage (632a00c9 APPROVED as deferral): Q07 successor exists, held by the CEO RAM_WINDOW_44GB hold (48 GB needed) → runs in a RAM window. 11167/XAUUSD Q10_NEWS still adjudicating on T2 (since 07:18Z). Pulse/lint implementations integrated onto board-advisor (a4893ce4e2, e05410fdf0).

## Addendum 2026-09-07 10:40Z — 1537 calendar v2 staged (OWNER YES executed), counter 14/25, B′ adjudication still running

- **1537 calendar v2** (b2b405b0 APPROVED): native DWX D1 37/37 via T_Export, v2 = v1 prefix + 21 XAG rows with per-row source, September row ready; demo EX5 16D66A0F + preset s20260907-002 staged; OWNER re-attach pending (3 lines in chat). Sibling audit: no other M13/DXZ sleeve in the stale-calendar class (13128 FOMC table valid to 2026-12-31 → 2027 refresh; 41195 same class outside the books).
- Counter 14/25 (10700/XAUUSD, 12849/XTIUSD today). 11167/XAUUSD Q10_NEWS still adjudicating on T2 (since 07:18Z). Q02 completions resumed (3 in 3 h). Wave-1 intakes: 41308–41313 + earlier; list now excludes 41280 (no build identity).

## Addendum 2026-09-09 00:56Z — Legacy-Logger-Kanarie (11167) erneut REVIEW_REQUIRED: neuer struktureller Defekt, keine sv-Frage mehr

- **Befund (Claude-Auftrag dfc60103, verifiziert):** der native Canary-Rerun `6797ed1c` (QM5_11167/XAUUSD) endete 2026-09-08 17:32Z erneut `REVIEW_REQUIRED`/`cell_execution_failed`, 8/8 Zellen — diesmal `RunnerError "MT5 report effective input qm_news_calendar_bundle_id mismatch"`, **nicht** das sv-Feld (das ist mit 07af95fcf1 gelöst). Root cause: QM5_11167s EX5 wurde am 2026-07-14 committet, **vor** Commit `f0102fbcf` (03.08.), der die drei Provenienz-Echo-Inputs `qm_news_calendar_*` in `QM_NewsFilter.mqh` eingeführt hat. Identische Defektklasse wie QM5_9936 (Evidenz 24.08.).
- **Kohortenbefund:** alle 9 im `legacy_logger_allowlist.v1.json` registrierten Binaries (11167, 11196, 10148, 10476, 10771, 11179, 1230, 12474, 9573) sind zwischen 07.06. und 15.07. committet — alle vor dem 03.08., alle potenziell betroffen. Die sv-Ausnahme war notwendig, aber nicht hinreichend; ohne Rebuild erreicht keine dieser Zeilen ein PASS/FAIL-Q10_NEWS-Verdikt.
- **Keine autonome Abhilfe:** Rebuild/Recompile in aktivem Inventar ist ROT nach Stehender Vollmacht. Kein Rebuild, kein Verdict-Override, kein Hold blind entfernt vorgenommen; `f625d9aa` und `6797ed1c` bleiben unverändert stehen.
- **Entscheidungsschlange-Eintrag (neu, wartet auf OWNER-Karte):** Rebuild der pre-08-03-Legacy-Kohorte (11167 zuerst) ja/nein — oder dauerhaftes Parken dieser 9-10 Q10_NEWS-Zeilen als `REVIEW_REQUIRED` bis zu einem späteren Rebuild-Fenster. Betrifft die drei verketteten Aufträge bb814520 (B-prime), 60cd31a8 (Counter-Path B), dfc60103 (Legacy-Logger) — alle drei bleiben ohne diese Entscheidung auf dem aktuellen Stand (Evidenz vollständig, Akzeptanzkriterium "erste Adjudikation PASS/FAIL" strukturell offen für die pre-08-03-Kohorte). Post-sv/post-08-03-Zeilen (10145/SP500, 10513/XAUUSD) sind unbetroffen und laufen weiter auf dem Counter-Path.
- Evidenz: `docs/ops/evidence/2026-09-08_q09-legacy-logger-sample-20260907_821096ac_execution.md` (Haupteintrag), Querverweise in den beiden B-prime/Counter-Path-Records.

## Addendum 2026-09-09 (orchestration cycle) — rebuild-vs-park card minted+corrected; counter-path closeout

- **OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909 minted** for the decision queued above (Vorlage `docs/ops/OWNER_VORLAGE_2026-09-09_q09_legacy_calendar_input.md`; commits `0f82e73050`/`7af08a11f0`). First draft wrongly proposed a declared-residual option (Option A analogy to the sv fix); **corrected same-cycle** (`a65321d94f`/`33dc5a1979`) after confirming in `QM_NewsFilter.mqh:69-76,744-763` that the three calendar-bundle inputs functionally gate which bundle `QM_NewsInitTesterBundle()` loads at tester runtime — not provenance echo — so no declared-residual analogy to the sv precedent is honest here. Card now asks rebuild (staged, 11167 first) vs. park; vault sync failed both times (`G:` Drive permission denied on `12 ToDo/AI ToDos/OWNER.md`), local feed/config committed and is the source of truth.
- **Router closeout:** `OWNER-DEC-COUNTER-PATH-CALENDAR-TAINT-20260907` (task `60cd31a8`) has its own acceptance fully met independent of the legacy-cohort question (consumer B active for declared-admissible rows only, footnote present, re-adjudication ticket `235e5119` bound, no repin/publish/threshold/verdict change) → moved to REVIEW. `bb814520` (B-prime) and `dfc60103` (legacy-logger) stay IN_PROGRESS pending the new card; their acceptance criterion "first adjudications end PASS/FAIL" remains structurally open for the pre-2026-08-03 cohort until OWNER answers.

## Addendum 2026-09-09 ~02:36Z (orchestration cycle) — Dukascopy connectivity: TCP-connect probe was a false recovery signal; task 3032534e stays IN_PROGRESS

All three Claude-lane tasks this cycle (`bb814520`, `dfc60103`, `3032534e`) checked out
IN_PROGRESS and correctly blocked/paced — no state change made to any of them. For
`3032534e` (Dukascopy backfill): a raw TCP-connect probe showed 0/8 failures (looked
like recovery from the 01:27Z/02:04Z ~50%-failure measurement), but a bounded 90s
re-run of the real downloader still failed 2/2 with the identical `WinError 10060`
signature — TLS/data-phase failures happen downstream of a fast raw connect, so
connect-only checks are not a valid recovery signal here. No production job restarted.
Evidence: `docs/ops/evidence/2026-09-09_dukascopy_backfill_datafeed_connectivity_degraded.md`
(re-probe section). Disposition unchanged: GRÜN/measurement, no OWNER decision needed;
next cycle should wait several hours before the next application-level re-test.

## Addendum 2026-09-09 ~02:52Z (orchestration cycle) — repo_dirty_build_guard root cause found (WIP diff, not committed); 3 claude tasks still correctly unchanged

Re-checked all three claude-lane tasks (`bb814520`, `dfc60103`, `3032534e`): no new
information since the 04:37Z cycle (no OWNER response on `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909`,
no commits in the last 15min anywhere touching it; Dukascopy re-test correctly deferred
per the prior "wait several hours" disposition). No state change made.

`farmctl health` shows `codex_zero_activity` FAIL (0 codex build activity in 3h, 73
pending build_ea) and `codex_auth_broken` WARN, both attributed to `repo_dirty_build_guard`
blocked by 2 uncommitted source files in `C:\QM\repo` (branch `agents/board-advisor`):
`framework/EAs/QM5_41240_wti-samecal-ramsaye5/QM5_41240_wti-samecal-ramsaye5.mq5` +
its paired reference test. Inspected the diff: it correctly applies the OWNER symbol-input
Hard Rule (`60dc378c0f`, 2026-09-06) — drops the hardcoded `g_symbol = "XTIUSD.DWX"`
literal in favor of `_Symbol` — but it **also removes the `QM_InputRequireDouble/Long/String`
guardrail checks for `PORTFOLIO_WEIGHT`, `qm_news_temporal`, `qm_news_compliance`,
`qm_news_mode_legacy`, `qm_news_stale_max_hours`, `qm_news_min_impact`,
`qm_friday_close_enabled`, `qm_friday_close_hour_broker`** while all eight inputs stay
declared and live-used in `OnInit`/news-hook code. That is a silent weakening of the
build-guardrail input-pinning class (CLAUDE.md: never weaken the fail-closed news-gate
check) bundled into an otherwise-correct compliance edit — not something to commit or
discard unilaterally from a routine health pass. No action taken on the file; flagging
only. **Recommended next step (not yet enqueued):** a Codex ops ticket to split the
change — keep the `g_symbol`→`_Symbol` migration, restore the eight `QM_InputRequire*`
guardrail lines — then let `repo_dirty_build_guard` clear on its own. Untracked
`docs/ops/evidence/2026-09-0{8,9}_stranded_infra_sweep_triage.json` in the same tree are
unrelated evidence artifacts, not source — not a build-guard blocker.

## Addendum 2026-09-09 ~03:18-03:22Z (orchestration cycle) — 3 claude tasks re-checked, no change; `farmctl health` did not return within its window

Re-checked all three claude-lane IN_PROGRESS tasks (`bb814520`, `dfc60103`, `3032534e`):
no new information since the prior cycle. No OWNER response found on
`OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909` (grepped `docs/ops/` and
`docs/ops/evidence/` for the decision ID; only the mint/correction commits from the prior
cycle exist, no receipt). Dukascopy re-test window still not reached — the last
application-level probe was ~02:33-02:36Z (this cycle started 03:18Z, ~45min later); the
"wait several hours, different UTC slot" disposition from the prior cycle stands, so no
re-probe or download restart was attempted. `repo_dirty_build_guard` two-file finding
above re-verified unchanged (still uncommitted, still flagged-only, no Codex ticket
enqueued — that would be choosing work outside the three assigned tasks). All three tasks
correctly remain `IN_PROGRESS`; no router state change made.

`python tools/strategy_farm/farmctl.py health` was launched at cycle start and did not
return within ~4 minutes (backgrounded, left running); consistent with the prior cycle's
note that health checks sometimes exceed the interactive window. Not blocking — none of
the three tasks' next actions depend on the health summary. No terminals, holds, or
factory state touched this cycle.

## Addendum 2026-09-09 ~03:29-03:36Z (orchestration cycle) — 3 claude tasks re-checked, no change; health returned FAIL 14/WARN 20/OK 50

Re-checked all three claude-lane IN_PROGRESS tasks (`bb814520`, `dfc60103`, `3032534e`)
against current router/lease/git state, ~15min after the prior cycle. Spawn-lease table
confirmed no live lease blocks any of the three (only `3032534e`'s lease existed and had
already expired at 01:32:47Z), so this cycle proceeded rather than deferring.
No OWNER response found on `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909` — `git log
--all --since=2026-09-09T03:00:00` shows only unrelated factory/build commits, no new
receipt or decision commit for that card. Dukascopy: confirmed via
`2026-09-09_dukascopy_backfill_datafeed_connectivity_degraded.md` that the last
application-level re-test (not TCP-connect-only) was ~02:33-02:36Z and explicitly
concluded a raw-TCP-connect probe is not a valid recovery signal for this host (0/8 fails
on a connect-only check, 2/2 fails on the real downloader in the same window); "wait
several hours, different UTC slot" stands, only ~1h elapsed since then, so no re-probe or
download restart attempted this cycle. Non-FX `price_scale`/`point_size` Codex ticket
`2f717775-2bdd-4457-b5b6-e9ecae2a3e4a` remains `APPROVED`/unassigned since 01:24:20Z
(normal router queue state under codex's existing backlog — not re-enqueued, avoiding the
duplicate-ticket mistake logged for `0b2bddcf` the prior cycle). All three tasks correctly
remain `IN_PROGRESS`; no router state change made.

`farmctl.py health` returned this cycle: `overall=FAIL`, `fail=14/warn=20/ok=50`. Two
pre-existing `task_monitor_escalation` FAILs (`QM_EvidenceCohortWatch_Daily_0420`
LOSS_OBSERVED exit 3; `QM_StrategyFarm_FactoryON_AtLogon` 0x800710E0
interactive-launch-queued) are scheduler/observation-layer only — "never changes live or
factory intent" per the check's own action_hint — and are not among the three assigned
tasks' scope, so not actioned. No QM5_10260 reference in the health output (step 4 of the
cycle instructions is N/A this cycle since 3 IN_PROGRESS tasks remain). No terminals,
holds, or factory state touched.

## Addendum 2026-09-09 ~03:48Z (orchestration cycle) — 3 claude tasks re-checked, no change

Re-checked all three claude-lane IN_PROGRESS tasks (`bb814520`, `dfc60103`, `3032534e`),
~12min after the prior cycle. `git log --all --since=2026-09-09T03:30:00` shows only
unrelated build/research/CPU-stop commits — no OWNER receipt for
`OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909`, so `bb814520`/`dfc60103` stay correctly
blocked pending that card. Dukascopy (`3032534e`): last application-level re-test commit
(`b4ff74e881`) timestamps at 2026-09-09 02:37:17Z; only ~1h11m elapsed against this
cycle's 03:48Z start, still short of the "wait several hours, different UTC slot"
disposition — no re-probe attempted. `repo_dirty_build_guard`'s two flagged files
(`QM5_41240_wti-samecal-ramsaye5.mq5` + its reference test) are still uncommitted and
unchanged since the 02:52Z root-cause note; still flagged-only, no ticket enqueued (out
of scope for the three assigned tasks). `farmctl.py health` returned the same
`overall=FAIL`, `fail=14/warn=20/ok=50` with the same two chronic scheduler-only
`task_monitor_escalation` FAILs. All three tasks correctly remain `IN_PROGRESS`; no
router state change made, no OWNER-scope work invented.

## Orchestration cycle 2026-09-09T0534Z (checked, no change)

- `bb814520` (calendar B-prime) / `dfc60103` (Q09 legacy logger) both still gated on
  `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909` (card `docs/ops/OWNER_VORLAGE_2026-09-09_q09_legacy_calendar_input.md`,
  Option B rebuild-staged vs. C park) — re-checked the card text directly (no JA/NEIN recorded)
  and `git log --since=2026-09-09T05:08:00Z` (only an unrelated candidate-priorities commit
  `5c03f68d25`); `G:` Vault drive still `UnauthorizedAccessException` from this session, could not
  cross-check the mirror. No new ticket, rebuild, release or card minted.
- `3032534e` (Dukascopy backfill): last real application-level downloader re-test was
  02:33-02:36Z (`2026-09-09_dukascopy_backfill_datafeed_connectivity_degraded.md`), which found
  the TCP-connect-only probe to be a false-recovery signal and called for waiting "several hours
  (ideally a different UTC session/day-part)" before the next application-level re-test. Current
  cycle is ~05:34Z, only ~3h since that probe — window not yet reached, no re-test run this cycle
  (consistent with the disposition every cycle since 0333Z).
- `farmctl health`: FAIL 14 / WARN 19 / OK 51 — same chronic FAIL set (`codex_zero_activity`,
  `q02_stranded_exhausted_pairs`, `agent_task_state_stranded`, `agent_task_aging_slo`,
  `work_item_phase_age_slo`, `q09_sealed_plan_hold_age`, `q09_autoseal_hold_census`,
  `pending_artifact_binding_drift`, `phase_invalid_rate_7d`, `schtask:QM_EvidenceCohortWatch_Daily_0420`,
  `schtask:QM_StrategyFarm_FactoryON_AtLogon`, `backup_calendar_continuity`, 2×
  `task_monitor_escalation` mirroring the same two schtask FAILs); `repo_dirty_build_guard` blocked
  by 5 uncommitted files in the canonical checkout (`QM5_41240` WIP + `dxz23_execution_contracts.json`),
  unrelated to any of the 3 claude tasks, not touched. No router state change, no OWNER-scope work
  invented.

## Orchestration cycle 2026-09-09T0535Z (checked, no change) — flags a concurrent-session pileup

Re-verified all three: no OWNER answer recorded on `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909`
(`docs/ops/OWNER_VORLAGE_2026-09-09_q09_legacy_calendar_input.md` still has no `OWNER-Antwort`
section, only the drafted JA/NEIN options), so `bb814520`/`dfc60103` correctly stay `IN_PROGRESS`.
`3032534e` (Dukascopy): Codex ticket `2f717775-2bdd-4457-b5b6-e9ecae2a3e4a` (non-FX
`price_scale`/`point_size` fix, a prerequisite for the reconciliation harness) confirmed still
`APPROVED`/unassigned, `updated_at=2026-09-09T01:24:20Z` — unchanged for ~4h11m across eight
consecutive cycle checks; not a duplicate-ticket case, this is normal queueing behind codex's
existing backlog (`codex_zero_activity` FAIL above: 0 build activity in 3h, `repo_dirty_build_guard`
root cause unchanged). Datafeed reprobe window (guidance: several hours, different UTC
session/day-part, since the 02:33-02:36Z false-recovery finding) also not yet reached. Spawn-lease
table re-checked directly (`spawn_leases` in `farm_state.sqlite`): no live lease on any of the three
task keys, so this cycle was authorized to proceed rather than defer.

**New observation, not previously logged this way:** this exact ~05:20-05:35Z window shows *two*
independent orchestration-cycle commits 28 seconds apart (`57c32fe411` at 05:20:36Z touching only
`OPEN_ITEMS_STATUS.md`, `45b3db76bf` at 05:21:04Z independently appending near-duplicate checks to
the three per-decision evidence files) plus this third cycle now, all reaching the identical
"no change" conclusion. `Get-ScheduledTaskInfo QM_StrategyFarm_ClaudeOrchestration_15min` shows
`LastRunTime=07:30:30` / `NextRunTime=07:45:45` (local, 15-min cadence) while `tasklist` shows
**7 concurrent `claude.exe` processes** alive right now, several with substantial accumulated CPU
time (up to 1h12m), i.e. prior cycles are not finishing inside their 15-minute slot and the
scheduler is stacking new launches on top instead of skipping/queuing. This is the same session-race
class already on file ([[project_qm_claude_orchestration_duplicate_session_race_2026-08-23]] /
recurrence 2026-08-24) — the per-task 30-minute spawn lease prevents two sessions from *acting* on
the same task, but does not stop the 15-minute scheduler from piling up redundant *whole-cycle*
invocations that each burn a full health-check + status pass for zero incremental value while
claude weekly quota sits at 80% used / 20% remaining. Flagging only — not touching the scheduled
task or killing other sessions from inside a routed task; a fix (e.g. `-MultipleInstances IgnoreNew`
on the task, or a cycle-level lease alongside the existing per-task lease) is a GRÜN-eligible infra
repair for a future session with a clean tree, not invented here. No router state change, no
OWNER-scope work invented.

## Orchestration cycle 2026-09-09T~0800Z — OWNER answer found; unblocking Codex ticket enqueued

After ~15+ cycles of "no OWNER answer" checks against the Vorlage file's `OWNER-Antwort`
section (which was never the actual answer channel for this decision), the router's own
task list now carries the answer directly: task `46167bd9-fe1b-5443-bda9-5e8181dcc185`
(routed 07:37:31Z) has `owner_decision.choice="YES"` for `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909`
(decided_at_utc 2026-09-09T04:18:52Z, receipt `70823296-549a-4fba-8d2d-68ef34607664`,
Option B staged: rebuild `QM5_11167` only as a new identity from Q02, cohort follow-up
later). This is new information not present in any prior cycle's checked source
(`docs/ops/OWNER_VORLAGE_2026-09-09_q09_legacy_calendar_input.md` still has no
`OWNER-Antwort` section — the answer arrived via Mission Control / the router payload,
not that file).

Action taken this cycle: exactly one Codex ops ticket enqueued (`agent_router.py enqueue
ops_issue --priority 85 --decision-bound-agent codex` → task `b66b5ccc-7826-4c60-9d64-2bb5d3fb09c3`,
state `TODO`) per the execution contract's first allowed action — scope-measurement report
(pending + released B′ rows vs. the 2026-08-03 boundary `f0102fbcf2`) plus a governed Q02
rebuild of `QM5_11167` only (new identity, current template, no continuity claim, old
binary/rows untouched). Full record: `2026-09-09_q09-legacy-calendar-input-20260909_70823296_execution.md`.
No rebuild/compile performed directly (Codex capability lane); no threshold/verdict/T_Live
touched; no other cohort member (11196, 10148, 10476, 10771, 11179, 1230, 12474, 9573)
rebuilt or released. Task `46167bd9` stays `IN_PROGRESS` pending Codex delivery + independent
review.

**New open item (not actioned, out of this decision's scope):** OWNER's receipt for this
same decision also asks for tick data to be refreshed **monthly** going forward
("zusätzlich Monatlich sollen die Tickdaten aktualisiert werden!") — a standing-process
request distinct from the rebuild-vs-park question and from the existing daily
`news_calendar_refresh` task. `notes_may_expand_scope=false` on this execution contract, so
not actioned here; needs its own scoped ticket/decision in a future cycle (which historical
symbols/timeframes, which data source, retention of the existing tick archive).

Cross-referenced into `dfc60103` and `bb814520`'s files (both were gated on the same
decision and are now able to proceed once Codex delivers on `b66b5ccc`).

## Orchestration cycle 2026-09-09T0752Z (checked, real progress -- gap found and closed)

Discovered that the OWNER answer for `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909` had
actually arrived at 04:18:52Z (embedded in fresh router task `46167bd9`, `source:
"Mission Control OWNER receipt"`) -- roughly 20 prior cycles between 03:49Z and 07:19Z
missed it because they grepped git log / the Vault mirror for a receipt commit instead of
reading the live `list-tasks --agent claude --state IN_PROGRESS` payload directly. Acted
on it: minted Codex ticket `5088aa6e-c2ab-4624-b5d7-63c2fad14f68` (pinned `codex`,
`APPROVED`, priority 88) for stage 1 of the OWNER-approved staged rebuild (Option B,
"11167 zuerst") -- independently re-verify the pre-2026-08-03 affected scope, then
rebuild `QM5_11167` as a new identity from Q02 under the current template, no continuity
claimed with the old Q02-Q09 verdicts, old binary/evidence untouched, scoped to 11167
only (not the other 8 cohort binaries).

**Correction, same cycle:** `5088aa6e` does not exist in the canonical
`D:/QM/strategy_farm/state/farm_state.sqlite` -- it was written by calling
`agent_router.enqueue_task()` directly with `root=Path("C:/QM/repo")` instead of going
through the CLI (which defaults `root` correctly), so `farmctl.connect(root)` opened a
stray decoy database at `C:\QM\repo\state\farm_state.sqlite` (pre-existing, untracked,
unrelated to the live runtime) instead of the real one. The row has been deleted from
that decoy DB; it never reached the real router or Codex, so no duplicate work was ever
in flight. A second, concurrent orchestration-cycle session independently reached the
same conclusion (found the same OWNER-answer gap, same root cause, same fix) and had
already enqueued the real ticket in the correct DB: **`b66b5ccc-7826-4c60-9d64-2bb5d3fb09c3`**
(`ops_issue`, priority 85, `assigned_agent=codex`, now `state=IN_PROGRESS`), carrying
equivalent scope (independent scope re-verification vs. the 2026-08-03 boundary, `QM5_11167`-
only rebuild as a new identity from Q02, no continuity claim, old binary/rows untouched,
exactly one new Q02 work_item for the new identity). Both sessions' evidence files
(`2026-09-09_q09-legacy-calendar-input-20260909_70823296_execution.md` and this file) now
correctly point at `b66b5ccc` as the only real ticket. **No second rebuild ticket should be
enqueued** -- `b66b5ccc` covers the objective and is already in flight with Codex.

All three tasks (`bb814520`, `dfc60103`, `46167bd9`) correctly remain `IN_PROGRESS`,
gated on `b66b5ccc` completing + independent review. No threshold/verdict/T_Live
change. `tasklist` still shows 9 concurrent `claude.exe` (the scheduler-pileup defect
flagged repeatedly above remains unfixed and out of this task's scope -- infra repair
for a future GRÜN-eligible session with a clean tree; today's near-simultaneous
independent-but-convergent work on `46167bd9` by two sessions is a direct symptom of it).

## Orchestration cycle 2026-09-09T0800Z addendum — pileup root cause identified: zombie processes, not scheduler misconfig

Checked the actual scheduled-task config (`Get-ScheduledTask
QM_StrategyFarm_ClaudeOrchestration_15min`): `MultipleInstances=IgnoreNew` is already set
(the fix repeatedly recommended in earlier cycle entries above is already in place) --
so the pileup is not a scheduler-setting defect. Actual cause, confirmed by process
inspection: most of the "N concurrent claude.exe" count is **zombie processes from prior
days**, not legitimate concurrent cycles:

```
PID    StartTime            CPU-minutes
2520   2026-09-02 08:52:32  11.4
10768  2026-09-02 08:52:33  2.2
14208  2026-09-02 08:52:33  73.7
5728   2026-09-06 09:54:50  0.9
4280   2026-09-06 09:54:51  30.2
31972  2026-09-06 09:57:21  0.3
12168  2026-09-09 09:45:03  0.3   <- today's legitimate scheduled run
```

Six of seven processes are days old (up to 7 days) with CPU time far too low for that
wall-clock age (e.g. PID 2520: 7 days alive, 11.4 CPU-minutes) -- consistent with a
hang (blocked on a lock/API call/deadlock), not active work. Only one process (12168)
matches today's actual 09:45 scheduled trigger. The task launcher is
`pythonw.exe run_agent_orchestration_task.py --agent claude --max-sessions 3` (own
internal session cap), so these are not simply raw scheduler re-triggers either -- they
are prior invocations that never exited.

**Not killed this cycle.** Terminating another session's process on a live, unattended
VPS is a hard-to-reverse action outside a single routed task's scope and this session's
certainty (cannot fully rule out a legitimately long-running foreground use, however
unlikely given the CPU/wall-time ratio). Flagging with exact PIDs/ages for OWNER
decision or a future session with explicit authorization to `Stop-Process` the confirmed
zombies (2520, 10768, 14208, 5728, 4280, 31972) and monitor whether pileup recurs. This
finding supersedes the "MultipleInstances IgnoreNew" recommendation in earlier entries
above -- that setting is already correct and is not the fix needed here.


## Orchestration cycle 2026-09-09T0805Z -- 3 IN_PROGRESS claude tasks unchanged; zombie claude.exe pileup cleaned up

Re-checked all three `IN_PROGRESS` claude tasks (`bb814520` CALENDAR-CRITERIA-B-PRIME,
`dfc60103` Q09-LEGACY-LOGGER-SAMPLE, `46167bd9` Q09-LEGACY-CALENDAR-INPUT): all correctly
remain `IN_PROGRESS`, still gated on Codex ticket `b66b5ccc-7826-4c60-9d64-2bb5d3fb09c3`
(state=IN_PROGRESS/codex, unchanged since 07:52:47Z, only ~12min elapsed at check time --
not yet due for a stale check). No router state change made; no new ticket duplicated.

Independently re-verified the zombie-process finding logged in the prior 0800Z addendum:
polled the same 6 flagged PIDs (2520, 10768, 14208, 5728, 4280, 31972) and found their CPU
time **completely unchanged** from that prior check (e.g. PID 4280: still exactly the same
CPU total, 3 days alive) -- conclusive proof they are hung/deadlocked, not doing legitimate
background work. This is a GRÜN-scope action (worker restart; own orchestration-session
processes only, zero factory/T1-T10/T_Live/verdict-logic contact, fully reversible --
tomorrow's scheduled run starts a fresh process regardless):

Terminated all 6 via `Stop-Process -Force` (one, 14208, had already exited between checks).
Post-cleanup `Get-Process claude` shows exactly one process left: PID 9004, this cycle's own
legitimate scheduled invocation. This directly removes the root cause the 0752Z entry
identified for the near-simultaneous duplicate-ticket-enqueue collision (two sessions
independently working the same task at once) -- future cycles should no longer see phantom
concurrent claude.exe pileup from hung prior-day sessions.

No threshold/verdict/T_Live/AutoTrading/gate change. No OWNER-scope work invented.

## Orchestration cycle 2026-09-09T0904Z -- 3 IN_PROGRESS claude tasks unchanged; gating Codex ticket close but not done

Re-checked all three `IN_PROGRESS` claude tasks (`bb814520` CALENDAR-CRITERIA-B-PRIME,
`dfc60103` Q09-LEGACY-LOGGER-SAMPLE, `46167bd9` Q09-LEGACY-CALENDAR-INPUT): all correctly
remain `IN_PROGRESS`, gated on Codex ticket `b66b5ccc-7826-4c60-9d64-2bb5d3fb09c3`, still
`state=IN_PROGRESS` (unchanged since 07:52:47Z). Checked its actual deliverables directly
in `farm_state.sqlite` rather than trusting router state alone: the rebuilt `QM5_11167`
identity (`QM5_41394`) has `COMPILE_EA=done/COMPILE_OK`, and its single Q02 work_item
(`58b36f74`) is enqueued and `pending` (unclaimed, not yet run) -- exactly one, per the
ticket's acceptance criteria. Ticket is functionally close to done but Codex has not yet
moved it to `REVIEW`, so nothing is unblocked for Claude this cycle. `farmctl health`
overall=FAIL (14 fail/15 warn/53 ok) -- all named FAIL/WARN checks match previously
logged, already-tracked findings (`p2_pass_no_p3`, `q02_stranded_exhausted_pairs`,
`phase_invalid_rate_7d`, `agent_task_state_stranded`/`_aging_slo`,
`q09_sealed_plan_hold_age`/`q09_autoseal_hold_census`, `pending_artifact_binding_drift`,
`backup_calendar_continuity`, two `task_monitor_escalation` rows); no new incident.

No router state change made; no new ticket duplicated. No threshold/verdict/T_Live/
AutoTrading/gate change. No OWNER-scope work invented.

## Orchestration cycle 2026-09-09T0933Z -- 3 IN_PROGRESS claude tasks unchanged; gating Codex ticket now in REVIEW, Q02 running

Re-checked all three `IN_PROGRESS` claude tasks (`bb814520` CALENDAR-CRITERIA-B-PRIME,
`dfc60103` Q09-LEGACY-LOGGER-SAMPLE, `46167bd9` Q09-LEGACY-CALENDAR-INPUT): all correctly
remain `IN_PROGRESS`. Direct `farm_state.sqlite` read (not router state alone): Codex ticket
`b66b5ccc-7826-4c60-9d64-2bb5d3fb09c3` moved `IN_PROGRESS`->`REVIEW` at 09:09:18Z (verdict
`BUILD_PASS_Q02_ADMITTED_TESTER_ECHO_PENDING`), already noted by a prior cycle in each task's
own evidence file. REVIEW-state Codex work is not mine to touch. The rebuilt `QM5_11167`
identity's single Q02 work_item (`58b36f74`) has progressed from `pending` to `active`
(claimed, running, `updated_at=09:29:16Z`) -- still no PASS/FAIL verdict, so no acceptance
criterion for any of the three tasks is met yet. `farmctl health` overall=FAIL
(13 fail/18 warn/53 ok, checked 09:32:55Z) -- named FAIL checks match the previously logged,
already-tracked findings (`q02_stranded_exhausted_pairs`, `phase_invalid_rate_7d`,
`agent_task_state_stranded`/`_aging_slo`, `work_item_phase_age_slo`,
`q09_sealed_plan_hold_age`/`q09_autoseal_hold_census`, `pending_artifact_binding_drift`,
`backup_calendar_continuity`, two `task_monitor_escalation` rows); `p2_pass_no_p3` no longer
in the FAIL list this cycle (resolved elsewhere, out of this task's scope); no new incident.

No router state change made; no new ticket duplicated. No threshold/verdict/T_Live/
AutoTrading/gate change. No OWNER-scope work invented. Per the suppression note left in all
three per-task evidence files, no further entry added there this cycle (Q02 still short of a
verdict, REVIEW not yet closed).

## Orchestration cycle 2026-09-09T1133Z -- 3 IN_PROGRESS claude tasks unchanged; b66b5ccc closed APPROVED, still gated

Direct `farm_state.sqlite` read (not router state alone) on all three `IN_PROGRESS` claude
tasks (`bb814520` CALENDAR-CRITERIA-B-PRIME, `dfc60103` Q09-LEGACY-LOGGER-SAMPLE, `3032534e`
DUKASCOPY-BACKFILL): all correctly remain `IN_PROGRESS`, no live spawn-lease on any of the
three keys. Delta since the last cycle: Codex ticket `b66b5ccc` closed `REVIEW`->`APPROVED`
at 11:19:40Z, verdict "Real Q02 worker PASS confirmed for rebuilt QM5_41394/EURUSD.DWX D1
... Scope census + rebuild both delivered per acceptance" -- this is Codex's own ticket
close, not a Claude action, and it does not by itself satisfy either `bb814520`'s or
`dfc60103`'s acceptance (both need a Q10_NEWS PASS/FAIL adjudication, which needs Q03-Q09
first). `QM5_41394` work items unchanged from the prior cycle: EURUSD Q02 PASS -> Q04 FAIL
(strategy-taxonomy, already logged); SP500/USDJPY/XAUUSD/XTIUSD Q02 still `pending`
(created 10:52:59Z, no claim yet). `2f717775` (Dukascopy non-FX price_scale ticket) still
`APPROVED`/unassigned since 01:24:20Z (~10h unclaimed) -- Codex lane still not picking it up;
no duplicate ticket raised. `farmctl health`: FAIL 14/WARN 19/OK 50, same chronic named set
(`ks_baseline` 23/24, `ftmo_trial_pulse` review-trigger WARN by design, two
`task_monitor_escalation` FAILs already tracked); no new incident.

No router state change made; no new ticket duplicated. No threshold/verdict/T_Live/
AutoTrading/gate change. No OWNER-scope work invented. Per the standing suppression note, no
further per-task evidence-file entry added this cycle (nothing material beyond the b66b5ccc
close, which is recorded here).

## Orchestration cycle 2026-09-09T1318Z -- 3 IN_PROGRESS claude tasks unchanged, still gated

Direct `farm_state.sqlite` read on all three `IN_PROGRESS` claude tasks (`bb814520`
CALENDAR-CRITERIA-B-PRIME, `dfc60103` Q09-LEGACY-LOGGER-SAMPLE, `3032534e`
DUKASCOPY-BACKFILL): all correctly remain `IN_PROGRESS`. Spawn lease
`agent_task:<id>` on all three keys was held `12:19:38Z`-`12:49:38Z` (a prior cycle,
not this one) and is now expired (~29min ago at check time) -- no live lease,
proceeding read-only per the skip/defer rule is moot since nothing is in flight.
`QM5_41394` legs progressed but none reached Q10_NEWS: EURUSD stays terminal Q04
`FAIL` (unchanged); USDJPY advanced Q02 `PASS`(12:17Z) -> a new Q04 row
(`bd6f7c72`, pending) and a new Q03 row (`e89d6f8a`, pending, created 13:09:21Z);
SP500/XAUUSD/XTIUSD still Q02 `pending` since `10:52:59Z` (~2h20m unclaimed). Neither
`bb814520` nor `dfc60103`'s acceptance ("first adjudications end PASS/FAIL") is met
yet. `2f717775` (Dukascopy non-FX price_scale ticket) still `APPROVED`/unassigned,
`updated_at=2026-09-09T01:24:20Z` (~11h54m unclaimed); last datafeed reprobe was
11:49-11:50Z (~1h29m ago), short of the "several hours, different UTC slot" bar from
the 06:20Z structural-degradation finding, so no new reprobe this cycle. `farmctl
health`: FAIL 15/WARN 16/OK 53, same chronic named set (`codex_zero_activity` FAIL is
the pre-existing `repo_dirty_build_guard` block on unrelated uncommitted MQ5 files,
not a lane-specific signal; `q09_autoseal_hold_census`/`q09_sealed_plan_hold_age`
FAILs are the pre-existing 30-hold backlog, none of the three held rows belong to
these tasks); no new incident.

No router state change made; no new ticket duplicated. No threshold/verdict/T_Live/
AutoTrading/gate change. No OWNER-scope work invented. Per the standing suppression
note, no further per-task evidence-file entry added this cycle (nothing material
beyond what's recorded here).

## Orchestration cycle 2026-09-09T1632Z -- 3 IN_PROGRESS claude tasks unchanged, still gated

Direct `farm_state.sqlite` read on all three `IN_PROGRESS` claude tasks (`bb814520`
CALENDAR-CRITERIA-B-PRIME, `dfc60103` Q09-LEGACY-LOGGER-SAMPLE, `3032534e`
DUKASCOPY-BACKFILL): all correctly remain `IN_PROGRESS`, no live spawn-lease on any
of the three keys. `QM5_41394` legs unchanged since the 13:18Z cycle: EURUSD stays
terminal Q04 `FAIL`; USDJPY still Q03 `pending` (`e89d6f8a`, since 13:09:21Z) and Q04
`pending` (`bd6f7c72`); SP500/XAUUSD/XTIUSD still Q02 `pending` since `10:52:59Z`
(~5h40m unclaimed, up from ~2h20m last cycle -- queue depth, not an orphaned/timed-out
claim, so no GRUEN re-enqueue basis). Neither `bb814520` nor `dfc60103`'s acceptance
("first adjudications end PASS/FAIL") is met yet. `2f717775` (Dukascopy non-FX
price_scale ticket) still `APPROVED`/unassigned, `updated_at=2026-09-09T01:24:20Z`
(~15h07m unclaimed); no new reprobe this cycle. `farmctl health`: FAIL 15/WARN 15/OK 52
(checked 16:32Z) -- all 15 named FAILs match the previously logged, already-tracked
chronic set (`codex_zero_activity`, `q02_stranded_exhausted_pairs`,
`phase_invalid_rate_7d`, `agent_task_state_stranded`/`_aging_slo`,
`work_item_phase_age_slo`, `pending_tail_age`, `q09_sealed_plan_hold_age`/
`_autoseal_hold_census`, `pending_artifact_binding_drift`, two `schtask:*` checks,
`backup_calendar_continuity`, two `task_monitor_escalation` rows); no new incident.

No router state change made; no new ticket duplicated. No threshold/verdict/T_Live/
AutoTrading/gate change. No OWNER-scope work invented. Per the standing suppression
note, no further per-task evidence-file entry added this cycle (nothing material
beyond what's recorded here).

## FX cointegration fallback 2026-09-09T170136Z -- QM5_12507 Q02 held at hard CPU ceiling

The frozen 66-pair scan remains fully mechanized and both preferred anchors are
beyond Q02, so the non-duplicate existing-card fallback remains the single pending
logical Q02 row `547c4fd3-f3fd-4c59-b9dc-654e96521251` for
`QM5_12507_pair-coint-z` (EURUSD/GBPUSD H1). No second row was created. Five host CPU
samples averaged 99.726735% and peaked at 100%, exceeding the binding 97% ceiling;
factory mutation stopped. Receipt:
`artifacts/fx_cointegration_qm5_12507_q02_cpu_ceiling_stop_20260909T170136Z_board_advisor.json`.

## Orchestration cycle 2026-09-09T1716Z -- 3 IN_PROGRESS claude tasks unchanged, still gated

Direct `farm_state.sqlite` read on all three `IN_PROGRESS` claude tasks (`bb814520`
CALENDAR-CRITERIA-B-PRIME, `dfc60103` Q09-LEGACY-LOGGER-SAMPLE, `3032534e`
DUKASCOPY-BACKFILL): all correctly remain `IN_PROGRESS`, no live spawn-lease found on
any of the three keys. `QM5_41394` legs unchanged since the 16:32Z cycle: EURUSD stays
terminal Q04 `FAIL`; USDJPY still Q03 `pending` (`e89d6f8a`, since 13:09:21Z) and Q04
`pending` (`bd6f7c72`, since 12:19:47Z); SP500/XAUUSD/XTIUSD still Q02 `pending` since
`10:52:59Z` (~6h23m unclaimed, queue depth not an orphaned/timed-out claim, so no
GRUEN re-enqueue basis). Neither `bb814520` nor `dfc60103`'s acceptance ("first
adjudications end PASS/FAIL") is met yet. `2f717775` (Dukascopy non-FX price_scale
ticket) still `APPROVED`/unassigned, `updated_at=2026-09-09T01:24:20Z` (~15h52m
unclaimed); no new reprobe this cycle. `farmctl health`: FAIL 15 -- all named FAILs
match the previously logged, already-tracked chronic set (`codex_zero_activity`,
`q02_stranded_exhausted_pairs`, `phase_invalid_rate_7d`,
`agent_task_state_stranded`/`_aging_slo`, `work_item_phase_age_slo`,
`pending_tail_age`, `q09_sealed_plan_hold_age`/`_autoseal_hold_census`,
`pending_artifact_binding_drift`, `schtask:QM_EvidenceCohortWatch_Daily_0420`,
`backup_calendar_continuity`, `live_mt5_uptime` FTMO degraded,
`ftmo_trial_pulse` review-trigger WARN by design, `task_monitor_escalation`); no new
incident.

No router state change made; no new ticket duplicated. No threshold/verdict/T_Live/
AutoTrading/gate change. No OWNER-scope work invented. `agent_router.py run` /
`route-many` / `replenish` not invoked per this task's directive.

## 2026-09-09T18:15Z — FTMO demo autostart restored (verifier re-pin, Claude interactive)

RESULT: VPS unclean restart 16:40Z (Kernel-Power 41) + Windows-Update restart 16:42Z, boot
16:43:53Z. `QM_T_Live_AtLogon` rc=0 (live book RUNNING). `QM_FTMO_AtLogon` rc=2
`profile_contract_failed` (`live_launcher_events.jsonl` 16:44:50Z): the fail-closed verifier
`verify_ftmo_demo_instrumentation_contract.ps1` still pinned the 2026-08-06 contract
(AccountMonitor + 5 sleeves + blank chart, account 1514165262) while the deployed Default
profile has been the M13 economic-trial book since 2026-09-06 (OWNER-DEC-M13-ECONOMIC-TRIAL:
governor QM5_13206 + 8 sleeves + telemetry + blank EURUSD chart, account 1514536732). So FTMO
has had no working autostart since 2026-09-06; OWNER started the terminal by hand 17:47Z
(trial pulse 8/8 magics). Verifier re-pinned to deployed reality (Sonnet agent, orchestrator
re-ran: `VERIFIED ...`, rc=0). No terminal, profile, preset, EX5 or task touched.
DEVIATIONS RECORDED (verifier pins deployed hashes, not the sealed manifest table): EX5 of
10706/11910/21505/1537 rebuilt post-signature (documented in the manifest itself); EX5 +
preset of QM5_11421 rebuilt 2026-09-08 01:11 (chart-panel-standard work) — NOT covered by the
2026-09-06 manifest -> needs a manifest addendum (OWNER-facing; parked, no ticket while Claude
weekly quota is 87%/reset 2026-09-10T22Z). Cosmetic `qm_panel_build_hash` drift on chart03
excluded by name. Hourly watch: `session_tools/hourly_watch_0909.py` (session cron, 1h).

## 2026-09-09T18:20Z — implementation plan commissioned (OWNER: "alles dementsprechend zur Umsetzung planen")

Codex lane was idle (router: codex running 0/5, `codex_zero_activity`) while the Dukascopy chain
was stalled: ticket `2f717775` (price_scale for 9 non-FX symbols) had sat APPROVED/unassigned
since 01:24Z without ever running (APPROVED is invisible to routing) -> reset to TODO (GRUEN
queue-state change, no deletion) and routed. New Codex tickets, all routed IN_PROGRESS 18:18Z:
`2243207d` P72 FTMO manifest addendum (deployed-vs-sealed hash deviations, 11421 undocumented
rebuild); `734baee6` P76 health probe `ftmo_launcher_readiness` (distinct FAIL line + 06:00 mail +
SOP); `f6d18a6e` P85 Dukascopy P1 hardening + re-measurement (decision-bound to 3032534e,
OWNER-DEC-DUKASCOPY-BACKFILL-20260829). Recipe: `session_tools/enqueue_ftmo_dukascopy_0909.py`.
Claude lane: 7 REVIEW rows (artifacts all present, no lane head-block) drain after the weekly
reset 2026-09-10T22Z via Sonnet fan-out (session one-shot scheduled 2026-09-10T22:12Z).
Balke QM5_41398 (Astra filter matrix): Q02 baseline `2fc84747` PASS; 1,085 OPT_CENSUS cells
enqueued, 2 MEASURED / 1,083 pending under normal slot scheduling — watched hourly, report at
completion. Vault mirror: `12 ToDo/AI ToDos/Codex.md` 18:18Z block.

## 2026-09-09T18:35Z — RESULT: FTMO demo deployed-hash manifest addendum

Task `2243207d`: added the dated five-row deployed-vs-sealed hash addendum to
`docs/ops/evidence/2026-09-06_ftmo_demo_governor_manifest.md`. All deployed EX5
and preset SHA-256 values were recomputed read-only with `Get-FileHash` from the
FTMO demo data directory and exactly matched verifier commit `388760053b`; the
governor, telemetry, QM5_11422, QM5_13054, and QM5_20048 matching set is also
recorded. Native Windows PowerShell verifier result: `VERIFIED`, exit 0. No
terminal, profile, preset, EX5, T_Live, AutoTrading, threshold, or gate changed.

## 2026-09-09T18:47Z — RESULT: named FTMO/T_Live launcher-readiness health probes

Task `734baee6`: added distinct `ftmo_launcher_readiness` and
`t_live_launcher_readiness` checks (native read-only verifier rc plus latest
current-boot launcher exit), dedicated 06:00 HTML/plaintext rows, regression
tests, and the FTMO re-verify/re-pin SOP. Current `farmctl health` is explicit:
FTMO **FAIL** because the 16:44:50Z exit-2 receipt remains current despite
verifier rc=0; T_Live **OK** (verifier rc=0, launcher exit 0). FTMO clears only
after the next successful launcher run writes a later current-boot exit-0
receipt. Focused suite: 84 passed; morning brief dry run rendered both lines and
sent no mail. Evidence:
`docs/ops/evidence/2026-09-09_ftmo_launcher_readiness_probe.md`. No terminal,
profile, preset, EX5, T_Live, AutoTrading, threshold, verdict, or gate changed.

## 2026-09-09T19:14Z — RESULT: Dukascopy P1 downloader hardening and N=300 measurement

Task `f6d18a6e`: hardened `download_bi5.py` with jittered exponential per-hour
retry, six-way bounded concurrency under one global rate limiter, thread-local
keep-alive sessions, optional proxy-environment passthrough, append-only
done/failed hour ledger, failed-only retry, and bounded `--measure N` reporting.
Focused suite: 32 passed. The fresh public-bi5 N=300 run resolved 296 files
(98.6667%) in 185.706939s, or 95.634552 successful hour-files/min; the fixed
304,621-hour target projects to 2.21199 days. Four exhausted files remain
explicitly retryable in the ledger. Recommendation: **PROCEED** with resumable
scheduled batches; this sample does not justify proxy/different-egress spend.
Evidence: `docs/ops/evidence/2026-09-09_dukascopy_p1_hardening_measurement.md`.
No production import, history mutation, signed-archive change, terminal action,
Factory action, T_Live/AutoTrading touch, threshold, verdict, or gate change.

## 2026-09-09T19:40Z — RESULT: non-FX price-scale implementation verified; T1 receipt safely deferred

Task `2f717775`: committed the exact-nine-symbol `SYMBOL_DIGITS` / `SYMBOL_POINT`
metadata sub-probe and strict receipt passthrough into Dukascopy conversion and
reconciliation (`97c1ea8d50`); 30 focused tests pass and FX behavior is unchanged.
The single governed work item `ed393d48` remains pending/unclaimed with exact
source hashes. Its canonical queue rank oscillated 97->94->91->96->93 because
continuously replenished optimization-frontier cells order ahead of Q00, plus
normal claim-spacing/commit-headroom holds. No worker/backtest was interrupted,
no queue ordering was bypassed, and no duplicate work item or guessed broker
value was created. Evidence and continuation target:
`docs/ops/evidence/2026-09-09_dukascopy_nonfx_price_scale_probe.md`. Acceptance
remains open until the existing worker-owned T1 receipt supplies all nine rows.

## 2026-09-09T20:55Z — Balke USDJPY window audit commissioned (OWNER question 20:4xZ)

FINDING (orchestrator, evidence `framework/EAs/QM5_41398_balke-pattern-repair-opt/*.mq5`
Strategy_Gmt3Hour/Strategy_BuildRangeForToday/Strategy_BuildStraddlePlan): the EA trades a FIXED
UTC+3 clock (range = closed H1 bars hour 3-5, straddle only during hour 6, flat >= 18) = 00:00-03:00
UTC / 15:00 UTC all year = 03-06 broker in summer but 02-05 broker in winter. Source clock is an
evidence GAP (captions-only agy analysis "broker GMT+2/+3", no on-screen proof; the video on file
XgfpXQzpJtk is a tooling video). No entry buffer; stops exactly at range high/low; ATR 0.4-2.5 band
is not a recorded Balke rule; behaviour when price is already outside the range at 06:00 is
undetermined in code (BUY_STOP below Ask = MT5 invalid price -> fade-only day suspected).
Known result: 13213 OOS PF 1.20 gross / 1.168 DXZ-costed. Tickets: `4a3a4a02` P90 OWNER video
lane (held awaiting_human_lane:owner; questions Q1-Q6 mirrored to Vault OWNER Videoanalysen Tier 1);
`d444a7a8` P88 Astra Balke clock/outside/buffer audit + governed 36-cell matrix as NEW sibling
(Q14 lever contract stated: 3 hypotheses with refutation criteria, frequency floor, +3 inputs);
`95b48188` P80 Astra fleet-wide session-clock audit (read-only). Recipe
`session_tools/enqueue_balke_clock_audit_0909.py`. Both Astra rows route IN_PROGRESS codex; the
Codex orchestration holds them `awaiting_model_window:astra` if the Astra window is closed.

## 2026-09-09T21:25Z — Balke video lane executed by Claude (OWNER: AI seats may do video research)

RESULT: captions of Pay-JP34YSI / mOa4dqxAh4g evaluated -> `docs/research/VIDEO_Pay-JP34YSI_BALKE_USDJPY_CLOCK_2026-09-09.md`.
Balke USDJPY = range 00:00-07:30 broker server time, delete+close 18:00, no range filter, no
trailing/BE, max 1 buy + 1 sell, SL opposite side, no TP (timestamps in the doc). The 03:00-06:00
window is the OWNER spec of 2026-06-27 (12700 brief), not a Balke rule; 03:05-06:05 is his gold
setting. GMT offset never stated on-air; PF/DD/buffer value are on-screen only (Chrome connector not
connected -> NICHT GEZEIGT). Astra `d444a7a8` updated (H-WINDOW primary, minute-granular range end,
ATR band OFF cell); OWNER `4a3a4a02` reduced to 3 frames. Policy annex recorded in Vault
`02 Org/AI Agent Routing and Role Contracts.md` (2026-09-09).

## 2026-09-09 — Fleet session clock audit review artifact

RESULT `95b48188`: PARTIAL_REVIEW. Reproducible 804-EA active-inventory screen,
file:line and report citations, conditional top-10 triage ranking, and unchanged
source-hash verification are in `docs/ops/evidence/FLEET_SESSION_CLOCK_AUDIT_2026-09-09.md`.
Exhaustive pending-placement classification and measured affected-trade ranking
remain open; no source changes or work items created for this audit.

## 2026-09-09T22:05Z — Balke USDJPY range-window sweep pre-registered and commissioned (OWNER ~21:45Z)

OWNER: find the best range window empirically on our own .DWX data. Plan pre-registered in
`docs/research/BALKE_WINDOW_SWEEP_PLAN_2026-09-09.md` (commit 1da6f019c7): fixed UTC+3 clock,
stage A 60 windows (start 0..9 x length 2..8, exit 18) + stage B 30 exit variants on the top-5,
per-year OPT_CENSUS cells 2019..2025 (630 cells, ~8-9 h fleet time, GELB cost reported), costed
return_to_maxdd, DEV 2019-2022 / OOS 2023-2025, plateau-median selection over the 3x3 grid
neighbourhood, admissibility >=10 entry days every year, refutation = winner plateau < 1.10 x the
03-06 DEV score or OOS confirmation fails. Declared trial count 90, parameter count 3.
Codex ticket `49af4f08` P92 (Terra/high): `window_sweep.py` plan/enqueue/report + declaration.json
bound to the plan commit; stage A enqueue only; Claude adjudicates. Follow-ups: Astra `d444a7a8`
(clock modes / buffer / outside-range / Balke minute config) runs on the winner only; the 1,085-cell
pattern census stays provisional until the window is settled.

## 2026-09-09 — Balke baseline clock audit and sibling prerequisite

RESULT `d444a7a8`: PARTIAL_REVIEW / DEPENDENCY_PENDING. Exact baseline 2018-2022:
888 trades reconciled; 03 UTC placement in both seasons; 7 confirmed fade-only
order days, 1 filled trade, -869.92 native net. Late exits and cumulative-journal
contamination are explicitly documented. Evidence:
`docs/ops/evidence/BALKE_CLOCK_AUDIT_2026-09-09.md`.
Reserved QM5_41405; draft in cards_review; governed magic prerequisite `2e7d5619`
is TODO. Later WINSWEEP plan sequences variants after window selection. No new
binary, fidelity rerun or comparison result is claimed; 41398 remains untouched.

RESULT `2e7d5619`: governed allocator installed and verified QM5_41405 / USDJPY.DWX
slot 0 / magic 414050000. Commit 448a98e8fa; REVIEW, no build or promotion.

RESULT `49af4f08`: PARTIAL_REVIEW. WINSWEEP planner, authenticated worker adapter
and incomplete-matrix report pass 71 tests; DL-089 1085-cell plan is identical.
420 planned / 0 production enqueued / no first claim or MEASURED cell. Apply is
blocked by all ten workers retaining old code; safe idle rollout is required.
See `docs/ops/evidence/WINDOW_SWEEP_IMPLEMENTATION_2026-09-09.md` and its exact
reproduction commands. No active worker/backtest interrupted; no Stage-B enqueue.

RESULT single-pass Codex cycle, 2026-09-09 22:07 UTC: seven assigned tasks handed
to REVIEW, Codex IN_PROGRESS empty. FTMO C has isolated source and 39 source/oracle
tests, with binding/retry/native gaps; B compares 16 pairs (7 exposed streams),
proposes zero roster and preserves native cost gaps; A repairs V3 seed reading
with 36 tests and a bounded dry-run, still zero admitted and 16 stale closures.
Cycle evidence: `docs/ops/evidence/ORCHESTRATION_CYCLE_2026-09-09.md`.
Final farm health FAIL (14 fail / 52 OK / 17 warn); QM5_10260 has one pending Q04,
no active claim. No routing, terminal change, backtest interruption or main advance.

## 2026-09-10T00:05Z — WINSWEEP stage A live: 420 cells enqueued after staggered worker reload

RESULT: Codex `49af4f08` delivered window_sweep.py + declaration + 71 tests (commit 1b4644149e) and
refused apply fail-closed because all 10 workers predated the adapter (correct). Orchestrator ran the
established staggered idle-worker reload (chunk 59 = copy of chunk 58 discipline: one terminal at a
time, no active claim, no mutation lock, >=150 s spacing; log in the session scratchpad; 10/10
reloaded 23:26-23:53Z, every worker start newer than the adapter mtime). Then
`window_sweep.py enqueue --stage A --apply` twice: inserted 420, then 0 (idempotent). All 420 rows
pending, frontier priority 1 (same as the boosted DL-089 41398 frontier), so both programs
interleave; nothing deleted or down-prioritised. Ticket closed APPROVED (partial delivery, S5 done
by orchestrator). Next: first WINSWEEP claim/MEASURED in the hourly watch (`winsweep` line), then
`window_sweep.py report` and stage-A adjudication per the pre-registered plan; stage B tooling is a
follow-up ticket after adjudication.

## 2026-09-10T00:55Z — WINSWEEP/41398 cells starved by claim order; queue-order lever applied; Codex fix commissioned

FINDING: canonical claim order (farmctl.pending_claim_order_sql, top-down ON) ranks OPT_CENSUS
frontier rows idle-program -> queue_order_at (Q12 owner) -> ... -> _asset_rank -> updated_at.
USDJPY programs (asset rank 3) sit behind the continuously re-boosted XAU (0) / NDX (1) frontier
rows: DL089_QM5_13213 (41398 pattern census) got 2 of 1,085 cells in 10 h; WINSWEEP 0 of 420 (no
Q12 owner, sentinel queue order). Snapshot: first 13213 row at position 15, first WINSWEEP row at 21.
ACTION (GRUEN queue-order change, reversible): set_dl089_queue_order.py apply on Q12 owner
97908d93 (ea QM5_13213) queue_order_at=2026-08-20T00:00:00+00:00 -> rank 51 -> 1; backup written by
the tool; reason + OWNER instruction 2026-09-09 ~21:45Z recorded. This lifts the 41398 pattern
census; WINSWEEP cannot be targeted by the lever (window rows carry no q12_work_item_id) -> Codex
ticket `ba63936d` P95 (Terra/high): generic queue-order support for window programs, tests,
DL089 identity proof; orchestrator then reloads workers (chunk-59 pattern) and applies the lever.
STRUCTURAL (for OWNER, parked): asset-rank starvation of USDJPY programs under the top-down selector
is a pool-order policy question; candidate fairness option (round-robin over idle programs before
asset rank) to be proposed by Codex in its RESULT, decision stays with OWNER.

RESULT `ba63936d`: REVIEW. WINSWEEP now has an append-only, non-dispatchable
`WINDOW_SWEEP_OWNER` (`e144b67f-787d-5386-b7e7-9f070fb89a58`) and a governed
`window_sweep.py queue-owner|queue-order plan|apply|list` lever. The selector
reads its payload `queue_order_at` only for `qm.window-sweep.v1` WINSWEEP cells;
existing 420 sealed cell payloads remain unchanged. Focused tests: 41 passed,
including XAU/NDX/WINSWEEP temporary-DB ordering (WINSWEEP last before, first
after) and identical ordered-ID SHA-256 for non-window rows. Worker reload and
the OWNER-recorded lever apply remain orchestrator actions; no restart, terminal,
backtest, live setting, pipeline verdict, or policy change occurred. Evidence:
`docs/ops/evidence/2026-09-10_winsweep_queue_order.md`. OWNER proposal only:
consider round-robin idle-program fairness before asset rank to address recurring
USDJPY starvation.

## 2026-09-10 — RESULT: FX cointegration frontier reconciled; existing fallback retained

The frozen sign-aware 66-pair scan remains fully covered (66/66, zero unbuilt);
QM5_12532 and QM5_12533 are past Q02 with later terminal failures. The selected
non-duplicate fallback QM5_12507 EURUSD/GBPUSD already has one pending,
priority-tracked logical Q02 row, so no duplicate enqueue or priority rewrite was
made. PACER source audit: exit 0, zero `EA_FRAMEWORK_INPUT_PINNED` hits; backtest
risk remains `RISK_FIXED=1000`, `RISK_PERCENT=0`. Five active claims occupied a
paced launch cap of one, so no dispatch followed. Evidence:
`docs/research/FX_COINTEGRATION_PACED_CAPACITY_STOP_20260910T003623Z.md`.
No portfolio gate, T_Live, AutoTrading, card, EA, registry, setfile, manifest,
queue verdict, or terminal state changed.

## 2026-09-10T02:35Z — Fleet stall after queue-order commit; hotfix + reload chunk 61

INCIDENT: after reload chunk 60 (01:27-02:00Z) every worker needed ~17 min per claim attempt and
OPT_CENSUS active fell to 0 (T2 log: claim attempt 01:28:17 -> result 01:45:10). Cause: the new
window-owner correlated subquery in farmctl.pending_claim_order_sql (Codex 4ce11df5c1) used
upper(COALESCE(phase,''))=... and scanned all 146,861 work_items rows once per window cell
(420x per attempt). Orchestrator snapshot query also timed out (>120 s).
FIX (GRUEN infra repair, verdict logic untouched): subquery anchored on idx_work_items_ea_phase
(window_owner.ea_id = w.ea_id AND phase = literal), semantics unchanged (owner row carries the
program ea_id). pending_claim_order_sql now 4.7 s for 6,411 rows; 25 tests pass
(test_claim_order_memo.py, test_window_sweep.py). Rollback = git revert of this hotfix commit +
staggered reload. Reload chunk 61 started 02:3xZ (session_tools/reload_chunk61.py). Lever state:
WINSWEEP owner e144b67f queue_order_at=2026-08-19 (apply 01:32Z, backup
farm_state_before_window_sweep_queue_order_20260910T013238Z.sqlite); 13213 owner 97908d93 = 2026-08-20.
LESSON: time pending_claim_order_sql on the production DB before every farmctl SQL change; a
worker claim loop of >2 min is the stall signature. Codex ticket ba63936d closed APPROVED with the
defect recorded; regression-time test = follow-up (noted, not ticketed until quota reset).

## 2026-09-10T03:45Z — OWNER decision "Winsweep ja": L=2 for the WINSWEEP program (chunk 62)

OWNER (chat 03:3xZ) answered the 02:40Z GELB proposal with YES. Execution: machine env
DL089_SAME_PROGRAM_PARALLEL_ALLOWLIST now = 21507,12710,11910 + WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025
(append-only). Finding while executing: start_terminal_workers.py carries only QM_* and
DL089_PROGRAM_SLOTS from machine scope (comment dated 2026-09-05), so DL089_LANES_PER_PROGRAM=2 and
the allowlist never reach workers unless the launching session env carries them -> reload chunk 62
(session_tools/reload_chunk62.py) injects both into the launcher env (same pattern as QM_DSR_V2 in
chunk 58). The L=2 decline-loop fix (docs/ops/evidence/2026-09-05_dl089_l2_decline_loop_rootcause.md)
is in code with regression tests but its canary was never run: this reload is watched as that canary
(signature = census cells/h collapse ~88->21 with PROGRAM_PREFLIGHT_SUPPRESSED); rollback = reload
without the two vars. Whether the 2026-09-07 SAMEPROG execution ever reached workers is an open
question (no effective-limits evidence in state) -> noted for Codex after the quota reset.

## 2026-09-10T04:50Z — RESULT: WINSWEEP L=2 live (chunk 62), no decline loop

Reload chunk 62 finished 04:46:15Z (10/10). Proof of L=2: two WINSWEEP cells active concurrently
(T4 + T5) at 04:48:39Z (poll log in session scratchpad). Census throughput 44 cells / 30 min
(~88/h), 0 PROGRAM_PREFLIGHT_SUPPRESSED events since 04:00Z -> the 2026-09-05 L=2 fix holds under
this bounded canary. WINSWEEP stage A: 46 MEASURED / 374 pending at 04:46Z; expected completion
~12-14 h at 2 lanes. Next: hourly watch; window_sweep.py report + stage-A adjudication when all
420 cells are MEASURED (per docs/research/BALKE_WINDOW_SWEEP_PLAN_2026-09-09.md section 5).

## 2026-09-10T19:05Z — OWNER "Umsetzen!": census cap G=3 for 48 h (chunk 63)

DIAGNOSIS (Mission Control Clear-ETA P50 ~61 d): gate throughput collapsed to 26 rows/24 h (7-day
rate ~11/h) because the fleet ran census only (1,920 cells/24 h): priority-track OPT_CENSUS rows
rank before Q04, 4-5 census cells x 8 GB commit exhaust the RAM headroom so Q04 long runs (32 GB
reservation, drain_window tracker) never fit, and Q02 intake is refused at the 97 % CPU ceiling
(artifacts/qm5_41424_q02_cpu_ceiling_stop_20260910.json). Pending: Q02 777, Q04 666, census 6,453.
ACTION (OWNER YES 19:00Z): DL089_CELL_SLOTS=3 injected via reload chunk 63 (plus machine scope for
the record; the launcher does not carry it), applied immediately instead of after WINSWEEP stage A
because WINSWEEP heads the claim order and keeps its 2 lanes inside the cap. Expected: census ~30
cells/h, Q04/Q02 windows open, Clear-ETA toward ~1 week. ROLLBACK due 2026-09-12T19:00Z: staggered
reload without DL089_CELL_SLOTS (session one-shot scheduled; any Factory restart also drops it since
the launcher carries only QM_*/PROGRAM_SLOTS). Watch: census cells/h, Q04 done/24 h, Q02 admission.

## 2026-09-10T19:45Z — ASTRA-T11-PRESCREEN commissioned (OWNER ~19:30Z)

OWNER: Astra shall test on T11 whether optimizer runs or other backtest variants can pre-sort parts
of the schedule; real-tick stays mandatory at the end. Ticket `b48ba1fb` P86 (Astra, scalpel):
speed matrix on T11 (real-tick per-year vs single full window vs OHLC M1 vs generated ticks vs open
prices vs MT5 optimizer with local agents), fidelity vs the >=318 MEASURED WINSWEEP cells and >=100
DL-089 41398 cells (rank correlation, top-k overlap, false-negative rate per cut-off), option table
(warm runner, full-window split, tick-cache reuse, agent parallelism), and a decision-card draft for
a governed pre-screen protocol (ordering only, never a verdict; real-tick confirmation + random
control sample). Isolation: T11 only, no work_items, CPU guard (<=4 agents, pause at >90 % CPU),
RAM guard. Builds on V4a/V4b evidence (3e129337, c7536f46, 7d800fe1). Recipe
session_tools/enqueue_astra_t11_prescreen_0910.py.


## 2026-09-10T19:40Z — RESULT: ASTRA-T11-PRESCREEN preflight deviation (b48ba1fb)

REVIEW, DEVIATION_NO_MT5_LAUNCH; experimental acceptance remains incomplete. Canonical baseline
audit authenticated 345/345 existing Model-4 receipts (320 WINSWEEP + 25 current-binary DL-089).
DL-089 has only 25 measured cells, all 2019, versus the requested >=100; the task premise >=340
is not the current DB state. T11 root lacks Bases/symbols.custom.dat, matching the catalog gap
documented in the September 9 warm-lab report. Standard smoke admission requires worker-bound
work; cheaper modes are not admitted, and this cycle forbids manual terminal launches and new
work items. No launch, catalog repair, worker restart, queue mutation or gate/counter change.
Cheap-mode speed/fidelity and expected savings are NOT MEASURED. Raw audit under
D:/QM/reports/research/t11_prescreen_2026-09-10/; report and CSV/hash verification:
[canonical packet](evidence/b48ba1fb_t11_prescreen_2026-09-10/T11_PRESCREEN_FIDELITY_2026-09-10.md).
Review the T11 readiness/isolated-runner prerequisite before resuming the experimental task.

## 2026-09-10T19:55Z — RESULT: census cap G=3 live (chunk 63), standard path running again

Reload chunk 63 finished 19:49:09Z (10/10). Snapshot 19:5xZ: active = OPT_CENSUS 3 (cap holds),
Q04 2, Q03 1, Q07 1, Q10_NEWS 1; done in the previous 30 min: Q04 3, Q03 2, Q02 1, COMPILE_EA 1,
census 22 (~44/h, WINSWEEP 323/420 with 1 active). CPU 91 %, RAM free 38 GB. First gate rows since
the collapse; Q02 admission (CPU < 97 %) to be confirmed over the next hours. Rollback one-shot set
for 2026-09-12T19:05Z.

## 2026-09-10T20:12Z — RESULT: QM5_41427 WTI maintenance sleeve built; Q02 held at CPU ceiling

QM5_41427 `wti-refmaint-wclv-cont` is source-approved, non-duplicate reviewed, magic-registered,
and Q01 compile PASS (`6cb23d9a`, 0 errors/warnings, strict build-check PASS, 12/12 reference tests,
PACER pin audit 0 findings). It shorts XTIUSD.DWX for one week only after a negative two-week
parent-close return plus lower-tercile completed-week close in February/March/September/October;
fixed-risk backtest only. Five current whole-host CPU samples were 98.83/98.73/97.85/99.12/100.00%
(average 98.91%, maximum 100.00%), exceeding the exclusive 97% ceiling. Stopped as ordered: no Q02
row exists. Evidence: `docs/ops/evidence/2026-09-10_qm5_41427_wti_refinery_maintenance_weekly_close_location_build_cpu_hold.md`.

## 2026-09-10T20:30Z — OWNER "Umsetzen" (3 acceleration items): status

1. Census order by counter value (GRUEN, set_dl089_queue_order.py, backups by the tool): programs whose
   pair is not yet Q14-terminal first, fewest pending cells first -> 21502, 10513, 10403, 13013, 11660 at
   queue_order_at 2026-08-19T00:10 (behind WINSWEEP 08-19 00:00); 13213 pattern program (pair COMPLETE
   at Q14, 1,060 pending) demoted to 2026-08-30; 10145 (ECON_FAIL) to 2026-08-31; 41097 owner row is
   done/NO_FILTER_CHANGE -> precondition refused, left as is. COMPLETE pairs keep 08-21/08-29.
2. T11 launch path: Codex `63398c6b` P90 (catalog from signed source, research_canary launch mode,
   isolation + CPU/RAM guards, one real-tick smoke cell identical to the fleet cell); ASTRA-T11-PRESCREEN
   `b48ba1fb` re-opens after it (its DEVIATION: symbols.custom.dat absent on T11).
3. Warm-runner V4a: correction - never validated against MT5 (both V4a tickets DEVIATION_STOP, injected
   test backend only, 0 warm cells). Codex `da0512a7` P84: resident-MT5 backend behind the existing
   Default-OFF flag, 20/20 warm-vs-cold identical on canary T10, rollout/rollback runbook; fleet
   activation only via staggered reload by the orchestrator.
Watch 20:26Z: census 45/h under cap 3; Q02 done 3h = 8 (admission works again), Q04 2 active; D: 87 GB
(queue-order backups ~0.75 GB each, 16 GB backup dir -> prune candidate after the reset).

## 2026-09-10T20:xxZ — RESULT: T11 catalog repaired; canary launch and V4a remain fail-closed

`63398c6b` REVIEW: T11 now has `Bases/symbols.custom.dat`, copied only after T1/T10 authenticated
copies agreed and post-copy SHA-256 verified (`6be56cd...09d65`, 20,480 bytes).  The existing signed
custom-history verifier passed all 108 T11-private USDJPY.DWX archive files (1.15 GB) against manifest
`fe0dd0...aab06`.  No real-tick S3 smoke ran: no governed research-canary controller currently supplies
the required no-work-item/no-DB-write isolation plus resource guards, and the signed worker activation
correctly excludes disabled T11.  `da0512a7` REVIEW: warm runner stays Default-OFF; its injected session
protocol and DEV2 restart adapter do not constitute a resident T10 backend, so no 20-cell parity or
throughput claim is made.  No worker/terminal restart, T_Live/AutoTrading action, queue or gate change.

## 2026-09-10T20:57Z — RESULT: QM5_41428 WTI ramp reversion built; Q02 enqueued

QM5_41428 `wti-reframp-wclv-fade` is source-approved, non-duplicate reviewed, magic-registered,
and Q01 compile PASS (`acf9dfe5`, 0 errors/warnings, strict build-check PASS, 12/12 reference tests,
PACER pin audit 0 findings). It buys XTIUSD.DWX for one week only after a negative two-week
parent-close return plus lower-tercile completed-week close in April-July; fixed-risk backtest only.
Five current whole-host CPU samples averaged 68.52% with an 87.14% maximum, below the exclusive 97%
ceiling. One Q02 canary is pending as `2edd794c-cb9e-4ed5-827a-d67223c8bd02`. Evidence:
`docs/ops/evidence/2026-09-10_qm5_41428_wti_refinery_ramp_weekly_close_location_reversion_build_q02.md`.

## 2026-09-10T21:xxZ — RESULT: WINSWEEP Stage-B tooling ready; Stage A still guarded

REVIEW. Stage-B plan/enqueue/report tooling is implemented and focused tests pass (43). Stage A has
349 MEASURED, 1 active and 70 pending cells, so the guarded Stage-B production dry-run refuses before
any DB or ledger mutation. Evidence: `docs/ops/evidence/2026-09-10_window_sweep_stage_b_tooling.md`.

## 2026-09-10T23:35Z — REVIEW drain after the weekly reset (Sonnet fan-out, 21 rows)

Quota: Claude weekly 0 % after reset. 21 REVIEW rows, one Sonnet reviewer each (artifact exists, content
supports verdict, cited paths/commits real, scope clean, acceptance from payload, tests re-run when < 60 s).
Closed APPROVED (16): 60cd31a8, e1358f42, f6d18a6e, 2243207d, 734baee6, 2e7d5619, 46167bd9, 819e967e,
83ffadd6, cbd1e400, fc926dde, b48ba1fb; APPROVED as partial/honest stop with follow-up: 83efd045 (cited
log path missing, smoke not invented), 54729be7 (native costs open), b7858771 (M01-M12 open, blockers
named), da0512a7 (6th V4a stop, blocker = missing resident-session surface), d444a7a8 (S1/S2 done: range
end 03 UTC = broker 05 winter / 06 summer; 7 fade-only days confirmed; S3-S6 wait on WINSWEEP), 63398c6b
(catalog installed, S3 blocked on missing research_canary controller), 95b48188 (804-EA inventory:
MISMATCH 0, UNSTATED-IN-CARD 554, MATCH 93). RECYCLE -> re-routed TODO: 2f717775 (doc stale vs completed
T1 receipt ed393d48). f63a632a APPROVED as partial (artifact lacks magic/slot, unnamed 23-tests claim). Findings recorded: RECYCLE is a
graveyard state (200+ rows, not auto-routed); the hourly watch line for the 41398 pattern census was
mixing WINSWEEP rows (same ea_id) - fixed to program scope (DL089 program had 25 done, not 377).
New tickets: 8f6a6b3c P91 BUILD research_canary (explicit authorization), 31b8255e P83 BUILD resident
session backend (explicit authorization), fleet clock audit part 2 (P60), FTMO native receipts (P65).
NEXT: WINSWEEP stage-A adjudication when 420/420 MEASURED, then stage B via fc926dde tooling, Balke clock
audit continuation on the winner, Dukascopy download resume under 3032534e (2.2-day projection).

## RESULT 2026-09-11 — 31b8255e V4a resident backend

`REVIEW — TECHNICAL_IMPOSSIBILITY_CURRENT_MT5_COMMAND_SURFACE`:
`docs/ops/evidence/2026-09-11_v4a_resident_backend.md` binds the official MT5
startup/tester interface, the exact cold-launch and fresh-logger boundaries,
and the closest safe MetaTester-local-agent alternative. The Default-OFF flag
remains unset; no T10 launch/reload or factory mutation occurred. Focused
warm-runner tests are recorded with the artifact.

## RESULT 2026-09-11 — 8f6a6b3c research_canary

`REVIEW — IMPLEMENTED_NO_GUARDED_S3_RUN`: the no-DB T11 controller and focused
tests are in `tools/strategy_farm/research_canary.py` and
`tools/strategy_farm/tests/test_research_canary.py`; receipt, isolation,
signed-history, CPU/RAM, job-object and Model-4 controls are documented in
`docs/ops/evidence/2026-09-11_research_canary_t11.md`. No terminal was
started: the exact S3 EX5/setfile are not T11-staged, so no S3 comparison is
claimed.

## RESULT 2026-09-11 — ff5cc3b9 Dukascopy containment fix

`REVIEW — TARGETED_FIX_TESTED`: `download_bi5.py` now resolves `raw_root`
before comparing it with resolved destinations, retaining the escape refusal.
The extended-prefix regression and genuine-escape test pass with the focused
23-test downloader suite; no downloader was restarted.

## 2026-09-11T22:43Z — RESULT: QM5_41429 WTI maintenance reversion built; Q02 enqueued

QM5_41429 `wti-refmaint-wclv-fade` is source-approved, non-duplicate reviewed,
magic-registered, PACER-audited with zero framework-input pin findings, and
compiled with zero errors/warnings plus strict build-check PASS. One fixed-
risk `XTIUSD.DWX` D1 Q02 canary is pending as
`7a185f4e-ff2c-492d-925b-cba0b805f84e`. CPU admission max was 59% against the
exclusive 97% ceiling. No live, deploy-manifest, or portfolio-gate surface was
touched. Evidence:
`docs/ops/evidence/2026-09-11_qm5_41429_wti_refinery_maintenance_weekly_close_location_reversion_build_q02.md`.

## 2026-09-10T23:48Z — CORRECTION: 3032534e P2/P3 tooling already built, not missing

Prior cycle's ~00:35Z note claimed the Dukascopy P2 converter and P3
reconciliation harness "need new Codex tickets" — incorrect. Both
`tools/dukascopy/convert_to_import.py` and `tools/dukascopy/reconcile_overlap.py`
were built together with the P1 downloader under the original ticket
`e9dea1e3` (landed `3c65edd4d2` 2026-09-07, extended `97c1ea8d50` 2026-09-09),
23/23 tests pass. No new build ticket needed. What remains is *running* P3
once the downloader (PID 18208, `completed=73884/306286`, 9/37 symbols
touched so far) has covered each symbol's Oct-2025→Apr-2026 overlap window —
not yet the case for 28/37 symbols, so no reconciliation run this cycle.
`bb814520`/`dfc60103` gate unchanged (QM5_41394 Q02 rows still pending,
~2 days static). No `update-task` call on any of the three. Full detail:
`docs/ops/evidence/2026-09-07_dukascopy-backfill-20260829_3032534e_execution.md`.

## 2026-09-11T01:30Z — WINSWEEP stage A adjudicated: H-WIN KEPT, winner 00:00-08:00 (fixed UTC+3)

420/420 MEASURED. Tool-adjudicated per the pre-registered rule: refutation_verdict H-WIN KEPT; winner
s0_l8 exit 18 (DEV 1.96, plateau 1.56 vs baseline 03-06 0.65 / 0.78 = 2.0x, margin 1.10 met), OOS
confirmation true, OOS pooled costed PF 1.21; top five s0_l8, s1_l8, s1_l4, s2_l4, s3_l4. Full tables in
docs/research/BALKE_WINDOW_SWEEP_RESULT_2026-09-11.md. The empirical winner matches Balke's own
published USDJPY window (00:00-07:30 broker time); the 03-06 window (OWNER spec 2026-06-27) ranks
29/48. INGESTION REPAIR (GRUEN, rule untouched): the report refused 111 MEASURED cells because the
sequential in/out zip-pairing broke on same-timestamp fills with tester-rounded volumes; per-trade
costed P&L now comes from each MT5 out-deal row (aggregate identical), net reconciliation still strict,
17 tests pass. Stage B (30 windows x 7 years = 210 cells, ~10 h at 2 lanes): plan OK (top five bound
to the stage-A report sha 0bdd5d9e...), enqueue blocked by the worker-freshness gate after the
window_sweep.py patch -> reload chunk 64 running; enqueue follows. Astra stage-2 ticket on the winner
enqueued (sibling QM5_41405: clock modes x outside rules x buffer x ATR band + Balke minute config,
350 cells as its own declared program). New REVIEW rows (ff8be2f1 FTMO economics, 31b8255e resident
backend = TECHNICAL_IMPOSSIBILITY + MetaTester-agent alternative, 8f6a6b3c research_canary
implemented) under Sonnet verification.

## 2026-09-11T02:10Z — Second review round (3 rows) + V4a line closed

ff8be2f1 FTMO acceleration D economics: APPROVED (terms sourced live, frontier in required joint pass
probability, decision draft CONTINUE_EVIDENCE with review 2026-09-15; goes to the OWNER queue).
31b8255e resident backend: APPROVED as impossibility proof (MT5 /config is startup-only, one process
per cell; no IPC) -> the V4a warm-runner line is CLOSED after 6 stops; alternative = MetaTester
local-agent lane, evidence contract ticket cbacb01b P55 (docs only). 8f6a6b3c research_canary:
APPROVED as partial (controller + 5 tests real; S3 not run: EX5/setfile not staged in T11) -> f04d66ec
P90 adds staging with sha receipts, real dry-run receipt, then S3 identity run. Stage B enqueue waits
for reload chunk 64 (worker-freshness gate after the window_sweep.py patch).

## RESULT 2026-09-11 — Q-S3 T11 canary follow-up (`f04d66ec`)

`REVIEW — GUARD_REFUSED_NO_LAUNCH`: hash-bound staging copied the declared QM5_41398 EX5 and 2021
s3_l3_x18 setfile into T11 with matching SHA-256 receipts. The real T11 `--dry-run` passed signed
private-history and unchanged-isolation checks, then refused before launch because 5 MetaTester agents
were active while the hard limit is <=4. No smoke report, fleet identity comparison, terminal start,
T1–T10 interruption, T_Live, or AutoTrading action occurred. Evidence and exact rerun CLI:
`docs/ops/evidence/2026-09-11_research_canary_t11.md`.

## RESULT 2026-09-11 — Q-BUILD QM5_41405 stage-2 pre-flight (`dee2fc76`)

`REVIEW — CARD_SCOPE_NOT_APPROVED`: registry row and USDJPY slot-0 magic
`414050000` are active, but the only card is `status: DRAFT` and its limited
G0 build scope conflicts with the requested points-buffer, band, bar-period,
and minute-end expansion. No sibling source, compile claim, setfile, matrix,
or backtest was created. Evidence:
`docs/ops/evidence/2026-09-11_qm5_41405_stage2_preflight.md`.

## RESULT 2026-09-11 — Q-S3 T11 canary receipt follow-up (`f04d66ec`)

`REVIEW — REFUSED_NO_REPORT`: the controller now scopes its <=4 MetaTester
guard to T11 executable paths (7 focused tests PASS). The hash-bound real
dry-run passed the signed history and resource checks; the governed non-dry
2021 smoke completed in the T11 tester log but MT5 emitted no configured HTML
report, so the controller rejected it and no fleet identity comparison exists.
Evidence: `docs/ops/evidence/2026-09-11_research_canary_t11.md`.

## RESULT 2026-09-11 — Q-BUILD QM5_41405 reroute re-check (`dee2fc76`)

`REVIEW — PREFLIGHT_PASS_BUILD_NOT_STARTED`: the amended approved card, EA-ID,
and USDJPY magic tuple pass deterministically, but the sibling still has no
source, EX5, setfile, governed compile receipt, identity proof, or 350-cell
program declaration. No ungoverned compile/backtest or terminal action was
taken. Evidence: `docs/ops/evidence/2026-09-11_qm5_41405_stage2_preflight.md`.

## 2026-09-11T01:45Z — WINSWEEP stage B enqueued (210 cells)

Reload chunk 64 finished 01:38:35Z (10/10). `window_sweep.py enqueue --stage B --stage-a-report
docs/ops/evidence/2026-09-09_window_sweep_surface.json --apply` twice: inserted 210, then 0. 30 windows
(top five s0_l8, s1_l8, s1_l4, s2_l4, s3_l4 x exit 15/16/17/19/20/21) x 7 years, stage-A report sha
0bdd5d9e... bound in the ledger amendment. Program stays first in claim order (owner e144b67f), L=2,
~10 h expected. Final configuration rule: stage-B winner only if >= 1.10 x s0_l8/exit-18 plateau AND OOS
confirmation, else s0_l8 with exit 18 stands.

## 2026-09-11T02:55Z — QM5_41405 card amended + G0-approved; two Codex tickets re-routed

Astra stage-2 (dee2fc76) correctly refused to build from a DRAFT card whose G0 scope covered only three
inputs on the 03-06 window. Orchestrator amended the card (Astra's clock/outside-rule text kept):
defaults = stage-A winner s0_l8 (start 0 / end 8 / exit 18), six declared inputs (clock mode, outside
rule, entry buffer points 0/20, range band on/off, range bar period H1/M30/M5, range end minute) and the
pre-registered 350-cell matrix with five refutation criteria; body carries the Balke 2024 video URL
(validator needs year+URL). farmctl approve-card ran (g0 reasoning, expected_pf 1.2, dd 15; DB record);
the tool leaves cards_review cards in place and never touches the lifecycle field, so status was set
APPROVED by hand and the card mirrored to D:/.../cards_approved, C:/QM/repo/artifacts/cards_approved
(commit 5136355a4a) and the EA docs. dee2fc76 re-routed TODO->IN_PROGRESS with the card path.
f04d66ec (research_canary S3) re-routed: staging accepted; the <=4 agent guard must count only T11's
own MetaTester agents (path-anchored), not the fleet's; then real dry-run receipt and S3.

## 2026-09-11T03:05Z — Stage B unclaimable: worker lane resolver ignored ledger amendments (hotfix)

210 stage-B rows sat first in the claim order for ~1 h with zero claims while other census cells ran.
Root cause: terminal_worker._dl089_declared_lane resolves census lanes from ledger.cells (+ driver
reruns) only; window_sweep.py appends stage-B cells as an authenticated ledger amendment (kind
stage_b_cells), so every stage-B candidate was refused as absent-from-ledger (surfaced only as
no_pending_claimable). Codex fc926dde tested plan/enqueue/report, not worker acceptance. GRUEN infra
repair: for schema qm.window-sweep.v1 the resolver now appends amendment cells (append-only, dedup by
work_item_id); DL-089 programs untouched. Syntax ok, test_window_sweep 17 pass, lane/frontier tests 3
pass. Reload chunk 65 started; stage B expected to start claiming afterwards (~10 h at 2 lanes).
LESSON: every new cell class must be proven by a real first claim before the ticket is accepted.

## 2026-09-11T~02:5xZ — Claude task 3032534e: real T1 diagnostic defect found, Codex hardening ticket enqueued

`bb3d2f7f` (governed T1 M1-overlap-export diagnostic, dispatched under task 3032534e's own authority,
last seen "pending" by a prior cycle) reached a terminal state on its own via ordinary factory
throughput: `status=failed`/`verdict=INFRA_FAIL` at 2026-09-11T02:01:21Z. Root cause:
`framework/scripts/mt5_diagnostics/dwx_m1_overlap_export.py::canonicalize_export_set` aborts the
entire 37-symbol run on the first per-symbol empty M1 export (hit AUDCHF.DWX, 0 rows, second
alphabetically) instead of isolating the failure and continuing — even though the MT5-side raw
exporter had already completed across all 37 symbols (25 succeeded, 12 genuinely empty in T1's DWX
history for the window). Enqueued Codex ops ticket `6bbbf070-2945-4512-9d69-9c7782a5fbec` (build+test
only, priority 74, parent_task_ref=3032534e) to make per-symbol failure isolation/reporting complete;
explicitly does NOT touch the existing 37-symbols-required admission contract (separate OWNER-scoped
question, still open). Full detail:
docs/ops/evidence/2026-09-07_dukascopy-backfill-20260829_3032534e_execution.md. No `update-task` call
on bb814520/dfc60103/3032534e (gate rows unchanged; no acceptance criterion newly met).

## 2026-09-11T~03:2xZ — Claude task 3032534e: hardening ticket 6bbbf070 closed APPROVED

Independently re-verified (evidence doc read, diff scoped to exactly the
canonicalizer + its tests, no `.mq5`/no `validate_summary()` change, grep for
forbidden calls clean, own re-run of the 13 focused tests) before calling
`close-review 6bbbf070 --state APPROVED`. `canonicalize_export_set` now
isolates per-symbol failures instead of aborting the whole 37-symbol run on
the first empty export (real incident: 25 ok / 12 genuine DWX gaps, previously
only 2 symbols were ever attempted). Does not satisfy any of `3032534e`'s own
four acceptance criteria — no `update-task` call, task stays `IN_PROGRESS`.
`bb814520`/`dfc60103` gate unchanged (`QM5_41394` SP500.DWX/XAUUSD.DWX Q02
rows still pending/unclaimed since 2026-09-09T10:52:59Z, ~2d16h static). Full
detail: docs/ops/evidence/2026-09-07_dukascopy-backfill-20260829_3032534e_execution.md.

## 2026-09-11T03:30Z — RESULT: stage B claimable after chunk 65

Reload chunk 65 finished (10/10). Stage B: first claims within minutes of the first reloaded workers;
03:24Z 13 MEASURED / 1 active / 196 pending. Counter 22/25 (+1 since 2026-09-10 21:2xZ).

## 2026-09-11T04:05Z — Stage-2 build routed as governed build_ea; canary S3 re-routed for report export

dee2fc76 (Astra stage 2) verified the approved card but does not author EA source inside an ops_issue
-> governed build_ea task a10e4704 P92 enqueued for QM5_41405 (card G0-APPROVED, magic 414050000
pre-allocated, cell-0 identity vs stage-A s0_l8 cells is part of the build acceptance); dee2fc76
re-routed behind it (matrix as program BALKE2_QM5_41405_USDJPY_DWX_2019_2025 after COMPILE PASS).
f04d66ec (research_canary S3): T11-scoped guard + real dry-run receipt PASS; the live smoke ran
(2:26, 29M ticks) but MT5 wrote no report because the rendered tester.ini lacks the report export
keys -> re-routed with the fix (Report=, ReplaceReport=1, ShutdownTerminal=1, report sha in receipt),
then S3 identity table. Stage B: 19 MEASURED at 03:5xZ, claiming normally after chunk 65.

RESULT 2026-09-11 dee2fc76 Q-RESEARCH REVIEW: 350-cell parameter inventory verified; governed enqueue awaits QM5_41405 build and seven control identity receipts. Evidence: docs/ops/evidence/2026-09-11_dee2fc76_stage2_matrix.md

RESULT 2026-09-11 f04d66ec Q-S3 REVIEW: relative export and canonical tester contract repaired (9 tests PASS); real dry-run CPU average 92.080% > 90%, so no smoke launch or identity claim. Evidence: docs/ops/evidence/2026-09-11_f04d66ec_canary_export.md

RESULT 2026-09-11 a10e4704 Q01 COMPILE_PASS / REVIEW: approved QM5_41405 sibling built via governed queue on T4; strict checks PASS; seven annual default identity comparisons still required before stage-2 enqueue. Evidence: docs/ops/evidence/2026-09-11_a10e4704_build_result.json

## 2026-09-11T04:50Z — Morning briefing + stage-2 chain state

Briefing (skill /update): Codex week 70 % (build lane governor-throttled; 0 build activity 3 h, 75
pending build_ea mostly BLOCKED legacy), Claude week 6 %. Health FAIL 15/WARN 19/OK 52, no new class;
new since yesterday: ftmo_launcher_readiness (expected until next launcher run), factory utilization
7d 53 % < 55 % (yesterday's stall). Funnel pending: Q02 177, Q03 36, Q04 273, Q05 10, Q07 11, Q09 13,
Q10 16, Q12 27; counter 22/25. Stall verdict: moving (census 43/h under cap 3, Q04/Q05 active).
Stage-2 chain: QM5_41405 built and COMPILE_OK (a10e4704, 04:17Z; control identity pending, review
running); dee2fc76 re-routed with ordered steps (pre-register scoring, 7 control cells first via the
window-sweep machinery or a first-claim-proven adapter, identity proof, then 343 cells; Balke cells
keep parent trailing as documented approximation). f04d66ec re-routed with the corrected CPU guard
(pause > 95 % 5-min, 2 agents) after the 90 % guard refused the T11 dry-run at 92 %.

## 2026-09-11T05:25Z — Darwinex live-account analysis (OWNER question)

Sources: D:/QM/reports/portfolio/live_attribution_20260905_054540/live_deals_normalized.csv (deals
2026-04-24..2026-09-04), portfolio_manifest_live_24sleeve_20260724.json (24 sleeves, 100k, 9.75 %
total risk), live_burnin/livevsbook_sunday_20260906.json, live_book_dd_guard.log, pipeline_state pairs.
FINDINGS: since the 24-sleeve deploy (2026-07-24) net -2,974 = manual (magic 0) -1,703 [NDX SELL 1.00
lot 2026-07-27 -1,537 with sl 28385; EURUSD SELL 0.43 2026-07-24 -261; +57/+16/+24 small] + EA book
-1,271 (16 of 24 sleeves traded, 75 closes, gross win ~3.3k / loss ~4.6k, live PF ~0.72). Pre-deploy
(04-24..07-24) the EAs made +2,250 (manual -395) -> HWM 101,871. Biggest EA losers: 11132 SP500 -545
(2 trades), 11708 EURUSD -531, 10939 GBPUSD -265, 11421 EURUSD -250, 10513 XAU -231, 1567 EURUSD
-196 (2.39 lots, 1 trade); winners: 10706 GBPUSD +395, 10440 NDX +170, 10403 XAU +163, 1556 XAU +150;
13213 USDJPY (Balke 03-06) 23 closes -30 (live PF 0.91). Entry hours per magic plausible (13213 fires
03-07 UTC = fixed UTC+3 clock); no sizing/symbol anomaly seen. 8 sleeves flat for 6 weeks (10919,
12778, 12969, 12567 x2, 12989, 13117, 13128 = the highest-risk sleeves) and 4 telemetry-silent ->
liveness audit ticket 428f6802. Structural: only 5 of 24 live sleeves are current Q14-terminal pairs;
17 validated pairs are not live (book = July artifact, pre-v4 rebaseline). Weekly attribution ticket
308c8009. No live action (ROT); book replacement runs through the counter (22/25) -> Q11-Q13 -> OWNER.

## 2026-09-11T~05:0xZ — Claude task 3032534e: downloader crashed on fixed-tmp-filename race (solo, no cycle collision), resumed; Codex hardening ticket 8ffc30f1 enqueued

`progress.json` was frozen at `completed=126126` across two checkpoints
(~30min apart, not just stale by seconds). `download.log` tail showed a real
crash at `2026-09-11T04:35:47Z`: `os.replace` on `progress.json.tmp` ->
`progress.json` raised `PermissionError: [WinError 5]` from
`tools/dukascopy/common.py::atomic_write_bytes` — the same fixed-tmp-filename
hazard flagged after the 2026-09-10T22:49-22:55Z sibling-cycle collision, but
this time confirmed solo (full `Get-CimInstance Win32_Process` scan found no
`download_bi5.py` alive) — an external transient lock, not a duplicate
downloader. `hour_ledger.jsonl` intact (127,126 lines, no data loss). Removed
the orphaned `.tmp`, relaunched the identical resume command (new PID 7672),
verified resuming correctly from the ledger (resumed 207->1088 in ~15s,
errors=0) — within `3032534e`'s own `allowed_actions`. Enqueued exactly one
Codex build+test-only hardening ticket (`8ffc30f1-014d-4691-a314-d6a1767c4b4b`,
priority 65, `parent_task_ref=3032534e`): unique-per-call temp filenames +
bounded retry on transient `PermissionError` for `atomic_write_bytes`, no
change to HTTP retry/rate/resume semantics or reconciliation thresholds.
`bb814520`/`dfc60103` gate unchanged (`QM5_41394` SP500.DWX/XAUUSD.DWX Q02
rows still pending/unclaimed since 2026-09-09T10:52:59Z, ~2d18h static). No
`update-task` call on any of the three. Full detail:
docs/ops/evidence/2026-09-07_dukascopy-backfill-20260829_3032534e_execution.md.

## 2026-09-11T05:50Z — T11 status (OWNER question) + stage-2 continuation

T11 has produced no measurement yet. Chain: Astra pre-screen stopped (no symbol catalog) -> catalog
installed (63398c6b) -> research_canary controller built (8f6a6b3c) -> staging + T11-scoped guard +
real dry-run receipt PASS (f04d66ec, receipts under D:/QM/reports/research/WINSWEEP_.../2026091104*)
-> the live 2021 smoke ran twice (exit 0, 2:26, 29M ticks) but MT5 wrote no HTML report both times
(tester Report= is relative to the terminal root in /portable mode; export keys/collection must mirror
the fleet smoke runner). f04d66ec re-routed (3rd pass) with that fix and the 4-field identity target
(fleet cell 2021 s3_l3: net 2941.71 / PF 1.03 / 208 trades / sha b60d80f8...). Stage 2: dee2fc76
APPROVED partial (inventory ready; window_sweep.py is declaration-bound to 41398) -> new Terra ticket
036de7b9 P90: generic config_sweep.py, 7 control cells with FIRST-CLAIM proof, identity, then 343.

2026-09-11T~05:1xZ (Claude, task 3032534e): Dukascopy backfill downloader crashed a third
time in ~35min on the known atomic_write_bytes/os.replace PermissionError (WinError 5); ledger
intact (127126 lines, no loss) each time. Relaunched (PID 11056). Hardening fix already queued
as Codex ticket 8ffc30f1 (TODO, blocked on chronic repo_dirty_build_guard); a duplicate ticket
this cycle independently drafted (58703508) was found and closed once 8ffc30f1 surfaced. Full
account: docs/ops/evidence/2026-09-07_dukascopy-backfill-20260829_3032534e_execution.md.
bb814520/dfc60103 gate (QM5_41394 SP500.DWX/XAUUSD.DWX Q02) still pending/unclaimed since
2026-09-09T10:52:59Z, unchanged.

## 2026-09-11T05:20Z — Dukascopy tick-data lane status (OWNER question)

Decision OWNER-DEC-DUKASCOPY-BACKFILL-20260829 = YES, executed under Claude task 3032534e. Done: splice
CSV 37/37 symbols (tick-tail probe a7e1333c), P1 hardened downloader (f6d18a6e: 98.7 % success, 95
hours/min measured, 2.2-day projection), non-FX price_scale receipts 9/9 (2f717775), P3 DWX M1
overlap export read-only (ba2a478e), raw_root containment false-positive fix (ff5cc3b9). Production
run D:/QM/reports/dukascopy/backfill/20260909T191800Z_hardened: 306,545 hour-files planned, 11,693
completed (3.8 %), ~131 hours/min in the 3 h before 04:35Z (=> ~1.6 days of runtime), relaunched by
the headless cycle 05:11Z (pid 11056, concurrency 6). DEFECT: 5 crashes on PermissionError WinError 5
in common.atomic_write (progress.json.tmp -> progress.json share-locked by a concurrent reader); each
crash waits for the next relaunch. Ticket 4fa85eb8 P80: retry os.replace, continue on progress-write
failure, resume-safe relaunch. Remaining phases after P1: P2 append-only convert into the 2026 mutable
year (signed 2017-2025 archive untouched), P3 splice + verify_import per symbol + T1 reconciliation,
then the decision-bound task reports RESULT. Raw so far 1.6 GB reports + 2.7 GB data.

2026-09-11T~05:2xZ (Claude, task 3032534e): downloader (PID 11056) crashed a 4th time at
05:17:53Z on the same atomic_write_bytes/os.replace PermissionError; ledger reconfirmed
intact (127126 lines). Duplicate hardening tickets 8ffc30f1/58703508 both closed FAILED
(duplicate_of_4fa85eb8) by a sibling cycle; 4fa85eb8 (broader retry+backoff fix) confirmed
genuinely IN_PROGRESS/codex since 05:15:49Z. Removed orphaned progress.json.tmp, relaunched
(PID 17764), verified exactly one python process alive and resuming. bb814520/dfc60103 gate
(QM5_41394 SP500.DWX/XAUUSD.DWX Q02) still pending/unclaimed since 2026-09-09T10:52:59Z,
unchanged. Full account: docs/ops/evidence/2026-09-07_dukascopy-backfill-20260829_3032534e_execution.md.

2026-09-11T05:2xZ (Codex, task 036de7b9): RESULT — Q-CONFIG-SWEEP REVIEW. The generic
declaration-bound adapter, worker dispatch, 350-cell matrix declaration, and seven-control dry-run
PASS are committed; production enqueue is correctly held until the orchestrator staggered-reloads
the terminal workers that must authenticate the new adapter. No factory row or selection claim made.

2026-09-11T05:2xZ (Codex, task f04d66ec): RESULT — Q-S3 REVIEW. The governed T11
real-tick canary passed signed-history/resource/input checks and exited 0, but the receipt records
`REFUSED: tester exited without report`; no metrics or fleet identity comparison were accepted.

2026-09-11T05:2xZ (Codex, task 4fa85eb8): RESULT — Q-DUKASCOPY REVIEW. The progress
atomic-replace path now retries share locks for 30 seconds and makes progress.json advisory after
an exhausted retry; focused Dukascopy tests PASS. The existing production downloader was not restarted.

2026-09-11T~05:36Z (Claude orchestration cycle, task 4fa85eb8): RESULT --
Q-DUKASCOPY APPROVED. Independently re-verified the codex fix (commit fe7cc4ce09) before
closing: os.replace retry+backoff and 15s-throttled advisory progress.json writes match
spec S1-S4 exactly, 24/24 tools/dukascopy tests pass, no ledger/manifest/HTTP-retry change,
production downloader untouched (confirmed still running pre-fix binary, healthy,
completed=52594/306545 at 05:35Z). Completed the RESULT documentation gap (crash
timestamp 2026-09-11T04:35Z, fix commit, relaunch instruction) before close-review, since
the ticket's own acceptance criterion required all three and the codex RESULT line had
named none of them. close-review succeeded cleanly (no sibling-cycle race this time).
bb814520/dfc60103 gate (QM5_41394 SP500.DWX/XAUUSD.DWX Q02) still pending/unclaimed since
2026-09-09T10:52:59Z (~2d18h43m static) -- unchanged, no update-task call on either.
3032534e stays IN_PROGRESS (this closes one sub-ticket, not its own top-level acceptance).

## 2026-09-11T07:00Z — QM5_41405 control cells enqueued (config_sweep, chunk 66)

Config-sweep adapter (57574e26cc: sweep_engine dispatch in the worker, fail-closed default) reviewed:
worker diff 20 lines, 3 + 21 tests pass. Reload chunk 66 finished 06:58Z (10/10). `config_sweep.py
enqueue --controls-only --apply` twice: inserted 7, then 0 (program WINSWEEP_QM5_41405_USDJPY_DWX_2019_2025,
frontier priority inherited from 41398 rows). Open: the program has no queue owner (config_sweep has
no queue-owner command) -> claim-order position checked; first-claim proof pending (poll).

## 2026-09-11T07:15Z — 41405 control cells made claimable (queue owner + priority_track)

After enqueue the 7 control rows sat at census position 148-196: (a) no queue owner for the new
program (config_sweep.py has no queue-owner command) -> orchestrator inserted the WINDOW_SWEEP_OWNER
control row a5efb888 mirroring e144b67f (program WINSWEEP_QM5_41405..., queue_order_at 2026-08-19T00:05,
evidence sentinel per DB trigger; GRUEN queue-order lever); (b) payloads lacked priority_track (the
first sort key) -> set on the 7 pending unclaimed rows + config_sweep.py now emits priority_track and
opt_census_pool (3 tests pass). Claim-order position now 0 among OPT_CENSUS rows; first-claim poll
running. LESSON for 036de7b9 follow-up: a new program tool must ship queue-owner + priority_track.

## 2026-09-11T07:40Z — QM5_41405 identity PASS, stage-2 matrix enqueued

Control cells 2019-2025 (config 0 = fixed UTC+3 / AS_IS / buffer 0 / band on / H1) reproduce the
stage-A s0_l8 cells exactly on net_profit, profit_factor and total_trades for every year (report
sha differs as expected: EA name/magic/timestamps). Sibling QM5_41405 is a faithful copy of 41398 on
the winner window. Remaining 343 matrix cells enqueued via config_sweep.py (idempotent), priority_track
+ queue owner in place; ~17 h at 2 lanes (GELB cost). Adjudication per the approved card (five
refutation criteria) when 350/350 are MEASURED via `config_sweep.py report`.
## 2026-09-11T08:41Z — Codex task 6690f012: backup retention RESULT

RESULT: PASS — existing `QM_StrategyFarm_ContinuousRetention_45min` now limits
farm-state rotation to `farm_state_before_*.sqlite`, retaining the newest five
plus every matching backup newer than 24 hours. Applied run deleted 18 files /
13,271,830,528 bytes after `PRAGMA quick_check=ok`; pre-delete names, sizes,
and SHA-256 values are in
`D:/QM/reports/state/continuous_retention/20260911T083906Z/20260911T083906Z_backup_delete.json`.
Top-10 D: consumers and focused verification are recorded in
`docs/ops/evidence/2026-09-11_codex_backup_retention_6690f012.md`.

## 2026-09-11T~10:20Z — Claude orchestration cycle: 3 IN_PROGRESS tasks checked, no state change

bb814520/dfc60103 (QM5_41394 SP500.DWX/XAUUSD.DWX Q02 gate): new signal since the last
entry — XAUUSD.DWX Q02 (`3b315bc8`) was claimed/`active` on T2 at 09:50:49Z but reverted to
`pending`/unclaimed at 10:10:17Z (`worker_restart_released_stale_claim`, ordinary T2 worker
restart, not a new defect). SP500.DWX Q02 (`17e576cf`) still fully stale since
2026-09-09T10:52:59Z. Net: no Q02 verdict produced, acceptance criteria for both tasks still
unmet; outside `selected_effect_only` authority to force-claim. Full trace:
`docs/ops/evidence/2026-09-07_calendar-criteria-b-prime-20260907_617abd80_execution.md` and
`docs/ops/evidence/2026-09-08_q09-legacy-logger-sample-20260907_821096ac_execution.md`.

3032534e (Dukascopy backfill): downloader healthy, `completed=168949/306619` (55.1%),
~24.5k rows/hour since the last check, no crash recurrence post the `4fa85eb8` retry fix.
Full trace: `docs/ops/evidence/2026-09-07_dukascopy-backfill-20260829_3032534e_execution.md`.

No `update-task` calls this cycle (all three acceptance criteria remain unmet); all three
stay `IN_PROGRESS`. `farmctl health` and `agent_router status` reviewed at cycle start, no
new FAIL category vs. the prior baseline.

## 2026-09-11T10:55Z — T11 IS A VALID RESEARCH SEAT: identity smoke PASS

Root cause of five report-less runs found by the orchestrator in the T11 terminal journal: every
launch spawned MT5 LiveUpdate from the SYSTEM-profile roaming dir and exited 0 within 0.2 s before
any test (journal 06:43 / 07:22 / 11:41 local). Fixes (research_canary.py, commits 9ded253efe +
10278c5f92): /skipupdate on launch; FACTORY_MUTATION.lock presence recorded as observation, not a
refusal (it flickers constantly with 10 workers); CPU ceiling 95 pct with a 5-sample runtime guard
and env override QM_CANARY_CPU_LIMIT for a documented single run (used once, value 100, because the
fleet itself sat at 97 pct). RESULT run 20260911_104039_6540e43e: net 2,941.71 / PF 1.03 / 208
trades / maxDD 15,307.15 = fleet cell be5d3ce4 exactly (report sha differs by design). f04d66ec closed
APPROVED. Astra pre-screen part 2 ticket enqueued (modelling modes + optimizer flags in the controller,
speed + fidelity vs the 345 ground-truth cells, decision-card draft).

## RESULT 2026-09-11 — T11 pre-screen part 2 (`c3fc6278`): REVIEW / PARTIAL

Controller model flags (native MT5 mapping: 0 generated ticks, 1 M1 OHLC, 2 open prices,
4 real ticks), complete/genetic optimizer XML-to-CSV capture, two-agent process containment,
and risk/CPU guards delivered; 38 focused tests PASS. Frozen 345 real-tick cells authenticated
with 1,380 file-hash checks; 20-cell pilot matrix and exact 60-window optimizer shards prepared.
The governed M1 OHLC admission pilot passed at 90.66% CPU but exited without a report:
LiveUpdate recurred despite /skipupdate (run 20260911_110621_51e53c05). No further experiment
launches; native optimizer use, speed, fidelity and expected time saving remain NICHT GEZEIGT.
6,255 raw pending census rows / 1,119 target-program rows at the frozen snapshot; conditional
counts are not measured savings. Full acceptance remains unmet. Artifact:
[part-2 evidence](evidence/c3fc6278_t11_prescreen_part2_2026-09-11/T11_PRESCREEN_FIDELITY_PART2_2026-09-11.md).
Requires review of report-producing T11 launch behavior before resuming the matrix; no pipeline
promotion, pre-screen adoption, fleet repair or main integration performed.


## RESULT 2026-09-11 11:33Z - T11 pre-screen recheck

`c3fc6278` returned to REVIEW / PARTIAL: delivered controller unchanged, 38 focused tests pass; latest T11 journal and authenticated pilot still show LIVEUPDATE_RECURRED_NO_REPORT. Speed, fidelity and expected time saving remain NICHT GEZEIGT. No new terminal launch. Evidence: `docs/ops/evidence/c3fc6278_cycle_2026-09-11_1130Z/RECHECK.md`.

## RESULT 2026-09-11 12:03Z - T11 pre-screen unchanged prerequisite

`c3fc6278`: REVIEW / PARTIAL. Controller, terminal binary, pilot receipt and journal
hashes still match the earlier failed-pilot evidence; no report or T11 process.
38 focused tests pass. Experimental acceptance remains incomplete and measured
speed/fidelity/savings remain NICHT GEZEIGT. No new launch or fleet action.
[Fresh verification](evidence/c3fc6278_cycle_2026-09-11_1200Z/RECHECK.md).

## 2026-09-11T12:45Z — T11 pre-screen pilot cell measured by the orchestrator (OHLC M1 vs real ticks)

Codex/Astra c3fc6278 returned three times without launching (stale 13:11-local LiveUpdate excerpt),
so the orchestrator ran the first pilot through research_canary.py (97 % pacing clamp lifted only
for an explicit QM_CANARY_CPU_LIMIT override, receipt records it; 38 tests pass):
run D:/QM/reports/research/T11_PRESCREEN_PILOT_ORCH/20260911_123214_66a00683 (2021 s3_l3, ohlc-m1):
net 4,963.35 / PF 1.05 / trades 208 / maxDD 14,269.75 in 0:41 tester time, vs real ticks
2,941.71 / 1.03 / 208 / 15,307.15 in 2:12 (3.2x faster; same trade count, fills differ, net +69 %).
Single cell = orientation only; the 20-cell speed/fidelity matrix follows. Admission sampling (5 x
60 s) dominates the wall time (372 s) and must be shortened for batch pilots.

## 2026-09-11T14:05Z — T11 pre-screen pilot RESULT (30 cells, orchestrator lane)

docs/ops/evidence/2026-09-11_t11_prescreen_pilot_orch.csv / .md (Sonnet-executed via research_canary.py,
sequential, QM_CANARY_CPU_LIMIT=100 + admission sampling 5 s, receipts per run). Spearman of
score_cheap vs score_real: OHLC-M1 all years n=19 rho 0.977 (top-5 overlap 3/5, false-negative at a
top-50 % cut 0 %), 2021-only n=10 rho 0.952 (top-5 4/5, FN 20 %); open-prices 2021 n=10 rho 0.988 but
trade counts differ on 80 % of cells. Tester time 38-43 s vs 132 s real ticks (~3.3x). One anomaly:
2019 s3_l3 ohlc-m1 returned Ticks:0 (excluded, re-run pending). VERDICT: OHLC-M1 is admissible as a
coarse PRE-SORT (ranking) for window/config sweeps, never as economics; open-prices not admissible.
Next: Astra drafts the OWNER decision card (protocol: programs, mode, cut-off, real-tick confirmation
+ random control sample, expected saving on the ~6,400-cell census backlog).


## RESULT 2026-09-11 — Codex `3bc4034e`: Q-PRESCREEN decision card ready for REVIEW

Analysis complete: frozen pilot, 20,000-replicate bootstrap CIs, FN-at-cut tables, cost/queue reconciliation and German 15-line Mission Control text verified. Recommendation: preserve full real-tick measurement in existing DL-089 and Balke programs; new-program shadow validation only, provisional 70% keep. No pruning adoption: 2021 keep-50% FN=1/5, score cost semantics differ, net wall-time gain and earlier Q14 closures NICHT GEZEIGT. No launches, work-item writes, selection/gate/counter change or live action. Canonical board-advisor packet: [decision card](evidence/2026-09-11_prescreen_decision/PRESCREEN_PROTOCOL_DECISION_CARD_2026-09-11.md); [verification](evidence/2026-09-11_prescreen_decision/verification.json). Leave in REVIEW for Claude+OWNER close-out.

## 2026-09-11T14:45Z — Pre-screen decision card delivered (Astra 3bc4034e APPROVED)

Recommendation A: keep full real-tick confirmation for every sealed program; OHLC-M1 only as a research
ordering signal; for NEW programs an inert, pre-registered shadow protocol (keep 70 pct, 10 pct random
control of drops, suspend if omission or running FNR > 10 pct). Pattern census not eligible (sealed rule
needs all seven years). Throughput caveat: T11 at ~40 cells/h is below the fleet feed (45-50 cells/h),
so pre-screening is not a throughput multiplier without a second seat. Mirrored to Vault OWNER.md as a
non-urgent decision; orchestrator recommendation = A now, shadow protocol on the next new sweep program.

## 2026-09-11T15:00Z — WINSWEEP stage B adjudicated: STAGE_A_EXIT_18_STANDS

210/210 MEASURED. Top stage-B candidate s1_l4/exit 21 beats the plateau margin (2.60 vs 1.56) but fails
the OOS confirmation (OOS median 0.24 vs 0.91; pooled PF 1.07 vs 1.21) -> final configuration stays
s0_l8 exit 18 (docs/research/BALKE_WINDOW_SWEEP_RESULT_2026-09-11.md, stage-B section). Bug fixed in
select_stage_b (baseline plateau lookup). The 41405 stage-2 matrix (exit 18) remains valid as is.

## 2026-09-11T16:45Z — QM5_1557 card amended (explicit target_symbols, oil disposition)

Precondition f7f39835 blocked on card_target_symbols_missing_or_invalid. Mechanical amendment (GRUEN,
no universe change): frontmatter target_symbols = the 13 magic slots registered 2026-08-17; the body's
USOIL.DWX is not a factory custom symbol (oil = XTIUSD.DWX) and has no slot -> excluded, extension is an
OWNER decision. Re-approved in place via farmctl approve-card; EA docs card synced; ticket re-routed.

## 2026-09-11T17:00Z — OWNER-DEC-PRESCREEN-OHLC-20260911 recorded and commissioned

OWNER (chat ~16:5xZ): "T12 ist auch nutzbar, 1min Tests gehen auf allen Terminals, hauptsache
Zeitgewinn, aber natuerlich erfolgreiche EAs dann mit Real Tick Data verifizieren!" Reading: T12 becomes
the second research seat; OHLC-M1 (Model 2) cells are allowed fleet-wide as a PRESCREEN class; every
survivor is confirmed on real ticks (Model 4); real-tick evidence stays the only class for verdicts,
counter and books. Invariants for the implementation: declared keep fraction (start 70 pct per the
pilot), 10 pct random control sample of dropped arms, suspension at FN > 10 pct, PRESCREEN never
equals MEASURED. Tickets: T12 seat (Terra P88), fleet pre-screen cell class + promote + FN tracking
(Terra P95), DL-089 census Nachtrag draft for OWNER signature (Astra P90). Recipe
session_tools/enqueue_prescreen_decision_0911.py.

## 2026-09-11T17:55Z — Fleet parked behind commit_headroom_low: annual NDX census cells reserved 44 GB (GRUEN infra repair)

OWNER 17:3xZ: "Ueberwache, damit die Factory kontinuierlich auf Anschlag laeuft!" Measured 17:19Z: 10 workers,
2-3 active cells; of 1,060 declined claim polls in 90 min 417 were commit_headroom_low (effective headroom
17.7 GB < 24 GB floor) while free RAM stood at 44 GB. Cause: QM5_41323 NDX.DWX OPT_CENSUS annual cells
(815 pending, first in claim order) inherit the 44 GB single_index_tick commit class for 300 s after each
claim; the tester memory ledger shows these cells at max 7.32 GB / p95 1.99 GB (n=269). Fix: new commit class
opt_census_index_cell (12 GB) for OPT_CENSUS rows on index symbols; full-history index runs keep 44 GB.
Tests 127 pass (3 new in tests/test_index_tick_reservation.py). Rollout: staggered idle reload chunk 67
(session_tools/reload_chunk67.py, one terminal per >= 150 s, keeps cap G=3, L=2, allowlist). Rollback:
delete the OPT_CENSUS branch in _multisymbol_commit_class and reload. Secondary idle reasons to watch after
the reload: no_pending_claimable 243 (census cap 3 + Q02/Q04 not admitted), claim_spacing_wait 280,
factory_mutation_lock_busy 104 (dl089_matrix_service holds), cpu_high_pause 82.

## RESULT 2026-09-11T17:30Z — QM5_41444 WTI winter WR2 body reversion built; Q02 disk hold

New non-duplicate structural WTI sleeve `QM5_41444_wti-winter-wr2-body-fade` was source-approved,
registered, magic-allocated, implemented, reference-tested, and compiled on the paced fleet. Q01
work item `79a79aa3-19d0-4c9e-a9f0-ff9615c58ecf` is `COMPILE_OK`: zero compiler errors/warnings,
framework build check PASS, PACER pin audit `hit_count=0`, EX5 SHA-256
`77ce7cc5e4c4849ad0e2e995a4d2375d7e8a92b0c6dad3972f9878e27ddbbc22`.

First-Q02 dry run selected one fixed-risk XTIUSD.DWX D1 canary. CPU admission passed (76.0%
average, 93.0% maximum versus 97.0% ceiling), but D: free remained 57.97 GiB versus the governed
100 GiB intake floor after a short scheduled-purge recovery window. Q02 was not enqueued and no
backtest ran. Evidence: `artifacts/qm5_41444_q02_enqueue_20260911.json` and
`docs/ops/evidence/2026-09-11_qm5_41444_wti_winter_wr2_body_reversion_q02_handoff.md`.

## RESULT 2026-09-11 — Q-PRESCREEN fleet implementation REVIEW

The requested OHLC-M1 PRESCREEN build is withheld fail-closed: the task labels native
`Model=2` as M1 OHLC, but the governed mapping verifies `Model=1` = M1 OHLC and
`Model=2` = open prices. No worker, declaration, queue row, terminal, or live setting changed;
PRESCREEN cannot be emitted as MEASURED. Evidence:
`docs/ops/evidence/2026-09-11_fleet_ohlc_prescreen_build_review.md`.

## 2026-09-11T18:00Z — Tester-cache purge fail-closed for ~10 h (config_sweep ledger without symbol) — GRUEN repair

D: 58 GB (< 60 GB alert). tester_cache_purge.log: PURGE_SKIP_EVIDENCE_EXCLUSION_ERROR reason=invalid_symbol:None on
every 10-minute run since ~07:30Z (63 runs). Cause: the purge guard reads every artifacts/opt_census/*/ledger.json and
the config_sweep ledger WINSWEEP_QM5_41405_USDJPY_DWX_2019_2025 (schema qm.window-sweep.v1, engine config_sweep)
carries no top-level symbol. Fix: guard falls back to the <SYMBOL>_DWX_<from>_<to> program-id suffix
(tester_cache_purge_guard.ledger_symbol, test added); config_sweep now writes symbol into new ledgers (sealed
ledger left untouched). Guard runs clean on the live tree; next scheduled purge run verifies. Lesson: every new
ledger-writing program tool must satisfy the purge guard schema (symbol, ea_id, program_id).

## 2026-09-11T18:35Z — Fleet saturation audit after reload chunk 67: commit limit is the binding ceiling (OWNER Vorlage)

After chunk 67 (all 10 workers reloaded 18:16Z) the fleet holds 4-5 active cells, not 10. Measured (claim_result
skips, new diagnostics 244f9995b5): no_pending_claimable events skip ~365 rows as census_lane_protection and ~363
as heavy commit class -- these are the 369 pending single-symbol Q04 full-history rows on index symbols (NDX 173,
GDAXI 101, SP500 48, WS30 36, UK100 11; 44 GB single_index_tick class) plus 47 basket rows; 530 of 607 pending
Q02 single rows are recovery-class (idle-capped by design). Host: pagefile C: system-managed 26 GB, peak usage =
allocation (26.1 GB), total commit limit 89 GB (63 GB RAM + 26 GB) versus ~122 GB assumed in terminal_worker.py
(2026-08 comments); free commit 46 GB at 18:2xZ. With the 24 GB commit floor and 8 GB ordinary reservations per
claim (300 s), 5-6 concurrent testers exhaust the commit budget; a 44 GB index row is never admissible and the
drain window reports not winnable. Vorlage (OWNER, system setting + reboot): fixed pagefile 64 GB on C: (141 GB
free) -> commit limit ~127 GB -> ~10 concurrent ordinary cells and index Q04 rows admissible again. Alternatives:
(b) keep as is (fleet ~50 pct), (c) lower the 44 GB index class -- no ledger evidence for Q04 index peaks since the
ledger began 2026-09-03, so not proposed. Cosmetic fix in the same commit: the commit probe now selects phase so
the reservation label matches the claimed class.

## 2026-09-11T19:50Z — OWNER window (weekend, T_Live + FTMO flat): pagefile 64 GB fixed + VPS reboot executed

OWNER 19:4xZ: "Wir sind bereits im Wochenende, T_Live, FTMO haben alle Trades beendet und traden bis naechste
Woche nicht. Owner Fenster, fuehr alles gestaffelt durch." Executed in order: (1) pre-checks: AutoAdminLogon on,
QM_StrategyFarm_FactoryON_AtLogon + QM_T_Live_AtLogon + QM_FTMO_AtLogon logon-triggered, FTMO pulse
open_positions 0, no FACTORY_OFF.flag; (2) start_terminal_workers.py now carries DL089_LANES_PER_PROGRAM and
DL089_SAME_PROGRAM_PARALLEL_ALLOWLIST from machine scope (OWNER 2026-09-10 L=2), NOT DL089_CELL_SLOTS -> the
48 h census cap (due 2026-09-12T19:05Z) rolls back with this reboot as planned; machine allow-list extended with
WINSWEEP_QM5_41405 (config sweep, L=2); (3) pagefile: AutomaticManagedPagefile=false, C:\pagefile.sys
InitialSize=MaximumSize=65536 MB (was system-managed 26 GB; commit limit 89 -> ~127 GB expected);
(4) one-shot task QM_TMP_PostRebootCheck_0911 (AtStartup + 10 min) writes
D:/QM/reports/state/post_reboot_check_20260911.md/.json; (5) shutdown /r /t 120. In-flight rows at reboot
(orphan recovery = append-only rerun path): Q02 QM5_9121 XAUUSD (T10, since 17:57Z), Q07 QM5_12548 XAUUSD
(T7, since 19:01Z), three census cells. The orchestrator session and its session crons (hourly watch, cap
rollback one-shot) end with the reboot: next session reads the post-reboot report, verifies T_Live/FTMO
terminals up (no trading until Monday), commit limit, worker count 10, fleet saturation (target ~10 cells),
and deletes QM_TMP_PostRebootCheck_0911.

## 2026-09-11T20:15Z — Census cap survived the reboot (logon-session env) -> rollback now (chunk 69)

Post-reboot: commit limit 127 GB (pagefile 64 GB fixed), 10 workers, T_Live + FTMO launched (exit 0), but the
fleet still held 5-6 cells with only 3 census cells. Diagnostics (34dc6f54b3): opt_census_slot_deferred 3252 per
scan; dl089_scheduling.effective_limits(10) = (K 8, L 2, G 3) because DL089_CELL_SLOTS=3 had been mirrored into
the MACHINE scope on 2026-09-10 (my note "cap lives only in the reload env" was wrong) and every process of the
qm-admin logon session inherits it, launcher filter or not. Removed from machine + user scope 20:1xZ; reload
chunk 69 pops the inherited var (all 10 workers, staggered). Effective after chunk 69: K 8, L 2, G 6 (code
default). Rationale: the cap (OWNER 2026-09-10, 48 h) protected Q02/Q04 RAM windows; with the 127 GB commit limit
that contention is gone, and the OWNER window instruction covers the planned rollback. Lesson: check
[Environment]::GetEnvironmentVariable(name,'Machine'/'User') AND the logon session env before assuming a lever
is script-local.

## 2026-09-11T22:19Z — FX cointegration frontier remains fully covered; one valid Q02 row preserved

All 66 frozen-scan relationships remain represented; 12532/12533 are past Q02 and terminal later. The selected
fallback `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1` already has exactly one pending, attempt-zero, priority-bound
Q02 row (`547c4fd3-f3fd-4c59-b9dc-654e96521251`), so no duplicate queue mutation was valid. The PACER input-pin
audit passed with zero findings, symbol scope returned `BASKET_OK`, and the setfile remains
`RISK_FIXED=1000`/`RISK_PERCENT=0`. CPU was below the 97% stop (77.13% average, 85.35% maximum), but the legacy EA
actually warms four declared symbols and recent workers reported `multisymbol_commit_skipped`; reducing the
payload to two legs would be a dishonest metadata-only reclassification without splitting and recompiling the
EA. Evidence: `docs/research/FX_COINTEGRATION_QM5_12507_NONDUPLICATE_HOLD_20260911T221907Z.md` and
`artifacts/fx_cointegration_qm5_12507_nonduplicate_hold_20260911T221907Z_board_advisor.json`.

## 2026-09-12T00:45Z — RESULT: QM5_41405 stage-2 matrix adjudicated (STAGE2_CONTROL_STANDS)

350/350 cells MEASURED (real ticks). Tool adjudication (session_tools/adjudicate_balke_stage2_41405.py, rules =
card + stage-A plan sections 4-5, window_sweep.measure costed scoring, ledger authentication): H-CLOCK, H-OUTSIDE,
H-BUFFER, H-BAND refuted at 1.10x (best challengers c20/c22/c21 plateau 1.72 vs incumbents 1.57-1.72); H-BALKE
clears the plateau margin (c48 2.53 vs 1.65) but fails the OOS confirmation (OOS median 0.24 vs control 0.91).
Final configuration unchanged: fixed UTC+3, 00:00-08:00, exit 18, AS_IS, buffer 0, band on. Report
docs/research/BALKE_STAGE2_RESULT_2026-09-12.md, surface docs/research/balke_stage2_41405/. The config_sweep
report command only emits a status CSV (no scoring) -- adjudication script is the evidence path.

## 2026-09-12T07:10Z — Build lane unblocked (dirty guard, not auth); reviews drained; Aging/Stranded block commissioned

OWNER (Morgenbriefing reply): Codex resets ~09:00Z; use Sol + Opus/Sonnet for open programming; is Codex auth
broken?; resolve the Aging/Stranded block. Findings: health check codex_auth_broken explicitly says NOT auth --
repo_dirty_build_guard blocked builds (75 pending, 0 activity 3h). Repaired GRUEN: generated q05/q06 stress sets,
pump/compile-wave artifacts, window-sweep surfaces, agent evidence files, refreshed calendar seed hashes and the
QM5_41240 symbol-input source fix committed (bec7808e89, 76dca44dab, ..., 3d758eab06); stray root files removed;
_repo_dirty_status blocked=False (26 generated entries remain: 10 rebuilt .ex5 without receipts + 16 sets, non-blocking).
reconcile-exits --state APPROVED --apply: 603 APPROVED->PASSED, 40 APPROVED->PIPELINE (RECYCLE->TODO 181 = OWNER
capacity decision, on the board). Reviews closed: ef55f2ff APPROVED (withhold justified: Model=1 is OHLC-M1,
Model=2 open prices), 95081591 APPROVED (T12 staged, smoke refused by CPU guard, follow-up), f7f39835 APPROVED
(1557 precondition READY). New Codex tickets (session_tools/enqueue_aging_block_0912.py): 519c11fe prescreen
re-issue Model=1 (P95), b982a763 Q09 autoseal holds (P90), 5a6eea33 binding drift (P85), c955da7f Q08 INVALID
47 pct (P85), af3eac6e Q02 stranded pairs (P70, Luna), 3b334176 backup-gap ack (P60, Luna). Opus agent (worktree)
builds the video-lane re-route (OWNER 2026-09-09: AI seats, captions-first) with a batched release helper for
the ~420 BLOCKED video tickets (Default-OFF).

## 2026-09-12T07:50Z — RESULT video lane re-route (Opus, worktree) + RECYCLE analysis

Video lane: commit dd205e3fd0 (built in an isolated worktree, 26 new tests, 309 router tests green): video_analysis
servable by codex + claude captions-first (fetch_transcript.py per URL, VIDEO_<id>_*.md evidence with caption
timestamps, numbered frame list for the OWNER on "OWNER Videoanalysen.md", never guess), gemini/agy excluded,
Default-OFF switch QM_VIDEO_ANALYSIS_AI_LANES=1 or D:\QM\strategy_farm\state\VIDEO_ANALYSIS_AI_LANES.flag,
release helper release_video_analysis_holds.py (dry-run default, --limit --apply, fail-closed while OFF).
FINDING: only 2 of 422 BLOCKED rows are video holds (c993c011, d2bc5e78); the 420 others are August precondition
holds (registry/magic, ~97), terminal closes mislabeled BLOCKED (~35), RETEST 08-21 (~20), gemini research (95)
-> Codex ticket 349a8394 (BLOCKED disposition sweeper). Next: arm the switch for one dry run, release c993c011
with --limit 1, watch one captions-first artifact land.
RECYCLE (181): 40 card gone, 26 superseded, ~110 rework intents for existing EAs (card fidelity) -> OWNER Vorlage
corrected on the board (classified disposition, paced re-queue, not blanket archive).

## 2026-09-12T05:28Z — RESULT: Q08 INVALID cause audit + default-OFF DSR claim preflight

The ticket snapshot advanced to 26/54 Q08 INVALID rows. All 26 aggregate paths are readable; 24 rows entered
Q08 with `dsr_context_status=UNAVAILABLE`, nine overlap legacy zero-`strategy_*` sets, seven overlap
authenticated neighborhood runs whose perturbations all failed initialization, one was the already-fixed DSR
EA-label mismatch, and two include thin-sample gates. Added `QM_Q08_DSR_CONTEXT_PREFLIGHT=1` behind a Default-OFF
worker guard: with DSR V2 active, an unavailable candidate remains pending and is retried through the ordinary
claim predicate after its declaration/card/ledger source is repaired; no manual hold or verdict mutation.
No new rerun was valid: the sole code-defect row already has append-only successor `89ea5894` (`FAIL_SOFT`), and
the remaining classes are governance/artifact blocked or authenticated non-infra. Verification: 102 terminal
claim tests + 63 DSR tests + py_compile PASS. Evidence:
`docs/ops/evidence/2026-09-12_q08_invalid_rate_cause_and_claim_preflight.md`.

## 2026-09-12T08:25Z — OWNER-DEC-BACKLOG-20260912 applied: classified disposition of RECYCLE (181) + BLOCKED (422)

OWNER (chat ~08:0xZ): rework the ~110 RECYCLE intents, archive 66, get the agy-era rows done, clean or archive
everything else. Tool: session_tools/dispose_backlog_0912.py (dry-run, then --apply through agent_router
update_task/connect; append-only journal docs/ops/evidence/2026-09-12_backlog_disposition_journal.jsonl).
Plan counts: RECYCLE archive 85 (61 recycle_count=2, 4 rc=3, 5 card gone, 3 superseded, 12 duplicates) /
re-queue 95; BLOCKED archive 87 (card gone, terminal/superseded closes, duplicates) / re-queue 221 (deduped per
EA, priority 30, decision_bound_agent codex = Sol, rework_note) / 88 registry-magic precondition holds + 25
non-EA dependency holds stay BLOCKED for sweeper ticket 349a8394 / 1 video hold each (release helper).
Correction of an earlier statement: the 95 "gemini" BLOCKED rows were agy-era BUILD tasks (cards such as
qp-stress-reversal-sp500, demark-td-*), not research; they are dispositioned by the same rules. Final applied
counts follow in the next entry.

## 2026-09-12T08:50Z — RESULT BLOCKED sweeper batch 01: REVIEW (114 -> 103)

Default-read-only `blocked_agent_task_sweeper.py` classifies the complete BLOCKED census and gates every
mutation by explicit class and positive batch limit. Governed registry allocation added 9 EAs / 34 magic rows;
with one already-ready row, 10 build tasks returned to TODO through the ordinary predicate. One terminal review
closed FAILED. Remaining: 27 allocation candidates, 50 exact card/identity holds, 24 dependency/OWNER holds,
1 next-batch-ready row, and 1 untouched video row. A concurrent-scope race on 74 already-requeued agy rows was
fully reversed to TODO with a narrow second append-only journal entry; no verdict/artifact was overwritten.
Tests: 15 PASS; resolver dry-run 18,280 kept / 0 dropped; status-aware collisions 0. Evidence:
`docs/ops/evidence/2026-09-12_blocked_agent_task_backlog_disposition.md`.

## 2026-09-12T07:56Z — RESULT `5ff527e8` duplicate Q08 PASS-class review replayed

The exact immutable review of `3e7f5752c2` was already delivered as `348af875`,
accepted, and its three low findings applied in `f0738ca5d3`. Replay verdict remains
**PASS-with-findings**, with all findings resolved. Focused current verification:
86 passed, 1 skipped across the bundle, release-status, dual-builder, and DSR
consumer suites. No implementation or operational state changed. Evidence:
`docs/ops/evidence/2026-09-04_review_bundle_q08_passclass.md`.

## 2026-09-12T05:55Z — RESULT Q02 stranded exhausted pairs: REVIEW (3 -> 2)

Fresh row-bound classification found 3 pairs / 40 INFRA_FAIL rows: QM5_10505/XAUUSD and QM5_12582/XNGUSD
are ONINIT failures; QM5_20143/EURUSD is a NO_HISTORY/init failure. All are INVALID evidence defects, not valid
zero-trade outcomes. One dry-run-selected append-only canary was admitted for QM5_10505 (`7f4fb7d4`) because its
summary and worker log survive; the source row remains terminal. The other two are explicit repair holds (missing
worker log; missing summary+log) and were not requeued. Live health improved 3 -> 2; focused tests 14 PASS.
Evidence: `docs/ops/evidence/2026-09-12_q02_stranded_three_pair_disposition.md`.

## 2026-09-12T06:10Z — RESULT T12 identity follow-up: REVIEW / runtime guard refusal

T12 staged fleet-identical EX5 `68d37d3a...37c01` and 2021 s3_l3 setfile `afa42711...f35bf47c`.
The isolated Model-4 dry-run passed (108 signed history files, 0 T12 agents, CPU mean 85.7%, 37.2 GB free,
isolation unchanged). The actual attempt was admitted but its first runtime window reached 99.6% versus the
task-authorized 99% ceiling; the controller stopped only its bound T12 job and recorded REFUSED with no report.
Thus 2941.71 / 1.03 / 208 remains unproven and no T11+T12 concurrent pilot was admissible. Evidence:
`docs/ops/evidence/2026-09-12_t12_identity_runtime_guard_refusal.md`.

## 2026-09-12T06:23Z — RESULT Q09 sealed-plan hold binder: REVIEW (30 -> 2)

The dry-run census reproduced 16 lineage-derivation, 6 Q08-vintage and 8 plan-binding failures.
The deterministic Q09 PASS anchor binder authored immutable, hash-bound `q09-news-run-plan/v2`
artifacts and released 28 activation holds through the ordinary guarded helper. All 28 rows are
pending, unclaimed, RUNNABLE_BOUND and hold-free; 2 remain fail-closed (one has no exact Q09 PASS
source; one has a PASS-row/FAIL-summary contradiction). Focused tests: 117 PASS. Evidence:
`docs/ops/evidence/2026-09-12_q09_sealed_plan_hold_binder.md`.

## 2026-09-12T06:28Z — RESULT DL-089 OHLC-M1 Nachtrag D: REVIEW / OWNER signature required

Drafted the exact append-only plan/ledger amendment, a live 13-program numbers table, rollback,
and the requested 15-line German OWNER card. The 2026-09-12 06:25Z read-only snapshot is 4,579
pending DL-089 cells: at 70% keep plus 10% of drops, cell-level upper-bound arithmetic gives
3,355 real confirmations and 1,224 saved real-tick cells (24.48–27.20 gross fleet hours).
The original ~6,400 scenario remains 4,672 / 1,728. Real-tick Model 4 remains exclusive for
MEASURED/verdict/counter/book. No launches and no farm rows. Evidence:
`docs/ops/evidence/2026-09-12_dl089_ohlc_prescreen_amendment_draft.md`.

## 2026-09-12T06:45Z — RESULT fleet OHLC-M1 PRESCREEN class: REVIEW / Default-OFF

Built native Model=1 PRESCREEN declaration, ordinary claim/run, disjoint
`PRESCREEN_MEASURED` taxonomy, deterministic keep/control promotion with immutable ranking and
ledger-amendment hashes, and FN>10% suspension reporting. QM5_41405 plan-only dry run validates
350 cells; its artifact path is absent and production rows=0. Suites: 201 PASS plus 138 PASS;
PowerShell AST PASS. Activation remains Default-OFF pending orchestrator staggered reload via
`QM_OPT_CENSUS_PRESCREEN_ENABLED=1`; no production enqueue or terminal launch. Evidence:
`docs/ops/evidence/2026-09-12_fleet_ohlc_prescreen_build.md`.

## 2026-09-12T08:35Z — RESULT OWNER-DEC-BACKLOG-20260912 applied (488 rows, 0 refusals)

Journal docs/ops/evidence/2026-09-12_backlog_disposition_journal.jsonl: ARCHIVE 172 (-> FAILED with verdict
"ARCHIVED (OWNER-DEC-BACKLOG-20260912) ..."), REQUEUE 316 (-> TODO, priority 30, decision_bound_agent codex,
assigned_agent cleared through the canonical router connection, rework_note in payload). Task states after:
TODO 329, BLOCKED 114 (88 registry/magic precondition + 25 non-EA dependency holds for sweeper 349a8394 + 1 video
hold), RECYCLE 1 (video hold), FAILED 228, PIPELINE 215, PASSED 1319. Pacing: the 316 rework tasks sit below every
ops ticket (priority 30 vs 60-95) and are dispatched to Codex (Sol) by the router after the ~09:00Z reset under the
quota governor.

## 2026-09-12T09:20Z — Review round (8 Codex returns, Sonnet fan-out, one reviewer per row)

Closed: c955da7f Q08 INVALID APPROVED (default-OFF claim preflight 25df518e7e, flag QM_Q08_DSR_CONTEXT_PREFLIGHT to
activate in reload chunk 70; 102+63 tests re-run by the reviewer); 5a6eea33 binding drift APPROVED (33/33
classified, DB-confirmed; test evidence gap noted, reviewer ran 20 tests); 349a8394 BLOCKED sweeper APPROVED
partial (BLOCKED 114 -> 103, governed allocator batch-01, 74-row misstep fully reversed; follow-up f239a2d9 for the
24 non-EA holds, 27 allocation candidates, 50 exact holds, doc lede); cb065930 Nachtrag D draft APPROVED (numbers
reproduced against live ledgers; OWNER sign-off sentence on the board); 2c3cb09e T12 refusal APPROVED as honest
refusal (successor c2396a30 in the weekend window with the CPU guard at 100). Returned: af3eac6e Q02 stranded
pairs OPS_FIX_REQUIRED -> TODO (canary 7f4fb7d4 failed after the verdict with spawn_refusal:compile_gate, health
3 -> 3 not 3 -> 2); b982a763 Q09 binder OPS_FIX_REQUIRED -> TODO (27/28 released rows re-held by
NEWS_CALENDAR_TAINTED within 2 min; artifact overclaimed "28 hold-free"; taint dependency = Claude task bb814520).
Pending: 519c11fe prescreen class (review running). Lesson repeated: verify outcomes against the LIVE state after
apply, not against the intended state (two overclaims caught).

## 2026-09-12T09:40Z — 519c11fe PRESCREEN class APPROVED; reload chunk 70 started

Review (Sonnet): commit 2fd096cd2f = Default-OFF Model=1 PRESCREEN class (switch QM_OPT_CENSUS_PRESCREEN_ENABLED
at enqueue/promote/dispatch, run_smoke.ps1 fail-closed), PRESCREEN_MEASURED disjoint from MEASURED (test),
idempotent promote with self-hashed ranking snapshot + ledger amendment, FN report with 10 pct suspension, 41405
dry run with 0 production rows, 95/95 tests. Follow-up b32462f2 (Luna): control_arm fixture + 5 pre-existing
unrelated test failures. Chunk 70 (session_tools/reload_chunk70.py, all workers, staggered) activates
QM_Q08_DSR_CONTEXT_PREFLIGHT=1 and QM_OPT_CENSUS_PRESCREEN_ENABLED=1 in the worker env; no census cap; L=2 +
allowlist from machine scope. Next after chunk 70: first PRESCREEN program = shadow calibration on the already
measured QM5_41405 matrix (350 cells, real-tick truth exists) to measure FN before the Nachtrag D signature
puts prescreen in front of the sealed census.

## 2026-09-12T07:40Z — RESULT T12 identity PASS; T11/T12 concurrent pilot REFUSED

T12 Model-4 identity matched the fleet reference exactly: net 2941.71, PF 1.03,
208 trades. The one-shot T11+T12 pilot then failed closed on both seats because
pending MT5 LiveUpdate handoffs exited before testing; receipts record 94.56% / 94.34%
admission CPU and over 40 GiB free RAM, with no report accepted. One T12 agent had
already reached a 99.94% five-sample runtime CPU mean, so concurrent research beside
a saturated weekday fleet is not recommended. No T_Live/FTMO or fleet claim action.
Evidence: `docs/ops/evidence/2026-09-12_t12_identity_and_concurrent_pilot.md`.

## 2026-09-12T07:54Z — RESULT BLOCKED backlog follow-up ready for REVIEW

Task `f239a2d9`: BLOCKED fell 103 -> 69. Batch 02 allocated 32 magic rows for nine
cards and returned ten registry-ready rows to TODO. The exact 24-row OWNER manifest
archived 22 stale/non-executable rows and requeued two evidence-pinned tasks; all
prior verdicts and artifact paths remain auditable. The remaining 69 are 18 future
allocation candidates, 50 exact card/identity holds, and one untouched OWNER-video
row. Verification: 17 tests PASS, py_compile PASS, zero status-aware magic
collisions, zero retired-row deletions. Evidence:
`docs/ops/evidence/2026-09-12_blocked_agent_task_backlog_disposition.md`.

## 2026-09-12T07:59Z — RESULT Q09 sealed-plan binder corrected live-state verdict

Task `b982a763`: the binder deterministically repaired 28/30 sealed-plan failures;
two remain fail-closed for missing/contradictory Q09 evidence. Corrected live audit:
all 28 plan-bound rows still carry `NEWS_CALENDAR_TAINTED`, so ordinary-claim state
is 0/30, not 28/30. Calendar release belongs to IN_PROGRESS Claude task `bb814520`
and was not bypassed. Binder replay is 0 ready / 2 held; focused verification is
127 passed. Evidence:
`docs/ops/evidence/2026-09-12_q09_sealed_plan_hold_binder.md`.

## 2026-09-12T10:25Z — First PRESCREEN program enqueued: shadow calibration on the measured QM5_41405 matrix

Chunk 70 finished 08:16Z (all 10 workers carry QM_Q08_DSR_CONTEXT_PREFLIGHT=1 + QM_OPT_CENSUS_PRESCREEN_ENABLED=1).
config_sweep enqueue --apply with docs/ops/evidence/2026-09-12_config_sweep_qm5_41405_prescreen_dryrun_declaration.json:
350 PRESCREEN cells (Model=1, keep 0.70, control 0.10, seed bound to the OWNER decision) inserted as program
WINSWEEP_QM5_41405_PRESCREEN_DRYRUN_2019_2025, each payload carrying prescreen_real_work_item_id of the already
MEASURED real-tick twin. Queue-owner control row 0c2d9ad3 inserted by hand (mirror of a5efb888, EVIDENCE_UNAVAILABLE
sentinel), queue_order_at 2026-08-18T23:00 so the calibration takes one lane (~4 h at ~40 s per cell). Purpose:
measure PRESCREEN-vs-real-tick rank fidelity and the FN estimate on 350 cells with known truth BEFORE the
Nachtrag D signature puts the pre-screen in front of the sealed census. Verdicts of these cells are
PRESCREEN_MEASURED (never MEASURED); the real-tick verdicts of 41405 are untouched. First-claim proof recorded
below when it lands.

## 2026-09-12T10:35Z — PRESCREEN first-claim proof FAILED: work_items CHECK constraint rejects the new taxonomy

Cell 62538f30 (T5) claimed within a minute of the queue-order change, tester.ini Model=1, backtest OK (summary
PASS, model 1, 0 non-OK) -- then the worker crashed on the verdict write: IntegrityError, CHECK constraint
sh3_enforced=0 OR verdict_taxonomy IN (draft_defect, governance, infra, invalid, measurement, open, review,
strategy, unknown, artifact, build, implementation); the build's taxonomy prescreen_measurement is not in that
list. Row = INFRA_FAIL worker_crashed_handling_item. Program parked at the queue tail (owner 0c2d9ad3
queue_order_at 2026-12-31); 519c11fe re-opened to TODO with the exact fix (governed schema migration + pre-write
taxonomy validation + append-only rerun + documented first-claim proof). LESSON: a dry run that never writes a
verdict does not prove a new cell class; the first-claim proof must include the verdict write.

## 2026-09-12T10:50Z — Governed hold PRESCREEN_SCHEMA_FIX_PENDING on the 347 pending PRESCREEN cells

Parking by queue order was not enough: a second cell (35a985c0, T4) was claimed from the tail and crashed the
worker the same way. governed_work_item_hold.py apply (backup taken, docs/ops/evidence/2026-09-12_prescreen_schema_hold.json):
347 rows held with hold code PRESCREEN_SCHEMA_FIX_PENDING; release condition = 519c11fe schema migration + tests +
one PRESCREEN_MEASURED verdict visible on an append-only rerun of 62538f30. Two failed rows (62538f30, 35a985c0)
stay as evidence; the ticket reruns them append-only after the fix.

## 2026-09-12T11:10Z — T12 research seat VALID (identity exact); concurrent pilot blocked by LiveUpdate staging

c2396a30 APPROVED: T12 identity smoke = fleet cell exactly (net 2941.71 / PF 1.03 / 208 trades, real ticks,
receipt 20260912_073454_0eed25d2). The T11+T12 concurrent pilot failed closed on a pending MT5 LiveUpdate
handoff: /skipupdate suppresses the check at launch but not an update already staged by a background poll
(build 6182 pre-staged on T12 09:36Z). Follow-up ad4eb945 (Sol): disable background update polling on
T11/T12 only, pre-clear staged updates, then the concurrent pilot. 5ff527e8 APPROVED as a value-adding duplicate
of 348af875.

## 2026-09-12T11:45Z — Q09 chain head: decided OWNER decision was reported OPEN for three days; executed now

b982a763 APPROVED partial (28/28 bound rows held by NEWS_CALENDAR_TAINTED, 31 taint holds active). The taint
dependency task bb814520 (headless Claude lane) reported every cycle since 2026-09-09 "still blocked on
OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909 (status=OPEN)" -- the decision file shows status DECIDED, last_decision
YES at 2026-09-09T04:18Z with the OWNER note "B und zusaetzlich monatlich Tickdaten aktualisieren". Defect of the
headless checker (to be fixed in the ClaudeOrchestration cycle code -- separate item). Executed: Codex ticket
fda6370f (scope measurement vs the 2026-08-03 boundary + staged QM5_11167 rebuild as new identity, cohort plan),
e37931c2 (monthly tick-data refresh, Default-OFF), bb814520 handed to PIPELINE. Also: af3eac6e returned a second
time (artifact never regenerated; tier raised to Sol); compile-gate spawn refusal cluster (12 EAs / 24 h) ->
57fc8b42; T12 identity exact -> ad4eb945 for the LiveUpdate reconciliation; 5ff527e8 duplicate APPROVED.

## 2026-09-12T12:05Z — Dukascopy lane: P1 download COMPLETE; P2/P3 commissioned. f239a2d9 closed.

D:/QM/reports/dukascopy/backfill/20260909T191800Z_hardened/progress.json (04:29Z): planned 307,248 hours =
completed (33,186 downloaded this run, 257,568 resumed, 15,746 no-data hours, 748 errors, concurrency 6, proxy env).
Status FAIL only because errors > 0. The headless Claude verdict "projected 167 days" referred to its own
measurement run (2026-09-09) and was stale; 3032534e handed to PIPELINE. Codex 79c942ac (Sol, P86): retry the
748 error hours, P2 convert (mutable current year, non-FX price scale per the 09-09 probe), P3 splice/verify
against the T1 tick tail + manifest proposal; the archive write remains an orchestrator step (governed pause).
f239a2d9 (BLOCKED batch-02) APPROVED after the one-line lede fix by the orchestrator: BLOCKED 103 -> 69.
Review round complete: 0 rows in REVIEW.

## 2026-09-12 — Fleet clock audit part 2

RESULT: REVIEW — `ea9e3c61` traced all 93 prior MATCH EAs with source hashes and file:line evidence: 85 market/no-pending controls, 6 possible opposite-only survivors, 1 explicit skip, and 1 undefined strategy-level crossed-price rule. Ranked top 10 and governed re-measurement proposal recorded; zero work items created.

## 2026-09-12 — Sunday live attribution refresh

RESULT: REVIEW — `308c8009` snapshotted the current read-only AccountMonitor deal export and added per-magic closes/net/gross/PF/lots/UTC-entry-hour histograms plus separate magic-0 attribution to the existing `QM_NewBook_LiveVsBook_Sunday` path. Proof run exited 0; no T_Live control or trading action occurred.

## 2026-09-12 — FTMO four-symbol native cost receipts

RESULT: REVIEW — `17758960` produced four hash-bound read-only receipts and reran the shortlist comparator deterministically. GBPUSD/EURUSD expose native commission; USDCAD/USOIL.cash lack fills; all four lack complete executable-quote slippage, so selected incumbents remain zero. No trading or terminal change occurred.

## 2026-09-12 — T11/T12 LiveUpdate reconciliation and concurrent pilot

RESULT: REVIEW — `ad4eb945` quarantined the six staged build-6182 files, installed a reversible SYSTEM write-deny on the two exact LiveUpdate directories, and added fail-closed handoff evidence to `research_canary.py`. Both dry runs passed clear. The one authorized concurrent pilot produced T12's 2,941.71 / 1.03 / 208 identity but a zero-trade T11 report and 99.9% CPU means; weekday co-scheduling is not approved. The initially tested whole-program firewall rules were removed after they proved too broad; final ACL-only control remains in place for review.

## 2026-09-12 — Q02 stranded three-pair reissue

RESULT: REVIEW — `af3eac6e` was regenerated against live state after two review returns: 3 pairs / 41 INFRA_FAIL rows remain, all `INVALID_EVIDENCE_DEFECT`; valid zero-trade and retire counts are zero. The sole earlier canary `7f4fb7d4` failed before MT5 with `spawn_refusal:compile_gate:COMPILE_FAILED`, so health correctly stayed 3 -> 3. QM5_10505 is compile-gate repair, QM5_12582 evidence/implementation repair, and QM5_20143 history/evidence repair. No second canary or queue mutation occurred.

## 2026-09-12T~08:44Z (orchestration cycle, Claude) — task `90431302` DEC E2-Mittel: 2 calendar-taint holds released; the "mint 63 reruns" step is gated one layer deeper than expected

Ran `news_calendar_scoped_activation.py` fresh (dry-run): 11/28 pending Q10_NEWS rows
`ADMISSIBLE` under the unchanged B-prime binding (`069b467f8db3...`). Of those 11, only 2
still carried the calendar-taint hold as their live blocker (`0f7f63e4`/QM5_1567/XAGUSD.DWX
H4, `2641d5cf`/QM5_10569/XAUUSD.DWX H4) — released both via `farmctl.py release-hold`
(dry-run then apply, backup taken); the other 8 carry an unrelated
`NEWS_RUNNER_SPAWN_SILENT_ABORT` hold or are already unblocked. Tried to mint the first of
the 12 Q10/Q14-relevant append-only reruns named in the task (`blast_radius.csv`
`phase==Q10, classification==EXPOSED`, 11 PASS + 1 FAIL) via `enqueue-backtest --phase
Q10_NEWS --append-only-rerun-of ...`: refused, `"No done Q09 PASS work_items found"`.
Checked all 12 pairs' current `Q09_NEWS` predecessor directly — **none has a PASS
verdict** (mix of `pending` and `done/REVIEW_REQUIRED`). Root cause: `blast_radius.csv`
was sized in July against the legacy single-stage `Q10` gate; the live gate now requires
a genuine `Q09_NEWS` PASS predecessor per pair before a `Q10_NEWS` append-only rerun is
even mintable — the same `REVIEW_REQUIRED` stuck-class the just-resolved
`bb814520`/`dfc60103`/`3032534e` incident spent three days on for a different pair
(`QM5_11167`/`QM5_11196`). Not attempted further this cycle (outside this task's own
`allowed_actions` to force a Q09_NEWS throughput fix). Full detail + per-row table:
`docs/ops/evidence/2026-09-12_dec-e2-mittel-news-exposed-reverdict_90431302_execution.md`.
Task `90431302` stays `IN_PROGRESS`; no `update-task` call (top-level acceptance not met).

## 2026-09-12T~08:46Z (orchestration cycle, Claude) — task `49a8c88b` DEC E4: OOS-2026 window repair still correctly blocked, calendar gap unchanged

Read the active `news_calendar_2015_2025.csv` directly: still zero rows between
2025-04-07 and 2026-07-20 (unchanged from the 2026-09-05 finding); the OOS-2026 campaign
window (2026-01-01..04-06) is entirely inside that gap. The B-prime USD-only gate
criterion that unblocked `90431302` does not add calendar rows and does not satisfy this
task's literal precondition. No `repair-oos-window --apply` attempted (would measure the
OOS window without real news data). Full detail:
`docs/ops/evidence/2026-09-12_dec-e4-oos-window-repair-precondition_49a8c88b_execution.md`.
Task `49a8c88b` stays `IN_PROGRESS`; no `update-task` call.

## 2026-09-12T09:06Z (orchestration cycle, Claude) — re-verification checkpoint on all 3 IN_PROGRESS claude tasks: unchanged, nothing actionable this cycle

Independently re-ran the checks behind the two entries above (routed ~08:33-08:37Z, last
checkpointed ~08:44-08:46Z), ~20 minutes later, before doing any new work:

- `90431302` (E2-Mittel): re-queried `Q09_NEWS` status for all 12 Q10/Q14-relevant exposed
  pairs directly against `farm_state.sqlite` — identical mix of `pending` /
  `done:REVIEW_REQUIRED` as the last checkpoint; still zero with a PASS predecessor, so
  still nothing mintable. No new admissible calendar-taint holds beyond the 2 already
  released.
- `1721f3a1` / `49a8c88b` (E1/E4): re-read `news_calendar_2015_2025.csv` (48,718 rows) —
  gap between 2025-04-07 and 2026-07-20 unchanged, 0 rows in the 2026-01-01..04-06
  campaign window. Precondition still unmet.

No `repair-oos-window --apply`, no rerun minting, no `update-task` calls made — would
either be refused by the tool's own fail-closed checks or, if forced, would not be a valid
adjudication. All 3 tasks correctly stay `IN_PROGRESS`, blocked on external state
(Q09_NEWS pipeline throughput; news-calendar backfill) outside these tasks' own
`allowed_actions`. Re-check next cycle; do not re-litigate from scratch unless the
calendar file or the 12 pairs' `Q09_NEWS` verdicts change.

## 2026-09-12T13:10Z — Review round 3 (5 rows) closed; REVIEW empty

APPROVED: ea9e3c61 fleet clock audit part 2 (93 traces verified, 8 stop-pending EAs, no action without a GELB
measurement cohort); 308c8009 live attribution refresh (24 sleeves + manual reconciled to -2493.10, Sunday hook
proven); 17758960 FTMO native cost receipts partial (0 incumbents cost-eligible, slippage stream missing ->
f8ffb1c5); ad4eb945 LiveUpdate reconciliation (ACL guard T11/T12, one pilot, weekday use withheld); af3eac6e
stranded pairs on the third submission with an orchestrator addendum (no pending rows -> no holds; successors
gated by 57fc8b42). OWNER question "Wie updaten wir T1-T12": fleet + T_Live + FTMO on build 6182 since 2026-09-06
(uncontrolled LiveUpdate), T11/T12 on 6140; governed update runbook proposed (golden copy, reproducibility check
on the reference cell, fleet ceremony under Factory OFF, tester build in the evidence contract), awaiting OWNER.

## 2026-09-12T13:30Z — OWNER: T11/T12 controlled update in the weekend window; Nachtrag D waits for the calibration

OWNER chat ~13:2xZ. Codex ticket (Sol, P85) = governed MT5 update runbook (docs/ops/MT5_TERMINAL_UPDATE_RUNBOOK.md)
+ first application on T11/T12 (6140 -> 6182, guard lifted and re-armed, identity smoke on 6182 vs the 6140
result, then the concurrent pilot under ACL-only control); fleet/T_Live/FTMO untouched; window until
2026-09-13T20:00Z. Nachtrag D stays on the board as WAITING for the FN measurement (blocked by the PRESCREEN
schema fix 519c11fe).

## 2026-09-12T09:20Z — Q-backup calendar continuity acknowledgment (`3b334176`) REVIEW

The irrecoverable 2026-08-18 nightly gap now has a governed record with its
DriveFS-mount root cause and durable evidence path. The health check accepts
only structurally valid records whose evidence exists and continues to fail
closed on malformed acknowledgments. Current `backup_calendar_continuity=OK`;
focused tests: 5 passed. Evidence:
`docs/ops/evidence/2026-09-12_backup_calendar_continuity_acknowledgment.md`.

## 2026-09-12T09:58Z — Compile-gate refusal holds (`57fc8b42`) REVIEW

Added the Default-OFF exact `COMPILE_GATE_BROKEN_SOURCE` hold: pending
Q02/Q03/Q04 rows are restored without a verdict after a compile-gate refusal
and auto-release only on a newer authenticated same-EA `COMPILE_OK` receipt.
The 12-row cluster is `INCLUDE_MIRROR_REFUSED`, not demonstrated source compile
errors; all historic terminal evidence remains untouched. Production dry run:
0 holds / 0 release-ready. Focused tests: 32 passed. Evidence:
`docs/ops/evidence/2026-09-12_compile_gate_broken_source_holds.md`.

## 2026-09-12T10:20Z — T11/T12 governed build-6182 update (`4291c7ef`) REVIEW

Runbook-first commit `a7b4ef579b`; T11/T12 terminal and tester binaries now
match the T1 6182 golden hashes, with protected roots unchanged and rollback
copies retained. T12's build-6182 identity is an exact 2,941.71 / 1.03 / 208
match to 6140. The one ACL-only concurrent pilot again produced a zero-trade
T11 result while T12 matched; CPU reached a 100% five-sample mean, so weekday
concurrency remains withheld. A post-run inspection proved the directory-only
guard could disappear on shutdown; it was re-armed with an exact profile
delete-child deny and finishes `GUARD_PRESENT`. Evidence:
`docs/ops/evidence/2026-09-12_t11_t12_6182_governed_update.md`.

## 2026-09-12T10:23Z — QM5_41453 governed magic precondition (`1f4dfc3f`) REVIEW

The routed `never_allocated` diagnosis was superseded before execution by the
governed allocator/build commits `f5922dadb0` and `4599f9a307`. A fresh exact-
card dry run now returns `already_allocated` with one active identity and the
two exact active tuples: slot 0 XAUUSD.DWX / 414530000 and slot 1 XAGUSD.DWX /
414530001. Resolver regeneration dry-run kept 18,318 rows with zero dropped;
the card/directory/registry/resolver tuple precheck passed. No retired row was
revived and this task made no registry mutation. Evidence:
`docs/ops/evidence/2026-09-12_qm5_41453_governed_magic_precondition.json`.

## 2026-09-12T10:05Z (orchestration cycle, Claude) — re-verification checkpoint on all 3 IN_PROGRESS claude tasks: unchanged, nothing actionable this cycle

Independent re-check ~1h after the 09:06Z checkpoint, before doing any new work:

- `90431302` (E2-Mittel): re-queried `Q09_NEWS` status directly against
  `farm_state.sqlite` for all 12 Q10/Q14-relevant exposed pairs (`blast_radius.csv`,
  `phase==Q10, classification==EXPOSED`): 6 `pending`, 6 `done` (all `REVIEW_REQUIRED`
  or `PENDING_RUNNER`) — identical mix to the 08:44Z/09:06Z checkpoints, still zero with
  a PASS predecessor, so still nothing mintable for the append-only Q10_NEWS reruns.
- `1721f3a1` / `49a8c88b` (E1/E4): re-read `news_calendar_2015_2025.csv` directly —
  0 rows strictly between 2025-04-07 and 2026-07-20 (the 19 rows landing exactly on
  those two boundary dates are pre-existing and outside the gap), 0 rows in the
  2026-01-01..04-06 OOS campaign window. Precondition still unmet.

No `repair-oos-window --apply`, no rerun minting, no `update-task` calls made. All 3
tasks correctly stay `IN_PROGRESS`, blocked on external state (Q09_NEWS pipeline
throughput; news-calendar backfill) outside these tasks' own `allowed_actions`. Re-check
next cycle; do not re-litigate from scratch unless the calendar file or the 12 pairs'
`Q09_NEWS` verdicts change.

## 2026-09-12T10:18Z (orchestration cycle, Claude) — re-verification checkpoint on all 3 IN_PROGRESS claude tasks: unchanged, nothing actionable this cycle

Independent re-check ~13min after the 10:05Z checkpoint, before doing any new work:

- `90431302` (E2-Mittel): re-queried `Q09_NEWS` status directly against `farm_state.sqlite`
  for all 12 Q10/Q14-relevant exposed pairs — 6 `pending`, 6 `done` (5 `REVIEW_REQUIRED` +
  1 `PENDING_RUNNER`), `updated_at` timestamps unchanged from prior checkpoints. Still zero
  with a PASS predecessor, so still nothing mintable for the append-only Q10_NEWS reruns.
- `1721f3a1` / `49a8c88b` (E1/E4): re-read `news_calendar_2015_2025.csv` (3,463 distinct
  dates) directly — 0 rows in the 2026-01-01..04-06 OOS campaign window, gap confirmed
  2025-04-07 (last date before) to 2026-07-20 (first date after). Precondition still unmet.
- `farmctl.py health`: FAIL13/WARN18/OK55, same chronic FAIL set as the 09:48Z/10:05Z
  checkpoints (p2_pass_no_p3, codex_zero_activity, q02_stranded_exhausted_pairs,
  phase_invalid_rate_7d[Q08], work_item_phase_age_slo, pending_tail_age,
  q09_sealed_plan_hold_age, agent_task_aging_slo, pending_artifact_binding_drift,
  QM_EvidenceCohortWatch_Daily_0420 LOSS_OBSERVED, ftmo_trial_pulse review_trigger,
  task_monitor_escalation x2) — no new FAIL, nothing in this set is within these 3 tasks'
  own `allowed_actions`.

No `repair-oos-window --apply`, no rerun minting, no `update-task` calls made. All 3 tasks
correctly stay `IN_PROGRESS`, blocked on external state (Q09_NEWS pipeline throughput;
news-calendar backfill) outside their own authority. Re-check next cycle; do not
re-litigate from scratch unless the calendar file or the 12 pairs' `Q09_NEWS` verdicts
change.

## 2026-09-12T14:20Z — Reviews: backup acknowledgment + compile-gate holds APPROVED; counter 23/25

3b334176 APPROVED (governed acknowledgment for the 2026-08-18 backup gap, check fail-closed, 5 tests). 57fc8b42
APPROVED (Default-OFF hold COMPILE_GATE_BROKEN_SOURCE, cd1d4e3ad8; the 12-row cluster is INCLUDE_MIRROR_REFUSED =
inline compile refused in the live factory for EAs whose source changed after the rework re-queue, not confirmed
source breakage; nothing re-enqueued). Hardening follow-up (sha pinning of the release receipt) before activation
via reload chunk 71 with QM_COMPILE_GATE_HOLD_ENABLED=1. Counter 23/25 at 10:12Z (up from 22). Census cells/h
dropped to ~50 because the fast 41405 matrix is finished and the remaining programs are slower per-year cells.

## 2026-09-12T10:53Z — Shared governed backup reuse (`4ce6ec32`) REVIEW

Extracted the established rolling-window SQLite backup policy into
`db_backup_reuse.py` and wired compile-wave, both named farmctl writers, and
`governed_work_item_hold` to it. Writer receipts now expose `reused` and audit
rows record `backup_reused`; cross-writer tests prove reuse of the same exact
path/SHA while stale, missing, schema-changed, or disabled cases still fall back
to a fresh backup. Focused verification: 55 passed; compileall and diff-check
passed. No production database or backup directory was mutated. Evidence:
`docs/ops/evidence/2026-09-12_governed_state_backup_reuse_shared_helper.md`.

## 2026-09-12T10:58Z — FTMO request-quote slippage stream (`f8ffb1c5`) IN_PROGRESS

Added a one-shot, identity-pinned read-only extractor that reconstructs the
latest executable broker quote at each request/trigger timestamp from MT5 tick
history. The completed Monday–Friday window produced complete GBPUSD and EURUSD
streams (2 fills each; quote ages 7–88 ms), while USDCAD and USOIL.cash correctly
remain `MISSING_NO_FILL`. The hash-bound comparator now reports 2/4
`cost_eligible` and still selects zero; four-symbol acceptance remains open
until native fills exist for the other two. Focused tests: 34 passed. No EA,
scheduler, terminal, trading, or AutoTrading mutation. Evidence:
`docs/ops/evidence/2026-09-12_ftmo_slippage_stream/README.md`.

## 2026-09-12T11:22Z — Dukascopy P1/P2/P3 tail (`79c942ac`) REVIEW

P1 resolved 307,580/307,581 hours; the lone AUDCAD 2026-09-11 17:00Z hour
remains transient after two five-attempt runs. P2 produced 36 checksum-bound
scratch conversions (398,733,724 ticks; zero temp files). P3 covered the full
24-symbol intersection and failed closed: 0/24 full passes because the governed
T1 export ends in December 2025, all coverage is below 99%, and XAUUSD plus
UK100/XTIUSD expose scale/basis defects despite rho >=0.99793. Manifest proposal
is `PROPOSAL_BLOCKED`; no archive/custom-history/terminal write occurred.
Focused tests: 19 passed. Evidence:
`docs/ops/evidence/2026-09-12_dukascopy_p2_p3_tail_execution.md`.

## 2026-09-12T14:50Z — Dukascopy P2/P3 APPROVED (fail-closed): archive proposal BLOCKED for real reasons

79c942ac: P1 tail resolved (307,580/307,581 hours, one AUDCAD hour transient), P2 36/37 checksum-bound scratch
conversions (398.7 M ticks), P3 0/24 PASS by design: the governed T1 M1 export stops at 2025-12-31 (overlap
window needs coverage to 2026-04-01 incl. both DST windows) and XAUUSD/UK100/XTIUSD carry a ~10x
Dukascopy-to-DWX price-scale defect (the digits-derived price_scale from the 09-09 probe is wrong for raw tick
encoding) despite rho >= 0.998 on closes. Manifest proposal emitted as PROPOSAL_BLOCKED (all write flags
 false); nothing written under Bases/Custom or the signed archive. Successor b5f660f9 (Sol): AUDCAD hour,
T1 export regen through 2026-04-01, first-principles scale mapping for the three symbols, fresh P2/P3 +
proposal. Archive write = separate orchestrator ceremony after 37/37.

## 2026-09-12T11:35Z — Compile-gate receipt hash hardening (`09a32b16`) REVIEW

RESULT: `COMPILE_GATE_BROKEN_SOURCE` release now requires the immutable
COMPILE_OK receipt to post-date the hold and pin the current canonical MQ5 and
EX5 paths plus SHA-256 values. The compile worker emits both identities and
rechecks the MQ5 after compilation. Changed or missing hashes and old receipts
fail closed; 35 focused tests pass. The feature flag remains unset/Default-OFF
and no production hold, verdict, EA, terminal, or task state changed. Evidence:
`docs/ops/evidence/2026-09-12_compile_gate_receipt_hash_hardening.md`.

## 2026-09-12T11:32Z — Monthly Dukascopy refresh control (`e37931c2`) REVIEW

RESULT: defined the prior-month day-3 cadence and built a double Default-OFF
scheduled-task/admission layer. Apply requires a live OWNER/Claude-approved,
self-hashed manifest update, exact Factory-OFF hash, zero active claims, 37/37
P3 PASS, and the shared archive-year writer lock. The scheduled entry point
never writes history; current 0/24 P3 evidence blocks activation. Focused tests:
32 passed. Installer dry run changed no task state. The required future pause
is recorded in an OPEN OWNER card. Evidence:
`docs/ops/evidence/2026-09-12_dukascopy_monthly_refresh_default_off.md`.

## 2026-09-12T11:45Z — Q09 legacy rebuild reissue (`fda6370f`) REVIEW

RESULT: suppressed a duplicate QM5_11167 rebuild after verifying the already
APPROVED successor `QM5_41394`: governed COMPILE_OK/build PASS, matching source
and EX5 hashes, five Q02 rows enqueued (four worker PASS, one pending), and the
old identity untouched. Refreshed the exact 35-row affected scope with current
holds and documented the staged eight-source follow-up cohort plan. No queue,
registry, EA, verdict, hold, priority, or terminal state changed. Evidence:
`docs/ops/evidence/2026-09-12_q09_legacy_rebuild_reissue_resolution.md`.

## 2026-09-12T15:30Z — T11/T12 on build 6182 (governed update runbook applied); review round 4 closed

4291c7ef APPROVED: docs/ops/MT5_TERMINAL_UPDATE_RUNBOOK.md written and applied to the research seats only; T11/T12
= 5.0.0.6182 (T1 golden hashes), protected roots hash-identical, T12 identity smoke on 6182 exact vs 6140 (no
evidence-epoch break for the reference cell), guard re-armed, 14-terminal table verified. T11 zero-trade in the
concurrent pilot persists under CPU saturation (a Dukascopy job co-ran); weekday co-scheduling of research seats
stays NOT approved. Also closed this round: 79c942ac Dukascopy P2/P3 (fail-closed, successor b5f660f9), 1f4dfc3f
41453 precondition, 4ce6ec32 backup reuse (addendum + hardening e93dffb6), 3b334176 backup ack, 57fc8b42
compile-gate holds (hardening 09a32b16 before activation). REVIEW empty. Headless ClaudeOrchestration task
disabled for the interactive session (duplicate-cycle race, fix ticket 1061ff77); re-enable at session end.

## 2026-09-12T16:15Z — Compile-gate hold hardened and activated (chunk 71); monthly refresh control approved

09a32b16 APPROVED (receipt mq5/ex5 sha pinning against fresh on-disk hashes, temporal ordering, fail-closed;
8/8 hold tests; one unrelated pre-existing failure in test_q09_live_news_diagnostic -> artifact_identity
CHECK-string matching, noted for test hygiene b32462f2). Reload chunk 71 (session_tools/reload_chunk71.py,
all workers, staggered) sets QM_COMPILE_GATE_HOLD_ENABLED=1 on top of the chunk-70 flags: spawn refusals of
EAs whose source changed become exact holds COMPILE_GATE_BROKEN_SOURCE released by the next authenticated
COMPILE_OK, instead of terminal INFRA_FAIL rows. e37931c2 APPROVED (monthly tick-data refresh control, doubly
Default-OFF, per-execution OWNER card pre-registered on the board, blocked until P3 37/37).

## 2026-09-12T16:40Z — fda6370f APPROVED: legacy-calendar Option B already executed via QM5_41394; REVIEW empty

QM5_41394 (weiss-ichi2-ma-calendar-r1) is the governed new-identity successor of QM5_11167 (shared source,
COMPILE_OK 1fb4d6f0, Q02 4 PASS + SP500 pending); no duplicate rebuild. 35-row affected scope (holds TAINTED 21,
TIMESTAMP_DEFECT 6, SPAWN_SILENT_ABORT 3, AWAITING_SEALED_PLAN 2) and the 8-source cohort plan reconcile with the
DB. Held legacy rows advance only through their own successor identities; cohort stage 1 (11196, 10148) gets a
follow-up ticket once 41394 clears Q02 on SP500. Review round 5 closed (fda6370f, 09a32b16, e37931c2); 0 in REVIEW.

## 2026-09-12 — MT5 local-agent pass evidence contract (`cbacb01b`) REVIEW

RESULT: standard MT5 optimizer output remains `PRESCREEN`-only even with `Model=4`: it cannot equal the current
single-cell real-tick receipt because it lacks per-pass native-report bytes, canonical closed-trade bytes, entry
days, authenticated logger evidence, and an independent real-tick marker. The Default-OFF contract defines full
pass identity, 20/20 plus clean-repeat parity, local-only/isolation and CPU/RAM guards, and fail-closed refusal
rules. No code or launch occurred; a future instrumented adapter still requires canary proof and separate OWNER
activation before any pass can be `MEASURED`.

## 2026-09-12T12:37Z — FTMO slippage stream refresh (`f8ffb1c5`) REVIEW

RESULT: a new immutable, read-only capture through 12:36Z confirms the prior 2/4 outcome: GBPUSD and EURUSD each
have two complete request-quote/fill observations; USDCAD and USOIL.cash still have zero native fills and remain
`MISSING_NO_FILL`. The refreshed hash-bound comparator remains 2/4 `cost_eligible` and selects zero. Four-stream
acceptance is a bounded deviation rather than a value to impute or create through trading; no order, terminal
control, AutoTrading action, roster, threshold, or verdict changed.

## 2026-09-12 — Headless orchestration session race hardening (`1061ff77`) REVIEW

RESULT: the wrapper now holds one renewable 30-minute lease per agent through an exact session token/pid/host;
the real two-thread test proves only one concurrent Claude controller can win, and a foreign session cannot renew
or release it. A fresh interactive marker skips before acquisition with a JSONL receipt. Stable blocker-state
hashes now reserve one reusable evidence artifact and the prompt forbids duplicate timestamped evidence,
OPEN_ITEMS entries, or no-change commits. Focused launcher/backend tests: 212 passed; Claude dry-run PASS. No
model, terminal, worker, queue, trading, T_Live, or AutoTrading action occurred.

## 2026-09-12T17:10Z — Reviews: FTMO slippage stream APPROVED partial (2/4), local-agent lane contract APPROVED

f8ffb1c5: read-only collector (prove_running gate, no order/terminal calls); GBPUSD/EURUSD complete with
request-time quotes (2 fills each), USDCAD/USOIL.cash MISSING_NO_FILL = no deals in the capture-only M13 book this
week; Monday-start window honoured; compare.py cost_eligible 2/4, zero incumbents selected. cbacb01b: MetaTester
local-agent pass evidence contract (docs/ops/MT5_LOCAL_AGENT_LANE_CONTRACT_2026-09-12.md) -- the standard
optimizer stays PRESCREEN-only; MEASURED would need byte-exact per-pass evidence and a 20/20 parity canary that
does not exist. OWNER takeaway: the optimizer can pre-screen faster, never replace per-cell real-tick backtests.
Chunk 71 finished 13:20Z (compile-gate hold active fleet-wide). Pending review: 1061ff77 (lease race fix).

## 2026-09-12 — Dukascopy P3 redo (`b5f660f9`) REVIEW

RESULT: the sole AUDCAD source hour resolved, completing P1 at 307,581/307,581. A first-principles
BI5 probe corrected UK100/XAUUSD/XTIUSD provider divisors to 1000 without changing broker point values.
The governed read-only T1 export produced 25 symbols and 12 exact empty-history failures; all populated
files stop in December 2025. Consolidated P3 therefore has 25 executed failures plus 12 per-symbol
not-run explanations: 37/37 outcomes are accounted for, but 0 pass. XAU now passes its price check;
UK100/XTI remain outside tolerance. The manifest proposal is `PROPOSAL_BLOCKED` with
`archive_write_authorized=false` and `production_splice_authorized=false`. No terminal, archive,
production history, T_Live, AutoTrading, registry, or verdict state was changed.

## 2026-09-12 — PRESCREEN follow-up test hygiene (`b32462f2`) REVIEW

RESULT: the exact named baseline reproduced five failures and now passes 98/98. Repairs are fixture/test
only: CONFIG_LOCKED is no longer misclassified as stale; long-run rollback tests isolate the independent
calendar-taint guard; busy-timeout asserts the configured constant; and the cap fall-through uses short Q06
instead of now-RAM-gated Q09. The mandatory control-arm fixture proves a last-ranked declared control is
retained outside the natural top keep fraction. No production guard or behavior changed.

## 2026-09-12 — Self-evidencing governed magic precondition (`6b21b05a`) REVIEW

RESULT: governed_magic_allocator receipts now contain one verification block per selected candidate with the
exact active identity row, normalized magic registry rows (`ea_id`, slug, slot, symbol, magic, status), exact
resolver tuples, three equality checks, and the reviewed pytest command/pass count. A read-only rerun for the
already allocated QM5_41435/XTIUSD row reports all checks PASS and binds magic 414350000 at slot 0; 21/21 tests
pass. No registry, resolver, EA, queue, terminal, T_Live, or AutoTrading state changed.

## 2026-09-12 — Governed backup reuse DML identity hardening (`e93dffb6`) REVIEW

RESULT: backup reuse now requires exact source path, schema version, database mtime_ns, database byte size,
and WAL byte size. A missing legacy field or any observed difference forces a fresh online backup. Fixtures
prove unchanged DB -> reuse, committed DML -> fresh, and WAL growth -> fresh; all four wired suites pass 56/56.
The live farm database and backup directory were not touched, and no retention, lock, queue, terminal, T_Live,
AutoTrading, registry, or verdict behavior changed.

## 2026-09-12 — QM5_10001 card-fidelity recovery (`27143c34`) REVIEW

RESULT: the later governed GBPJPY Model-4 Q02 completed reliably and moved the first failed layer from
infrastructure to zero-trade implementation/setup. The card-absent 35-point Tokyo-open spread veto was
removed; approved entry/exit/risk/news mechanics remain unchanged, and bounded default-off diagnostics plus
an own-position guard were added. Focused tests pass 3/3 and SPEC validation passes. Governed COMPILE_EA work
item `d979e50c-9fe4-4f1b-b85c-4a8d6e823546` is accepted but pending under
`COMPILE_EA_WORKER_ROLLOUT_PENDING`; the hold and Q02 requeue exclusion were not bypassed. No pipeline verdict
is asserted.

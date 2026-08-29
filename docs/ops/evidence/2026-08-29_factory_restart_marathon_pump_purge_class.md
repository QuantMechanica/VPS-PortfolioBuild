# Factory-Restart-Marathon 28./29.08.2026 — Pump/Purge-Klasse (R2–R5)

Restart-Fenster OWNER-genehmigt für 28.08 18:00; ausgeführt ab 20:55 (Session-Kompaktierung
riss den 18:00-Plan ab — Orchestrator-Fehler, dokumentiert). Vier ON-Anläufe bis Erfolg;
jede Runde fand eine eigenständige, vorher unsichtbare Ursache. Faktenlage aus
TaskScheduler-Eventlog, Worker-Logs, Pump-Logs, farm_state.

## Ausgangsbefund („nur noch 1 MT5")

7 von 9 aktiven Claims waren Deferred-Finish-Leichen: `summary.json` fertig
(02:45–15:44), finaler SQLite-Write in Fleet-Contention verloren; Resident-Worker
verweigerten seither jeden Claim als `terminal_worker_busy`. Reconcile-Fix (329d1cdfe
bereits committet) lädt nur bei Worker-Neustart → Restart war der Fix.

## Kette der Anläufe

| Runde | Ergebnis | Ursache (bewiesen) | Gegenmaßnahme |
|---|---|---|---|
| R1 (21:00) | fail-closed vor Start | Disk-Headroom 114,7 < 120 GB (floor((frei−40)/8) ≥ 10 Worker) | 212 alte farm_state-Snapshots (13,4 GB) nach C: verschoben → 128 GB |
| R2 (21:12–22:12) | Gate-Timeout 3600 s, starved=Pump | Pump hatte seit **26.08 00:37 keinen vollständigen Lauf**: 89 Agent-Worktrees unter C:\QM\worktrees blähten das Kill-Safety-Audit auf 10–22 min; 30-min-ExecutionTimeLimit killte jeden Lauf (0x41306). Health-Check meldete das 3 Tage lang als „busy"=OK | Worktree-Prune 89→51 (nur clean+unbenutzt, Census+Log unter D:\QM\reports\maintenance\worktree_*_20260828.*); Pump-Limit PT30M→PT1H |
| R3 (22:40–23:40) | Gate-Timeout, Pump `Disabled` + Worker „not visible" | `tester_cache_purge` (10-min-SYSTEM-Task) macht bei D:<150 GB **unbedingten Factory-Teardown** (Stop+Disable Pump/Tick, Worker-Kill, dann Restore) — feuerte alle 10 min ins Gate; Eventlog: Pump-Disable 23:40:09, Gate-Deadline 23:40:26 | Ceremony-Guard in tester_cache_purge.ps1 (Skip bei FACTORY_ON_CEREMONY_INCOMPLETE.json), live getestet, Commit dcc75e46c |
| R4-Mint (23:53) | Mint-PRECONDITION dirty tree | 5 Codex-REVIEW_REWORK-Builds (36003/37003/38004/39003/40005/41003) schrieben ins kanonische Repo weiter, obwohl ihre tasks-Zeilen seit 23:08 `blocked`/`pending` waren (verwaiste Prozesse im OFF-Fenster) | Prozesse ausgelaufen; Dirt als Patch archiviert (D:\QM\reports\maintenance\rework_build_dirt_20260828T2156Z.patch), Tree restauriert, 37003-EX5 quarantäniert |
| R4 (23:58–00:58) | Gate-Timeout, Pump `Running` nie fertig | Struktur-Defekt: ON hält den FACTORY_MUTATION-Lock bis nach dem Gate; `farmctl pump` verbringt das Gate in Lock/SQLite-Retry-Sleeps (54 min Wall, 17 s CPU) — mit PT1H lief EIN Lauf das ganze Gate ohne Abschluss | Pump-Ceremony-No-op in run_pump_task.py (Spiegel des FACTORY_OFF-No-ops; unit-getestet beide Zweige), Commit 4e6e2332b |
| **R5 (01:03)** | **exit 0 — FACTORY STARTED 10/10, Session 3** | — | Decision RESTART_20260828_TOPDOWN_R5 konsumiert (e7332e6a8) |

## Nachgang (Normalbetrieb)

- Pump-Result 01:08 wieder 0x41306 → Alltagsmechanismus identifiziert: Purge-Teardown
  feuert bei D:<150 auch im Normalbetrieb alle 10 min → **darum** starb der Pump seit dem
  26.08 (D: fiel damals unter 150). Interim: weitere Relokationen nach C:
  (Karten-Backups 23.08, Retention-Quarantäne, MT5-/Farm-Logs >3d/7d; 458 Dateien) → 145,4 GB;
  Purge-Task-Parameter `-LowWaterGB 140` (dokumentiert; selbststabilisierend: über Schwelle
  No-op, Unterschreiten durch Cache-Regrowth → ein Purge-Lauf hebt wieder über Schwelle;
  Cold-Start-Marge ≥120 GB bleibt). Rollback auf 150 nach Codex-P0-Fix.
- Top-Down-Selector live (`QM_TOPDOWN_GATE_PRIORITY_ENABLED=1` Machine): erste Claims nach
  Restart ausschließlich OPT_CENSUS-Zellen (41097/USDJPY, 41161/GBPUSD), kein Q02/Q03.
- Alle 9 Stale-Claims geräumt; Worker-Declines nur noch `claim_spacing_wait` /
  kurzzeitig `factory_mutation_lock_busy` (laufender Pump-Backlog-Drain) — designkonform.

## Offene Dauerfixes (Router-Tickets)

- **f7a6975d (P90, high)**: Health-CRITICAL bei wiederholtem 0x41306; Purge-Teardown nur bei
  echtem Purge-Bedarf; Worktree-Janitor für C:\QM\worktrees; Audit-Caching je (Root, HEAD);
  Blocked-Rows müssen Prozessbäume terminieren; Pump-Limit-Entscheid (PT1H temporär).
- **57ab1771 (P70, medium)**: 6 quarantänierte EX5s (41164/41165/41166/41168/41172/41191)
  über den gebundenen Compile-Pfad (BUILD_TASK_BINDING) neu bauen; Standalone-enqueue-compile
  refused korrekt.

## Nachtrag Vormittags-Audit 29.08 (07:45–09:00) — Contention-Klasse

Volles Audit auf OWNER-Anweisung. Befunde (alle gemessen, alle adressiert):

1. **64/65 Pump-Läufe 02:00–07:40 crashten `database is locked`** — Write-Lock-Duty
   50–60 % (BEGIN-IMMEDIATE-Probe 15/30 bzw. 9/15 Fehlschläge), WAL wuchs auf 45 MB
   (nach TRUNCATE binnen 15 min wieder 41 MB). Dominanter Schreiber per
   WriteTransferCount-Delta: **`farmctl pump-maintenance` ea_metrics-Bulk-Rebuild**
   (21,8 MB/12 s über ≥30 min, stündlich). Interim: Trigger 1h→4h; init_db in
   retry_sqlite_busy eingehängt + Fenster verbreitert (79a9e384d, 011b25db2).
   Struktursanierung: Ticket 34858637 (P92).
2. **OPT_CENSUS-Zell-Runner T3/T5 starben ~02:00** (letzte Zellen 23:20Z/23:57Z, dann
   0 Zellen/2 h bei ~58 % Kern CPU-Spin der Resident-Worker). Claims blieben aktiv, weil
   die Claim-PID der lebende Resident-Worker ist, nicht der tote Runner
   (Worker/Runner-Konflation). Freigabe per gezieltem Worker-Restart (Design-Pfad);
   beide Zeilen re-claimt. Klasse in Ticket 34858637 (Punkte 3+4).
3. **`public_snapshot` hielt den FACTORY_MUTATION-Lock 45 min** (08:07–08:52, per
   psutil-Handle-Scan bewiesen; Owner-JSON pid 36464) — alle Worker-Claims declined,
   News-Refresh scheiterte (`stale_reap=unreadable`). Prozesse nach Identitätsprüfung
   beendet, Lock frei. Klasse: Ticket c5ee7b2c (P85, Laufzeit-Bound + Lock-Hygiene +
   Health-Check auf Langhalter).
4. **News-Kalender 1 Tag stale** (05:30-Lauf an Punkt 3 gescheitert); Refresh nach
   Lock-Freigabe erneut fällig.
5. Reviews 5/5 abgenommen (Fanout-Verifikation): f7a6975d APPROVED (Pump-Dauerfixe
   geliefert, Purge-Preflight + Worktree-Janitor `QM_StrategyFarm_WorktreeJanitor_6h`
   live), f775b87f APPROVED (MC-Null-Kacheln: Allowlist-Scope-Bug, Kacheln==DB
   verifiziert), 57ab1771 APPROVED-as-refusal (+ Folgeauftrag e173b7a8),
   000bb713 APPROVED (41192-Q02-Receipt), 25d7265a zurück IN_PROGRESS.
6. Health-Triage kommissioniert: 08f928e7 (17 Q10_NEWS-Sealed-Plan-Holds, P85),
   e4107fb6 (55 Binding-Drifts nach Sweep, P80), d1a5e5aa (34 Q02-Stranded, P60),
   d37d9ae4 (6 gebaute EAs ohne Q02, P55).

## Temporäre Abweichungen (Rollback-Pflicht)

1. Pump-Task ExecutionTimeLimit PT30M→**PT1H** (bis Audit-Caching geliefert).
2. TesterCachePurge `-LowWaterGB 150→**140**` (bis Teardown-Fix geliefert; Preflight-Fix 90fff7bd6 seit 29.08 live).
2b. PumpMaintenance-Trigger **1h→4h** (bis inkrementeller Metrics-Build, Ticket 34858637).
3. Quarantäne D:\QM\strategy_farm\state\quarantine_ex5_20260828_restart (Löschen nach
   governed Recompile).
4. Relokationen unter C:\QM\backups_relocated\ (verlustfrei, rückholbar).

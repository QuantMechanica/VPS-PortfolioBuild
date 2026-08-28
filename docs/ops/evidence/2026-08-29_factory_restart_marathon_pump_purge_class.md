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

## Temporäre Abweichungen (Rollback-Pflicht)

1. Pump-Task ExecutionTimeLimit PT30M→**PT1H** (bis Audit-Caching geliefert).
2. TesterCachePurge `-LowWaterGB 150→**140**` (bis Teardown-Fix geliefert).
3. Quarantäne D:\QM\strategy_farm\state\quarantine_ex5_20260828_restart (Löschen nach
   governed Recompile).
4. Relokationen unter C:\QM\backups_relocated\ (verlustfrei, rückholbar).

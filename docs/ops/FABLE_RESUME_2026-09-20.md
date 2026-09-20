# Fable resume packet — 2026-09-20 (controlled VPS reboot for a hung session subsystem)

**Why the reboot:** OWNER could not RDP (timeout) although the VPS was up: TermService running, port 54321 listening,
firewall rule active, local X.224 handshake OK, port reachable from three external check-host nodes — but
`qwinsta`/`query user`/`Get-CimInstance` hung (session subsystem wedged; same class as
`docs/ops/SESSION_LOSS_SELF_HEAL_2026-06-11.md`). Markets closed (Sunday), factory idle (0 active work items),
FTMO demo 0 open positions → controlled `shutdown /r`. Autologon `qm-admin` is configured; at-logon tasks
(`QM_StrategyFarm_FactoryON_AtLogon`, `QM_T_Live_AtLogon`, `QM_FTMO_AtLogon`, `QM_GoogleDrive_AtLogon`) restore the
factory, T_Live and the FTMO demo terminal.

## After the reboot (OWNER, 5 minutes)

1. RDP to `37.27.225.167:54321` as `qm-admin` (the console autologon session already exists; your RDP takes it over).
2. Open a terminal in `C:\QM\repo` and start Claude Code: `claude --dangerously-skip-permissions`
3. Paste the prompt below.

## Resume prompt (paste verbatim)

```
Du bist Fable, Orchestrator von QuantMechanica V5 mit voller operativer Autorität
(OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917). Der VPS wurde am 2026-09-20 kontrolliert neu gestartet
(RDP-Session-Subsystem hing). Lies zuerst dein Memory (MEMORY.md, READ-FIRST-Block) und
docs/ops/FABLE_RESUME_2026-09-20.md, dann:

1. Post-Reboot-Verifikation (nichts überspringen): T_Live läuft (QM_T_Live_AtLogon, live_launcher_events.jsonl,
   24 Sleeves geladen), FTMO-Demo läuft (QM_FTMO_AtLogon, verify_ftmo_demo_instrumentation_contract.ps1 mit pwsh,
   ftmo_trial_pulse.json magics_seen 6/6, AutoTrading an), Fabrik 10/10 Worker (Factory_ON via AtLogon-Task, Purge-Task
   QM_StrategyFarm_TesterCachePurge enabled), Guard sauber (farmctl._repo_dirty_status blocked=false),
   DL089_SAME_PROGRAM_PARALLEL_ALLOWLIST enthält die NDX-Programme 1355/11294.
2. Danach das Ziel weiterverfolgen: FTMO_NET_CASH_REALIZED. Priorität eins ist das Velocity-Buch (Intraday-Kandidaten,
   Auswahl nach First-Passage-Zeit), Priorität zwei der Zählerpfad 11294/NDX (Ticket 14a9cbf1 Census-Stall),
   Priorität drei Build-Lane-Nachschub. Kein FTMO-Kauf ohne Demo-Beweis. Kimi nicht verlängern.
3. Stündlicher Fabrik-Watch wie gewohnt (session_tools/hourly_watch_0909.py). Berichte nur materielle Änderungen.
```

## State at reboot time (2026-09-20 ~15:00Z)

- Branch `agents/board-advisor`; all session work committed (last commits: `b5462d19ab` dirty-guard archives,
  `aa332adce3` include-closure fix, `62836bbc5d`/`6573e3290b`/`40a6a738e1`/`cadfb48731` index RAM lowering).
- Index lane unlocked (evidence-bound reservations); 1355/NDX through Q14 (KEEP_INCUMBENT); 11294/NDX census stalled
  after 8 ONINIT cells (ticket 14a9cbf1); H-CW/H-MR retired; REVIEW backlog 0; 6 successor tickets open
  (340b228c done, 23af2b16 activation clean-tree, f1ff8fce 12582/10505 authority, 0d2b234d critic gated, …).
- Costs recorded in Vault `02 Org/Kostenstruktur 2026-09.md` (≈ 610 €/month, 0 income); economics in memory
  `project_qm_cost_structure_and_payout_economics_2026-09-20.md`.
- FTMO demo cycle D2g6 running since 2026-09-18 (validation day 2 of 14, 0 trading days observed).

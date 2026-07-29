# MNT-Implementierungsstatus 2026-07-29

> **Snapshot:** 2026-07-29T12:57:00Z · Branch
> `agents/mnt-20260729-implementation` · Basis-HEAD
> `e06c68f8285618aa8dfbba8ddd0037c0515f9f74`

Die konvergierten Lösungsverträge in
[`MNT_CONVERGENCE_LEDGER.md`](MNT_CONVERGENCE_LEDGER.md) sind nicht mit einer
Implementierung oder Runtime-Abnahme gleichzusetzen. Diese Matrix trennt
Source, Runtime und offene Akzeptanz. Insbesondere behauptet sie **keine**
Vollständigkeit der P0-/P1-Wartung.

Factory ist auf ausdrückliche OWNER-Absicht weiterhin OFF. Es gab keinen
Factory-Neustart und keinen Canary. Der bestehende T_Live-Terminal, die
T_Live-Aufgaben und AutoTrading wurden nicht verändert.

## Statussemantik

| Status | Bedeutung |
|---|---|
| `COMPLETED_RUNTIME` | Der auf der Seite eng definierte Runtime-Scope wurde mit dauerhafter Evidenz abgeschlossen; das schließt keine abhängigen Tickets. |
| `SOURCE_IMPLEMENTED` | Source und fokussierte Regressionstests sind vorhanden; Deploy, Betriebsbeobachtung oder fachliche Reruns können noch fehlen. |
| `RUNTIME_DEFERRED` | Tooling/Plan ist vorbereitet, die vorgesehene Runtime-Ausführung wurde bewusst noch nicht vorgenommen. |
| `PARTIAL` | Ein materieller Teil ist umgesetzt, mindestens ein ebenso materieller Teil oder Akzeptanznachweis fehlt. |
| `CONTRACT_ONLY` | Lösungsweg/Akzeptanz sind konvergiert, aber keine substanzielle Umsetzung liegt vor. |
| `NOT_IMPLEMENTED` | Der konkrete Defekt ist im aktuellen Stand nicht implementiert; vorhandene allgemeine Mechanismen genügen seiner Akzeptanz nicht. |

## Matrix MNT-001 bis MNT-053

| ID | Prio | Status | Geliefert | Offen / nächster harter Nachweis |
|---|---:|---|---|---|
| MNT-001 | P0 | `PARTIAL` | KS-Dual-Directory-Checks, Loader-/Health-Sicht und Tests implementiert. | 54 divergierende Paare OWNER-gebunden reconciliieren und 24/24 Live-Sleeves mit geladenem, hashgebundenem Baseline-Status belegen. [Seite](mnt_page_updates_2026-07-28/MNT-001.md) |
| MNT-002 | P0 | `PARTIAL` | Supervisor-Root-Cause, Source-/Task-Contract-Korrektur und Tests vorhanden. | Taskpaket anwenden und echten Heartbeat/Restart-Vertrag in der Console-Session beweisen. [Seite](mnt_page_updates_2026-07-28/MNT-002.md) |
| MNT-003 | P0 | `RUNTIME_DEFERRED` | Acht-Task-Paket, PLAN/WhatIf/Apply/Rollback und Tests vorbereitet. | OWNER-gesteuertes Apply; `0x800710E0`-Klasse und LogonType=Interactive danach live verifizieren. [Paket](../../tools/ops/task_contract_fix_2026-07-28/README.md) |
| MNT-004 | P0 | `SOURCE_IMPLEMENTED` | Park-/Maintenance-/Expiry-Zustandsvertrag, Watchdog-/Pulse-Änderungen und Tests vorhanden. | Deploy nach MNT-003 und Runtime-Nachweis ohne Relaunch-/Alarmloop. [Seite](mnt_page_updates_2026-07-28/MNT-004.md) |
| MNT-005 | P0 | `SOURCE_IMPLEMENTED` | Legacy-Q02-Reaper ist progress-aware und source-getestet. | Betriebsbeobachtung nach Neustart; keine fortschreitenden Läufe reapen. |
| MNT-006 | P0 | `PARTIAL` | Health gruppiert Q02/P2 als eine Historie, nutzt eine invariant-basierte Infra-only-Definition und behandelt ZERO/INVALID/DRAFT als terminale Nicht-Infra-Disposition; fokussierte Tests PASS. Read-only bleiben 265 echte infra-only Paare, 24 frühere False-Positives sind entfernt. | Runtime-Backlog bleibt bis zu den kontrollierten MNT-007-Wellen offen; daher keine Completion. |
| MNT-007 | P0 | `RUNTIME_DEFERRED` | Deterministischer Recovery-Vertrag exakt `5 -> 25`, hashgebundene Wave-Receipts, Q08-Invalid-Block und Tests implementiert. | Keine Wave ausgeführt; erst 5/5 echte Terminal-PASS, danach exakt 25; verbleibenden Graveyard adjudizieren. [Vertrag](evidence/2026-07-29_mnt007_wave_contract.md) |
| MNT-008 | P1 | `CONTRACT_ONLY` | Korrekte invariant-basierte NO_HISTORY-Disposition ist konvergiert. | 35er Restbestand inklusive Legacy-P2 real auflösen; valid zero nie als Infra-Retry behandeln. |
| MNT-009 | P1 | `PARTIAL` | Forward-Trigger blockieren neue terminale NULL-Verdicts. Runtime: 832/832 Legacy-NULL-Zeilen klassifiziert und 1.005 existierende lineage-valide Evidence-Artefakte hashgebunden; 0 terminale NULL-Zeilen im Nachlauf. | Für 45.833 Zeilen existiert weiterhin kein zulässiges Artefakt; Evidence nicht erfinden, sondern nur provenance-gestützt nachbinden oder explizit ungebunden lassen. [Apply](evidence/2026-07-29_mnt009_010_reconciliation_apply.md) |
| MNT-010 | P1 | `COMPLETED_RUNTIME` | Gemeinsamer atomarer Parent-CAS und append-only Ledger implementiert; 43/43 Zombies geschlossen (13 PASS, 27 INFRA, 3 STRATEGY), alle 13 PASS-Folgen bei OFF dauerhaft deferred, 0 Enqueues. | Nur Nachlaufbeobachtung: der idempotente Plan zeigt 0 weitere Parent-Zombies. [Apply](evidence/2026-07-29_mnt009_010_reconciliation_apply.md) |
| MNT-011 | P1 | `PARTIAL` | Magic-Resolver und repo-interne getrackte Text-Dependencies verwenden Git-LF-kanonische Hashes nach einem Raw-Byte-Check; CRLF-Drift und negative Grenzen sind getestet. | Allgemeinen Repo-Dirty-Guard für generierte/ungetrackte Artefakte dauerhaft entkoppeln; Runtime-Setfiles bleiben absichtlich bytegenau. [Triage](evidence/2026-07-29_execution_contract_residual_triage.md) |
| MNT-012 | P1 | `PARTIAL` | Claim-/R-Gate-Guards implementiert; QM5_1457 und QM5_1459 hashgebunden `pending -> blocked` reconciliiert, mit Snapshot und append-only Ledger. | Die beiden Runtime-Karten fachlich auf konsistentes R3/G0 zurücksetzen; dies bleibt OWNER-/Research-gebunden. [Apply-Receipt](evidence/2026-07-29_mnt012_build_zombie_reconciliation_apply.json) |
| MNT-013 | P1 | `RUNTIME_DEFERRED` | Kontrollierter READY-Preflight-/Drain-Vertrag liegt vor. | Approved-Card-Backlog in gebundenen Wellen real abbauen und Laufbelege erzeugen. |
| MNT-014 | P1 | `CONTRACT_ONLY` | Dispositionsklassen statt pauschalem RECYCLE→TODO konvergiert. | Backlog-Disposition materialisieren und jeden Übergang evidenzbinden. |
| MNT-015 | P1 | `SOURCE_IMPLEMENTED` | Append-only Events erhalten einen transaktionalen Dedupe-Sidecar; identische Nullsignale werden 24 h unterdrückt, Änderungen sofort emittiert und Suppressionen gezählt. Tests PASS. | Historische 297.847 Events bleiben unverändert; Sidecar-Aufbau und 24-h-Runtime-Evidenz sind bis Factory_ON deferred. |
| MNT-016 | P1 | `PARTIAL` | Forward-Taxonomie und Verdict-Familien wurden verbessert. | Historische bidirektionale Kontamination inklusive `verdict_reason` und INFRA-Status-Split bereinigen/adjudizieren. |
| MNT-017 | P1 | `PARTIAL` | Forward-Provenance-Checks und per-EA-Wiring-Vertrag vorhanden. | 13-EA-Kohorte quellseitig reparieren, durch MNT-043 rebuilden und Q05/Q06 neu laufen lassen. [Seite](mnt_page_updates_2026-07-28/MNT-017.md) |
| MNT-018 | P1 | `PARTIAL` | Neue Q07-Läufe fail-closed bei fehlender Seed-Authentisierung. | Legacy-Altlast mit rebuilt binaries und echter requested/effective-Seed-Evidenz requalifizieren. [Seite](mnt_page_updates_2026-07-28/MNT-018.md) |
| MNT-019 | P1 | `CONTRACT_ONLY` | Gültige positive Kontrollkohorte und Same-Indicator-A/B-Vertrag definiert. | Echte T5-A/B-Probe ausführen; Handle-Cache-Hypothese nicht vorab als Ursache deklarieren. [Seite](mnt_page_updates_2026-07-28/MNT-019.md) |
| MNT-020 | P1 | `CONTRACT_ONLY` | Call-Site-Linter-/Same-Source-A/B-/Rebuild-Vertrag konvergiert. | TEMP-DIAG bereinigen, Linter/Cache-Reparatur implementieren, 20143/20144 triagieren und Kohorte rebuilden/rerunnen. |
| MNT-021 | P1 | `PARTIAL` | Register-Selbstduplikate und veraltete Re-key-Testannahmen wurden bereinigt. | Q12-/Live-Sicht vollständig reconciliieren; insbesondere DXZ10939/12567 versioniert amendieren und 25 Setfile-Bindungen provenance-gestützt entscheiden. [Residualplan](evidence/2026-07-29_integration_residual_action_plan.md) |
| MNT-022 | P1 | `PARTIAL` | FTMO-Slot 2 ist source-seitig auf OWNER-Wahl QM5_13108 fixiert; neue Book-3-Setdatei vorhanden. | QM5_20181 kompilieren, Binary-/Source-Fidelity und Joint Replay/Estimator/Governor-Parität belegen. [Slot-Lock](evidence/2026-07-29_qm5_20181_slot2_owner_lock.md) |
| MNT-023 | P1 | `SOURCE_IMPLEMENTED` | Strikter DXZ-Trigger: Sharpe +0,06 und DD-Verschlechterung höchstens +0,05 pp; Tests vorhanden. | Deploy-/Runtime-Nutzung noch nicht nachgewiesen. [Vertrag](evidence/2026-07-29_mnt023_dxz_next_book_trigger_contract.md) |
| MNT-024 | P2 | `CONTRACT_ONLY` | Kanonischer Vault-Navigations- und G:-Preflight-Vertrag konvergiert. | Vault-Mount-Kontext ausführen und aktive/historische Navigation korrigieren. |
| MNT-025 | P2 | `CONTRACT_ONLY` | Drei-Zustands-Preflight `MOUNT_UNAVAILABLE`/`TARGET_MISSING`/`TARGET_INVALID` definiert. | Aktive Pfade korrigieren und im qm-admin-Kontext testen. |
| MNT-026 | P2 | `CONTRACT_ONLY` | Fail-closed UTF-8-/Pfadvertrag konvergiert. | Dedup-Checks implementieren und False-CLEAN-Fault-Tests liefern. |
| MNT-027 | P2 | `CONTRACT_ONLY` | Q01–Q10-Matrix einschließlich Q04-Kosten- und Q08-Strategy-Parameteranforderungen konvergiert. | Vault-/Repo-Gate-Dokumentation tatsächlich synchronisieren und linten. |
| MNT-028 | P2 | `CONTRACT_ONLY` | Versioniertes Manifest-/Linter-Baseline- und G:-Runner-Konzept konvergiert. | Manifest erneuern, 31 gebrochene Links dispositionieren und deaktivierte Checks wieder aktivieren. |
| MNT-029 | P2 | `CONTRACT_ONLY` | Source-Fehler darf nicht als leerer Cockpit-Feed maskiert werden; Refresh-Vertrag definiert. | `owner_decisions.json`, Morning Brief und Renderer real reparieren/aktualisieren. |
| MNT-030 | P1 | `PARTIAL` | Legacy-Key `gemini` löst ausschließlich Antigravity `agy` aus; Gemini-CLI-Fallbacks entfernt. | MNT-003 anwenden, qm-admin-Credential-/Mailbox-Lane und Heartbeats runtime beweisen. [Backend-Lock](evidence/2026-07-29_antigravity_backend_lock.md) |
| MNT-031 | P1 | `PARTIAL` | Wartungsarbeit ancestry-erhaltend in den Integrations-Worktree übernommen. | Kanonischen Main-Fast-Forward, Origin-Abgleich und Inventar/Disposition der 76 Worktrees abschließen. |
| MNT-032 | P1/P2 | `PARTIAL` | Akuter Purge-Incident wurde behoben und Kapazität wiedergewonnen. | Scheduler-Heilung über MNT-003 sowie Disk-/RAM-/Cache-Härtung und Reclaim-Telemetrie fehlen. |
| MNT-033 | P2 | `CONTRACT_ONLY` | Generierte Sicht statt dritter manueller Wahrheit konvergiert. | Messbares Owner-/Akzeptanz-/Ist-/Evidenz-/Distanz-Ledger implementieren. |
| MNT-034 | P1 | `PARTIAL` | Frühere Recovery-Requeues erfolgt; neue 5→25-Wellen sind source-seitig abgesichert. | Wave-1/2 ausführen und Restkohorte nach Verdict-Familie adjudizieren. Abhängig von MNT-005/007. |
| MNT-035 | P1 | `NOT_IMPLEMENTED` | Problem und Zielvertrag bekannt. | Farm Health, Silent Monitor und Live Pulse in eine gemeinsame Statussemantik überführen. |
| MNT-036 | P2 | `CONTRACT_ONLY` | Probation-Anker 2026-07-13 und Review-Ziel 2026-08-24 präzisiert. | Feste Evidenz für QM5_1556, QM5_10706 und QM5_13128 erzeugen. |
| MNT-037 | P1 | `COMPLETED_RUNTIME` | SAFE_DEFER kann source-seitig nicht mehr als PASS schließen; Runtime-Task `61cfbaf3…` wurde hashgebunden `PASSED -> BLOCKED` reklassifiziert. | Nur Betriebsbeobachtung nach Restart; die Incident-Zeile bleibt append-only belegt. [Evidenz](evidence/2026-07-29_mnt037_safe_defer_reclassification.json) |
| MNT-038 | P1 | `NOT_IMPLEMENTED` | Stopregel-Vertrag konvergiert. | Adaptive Fanout-Stopregeln und kohortenweite deterministische Fehlerbremse implementieren. |
| MNT-039 | P1 | `RUNTIME_DEFERRED` | Reconciler und Health-Sicht sind vorbereitet. | Agent-Task-Limbo auf Runtime-Daten anwenden und jede Disposition evidenzbinden. |
| MNT-040 | P1 | `SOURCE_IMPLEMENTED` | `pipeline_view` liest Work-Items, trennt Strategy/Neutral, latest/best/regressed und kanonisiert Phasen; Tests vorhanden. | Deploy-/Operator-Runtime-Verifikation nach Wartung. [Seite](mnt_page_updates_2026-07-28/MNT-040.md) |
| MNT-041 | P2 | `SOURCE_IMPLEMENTED` | Health meldet eine gesunde T5-Quarantäne als WARN `9/10 design`, trennt enabled von Designkapazität und bezeichnet sie nicht mehr als RAM-Cap; 5 fokussierte Tests PASS. | Deploy-/Runtime-Anzeige nach Restart verifizieren. |
| MNT-042 | P2 | `CONTRACT_ONLY` | Re-Q08-Termin 2026-10-01 und Einfrierbedarf dokumentiert. | Scope, Inputs und Compute-Manifest rechtzeitig materialisieren. |
| MNT-043 | P0 | `PARTIAL` | Read-only Closure-Scanner, rekursive Include-/Hash-Bindung, Schemas und Tests implementiert. | Kein Fleet-Rebuild, kein statischer Live-Halt-Nachweis und keine frischen Q06/Q07-Runs; zusätzlich brauchen DXZ10939/12567 und 25 Setfiles provenance-gebundene Requalifikation. 50-Subject-Canary zeigt 0 PASS. [Residualplan](evidence/2026-07-29_integration_residual_action_plan.md) |
| MNT-044 | P0 | `PARTIAL` | Append-only Adjudication-Overlay und read-only Scanner implementiert; Live immer `HOLD_OWNER_REVIEW`. | 580 Alt-Adjudications (573 unverified, 7 vintage stale) real reviewen, rebuilt Offender rerunnen und Overlay in Leser integrieren. [Canary](evidence/2026-07-29_mnt043_044_scanner_canary.json) |
| MNT-045 | P1 | `PARTIAL` | Per-Principal Kalender-Preflight vor Claim und direkt vor Spawn, feine Taxonomie sowie ein hashgebundener atomarer Zwei-Dateien-Publisher mit immutable Bundle/Manifest sind implementiert und getestet. | 24 echte QM20009-Driftbefunde bleiben: D:\QM bis 2026-07-31, Common-Kopien bis 2026-07-24. Validieren, atomar publizieren, autorisiert neu binden und sieben Tage beobachten. [Triage](evidence/2026-07-29_execution_contract_residual_triage.md) |
| MNT-046 | P1 | `SOURCE_IMPLEMENTED` | Gemeinsame versionierte 16-Runner-Allowlist, exakte Script-/UUID-/`--out-prefix`-/Terminal-Lineage, T5/T_Live/ALL-Ausschluss, fail-closed Legacy-Dispatcher, Near-Match `REVIEW_REQUIRED`, geordneter Reap und Zwei-Nullscan-Vertrag sind implementiert. PS 254 Assertions, Python 31 Tests und 16/16 reale argv Parser+Classifier PASS. | Echter OWNER-freigegebener OFF-E2E-Nachweis ist runtime-deferred und Teil des MNT-052-Exit-Gates. [Seite](mnt_page_updates_2026-07-28/MNT-046.md) |
| MNT-047 | P0 | `COMPLETED_RUNTIME` | 73 Phantom-Reservierungen archiviert, T1–T10 `3 -> 0`, Phase-Matrix unverändert, Post-Dry-Run konsistent. | Nur der koordinierte Restart bleibt abhängig von MNT-052. [Seite](mnt_page_updates_2026-07-29/MNT-047.md) |
| MNT-048 | P0 | `SOURCE_IMPLEMENTED` | Generation-/Attempt-/Hash-Bindung und stale-result-Quarantäne für QM5_20172 umgesetzt. | Frischer QM5_20172-Build/Q02 nach Exit; flottenweite Altbestandsprüfung separat. [Seite](mnt_page_updates_2026-07-29/MNT-048.md) |
| MNT-049 | P0 | `SOURCE_IMPLEMENTED` | `record-build` blockiert vor DB-Write; hashgebundene OFF-Ausnahme kann nie Auto-Q02 erzeugen; QM5_20182-Zeile quarantänisiert. | Frischer QM5_20182-Q02 erst nach koordiniertem Exit. [Seite](mnt_page_updates_2026-07-29/MNT-049.md) |
| MNT-050 | P1 | `RUNTIME_DEFERRED` | Q09_NEWS v2, 7 Modi, 5 Seeds, gepaarte Arme, Kalender-/Lineage-Schema, Q10-Doppelbindung und Migrationstool implementiert. | Migration nicht angewandt; reale Q09_NEWS/Q10-Runs fehlen. [Seite](mnt_page_updates_2026-07-29/MNT-050.md) |
| MNT-051 | P0 | `COMPLETED_RUNTIME` | Zehn Work-Item-Transitionen/ Holds reconciliiert; QM5_13301 T6 `done/PASS`, Fidelity FAIL sauber bewertet und erledigter Hold freigegeben. | Sieben allgemeine Restart-Holds bleiben; 20172/20182 brauchen zulässige Folgearbeit. [Seite](mnt_page_updates_2026-07-29/MNT-051.md) |
| MNT-052 | P0 | `PARTIAL` | Breite OFF-Quieszenz, globale Mutations-/Restart-Locks, Hold-Release, Hourly-Monitor-Guard und MNT-046-Phase-Runner-Scope source-seitig; 30 Runtime-Tasks deaktiviert. Der Legacy-v1-Upgradepfad verlangt nun ein exakt flag-hashgebundenes OWNER-Manifest mit 21 echten Boolean-Entscheidungen; Factory_ON validiert denselben exakten Satz vor Release. | Die tatsächlichen Pre-OFF-Task-Entscheidungen nicht erfinden, sondern OWNER-seitig autorisieren; danach echten OFF/ON-E2E einschließlich Runtime-Evidenz ausführen. [Seite](mnt_page_updates_2026-07-29/MNT-052.md) |
| MNT-053 | P0 | `SOURCE_IMPLEMENTED` | Alle `_scope_guard`-Callsites besitzen expliziten Ziel-DB-Sink; Temp-Root-/AST-Regressionstests. | Runtime-Beobachtung nach Restart; fünf historische Incident-Ereignisse bleiben append-only sichtbar. [Seite](mnt_page_updates_2026-07-29/MNT-053.md) |

## Nächste harte Exit-Reihenfolge

1. MNT-009s NULL-Scope und MNT-010 sind runtime-seitig abgeschlossen; 45.833
   ehrlich ungebundene Evidence-Zeilen bleiben als MNT-009-Rest sichtbar.
2. MNT-046 ist source-seitig abgeschlossen. Für MNT-052 den Legacy-v1-
   Pre-OFF-Task-Intent sicher rekonstruieren und danach den echten
   OWNER-freigegebenen OFF/ON-E2E mit dessen Runtime-Evidenz abnehmen.
3. Offene P0-Live-/Evidence-Punkte MNT-001/002/003/006/007/043/044 schließen
   oder mit expliziter OWNER-Disposition halten.
4. Die fünf fail-closed Integrationsresiduen aus MNT-021/043/045 ohne
   Testlockerung requalifizieren.
5. Erst dann den gemeinsamen Factory_ON-Vertrag ausführen und die sieben
   `release_on_restart`-Holds freigeben. Kein Canary; T_Live und AutoTrading
   bleiben außerhalb des Scopes.

Die maschinenlesbare Spiegelung ist
[`MNT_IMPLEMENTATION_STATUS_2026-07-29.json`](MNT_IMPLEMENTATION_STATUS_2026-07-29.json).

## Integrationsverifikation

- Finaler Gesamtlauf über `tools/strategy_farm/tests` und
  `framework/scripts/tests`: **2.635 PASS**, **1 SKIP**, **25 Subtests PASS**.
- Exakt fünf fail-closed Checks bleiben rot: zwei datierte DXZ-Paketbindungen
  sowie drei Execution-Contract-Sauberkeitschecks für 25 Setfiles und 24
  QM20009-Kalenderdrifts.
- Keine dieser fünf Prüfungen wurde gelockert, übersprungen oder als XFail
  maskiert. Der deterministische Folgeplan steht in
  [`2026-07-29_integration_residual_action_plan.md`](evidence/2026-07-29_integration_residual_action_plan.md).
- Der abschließende Zwei-Nullscan, Taskzustand und Runtime-Postzustand sind in
  [`2026-07-29_maintenance_implementation_closure.md`](evidence/2026-07-29_maintenance_implementation_closure.md)
  gebunden.

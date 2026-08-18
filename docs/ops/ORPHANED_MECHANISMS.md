# ORPHANED_MECHANISMS — Automatismen ohne Aufrufer

**Stand:** 2026-08-18 · Work Order Runde 6 §5.2
**Erzeuger:** `tools/strategy_farm/find_orphaned_mechanisms.py` ·
Artefakt `artifacts/orphaned_mechanisms_20260818.json`
**Charakter: Suche, keine Reparatur.** Nichts hiervon wurde behoben.

---

## 0 · Warum die Klasse zählt

Drei Fälle in einem Monat, jeder derselben Bauart: ein Mechanismus, dessen Entwurf einen Operator
voraussetzt, und kein Operator.

| | Mechanismus | wie es aufgefallen ist |
|---|---|---|
| 1 | Poison-Pill-Quarantäne-Refresh | Quarantäne blieb leer, obwohl 184 Zeilen qualifiziert waren |
| 2 | stranded-INFRA-Sweep | eine fälschlich getötete Zeile wäre für immer `failed` geblieben |
| 3 | `QM_StrategyFarm_Repair_Hourly` | Disabled seit **01.06.**, gehört zum Requeue-Vertrag des Reapers |

**Keiner hat sich gemeldet.** Sie erscheinen als Rückstau, als hängende Zeile, als Queue, die nicht
leerläuft — Symptome, die wie Kapazitätsprobleme aussehen und als solche behandelt werden.

---

## 1 · Deaktivierte Aufgaben — die härteste Liste, weil die Oberfläche Deckung suggeriert

Acht QM-Aufgaben stehen auf **Disabled**. Sie sind eingerichtet, sie haben gelaufen, sie stehen im
Aufgabenplaner — und sie laufen nicht.

| Aufgabe | letzter Lauf | Einschätzung |
|---|---|---|
| **`QM_StrategyFarm_TerminalWorkers_AT_STARTUP`** | **23.05.** | ⚠️ **CLAUDE.md verweist ausdrücklich darauf**: *„After a VPS reboot, check the `QM_StrategyFarm_TerminalWorkers_AT_STARTUP` scheduled task."* Sie ist die dokumentierte Wiederanlaufsicherung der Worker-Flotte — und deaktiviert. Die Worker laufen heute, gestartet von etwas anderem. **Welcher Pfad sie tatsächlich startet, ist nicht verifiziert.** Bis das geklärt ist, ist der Wiederanlauf nach einem Reboot unbelegt. |
| **`QM_StrategyFarm_Repair_Hourly`** | **01.06.** | Trägt den Requeue-Vertrag, auf den sich der Reaper im Code beruft. Fall 3 oben. |
| `QM_StrategyFarm_SourcingIntakeSweep` | 20.07. | Sourcing-Zufluss. Research ist gedrosselt, kann also Absicht sein. |
| `QM_StrategyFarm_FactoryRecycle_Daily` | 21.07. | Recycle-Abbau läuft seit dem Direktiv batchweise von Hand. Vermutlich Absicht. |
| `QM_StrategyFarm_GmailAlarm_Hourly` | 23.07. | Mail-Kanäle sind bewusst auf 06:00-HTML + FAIL-Digest beschränkt. Absicht. |
| `QM_StrategyFarm_HygieneReboot` | 19.07. | Reboots sind wegen T_Live unerwünscht. Absicht. |
| `QM_StrategyFarm_UnreadableLinks_Friday` | 24.07. | unklar |
| `QM_TSCon_Console_OnDisconnect` | 21.07. | Session-Handling; hing an der Session-Loss-Klasse. unklar |

**Die ersten beiden Zeilen sind die, die geprüft gehören.** Der Rest ist plausibel gewollt — aber
„plausibel gewollt" ist keine Dokumentation, und genau diese Lücke hat die drei Fälle oben erzeugt.

---

## 2 · Skripte mit Wartungsverb — Ergebnis des Scans

54 Kandidaten (Name enthält *sweep, purge, requeue, reconcile, refresh, prune, heal, monitor, watch,
guard, governor, pacer, drain, cleanup, clean, reclaim, dedupe, repair, recover*):

| Status | Anzahl | Bedeutung |
|---|---:|---|
| `scheduled` | 22 | eine aktivierte Aufgabe ruft sie auf |
| `documented_only` | 14 | nur in Dokumentation erwähnt |
| **`mentioned_but_not_invoked`** | **10** | in Code erwähnt, aber **nicht aufgerufen** — siehe §3 |
| `called_from_code` | 3 | echter Aufruf nachgewiesen |
| `scheduled_but_disabled` | 1 | `sourcing_intake_sweep.py` |
| `orphan` | 4 | keinerlei Bezug |

Die vier `orphan` sind **falsche Treffer meiner Heuristik** und werden hier als solche benannt statt
als Befund verkauft: drei sind Einmal-Installer bzw. Einmal-Reparaturen
(`install_*_scheduled_task.ps1`, `repair_basket_history_symbols.py`,
`recover_r1_source_rejections.py`) — bei denen ist „kein Aufrufer" der Sollzustand.

---

## 3 · Die Schwäche meines eigenen Scans, und was sie ändert

Die erste Fassung zählte **jede Nennung** eines Skriptnamens als Aufruf. Damit galt
`requeue_stranded_infra.py` als `called_from_code` — obwohl seine beiden Fundstellen der
**Docstring meines eigenen** `requeue_false_progress_reap.py` und seine **Testdatei** sind. Keine
davon ruft irgendetwas auf.

Ein strengerer Durchlauf (Aufruf nur bei `subprocess`, `python …`, `& …` oder `import`) stuft
**10 von 13** zurück. Damit ist die Zahl belastbarer — aber sie hat den Fehler jetzt in der anderen
Richtung: PowerShell-Dot-Sourcing (`. .\script.ps1`) und Aufrufe über Task-Runner erkennt das Muster
nicht, weshalb etwa `factory_restart_health.ps1` (referenziert von `Factory_ON.ps1`) und
`public_snapshot_incident_guard.py` (referenziert von `run_public_snapshot_task.ps1`) vermutlich
**echte** Aufrufer haben.

**Was das für die Liste bedeutet:** sie ist eine **Kandidatenliste, keine Befundliste.** Jede Zeile
braucht eine einzeilige menschliche Prüfung. Ich gebe sie so heraus, statt eine Präzision zu
behaupten, die der Scan nicht hat.

**Belastbar nachgewiesen ist genau eines:**

> **`requeue_stranded_infra.py` hat keinen Aufrufer.** Keine Aufgabe im Planer nennt es, keine
> Codestelle ruft es auf, und `QM_StrategyFarm_Repair_Hourly` — die Aufgabe, die den Vertrag
> tragen würde — ist seit dem **1. Juni** deaktiviert.

---

## 4 · Der Review-Stau, gesondert

**[MESSUNG]** 86 Aufgaben in `REVIEW`, sämtlich vom Typ `review_ea`, gewachsen von 56 auf 86 seit
dem 18.08. früh.

**Ursache — kein Operator, sondern eine Zuständigkeit.** `review_ea`-Tickets sind
Claude-Kapazität: der Router führt Claude mit `enabled: false` und `max_parallel: 0`
(`agent_router.py status`), also routet nichts. Sie werden in Sitzungen wie dieser abgearbeitet, und
diese Sitzung hat an Audit und Infrastruktur gearbeitet.

**Berührt er den kritischen Pfad?** **Nein.** Es sind Build-Reviews neuer EAs; sie stauen den
Zufluss, nicht die Kette 2.3 → 3.4. Ein mechanischer Vorabfilter existiert bereits
(`prescreen_build_reviews.py`, fand 3 echte Defekte in 59).

**Aber er ist die vierte Ausprägung derselben Klasse:** eine Queue, deren Bearbeiter strukturell
abwesend ist, und die deshalb wächst, ohne dass etwas Alarm schlägt.

---

## 5 · Was ich daraus ableite, ohne es umzusetzen

Alle vier Fälle haben dieselbe Form: **ein Zustand, den niemand beobachtet.** Dazu gehört auch der
heutige Containment-Befund (`LEASE_SCOPE_ANALYSIS.md` §6, OQ-13) — vier Stunden Notlage, neun
Terminals still, entdeckt nur, weil jemand nach der Ursache fehlender Claims gesucht hat.

Die billigste Gegenmaßnahme ist nicht, die Mechanismen zu reparieren, sondern **ihre Abwesenheit
sichtbar zu machen**: ein Health-Check, der deaktivierte QM-Aufgaben, `enabled:true`-Containment und
Queue-Tiefen ohne Servicerate als Befund meldet. `health.py` führt bereits zehn Invarianten — drei
weitere wären dort eine kleine Ergänzung.

**Vorgelegt, nicht gebaut.**

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

**Nachtrag 20:55 UTC — die Umkehrung derselben Klasse.** `QM_StrategyFarm_WorktreeClean_4h` ist
**aktiviert** und läuft, deckt aber nicht ab, wonach sie klingt: sie räumt Bau-Artefakte im Repo auf,
nicht die 90 registrierten Git-Worktrees (~64 GB auf einem C: mit 46,7 GB frei). Ein Aufrufer, dessen
Name Deckung suggeriert, erzeugt denselben blinden Fleck wie ein Mechanismus ohne Aufrufer → OQ-16.

**Die ersten beiden Zeilen sind die, die geprüft gehören.** Der Rest ist plausibel gewollt — aber
„plausibel gewollt" ist keine Dokumentation, und genau diese Lücke hat die drei Fälle oben erzeugt.

---

## 2 · Skripte mit Wartungsverb — Ergebnis des Scans

54 Kandidaten (Name enthält *sweep, purge, requeue, reconcile, refresh, prune, heal, monitor, watch,
guard, governor, pacer, drain, cleanup, clean, reclaim, dedupe, repair, recover*), gescannt über das
gesamte Repo **ohne verschachtelte Checkouts**:

| Status | Anzahl | Bedeutung |
|---|---:|---|
| `scheduled` | **22** | eine aktivierte Aufgabe ruft sie auf |
| `documented_only` | **18** | nur in Dokumentation erwähnt |
| `mentioned_but_not_invoked` | **9** | im Code erwähnt, aber nicht aufgerufen |
| `documented_command_only` | **3** | die einzige „Aufruf"-Fundstelle ist ein Brief oder eine Result-JSON, die die Kommandozeile protokolliert |
| `called_from_code` | **1** | echter automatischer Aufrufer nachgewiesen |
| `scheduled_but_disabled` | **1** | `sourcing_intake_sweep.py` |

**31 von 54 wartungsförmigen Skripten haben keinen automatischen Aufrufer.** Ein großer Teil davon
ist zu Recht einmalig (Installer, Einmal-Reparaturen) — die Zahl ist der ehrliche Nenner der Klasse,
nicht ihre Befundmenge.

**Der einzige nachgewiesene automatische Aufruf im gesamten Feld** ist
`reclaim_busy_agent_temp.ps1` ← `run_agent_temp_reclaim.ps1`.

---

## 3 · Drei Fehlversuche meines eigenen Scans, und was sie ändern

Der Weg zu den Zahlen oben war dreimal falsch, und jede Korrektur ging in eine andere Richtung.
Das gehört in die Vorlage, weil es die Belastbarkeit bestimmt.

**Fehler 1 — zu enger Korpus.** Die erste schnelle Fassung las nur `tools/`, `scripts/`,
`docs/ops/` und meldete **4 „orphans"**. Über das ganze Repo sind es **0**: die vier hatten
Referenzen außerhalb des engen Korpus.

**Fehler 2 — Korpus mit Klonen.** Der erste Vollrepo-Lauf schloss `.claude/worktrees/` ein — dort
liegen **vollständige Kopien dieses Repos**. Damit erschien `requeue_stranded_infra.py` als
„called_from_code", weil sein eigener Klon es referenziert. Nach Ausschluss verschachtelter
Checkouts fällt es zurück.

**Fehler 3 — Dokumentation als Aufruf gezählt.** Der strenge Durchlauf akzeptierte
`python <name>` als Aufrufnachweis. Genau so „belegt" ein Codex-Brief den Aufruf von
`requeue_stranded_infra.py`, und Build-Result-JSONs den von `validate_build_guardrails.py`. Eine
protokollierte Kommandozeile und ein automatischer Aufrufer sind **textlich identisch**.

**Was daraus folgt — und es ist die eigentliche Aussage dieses Abschnitts:** die Klasse ist
maschinell **nicht** abschließend entscheidbar. Der Scan verengt das Feld von 54 auf ~31; der letzte
Schritt braucht je Zeile einen Blick. Ich gebe die Liste deshalb als **Kandidatenliste** heraus.

**Belastbar nachgewiesen ist genau eines, jetzt über zwei unabhängige Wege:**

> **`requeue_stranded_infra.py` hat keinen Aufrufer.** Keine Aufgabe im Planer nennt es; die einzige
> aufrufähnliche Fundstelle ist ein Markdown-Brief. `QM_StrategyFarm_Repair_Hourly` — die Aufgabe,
> die den Requeue-Vertrag des Reapers tragen würde — ist seit dem **1. Juni** deaktiviert.

## 4 · Der Review-Stau, gesondert

**[MESSUNG] Stand 19:40 UTC: 106 Aufgaben in `REVIEW`** — 56 `build_ea` und 50 `review_ea`. Die
frühere Zählung („86, sämtlich `review_ea`") war eine Momentaufnahme **einer** Typspalte; korrekt
sind zwei Typen. Die `ops_issue`-Lieferungen dieser Sitzung sind beide geschlossen.

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

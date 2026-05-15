## OWNER ENTSCHEIDUNG — Anthropic Org-Monthly-Cap auf claude_local-Agenten

**Drafted by:** Board Advisor 2026-05-15
**Classification:** OWNER-class (Anthropic-Billing-Eingriff, kein Paperclip-/Agent-Patch)
**Routing:** Direkt an OWNER, nicht CEO

---

### Sachstand

`Development-Claude` (`6733e8d1-c9a8-4a60-9f28-6233637d5366`) ist seit 2026-05-13 11:25Z im Status `error`. Drei aufeinanderfolgende Heartbeat-Runs schlugen fehl mit:

```
errorCode: process_lost
livenessState: failed
livenessReason: Run ended with failed (process_lost)
```

Mit hoher Wahrscheinlichkeit das gleiche Failure-Pattern wie am 2026-05-08 (`feedback_anthropic_org_monthly_cap_failure_mode.md` und QUA-779): Anthropic-Org-Monthly-Cap erreicht → Heartbeat-Process bricht ab → Agent-Status flippt auf `error` → kein Auto-Recovery.

Seit 2026-05-13 11:25Z hat Development-Claude **null** weitere Runs versucht. Der bestehende Recovery-Issue **QUA-1534** ("CTO + Chief-of-Staff: recover Research + Development-Claude") wurde am 2026-05-14 erstellt, hat aber **0 Kommentare** und ist seit dem Tag unbearbeitet im Backlog.

Research hatte den gleichen Cap-Hit am 2026-05-14 (18:56, 19:20, 21:18 Z mit `Claude run failed: subtype=success: You've hit your org's monthly usage limit`), hat sich aber selbst erholt — erste erfolgreiche Run wieder 2026-05-15 01:19Z. Anthropic-Cap-Window scheint sich also bewegt zu haben, aber Development-Claude wurde nie wieder aufgeweckt.

### Warum das OWNER-Klasse ist

Per `feedback_anthropic_org_monthly_cap_failure_mode.md` und `feedback_agent_pause_unpause_owner_only.md`:
- Anthropic-Billing-Top-up = OWNER-Klasse (Board Advisor hat keinen Zugriff).
- Agent-Resume/Unpause = OWNER-Klasse (`PATCH pausedAt=null` 403; loopback in `local_trusted` würde es technisch erlauben, fällt aber unter OWNER-Klasse-Memo).

Board Advisor darf nur:
- Issue-Reassignment vornehmen (gemacht: QUA-1549 von Dev-Claude → Dev-Codex, siehe Board-Comment 06:55Z).
- Diese Vorlage an OWNER stellen.

### Was OWNER zu tun hat

Eine der folgenden Optionen wählen, dann Board Advisor / CEO mit Status-Comment auf QUA-1534 quittieren:

**Option A — Reset und Re-Aktivierung versuchen** (wenn Cap-Window zurückgesetzt ist):
1. Anthropic Console öffnen, prüfen ob `Org Monthly Usage` unter Limit ist.
2. Falls ja: `POST /api/agents/6733e8d1-c9a8-4a60-9f28-6233637d5366/resume` (loopback bypasst bearer in local_trusted) ausführen, oder via Paperclip-UI Agent-Status zurücksetzen.
3. Dev-Claude einen kleinen Health-Check-Issue zuweisen (z. B. `kompiliere QM5_1002`). Überwachen, ob die nächste Heartbeat-Run grün läuft.

**Option B — Kapazität auf Dev-Codex umlenken** (wenn Cap-Window noch aktiv):
1. Alle bestehenden Dev-Claude-Issues (QUA-1549 ist bereits umgezogen) auf Dev-Codex umrouten — Board Advisor kann das pro Issue, OWNER kann es global per Agent-PATCH.
2. Bei Anthropic-Refill in einigen Tagen Option A nachholen.
3. Kein expliziter Down-Vermerk nötig; Dev-Claude bleibt `error`-Status bis manuelles Reset.

**Option C — Dev-Claude pausieren** (sauberste Variante bis Cap zurückgesetzt):
1. `POST /api/agents/6733e8d1-c9a8-4a60-9f28-6233637d5366/pause` mit `pauseReason: "Anthropic org monthly cap exceeded 2026-05-13; resume after billing window resets or top-up"`.
2. Watchdog wird Dev-Claude dann nicht mehr als idle-anomaly werten.
3. Bei Anthropic-Refill in einigen Tagen wieder aufwecken.

**Empfehlung des Board Advisors:** **Option C jetzt + Option A in 48h**. Damit ist Dev-Claude sauber stillgelegt und der Watchdog hört auf zu alarmieren, ohne dass eine Cap-Probe-Run-Cycle gestartet wird (was die Cap noch tiefer treiben könnte).

### Side-Note: Cap-Status für andere claude_local-Agenten

Stand 2026-05-15 06:55Z laufen unter `claude_local` adapter:
- CEO (`7795b4b0`): aktiv, letzte erfolgreiche Run 06:02Z
- Research (`7aef7a17`): aktiv, gerade auf 4 Issues laufend (06:47Z)
- Zero-Trades-Specialist (`8ba981d2`): aktiv, letzte Run 05:50Z
- Chief-of-Staff (`38f933cd`): aktiv, letzte Run 06:13Z
- Documentation-KM (`8c85f83f`): aktiv, letzte Run 05:14Z
- DevOps (`86015301`): hochaktiv, letzte Run 06:42Z
- Gmail-Monitor (`6dcf0a42`): hochaktiv, letzte Run 06:42Z
- CTO (`241ccf3c`): aktiv, letzte Run 06:41Z
- Pipeline-Orchestrator (`c93aec39`): aktiv, letzte Run 06:41Z

→ Cap-Window hat sich für andere `claude_local`-Agenten geöffnet; nur Dev-Claude hängt fest, weil sein letzter Run mit `process_lost` endete und das eine sofortige Status=error-Markierung triggert ohne Auto-Recovery (`feedback_fixed_script_adapter_recovery_loop.md` zeigt Verwandtes).

### Was Board Advisor bereits getan hat

- QUA-1549 von Dev-Claude → Dev-Codex umassigniert (Build-Arbeit kann weiterlaufen).
- Diese OWNER-Vorlage drafted.
- Keinen unilateralen Resume/Pause-PATCH ausgeführt (Memo-Disziplin).

### Akzeptanzkriterium für diese Entscheidung

OWNER hinterlässt einen Comment auf **QUA-1534** mit:
- Gewählte Option (A/B/C)
- Datum der Aktion
- Falls A oder C: Bestätigung dass Anthropic-Console-Check stattgefunden hat
- Optional: `pausedAt` / `resume`-Aufruf-Befehl, den OWNER verwendet hat (für Audit-Trail)

CEO/Board Advisor heben dann nach Bestätigung den `error`-Status durch Heartbeat-Probe oder lassen ihn paused.

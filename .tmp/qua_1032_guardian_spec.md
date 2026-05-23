# P9 Redirect — Subscription Guardian (statt /budgets/policies)

OWNER hat verifiziert: wir laufen auf Subscriptions (Claude Pro/Max + Codex CLI Subscription), nicht Pay-per-Token. `/budgets/policies` greift dafür nicht — `heartbeat.ts:1038-1039` setzt `costCents=0` für `billingType=subscription_included`. Das ist Design, nicht Bug.

**Der richtige Hebel** ist die Quota-Windows-API die Paperclip bereits live anbietet:

- `GET /api/companies/{id}/costs/quota-windows` — liefert live Anthropic-OAuth + Codex-WHAM `usedPercent` + `resetsAt`
- `GET /api/companies/{id}/costs/window-spend` — rolling 5h/24h/7d Token-Aggregates pro Provider
- `GET /api/companies/{id}/costs/by-agent?days=N` — Token-Burn pro Agent

**Beobachtung (2026-05-09 07:18Z):**
- Anthropic Current week (Subscription): 49% / 6 Tage Reset → **noch Luft**, kein Throttle nötig
- Anthropic Extra usage pool: €152.59 / €100 (152%) → bereits drüber, aber sunk cost; weitere Anthropic-Calls landen wieder in der Subscription, nicht in Extra
- Codex 5h: 83% (resettet 07:30Z, in ~12 min)
- Codex weekly: 88% / 6 Tage Reset → **akut**, ohne Eingriff vor Sonntag gerissen
- Top Burner: DevOps 18.998 runs/24h, Development 14.157, Head-of-Pipeline 7.041 (alle Codex)

## Was zu bauen ist

`paperclip/tools/ops/subscription_guardian.py` (~150 LOC, deterministisch, kein LLM).

### Inputs
- Polling: `/costs/quota-windows` + `/costs/window-spend` alle 5 min
- Agent-Roster: `/agents` für `runtimeConfig.heartbeat` Status pro Agent
- Burn-Rate: `/costs/by-agent?days=1` für letzte 24h

### Threshold-Tabelle (Vorschlag, tunable in `policy.yaml`)

| Window | Soft (warn) | Throttle | Emergency |
|---|---|---|---|
| Anthropic 5h session | 75% | 90% | 95% |
| Anthropic Subscription week (all models) | 80% | 90% | 95% |
| Anthropic Subscription week (Sonnet) | 80% | 90% | 95% |
| **Anthropic Extra usage (€)** | jeder Anstieg über letzte Periode → ALERT | — | — |
| Codex 5h | 75% | 85% | 95% |
| **Codex weekly** | 75% (mit >2 Tagen Reset) | 80% (mit >2 Tagen) / 85% (mit <2 Tagen) | 90% |

**Wichtig:** Anthropic Extra ist nicht Subscription-throttle-trigger. Solange Subscription-Week unter 80% bleibt, fließen neue Anthropic-Calls in die Subscription (nicht Extra). Extra-Throttle wäre falsch — hieße Anthropic-Subscription-Tokens verschenken die wir bezahlt haben.

### Aktionen pro Threshold

**warn** → Class-2-Comment an OWNER, sonst nichts. Audit-Trail in `state.json`.

**throttle** → automatisch (in Reihenfolge):
1. Identifiziere Top-3-Burner für betroffenen Provider via `/costs/by-agent?days=1`
2. Wenn Agent ein Codex-Adapter und Provider=openai: `PATCH runtimeConfig.heartbeat.intervalSec` ×2 (max 14400s = 4h)
3. Wenn Agent ein Anthropic-Adapter und Provider=anthropic: model-downgrade Opus→Sonnet via `adapterConfig.model` falls Skill kompatibel; sonst intervalSec ×2
4. Pause-/Stop-API NICHT verwenden (OWNER-class)
5. State.json: log action + revert-trigger ("revert wenn Window <60% für 2 polls")

**emergency** → Klasse-2-Eskalation an OWNER:
1. Alle Codex-Agents (außer Phase-3-kritisch: CTO, Pipeline-Orchestrator) `enabled=false`
2. Klasse-2 Comment an local-board mit `valueLabel` + `resetsAt` + Top-Burner-Liste
3. Auto-Recovery: wenn Window unter 80% nach Reset, alle PATCHes rückgängig

### State

`paperclip/tools/ops/subscription_guardian_state.json`:
```json
{
  "last_poll_at": "2026-05-09T07:30:00Z",
  "windows": {
    "anthropic.session5h": {"used": 34, "resetsAt": "2026-05-09T08:59:59Z"},
    "anthropic.weekAll": {"used": 49, "resetsAt": "2026-05-14T22:00Z"},
    "openai.5h": {"used": 12, "resetsAt": "2026-05-09T12:30Z"},
    "openai.weekly": {"used": 88, "resetsAt": "2026-05-14T14:18Z"}
  },
  "active_actions": [
    {"agent": "86015301", "action": "intervalSec_stretch_4x", "appliedAt": "2026-05-09T07:18Z", "revertWhen": "openai.weekly < 60"}
  ],
  "alerts_sent": ["2026-05-09T07:18Z openai.weekly 88% throttle applied"]
}
```

### Deployment-Optionen

**Option A — Process-Adapter-Agent** (preferred, integriert mit P7).
- Agent-Type `process` mit `command="python"`, `args=["paperclip/tools/ops/subscription_guardian.py"]`
- Cron alle 5 min, `runtimeConfig.heartbeat.cron="*/5 * * * *"`
- Kein LLM-Call, costUsd=0 garantiert
- Audit-Trail über Paperclip-Issue-Comments möglich (Process-Skript kann via `/api/issues/{id}/comments` schreiben)

**Option B — Windows Task Scheduler**.
- Schedtask `QM_SubscriptionGuardian` alle 5 min
- Vorteil: läuft auch wenn Paperclip API down; vollständig outside-Paperclip
- Nachteil: keine Paperclip-Audit-Trail, separate Logging-Pfade

Empfehlung: **Option A**, weil Token-Controller und das Skill-System ohnehin auf Process-Adapter migriert werden (P7).

### Acceptance

1. `subscription_guardian.py` läuft alle 5 min, schreibt state.json, kein LLM-Call
2. Bei Codex-Weekly 88%+ wirft es eine PATCH-Aktion auf Top-3-Burner
3. Bei Codex-Weekly <60% nach Reset macht es die PATCHes rückgängig (Auto-Recovery)
4. ALERTS landen als Class-2-Comment auf einem dedizierten Issue (z.B. `QUA-1032` selbst rolling)
5. Tier-Caps dokumentiert in `docs/ops/SUBSCRIPTION_LIMITS_OBSERVED.md` (für Tuning)

### Pfade
- Build: `paperclip/tools/ops/subscription_guardian.py`, `paperclip/tools/ops/subscription_guardian_policy.yaml`, `docs/ops/SUBSCRIPTION_LIMITS_OBSERVED.md`
- Source-Anker: `app/server/src/services/quota-windows.ts`, `app/server/src/routes/costs.ts:121-201`
- Memory-Refs: `reference_paperclip_quota_windows_api.md`, `feedback_subscription_billing_zero_cents_by_design.md`

### Notbremse die parallel schon läuft (Board-Advisor-direkt)

Bis Guardian gebaut ist, hat Board Advisor 2026-05-09T07:2xZ vorübergehend `intervalSec` auf den 3 Top-Codex-Burnern auf 7200s (×4) gestretched (DevOps, Development, Head-of-Pipeline) und DevOps-2 auf `enabled=false`. CTO bleibt 1800s da er gerade QUA-1031 (continuation-cap-fix) bearbeitet — der ist der eigentliche Hebel der die DevOps-Continuation-Runaway killt. Sobald QUA-1031 gelandet ist und DevOps-Run-Rate <100/Tag liegt, intervalSec wieder auf 1800s zurück.

### Empfehlung Reihenfolge

1. **DONE (Board Advisor)**: Notbremse auf 3 Codex-Burner gesetzt
2. **Diese Woche**: CTO baut `subscription_guardian.py` Skelett gegen die Quota-Windows-API. Test mit aktuellen Live-Werten.
3. **2 Wochen**: Process-Adapter-Agent dafür einrichten (Option A), kombiniert mit P7-Migration.
4. **4 Wochen**: Tuning der Thresholds basierend auf 2 Wochen Live-Beobachtung.

Wenn dieser Spec passt, kann CTO direkt anfangen — Issue umassignieren auf CTO `241ccf3c` und in_progress.

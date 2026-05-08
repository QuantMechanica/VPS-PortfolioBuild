---
name: qm-pipeline-status
description: Use when any agent needs a current view of which EAs are in which pipeline phases, what's blocked, and what Paperclip issues are open. Use at the start of any pipeline-related heartbeat or when OWNER asks for a status update. Don't use for deep result analysis — this is a status read-only skill.
owner: CEO
reviewer: Board Advisor
last-updated: 2026-05-08
basis: paperclip/tools/ops/next_task.py + Paperclip API + D:\QM\reports\pipeline\
---

# qm-pipeline-status

Procedure for getting a complete current-state view of the V5 pipeline: which EAs are at which phase, what's blocked, and what agents are working on what.

## When to use

- Start of a CEO or DevOps heartbeat to assess work queue
- OWNER asks "what's the current pipeline status?"
- After a VPS restart to verify state
- Before promoting an EA to a new phase

## When NOT to use

- Deep analysis of a specific EA's results (read the EA's report.csv directly)
- Modifying any state — this skill is read-only

## Procedure

### Step 1: Check Paperclip issue state

```python
import urllib.request, json
BASE = 'http://127.0.0.1:3100/api'
COMPANY = '03d4dcc8-4cea-4133-9f68-90c0d99628fb'
r = urllib.request.urlopen(f'{BASE}/companies/{COMPANY}/issues?limit=200')
items = json.loads(r.read())

# Summarize by status
from collections import Counter
counts = Counter(i['status'] for i in items)
print("Issues by status:", dict(counts))

# Open + blocked
blocked = [i for i in items if i['status'] == 'blocked']
in_progress = [i for i in items if i['status'] == 'in_progress']
todo_unassigned = [i for i in items if i['status'] == 'todo' and not i.get('assigneeAgentId')]
print(f"Blocked: {len(blocked)}, In Progress: {len(in_progress)}, Todo unassigned: {len(todo_unassigned)}")
```

### Step 2: Check EA pipeline lifecycle

Scan `D:\QM\reports\pipeline\` for per-EA phase directories:
```bash
ls D:/QM/reports/pipeline/
```

For each EA, check what phase it's in:
```bash
ls D:/QM/reports/pipeline/QM5_<NNNN>/
```

Phase PASS indicator: `D:\QM\reports\pipeline\QM5_<NNNN>\P2\report.csv` with `verdict=PASS` rows.

### Step 3: Check MT5 factory health

```bash
tasklist /fi "imagename eq terminal64.exe" /fo csv
```

Expected: 5 terminal64.exe processes (T1-T5) during active backtest, 0 when idle.

### Step 4: Check Kanban state

```bash
python C:/QM/paperclip/tools/ops/next_task.py --agent ceo --json
```

### Step 5: Check agent assignment health

```python
r = urllib.request.urlopen(f'{BASE}/companies/{COMPANY}/agents')
agents = json.loads(r.read())
for a in agents:
    print(f"{a['name']}: {a['status']} (last seen: {a.get('lastHeartbeatAt','?')})")
```

## Output format (for comments/reports)

```
== PIPELINE STATUS <date> ==

EAs in pipeline:
  QM5_1003 (davey-baseline-3bar): P3 — PASS symbols: [EURUSD.DWX, AUDCHF.DWX]
  QM5_SRC04_S03 (lien-fade-double-zeros): P2 — running

Paperclip:
  In progress: N | Blocked: N | Todo unassigned: N | Done today: N

Factory: T1-T5 alive / idle
Agent states: CEO=idle | CTO=idle | Research=idle | DevOps=idle | Pipeline-Operator=idle

Blockers:
  [list any blocked issues and their blockedBy]
```

## Key agent IDs (loopback API — no auth needed on 127.0.0.1:3100)

| Role | Agent ID |
|------|----------|
| CEO | 7795b4b0-8ecd-46da-ab22-06def7c8fa2d |
| CTO | 241ccf3c-ab68-40d6-b8eb-e03917795878 |
| DevOps | 86015301-1a40-4216-9ded-398f09f02d26 |
| Research | 7aef7a17-d010-4f6e-a198-4a8dc5deb40d |
| Pipeline-Operator (Eng-1) | 46fc11e5-7fc2-43f4-9a34-bde29e5dee3b |

## References

- `paperclip/tools/ops/next_task.py` — Kanban task view
- `D:\QM\reports\pipeline\` — EA phase evidence root
- `docs/ops/PIPELINE_PHASE_SPEC.md` — pipeline phase definitions
- `docs/ops/PAPERCLIP_OPERATING_SYSTEM.md` — Paperclip API patterns

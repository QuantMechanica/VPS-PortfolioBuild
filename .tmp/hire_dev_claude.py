"""Hire Development-Claude (claude_local, Opus 4.6, parallel to Development-Codex)."""
import sys, urllib.request, urllib.error, json, shutil
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8')

API='http://127.0.0.1:3100/api'
COMPANY='03d4dcc8-4cea-4133-9f68-90c0d99628fb'
CTO='241ccf3c-ab68-40d6-b8eb-e03917795878'

# 1. Create the agent
agent_body = {
    'name': 'Development-Claude',
    'role': 'engineer',
    'title': 'Development (Claude) — V5 EA implementation parallel to Development-Codex',
    'icon': 'code',
    'reportsTo': CTO,
    'adapterType': 'claude_local',
    'adapterConfig': {
        'cwd': 'C:\\QM\\worktrees\\development-claude',
        'model': 'claude-opus-4-6',
        'graceSec': 15,
        'timeoutSec': 0,
        'maxTurnsPerRun': 80,
        'chrome': False,
        'instructionsBundleMode': 'managed',
    },
    'runtimeConfig': {
        'heartbeat': {'enabled': False, 'wakeOnDemand': True}
    },
    'capabilities': 'Implements V5 EAs in MQL5 from CEO-approved Strategy Cards (parallel to Development-Codex). CTO Review-only gate before Pipeline-Op smoke. Cross-review eligible for Codex-built EAs.',
    'status': 'idle',
}

req = urllib.request.Request(
    f'{API}/companies/{COMPANY}/agents',
    data=json.dumps(agent_body).encode('utf-8'),
    headers={'Content-Type': 'application/json'},
    method='POST',
)
try:
    resp = urllib.request.urlopen(req)
    new_agent = json.loads(resp.read())
    print(f'Agent created: {new_agent.get("id")} | name={new_agent.get("name")}')
    print(f'  adapterType={new_agent.get("adapterType")} model={(new_agent.get("adapterConfig") or {}).get("model")}')
    print(f'  status={new_agent.get("status")}')
    NEW_ID = new_agent['id']
except urllib.error.HTTPError as e:
    print(f'POST agent error: {e.status}')
    print(e.read().decode()[:600])
    sys.exit(1)

# 2. Find / create instructions dir + copy AGENTS.md from Codex-Dev with adjustments
codex_instructions = Path(r'C:/QM/paperclip/data/instances/default/companies/03d4dcc8-4cea-4133-9f68-90c0d99628fb/agents/ebefc3a6-4a11-43a7-bd5d-c0baf50eb1f9/instructions/AGENTS.md')
new_instructions_dir = Path(rf'C:/QM/paperclip/data/instances/default/companies/03d4dcc8-4cea-4133-9f68-90c0d99628fb/agents/{NEW_ID}/instructions')
new_instructions_dir.mkdir(parents=True, exist_ok=True)
new_instructions_path = new_instructions_dir / 'AGENTS.md'

# Read original
original_text = codex_instructions.read_text(encoding='utf-8')

# Identity adjustment: prepend identity block + work-routing
identity_block = """---
agent_name: Development-Claude
agent_id: {agent_id}
adapter: claude_local
model: claude-opus-4-6
worktree: C:/QM/worktrees/development-claude (branch: agents/development-claude)
parallel_to: Development-Codex (ebefc3a6-4a11-43a7-bd5d-c0baf50eb1f9)
hire_directive: OWNER 2026-05-09 — provider-diversification on Dev-side; Codex weekly cap risk mitigation
---

# Development-Claude — Identity & Routing Rules

You are **one of TWO Development Agents** for QuantMechanica V5. Your sibling is **Development-Codex** (`ebefc3a6-4a11-43a7-bd5d-c0baf50eb1f9`, codex_local, gpt-5.3-codex). You both implement V5 EAs from APPROVED Strategy Cards. **Same role, same scope, same conventions.**

## Why TWO Development Agents

OWNER 2026-05-09: Codex provider has weekly rolling caps (~3.5 day window observed); when Codex is throttled, EA build pipeline stalls (= MT5 saturation drops = mission failure). Provider-diversification fixes the bottleneck. Memory: `project_qm_mission_baseline_2026-05-09`.

## Work-Routing Rules

CEO/HoP routes scaffold/build issues based on Codex weekly limit:

- **Codex weekly < 70%**: bevorzugt Development-Codex (etablierter Workflow, Codex schneller bei pure-code patterns)
- **Codex weekly 70–85%**: split — kleinere scaffolds an Development-Claude, komplexere code-changes an Development-Codex
- **Codex weekly ≥ 85% OR 5h-cap nahe**: alles routed zu Development-Claude

Manual override via assignee-PATCH bleibt jederzeit möglich. Wenn du ein Issue bekommst: ausführen, NICHT zurück-routing-debattieren.

## Cross-Review (Phase 2, nach Erfahrung)

When Development-Codex builds an EA, you may be assigned a peer-review issue:
- Code-style adherence (framework conventions)
- Strategy-card-fidelity (matches REVIEW_INPUT.json)
- Edge cases (boundary conditions, no-history scenarios)
- Compile success
- Comment with approve/request-changes; CTO DL-036 final sign-off unchanged

Vice versa for your output (Codex peer-reviews you).

## Your Worktree

`C:/QM/worktrees/development-claude` on branch `agents/development-claude`. NEVER work in `C:/QM/repo` (main checkout — orphan files block ff-merges per DL-028).

## Adapter-Specific Notes

- claude_local adapter, NO Codex CLI plugin skills (those are Codex-only).
- Use Bash/Read/Write/Edit/Grep tools natively + framework docs as your "skills":
  - `framework/V5_FRAMEWORK_DESIGN.md` — design spec
  - `framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/` — existing EA reference
  - `processes/13-strategy-research.md` — card structure
  - `framework/registry/ea_id_registry.csv` — ea_id allocation
  - `framework/registry/tester_defaults.json` — tester constants (deposit, leverage, fixed_risk)

---

"""

new_text = identity_block.format(agent_id=NEW_ID) + original_text

new_instructions_path.write_text(new_text, encoding='utf-8')
print(f'Instructions written: {new_instructions_path} ({len(new_text)} chars)')

# 3. PATCH adapterConfig with the resolved instructionsFilePath (Paperclip might auto-set this on create, but be explicit)
adapter_config_update = {
    'adapterConfig': {
        'cwd': 'C:\\QM\\worktrees\\development-claude',
        'model': 'claude-opus-4-6',
        'graceSec': 15,
        'timeoutSec': 0,
        'maxTurnsPerRun': 80,
        'chrome': False,
        'instructionsFilePath': str(new_instructions_path).replace('/', '\\'),
        'instructionsRootPath': str(new_instructions_dir).replace('/', '\\'),
        'instructionsEntryFile': 'AGENTS.md',
        'instructionsBundleMode': 'managed',
    }
}
req2 = urllib.request.Request(f'{API}/agents/{NEW_ID}',
    data=json.dumps(adapter_config_update).encode('utf-8'),
    headers={'Content-Type': 'application/json'},
    method='PATCH')
try:
    resp = urllib.request.urlopen(req2); d=json.loads(resp.read())
    ac=(d.get('adapterConfig') or {})
    print(f'adapterConfig PATCH: model={ac.get("model")} cwd={ac.get("cwd")} instructionsFilePath set={bool(ac.get("instructionsFilePath"))}')
except urllib.error.HTTPError as e:
    print(f'PATCH err: {e.status} {e.read().decode()[:300]}')

# 4. Reassign QUA-1090 to Development-Claude
issues_url = f'{API}/companies/{COMPANY}/issues?limit=200'
issues = json.load(urllib.request.urlopen(issues_url))
issues = issues if isinstance(issues, list) else issues.get('data', [])
qua1090 = next((i for i in issues if i.get('identifier') == 'QUA-1090'), None)
if qua1090:
    req3 = urllib.request.Request(f'{API}/issues/{qua1090["id"]}',
        data=json.dumps({'assigneeAgentId': NEW_ID}).encode('utf-8'),
        headers={'Content-Type': 'application/json'},
        method='PATCH')
    try:
        resp = urllib.request.urlopen(req3); d = json.loads(resp.read())
        print(f'QUA-1090 reassigned: assigneeAgentId={d.get("assigneeAgentId")[:8]}.. (was Development-Codex)')
    except urllib.error.HTTPError as e:
        print(f'reassign err: {e.status} {e.read().decode()[:300]}')

    # Comment on QUA-1090 explaining the reroute
    comment = f"""## Reassigned: Development-Claude (new hire 2026-05-09)

OWNER 2026-05-09 directive: hire second Development agent on Claude (Anthropic) to mitigate Codex weekly-cap bottleneck. Provider-diversification = continuous EA-build velocity.

- New agent: Development-Claude (`{NEW_ID[:8]}..`)
- Adapter: claude_local, model: claude-opus-4-6
- Worktree: C:/QM/worktrees/development-claude (branch agents/development-claude)
- Reports to: CTO (same as Codex-Dev)

This issue (QM5_1014 lien-channels scaffold) is the FIRST USE CASE — Codex weekly at 93%+ is too tight for full EA scaffold + compile cycle, so route to Claude-Dev.

Wake fires now via assignment-trigger. Monitor for first delivery.
"""
    req4 = urllib.request.Request(f'{API}/issues/{qua1090["id"]}/comments',
        data=json.dumps({'body':comment}).encode('utf-8'),
        headers={'Content-Type': 'application/json'},
        method='POST')
    try:
        urllib.request.urlopen(req4)
        print('QUA-1090 comment posted')
    except Exception as e:
        print(f'comment err: {e}')

print()
print(f'=== HIRE COMPLETE: Development-Claude id={NEW_ID} ===')

"""Refile 7 hires with corrected role/icon enums.

Allowed enums:
- role: ceo, cto, cmo, cfo, security, engineer, designer, pm, qa, devops, researcher, general
- icon: bot, cpu, brain, zap, rocket, code, terminal, shield, eye, search, wrench, hammer, lightbulb, palette (+ more)
"""
import sys, urllib.request, urllib.error, json, subprocess
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8')

API='http://127.0.0.1:3100/api'
COMPANY='03d4dcc8-4cea-4133-9f68-90c0d99628fb'
CTO='241ccf3c-ab68-40d6-b8eb-e03917795878'
COS='38f933cd-557b-41ff-8498-30db273273ef'
HOP='46fc11e5-7fc2-43f4-9a34-bde29e5dee3b'
DEVOPS='86015301-1a40-4216-9ded-398f09f02d26'

INSTR_BASE = Path(r'C:/QM/paperclip/data/instances/default/companies/03d4dcc8-4cea-4133-9f68-90c0d99628fb/agents')
WT_BASE = Path(r'C:/QM/worktrees')

HIRES = [
    {
        'name': 'Frontend-Designer',
        'role': 'designer',
        'icon': 'zap',
        'title': 'Frontend Designer / Dashboard Engineer — UI/UX + Brand-Konsistenz',
        'reportsTo': DEVOPS,
        'adapter': 'claude_local',
        'model': 'claude-sonnet-4-6',
        'wt_branch': 'agents/frontend-designer',
        'capabilities': 'Designs and refines QM dashboards (current.html, strategies.html), component-refactors, brand-token consistency per branding/brand_tokens.json + ClaudeDesign_Upload/03_Website/style.css. Frontend-design Claude skill installed.',
        'identity_short': 'Frontend Designer — refines QM dashboards on V2 brand. Worktree agents/frontend-designer. Skill: frontend-design. Reads style.css for tokens. Mobile + desktop. Hands implementation to DevOps.',
    },
    {
        'name': 'Agent-Configurator',
        'role': 'general',
        'icon': 'cpu',
        'title': 'Agent Configurator (Recommender-only) — Spec drafts + drift audit',
        'reportsTo': COS,
        'adapter': 'claude_local',
        'model': 'claude-sonnet-4-6',
        'wt_branch': 'agents/agent-configurator',
        'capabilities': 'Drafts agent configuration specs (model, skills, heartbeat, cwd, adapterConfig). Audits live state vs spec. RECOMMENDER-ONLY: writes drafts to paperclip/governance/agent_configs/, CEO/Board patches.',
        'identity_short': 'Agent Configurator — Recommender only. Drafts specs to paperclip/governance/agent_configs/<role>.yaml. CEO/Board executes PATCHes. Per memory feedback_paperclip_agent_patch_permission_scope.',
    },
    {
        'name': 'P2-Baseline-Runner',
        'role': 'engineer',
        'icon': 'zap',
        'title': 'P2 Baseline Runner — qm-p2-baseline skill, single responsibility',
        'reportsTo': HOP,
        'adapter': 'codex_local',
        'model': 'gpt-5.3-codex',
        'wt_branch': 'agents/p2-baseline-runner',
        'capabilities': 'Runs qm-p2-baseline skill on assigned EAs. Dispatches p2_baseline.py / p2_matrix_launcher.py per Head-of-Pipeline assignment.',
        'identity_short': 'P2 Baseline Runner — skill qm-p2-baseline. Dispatched by HoP when EA reaches P1 PASS. Output: report.csv + DL-054 verdict per symbol. PATCH done.',
    },
    {
        'name': 'Phase-Runner-P3plus',
        'role': 'engineer',
        'icon': 'zap',
        'title': 'Phase Runner P3+ — qm-run-pipeline-phase skill (P3.5/P5/P5b/P5c/P6/P7/P8)',
        'reportsTo': HOP,
        'adapter': 'codex_local',
        'model': 'gpt-5.3-codex',
        'wt_branch': 'agents/phase-runner-p3plus',
        'capabilities': 'Runs phase runners P3.5/P5/P5b/P5c/P6/P7/P8 per Head-of-Pipeline assignment.',
        'identity_short': 'Phase Runner P3+ — skill qm-run-pipeline-phase. Picks up post-P3 phases dispatched by HoP. P3 itself = Pipeline-Operator runs p3_param_sweep.',
    },
    {
        'name': 'Setfile-Engineer',
        'role': 'engineer',
        'icon': 'wrench',
        'title': 'Setfile Engineer — qm-new-setfiles skill',
        'reportsTo': HOP,
        'adapter': 'codex_local',
        'model': 'gpt-5.3-codex',
        'wt_branch': 'agents/setfile-engineer',
        'capabilities': 'Generates setfiles per EA × symbol × timeframe via gen_setfile.ps1.',
        'identity_short': 'Setfile Engineer — skill qm-new-setfiles. Calls gen_setfile.ps1 per EA × Symbol × Timeframe. Output: 36 setfiles in framework/EAs/<EA>/sets/. Verify RISK_FIXED + RISK_PERCENT inputs.',
    },
    {
        'name': 'Zero-Trades-Specialist',
        'role': 'engineer',
        'icon': 'hammer',
        'title': 'Zero-Trades Specialist — qm-zero-trades-recovery skill',
        'reportsTo': HOP,
        'adapter': 'codex_local',
        'model': 'gpt-5.3-codex',
        'wt_branch': 'agents/zero-trades-specialist',
        'capabilities': 'Diagnoses 0-trade backtest results post NO_REPORT-check. Fixes set/symbol/timeframe issues.',
        'identity_short': 'Zero-Trades Specialist — skill qm-zero-trades-recovery. Dispatched when backtest yields 0 trades AFTER NO_REPORT check. Diagnose: setfile? symbol? timeframe? news-filter? magic conflict? Fix or write ZT_RootCause.',
    },
    {
        'name': 'Framework-Guardian',
        'role': 'engineer',
        'icon': 'shield',
        'title': 'Framework Guardian — magic registry + ea_id collision + V5 build_check enforcement',
        'reportsTo': CTO,
        'adapter': 'codex_local',
        'model': 'gpt-5.3-codex',
        'wt_branch': 'agents/framework-guardian',
        'capabilities': 'Daily framework health: magic registry consistency, ea_id collisions, header versioning, V5 build_check enforcement.',
        'identity_short': 'Framework Guardian — daily health audit. Magic registry consistency (framework/registry/magic_numbers.csv vs framework/EAs/). ea_id collision check. Shared headers QM_*.mqh versioning. V5 build_check: no ML, no V4-Erbnamen, RISK_FIXED + RISK_PERCENT both. Anomaly report → CTO.',
    },
]


def post(path, body):
    req=urllib.request.Request(API+path, data=json.dumps(body).encode('utf-8'),
        headers={'Content-Type':'application/json'}, method='POST')
    try: return json.loads(urllib.request.urlopen(req).read()), None
    except urllib.error.HTTPError as e: return None, f'HTTP {e.status}: {e.read().decode()[:300]}'

def patch(path, body):
    req=urllib.request.Request(API+path, data=json.dumps(body).encode('utf-8'),
        headers={'Content-Type':'application/json'}, method='PATCH')
    try: return json.loads(urllib.request.urlopen(req).read()), None
    except urllib.error.HTTPError as e: return None, f'HTTP {e.status}: {e.read().decode()[:300]}'

results=[]
for h in HIRES:
    branch = h['wt_branch']
    wt_short = branch.split('/')[-1]
    wt_path = str(WT_BASE / wt_short).replace('/','\\')
    print(f"\n=== {h['name']} ===")
    # Worktree create (if not exists)
    wt_check = subprocess.run(['git','-C','C:/QM/repo','worktree','list'], capture_output=True, text=True)
    if branch not in wt_check.stdout:
        wt = subprocess.run(['git','-C','C:/QM/repo','worktree','add','-b',branch,wt_path,'origin/main'],
            capture_output=True, text=True)
        if wt.returncode != 0:
            print(f'  worktree FAIL: {wt.stderr[:200]}')
            results.append((h['name'], None, 'wt_fail'))
            continue
        print(f'  worktree ✓')
    else:
        print(f'  worktree exists')

    # Create agent
    body = {
        'name': h['name'],
        'role': h['role'],
        'title': h['title'],
        'icon': h['icon'],
        'reportsTo': h['reportsTo'],
        'adapterType': h['adapter'],
        'adapterConfig': {
            'cwd': wt_path,
            'model': h['model'],
            'graceSec': 15,
            'timeoutSec': 0,
            'maxTurnsPerRun': 80,
            'instructionsBundleMode': 'managed',
        },
        'runtimeConfig': {'heartbeat': {'enabled': False, 'wakeOnDemand': True}},
        'capabilities': h['capabilities'],
        'status': 'idle',
    }
    if h['adapter'] == 'claude_local':
        body['adapterConfig']['chrome'] = False
    if h['adapter'] == 'codex_local':
        body['adapterConfig']['dangerouslyBypassApprovalsAndSandbox'] = True

    data, err = post(f'/companies/{COMPANY}/agents', body)
    if err:
        print(f'  CREATE FAIL: {err}')
        results.append((h['name'], None, err))
        continue
    new_id = data['id']
    print(f'  agent: {new_id[:8]}..')

    # Instructions
    instr_dir = INSTR_BASE / new_id / 'instructions'
    instr_dir.mkdir(parents=True, exist_ok=True)
    instr_file = instr_dir / 'AGENTS.md'
    full_instructions = f"""# {h['name']}

{h['title']}

Adapter: `{h['adapter']}`, model `{h['model']}`. Worktree: `{wt_path}` (branch `{branch}`). Reports to ID `{h['reportsTo']}`.

Hire date: 2026-05-09 per OWNER directive (Endausbaustufe-Modus, planned-hires batch).

## Role

{h['identity_short']}

## Common rules (all QM agents)

- **DL-046**: blocked = stop + escalate + wait. No "still blocked" comments.
- **DL-054**: anti-theater pass criteria — no PASS verdict without report.csv + DL-054 gates passing.
- **DL-061** (Endausbaustufe): no company-level Phase 1/2/3 gating; all workstreams continuous parallel.
- **Mission Baseline 2026-05-09**: DXZ €100k, 5%/20% DD, 20% p.a., MT5-saturation = success metric, no ML.
- **Worktree discipline (DL-028)**: work only in your assigned worktree, never in C:/QM/repo main checkout.
- **Comment-then-PATCH** for status transitions (memory feedback_in_review_needs_closeout_comment).
- **Forward slashes in API comments** (memory feedback_paperclip_api_backslash_comment_500).
- **Loopback API on 127.0.0.1:3100** in local_trusted mode bypasses bearer for /api/*.

## Instructions

You are assignment-driven (`runtimeConfig.heartbeat.enabled=false, wakeOnDemand=true`). When woken via assignment or comment, perform the task and PATCH the issue. Stay in scope per `capabilities` field.

For detailed framework/process docs see:
- `processes/13-strategy-research.md` — research methodology (R1-R4)
- `framework/V5_FRAMEWORK_DESIGN.md` — EA framework spec
- `decisions/REGISTRY.md` — DL-NNN log
- `paperclip/governance/PHASE_STATE.md` — current company state pointer
"""
    instr_file.write_text(full_instructions, encoding='utf-8')

    # PATCH adapterConfig with instructions paths
    cfg = body['adapterConfig'].copy()
    cfg['instructionsFilePath'] = str(instr_file).replace('/','\\')
    cfg['instructionsRootPath'] = str(instr_dir).replace('/','\\')
    cfg['instructionsEntryFile'] = 'AGENTS.md'
    pdata, perr = patch(f'/agents/{new_id}', {'adapterConfig': cfg})
    print(f'  instr-patch: {"✓" if pdata else perr[:100]}')

    results.append((h['name'], new_id, 'OK'))

print()
print('=== SUMMARY ===')
ok = 0
for name, aid, status in results:
    print(f'  {name:30s} | {(aid[:8] if aid else "FAIL"):10s} | {status[:50]}')
    if status == 'OK': ok += 1
print(f'\n{ok}/{len(HIRES)} agents created successfully')

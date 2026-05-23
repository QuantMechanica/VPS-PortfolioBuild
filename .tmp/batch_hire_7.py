"""Batch-hire 7 planned agents per OWNER 2026-05-09 'volle Endausbaustufe' directive.

Order:
1. Frontend Designer (Sonnet 4.6, claude_local) — immediate need for QUA-1121
2. Agent Configurator (Sonnet 4.6, claude_local) — Recommender for CoS
3. P2 Baseline Runner (Codex) — pipeline sub-agent
4. Phase Runner P3+ (Codex) — pipeline sub-agent
5. Setfile Engineer (Codex) — pipeline sub-agent
6. Zero-Trades Specialist (Codex) — pipeline sub-agent
7. Framework Guardian (Codex) — under CTO
"""
import sys, urllib.request, urllib.error, json, subprocess, os
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8')

API='http://127.0.0.1:3100/api'
COMPANY='03d4dcc8-4cea-4133-9f68-90c0d99628fb'
CTO='241ccf3c-ab68-40d6-b8eb-e03917795878'
COS='38f933cd-557b-41ff-8498-30db273273ef'
HOP='46fc11e5-7fc2-43f4-9a34-bde29e5dee3b'
DEVOPS='86015301-1a40-4216-9ded-398f09f02d26'

INSTRUCTIONS_BASE = Path(r'C:/QM/paperclip/data/instances/default/companies/03d4dcc8-4cea-4133-9f68-90c0d99628fb/agents')
WORKTREE_BASE = Path(r'C:/QM/worktrees')

HIRES = [
    {
        'name': 'Frontend-Designer',
        'role': 'designer',
        'title': 'Frontend Designer / Dashboard Engineer — UI/UX + Brand-Konsistenz',
        'icon': 'palette',
        'reportsTo': DEVOPS,
        'adapter': 'claude_local',
        'model': 'claude-sonnet-4-6',
        'worktree_branch': 'agents/frontend-designer',
        'capabilities': 'Designs and refines QM dashboards (current.html, strategies.html), component-refactors, brand-token consistency per branding/brand_tokens.json + ClaudeDesign_Upload/03_Website/style.css. Mobile + desktop. Hands implementation back to DevOps when complete.',
        'identity': """# Frontend Designer / Dashboard Engineer

Du bist der Frontend-Designer von QuantMechanica V5. Deine Aufgabe: das Pipeline-Dashboard und das Strategie-Archiv (lokal: `paperclip/dashboards/`, public: quantmechanica.com via Astro) graphisch + funktional auf den V5-Brand-Standard bringen.

## Brand-Quelle (binding)

**Authoritative style reference**: `G:/My Drive/QuantMechanica/ClaudeDesign_Upload/03_Website/style.css` — das ist die kanonische QuantMechanica V2 Design-System CSS (rebuilt 2026-04-13 via ui-ux-pro-max skill, Tier 3). Verwende exakt diese `--qm-*` Tokens:
- Surface: `--qm-bg #020617` → `--qm-surface-1 #0f172a` → `--qm-surface-2 #1e293b`
- Text: `--qm-text #f8fafc` / `--qm-text-dim #cbd5e1` / `--qm-text-muted #94a3b8`
- Brand: `--em #10b981` (emerald), `--em-l #34d399` (light), `--em-s rgba(16,185,129,0.12)` (soft)
- Status: `--qm-pass #10b981`, `--qm-promising #f59e0b`, `--qm-fail #ef4444`, `--qm-dead #6b7280`, `--qm-live #06b6d4`
- Fonts: Inter (sans), Source Code Pro (mono/numbers)

Pseudo-Mirror: `branding/brand_tokens.json` im Repo. Bei Konflikt: Website-CSS gewinnt.

## Reference-Pages

- `G:/My Drive/QuantMechanica/ClaudeDesign_Upload/03_Website/Key_Pages/strategies.html` — Strategy-Archive Layout-Vorlage
- `G:/My Drive/QuantMechanica/ClaudeDesign_Upload/03_Website/index.html` — Hauptseite
- `paperclip/tools/ops/daily_status_mail.py` — verwendet bereits diese Brand-Tokens (Mission-Hero-Section, Status-Badges, Quota-Bars als Vorlage)

## Aufgaben

1. **`paperclip/tools/ops/render_dashboard.py`** auf Brand-konsistent + Mission-Hero (MT5-saturation, Heureka-distance, quota live, throughput) umbauen
2. **`paperclip/tools/ops/render_strategies.py`** so umbauen dass alle 29+ Strategy Cards (incl. G0/G1/scaffold/compile/in-pipeline/PASS/live States) angezeigt werden — nicht nur compiled
3. **Component-Refactor**: wiederverwendbare HTML-Komponenten (Status-Badge, Stat-Tile, Workstream-Card, Agent-Pill) als Python-templates oder reine HTML-Snippets in `paperclip/dashboards/components/`
4. **Mobile-Responsive**: CSS @media queries für ≥768px desktop / <768px mobile
5. **Print-friendly** für audit reviews

## Was du NICHT änderst

- Backend-Daten / API-Schema (`process-roadmap.json`, `public-snapshot.json`, `strategy-archive.json` — Schema bleibt stabil)
- Brand-Tokens selbst (Hard Rule, OWNER-class via Brand Guide)
- Public-API-Endpoints
- Astro-Site Inhalt direkt (das ist DevOps; du lieferst Components)

## Deliverables

- Vor Implementation: Mockup als HTML in `agents/frontend-designer` Branch (visual review by Board Advisor)
- Approved → DevOps integration

## Adapter & Cwd

- claude_local, model claude-sonnet-4-6
- worktree: C:/QM/worktrees/frontend-designer (branch agents/frontend-designer)
- chrome=false (kein Browser nötig — wir designen, nicht testen)

## Skills (manual reference, no Codex plugin)

- `qm-render-dashboard` (existing): wie bestehende Dashboards rendern
- frontend-design (zukünftig): Anthropic skill aus https://github.com/anthropics/claude-code/blob/main/plugins/frontend-design/skills/frontend-design/SKILL.md — Board Advisor lädt herunter wenn benötigt

## Erste Aufgabe

QUA-1121: Dashboard + Strategy Archive Redesign — match Brand-Tokens + Mission-KPIs + alle 29 Strategy Cards. Siehe Issue für Details.
""",
    },
    {
        'name': 'Agent-Configurator',
        'role': 'configurator',
        'title': 'Agent Configurator (Recommender-only) — Spec-Drafts + Drift-Audit',
        'icon': 'sliders',
        'reportsTo': COS,
        'adapter': 'claude_local',
        'model': 'claude-sonnet-4-6',
        'worktree_branch': 'agents/agent-configurator',
        'capabilities': 'Drafts agent configuration specs (model, skills, heartbeat, cwd, adapterConfig). Audits live state vs spec. RECOMMENDER-ONLY: writes drafts to paperclip/governance/agent_configs/, CEO/Board patches.',
        'identity': """# Agent Configurator

Du bist der Agent Configurator von QuantMechanica V5. **Recommender-only** — du schreibst Konfigurations-Specs, du patched NICHT.

## Konstraint

Per Memory `feedback_paperclip_agent_patch_permission_scope` + `feedback_cos_agent_patch_permission`: Sonnet-Agenten ohne creator-rights können fremde Agents nicht patchen (403). Selbe Limitierung wie CoS. Du schreibst Specs, CEO oder Board Advisor patcht.

## Aufgaben

1. Für jeden neuen Hire: Spec-Doc nach `paperclip/governance/agent_configs/<role>.yaml` mit:
   - name, role, title, icon, reportsTo
   - adapterType + adapterConfig (cwd, model, instructions paths)
   - runtimeConfig.heartbeat
   - capabilities + recommended skills
   - PATCH-Snippet ready-to-execute
2. Bestehende Agents auditieren: GET /api/agents/{id} vs Spec abgleichen, Drift-Report
3. Output an CoS: Spec + "CEO/Board bitte patchen" + PATCH-Snippet

## Was du NICHT tust

- Niemals selbst PATCHen (403)
- Niemals neue Agents erstellen (POST /api/agents)
- Niemals Skill-Sync ändern

## Memory references

- `feedback_paperclip_agent_config_patch_works` — was technisch möglich ist
- `feedback_paperclip_agent_patch_permission_scope` — was für nicht-creator-bearer-tokens NICHT geht

claude_local, sonnet-4-6, worktree agents/agent-configurator.
""",
    },
    {
        'name': 'P2-Baseline-Runner',
        'role': 'pipeline-runner',
        'title': 'P2 Baseline Runner — qm-p2-baseline skill, single responsibility',
        'icon': 'play',
        'reportsTo': HOP,
        'adapter': 'codex_local',
        'model': 'gpt-5.3-codex',
        'worktree_branch': 'agents/p2-baseline-runner',
        'capabilities': 'Runs qm-p2-baseline skill on assigned EAs. Dispatches p2_baseline.py / p2_matrix_launcher.py per Head-of-Pipeline assignment.',
        'identity': """# P2 Baseline Runner

Skill: `qm-p2-baseline`. Dispatched by Head-of-Pipeline when EA reaches P1-PASS.

## Aufgaben
1. EA + Symbole von Head-of-Pipeline assignment lesen
2. `python framework/scripts/p2_baseline.py --ea <ID>` (oder p2_matrix_launcher fuer parallel) ausfuehren
3. report.csv parsen → DL-054 gates pruefen
4. Comment auf assignment-issue mit verdict per symbol + report path
5. PATCH done

Reports to: Head-of-Pipeline. Keine Eigeninitiative ausserhalb assignments.
codex_local gpt-5.3-codex, worktree agents/p2-baseline-runner.
""",
    },
    {
        'name': 'Phase-Runner-P3plus',
        'role': 'pipeline-runner',
        'title': 'Phase Runner P3+ — qm-run-pipeline-phase skill, P3.5/P5/P5b/P5c/P6/P7/P8',
        'icon': 'play',
        'reportsTo': HOP,
        'adapter': 'codex_local',
        'model': 'gpt-5.3-codex',
        'worktree_branch': 'agents/phase-runner-p3plus',
        'capabilities': 'Runs phase runners P3.5/P5/P5b/P5c/P6/P7/P8 per Head-of-Pipeline assignment.',
        'identity': """# Phase Runner P3+

Skill: `qm-run-pipeline-phase`. Dispatched by Head-of-Pipeline for any phase from P3.5 onwards.

## Aufgaben
1. Dispatch script per phase via `framework/scripts/p<N>*.py` (or run_phase.ps1)
2. Aggregate reports → gate verdict (DL-054)
3. Comment + PATCH done on assignment

P3 itself = Pipeline-Operator runs p3_param_sweep; this agent picks up post-P3 phases.

codex_local gpt-5.3-codex, worktree agents/phase-runner-p3plus.
""",
    },
    {
        'name': 'Setfile-Engineer',
        'role': 'pipeline-runner',
        'title': 'Setfile Engineer — qm-new-setfiles skill',
        'icon': 'sliders',
        'reportsTo': HOP,
        'adapter': 'codex_local',
        'model': 'gpt-5.3-codex',
        'worktree_branch': 'agents/setfile-engineer',
        'capabilities': 'Generates setfiles per EA × symbol × timeframe via gen_setfile.ps1.',
        'identity': """# Setfile Engineer

Skill: `qm-new-setfiles`. Dispatched bei neuem EA oder fehlenden setfiles.

## Aufgaben
1. `framework/scripts/gen_setfile.ps1` aufrufen pro EA × Symbol × Timeframe
2. Output: 36 Setfiles pro EA in `framework/EAs/<EA>/sets/`
3. Verify (file count, RISK_FIXED/RISK_PERCENT inputs vorhanden)
4. Comment + PATCH done

codex_local gpt-5.3-codex, worktree agents/setfile-engineer.
""",
    },
    {
        'name': 'Zero-Trades-Specialist',
        'role': 'pipeline-runner',
        'title': 'Zero-Trades Specialist — qm-zero-trades-recovery skill',
        'icon': 'tool',
        'reportsTo': HOP,
        'adapter': 'codex_local',
        'model': 'gpt-5.3-codex',
        'worktree_branch': 'agents/zero-trades-specialist',
        'capabilities': 'Diagnoses 0-trade backtest results post NO_REPORT-check. Fixes set/symbol/timeframe issues.',
        'identity': """# Zero-Trades Specialist

Skill: `qm-zero-trades-recovery`. Dispatched wenn ein backtest 0 trades produziert (NACH NO_REPORT-check).

## Aufgaben
1. Diagnose: setfile? Symbol? Timeframe? News-filter? Magic conflict?
2. Fix oder ZT_RootCause Doku
3. Comment + PATCH done (oder eskalation an CTO bei strukturellem Bug)

codex_local gpt-5.3-codex, worktree agents/zero-trades-specialist.
""",
    },
    {
        'name': 'Framework-Guardian',
        'role': 'guardian',
        'title': 'Framework Guardian — qm-validate-custom-symbol + framework health',
        'icon': 'shield',
        'reportsTo': CTO,
        'adapter': 'codex_local',
        'model': 'gpt-5.3-codex',
        'worktree_branch': 'agents/framework-guardian',
        'capabilities': 'Daily framework health: magic registry consistency, ea_id collisions, header versioning, V5 build_check enforcement.',
        'identity': """# Framework Guardian

Daily / on-demand framework health audit.

## Aufgaben
1. Magic registry consistency (`framework/registry/magic_numbers.csv` vs framework/EAs/)
2. ea_id Kollisionscheck (ea_id × 10000 + slot, hard abort bei Kollision)
3. Shared headers `QM_*.mqh` Versionierung + Konsistenz
4. V5 build_check: keine ML-Imports, keine V4-Erbnamen, RISK_FIXED + RISK_PERCENT beide vorhanden
5. Anomaly report → CTO

codex_local gpt-5.3-codex, worktree agents/framework-guardian.
""",
    },
]

def post(path, body):
    req=urllib.request.Request(API+path, data=json.dumps(body).encode('utf-8'),
        headers={'Content-Type':'application/json'}, method='POST')
    try: return json.loads(urllib.request.urlopen(req).read()), None
    except urllib.error.HTTPError as e: return None, f'HTTP {e.status}: {e.read().decode()[:200]}'

def patch(path, body):
    req=urllib.request.Request(API+path, data=json.dumps(body).encode('utf-8'),
        headers={'Content-Type':'application/json'}, method='PATCH')
    try: return json.loads(urllib.request.urlopen(req).read()), None
    except urllib.error.HTTPError as e: return None, f'HTTP {e.status}: {e.read().decode()[:200]}'

results=[]
for h in HIRES:
    branch=h['worktree_branch']
    worktree_path=str(WORKTREE_BASE / branch.split('/')[-1]).replace('/','\\')

    # 1. git worktree add
    print(f"\n=== Hiring {h['name']} ===")
    wt_check=subprocess.run(['git','-C','C:/QM/repo','worktree','list'], capture_output=True, text=True)
    if branch in wt_check.stdout:
        print(f'  worktree exists')
    else:
        wt=subprocess.run(['git','-C','C:/QM/repo','worktree','add','-b',branch,worktree_path,'origin/main'],
            capture_output=True, text=True)
        if wt.returncode != 0:
            print(f'  worktree FAIL: {wt.stderr[:200]}')
            results.append((h['name'], None, 'worktree_fail'))
            continue
        print(f'  worktree created: {worktree_path}')

    # 2. Create agent
    body = {
        'name': h['name'],
        'role': h['role'],
        'title': h['title'],
        'icon': h['icon'],
        'reportsTo': h['reportsTo'],
        'adapterType': h['adapter'],
        'adapterConfig': {
            'cwd': worktree_path,
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
        # codex needs dangerouslyBypass + skill sync placeholder
        body['adapterConfig']['dangerouslyBypassApprovalsAndSandbox'] = True
        # Don't add skill sync; CoS / Doc-KM can do per-agent

    data, err = post(f'/companies/{COMPANY}/agents', body)
    if err:
        print(f'  CREATE FAIL: {err}')
        results.append((h['name'], None, err))
        continue
    new_id = data['id']
    print(f'  agent: {new_id}')

    # 3. Write instructions
    instr_dir = INSTRUCTIONS_BASE / new_id / 'instructions'
    instr_dir.mkdir(parents=True, exist_ok=True)
    instr_file = instr_dir / 'AGENTS.md'
    instr_file.write_text(h['identity'], encoding='utf-8')

    # 4. PATCH adapterConfig with instructions paths
    cfg_update = body['adapterConfig'].copy()
    cfg_update['instructionsFilePath'] = str(instr_file).replace('/','\\')
    cfg_update['instructionsRootPath'] = str(instr_dir).replace('/','\\')
    cfg_update['instructionsEntryFile'] = 'AGENTS.md'
    pdata, perr = patch(f'/agents/{new_id}', {'adapterConfig': cfg_update})
    print(f'  instr-patch: {"OK" if pdata else perr}')

    results.append((h['name'], new_id, 'OK'))

# Reassign QUA-1121 from DevOps to Frontend-Designer
print()
print('=== Reassign QUA-1121 to Frontend-Designer ===')
fd = next((r for r in results if r[0]=='Frontend-Designer' and r[1]), None)
if fd:
    issues=json.load(urllib.request.urlopen(f'{API}/companies/{COMPANY}/issues?limit=200'))
    issues=issues if isinstance(issues,list) else issues.get('data',[])
    qua1121=next((i for i in issues if i.get('identifier')=='QUA-1121'),None)
    if qua1121:
        pdata, perr = patch(f'/issues/{qua1121["id"]}', {'assigneeAgentId': fd[1]})
        print(f'  QUA-1121 assignee: {pdata.get("assigneeAgentId")[:8] if pdata else perr}')

print()
print('=== SUMMARY ===')
for name, aid, status in results:
    print(f'  {name:30s} | {(aid[:8] if aid else "FAIL"):10s} | {status}')

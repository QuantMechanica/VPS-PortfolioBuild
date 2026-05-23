"""Dispatch CTO for DL-036 peer-review of Dev-Claude's QM5_1014 scaffold."""
import sys, urllib.request, urllib.error, json
sys.stdout.reconfigure(encoding='utf-8')

API='http://127.0.0.1:3100/api'
COMPANY='03d4dcc8-4cea-4133-9f68-90c0d99628fb'
GOAL='4662e91e-8e9b-458e-9383-b1f67751965b'
CTO='241ccf3c-ab68-40d6-b8eb-e03917795878'

BODY="""## Aufgabe — DL-036 Review + merge of QM5_1014 (Dev-Claude scaffold)

Development-Claude (new hire 2026-05-09) scaffolded QM5_1014_lien_channels in seinem ersten Run:
- Commit `048404f5` on `agents/development-claude` branch
- `framework/EAs/QM5_1014_lien_channels/QM5_1014_lien_channels.mq5` (12 KB)
- `framework/EAs/QM5_1014_lien_channels/QM5_1014_lien_channels.ex5` (99 KB compiled, 0 errors / 0 warnings via MetaEditor64)
- `REVIEW_INPUT.json` (card SRC04_S08 reference)

Strategy: SRC04_S08 Lien Ch 15 narrow-range-breakout. Implementation: bracket entry BUY_STOP + SELL_STOP an channel boundaries ± offset, unfilled side cancelled on fill.

## Review-Scope (DL-036)

1. **Code-style adherence** — V5 framework conventions
   - `<QM/QM_Common.mqh>` include
   - 4-module Modularity (Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal)
   - Naming: `framework/EAs/QM5_1014_lien_channels/QM5_1014_lien_channels.mq5` ✓
   - Magic via `QM_Magic(ea_id, slot)` — ea_id=1014 from registry
   - RISK_FIXED + RISK_PERCENT both present
   - Friday Close enabled
   - No hardcoded symbols
   - No external API calls / no ML imports
   - Strategy Card ID in EA header

2. **Card-fidelity** — matches REVIEW_INPUT.json + SRC04_S08 strategy card narrow-range-breakout logic

3. **Edge cases**
   - Channel boundary detection robust gegen low-volatility periods?
   - BUY_STOP/SELL_STOP placement: offset reasonable (nicht 0, nicht zu eng)?
   - Unfilled-side-cancel logic: race condition wenn beide nahezu zeitgleich fillen?
   - Friday Close: respektiert während aktivem bracket?
   - News-Window: kein Entry vor red-news per QM_NewsFilter?

4. **Compile + runtime sanity**
   - .ex5 size 99 KB plausibel (vergleichbar mit existing EAs)
   - Tester journal sollte clean starten (kein "no history data" pattern)

## Acceptance + Action

Wenn review PASS (DL-036 sign-off):
1. **Merge** `agents/development-claude` -> `main` (oder cherry-pick commit `048404f5`)
2. **Propagate to T1-T5**: copy `.ex5` zu jedem `D:/QM/mt5/T<N>/MQL5/Experts/QM/QM5_1014_lien_channels.ex5` (per existing EA copy pattern; pruefe ob automated script existiert oder manual)
3. **Magic-numbers** registrieren: `framework/registry/magic_numbers.csv` — ea_id=1014, slot per symbol allocation
4. PATCH QUA-1075 (HoP) blockedByIssueIds=[] + status=todo -> HoP wakes + dispatches P1/P2

Wenn review FAIL (Anmerkungen):
1. Comment auf QUA-1090 mit konkreten Issues
2. Reassign QUA-1090 zurueck an Dev-Claude mit Korrekturen-Spec
3. status=todo

## Future cross-review (optional pattern)

Per OWNER directive: future EAs from Dev-Codex sollen von Dev-Claude peer-reviewed werden, vice versa. Heutiges Issue ist CTO-only weil DL-036 final-gate noch nicht delegiert ist. Wenn das Pattern stabil laeuft, kann CTO sich aus DL-036 zurueckziehen + nur bei conflicts eskalieren.

## Constraints

- Codex weekly aktuell 94% — Review ist leicht (lesen + comments), sollte minimal Codex-Tokens kosten
- DL-046: comment-then-PATCH bei Status-Aenderung
- KEIN Pipeline-Operator dispatch from your side — HoP unblockt sich selbst via QUA-1075 wenn merge done

## Pfade

- Source: `C:/QM/worktrees/development-claude/framework/EAs/QM5_1014_lien_channels/`
- Branch: `agents/development-claude` commit `048404f5`
- Compare-EA als Vorbild: `framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/`
- Magic registry: `framework/registry/magic_numbers.csv`
- Memory: `project_qm_mission_baseline_2026-05-09` (no-phasing, MT5 saturation = success)
"""

req=urllib.request.Request(f'{API}/companies/{COMPANY}/issues',
    data=json.dumps({
        'title': 'DL-036 Review + merge: QM5_1014_lien_channels (Dev-Claude scaffold)',
        'description': 'Dev-Claude delivered QM5_1014 scaffold in first run (commit 048404f5, 0 errors/0 warnings). Review gegen V5 framework conventions + card-fidelity, dann merge to main + propagate T1-T5 + unblock HoP QUA-1075.',
        'priority': 'high',
        'assigneeAgentId': CTO,
        'goalId': GOAL,
        'createdByUserId': 'local-board',
    }).encode('utf-8'),
    headers={'Content-Type':'application/json'}, method='POST')
try:
    resp=urllib.request.urlopen(req); d=json.loads(resp.read())
    iid=d['id']; ident=d['identifier']
    print(f'Issue created: {ident} | id={iid}')
    # to_do
    req2=urllib.request.Request(f'{API}/issues/{iid}',
        data=json.dumps({'status':'todo'}).encode('utf-8'),
        headers={'Content-Type':'application/json'}, method='PATCH')
    urllib.request.urlopen(req2)
    # body comment
    req3=urllib.request.Request(f'{API}/issues/{iid}/comments',
        data=json.dumps({'body':BODY}).encode('utf-8'),
        headers={'Content-Type':'application/json'}, method='POST')
    resp3=urllib.request.urlopen(req3); print(f'Comment: {resp3.status}')
except urllib.error.HTTPError as e:
    print(f'ERR: {e.status} {e.read().decode()[:300]}')

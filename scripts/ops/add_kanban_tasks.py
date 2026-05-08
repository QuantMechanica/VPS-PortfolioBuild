"""Add Wave 2 + research source tasks to kanban CSV."""
import csv, io
from pathlib import Path

csv_path = Path('C:/QM/paperclip/kanban/company_kanban.csv')
rows = list(csv.DictReader(csv_path.open(encoding='utf-8')))
fieldnames = list(csv.DictReader(csv_path.open(encoding='utf-8')).fieldnames)

# Kill QM-00066 — p3_param_sweep.py already exists; superseded by parallel rewrite
for r in rows:
    if r['task_id'] == 'QM-00066':
        r['status'] = 'killed'
        r['notes'] = (r.get('notes', '') + ' | KILLED 2026-05-08: script already exists; superseded by QM-00091 (5-terminal parallel rewrite).').strip()

new_tasks = [
    dict(
        task_id='QM-00091', process='pipeline_infra', phase='P3', assignee='cto',
        status='queued', priority='P0', created='2026-05-08', started='', deadline='2026-05-08',
        depends_on='', paperclip_issue_id='37018eba-1ca4-47e4-b334-647af8978f43',
        title='CTO: rewrite p3_param_sweep.py for 5-terminal parallel dispatch via pipeline_dispatcher.py',
        evidence_paths='C:/QM/repo/framework/scripts/p3_param_sweep.py',
        notes='OWNER P0 directive 2026-05-08. Use subprocess.Popen to launch up to 5 run_smoke.ps1 in parallel. Assign terminals via pipeline_dispatcher.py (42 symbols affinitized in dispatch_state.json). Poll completions, refill queue immediately. Write CSV rows as each subprocess finishes. Fix must land on main branch not board-advisor only (QUA-848 lesson). Deadline: today.',
    ),
    dict(
        task_id='QM-00092', process='pipeline_wave2', phase='P1', assignee='development',
        status='queued', priority='P0', created='2026-05-08', started='', deadline='',
        depends_on='QM-00091', paperclip_issue_id='74e48f95-4ca0-4a3e-9e8b-fba9a497b9d7',
        title='Development: build Wave 2 EAs from approved cards (1010-1016 lien + 1018/1019 williams)',
        evidence_paths='C:/QM/repo/strategy-seeds/cards/',
        notes='9 APPROVED cards unbuilt. EA build = minutes each. Order: 1010 lien-waiting-deal, 1011 lien-inside-day-breakout, 1012 lien-fader, 1013 lien-20day-breakout, 1014 lien-channels, 1015 lien-perfect-order, 1016 lien-carry-trade. williams-pinch-paunch + williams-pro-go need IDs 1018/1019 assigned in ea_id_registry.csv first. P1 validate each then enter P2 with 5-terminal parallel sweep.',
    ),
    dict(
        task_id='QM-00093', process='research_sources', phase='G0', assignee='research',
        status='queued', priority='P1', created='2026-05-08', started='', deadline='',
        depends_on='', paperclip_issue_id='',
        title='Research: inventory all unprocessed Drive PDFs + V4 notes — assign SRC numbers',
        evidence_paths='G:/My Drive/QuantMechanica - Company Reference/strategy-seeds/sources/',
        notes='One-time. Scan Drive for uploaded trading books not yet assigned a SRC number. Check V4 strategy notes for untested ideas. Output: strategy-seeds/sources/SOURCE_REGISTRY.md (SRC number, title, status: queued/in_progress/exhausted, card count). Assign SRC05+ sequentially, highest-signal-quality first.',
    ),
    dict(
        task_id='QM-00094', process='research_sources', phase='G0', assignee='research',
        status='queued', priority='P1', created='2026-05-08', started='', deadline='',
        depends_on='QM-00093', paperclip_issue_id='',
        title='Research: SRC05 MQL5 community articles — batch 3 cards per run (ENDLESS)',
        evidence_paths='strategy-seeds/sources/SRC05/',
        notes='ENDLESS SOURCE. mql5.com/en/articles — hundreds of coded+backtested forex strategies. Highest signal: rules already in code. Batch: up to 3 cards per run, submit to QB G0, repeat indefinitely. Focus: trend-following, breakout, mean-reversion, carry. Skip: ML-heavy (V5 no-ML rule).',
    ),
    dict(
        task_id='QM-00095', process='research_sources', phase='G0', assignee='research',
        status='queued', priority='P1', created='2026-05-08', started='', deadline='',
        depends_on='', paperclip_issue_id='',
        title='Research: SRC06 Academic quant papers — momentum/carry/trend factor canon (ENDLESS)',
        evidence_paths='strategy-seeds/sources/SRC06/',
        notes='ENDLESS SOURCE. SSRN + arXiv quant finance. Priority: AQR momentum/carry/trend (Asness, Moskowitz, Pedersen), TSMOM, FX carry. Proven factor premia with high P2/P3 survival probability. Batch: up to 3 cards per run. Cards must map paper rules to MQL5-implementable logic (no portfolio optimization or PCA).',
    ),
    dict(
        task_id='QM-00096', process='research_sources', phase='G0', assignee='research',
        status='queued', priority='P2', created='2026-05-08', started='', deadline='',
        depends_on='', paperclip_issue_id='',
        title='Research: SRC07 Forex Factory Strategy subforum — batch extraction (ENDLESS)',
        evidence_paths='strategy-seeds/sources/SRC07/',
        notes='ENDLESS SOURCE. forexfactory.com/forum/trading-systems — community rule-based systems. Quality varies; QB G0 is the filter. Focus on threads 50+ pages with documented rules. Batch: up to 3 cards per run.',
    ),
    dict(
        task_id='QM-00097', process='research_sources', phase='G0', assignee='research',
        status='queued', priority='P2', created='2026-05-08', started='', deadline='',
        depends_on='', paperclip_issue_id='',
        title='Research: SRC08 Babypips School + forums — rule-codeable setups (one-time)',
        evidence_paths='strategy-seeds/sources/SRC08/',
        notes='babypips.com School of Pipsology + trading system forum. Retail-oriented but clearly-stated rule-based setups. One-time scan. Estimated 5-10 cards total then largely exhausted.',
    ),
    dict(
        task_id='QM-00098', process='research_sources', phase='G0', assignee='research',
        status='queued', priority='P2', created='2026-05-08', started='', deadline='',
        depends_on='', paperclip_issue_id='',
        title='Research: SRC09 QuantConnect community + Alpha Streams — adaptable strategies (recurring)',
        evidence_paths='strategy-seeds/sources/SRC09/',
        notes='quantconnect.com community strategies. Python quant logic adapted to MQL5 rules. Focus on strategies with clear descriptions not just code dumps. Batch: up to 3 cards per run.',
    ),
    dict(
        task_id='QM-00099', process='research_sources', phase='G0', assignee='ceo',
        status='queued', priority='P2', created='2026-05-08', started='', deadline='',
        depends_on='', paperclip_issue_id='',
        title='CEO: wire YouTube Analyst into Research pipeline — SRC10 strategy extraction (ENDLESS)',
        evidence_paths='',
        notes='YouTube Analyst agent already hired and idle. CEO to update YouTube Analyst + Research instructions to establish handoff: YouTube Analyst watches trading strategy channels, extracts rule-codeable setups, passes summaries to Research for card drafting. ENDLESS SOURCE — runs continuously as new content published.',
    ),
    dict(
        task_id='QM-00100', process='research_sources', phase='G0', assignee='research',
        status='queued', priority='P3', created='2026-05-08', started='', deadline='',
        depends_on='QM-00093', paperclip_issue_id='',
        title='Research: SRC11-SRC14 non-English sources RU/CN/JP/IN — plan + batch extraction (ENDLESS)',
        evidence_paths='strategy-seeds/sources/',
        notes='ENDLESS + LARGELY UNTAPPED. SRC11: Russian SmartLab (smart-lab.ru). SRC12: Chinese Joinquant/RiceQuant. SRC13: Japanese retail algo communities. SRC14: Indian QuantInsti/Zerodha Varsity. Requires translation pipeline. First task: Research creates SOURCE_REGISTRY.md entries for these sources. Then same 3-cards-per-batch pattern. Lower priority than English sources but large untapped volume.',
    ),
]

rows.extend(new_tasks)

out = io.StringIO()
writer = csv.DictWriter(out, fieldnames=fieldnames, lineterminator='\n')
writer.writeheader()
writer.writerows(rows)

csv_path.write_text(out.getvalue(), encoding='utf-8')
print(f'Written {len(rows)} rows total ({len(new_tasks)} new tasks added, QM-00066 killed)')
print('New: QM-00091 through QM-00100')

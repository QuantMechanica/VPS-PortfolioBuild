"""Mint the Mission-Control card OWNER-DEC-COUNTER-PATH-CALENDAR-TAINT-20260907 (ROT: activate the scoped news-calendar
consumer B for counting, or wait for the full-scope seal) + execution plan; commit Vorlage and config with pathspecs.
Pattern: session_tools/dsr_declaration_card_0906.py (OWNER 2026-08-24: one decision-bound Claude task per terminal receipt).
"""
import datetime
import json
import subprocess
import sys
import time
from pathlib import Path

REPO = Path('C:/QM/repo')
sys.path.insert(0, str(REPO / 'tools' / 'strategy_farm'))
import owner_decision_store as store  # noqa: E402
import owner_decision_execution as execution  # noqa: E402

now = datetime.datetime.now(datetime.timezone.utc)
NOW_ISO = now.replace(microsecond=0).isoformat().replace('+00:00', 'Z')
TRAILER = '\n\nCo-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_018mXkPPkaHQ2fPuduPCBcWc\n'
VP = 'docs/ops/OWNER_VORLAGE_2026-09-07_counter_path_calendar_taint.md'
CID = 'OWNER-DEC-COUNTER-PATH-CALENDAR-TAINT-20260907'


def git(*a):
    return subprocess.run(['git', *a], capture_output=True, text=True, cwd=REPO)


def commit(files, text):
    git('add', *files)
    msg = REPO / 'artifacts/_commit_msg_tmp.txt'
    msg.write_text(text + TRAILER, encoding='utf-8')
    r = None
    for _ in range(5):
        r = git('commit', '-q', '-F', str(msg), *files)
        if r.returncode == 0:
            break
        time.sleep(5)
    msg.unlink(missing_ok=True)
    return git('rev-parse', '--short=10', 'HEAD').stdout.strip(), r.returncode, (r.stdout + r.stderr)[-300:]


sha, rc, out = commit([VP, 'tools/strategy_farm/session_tools/counter_path_calendar_card_0907.py'],
                      'docs(ops): OWNER Vorlage - counter path frozen at the news-calendar taint (ROT: option B scoped consumer for counting vs wait for the full-scope seal; recommendation A today, resubmission Wed 09.09.)')
print('vorlage commit', sha, rc, out if rc else '')

CARD = {
    "category": "Pipeline/News-Kalender",
    "cost_of_wait": "Pro Tag 0 Zaehlerfortschritt: 47 Q10_NEWS-Zeilen + 11196/XAUUSD (Q02-Q09 PASS, DSR V2 bestanden) warten im Kalender-Taint-Hold; der Zaehler bleibt strukturell bei 12/25, unabhaengig vom Fabrikdurchsatz. Vollsiegel (E1-D2-D4 bei Codex) braucht Tage: AUD/CAD-M5-Exporte, Nicht-USD-Anker, 2.591 unverifizierte Zeilen, Kandidat neu bauen. Fruehester ehrlicher Termin Mittwoch 09.09.",
    "created_at_utc": NOW_ISO,
    "depends_on": [],
    "due": "2026-09-09",
    "evidence": [VP, "docs/ops/evidence/2026-09-07_news_calendar_e1d_full_scope_seal.md", "docs/ops/evidence/2026-09-06_dsr-single-config-declaration-20260906_5bf3bf5e_execution.md", "docs/ops/OWNER_VORLAGE_2026-09-05_news_calendar_defect.md"],
    "id": CID,
    "no_effect": "Option A (Empfehlung heute): Vollsiegel abwarten, Q10_NEWS bleibt im Taint-Hold, Wiedervorlage Mittwoch 09.09. 08:00 als To-Do; E1-D2-D4 laufen weiter; kein Code, kein Repin.",
    "question": "Zaehler-Pfad: Soll der scoped news-calendar consumer B (seit 05.09. implementiert, inaktiv) fuer die Q10_NEWS-Adjudikation AKTIVIERT und die so passierten D1/USD-Paare als zaehlbar akzeptiert werden (Option B, Fussnote 'Kalender scope-begrenzt', Re-Adjudikation nach Vollsiegel) - oder warten wir auf das Vollsiegel (Option A)?",
    "recommendation": "NEIN heute = Option A (Vollsiegel abwarten, E1-D2-D4 laufen), mit fester Wiedervorlage Mittwoch 09.09. 08:00. Liefert E1-D3/D4 bis dahin keinen Vollsiegel-Dry-Run, empfehle ich B fuer die D1-USD-Teilmenge als eigenen JA-Entscheid. Zwei Tage Wartezeit sind billiger als eine Zaehlung, die nach dem Repin neu angefasst werden muss.",
    "severity": "action",
    "status": "OPEN",
    "yes_effect": "Option B: genau EIN Claude-Auftrag - Codex-Ticket (scoped consumer B aktivieren; Taint-Policy-Lift nur fuer B-adjudizierte Zeilen, alle anderen bleiben im Hold; Zaehler-Fussnote in Cockpit/OPEN_ITEMS/Vault; Re-Adjudikationspflicht nach Vollsiegel als Ticket), zeilenweise Freigabe der 47+1 Zeilen append-only, priority_track auf 11196. Kein Repin, kein Kalender-Publish, kein T_Live, kein Gate-Schwellenwert. Reversibel (Policy zurueck auf inaktiv; Evidenz bleibt).",
}
PLAN = {
    "id": CID,
    "todo_id": "QM-TODO-20260907-COUNTER-PATH-CALENDAR-TAINT",
    "priority": 90,
    "choices": {
        "YES": {"mode": "APPLY_AND_VERIFY", "objective": "Adopt Option B: activate the scoped news-calendar consumer B for Q10_NEWS adjudication; lift the taint hold only for rows B adjudicates (declared exclusions stay held); footnote every pair counted this way as 'calendar scope-limited' in cockpit, OPEN_ITEMS and the Vault; open the re-adjudication-after-full-seal ticket. No repin, no calendar publish, no T_Live/AutoTrading, no threshold change.", "allowed_actions": ["Enqueue one Codex ops ticket with exact acceptance criteria (consumer B activation config + taint-policy lift scope + counter footnote + re-adjudication ticket)", "Integrate the Codex branch (tests, Codex co-author trailer)", "farmctl release-hold row by row for B-admissible Q10_NEWS rows (append-only, never a verdict overwrite); mark-priority-track on 11196/XAUUSD", "Update OPEN_ITEMS, the receipts file and the Vault"], "acceptance": ["Consumer B active only for declared-admissible rows; excluded rows remain held", "Every counted pair carries the scope-limited footnote in all OWNER surfaces", "Re-adjudication ticket exists and is bound to the full-scope seal", "No repin, publish, threshold or stored-verdict change"]},
        "NO": {"mode": "DOCUMENT_AND_VERIFY", "objective": "Record Option A: wait for the full-scope seal (E1-D2-D4), keep the taint hold, add the OWNER to-do for the Wednesday 2026-09-09 08:00 resubmission; no code change.", "allowed_actions": ["Document in OPEN_ITEMS_STATUS.md, the receipts file and the Vault", "owner_todos.py add for the resubmission"], "acceptance": ["Taint hold unchanged", "Resubmission to-do exists with due 2026-09-09"]},
    },
}
CONTRACT = REPO / 'tools/strategy_farm/config/owner_decision_execution.v1.json'
SEED = REPO / 'tools/strategy_farm/config/owner_decisions.v2.bootstrap.json'


def load_json(p):
    raw = p.read_bytes()
    return json.loads(raw.decode('utf-8-sig')), (b'\r\n' in raw)


def dump_json(p, obj, use_crlf):
    text = json.dumps(obj, ensure_ascii=False, indent=2)
    p.write_bytes((text.replace('\n', '\r\n') if use_crlf else text).encode('utf-8'))


c, cc = load_json(CONTRACT)
if CID not in {d['id'] for d in c['decisions']}:
    c['decisions'].append(PLAN)
    dump_json(CONTRACT, c, cc)
seed, sc = load_json(SEED)
if CID not in {i['id'] for i in seed['items']}:
    seed['items'].append(CARD)
    seed['revision'] = int(seed.get('revision') or 0) + 1
    store.validate_feed(seed)
    dump_json(SEED, seed, sc)
with store.exclusive_store_lock(store.DEFAULT_FEED):
    feed = store.load_feed(store.DEFAULT_FEED)
    if CID not in {i['id'] for i in feed['items']}:
        feed['items'].append(json.loads(json.dumps(CARD)))
        feed['revision'] = int(feed['revision']) + 1
        feed['updated_at_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        store.validate_feed(feed)
        store._write_json(store.DEFAULT_FEED, feed)
        print('feed revision', feed['revision'])
try:
    store.sync_vault_queue(feed)
    print('vault synced')
except Exception as exc:  # noqa: BLE001
    print('vault sync failed:', exc)
print(CID, 'ready', execution.plan_summary(CID).get('ready'))
r = subprocess.run([sys.executable, 'tools/strategy_farm/render_cockpit_v2.py'], capture_output=True, text=True, cwd=REPO)
print((r.stdout + r.stderr).strip()[-80:])
sha2, rc2, out2 = commit(['tools/strategy_farm/config/owner_decision_execution.v1.json', 'tools/strategy_farm/config/owner_decisions.v2.bootstrap.json'],
                         'mission-control: ' + CID + ' card + plan (ROT: scoped consumer B for counting vs full-scope seal; recommendation A today, resubmission Wed 09.09.)')
print('card commit', sha2, rc2, out2 if rc2 else '')

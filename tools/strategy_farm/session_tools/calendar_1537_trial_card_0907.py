"""Mint the Mission-Control card OWNER-DEC-1537-TRIAL-CALENDAR-SOURCE-20260907 (declared source change: native
Darwinex D1 continuation for the QM5_1537 monthly sleeve calendar in the FTMO trial) + execution plan.
Pattern: session_tools/counter_path_calendar_card_0907.py.
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
VP = 'docs/ops/OWNER_VORLAGE_2026-09-07_1537_trial_calendar_source.md'
CID = 'OWNER-DEC-1537-TRIAL-CALENDAR-SOURCE-20260907'


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


sha, rc, out = commit([VP, 'tools/strategy_farm/session_tools/calendar_1537_trial_card_0907.py'],
                      'docs(ops): OWNER Vorlage - QM5_1537 trial calendar continuation from native Darwinex D1 (declared source change); recommendation A')
print('vorlage commit', sha, rc, out if rc else '')

CARD = {
    "category": "FTMO/Live-Readiness",
    "cost_of_wait": "QM5_1537 handelt im FTMO-Trial nicht (calendar_stale fuer 2026-09) und waere so auch live inert; jeder Trial-Tag ohne 1537 ist ein Sleeve weniger Evidenz. Der Kalender laesst sich aus den heutigen Quellen nicht verlaengern (Fabrik-History endet 2024-12-31; Broker-Caches unvollstaendig).",
    "created_at_utc": NOW_ISO,
    "depends_on": [],
    "due": "2026-09-08",
    "evidence": [VP, "docs/ops/evidence/86b7dfb5_qm5_1537_calendar_staleness_recovery_2026-09-07.md", "framework/EAs/QM5_1537_aa-vol-sma10/calendar/QM5_1537_monthly_sleeves_v1.csv"],
    "id": CID,
    "no_effect": "Option B: 1537 verlaesst den FTMO-Trial (OWNER entfernt den XAGUSD-Chart), Kalender bleibt v1, Dokumentation; live-Untauglichkeit bleibt offen bis zum Fabrik-History-Nachzug.",
    "question": "QM5_1537: Darf der Monats-Sleeve-Kalender fuer den FTMO-Trial (und spaeter live) ab 2025-01 aus nativer Darwinex-D1-History (T_Export-Lane, alle 37 Universum-Symbole, identischer Ranking-Vertrag) als DEKLARIERTER Quellenwechsel fortgeschrieben werden (Kalender v2, neue SHA, Preset-Re-Pin, monatlicher Refresh)?",
    "recommendation": "JA (Option A). v1 bleibt unveraendert und append-only; jede neue Zeile traegt ihre Quelle; Vergleichslauf gegen die Fabrik-History, sobald diese nachgezogen ist. Codex prueft zugleich 21505 und weitere kalender-/planbasierte Sleeves auf dieselbe Klasse.",
    "severity": "action",
    "status": "OPEN",
    "yes_effect": "Genau EIN Claude-Auftrag: Codex-Ticket (T_Export-D1-Download + Export der 37 Symbole mit Receipt, Builder-Erweiterung mit Quellen-Deklaration je Zeile, Kalender v2 + Manifest, Preset-Re-Pin als neue Set-Version, Demo-Install mit Receipt + OWNER-3-Zeilen, Refresh-Regel am 1. Handelstag, M13-Manifest-Nachtrag). Kein T_Live, kein AutoTrading, keine Q-Gate-Aenderung.",
}
PLAN = {
    "id": CID,
    "todo_id": "QM-TODO-20260907-1537-TRIAL-CALENDAR-SOURCE",
    "priority": 82,
    "choices": {
        "YES": {"mode": "APPLY_AND_VERIFY", "objective": "Adopt option A: continue the QM5_1537 monthly sleeve calendar from 2025-01 with native Darwinex D1 (all 37 universe symbols via the governed T_Export lane) under the identical ranking contract as a declared source change: calendar v2 (v1 rows untouched), new sha, preset re-pin as a new set version, FTMO demo install with receipt, OWNER re-attach, monthly refresh rule, M13 manifest addendum. No T_Live, no AutoTrading, no Q-gate change.", "allowed_actions": ["Enqueue one Codex ops ticket with exact acceptance criteria", "Integrate the Codex branch (tests, LF/byte checks, co-author trailer)", "Verify the demo install receipt and the calendar v2 sha; hand the OWNER the 3-line re-attach instruction", "Update OPEN_ITEMS, the M13 manifest and the Vault"], "acceptance": ["Calendar v2 rows 2025-01..2026-09 exist for the XAG host with declared source per row; v1 rows byte-identical", "EA reports MONTHLY_SLEEVE_STATE ready=true for 202609 on the demo after re-attach", "Presets/manifest re-pinned append-only; factory EX5 untouched", "No T_Live/AutoTrading/threshold change"]},
        "NO": {"mode": "DOCUMENT_AND_VERIFY", "objective": "Option B: remove QM5_1537 from the FTMO trial (OWNER detaches the XAGUSD chart), keep calendar v1, document the live-readiness gap for the factory-history backfill.", "allowed_actions": ["Document in OPEN_ITEMS_STATUS.md, the M13 manifest and the Vault", "owner_todos.py add for the chart removal"], "acceptance": ["1537 documented as removed from the trial", "No calendar change"]},
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
sha2, rc2, out2 = commit(['tools/strategy_farm/config/owner_decision_execution.v1.json', 'tools/strategy_farm/config/owner_decisions.v2.bootstrap.json'],
                         'mission-control: ' + CID + ' card + plan (declared source change for the 1537 trial calendar; recommendation A)')
print('card commit', sha2, rc2, out2 if rc2 else '')

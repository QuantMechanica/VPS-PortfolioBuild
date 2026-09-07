"""Mint the Mission-Control card OWNER-DEC-CALENDAR-CRITERIA-B-PRIME-20260907 (ROT: full-scope seal = measured gates +
declared residuals; consumer B admissibility beyond D1 for USD-only exposure) + execution plan; commit Vorlage/config with pathspecs.
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
VP = 'docs/ops/OWNER_VORLAGE_2026-09-07_calendar_criteria_b_prime.md'
CID = 'OWNER-DEC-CALENDAR-CRITERIA-B-PRIME-20260907'


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


sha, rc, out = commit([VP, 'tools/strategy_farm/session_tools/calendar_criteria_b_prime_card_0907.py'],
                      'docs(ops): OWNER Vorlage B-prime - news-calendar criteria decision (measured gates + declared residuals; consumer B beyond D1 for USD-only exposure); recommendation JA')
print('vorlage commit', sha, rc, out if rc else '')

CARD = {
    "category": "Pipeline/News-Kalender",
    "cost_of_wait": "Consumer B (dein JA von heute) laesst unter den heutigen Kriterien 0 von 47 Zeilen zu; 11196/XAUUSD ist H4 und bleibt ausgeschlossen. Ohne B-prime bleibt jeder Intraday-USD-Kandidat ohne Endpunkt; nur die 9 D1/USD-Zeilen laufen nach dem Fenster-Siegel. Pro Tag 0 Zaehlerfortschritt fuer Intraday-Paare.",
    "created_at_utc": NOW_ISO,
    "depends_on": ["OWNER-DEC-COUNTER-PATH-CALENDAR-TAINT-20260907"],
    "due": "2026-09-08",
    "evidence": [VP, "docs/ops/evidence/2026-09-07_f3a94b87_scoped_calendar_b_activation.md", "docs/ops/evidence/2026-09-07_f3a94b87_scoped_calendar_b_dry_run.json", "docs/ops/evidence/2026-09-07_news_calendar_e1d34_continuation.md", "docs/ops/evidence/2026-09-05_news_calendar_timestamp_defect.md"],
    "id": CID,
    "no_effect": "Kriterien unveraendert (alle acht Gates muessen gemessen PASS sein); Consumer B bleibt D1-only. Die 9 D1/USD-Zeilen laufen nach dem Fenster-Siegel; 11196 und alle Intraday-Zeilen bleiben im Hold; Dokumentation.",
    "question": "B-prime (ROT, Gate-Kriterium): Darf der E1-D3/D4-Kandidatenkalender (USD-08:30-ET-Zeilen aus dem nativen MT5-Export korrigiert, Manifest 5f28c2f3..., Bindung b12615d8...) als Adjudikationsbasis fuer Q10_NEWS gelten fuer USD-exponierte Zeilen ALLER Timeframes, mit deklarierten Residuen fuer Nicht-USD-Klassen und Event-by-Event-Eintraege ohne offiziellen Zeitplan (betroffene Zeilen bleiben gehalten) - statt der heutigen Regel 'alle acht Gates gemessen PASS'?",
    "recommendation": "JA. Gemessen wird weiter alles Messbare; deklariert nur, was nachweislich nicht messbar ist (1.865 Event-by-Event-Zeilen ohne Quelle, Footprints jenseits der History bis 2024-12-31). Jede so adjudizierte Zeile traegt Marker + Fussnote 'Kalender scope-begrenzt' und wird bei einem besseren Kalender append-only neu adjudiziert (Ticket 235e5119). Damit wird 11196/XAUUSD (H4, USD-exponiert) adjudizierbar.",
    "severity": "action",
    "status": "OPEN",
    "yes_effect": "Genau EIN Claude-Auftrag: Codex-Ticket (Kriterium 'measured + declared residual' im Kalender-Gate-Vertrag formalisieren; Consumer-B-Zulaessigkeit auf alle Timeframes bei USD-only-Exposition erweitern, Nicht-USD-Klassen je Zeile deklariert = Zeile bleibt gehalten; Tests; neuer Dry-Run), danach zeilenweise Freigabe append-only (11196 zuerst), Fussnote bleibt, Re-Adjudikationsticket bleibt gebunden. Kein Repin des Produktionsbundles, kein Publish, kein T_Live, keine Q-Gate-Schwelle.",
}
PLAN = {
    "id": CID,
    "todo_id": "QM-TODO-20260907-CALENDAR-CRITERIA-B-PRIME",
    "priority": 91,
    "choices": {
        "YES": {"mode": "APPLY_AND_VERIFY", "objective": "Adopt B-prime: formalize 'measured gates + declared residuals' as the full-scope admission criterion in the calendar gate contract; extend consumer B admissibility beyond D1 for USD-only exposure (rows with non-USD exposure stay held); rerun the dry run; release admissible rows row by row (11196/XAUUSD first) with marker + footnote; keep the re-adjudication ticket bound. No production repin/publish, no T_Live/AutoTrading, no Q-gate threshold change.", "allowed_actions": ["Enqueue one Codex ops ticket with exact acceptance criteria", "Integrate the Codex branch (tests, LF check, Codex co-author trailer); worker reload if the claim guard changes", "news_calendar_taint release_scoped_item / farmctl release-hold row by row for admissible rows (append-only)", "Update OPEN_ITEMS, the receipts file and the Vault"], "acceptance": ["Criterion recorded in the gate contract with the exact residual classes", "Consumer B admits USD-only rows of any timeframe and still refuses non-USD-exposed rows", "Released rows carry the marker + footnote; first adjudications end PASS/FAIL (not INVALID)", "No production repin/publish/threshold/verdict change"]},
        "NO": {"mode": "DOCUMENT_AND_VERIFY", "objective": "Keep the current criterion; consumer B stays D1-only; document; the nine D1/USD rows proceed after the window seal.", "allowed_actions": ["Document in OPEN_ITEMS_STATUS.md, the receipts file and the Vault"], "acceptance": ["No criterion change", "Intraday rows remain held"]},
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
                         'mission-control: ' + CID + ' card + plan (ROT: measured gates + declared residuals; consumer B beyond D1 for USD-only exposure; recommendation JA)')
print('card commit', sha2, rc2, out2 if rc2 else '')

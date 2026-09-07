"""Mint the Mission-Control card OWNER-DEC-Q09-LEGACY-LOGGER-SAMPLE-20260907 (ROT-adjacent: P1 evidence-integrity control
scope for pre-2026-07-20 builds in the Q09 v3 selection run) + execution plan; commit Vorlage/config with pathspecs.
Pattern: session_tools/calendar_criteria_b_prime_card_0907.py.
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
VP = 'docs/ops/OWNER_VORLAGE_2026-09-07_q09_legacy_logger_sample.md'
CID = 'OWNER-DEC-Q09-LEGACY-LOGGER-SAMPLE-20260907'


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


sha, rc, out = commit([VP, 'tools/strategy_farm/session_tools/legacy_logger_sample_card_0907.py'],
                      'docs(ops): OWNER Vorlage - Q09/Q10_NEWS adjudication for pre-2026-07-20 builds (legacy logger sample without sv); recommendation A')
print('vorlage commit', sha, rc, out if rc else '')

CARD = {
    "category": "Pipeline/Evidenz-Integritaet",
    "cost_of_wait": "Die erste B-prime-Adjudikation (11167/XAUUSD) hat 9 h T2 ohne ein authentifiziertes Zellergebnis verbraucht. 10 von 54 Q10_NEWS-Kandidaten (3 der 11 freigegebenen B-prime-Zeilen) sind Builds vor dem 20.07. und scheitern am selben Guard; jeder weitere Claim einer solchen Zeile verbrennt einen 9-h-Slot. 11196 ist bis zum Entscheid von der Prioritaetsspur genommen.",
    "created_at_utc": NOW_ISO,
    "depends_on": ["OWNER-DEC-CALENDAR-CRITERIA-B-PRIME-20260907"],
    "due": "2026-09-08",
    "evidence": [VP, "docs/ops/evidence/2026-09-07_calendar-criteria-b-prime-20260907_617abd80_execution.md"],
    "id": CID,
    "no_effect": "Option C: Pre-sv-Zeilen (10148, 10476, 10771x2, 11179, 11196, 1230x2, 12474, 9573; 11167 REVIEW_REQUIRED) werden dokumentiert geparkt und bleiben ohne Prioritaetsspur; die 7 Post-sv-B-prime-Zeilen laufen weiter. Option B (Neubau, neue Identitaet ab Q02) nur per separatem Bauauftrag.",
    "question": "Q09-v3-Selektionslauf: Darf run_smoke fuer EX5-Builds vor dem 20.07.2026 (vor der P1-Evidenzintegritaetskontrolle 6e92c80626) ein frisches Logger-Sample OHNE das Pflichtfeld sv als deklariertes Residuum akzeptieren (alle uebrigen Pflichtfelder, ea_id/magic-Bindung und Frische gegen das Pre-Run-Archiv bleiben Pflicht; Receipt-Feld logger_sample_authentication=legacy_no_sv), damit die 10 Pre-sv-Kandidaten des Zaehlerpfads adjudizierbar werden - statt Neubau (B) oder Parken (C)?",
    "recommendation": "JA (Option A). Die Kontrolle bleibt fuer alle Builds nach dem 20.07. unveraendert; fuer Altbestaende wird das Residuum deklariert statt die Adjudikation verweigert. Danach 11167 als Append-only-Rerun und 11196 zurueck auf die Prioritaetsspur.",
    "severity": "action",
    "status": "OPEN",
    "yes_effect": "Genau EIN Claude-Auftrag: Codex-Ticket (Guard-Zweig in run_smoke.ps1 nur unter -RequireFreshLoggerSample und nur fuer Builds vor 6e92c80626, Tests mit Pre-/Post-sv-Fixtures, Receipt-Feld + Fussnote), Integration, dann Reruns: 11167 append-only (--append-only-rerun-of f625d9aa), 11196 Prioritaetsspur zurueck, uebrige Pre-sv-Zeilen in Freigabe-Reihenfolge. Kein Repin, kein Publish, kein T_Live, keine Schwelle, kein Verdict-Overwrite.",
}
PLAN = {
    "id": CID,
    "todo_id": "QM-TODO-20260907-Q09-LEGACY-LOGGER-SAMPLE",
    "priority": 90,
    "choices": {
        "YES": {"mode": "APPLY_AND_VERIFY", "objective": "Option A: accept a fresh structured logger sample without the sv field as a declared residual in the Q09 v3 selection run for EX5 builds older than the P1 evidence-integrity control (6e92c80626, 2026-07-20); all other required fields, ea_id/magic binding and freshness against the pre-run archive stay mandatory; receipt field logger_sample_authentication=legacy_no_sv + footnote. Then append-only reruns for 11167 and the pre-sv candidates. No threshold/verdict/T_Live change.", "allowed_actions": ["Enqueue one Codex ops ticket with exact acceptance criteria (run_smoke.ps1 guard branch, tests, receipt field)", "Integrate the Codex branch (tests, LF/byte checks, co-author trailer)", "farmctl enqueue-backtest --append-only-rerun-of f625d9aa… for 11167; mark-priority-track for 11196; releases in the B-prime order", "Update OPEN_ITEMS, the B-prime execution record and the Vault"], "acceptance": ["Guard accepts legacy samples only for pre-6e92c80626 builds and only under -RequireFreshLoggerSample; post-sv builds unchanged (tests)", "Receipt/footnote carry logger_sample_authentication=legacy_no_sv", "11167 rerun ends PASS/FAIL (not REVIEW_REQUIRED cell_execution_failed)", "No threshold/verdict/T_Live change"]},
        "NO": {"mode": "DOCUMENT_AND_VERIFY", "objective": "Option C: park the pre-sv Q10_NEWS candidates (documented, no priority track); the 7 post-sv B-prime rows continue; option B only via a separate build order.", "allowed_actions": ["Document in OPEN_ITEMS_STATUS.md, the B-prime execution record and the Vault"], "acceptance": ["Pre-sv rows documented as parked", "No guard change"]},
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
                         'mission-control: ' + CID + ' card + plan (legacy logger sample for pre-2026-07-20 builds in the Q09 v3 selection run; recommendation JA)')
print('card commit', sha2, rc2, out2 if rc2 else '')

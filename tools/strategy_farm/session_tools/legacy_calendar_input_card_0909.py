"""Mint the Mission-Control card OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909 (second, earlier
legacy boundary: EX5 builds before f0102fbcf2/2026-08-03 lack the calendar-bundle input fields
entirely, so `_validate_report_effective_inputs` can never pass for them) + execution plan;
commit Vorlage/config with pathspecs.
Pattern: session_tools/legacy_logger_sample_card_0907.py.
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
TRAILER = '\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\n'
VP = 'docs/ops/OWNER_VORLAGE_2026-09-09_q09_legacy_calendar_input.md'
CID = 'OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909'


def git(*a):
    return subprocess.run(['git', *a], capture_output=True, text=True, cwd=REPO)


def commit(files, text):
    git('add', *files)
    msg = REPO / 'artifacts/_commit_msg_tmp.txt'
    msg.parent.mkdir(parents=True, exist_ok=True)
    msg.write_text(text + TRAILER, encoding='utf-8')
    r = None
    for _ in range(5):
        r = git('commit', '-q', '-F', str(msg), *files)
        if r.returncode == 0:
            break
        time.sleep(5)
    msg.unlink(missing_ok=True)
    return git('rev-parse', '--short=10', 'HEAD').stdout.strip(), r.returncode, (r.stdout + r.stderr)[-300:]


sha, rc, out = commit([VP, 'tools/strategy_farm/session_tools/legacy_calendar_input_card_0909.py'],
                      'docs(ops): OWNER Vorlage - Q09/Q10_NEWS second legacy boundary (pre-2026-08-03 builds lack calendar-bundle inputs entirely); recommendation A')
print('vorlage commit', sha, rc, out if rc else '')

CARD = {
    "category": "Pipeline/Evidenz-Integritaet",
    "cost_of_wait": "Jeder Pre-03.08-Build bleibt im B'-Zaehlerpfad strukturell unpassierbar; jeder Claim-Versuch verbrennt einen mehrstuendigen Tester-Slot ohne Endpunkt. 11167 hat bereits zwei solche Slots verbraucht (07.09. 07:18-16:00Z, 08.09. 14:40-15:15Z). 11196 bleibt von der Prioritaetsspur genommen.",
    "created_at_utc": NOW_ISO,
    "depends_on": ["OWNER-DEC-Q09-LEGACY-LOGGER-SAMPLE-20260907"],
    "due": "2026-09-11",
    "evidence": [VP, "docs/ops/evidence/2026-09-08_q09-legacy-logger-sample-20260907_821096ac_execution.md", "docs/ops/evidence/2026-09-07_calendar-criteria-b-prime-20260907_617abd80_execution.md"],
    "id": CID,
    "no_effect": "Option C: betroffene Zeilen bleiben dokumentiert ohne Prioritaetsspur geparkt; post-08.03-B'-Zeilen laufen unveraendert weiter.",
    "question": "Darf q09_news_runner.py::_validate_report_effective_inputs fuer EX5-Builds vor dem 03.08.2026-Commit (f0102fbcf2, git-archiviert, Baudatum exakt geprueft) das Fehlen der drei Kalender-Bundle-Input-Felder (qm_news_calendar_bundle_id/_expected_sha256/_common_relative_path) als deklariertes Residuum akzeptieren (Option A, analog zum sv-Praezedenzfall; alle anderen Effektiv-Input-Pruefungen bleiben scharf) - statt Neubau (B) oder Parken (C)?",
    "recommendation": "JA (Option A). Gleiche Begruendung wie beim sv-Praezedenzfall: das Residuum ist git-archiviert, exakt baudatumsgebunden und ehrlich deklariert. Schritt 1 (exakter betroffener Scope inkl. bereits freigegebener B'-Zeilen) ist unabhaengig von der Wahl zuerst noetig.",
    "severity": "action",
    "status": "OPEN",
    "yes_effect": "Genau EIN Claude-Auftrag: Codex-Ticket (Scope-Messung gegen die 03.08.-Grenze; Guard-Erweiterung nur fuer exakt git-archivierte Pre-f0102fbcf2-Builds, Tests, Receipt-Feld calendar_input_authentication=legacy_no_bundle_binding + Fussnote), danach ein 11167-Rerun (append-only) und bei PASS/FAIL-Ergebnis Rueckgabe der Prioritaetsspur an 11196. Kein Repin, kein Publish, kein T_Live, keine Schwelle, kein Verdict-Overwrite.",
}
PLAN = {
    "id": CID,
    "todo_id": "QM-TODO-20260909-Q09-LEGACY-CALENDAR-INPUT",
    "priority": 88,
    "choices": {
        "YES": {"mode": "APPLY_AND_VERIFY", "objective": "Option A: accept the absence of the three calendar-bundle input fields as a declared residual in _validate_report_effective_inputs for EX5 builds older than commit f0102fbcf2 (2026-08-03, calendar-bundle input introduction); all other effective-input checks (RISK_FIXED/RISK_PERCENT, seed, news temporal/compliance, stale-max) stay strict; receipt field calendar_input_authentication=legacy_no_bundle_binding + footnote. First measure exact affected scope (pending + already-released B' rows) against the 2026-08-03 boundary, then guard change with tests, then one append-only 11167 rerun. No threshold/verdict/T_Live change.", "allowed_actions": ["Enqueue one Codex ops ticket with exact acceptance criteria (scope measurement, guard branch, tests, receipt field)", "Integrate the Codex branch (tests, LF/byte checks, co-author trailer)", "farmctl enqueue-backtest --append-only-rerun-of for 11167; mark-priority-track for 11196 only after a terminal PASS/FAIL", "Update OPEN_ITEMS, this execution record and the Vault"], "acceptance": ["Exact affected scope measured and documented (pending + released B' rows vs the 2026-08-03 boundary)", "Guard accepts the declared residual only for exactly git-archived pre-f0102fbcf2 builds; post-boundary builds unchanged (tests)", "Receipt/footnote carry calendar_input_authentication=legacy_no_bundle_binding", "11167 rerun ends PASS/FAIL (not REVIEW_REQUIRED cell_execution_failed)", "No threshold/verdict/T_Live change"]},
        "NO": {"mode": "DOCUMENT_AND_VERIFY", "objective": "Option C: park the pre-2026-08-03 Q10_NEWS candidates (documented, no priority track); post-boundary B' rows continue unchanged.", "allowed_actions": ["Document in OPEN_ITEMS_STATUS.md, this execution record and the Vault"], "acceptance": ["Pre-boundary rows documented as parked", "No guard change"]},
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
                         'mission-control: ' + CID + ' card + plan (second legacy boundary: pre-2026-08-03 builds lack calendar-bundle inputs entirely; recommendation JA)')
print('card commit', sha2, rc2, out2 if rc2 else '')

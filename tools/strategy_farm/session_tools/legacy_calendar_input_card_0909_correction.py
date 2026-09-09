"""Correct the just-minted card OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909: a concurrent
session proved (QM_NewsFilter.mqh:69-76,744-763) that qm_news_calendar_bundle_id/_expected_sha256/
_common_relative_path are not provenance echo but functionally gate which calendar bundle the
tester loads (QM_NewsInitTesterBundle). A declared residual is therefore not a safe analogy to the
sv precedent (the sv gap left the underlying execution fully evidenced; this gap leaves the
calendar binding itself unverifiable). Replace Option A (declared residual) with the concurrent
session's better-supported framing: rebuild (staged, 11167 first) vs. park. Card is still OPEN
(no OWNER receipt yet) so an in-place correction, not a new card, is correct.
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


sha, rc, out = commit([VP],
                      'docs(ops): correct OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909 Vorlage - no safe declared-residual path (bundle inputs gate tester calendar load, not provenance echo); rebuild-vs-park')
print('vorlage correction commit', sha, rc, out if rc else '')

CARD_PATCH = {
    "question": "Es gibt keine belegte Deklarations-Option: qm_news_calendar_bundle_id/_expected_sha256/_common_relative_path steuern in QM_NewsInitTesterBundle() (QM_NewsFilter.mqh:744), welchen Kalender-Bundle der Tester laedt - kein Provenienz-Echo. Ein Alt-Binary ohne diese Inputs kann nicht nachweislich an den versiegelten Bundle gebunden werden. Soll Codex (1) den exakten betroffenen Scope vermessen (alle pending + freigegebenen B'-Zeilen gegen die 03.08.-Grenze, Commit f0102fbcf2) und (2) Option B (Neubau, gestuft mit 11167 zuerst, neue Identitaet ab Q02) vorbereiten - oder gilt bis auf Weiteres Option C (Parken)?",
    "recommendation": "B, aber gestuft (11167 zuerst). Neubau ist der einzig belegte Weg zu einem echten PASS/FAIL-Verdikt; ein deklariertes Residuum waere hier keine ehrliche Analogie zum sv-Fall, weil die Kalenderbindung selbst unverifizierbar bliebe. Alternativ C, falls der Rebuild-Aufwand jetzt nicht gewollt ist.",
    "no_effect": "Option C: betroffene Zeilen bleiben dokumentiert ohne Prioritaetsspur geparkt (dauerhaft REVIEW_REQUIRED); post-08.03-B'-Zeilen laufen unveraendert weiter.",
    "yes_effect": "Genau EIN Claude-Auftrag: Codex-Ticket (Scope-Messung gegen die 03.08.-Grenze; Neubau von QM5_11167 mit aktuellem Template als neue Identitaet ab Q02, kein Bestandsschutz fuer die alten Q02-Q09-Verdikte, altes Binary/alte Zeilen bleiben unveraendert als Evidenz stehen; Kohorte danach nachziehen). Kein Repin, kein Publish, kein T_Live, keine Schwelle, kein Verdict-Overwrite auf bestehenden Zeilen.",
}
PLAN_PATCH = {
    "YES": {
        "mode": "APPLY_AND_VERIFY",
        "objective": "Option B, staged: measure exact affected scope (pending + already-released B' rows) against the 2026-08-03 boundary (commit f0102fbcf2), then rebuild QM5_11167 with the current EA template as a new identity from Q02 (no continuity claimed for the old Q02-Q09 verdicts; old binary/rows stay untouched as evidence); cohort follow-up after 11167 proves the path. No threshold/verdict/T_Live change.",
        "allowed_actions": ["Enqueue one Codex ops ticket with exact acceptance criteria (scope measurement, then a governed Q02 rebuild order for QM5_11167 only)", "Integrate the Codex branch/build (tests, co-author trailer)", "farmctl enqueue new Q02 work item for the rebuilt QM5_11167 identity", "Update OPEN_ITEMS, this execution record and the Vault"],
        "acceptance": ["Exact affected scope measured and documented (pending + released B' rows vs the 2026-08-03 boundary)", "QM5_11167 rebuilt as a new identity from Q02 under the current template; old identity/evidence untouched", "No threshold/verdict/T_Live change", "No claimed continuity between old and new identity verdicts"],
    },
    "NO": {
        "mode": "DOCUMENT_AND_VERIFY",
        "objective": "Option C: park the pre-2026-08-03 Q10_NEWS candidates (documented, no priority track, permanently REVIEW_REQUIRED); post-boundary B' rows continue unchanged.",
        "allowed_actions": ["Document in OPEN_ITEMS_STATUS.md, this execution record and the Vault"],
        "acceptance": ["Pre-boundary rows documented as parked", "No rebuild, no guard change"],
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
for d in c['decisions']:
    if d['id'] == CID:
        d['choices']['YES'].update(PLAN_PATCH['YES'])
        d['choices']['NO'].update(PLAN_PATCH['NO'])
dump_json(CONTRACT, c, cc)

seed, sc = load_json(SEED)
for i in seed['items']:
    if i['id'] == CID:
        i.update(CARD_PATCH)
seed['revision'] = int(seed.get('revision') or 0) + 1
store.validate_feed(seed)
dump_json(SEED, seed, sc)

with store.exclusive_store_lock(store.DEFAULT_FEED):
    feed = store.load_feed(store.DEFAULT_FEED)
    for i in feed['items']:
        if i['id'] == CID:
            i.update(json.loads(json.dumps(CARD_PATCH)))
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
sha2, rc2, out2 = commit(['tools/strategy_farm/config/owner_decision_execution.v1.json', 'tools/strategy_farm/config/owner_decisions.v2.bootstrap.json', 'tools/strategy_farm/session_tools/legacy_calendar_input_card_0909_correction.py'],
                         'mission-control: correct ' + CID + ' card + plan (rebuild-vs-park, staged 11167 first; no safe declared-residual path)')
print('card correction commit', sha2, rc2, out2 if rc2 else '')

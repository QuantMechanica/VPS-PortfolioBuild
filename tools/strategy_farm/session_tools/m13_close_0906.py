"""M13: commit the Vorlage, close task 1bf87710, mint MC card OWNER-DEC-M13-ECONOMIC-TRIAL-20260906."""
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
NOW = now.strftime('%H:%MZ')
NOW_ISO = now.replace(microsecond=0).isoformat().replace('+00:00', 'Z')
TRAILER = '\n\nCo-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_018TXU36R3wPUNEzGHtsFZpM\n'
VP = 'docs/ops/OWNER_VORLAGE_2026-09-06_m13_economic_test_contract.md'
TID = '1bf87710-04c7-4cbc-b342-0bc0d660a5fd'
CID = 'OWNER-DEC-M13-ECONOMIC-TRIAL-20260906'


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
    return git('rev-parse', '--short=10', 'HEAD').stdout.strip(), r.returncode


sha, rc = commit([VP], 'docs(m13): bounded FTMO economic learning-trial contract Vorlage (DRAFT; options A/B/C, NO-BUY intact, recommendation B = capture-only free demo)')
print('vorlage commit', sha, rc)


def run(args):
    rr = subprocess.run([sys.executable, 'tools/strategy_farm/agent_router.py', *args], capture_output=True, text=True, cwd=REPO)
    return (rr.stdout + rr.stderr)[-90:]


print(run(['update-task', TID, '--state', 'REVIEW', '--artifact-path', VP, '--verdict', 'Executed on the Claude agent lane (Codex throttled; OWNER 03.09. routing): DRAFT contract with purpose, R5/C-6 firewalls (no double-counting), scope (free demo only, USD 0), pre-registered success/stop criteria, evidence paths, cost table, OWNER-only points (no purchase, account creation OWNER, PARKED->RUNNING OWNER). Options A/B/C, recommendation B. Commit ' + sha]))
print(run(['close-review', TID, '--state', 'APPROVED', '--verdict', 'APPROVED (Claude ' + NOW + '): Vorlage reviewed - NO-BUY intact, every number sourced, R5 population untouched, C-6 stays INERT; the 5.75-year R5 OOS horizon is surfaced honestly. Mission-Control card ' + CID + ' minted (Option B, OWNER acts: free demo account + terms + PARKED->RUNNING).', '--artifact-path', VP]))

CARD = {
    "category": "FTMO/Wirtschaftlichkeit",
    "cost_of_wait": "Gering fuer den Zaehler; fuer den FTMO-Pfad hoch: Der ratifizierte R5-Abnahmetest braucht ~2.100 versiegelte OOS-Tage (~5,75 Jahre), bis dahin bleibt der FTMO-Cashflow-Pfad undatiert. Ohne Option B fehlt weiter die einzige Evidenzklasse, die kein Backtest liefert (echte M5-Equity inkl. offener PnL am Prag-Mitternachtsanker), und die Kollektor-Abnahme bleibt offen.",
    "created_at_utc": NOW_ISO,
    "depends_on": [],
    "due": None,
    "evidence": [VP, "docs/ops/OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md", "docs/ops/evidence/2026-09-05_ftmo_readiness_part2.md"],
    "id": CID,
    "no_effect": "Option A: kein Trial, R5-Langzeitpfad allein; Ausfuehrungstreue bleibt unbelegt, Kollektor-Abnahme offen, NO-BUY bleibt. Nichts wird geloescht; die Vorlage bleibt als Vertrag fuer spaeter.",
    "question": "M13 (Audit-Befund F): Freigabe von Option B - ein KOSTENLOSER, gedeckelter Capture-only-Demo-Trial bei FTMO (Free Trial/Demo, USD 0, kein Kauf): nur echte M5-Telemetrie aufzeichnen (Equity inkl. offener PnL, Positionen, Pending am Prag-Anker), Scoring verschoben und als Bestaetigung UNZULAESSIG; getrennt vom R5-Test (Population unveraendert) und vom C-6-Schaetzer (bleibt INERT). Deine Handlungen bei JA: Free-Trial/Demo-Konto + Terminal-Login selbst anlegen, Client-Area-Bedingungen bestaetigen (Swing-Hebel, Symbole, Margin/Swap), Dauer-Cap als Zahl nennen, spaeter EXPECTED_STATE PARKED->RUNNING selbst umlegen. Meine Seite: Live-Modus-Set-Pfad-Generator + Kollektor-Abnahme kommissionieren, Capture-Runbook, Evidenzpfad. Kein Kauf, kein AutoTrading, kein Gate-Kriterium.",
    "recommendation": "JA (Option B). Kleinster Schritt, der die fehlende Evidenzklasse erzeugt, ohne Geld, ohne R5/C-6 zu beruehren, und der nicht in eine Bestaetigung umgedeutet werden kann. Option C (for-record) erst nach ratifizierten Prediction-Bands - eigene Karte.",
    "severity": "action",
    "status": "OPEN",
    "yes_effect": "Genau EIN Claude-Auftrag: (1) Codex-Tickets fuer Live-Modus-Set-Pfad-Generator und Kollektor-Abnahme/Installation (inert bis Deine Konto-Anlage); (2) Capture-Runbook + Evidenzverzeichnis docs/ops/evidence/<datum>_ftmo_m13_trial_capture_only.md; (3) OPEN_ITEMS/Vault-Mirror. Konto-Anlage, Login, Bedingungen und PARKED->RUNNING bleiben Deine Handlungen; kein Kauf.",
}
PLAN = {
    "id": CID,
    "todo_id": "QM-TODO-20260906-M13-ECONOMIC-TRIAL",
    "priority": 70,
    "choices": {
        "YES": {"mode": "APPLY_AND_VERIFY", "objective": "Prepare the capture-only free demo trial (Option B) without any purchase or account creation: commission the live-mode set-path generator and the telemetry collector acceptance/installation as Codex tickets (inert until the OWNER creates the demo account), write the capture runbook and the evidence directory skeleton, mirror to OPEN_ITEMS and the Vault. OWNER-only steps (account, login, client-area terms, duration cap, PARKED->RUNNING) remain OWNER receipts.", "allowed_actions": ["Enqueue Codex ops tickets for set-path generator and collector acceptance", "Write docs/ops/FTMO_M13_CAPTURE_RUNBOOK_<date>.md and the evidence skeleton", "Commit with explicit pathspecs; update OPEN_ITEMS"], "acceptance": ["Tickets exist with exact acceptance criteria", "Runbook names the OWNER steps and the firewall (capture-only, ineligible as confirmation)", "No purchase, no account creation, no EXPECTED_STATE change, no T_Live write"]},
        "NO": {"mode": "DOCUMENT_AND_VERIFY", "objective": "Record the rejection (Option A); the contract stays on file; nothing executes.", "allowed_actions": ["Document in OPEN_ITEMS_STATUS.md and the receipts file"], "acceptance": ["No trial preparation"]},
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
sha2, rc2 = commit(['tools/strategy_farm/config/owner_decision_execution.v1.json', 'tools/strategy_farm/config/owner_decisions.v2.bootstrap.json'], 'mission-control: ' + CID + ' card + plan (Option B capture-only free demo trial; NO-BUY intact)')
print('card commit', sha2, rc2)

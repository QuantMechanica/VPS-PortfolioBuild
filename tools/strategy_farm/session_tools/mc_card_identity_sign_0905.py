"""Mission Control card: OWNER attestation of the unsigned attest-current proposal (M06 phase 2); commit evidence; task 24b98bc4 -> REVIEW."""
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

NOW_ISO = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace('+00:00', 'Z')
NOW = datetime.datetime.now(datetime.timezone.utc).strftime('%H:%MZ')
CR, LF = chr(13), chr(10)
CONTRACT = REPO / 'tools/strategy_farm/config/owner_decision_execution.v1.json'
SEED = REPO / 'tools/strategy_farm/config/owner_decisions.v2.bootstrap.json'
CID = 'OWNER-DEC-LIVE-IDENTITY-SIGN-20260905'
D = 'docs/ops/evidence/2026-09-05_m06_attest_current'
PROP_SHA = '20de8acd31157cad84c5df8b54855af7a77ea7d32bcfdc108b3b32215af4d7c3'
OBS_SHA = 'c411e0f38885a9ae47c9cbde153461c4bc31a32c976a49718fcbfd90403ee640'

CARD = {
    "category": "Live-Buch/Governance",
    "cost_of_wait": "Ohne Deine Beglaubigung bleibt das laufende Buch ohne beglaubigte Identitaet; die Consumer-Ausnahme (in Umsetzung) kann nichts akzeptieren und der Freeze-Kreis bleibt bis zu einem signierten Mint geschlossen. Kein Verlust durch Warten ausser dem weiter offenen Audit-Punkt M06.",
    "created_at_utc": NOW_ISO,
    "depends_on": ["OWNER-DEC-LIVE-IDENTITY-ATTEST-20260905"],
    "due": None,
    "evidence": [D + '/proposal/proposal.json', D + '/proposal/receipt.json', D + '/observation.json', 'docs/ops/evidence/2026-09-05_m06_live_identity_attest.md'],
    "id": CID,
    "no_effect": "Der Vorschlag verfaellt; das laufende Buch bleibt unbeglaubigt; eine neue Beobachtung + neuer Vorschlag waeren fuer einen spaeteren Anlauf noetig.",
    "question": "Beglaubigst Du diesen unsignierten Attest-Vorschlag als Identitaet des UNVERAENDERTEN laufenden Live-Buchs? Vorschlag-SHA256 " + PROP_SHA[:16] + "... (Beobachtung " + OBS_SHA[:16] + "..., risk_freeze.measure read-only, Alter beim Vorschlag 15 s): 24 Sleeves, 21 Binaerdateien, Gesamtrisiko 9,7499 %, alle beobachteten Fingerabdruecke identisch mit der eingefrorenen Baseline, Freeze ACTIVE, Pointer unsigniert, keine Laufzeit-Aenderung. Dein JA ist der Beglaubigungs-Receipt, den die Consumer-Ausnahme (hinter Flag, in Umsetzung) spaeter als Freeze-Bedingung 1 akzeptieren darf. Es aktiviert nichts, aendert kein Risiko und beruehrt AutoTrading nicht.",
    "recommendation": "JA. Die Beobachtung ist frisch, vollstaendig und byte-identisch mit der Baseline; der Vorschlag ist inert und ohne Laufzeitwirkung. Das ist die vom Audit geforderte Beglaubigung der bestehenden Identitaet ohne Risikoaenderung.",
    "severity": "action",
    "status": "OPEN",
    "yes_effect": "Dokumentation: der Receipt wird als Beglaubigung an den Vorschlag gebunden (Evidenzdokument + OPEN_ITEMS); keine Code-Aktivierung, kein Pointer-Write, Freeze bleibt ACTIVE. Die Consumer-Ausnahme wird erst nach Review und einer eigenen Aktivierungs-Freigabe eingeschaltet.",
}
PLAN = {
    "id": CID,
    "todo_id": "QM-TODO-20260905-LIVE-IDENTITY-SIGN",
    "priority": 86,
    "choices": {
        "YES": {"mode": "DOCUMENT_AND_VERIFY", "objective": "Bind the OWNER attestation receipt to the proposal (sha " + PROP_SHA + ") in the evidence directory and OPEN_ITEMS; no code activation, no pointer write, freeze stays ACTIVE.", "allowed_actions": ["Write the receipt id + proposal sha into " + D + "/attestation.json and OPEN_ITEMS", "Commit with explicit pathspecs"], "acceptance": ["Attestation record exists and references the exact proposal sha", "No runtime file under C:/QM/mt5/T_Live or D:/QM/reports/state changed"]},
        "NO": {"mode": "DOCUMENT_AND_VERIFY", "objective": "Record the rejection; proposal expires unused.", "allowed_actions": ["Document in OPEN_ITEMS_STATUS.md"], "acceptance": ["No activation"]},
    },
}


def load_json(p):
    raw = p.read_bytes(); return json.loads(raw.decode('utf-8-sig')), (b'\r\n' in raw)


def dump_json(p, obj, crlf):
    text = json.dumps(obj, ensure_ascii=False, indent=2)
    if crlf:
        text = text.replace('\n', '\r\n')
    p.write_bytes(text.encode('utf-8'))


c, ccrlf = load_json(CONTRACT)
if CID not in {d['id'] for d in c['decisions']}:
    c['decisions'].append(PLAN); dump_json(CONTRACT, c, ccrlf)
seed, scrlf = load_json(SEED)
if CID not in {i['id'] for i in seed['items']}:
    seed['items'].append(CARD); seed['revision'] = int(seed.get('revision') or 0) + 1; store.validate_feed(seed); dump_json(SEED, seed, scrlf)
with store.exclusive_store_lock(store.DEFAULT_FEED):
    feed = store.load_feed(store.DEFAULT_FEED)
    if CID not in {i['id'] for i in feed['items']}:
        feed['items'].append(json.loads(json.dumps(CARD)))
        feed['revision'] = int(feed['revision']) + 1
        feed['updated_at_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        store.validate_feed(feed); store._write_json(store.DEFAULT_FEED, feed); print('feed revision', feed['revision'])
try:
    store.sync_vault_queue(feed); print('vault synced')
except Exception as exc:  # noqa: BLE001
    print('vault sync failed:', exc)
s = execution.plan_summary(CID); print(CID, 'ready', s.get('ready'))
r = subprocess.run([sys.executable, 'tools/strategy_farm/render_cockpit_v2.py'], capture_output=True, text=True, cwd=REPO); print((r.stdout + r.stderr).strip()[-80:])


def rw(p):
    raw = p.read_bytes(); crlf = (CR + LF).encode() in raw
    return raw.decode('utf-8').replace(CR + LF, LF), crlf


def ww(p, t, crlf):
    t = t.replace(CR + LF, LF)
    if crlf:
        t = t.replace(LF, CR + LF)
    p.write_bytes(t.encode('utf-8'))


p = REPO / 'docs/ops/OPEN_ITEMS_STATUS.md'; s2, c2 = rw(p); L = s2.split(LF)
L.insert(17, f"> **Nachtrag {NOW} (05.09.) — M06 Phase 1 ausgefuehrt, Beglaubigungs-Karte offen:** frische Read-only-Beobachtung des Live-Buchs (risk_freeze.measure: 24 Sleeves, 21 Binaerdateien, Gesamtrisiko 9,7499 %, keine Probleme; {D}/observation.json, SHA {OBS_SHA[:12]}...) und unsignierter Attest-Vorschlag {D}/proposal/proposal.json (SHA {PROP_SHA[:12]}..., Status ELIGIBLE_FOR_OWNER_REVIEW, alle Fingerabdruecke = Baseline, Freeze ACTIVE, Alter 15 s). Neue Mission-Control-Karte **{CID}** (Empfehlung JA = Beglaubigungs-Receipt, keine Aktivierung). Consumer-Ausnahme hinter Flag in Umsetzung (Codex). Task 24b98bc4 -> REVIEW.")
L.insert(18, ''); ww(p, LF.join(L), c2)
msg = REPO / 'artifacts' / '_commit_msg_tmp.txt'
msg.write_text('mission-control: ' + CID + ' card + plan; M06 fresh observation + unsigned attest-current proposal (ELIGIBLE_FOR_OWNER_REVIEW)\n\nCo-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_018TXU36R3wPUNEzGHtsFZpM\n', encoding='utf-8')
files = ['docs/ops/OPEN_ITEMS_STATUS.md', 'tools/strategy_farm/config/owner_decision_execution.v1.json', 'tools/strategy_farm/config/owner_decisions.v2.bootstrap.json', D + '/observation.json', D + '/observation.sha256', D + '/proposal/proposal.json', D + '/proposal/receipt.json']
subprocess.run(['git', 'add', *files], capture_output=True, cwd=REPO)
for a in range(5):
    rr = subprocess.run(['git', 'commit', '-q', '-F', str(msg), *files], capture_output=True, text=True, cwd=REPO)
    if rr.returncode == 0:
        break
    time.sleep(6)
msg.unlink(missing_ok=True)
sha = subprocess.run(['git', 'rev-parse', '--short=10', 'HEAD'], capture_output=True, text=True, cwd=REPO).stdout.strip(); print('commit', sha, rr.returncode, rr.stderr[-120:])
rr = subprocess.run([sys.executable, 'tools/strategy_farm/agent_router.py', 'update-task', '24b98bc4-cdc4-5681-bf8e-148051fba8af', '--state', 'REVIEW', '--artifact-path', D + '/proposal/proposal.json', '--verdict', 'Decision executed (phase 1): fresh read-only observation + unsigned attest-current proposal ELIGIBLE_FOR_OWNER_REVIEW (sha ' + PROP_SHA[:16] + ', commit ' + sha + '); consumer exception commissioned (Codex, flag default off); attestation = card ' + CID + '. No live effect.'], capture_output=True, text=True, cwd=REPO); print('task ->', 'REVIEW' in (rr.stdout + rr.stderr))

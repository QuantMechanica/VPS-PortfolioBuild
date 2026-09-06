"""M11: append CEO review to the Vorlage, commit, close task 93cd0e1c, mint MC card OWNER-DEC-M11-CENSUS-BRANCH-20260906."""
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

CR, LF = chr(13), chr(10)
now = datetime.datetime.now(datetime.timezone.utc)
NOW = now.strftime('%H:%MZ')
NOW_ISO = now.replace(microsecond=0).isoformat().replace('+00:00', 'Z')
TRAILER = '\n\nCo-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_018TXU36R3wPUNEzGHtsFZpM\n'
VP = 'docs/ops/OWNER_VORLAGE_2026-09-06_m11_optimisation_branch_utility.md'
CID = 'OWNER-DEC-M11-CENSUS-BRANCH-20260906'

ps = json.load(open('D:/QM/reports/state/pipeline_state.json', encoding='utf-8-sig'))
eta = (ps.get('operator_surface') or {}).get('path_to_25', {}).get('eta_to_25', {})
eta_txt = json.dumps({k: v for k, v in eta.items() if not isinstance(v, (list, dict))}, ensure_ascii=False)

REVIEW = """

## 6 - CEO review (Orchestrator, 2026-09-06 %s) - corrections and the recommendation that goes to the OWNER

The analysis above (sections 1-5) was produced by an agent on the Claude lane and is kept verbatim. Two facts changed under it and one framing must be corrected before the OWNER decides:

1. **The counter is 11 / 25, not 8.** `build_qualified_roster.py --venue dxz --dry-run` (03:13Z) and `pipeline_state.json` (`operator_surface.book_guard.qualified_pairs`, 03:11Z) both count 11 qualified pairs: the three 09-05 closures (21507/XAUUSD, 20266/XTIUSD, 12710/XTIUSD) qualify now. The public `funnel-stats.json` still shows 8 because its snapshot is from 09-05 16:26Z (stale, not a different definition). The "8 vs 11 = contiguity gap" reading in sections 2a/5 is therefore obsolete.
2. **Under the OWNER's counting rule the census IS the counter path.** OWNER-DEC-A1 counts terminal v4 Q14 pairs; a `KEEP_INCUMBENT` closure counts exactly like a promotion. So "0 promotions" is an *audit* finding about the branch's optimisation value, but it is not a reason to stop the census while 25 is the goal: Option C freezes the counter at 11, and Option B (>=50 %% measured cutoff) caps it at roughly 15 - see the program table below. The Option C text ("growth comes from fresh strategies clearing Q08 -> Q11 -> Q14") is wrong under A1, because Q14 requires the census.
3. **The 13 remaining programs are the 13 pairs Amendment C enrolled (OWNER YES, 2026-09-05, receipt row 14)** - i.e. the queue order of the census is already an OWNER decision in force. Reordering or pausing it is a card, never GRUEN.

Remaining census by program (03:2xZ; pending / measured / skipped), all `_opt` measurement siblings of counted or enrolled pairs:

| program | pair symbol | pending | measured | skipped | state |
|---|---|---|---|---|---|
| 41162, 41194, 41195, 41303, 41304, 41332 | EUR, XTI, XAG, XTI, XAG, NZD | 0 | 165-612 | 477-924 | terminal, counted |
| 41343, 41344 | EUR, EUR | 4 | 70 / 7 | 1,015 / 1,078 | terminal, counted |
| 41196, 41331, 41198 | XAU, XTI, XTI | 48 / 83 / 146 | 1,041 / 697 / 943 | 0 / 309 / 0 | terminal, counted (09-05) |
| 41097 | USDJPY | 227 | 858 | 0 | in progress |
| 41307, 41333, 41342, 41197, 41161, 41305, 41302, 41163, 41301, 41324, 41322, 41345 | XTI, XAU, EUR, GBP, GBP, XTI, XAU, CAD, XAU, JPY, XAU, XAU | 600-1,073 | 12-453 | 0-140 | in progress |

**Counter arithmetic.** 10,178 pending cells at the sustained ~104-130 MEASURED/h (03:01Z: 130/h; D1 pre-screen skips are free) = **3-4 factory-days** to drain all 13 programs. If they close like the first 12 (every one `KEEP_INCUMBENT`, none failed), that is **+13 -> 24 / 25**. The 25th pair needs one more Q11 survivor, and Q02-Q10 is exactly what the census currently starves (0 Q02 completions in >3 h, 772 Q02 rows pending) - that resumes automatically once the census pool empties, because the claim order is census-first. `pipeline_state.eta_to_25` for reference: %s.

**CEO recommendation (differs from section 4): Option A with a pre-registered refutation rule, not Option B.**
- Keep the census running exactly as decided (Amendment C queue order). It is the shortest path to 24/25 (~3-4 days), every byte stays append-only, and nothing is re-decided.
- Register the audit finding as a *refutation rule*, not as a stop: if the next **5** Q14 closures again promote no challenger (0/16 overall, rule-of-three upper bound ~19 %%), the *mandatory* optimisation branch is refuted for the book that follows - then the branch becomes on-demand (Option B's cohort contract) **for pairs beyond 25**, and the Q14-terminal requirement in the counting rule is put to the OWNER again. Until then the branch stays mandatory because the counting rule says so.
- Fix the public counter (regenerate `funnel-stats.json` from the guard) before the website deploy - stale 8 vs. live 11 would be an evidence error on the public site.

**Cost of waiting on this card:** none for the counter (Option A is the running state). The cost of choosing B or C is a stalled counter (15 or 11) in exchange for ~3-4 factory-days returned to Q02-Q10, which produce no counted pair until they reach Q14 themselves. The 12 h Auffangregel does not apply (ROT); the running state continues either way.
""" % (NOW, eta_txt)

V = REPO / VP
raw = V.read_bytes()
crlf = (CR + LF).encode() in raw
s = raw.decode('utf-8').replace(CR + LF, LF).rstrip('\n') + REVIEW
V.write_bytes((s.replace(LF, CR + LF) if crlf else s).encode('utf-8'))


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


sha, rc = commit([VP], 'docs(m11): optimisation-branch utility Vorlage (agent analysis + CEO review: counter 11/25, census is the counter path under A1, recommendation Option A + refutation rule)')
print('vorlage commit', sha, rc)


def run(args):
    rr = subprocess.run([sys.executable, 'tools/strategy_farm/agent_router.py', *args], capture_output=True, text=True, cwd=REPO)
    return (rr.stdout + rr.stderr)[-90:]


print(run(['update-task', '93cd0e1c-1b91-4a36-b864-571d3cea167c', '--state', 'REVIEW', '--artifact-path', VP, '--verdict', 'Executed on the Claude agent lane: Vorlage with measured facts (12 Q14 closures, all KEEP_INCUMBENT, 0 promotions; 24 programs, 8,437 MEASURED, 10,178 pending) + CEO review (counter 11/25 live; census = counter path under OWNER-DEC-A1; recommendation Option A + 5-pair refutation rule). Commit ' + sha]))
print(run(['close-review', '93cd0e1c-1b91-4a36-b864-571d3cea167c', '--state', 'APPROVED', '--verdict', 'APPROVED (Claude ' + NOW + '): Vorlage delivered and corrected in the CEO review (counter 11/25; Option C/B would stall the counter under A1; Amendment C queue order is an OWNER decision in force); Mission-Control card ' + CID + ' minted. No census, threshold, verdict or pool change.', '--artifact-path', VP]))

CARD = {
    "category": "Zaehler/Optimierungszweig",
    "cost_of_wait": "Fuer den Zaehler keine: Option A ist der laufende Zustand (Zensus laeuft in der beschlossenen Reihenfolge weiter, ~3-4 Fabriktage bis 24/25). Ohne Deinen Receipt bleibt nur der Audit-Punkt M11 offen; die Widerlegungsregel wird erst mit JA verbindlich registriert.",
    "created_at_utc": NOW_ISO,
    "depends_on": [],
    "due": None,
    "evidence": [VP, "docs/ops/CEO_AUDIT_INTEGRATION_2026-09-05.md", "docs/research/PATTERN_FILTER_WF_OPT_PLAN_V3_2026-08-21.md"],
    "id": CID,
    "no_effect": "NEIN = Du willst den Zensus NICHT unveraendert weiterlaufen lassen (Option B gebundene Kohorte mit Stichtag 2026-09-09 oder Option C Pause zugunsten Q02-Q10). Folge: Ich lege die Kohorten-Vertragskarte (Einschluss/Ausschluss, unveraenderlicher Incumbent, versiegelte Varianten, COHORT_DEFERRED-Holds append-only) als eigene Karte vor; der Zaehler bleibt bis dahin bei 11 (C) bzw. ~15 (B). Nichts wird geloescht.",
    "question": "M11 (Audit-Befund C): Alle 12 Q14-Closures sind KEEP_INCUMBENT, 0 Challenger befoerdert, der Zensus belegt die ganze Fabrik (0 Q02-Abschluesse seit >3 h). Zaehler LIVE 11/25 (nicht 8: 21507/XAUUSD, 20266+12710/XTIUSD zaehlen seit heute; public funnel-stats.json ist stale). Unter Deiner Zaehlregel (A1: terminale Q14-Paare, KEEP zaehlt wie Promotion) ist der Zensus der Zaehlerpfad: 10.178 offene Zellen = ~3-4 Fabriktage = +13 Paare -> 24/25; das 25. Paar braucht einen neuen Q11-Ueberlebenden aus Q02-Q10. Soll der Zensus UNVERAENDERT in der beschlossenen Reihenfolge (Amendment C) weiterlaufen (Option A) und die Audit-Frage als vor-registrierte WIDERLEGUNGSREGEL festgehalten werden: wenn auch die naechsten 5 Q14-Closures keinen Challenger befoerdern (0/16), gilt der PFLICHT-Optimierungszweig fuer Paare jenseits von 25 als widerlegt und wird zur On-Demand-Kohorte (Option B) - dann eigene Karte inkl. Zaehlregel?",
    "recommendation": "JA. Option A ist der kuerzeste Weg zu 24/25 und aendert nichts; B/C tauschen den Zaehler (15 bzw. 11) gegen 3-4 Fabriktage fuer Q02-Q10, die erst nach eigenem Q14 zaehlen wuerden. Die Widerlegungsregel macht den Audit-Befund verbindlich, ohne jetzt etwas zu stoppen.",
    "severity": "action",
    "status": "OPEN",
    "yes_effect": "Genau EIN Claude-Auftrag (dokumentarisch): Widerlegungsregel (5 weitere Closures, 0/16 -> Pflichtzweig widerlegt) als Addendum im DL-089-Plan-Dokument + OPEN_ITEMS registrieren; public funnel-stats.json aus dem Guard regenerieren (11/25) vor dem Website-Deploy. Kein Zensus-, Schwellen-, Verdikt- oder Pool-Eingriff; Zensus laeuft unveraendert.",
}
PLAN = {
    "id": CID,
    "todo_id": "QM-TODO-20260906-M11-CENSUS-BRANCH",
    "priority": 84,
    "choices": {
        "YES": {"mode": "DOCUMENT_AND_VERIFY", "objective": "Register the pre-registered refutation rule (next 5 Q14 closures without a promoted challenger, 0/16 overall -> mandatory optimisation branch refuted beyond 25 -> on-demand cohort card) as an addendum to docs/research/PATTERN_FILTER_WF_OPT_PLAN_V3_2026-08-21.md and OPEN_ITEMS; regenerate public-data/funnel-stats.json from book_build_guard (11/25); no census, threshold, verdict or pool change.", "allowed_actions": ["Append the refutation-rule addendum (dated, receipt id) to the DL-089 plan doc and OPEN_ITEMS", "Regenerate public-data/funnel-stats.json from the guard/roster (read-only DB access)", "Commit with explicit pathspecs"], "acceptance": ["Addendum present with receipt id and the exact rule (5 closures, 0/16)", "funnel-stats.json qualified_pairs_current == book_build_guard qualified_pairs at generation time", "No work_items/holds mutation"]},
        "NO": {"mode": "DOCUMENT_AND_VERIFY", "objective": "Record the rejection and prepare the cohort-contract card (Option B: cutoff 2026-09-09, inclusion/exclusion, immutable incumbent, sealed variant set, COHORT_DEFERRED holds append-only) or the pause card (Option C) as a separate OWNER Vorlage; nothing executes before that card's receipt.", "allowed_actions": ["Write the follow-up Vorlage + Mission-Control card", "Document in OPEN_ITEMS_STATUS.md"], "acceptance": ["No census/holds mutation before the follow-up receipt"]},
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
sha2, rc2 = commit(['tools/strategy_farm/config/owner_decision_execution.v1.json', 'tools/strategy_farm/config/owner_decisions.v2.bootstrap.json'], 'mission-control: ' + CID + ' card + plan (Option A + refutation rule recommended; counter live 11/25)')
print('card commit', sha2, rc2)

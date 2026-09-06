"""Mint the Mission-Control card OWNER-DEC-DSR-SINGLE-CONFIG-DECLARATION-20260906 (ROT: search-history authority for single-configuration EAs) + execution plan; commit Vorlage and config with pathspecs."""
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
VP = 'docs/ops/OWNER_VORLAGE_2026-09-06_dsr_single_configuration_declaration.md'
CID = 'OWNER-DEC-DSR-SINGLE-CONFIG-DECLARATION-20260906'


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


sha, rc, out = commit([VP, 'tools/strategy_farm/session_tools/fleet_monitor.py', 'tools/strategy_farm/session_tools/reload_chunk50.py', 'tools/strategy_farm/session_tools/dsr_declaration_card_0906.py'],
                      'docs(dsr): OWNER Vorlage - search-history authority for single-configuration EAs under DSR V2 (ROT; options A/B/C, recommendation A = sweep lists are Q14 proposals, machine-checked; the structural 25th-pair blocker) + session tools (fleet monitor, reload chunk 50, card script)')
print('vorlage commit', sha, rc, out if rc else '')

CARD = {
    "category": "Pipeline/DSR V2",
    "cost_of_wait": "Hoch fuer den Zaehler: Seit DSR V2 (05.09.) endet JEDES Q08 eines Single-Configuration-EAs ohne versiegeltes Such-Ledger INVALID (11167/XAUUSD, 11196/XAUUSD, 11015/EURUSD). Der Zensus-Pfad bringt den Zaehler in ~3-4 Fabriktagen auf hoechstens 24; das 25. Paar ist strukturell unerreichbar, solange diese Frage offen ist. Jeder Tag ohne Entscheid = 0 Beitrag des Q02-Q10-Trichters zum Zaehler.",
    "created_at_utc": NOW_ISO,
    "depends_on": [],
    "due": None,
    "evidence": [VP, "docs/ops/evidence/2026-09-06_dsr_trivial_cohort.md", "tools/strategy_farm/schemas/dsr_single_configuration_declaration_v1.schema.json"],
    "id": CID,
    "no_effect": "Option B: Sweep-Listen gelten als Forschung, die ledgert werden muss -> Ledger existieren nicht und koennen ehrlich nicht nachproduziert werden -> die drei EAs und jedes kuenftige Single-Config-EA bleiben INVALID; Zaehler hart bei 24; Buch-Zeremonie ohne Datum. Keine Loeschung; Vorlage bleibt Vertrag.",
    "question": "DSR V2 (Q08 Sub-Gate 8.2): Zaehlt die in einer Card gelistete 'P3-Sweep'/'Parameters To Test'-Liste als DURCHGEFUEHRTE Suche (=> vollstaendiges Verlierer-Ledger noetig) oder als VORSCHLAG fuer den Optimierungszweig (=> research_trial_count = 0, N = 1)? Fakten: Fuer 11167, 11196, 11015 gibt es im Fabrik-Ledger KEINE Optimierungszeile vor dem Q08-Claim; die getestete Konfiguration ist der Card-Default, fixiert vor dem ersten Q02; DSR korrigiert fuer SELEKTION, und es wurde nichts selektiert. Codex hat den Deklarationspfad fail-closed gebaut (7a89b5b701; 42 Tests; Schwellen unveraendert; echte Cards werden verweigert, bis DU diese Regel setzt). Option A (Empfehlung): Sweep-Liste = Q14-Vorschlag, wenn (i) keine Optimierungszeile vor Q08 im work_items-Ledger (maschinell geprueft) und (ii) gebauter Set = Card-Lock; Deklarationsblock als append-only Card-Amendment; Q08 append-only neu. Option C (Sweeps jetzt fahren, ~300 Zellen) ist statistisch falsch fuer den Incumbent und skaliert nicht. Symbol-Multiplizitaet und Upstream-Hyperopt (11196) bleiben ausdruecklich ausserhalb dieser Frage (siehe Vorlage §2.4). Keine Schwelle, kein Verdikt, kein T_Live wird beruehrt.",
    "recommendation": "JA (Option A) mit beiden Bedingungen maschinell geprueft. Das ist die Lesart, unter der DSR V2 misst, wofuer es ratifiziert wurde (Selektion INNERHALB unserer Fabrik), und die einzige, die das 25-Paar-Ziel ohne Schwellenaenderung erreichbar haelt. Widerlegung: Findet ein spaeteres Audit eine Optimierungszeile vor dem Q08 eines so deklarierten EAs, wird die Q08-Zeile append-only superseded.",
    "severity": "action",
    "status": "OPEN",
    "yes_effect": "Genau EIN Claude-Auftrag: (1) Codex-Ticket (Sol, high): Deklarations-Amendments fuer die Cards 11167 und 11196 (append-only ueber den approve-card-Pfad, SPEC-SHA-Rebind), Producer-Maschinencheck fuer Bedingung (i) aus work_items, Card-Linter-Regel 'Sweep-Liste = Q14-Vorschlag', Tests, Evidenz; (2) nach Integration: append-only Q08-Reruns 11167/XAUUSD und 11196/XAUUSD (11015 erst nach Klaerung des Set-Locks, eigene OPEN_ITEMS-Zeile); (3) OPEN_ITEMS + Vault-Spiegel (03 Pipeline/Q08-Nachtrag). Keine Schwelle, kein bestehendes Verdikt, kein T_Live.",
}
PLAN = {
    "id": CID,
    "todo_id": "QM-TODO-20260906-DSR-SINGLE-CONFIG-DECLARATION",
    "priority": 92,
    "choices": {
        "YES": {"mode": "APPLY_AND_VERIFY", "objective": "Adopt Option A: a card sweep/parameters-to-test list counts as zero research trials when (i) the factory ledger has no optimisation row for the EA before its Q08 claim (machine-checked from work_items at seal time) and (ii) the built set equals the card lock. Commission the Codex ticket (card declaration amendments for QM5_11167 and QM5_11196 via the approve-card path, producer condition-(i) check, card-linter rule, tests, evidence), integrate it, then enqueue append-only Q08 reruns for 11167/XAUUSD and 11196/XAUUSD. No threshold, stored verdict, T_Live or AutoTrading change.", "allowed_actions": ["Enqueue one Codex ops ticket with exact acceptance criteria", "Integrate the Codex branch (cherry-pick, tests, Codex co-author trailer)", "farmctl enqueue-backtest --phase Q08 --append-only-rerun-of <INVALID row> for 11167/XAUUSD and 11196/XAUUSD", "Update OPEN_ITEMS and the Vault Q08 page"], "acceptance": ["Declaration blocks exist in the two approved cards and the producer seals a cohort with declared_trial_count=1 bound to card/SPEC/source/binary/set SHA", "The producer refuses when an optimisation row precedes the Q08 claim", "Q08 reruns end PASS or FAIL (not INVALID); old INVALID rows preserved append-only", "No threshold or stored verdict changed"]},
        "NO": {"mode": "DOCUMENT_AND_VERIFY", "objective": "Record Option B; restate the counter ceiling as 24 (structural) in Mission Control, OPEN_ITEMS and the Vault; no code change.", "allowed_actions": ["Document in OPEN_ITEMS_STATUS.md, the receipts file and the Vault"], "acceptance": ["No declaration added to any card", "Ceiling 24 stated in the OWNER surfaces"]},
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
sha2, rc2, out2 = commit(['tools/strategy_farm/config/owner_decision_execution.v1.json', 'tools/strategy_farm/config/owner_decisions.v2.bootstrap.json'], 'mission-control: ' + CID + ' card + plan (ROT: sweep lists as Q14 proposals vs. ledgered research; recommendation A; the structural 25th-pair blocker)')
print('card commit', sha2, rc2, out2 if rc2 else '')

"""Dispatch Development to scaffold + compile QM5_1014 (SRC04_S08 lien-channels).
Without this, HoP's QUA-1075 loops 'blocked:missing_artifacts' every wake.
"""
import sys, urllib.request, urllib.error, json
sys.stdout.reconfigure(encoding='utf-8')

API='http://127.0.0.1:3100/api'
COMPANY='03d4dcc8-4cea-4133-9f68-90c0d99628fb'
GOAL='4662e91e-8e9b-458e-9383-b1f67751965b'
DEVELOPMENT='ebefc3a6-4a11-43a7-bd5d-c0baf50eb1f9'

BODY="""## Aufgabe — Unblock HoP / Phase-3-next-card chain

Per OWNER mission baseline 2026-05-09: MT5 saturation = primary success metric. Aktuell 1/5 Terminals saturiert weil HoP (QUA-1075) seit 10:00Z im Loop "blocked:missing_artifacts ea_dir=False ex5=False p2=False" feststeckt.

CEO hat 10:00Z via QUA-1074 dispatcht: "SRC04_S08 lien-channels P0..P3". Der HoP-dispatch (QUA-1075) braucht aber die EA-Artefakte die noch nicht existieren.

## Was zu bauen

Scaffold + compile QM5_1014 (= SRC04_S08 lien-channels):

1. **EA-Verzeichnis anlegen**: `framework/EAs/QM5_1014_lien_channels/` (oder analog Naming-Convention der existierenden EAs wie `QM5_SRC04_S03_lien_fade_double_zeros`)
2. **REVIEW_INPUT.json kopieren** aus dem APPROVED Strategy Card (lookup im Research-Output / strategy-seeds)
3. **CHECKLIST.md kopieren** vom Card-Template
4. **`.mq5` source generieren** aus framework template + Strategy-Card-Logik (lien-channels = Lane: trend / breakout)
5. **Compile via MetaEditor** zu `QM5_1014_lien_channels.ex5`
6. **Magic-Number** registrieren: `ea_id*10000+slot` — ea_id=1014, slot=ein Slot pro Symbol
7. Verify `.ex5` exists + symlinks/copies T1-T5 (per existing EA copy pattern)

## Blocker-Relation
Set `blockedByIssueIds` auf **diesem Issue** für QUA-1075. Sobald hier done → HoP wakes auf QUA-1075 + kann P1/P2 starten.

## Voraussetzung
- Strategy Card `SRC04_S08 lien-channels` muss G1-APPROVED sein (per QUA-1059 QB-Sweep — laut Comment auf QUA-1059: "SRC04 Lien S01-S11 (10 cards) | All APPROVED per QUA-438; in build queue")
- Das ea_id_registry.csv hat schon Eintrag: `1014,lien-channels,SRC04_S08,active,CTO,2026-05-01` ✓

## Acceptance
- `framework/EAs/QM5_1014_*/` dir existiert mit mq5 + ex5 + REVIEW_INPUT + CHECKLIST
- Magic-numbers registriert
- T1-T5 EA-Copies vorhanden (oder symlinks per existing pattern)
- Comment auf diesem Issue mit File-Liste + commit-hash
- Status PATCH zu in_review (CTO peer review per DL-036) → done

## Flag — separates Issue (CTO)
**`framework/scripts/p1_build_validation.py` fehlt komplett auf disk.** phase_orchestrator.py erwartet diesen Runner für die P1-Phase. Bedeutet: selbst wenn QM5_1014 scaffold + compile fertig ist, wird HoP nochmal stallen weil p1_build_validation.py nicht existiert. Bitte mark dieses Problem in Comment auf diesem Issue (sodass CTO-Issue separat aufgemacht werden kann), oder: per-EA P1 manuell skippen wenn .ex5 schon existiert.

## Pfade
- Existing EA pattern: `framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/` (Vorbild scaffold)
- Card source: strategy-seeds/cards/SRC04/S08_lien-channels.* (suchen)
- Registry: `framework/registry/ea_id_registry.csv` (Eintrag 1014 existiert)
- Compile-Pattern: bestehende EAs zeigen wie .mq5 → .ex5 läuft (MetaEditor /compile oder ähnlich)
- Memory: `project_qm_mission_baseline_2026-05-09` für no-phasing context

## Constraints
- Codex weekly 93%, kann eng werden. Einzelne EA-scaffold sollte aber drin sein.
- KEINE OWNER-Klasse (T6, real-money)
- Anti-theater per DL-054: keine Quick-and-dirty mq5-Generation; muss tatsächlich kompilierbar sein
- DL-046: keine "still working"-Loop-Comments; comment einmal mit progress, dann PATCH

Prio: HIGH — direct blocker auf Mission-Critical-MT5-Saturation.
"""

req=urllib.request.Request(f'{API}/companies/{COMPANY}/issues',
    data=json.dumps({
        'title': 'Scaffold + compile QM5_1014 (SRC04_S08 lien-channels) — unblocks HoP QUA-1075',
        'description': 'HoP (QUA-1075) seit 10:00Z im Loop blocked:missing_artifacts. Development scaffolded QM5_1014 nicht. Plus: p1_build_validation.py fehlt auf disk (separates flag).',
        'priority': 'high',
        'assigneeAgentId': DEVELOPMENT,
        'goalId': GOAL,
        'createdByUserId': 'local-board',
    }).encode('utf-8'),
    headers={'Content-Type':'application/json'}, method='POST')
try:
    resp=urllib.request.urlopen(req); d=json.loads(resp.read())
    iid=d['id']; ident=d['identifier']
    print(f'Issue: {ident} | id={iid}')
    # status to_do
    req2=urllib.request.Request(f'{API}/issues/{iid}',
        data=json.dumps({'status':'todo'}).encode('utf-8'),
        headers={'Content-Type':'application/json'}, method='PATCH')
    resp2=urllib.request.urlopen(req2); print(f'PATCH: {resp2.status}')
    # body
    req3=urllib.request.Request(f'{API}/issues/{iid}/comments',
        data=json.dumps({'body':BODY}).encode('utf-8'),
        headers={'Content-Type':'application/json'}, method='POST')
    resp3=urllib.request.urlopen(req3); print(f'Comment: {resp3.status}')

    # Now PATCH QUA-1075 with blockedByIssueIds = [iid] so HoP stops looping
    issues=json.load(urllib.request.urlopen(f'{API}/companies/{COMPANY}/issues?limit=200'))
    issues=issues if isinstance(issues,list) else issues.get('data',[])
    qua1075=next((i for i in issues if i.get('identifier')=='QUA-1075'),None)
    if qua1075:
        body_block={
            'blockedByIssueIds': [iid],
            'status': 'blocked',
        }
        req4=urllib.request.Request(f'{API}/issues/{qua1075["id"]}',
            data=json.dumps(body_block).encode('utf-8'),
            headers={'Content-Type':'application/json'}, method='PATCH')
        resp4=urllib.request.urlopen(req4); d4=json.loads(resp4.read())
        print(f'QUA-1075 blocked-by-PATCH: {resp4.status} | status={d4.get("status")} | blockedByIssueIds={d4.get("blockedByIssueIds")}')
        # Comment explaining the blocker
        comment_text=f"""## Blocker dispatched: {ident} (Development scaffold QM5_1014)

HoP loop pattern observed since 10:00Z: 'blocked:missing_artifacts ea_dir=False ex5=False p2=False' every wake (DL-046 violation).

Root cause: QM5_1014 EA never scaffolded by Development. Filed {ident} (Development assignee) with HIGH prio. blockedByIssueIds set on this issue to {ident} - HoP should stop looping until upstream done.

Once {ident} closes done -> blocker lifts -> HoP resumes P1+ on QM5_1014.
"""
        req5=urllib.request.Request(f'{API}/issues/{qua1075["id"]}/comments',
            data=json.dumps({'body':comment_text}).encode('utf-8'),
            headers={'Content-Type':'application/json'}, method='POST')
        resp5=urllib.request.urlopen(req5); print(f'QUA-1075 comment: {resp5.status}')
except urllib.error.HTTPError as e:
    print(f'ERR: {e.status} {e.read().decode()[:400]}')

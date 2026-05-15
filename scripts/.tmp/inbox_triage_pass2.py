"""
Pass 2: triage the 33 remaining open issues.
- Cancel: truly resolved/expired/superseded
- Close as done: parents whose children completed
- Archive (inbox-archive): in-flight other-agent work
- Leave visible: only OWNER-actionable items
"""
import json, urllib.request, time

CID = "03d4dcc8-4cea-4133-9f68-90c0d99628fb"
API = "http://127.0.0.1:3100/api"

def fetch(url):
    return json.loads(urllib.request.urlopen(url, timeout=30).read())

def post_comment(iid, body):
    req = urllib.request.Request(f"{API}/issues/{iid}/comments",
        data=json.dumps({"body":body}).encode("utf-8"),
        headers={"Content-Type":"application/json"}, method="POST")
    try:
        urllib.request.urlopen(req, timeout=15)
        return True
    except Exception as e:
        return False

def patch(iid, body):
    req = urllib.request.Request(f"{API}/issues/{iid}",
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type":"application/json"}, method="PATCH")
    try:
        return True, json.loads(urllib.request.urlopen(req, timeout=15).read())
    except Exception as e:
        return False, str(e)

def archive(iid):
    req = urllib.request.Request(f"{API}/issues/{iid}/inbox-archive",
        data=json.dumps({}).encode("utf-8"),
        headers={"Content-Type":"application/json"}, method="POST")
    try:
        urllib.request.urlopen(req, timeout=15)
        return True
    except: return False

# Fetch current inbox
items = fetch(f"{API}/companies/{CID}/issues?status=backlog,todo,in_progress,in_review,blocked,done&touchedByUserId=me&inboxArchivedByUserId=me&limit=500")
print(f"inbox count: {len(items)}")
by_ident = {i.get('identifier'): i for i in items}

# 1. CANCEL truly resolved/expired
cancel_with_reason = [
    ("QUA-1354", "P2 Full Matrix on QM5_1014 — superseded by 2026-05-15 drift triage: ZTS verdict BASELINE_ACCURATE_FAILED, Research follow-up dispatched as QUA-1552. Original P2 full-matrix work no longer relevant for this EA."),
    ("QUA-1340", "CTO Codex adapter cap expiry was 2026-05-14 16:18 PDT — window closed. Today's session confirms CTO + Codex agents are healthy and firing (Codex last successful run 2026-05-15 07:48Z)."),
    ("QUA-899",  "Continuation-runaway bug PATCHED 2026-05-15 by Board Advisor in paperclip/app/server/src/services/recovery/service.ts at line ~1568 (in_progress branch). Server restarted (PID 16868). Verified 0 issue_continuation_needed wakes in 4-min post-restart window. See memory feedback_qua899_continuation_runaway_patch.md."),
    ("QUA-1189", "Gmail-Monitor heartbeat liveness log: separate self-comment loop bug on QUA-803 stopped 2026-05-15 by setting Gmail-Monitor runtimeConfig.heartbeat.wakeOnDemand=false (daily 8am Vienna cron still fires). Durable fix tracked in memory feedback_loopback_comment_wake_attribution_bug.md."),
]

print("\n=== CANCEL resolved/expired ===")
for ident, reason in cancel_with_reason:
    if ident in by_ident:
        iid = by_ident[ident]['id']
        post_comment(iid, f"Board Advisor cancel 2026-05-15T08:15Z: {reason}")
        ok, d = patch(iid, {"status":"cancelled"})
        print(f"  {ident}: {'cancelled' if ok else 'FAILED'}")

# 2. CLOSE QUA-1547 — child QUA-1549 done, work complete
if "QUA-1547" in by_ident:
    iid = by_ident["QUA-1547"]['id']
    post_comment(iid, "Board Advisor closing 2026-05-15T08:15Z: child QUA-1549 (Build & deploy QM5_1002 .ex5) completed by Dev-Codex. Binary deployed T1-T5 with matching SHA. Phantom `QM5_1002` (no -davey-eu-night suffix) noted separately — it's a registry-only entry, no build possible until removed from EA registry. Parent closes; further phantom-cleanup is a Pipeline-Op concern, not blocking V5 progress.")
    ok, _ = patch(iid, {"status":"done"})
    print(f"\n  QUA-1547: closed done={ok}")

# 3. ARCHIVE all other in-flight other-agent work
# (We leave only OWNER-actionable: QUA-1527 needs OWNER decision)
keep_visible = {"QUA-1527"}  # OWNER ratification needed
archive_list = []
for ident, i in by_ident.items():
    if ident in keep_visible: continue
    # Skip ones we already cancelled/closed above
    if ident in [x[0] for x in cancel_with_reason] or ident == "QUA-1547": continue
    if i.get('status') in ('backlog','todo','in_progress','in_review','blocked'):
        archive_list.append((ident, i))

print(f"\n=== ARCHIVE {len(archive_list)} in-flight other-agent items ===")
for ident, i in archive_list:
    success = archive(i['id'])
    title = (i.get('title') or '').encode('ascii','replace').decode()[:50]
    print(f"  {ident:10} {('OK' if success else 'FAIL'):5} {title}")

# 4. Final state
print("\n=== Inbox AFTER pass 2 ===")
final = fetch(f"{API}/companies/{CID}/issues?status=backlog,todo,in_progress,in_review,blocked,done&touchedByUserId=me&inboxArchivedByUserId=me&limit=500")
print(f"OWNER inbox count: {len(final)}")
for i in final:
    title = (i.get('title') or '').encode('ascii','replace').decode()[:55]
    print(f"  {i.get('identifier',''):10} {i.get('status',''):11} {title}")

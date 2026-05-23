"""
Inbox sweep — archives done/cancelled + routine_execution + rolling-tracker issues
from OWNER's Paperclip inbox. Cancellations not done here — only archive (reversible).
"""
import json, urllib.request, time

CID = "03d4dcc8-4cea-4133-9f68-90c0d99628fb"
API = "http://127.0.0.1:3100/api"

def fetch(url):
    r = urllib.request.urlopen(url, timeout=30)
    return json.loads(r.read())

def archive(issue_id):
    req = urllib.request.Request(
        f"{API}/issues/{issue_id}/inbox-archive",
        data=json.dumps({}).encode("utf-8"),
        headers={"Content-Type":"application/json"}, method="POST")
    try:
        r = urllib.request.urlopen(req, timeout=15)
        return True, json.loads(r.read())
    except urllib.error.HTTPError as e:
        return False, f"HTTP {e.code}: {e.read().decode()[:200]}"
    except Exception as e:
        return False, str(e)

# Fetch the full OWNER inbox (touched-by + not-yet-archived)
all_items = fetch(f"{API}/companies/{CID}/issues?status=backlog,todo,in_progress,in_review,blocked,done&touchedByUserId=me&inboxArchivedByUserId=me&limit=500")
print(f"OWNER inbox before sweep: {len(all_items)}")

# Categorize
done_or_cancelled = [i for i in all_items if i.get('status') in ('done','cancelled')]
routine_exec = [i for i in all_items if i.get('originKind') == 'routine_execution' and i.get('status') not in ('done','cancelled')]
rolling_tracker = [i for i in all_items if bool(i.get('rollingTracker')) and i.get('status') not in ('done','cancelled')]
open_other = [i for i in all_items if i.get('status') in ('backlog','todo','in_progress','in_review','blocked')
              and not i.get('rollingTracker')
              and i.get('originKind') != 'routine_execution']

print(f"  done/cancelled: {len(done_or_cancelled)}")
print(f"  routine_execution (open): {len(routine_exec)}")
print(f"  rolling_tracker (open): {len(rolling_tracker)}")
print(f"  other open: {len(open_other)}")

# Archive done/cancelled + routine_execution + rolling_tracker
to_archive = done_or_cancelled + routine_exec + rolling_tracker
seen = set()
unique = []
for i in to_archive:
    if i['id'] not in seen:
        seen.add(i['id'])
        unique.append(i)
print(f"\nArchiving {len(unique)} issues ...")
ok, fail = 0, 0
for i in unique:
    success, _ = archive(i['id'])
    if success: ok += 1
    else: fail += 1
print(f"archived: {ok}, failed: {fail}")

# Show the remaining open_other
print(f"\n=== Remaining {len(open_other)} 'real' open issues for OWNER triage ===")
open_other.sort(key=lambda i: i.get('updatedAt',''), reverse=True)
for i in open_other:
    title = (i.get('title') or '').encode('ascii','replace').decode()[:55]
    asg = (i.get('assigneeAgentId') or '-')[:8]
    print(f"  {i.get('identifier',''):10} {i.get('status',''):11} asg={asg}  {title}")

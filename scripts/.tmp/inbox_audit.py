import json, urllib.request
from datetime import datetime, timezone, timedelta

CID = "03d4dcc8-4cea-4133-9f68-90c0d99628fb"
now = datetime.now(timezone.utc)
all_issues = []
for st in ["backlog","todo","in_progress","in_review","blocked","done"]:
    r = urllib.request.urlopen(f"http://127.0.0.1:3100/api/companies/{CID}/issues?status={st}&limit=500",timeout=15)
    arr = json.loads(r.read())
    for i in arr if isinstance(arr,list) else arr.get('items',[]):
        all_issues.append(i)

# Show non-cancelled / non-done open issues with age
open_only = [i for i in all_issues if i.get('status') in ('backlog','todo','in_progress','in_review','blocked')]
print(f"Open issues: {len(open_only)}\n")

# Sort by updatedAt asc (stalest first)
def age_days(i):
    ts_s = i.get('updatedAt') or i.get('createdAt') or ''
    try:
        ts = datetime.fromisoformat(ts_s.replace('Z','+00:00'))
        return (now - ts).total_seconds() / 86400
    except: return 999

open_only.sort(key=age_days, reverse=True)

print(f"{'ID':10} {'STAT':10} {'AGE':>5} {'ORIG':18} {'ASG':10} TITLE")
for i in open_only:
    title = (i.get('title') or '').encode('ascii','replace').decode()[:55]
    asg = (i.get('assigneeAgentId') or '-')[:8]
    age = age_days(i)
    age_str = f"{age:.1f}d"
    orig = (i.get('originKind') or '-')[:18]
    print(f"{i.get('identifier',''):10} {i.get('status',''):10} {age_str:>5} {orig:18} {asg:10} {title}")

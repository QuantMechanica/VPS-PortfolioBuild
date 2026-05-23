import json, urllib.request, sys
from datetime import datetime, timezone, timedelta

issues = [
    ("QUA-1483 dashboard","52c652f5-873a-4982-a316-14de405c9990"),
    ("QUA-1516 website","1c3a4d41"),
    ("QUA-803 gmail-poller","5d2f0ffd"),
    ("QUA-838 quartz-poc","f0fbfa34"),
    ("QUA-1549 build (productive)","34bf4d2e-0d37-4f29-9a72-7063e300c5c2"),
]

# Resolve short ids
for label, iid in list(issues):
    if "-" not in iid or len(iid) < 36:
        for st in ["in_progress","backlog","blocked"]:
            r = urllib.request.urlopen(f"http://127.0.0.1:3100/api/companies/03d4dcc8-4cea-4133-9f68-90c0d99628fb/issues?status={st}&limit=200", timeout=15)
            arr = json.loads(r.read())
            for i in arr:
                if i.get('id','').startswith(iid):
                    issues[issues.index((label,iid))] = (label, i['id'])
                    break

cutoff = datetime.now(timezone.utc) - timedelta(minutes=60)
for label, iid in issues:
    try:
        r = urllib.request.urlopen(f"http://127.0.0.1:3100/api/issues/{iid}/comments", timeout=15)
        arr = json.loads(r.read())
        items = arr if isinstance(arr,list) else arr.get('items',[])
        recent = []
        for c in items:
            ca = c.get('createdAt') or ''
            try:
                ts = datetime.fromisoformat(ca.replace('Z','+00:00'))
                if ts >= cutoff:
                    recent.append(c)
            except: pass
        print(f"\n=== {label} ({iid[:8]}): total={len(items)} recent60m={len(recent)}")
        for c in recent[:2]:
            bd = (c.get('body') or '')[:120].replace(chr(10),' ').encode('ascii','replace').decode()
            aid = (c.get('authorAgentId') or c.get('authorUserId') or '?')[:8]
            print(f"  {(c.get('createdAt') or '')[:19]}  {aid}  {bd}")
    except Exception as e:
        print(f"  ERR {label}: {e}")

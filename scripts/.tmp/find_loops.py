import json, urllib.request, sys

targets = {'1c3a4d41','52c652f5','5d2f0ffd','f0fbfa34','34bf4d2e','bde73d6b'}
found = {}
for st in ['in_progress','backlog','blocked','todo','done','cancelled']:
    r = urllib.request.urlopen(f'http://127.0.0.1:3100/api/companies/03d4dcc8-4cea-4133-9f68-90c0d99628fb/issues?status={st}&limit=200', timeout=15)
    arr = json.loads(r.read())
    for i in arr:
        for t in list(targets - set(found)):
            if i.get('id','').startswith(t):
                found[t] = i
for t in targets:
    if t in found:
        i = found[t]
        title = (i.get('title') or '').encode('ascii','replace').decode()
        print(f"  {t}: {i.get('identifier')}  status={i.get('status')}  asg={(i.get('assigneeAgentId') or '')[:8]}  origin={i.get('originKind')}  title={title[:60]}")
    else:
        print(f'  {t}: NOT FOUND')

# Paperclip API Discipline — Encoding Reference

Operational companion to [`processes/21-issue-discipline.md`](../../processes/21-issue-discipline.md).
This doc translates the rule set into specific API call patterns for agents using the Paperclip control plane.

---

## Blocked-issue creation: required fields

When PATCHing or creating an issue with `status: "blocked"`, always include:

### 1. `blockedByIssueIds` (platform-native, preferred)

Set this when another Paperclip issue is the blocker. The platform fires `issue_blockers_resolved` wake automatically when all listed issues reach `done`.

```bash
curl -s -X PATCH "$PAPERCLIP_API_URL/api/issues/$ISSUE_ID" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID" \
  -H "Content-Type: application/json" \
  -d '{"status":"blocked","blockedByIssueIds":["<blocker-issue-id>"]}'
```

### 2. `<!-- unblock_owner: ... -->` in description (interim convention)

Append or update the HTML comment in the issue description until the platform adds a native `unblockOwner` field. The comment must be the last item in the description so automated scans can reliably extract it.

```bash
# Read current description, append unblock_owner comment, PATCH back
CURRENT_DESC=$(curl -s -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  "$PAPERCLIP_API_URL/api/issues/$ISSUE_ID" | python3 -c "import sys,json; print(json.load(sys.stdin)['description'])")

NEW_DESC="${CURRENT_DESC}

<!-- unblock_owner: cto -->"

curl -s -X PATCH "$PAPERCLIP_API_URL/api/issues/$ISSUE_ID" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID" \
  -H "Content-Type: application/json" \
  --data-binary @- <<EOF
{"status":"blocked","description":$(echo "$NEW_DESC" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")}
EOF
```

### 3. Load-bearing comment

The PATCH alone is not sufficient for capacity-blocked issues. Post a comment explaining:
- What specific decision / action is needed
- Who must act (matching `unblock_owner`)
- What the requester needs to provide

```bash
scripts/paperclip-issue-update.sh --issue-id "$ISSUE_ID" <<'MD'
Blocked — waiting on CTO decision.

- **What's needed:** confirm whether the `stale_lock_recovery` mechanism in `infra/` should use
  `file_lock_timeout_sec` from runtimeConfig or a hard-coded 300 s default.
- **Owner:** CTO
- **Impact:** Development cannot proceed on QUA-NNN until this is resolved.
MD
```

---

## Issue creation: budget guard

Before creating child issues in a heartbeat, count how many you've already created this run:

```bash
# Check issues created by me in this run (proxy: filter by parentId + createdAt window)
curl -s -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  "$PAPERCLIP_API_URL/api/companies/$PAPERCLIP_COMPANY_ID/issues?assigneeAgentId=$PAPERCLIP_AGENT_ID&status=todo,in_progress" \
  | python3 -c "
import sys, json
from datetime import datetime, timezone, timedelta
items = json.load(sys.stdin)
cutoff = (datetime.now(timezone.utc) - timedelta(hours=1)).isoformat()
recent = [i for i in items if i.get('createdAt','') > cutoff]
print(len(recent))
"
```

If the count meets or exceeds the budget for your tier (see `processes/issue_discipline.md` § 2), stop creating issues for this heartbeat. Use comments instead.

---

## Smoke-test: comment, not issue

When a smoke test run completes (pass or fail), post the result as a comment on the parent backtest issue. Do NOT create a child issue unless the failure reveals a new root-cause class.

Comment template:

```bash
scripts/paperclip-issue-update.sh --issue-id "$PARENT_ISSUE_ID" <<MD
**Smoke run** $(date -u +%Y-%m-%dT%H:%M:%SZ)

| Symbol | EA | Result | Notes |
|---|---|---|---|
| EURUSD | QM5_1002 | ✅ PASS | 847 trades, -0.3 % DD |
| GBPUSD | QM5_1002 | ❌ FAIL | 0 trades — ZT detected |

ZT on GBPUSD is a new root-cause class (spread filter too tight on 4H). Creating child issue [QUA-NNN].
MD
```

---

## Blocked-issue scan (CEO heartbeat query)

```bash
curl -s -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  "$PAPERCLIP_API_URL/api/companies/$PAPERCLIP_COMPANY_ID/issues?status=blocked" \
  | python3 -c "
import sys, json, re
items = json.load(sys.stdin)
missing = []
for i in items:
    desc = i.get('description') or ''
    if '<!-- unblock_owner:' not in desc:
        missing.append((i['identifier'], i['title'][:60]))
if missing:
    print(f'{len(missing)} blocked issues lack unblock_owner:')
    for id_, title in missing:
        print(f'  {id_}: {title}')
else:
    print('All blocked issues have unblock_owner encoding.')
"
```

---

## References

- [`processes/21-issue-discipline.md`](../../processes/21-issue-discipline.md) — authoritative rule set
- [`decisions/2026-05-01_issue_inflation_discipline.md`](../../decisions/2026-05-01_issue_inflation_discipline.md) — DL-057 formal decision record
- `paperclip/governance/decision_log.md` § DL-057 — decision log entry
- [QUA-647](/QUA/issues/QUA-647) — authoring issue

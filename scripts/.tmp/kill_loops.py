import json, urllib.request

actions = [
    {
        "id": "34bf4d2e-0d37-4f29-9a72-7063e300c5c2",
        "label": "QUA-1549",
        "status": "done",
        "comment": """Board Advisor closing as done at 2026-05-15T07:03Z.

Verified work that Dev-Codex actually completed:
- `framework/EAs/QM5_1002_davey-eu-night/QM5_1002_davey-eu-night.ex5` exists (106220 bytes, mtime 2026-05-15 08:54 local) — fresh build by Dev-Codex this heartbeat
- T1..T5 deployment to `MQL5/Experts/QM/QM5_1002_davey-eu-night.ex5` already done with matching SHA across all 5 (hash 0999E40F...)

Dev-Codex was looping (`issue_continuation_needed` -> 11 runs/hour) because the harness kept firing continuation_needed on an in_progress issue that the agent never marked done. The work itself was already complete after the first run; the loop was burning ~30 tokens × 11 runs/hr for no new output.

**Phantom `QM5_1002` (without -davey-eu-night suffix)**: this is a registry-only entry with no source code in `framework/EAs/`. Build is not possible. Phase Orchestrator will keep failing P1 for it hourly until someone removes it from the EA registry. Spawning a separate cleanup issue is out-of-scope for QUA-1549 build work; tracking is in the broader QUA-1547 (this issue's parent).

Closing this thread to break the continuation loop. If Phase Orchestrator detects a regression on QM5_1002_davey-eu-night after this point, a new build issue will be drafted."""
    },
    {
        "id": "52c652f5-873a-4982-a316-14de405c9990",
        "label": "QUA-1483 dashboard",
        "status": "cancelled",
        "comment": """Board Advisor cancelling at 2026-05-15T07:03Z.

This issue was in a pure runaway (145 `issue_continuation_needed` runs in last 60 min, **zero comments produced** — no work output at all). Pattern matches the documented `continuation-runaway` bug (memory `feedback_continuation_runaway_only_patchable.md`); the only durable fix is the heartbeat.ts patch from QUA-1031.

This was a `routine_execution` issue from "Local dashboard and strategy archive regeneration" (`b6d8c351`). The routine itself is unchanged — it will create a fresh issue on next cron fire. Cancelling THIS instance terminates the loop. If the new instance also loops, the routine itself needs the QUA-1031 patch or to be paused."""
    },
    {
        "id": None,  # short id
        "short_id": "1c3a4d41",
        "label": "QUA-1516 website",
        "status": "cancelled",
        "comment": """Board Advisor cancelling at 2026-05-15T07:03Z.

Same pattern as QUA-1483: 146 `issue_continuation_needed` runs in last 60 min, zero comments. Pure continuation runaway on a `routine_execution` issue ("Website publication dry-run manifest"). Cancelling this instance terminates the loop. The routine will create a fresh one on next cron fire."""
    },
    {
        "id": "5d2f0ffd",
        "short_id": "5d2f0ffd",
        "label": "QUA-803 gmail-poller",
        "status": "cancelled",
        "comment": """Board Advisor cancelling at 2026-05-15T07:03Z.

This is the Gmail Monitor rolling inbox poll tracker. It received 97 wake events in 60 min and produced 167 liveness comments — average ~22 second interval between firings, despite each comment claiming "next poll 07:07Z" (5-min cadence intended). Classic continuation-runaway on a rolling tracker.

Cancelling this tracker stops the loop. Gmail Monitor's actual polling cadence is owned by its underlying routine; the tracker just records pulses. A new rolling tracker can be created cleanly once the underlying continuation runaway is patched (QUA-1031). For now, polling continues without the tracker."""
    },
    {
        "id": "f0fbfa34",
        "short_id": "f0fbfa34",
        "label": "QUA-838 quartz-poc",
        "status": "cancelled",
        "comment": """Board Advisor cancelling at 2026-05-15T07:03Z.

74 `issue_continuation_needed` runs in last 60 min on an issue that is **explicitly blocked on an OWNER decision** ("OWNER decision: pu..."). Every CTO heartbeat posts: "No action taken in this heartbeat. QUA-838 remains blocked on the same unchanged blocker chain." Each run burns tokens for no output.

If the underlying OWNER decision is still wanted, it belongs in a separate decision-tracker issue with `wakeOnDemand` semantics — not a `routine_execution` that fires every minute. Cancelling stops the burn."""
    },
]

# Resolve short ids
for a in actions:
    if not a.get("id") and a.get("short_id"):
        for st in ["in_progress","backlog","blocked"]:
            r = urllib.request.urlopen(f"http://127.0.0.1:3100/api/companies/03d4dcc8-4cea-4133-9f68-90c0d99628fb/issues?status={st}&limit=200", timeout=15)
            for i in json.loads(r.read()):
                if i.get('id','').startswith(a["short_id"]):
                    a["id"] = i["id"]
                    break
            if a.get("id"): break

# Step 1: post comment first; Step 2: PATCH status
for a in actions:
    iid = a["id"]
    if not iid:
        print(f"!! {a['label']}: id not resolved")
        continue
    print(f"=== {a['label']} ({iid[:8]}) ===")
    # Comment first
    body = a["comment"]
    req = urllib.request.Request(f"http://127.0.0.1:3100/api/issues/{iid}/comments",
        data=json.dumps({"body":body}).encode("utf-8"),
        headers={"Content-Type":"application/json"}, method="POST")
    try:
        r = urllib.request.urlopen(req, timeout=15)
        cid = json.loads(r.read()).get('id','?')[:8]
        print(f"  comment posted: {cid}")
    except Exception as e:
        print(f"  comment FAILED: {e}")
        continue
    # Then PATCH status
    req = urllib.request.Request(f"http://127.0.0.1:3100/api/issues/{iid}",
        data=json.dumps({"status":a["status"]}).encode("utf-8"),
        headers={"Content-Type":"application/json"}, method="PATCH")
    try:
        r = urllib.request.urlopen(req, timeout=15)
        d = json.loads(r.read())
        print(f"  status: {d.get('status')}")
    except Exception as e:
        print(f"  patch FAILED: {e}")

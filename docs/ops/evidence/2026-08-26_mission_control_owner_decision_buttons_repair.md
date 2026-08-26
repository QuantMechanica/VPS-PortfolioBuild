# Mission Control OWNER decision buttons repair — 2026-08-26

Task: `8f0e4d53-076d-47d6-979a-637c3039af6c`
Status: implementation and focused verification complete; awaiting review.

## Root cause

`render_cockpit_v2.py` stored the inline decision JavaScript in a normal Python
triple-quoted string. The JavaScript confirmation text used `\n` escapes. Python
consumed those escapes while rendering, leaving literal line breaks inside a
single-quoted JavaScript string. Chrome therefore rejected the complete inline
script with:

```text
SyntaxError: Invalid or unexpected token
```

The failure occurred before the delegated click listener was registered. The
loopback service, token, card hashes and endpoint were healthy; the dead buttons
were a renderer escaping defect, not a receipt-store or router failure.

## Repair

The decision script is now a raw Python string, preserving JavaScript `\n`
escapes in generated HTML. No receipt, handoff, routing, Factory, deployment or
live-trading contract was weakened or expanded.

A browser E2E regression test now exercises the full local path:

```text
file:// cockpit -> health GET -> confirm -> CORS preflight -> POST
-> append-only JSONL receipt -> feed DECIDED -> visible recorded card
```

Every file used by this test is under pytest's temporary directory. The handoff
stub returns `TEST_ONLY_NO_ROUTER_TASK` and creates no router task.

## Focused verification

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_owner_decision_browser_e2e.py \
  tools/strategy_farm/tests/test_render_cockpit_v2.py \
  tools/strategy_farm/tests/test_owner_decision_service.py \
  tools/strategy_farm/tests/test_owner_decision_store.py

20 passed in 8.17s
```

Generated-script syntax verification:

```text
node --check -
PASS (exit 0)
```

Temporary E2E receipt excerpt, explicitly marked TEST:

```json
{
  "schema": "qm.owner-decision-receipt/v2",
  "decision_id": "OWNER-DEC-TEST-BROWSER-E2E",
  "decision": "YES",
  "notes": "[TEST] Synthetic browser E2E receipt; not an OWNER decision.",
  "decision_card_sha256": "0c687a3f052aecbc9614d65331ae9d29d89d44d88523805fcb088594be1624a6",
  "execution_plan_sha256": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
  "receipt_id": "cd7bd154-ddc5-419e-9614-7c7984d2b42f",
  "receipt_sha256": "05af175db61259391d16ee7ae666242ce4807d44e21e7cffb7c8e58059fc31e6",
  "live_execution_authorized": false,
  "deployment_authorized": false,
  "autotrading_authorized": false
}
```

This receipt existed only in `scratch/pytest-*`; it was not appended to
`D:/QM/strategy_farm/state/owner_decision_receipts.jsonl`, did not mutate the
production `owner_decisions.json`, and did not represent OWNER authority.

## Live surface smoke check

The canonical renderer rewrote both dashboard aliases from the repaired code:

```text
cockpit.html bytes: 102382
cockpit.html SHA-256:    4C5B2C45C7B9F1ED0475FE62EDE559EA46BB259470C1CB31EA0D282D33B8EA31
cockpit_v2.html SHA-256: 4C5B2C45C7B9F1ED0475FE62EDE559EA46BB259470C1CB31EA0D282D33B8EA31
```

A headless Chrome smoke test opened the production `file://` page while
intercepting and aborting the POST before it reached the production service:

```text
decision buttons: 18
service state: INTAKE VERBUNDEN
page errors: []
click handler attempted POST: 1
visible fail-closed status after intercepted POST: NICHT GESPEICHERT: Failed to fetch
```

Thus the production page's JavaScript parses, the health path connects, the
click handler runs, and failed persistence is visibly reported. No production
OWNER choice or receipt was fabricated during the smoke check.

## Rollback

Revert the repair commit on `agents/board-advisor`, then rerun:

```text
python C:/QM/repo/tools/strategy_farm/render_cockpit_v2.py
```

No database rollback, receipt deletion or service restart is required. Receipts
remain append-only. T1-T10, Factory workers, T_Live and AutoTrading were not
changed or interrupted.

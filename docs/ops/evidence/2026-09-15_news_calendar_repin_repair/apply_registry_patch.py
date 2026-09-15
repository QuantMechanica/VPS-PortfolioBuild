"""OWNER/FABLE-APPLIED governed repair patch for the dxz23 news-calendar registry pin.

Authority: OWNER-DEC-CALENDAR-REPIN (kein AI-Commit). This script is run BY OWNER or Fable
after reviewing prepared_registry_patch.json in this directory. It restores the 19
calendar-identity fields (receipt 000016 attested after state) that an un-attested
`git restore` reverted, so the next scheduled QM_NewsCalendar_Refresh can mint receipt
000017 and the chain self-heals.

Guards (all must pass or nothing is written):
  G1  every patch field's current_value matches the live registry byte-context
  G2  replacement occurrence counts match render_registry_update semantics exactly
      (11 primary-sha, 8 secondary-sha, 19 coverage_end replacements)
  G3  post-write parse: every json_pointer field equals restore_to
  G4  post-write pin state equals the receipt-000016 chain tail for both calendars
"""
import hashlib
import json
import re
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
PATCH = json.loads((HERE / "prepared_registry_patch.json").read_text(encoding="utf-8"))
REG = Path(PATCH["registry"]["path"])
RCP = Path(PATCH["governing_receipt"]["path"])

PRIMARY_AFTER = "8744295adcb7c3aeb0a8fd25d7209f37d34159aee1913472b7c0522afa916a46"
SECONDARY_AFTER = "3abc0cd3cea5c5385e78f5c7027de11d0932202971f886704e6668fcef75da94"
COVERAGE_AFTER = "2026-09-19"
EXPECTED_COUNTS = {PRIMARY_AFTER: 11, SECONDARY_AFTER: 8, COVERAGE_AFTER: 19}


def fail(msg):
    print(json.dumps({"ok": False, "status": "REFUSED", "error": msg}, sort_keys=True))
    sys.exit(2)


def resolve(root, pointer):
    # pointer form: $.contracts[23].calendar.sources[0]/field
    obj_ptr, _, field = pointer.rpartition("/")
    node = root
    for k in obj_ptr[2:].replace("]", "").replace("[", ".").split("."):
        node = node[int(k)] if k.isdigit() else node[k]
    return node, field


def main():
    raw = REG.read_bytes()
    before_sha = hashlib.sha256(raw).hexdigest()
    receipt = json.loads(RCP.read_text(encoding="utf-8"))
    if receipt["receipt_sha256"] != PATCH["governing_receipt"]["receipt_sha256"]:
        fail("governing receipt sha mismatch vs prepared patch")

    fields = PATCH["reverted_to_before_fields"]
    parsed = json.loads(raw)

    # G1: current values must match the patch's recorded current_value
    for f in fields:
        node, key = resolve(parsed, f["json_pointer"])
        if node.get(key) != f["current_value"]:
            fail(f"G1: {f['json_pointer']} current={node.get(key)!r} expected={f['current_value']!r}")

    # G2: exact-count byte replacements (mirrors render_registry_update)
    out = raw.decode("utf-8")
    for new_value, count in EXPECTED_COUNTS.items():
        if new_value in (PRIMARY_AFTER, SECONDARY_AFTER):
            old = next(f["current_value"] for f in fields if f["restore_to"] == new_value)
            pattern = re.compile(r'("sha256"\s*:\s*")' + re.escape(old) + r'(")')
        else:
            old = "2026-09-12"
            pattern = re.compile(r'("coverage_end"\s*:\s*")' + re.escape(old) + r'(")')
        out, n = pattern.subn(r"\g<1>" + new_value + r"\g<2>", out)
        if n != count:
            fail(f"G2: replaced {n} occurrences of {new_value[:12]}..., expected {count}")

    # G3 + G4 on the rendered result (before writing)
    rendered = json.loads(out)
    for f in fields:
        node, key = resolve(rendered, f["json_pointer"])
        if node.get(key) != f["restore_to"]:
            fail(f"G3: {f['json_pointer']} rendered={node.get(key)!r} expected={f['restore_to']!r}")
    for name, after_hash in (("news_calendar_2015_2025.csv", PRIMARY_AFTER),
                             ("forex_factory_calendar_clean.csv", SECONDARY_AFTER)):
        src = next(s for s in receipt["sources"] if s["name"] == name)
        for jp in src["registry_target_json_paths"]:
            node, _ = resolve(rendered, jp + "/sha256")
            if node["sha256"] != after_hash or node["coverage_end"] != COVERAGE_AFTER:
                fail(f"G4: {jp} does not carry receipt-16 after identity")

    # write atomically
    fd, tmp = tempfile.mkstemp(dir=str(REG.parent), prefix=REG.name + ".", suffix=".tmp")
    with open(fd, "wb") as h:
        h.write(out.encode("utf-8"))
    Path(tmp).replace(REG)
    after_sha = hashlib.sha256(REG.read_bytes()).hexdigest()
    print(json.dumps({
        "ok": True,
        "status": "APPLIED",
        "registry": str(REG),
        "fields_restored": len(fields),
        "file_sha256_before": before_sha,
        "file_sha256_after": after_sha,
        "note": "pin now equals receipt-16 tail; next scheduled QM_NewsCalendar_Refresh mints 000017; "
                "do NOT commit without OWNER direction (kein AI-Commit)",
    }, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

"""Velocity intake wave 3: add target_symbols (frontmatter + body line) to approved
intraday cards that lack them. Symbols come from the plan JSON (registry active rows
in slot order, or the OWNER 2026-09-01 default universe). Backs up every card first.
Usage: amend_cards.py <plan.json> <ea_id>[,<ea_id>...] | ALL
"""
import json, os, re, shutil, sys, datetime as dt

plan_path, sel = sys.argv[1], sys.argv[2]
plan = json.load(open(plan_path, encoding="utf-8"))
want = None if sel == "ALL" else set(sel.split(","))
EV = r"C:\QM\repo\docs\ops\evidence\2026-09-20_velocity_book\card_backups"
os.makedirs(EV, exist_ok=True)
REPO_MIRROR = r"C:\QM\repo\artifacts\cards_approved"
log = []


def amend(path, syms):
    txt = open(path, encoding="utf-8").read()
    if not txt.startswith("---"):
        return "NO_FRONTMATTER"
    end = txt.find("\n---", 3)
    fm, body = txt[3:end], txt[end + 4:]
    if re.search(r"^target_symbols\s*:", fm, re.M):
        return "ALREADY_HAS_TARGET_SYMBOLS"
    line = "target_symbols: [" + ", ".join(syms) + "]\n"
    # insert after `period:` when present, else before g0_status, else at end
    m = re.search(r"^period\s*:.*\n", fm, re.M)
    if m:
        fm = fm[: m.end()] + line + fm[m.end():]
    else:
        m = re.search(r"^g0_status\s*:", fm, re.M)
        fm = (fm[: m.start()] + line + fm[m.start():]) if m else (fm.rstrip("\n") + "\n" + line)
    body_line = "Target symbols: " + ", ".join(syms)
    if not re.search(r"^\s*(?:Universe|Target symbol\(s\)|Target symbols?)\b", body, re.I | re.M):
        body = body.rstrip("\n") + (
            "\n\n## Symbol Universe (amendment 2026-09-20, Velocity intake)\n\n"
            + body_line
            + "\n\nSymbols follow the EA's active magic-registry rows in slot order (or the OWNER 2026-09-01 "
            "default universe when no rows existed); `.DWX` is the factory custom-symbol name only. "
            "Amendment authority: FABLE-DEC-VELOCITY-INTAKE-20260920.\n"
        )
    open(path, "w", encoding="utf-8", newline="\n").write("---" + fm + "\n---" + body)
    return "AMENDED"


for p in plan:
    if want and p["ea_id"] not in want:
        continue
    card = p["card_path"]
    if not os.path.exists(card):
        log.append({"ea": p["ea_label"], "result": "CARD_MISSING", "path": card}); continue
    name = os.path.basename(card)
    shutil.copy2(card, os.path.join(EV, name + ".bak"))
    r = amend(card, p["target_symbols"])
    entry = {"ea": p["ea_label"], "d_card": r, "symbols": p["target_symbols"], "policy": p["symbol_policy"]}
    mirror = os.path.join(REPO_MIRROR, name)
    if os.path.exists(mirror):
        shutil.copy2(mirror, os.path.join(EV, name + ".repo.bak"))
        entry["repo_mirror"] = amend(mirror, p["target_symbols"])
    log.append(entry)
stamp = dt.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
out = os.path.join(os.path.dirname(EV), f"wave3_card_amendment_log_{stamp}.json")
json.dump(log, open(out, "w", encoding="utf-8"), indent=1)
print(json.dumps(log, indent=1)[:3000])
print("log:", out)

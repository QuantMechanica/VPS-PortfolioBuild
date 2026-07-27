"""Backfill missing strategy_* parameters into backtest set files, from the EA itself.

THE DEFECT. Q08 sub-gate 8.5 (neighborhood) perturbs strategy parameters around
the baseline set file. If the set file declares none, the sub-gate raises

    ValueError('baseline setfile has no strategy parameters: <path>')

which classifies INVALID and maps to INFRA_FAIL. INFRA_FAIL is not a merit
verdict, so the item looks retryable and gets requeued -- and fails identically,
forever. QM5_9936/USDJPY burned two runs on exactly this, and it is the strongest
sleeve in the FTMO campaign.

THE SCALE. 390 of ~1270 backtest set files carry no strategy_* line at all. That
is a plausible principal cause of the 163 farm-wide Q08 INFRA_FAIL rows (34% of
all Q08 runs) -- an entire class of EAs permanently stuck at the last automated
gate for a set-file reason rather than a strategy one.

THE FIX, and why it is safe. The values are taken from the EA's OWN compiled-in
`input` defaults, not from the strategy card. A set file that omits a parameter
leaves the EA using its default, so writing that same default explicitly cannot
change behaviour -- the run is bit-identical, and prior gate evidence stays valid.
Taking card values instead COULD change behaviour, which is why this tool refuses
to use them.

Verified per file before writing: every parameter added must be absent from the
set file, and the file must gain nothing else.

Usage:
    python tools/strategy_farm/backfill_setfile_strategy_params.py --ea QM5_9936
    python tools/strategy_farm/backfill_setfile_strategy_params.py --all --dry-run
"""
import argparse
import glob
import os
import re
import sys

INPUT_RE = re.compile(
    r"^\s*input\s+(?:const\s+)?\w+\s+(strategy_\w+)\s*=\s*([^;]+);", re.M)


def ea_defaults(ea_dir):
    """strategy_* input defaults declared by the EA's own .mq5."""
    src = glob.glob(os.path.join(ea_dir, "*.mq5"))
    if not src:
        return {}
    text = open(src[0], encoding="utf-8", errors="replace").read()
    out = {}
    for name, raw in INPUT_RE.findall(text):
        v = raw.strip().rstrip("f").strip()
        if v.lower() in ("true", "false"):
            v = "1" if v.lower() == "true" else "0"
        out[name] = v
    return out


def existing_keys(text):
    return {m.split("=", 1)[0].strip()
            for m in text.splitlines()
            if m.strip() and not m.strip().startswith(";") and "=" in m}


def backfill(path, defaults, dry_run):
    text = open(path, encoding="utf-8", errors="replace").read()
    if re.search(r"^strategy_\w+=", text, re.M):
        return None                      # already has them; never touch
    have = existing_keys(text)
    add = {k: v for k, v in defaults.items() if k not in have}
    if not add:
        return None
    lines = text.rstrip("\n").splitlines()
    lines.append("; strategy params backfilled from the EA's own input defaults;")
    lines.append("; behaviour-identical (an omitted param already used this value),")
    lines.append("; required by Q08 sub-gate 8.5 which perturbs named parameters.")
    for k in sorted(add):
        lines.append(f"{k}={add[k]}")
    new = "\n".join(lines) + "\n"
    if not dry_run:
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(new)
    return sorted(add)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ea", help="bare or full slug, e.g. QM5_9936")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    if not args.ea and not args.all:
        ap.error("pass --ea or --all")

    pattern = f"framework/EAs/{args.ea}*" if args.ea else "framework/EAs/*"
    touched = skipped_no_defaults = 0
    for ea_dir in sorted(glob.glob(pattern)):
        if not os.path.isdir(ea_dir):
            continue
        defaults = ea_defaults(ea_dir)
        sets = glob.glob(os.path.join(ea_dir, "sets", "*_backtest.set"))
        if not sets:
            continue
        if not defaults:
            if any(not re.search(r"^strategy_\w+=",
                                 open(s, encoding="utf-8", errors="replace").read(), re.M)
                   for s in sets):
                skipped_no_defaults += 1
            continue
        for s in sorted(sets):
            added = backfill(s, defaults, args.dry_run)
            if added:
                touched += 1
                print(f"{'WOULD ADD' if args.dry_run else 'ADDED'} "
                      f"{len(added):2} to {os.path.basename(s)}")
                if args.ea:
                    for k in added:
                        print(f"      {k}={defaults[k]}")
    print()
    print(f"set files {'that would be ' if args.dry_run else ''}updated: {touched}")
    if skipped_no_defaults:
        print(f"EAs skipped -- no strategy_* inputs in the .mq5 either: "
              f"{skipped_no_defaults}")
        print("  those cannot be fixed here; the EA declares no tunable strategy")
        print("  parameter at all, so Q08 8.5 has nothing to perturb by design.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

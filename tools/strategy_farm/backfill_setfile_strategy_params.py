"""Backfill missing strategy_* parameters into backtest set files, from the EA itself.

THE DEFECT. Q08 sub-gate 8.5 (neighborhood) perturbs strategy parameters around
the baseline set file. If the set file declares none, the sub-gate raises

    ValueError('baseline setfile has no strategy parameters: <path>')

which classifies INVALID and maps to INFRA_FAIL. INFRA_FAIL is not a merit
verdict, so the item looks retryable and gets requeued -- and fails identically,
forever. QM5_9936/USDJPY burned two runs on exactly this, and it is the strongest
sleeve in the FTMO campaign.

THE SCALE -- corrected downward after Codex's review disputed my first figure, and
he was right. I had claimed this was "a plausible principal cause of 34% of all
Q08 runs", inferred from a file count rather than measured against the failures
themselves. Measured properly, of 204 Q08 INFRA_FAIL rows:

    158  set file DOES carry strategy_* params  -> some other cause, undiagnosed
     46  set file carries none                  -> this defect

So this explains 46 rows, roughly a fifth of Q08 INFRA_FAIL, not a third of every
Q08 run. It is worth fixing and it unblocks the strongest FTMO campaign sleeve,
but the remaining 158 have a different root cause that nothing here addresses.

THE FIX. The values are taken from the EA's OWN compiled-in `input` defaults, not
from the strategy card. A set file that omits a parameter leaves the EA using its
default, so writing that same default explicitly cannot change behaviour -- the
run is bit-identical. Taking card values instead COULD differ, which is why this
tool refuses to use them.

WHERE THE SAFETY CLAIM STOPS -- a correction to my own first version, which said
"prior gate evidence stays valid" without checking. It does not, universally:

    Q04-Q07 aggregates store NO set-file hash (0/15 sampled per gate) -> unaffected
    Q08     stores baseline_run.baseline_setfile_sha256 and
            portfolio_stream.source_setfile_sha256
    Q10     stores a set-file hash in 3/15 sampled aggregates

So editing a set file breaks the identity binding of any Q08 and Q10 evidence
already recorded against it. For the 389 EAs this targets that is mostly harmless
-- their Q08 is precisely the INFRA_FAIL we are trying to clear, so there is no
valid Q08 evidence to lose. Q10 is different: it is the closing per-(EA, symbol)
verdict, and 7 of the 389 already hold Q10 evidence, 6 of them PASS -- including
10128 and 10145 on XAUUSD, the only two challenge_ready sleeves in the book.

Editing those would silently invalidate the strongest evidence we own. The tool
therefore SKIPS any EA holding Q10 evidence unless --allow-q10-rebind is passed,
and prints what it skipped. Clearing an INFRA_FAIL is not worth breaking a PASS.

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
import sqlite3
import sys

DB = r"D:\QM\strategy_farm\state\farm_state.sqlite"


def eas_with_q10_evidence():
    """Bare ea_ids holding any Q10 verdict. Their set-file hash is bound into
    that evidence, so a rewrite silently breaks the closing gate's identity."""
    try:
        con = sqlite3.connect(f"file:{DB.replace(os.sep, '/')}?mode=ro", uri=True)
    except sqlite3.Error:
        return None                      # unknown, not "none" -- caller must fail closed
    try:
        rows = con.execute(
            "select distinct ea_id, verdict from work_items "
            "where phase='Q10' and status='done'").fetchall()
    except sqlite3.Error:
        return None
    finally:
        con.close()
    out = {}
    for ea_id, verdict in rows:
        bare = str(ea_id).replace("QM5_", "").split("_")[0]
        out.setdefault(bare, set()).add(str(verdict or ""))
    return out

INPUT_RE = re.compile(
    r"^\s*input\s+(?:const\s+)?(\w+)\s+(strategy_\w+)\s*=\s*([^;]+);", re.M)

SCALAR_RE = re.compile(r"^-?\d+(?:\.\d+)?f?$")


def serialize(raw):
    """Set-file text for an MQL default, or None if it cannot be trusted.

    Codex's review caught this and it is the most dangerous defect the first
    version had. A set file stores VALUES, but MQL defaults are frequently
    symbolic:

        input ENUM_TIMEFRAMES strategy_tf = PERIOD_H1;   -> 16385, not "PERIOD_H1"
        input string strategy_host = "SP500.DWX";        -> unquoted
        input ENUM_MA_METHOD  strategy_ma = MODE_SMA;    -> 0

    Across the EA tree there are 335 such occurrences in 55 distinct forms.
    Writing the symbol verbatim would leave MT5 parsing it as 0 -- silently
    changing the strategy, which is precisely what this tool claims cannot happen.

    So anything that is not a plain numeric literal or a bool fails CLOSED. Not
    guessing an enum's ordinal is the entire point: a wrong ordinal is invisible
    and a refusal is not.
    """
    v = raw.strip()
    if v.lower() in ("true", "false"):
        return "1" if v.lower() == "true" else "0"
    if SCALAR_RE.match(v):
        return v.rstrip("f")
    return None


def ea_defaults(ea_dir):
    """strategy_* input defaults from the EA's own .mq5.

    Returns (usable, refused) so callers can report what was skipped instead of
    silently emitting a partial parameter block -- a set file carrying some
    strategy params but not others still misrepresents the baseline.
    """
    src = glob.glob(os.path.join(ea_dir, "*.mq5"))
    if not src:
        return {}, {}
    text = open(src[0], encoding="utf-8", errors="replace").read()
    usable, refused = {}, {}
    for typ, name, raw in INPUT_RE.findall(text):
        val = serialize(raw)
        if val is None:
            refused[name] = f"{typ} = {raw.strip()}"
        else:
            usable[name] = val
    return usable, refused


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
    ap.add_argument("--allow-q10-rebind", action="store_true",
                    help="edit set files even for EAs holding Q10 evidence; this "
                         "breaks the identity hash bound into that closing verdict")
    args = ap.parse_args()
    if not args.ea and not args.all:
        ap.error("pass --ea or --all")

    q10 = eas_with_q10_evidence()
    if q10 is None and not args.allow_q10_rebind:
        print("ERROR: cannot read the farm DB to check for Q10 evidence.", file=sys.stderr)
        print("Failing closed -- editing a set file bound into a Q10 verdict would",
              file=sys.stderr)
        print("break it silently. Re-run when the DB is readable, or pass",
              file=sys.stderr)
        print("--allow-q10-rebind if you have verified this another way.", file=sys.stderr)
        return 2

    pattern = f"framework/EAs/{args.ea}*" if args.ea else "framework/EAs/*"
    touched = skipped_no_defaults = 0
    skipped_q10 = []
    skipped_unserializable = []
    for ea_dir in sorted(glob.glob(pattern)):
        if not os.path.isdir(ea_dir):
            continue
        bare = os.path.basename(ea_dir).replace("QM5_", "").split("_")[0]
        if not args.allow_q10_rebind and q10 and bare in q10:
            verdicts = ",".join(sorted(v for v in q10[bare] if v))
            skipped_q10.append((os.path.basename(ea_dir), verdicts))
            continue
        defaults, refused = ea_defaults(ea_dir)
        sets = glob.glob(os.path.join(ea_dir, "sets", "*_backtest.set"))
        if not sets:
            continue
        if refused:
            # A partial block is worse than none: the baseline would then declare
            # some parameters and hide others, and 8.5 would perturb a strategy
            # that never ran. Refuse the whole EA until serialization is proven.
            skipped_unserializable.append((os.path.basename(ea_dir), refused))
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
    if skipped_q10:
        print()
        print(f"SKIPPED -- these hold Q10 evidence whose identity hash binds this "
              f"set file ({len(skipped_q10)}):")
        for ea, verdicts in skipped_q10:
            print(f"   {ea:46} Q10={verdicts or 'unknown'}")
        print("  Clearing an INFRA_FAIL is not worth invalidating a closing verdict.")
        print("  To include them anyway, pass --allow-q10-rebind and plan a Q10 re-run.")
    if skipped_unserializable:
        print()
        print(f"REFUSED -- non-scalar defaults that cannot be serialized safely "
              f"({len(skipped_unserializable)} EAs):")
        for ea, refused in skipped_unserializable[:12]:
            sample = "; ".join(f"{k}={v}" for k, v in list(refused.items())[:2])
            print(f"   {ea:46} {sample}")
        if len(skipped_unserializable) > 12:
            print(f"   ... and {len(skipped_unserializable) - 12} more")
        print("  A set file stores values, not symbols: PERIOD_H1 must become 16385,")
        print("  MODE_SMA must become 0, and a quoted string must lose its quotes.")
        print("  Guessing an ordinal wrong is invisible; refusing is not.")
    if skipped_no_defaults:
        print(f"EAs skipped -- no strategy_* inputs in the .mq5 either: "
              f"{skipped_no_defaults}")
        print("  those cannot be fixed here; the EA declares no tunable strategy")
        print("  parameter at all, so Q08 8.5 has nothing to perturb by design.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Apply the Gate Manifest v4 vault migration (idempotent).

Steps (see ARCHIVE_PLAN.md, section F):
  1. Move the 9 superseded v3 pages into _ARCHIV/03 Pipeline/ with a "superseded by
     v4 2026-08-23" header.
  2. Copy the staged v4 pages into the vault (overwrite Q00-Q08 + hubs, create Q09-Q17
     + Gate Manifest v4 Diff).
  3. Apply the listed inbound-wikilink retargets and in-place token replacements.
  4. Run the vault linter and print PASS/FAIL.

Default is --dry-run (nothing is written). --apply performs the migration.
DO NOT run --apply without explicit authorization.

Usage:
  python APPLY.py [--dry-run] [--apply] [--vault "<path>"]
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

# --- Paths -------------------------------------------------------------------

DEFAULT_VAULT = Path("G:/My Drive/QuantMechanica - Company Reference")
STAGING_ROOT = Path(__file__).resolve().parent
STAGING_PIPELINE = STAGING_ROOT / "03 Pipeline"

ARCHIVE_HEADER = (
    "> **Superseded by v4 2026-08-23.** Diese Seite ist der eingefrorene historische v3-Stand.\n"
    "> Der aktuelle lineare 3-Phasen-Vertrag steht in `03 Pipeline/` (Q00–Q17) und in\n"
    "> [[Gate Manifest v4 Diff]]. Nicht mehr aktiv pflegen.\n\n"
)

# --- A: pages to move to _ARCHIV/03 Pipeline/ --------------------------------

ARCHIVE_PAGES = [
    "Q09 News Impact Mode.md",
    "Q10 Full-History Confirmation.md",
    "Q11 Portfolio Construction.md",
    "Q12 Operational Readiness.md",
    "Q13 Live Burn-In DXZ.md",
    "Q14 Optimization Admission.md",
    "Q15 Challenger Build and Freeze.md",
    "Q16 Head-to-Head Requalification.md",
    "Gate Manifest v3 Diff.md",
]

# --- B: staged pages to copy into 03 Pipeline/ -------------------------------

COPY_PAGES = [
    "Q00 Research Intake.md",
    "Q01 Build & Spec.md",
    "Q02 Baseline Screening.md",
    "Q03 Parameter Sweep.md",
    "Q04 Walk-Forward + Commission.md",
    "Q05 Gross Full-History Robustness.md",
    "Q06 Stress HARSH.md",
    "Q07 Multi-Seed.md",
    "Q08 Davey Statistical Validation.md",
    "Q09 Baseline Full Run.md",
    "Q10 News Impact + FTMO Recommendation.md",
    "Q11 Incumbent Full-History Confirmation.md",
    "Q12 Pattern Filter Selection.md",
    "Q13 Parameter Optimization & Freeze.md",
    "Q14 Best-Settings Head-to-Head.md",
    "Q15 Final Portfolio Construction.md",
    "Q16 Operational Readiness.md",
    "Q17 Live Burn-In DXZ.md",
    "Pipeline Overview.md",
    "Pipeline Operations Workflow.md",
    "Gate Manifest v4 Diff.md",
]

# New v4 filenames (relative to vault) that did not exist before — needed for the
# dry-run wikilink simulation.
NEW_PIPELINE_FILES = [
    "Q09 Baseline Full Run.md",
    "Q10 News Impact + FTMO Recommendation.md",
    "Q11 Incumbent Full-History Confirmation.md",
    "Q12 Pattern Filter Selection.md",
    "Q13 Parameter Optimization & Freeze.md",
    "Q14 Best-Settings Head-to-Head.md",
    "Q15 Final Portfolio Construction.md",
    "Q16 Operational Readiness.md",
    "Q17 Live Burn-In DXZ.md",
    "Gate Manifest v4 Diff.md",
]

# --- C + D: string replacements on active non-gate pages ---------------------
# Each entry: (relative_path, old, new). Applied with str.replace (all occurrences).
# Idempotent: if `old` is absent but `new` present, it is reported as already-applied.

REPLACEMENTS = [
    # C - inbound wikilink retargets
    ("05 Skills/qm-t6-deploy-verification.md",
     "[[../03 Pipeline/Q12 Operational Readiness]]",
     "[[../03 Pipeline/Q16 Operational Readiness]]"),
    ("05 Skills/qm-t6-deploy-verification.md",
     "[[../03 Pipeline/Q13 Live Burn-In DXZ]]",
     "[[../03 Pipeline/Q17 Live Burn-In DXZ]]"),
    ("12 ToDo/08_DXZ_Live_Book.md",
     "[[../03 Pipeline/Q11 Portfolio Construction|Q11]]",
     "[[../03 Pipeline/Q15 Final Portfolio Construction|Q15]]"),
    ("12 ToDo/08_DXZ_Live_Book.md",
     "[[../03 Pipeline/Q11 Portfolio Construction]]",
     "[[../03 Pipeline/Q15 Final Portfolio Construction]]"),
    ("12 ToDo/07_FTMO_Kampagne.md",
     "[[../03 Pipeline/Q11 Portfolio Construction|Q11]]",
     "[[../03 Pipeline/Q15 Final Portfolio Construction|Q15]]"),
    ("12 ToDo/07_FTMO_Kampagne.md",
     "[[../03 Pipeline/Q11 Portfolio Construction]]",
     "[[../03 Pipeline/Q15 Final Portfolio Construction]]"),
    ("12 ToDo/AI ToDos/OWNER.md",
     "[[03 Pipeline/Gate Manifest v3 Diff|Gate Manifest v3 Diff]]",
     "[[_ARCHIV/03 Pipeline/Gate Manifest v3 Diff|Gate Manifest v3 Diff]]"),
    # D - in-place token replacements (unambiguous whole-span/structural tokens)
    ("08 Current State/Current Operating State.md",
     "Q00\u2013Q13-Pipeline",
     "Q00\u2013Q17-Pipeline"),
    ("08 Current State/Current Operating State.md",
     "- **Pipeline-Rebaseline beauftragt:**",
     "- **Gate Manifest v4 (linear, 3 Makrophasen) \u2014 Vault-Migration gestaged:** "
     "Der Pfad wird in drei Makrophasen mit streng linearer Gate-Nummerierung "
     "Q00\u2013Q17 \u00fcberf\u00fchrt (Strategiebeweis Q00\u2013Q08 \u2192 Optimierung/"
     "Requalifikation Q09\u2013Q14 \u2192 Buchbewertung Q15\u2013Q17). Kriterien/Schwellen "
     "unver\u00e4ndert (ROT); der aktive Runtime-Vertrag bleibt v3 bis zur OWNER-Ratifikation. "
     "Staging + Migrationsplan: `docs/ops/rebaseline/vault_v4_staging/`; Diff: "
     "[[../03 Pipeline/Gate Manifest v4 Diff]].\n"
     "- **Pipeline-Rebaseline beauftragt:**"),
    ("08 Current State/Mission Baseline.md",
     "Q00\u2013Q16-Vertrag",
     "Q00\u2013Q17-Vertrag"),
    ("08 Current State/Mission Baseline.md",
     "EA-Lifecycle Q00..Q13",
     "EA-Lifecycle Q00..Q17"),
]

# --- linter regexes (mirrors 00 Governance/lint_company_reference.py) ---------

OLD_GATE_RE = re.compile(
    r"(?<![A-Za-z0-9])P(?:0|1|2|3(?:\.5)?|4|5[bc]?|6|7|8|9b?|10)(?![A-Za-z0-9])"
)
RETIRED_SYS_RE = re.compile(r"paperclip|papeclip", re.IGNORECASE)
LEGACY_ROLES_RE = re.compile(
    r"Token Controller|Controlling Agent|Doc-KM|Documentation-KM|Board Advisor"
    r"|(?<![A-Za-z0-9])(?:CoS|CTO|DevOps)(?![A-Za-z0-9])"
)
WIKILINK_RE = re.compile(r"\[\[([^\]]+)\]\]")


def read(p: Path) -> str:
    return p.read_text(encoding="utf-8", errors="replace")


# --- action planning ---------------------------------------------------------

def plan_archive(vault: Path):
    """Return list of (src, dst, status)."""
    out = []
    for name in ARCHIVE_PAGES:
        src = vault / "03 Pipeline" / name
        dst = vault / "_ARCHIV" / "03 Pipeline" / name
        if src.exists():
            out.append((src, dst, "MOVE"))
        elif dst.exists():
            out.append((src, dst, "ALREADY_ARCHIVED"))
        else:
            out.append((src, dst, "MISSING_BOTH"))
    return out


def plan_copy(vault: Path):
    out = []
    for name in COPY_PAGES:
        src = STAGING_PIPELINE / name
        dst = vault / "03 Pipeline" / name
        if not src.exists():
            out.append((src, dst, "STAGING_MISSING"))
        elif dst.exists():
            out.append((src, dst, "OVERWRITE"))
        else:
            out.append((src, dst, "CREATE"))
    return out


def plan_replacements(vault: Path):
    out = []
    for rel, old, new in REPLACEMENTS:
        path = vault / rel
        if not path.exists():
            out.append((rel, old, new, "FILE_MISSING"))
            continue
        text = read(path)
        if old in text:
            out.append((rel, old, new, "APPLY"))
        elif new in text:
            out.append((rel, old, new, "ALREADY_APPLIED"))
        else:
            out.append((rel, old, new, "ANCHOR_NOT_FOUND"))
    return out


# --- execution ---------------------------------------------------------------

def do_apply(vault: Path):
    # 1. archive
    for src, dst, status in plan_archive(vault):
        if status == "MOVE":
            dst.parent.mkdir(parents=True, exist_ok=True)
            content = read(src)
            if not content.startswith("> **Superseded by v4 2026-08-23."):
                content = ARCHIVE_HEADER + content
            dst.write_text(content, encoding="utf-8")
            src.unlink()
            print(f"  archived: {src.name}")
        else:
            print(f"  skip archive ({status}): {src.name}")
    # 2. copy
    for src, dst, status in plan_copy(vault):
        if status in ("OVERWRITE", "CREATE"):
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_text(read(src), encoding="utf-8")
            print(f"  {status.lower()}: {dst.name}")
        else:
            print(f"  skip copy ({status}): {src.name}")
    # 3. replacements
    for rel, old, new, status in plan_replacements(vault):
        if status == "APPLY":
            path = vault / rel
            path.write_text(read(path).replace(old, new), encoding="utf-8")
            print(f"  replaced in {rel}: {old[:48]!r} ...")
        else:
            print(f"  skip replace ({status}) in {rel}: {old[:48]!r}")


# --- lint (real + simulated) -------------------------------------------------

def run_real_linter(vault: Path) -> int:
    linter = vault / "00 Governance" / "lint_company_reference.py"
    if not linter.exists():
        print(f"  linter not found: {linter}")
        return 2
    res = subprocess.run([sys.executable, str(linter)], capture_output=True, text=True)
    sys.stdout.write(res.stdout)
    if res.stderr:
        sys.stdout.write(res.stderr)
    return res.returncode


def simulate_lint(vault: Path) -> bool:
    """Predict the post-apply lint result WITHOUT mutating the vault.

    Faithful to the two checks the migration can affect: forbidden active-term tokens
    and broken wikilinks. Other linter checks (frontmatter, symbols, todo routing) are
    untouched by this migration.
    """
    archive_names = set(ARCHIVE_PAGES)
    staging_targets = {f"03 Pipeline/{n}" for n in COPY_PAGES}

    # Build the after-state map: rel_posix -> content, and rel_posix -> is_active
    after_content: dict[str, str] = {}
    active: dict[str, bool] = {}

    for p in vault.rglob("*.md"):
        if ".obsidian" in p.parts:
            continue
        rel = p.relative_to(vault).as_posix()
        parts = p.parts
        in_archive = "_ARCHIV" in parts
        # the 9 superseded pages move from 03 Pipeline -> _ARCHIV
        if not in_archive and rel in {f"03 Pipeline/{n}" for n in archive_names}:
            new_rel = f"_ARCHIV/03 Pipeline/{p.name}"
            after_content[new_rel] = ARCHIVE_HEADER + read(p)
            active[new_rel] = False
            continue
        # staging overwrites of existing files handled below; keep original for now
        after_content[rel] = read(p)
        active[rel] = not in_archive

    # staging copies (overwrite or create)
    for name in COPY_PAGES:
        rel = f"03 Pipeline/{name}"
        after_content[rel] = read(STAGING_PIPELINE / name)
        active[rel] = True

    # in-place replacements
    for rel, old, new, status in plan_replacements(vault):
        if status == "APPLY" and rel in after_content:
            after_content[rel] = after_content[rel].replace(old, new)

    # existing set for wikilink resolution (all after-files)
    existing: set[str] = set()
    for rel in after_content:
        existing.add(rel)
        existing.add(rel[:-3] if rel.endswith(".md") else rel)
        existing.add(Path(rel).stem)

    ok = True
    # forbidden tokens on active pages
    for rel, text in after_content.items():
        if not active[rel]:
            continue
        if OLD_GATE_RE.search(text):
            print(f"  [SIM] old gate token in active page: {rel}")
            ok = False
        if RETIRED_SYS_RE.search(text):
            print(f"  [SIM] retired agent-system reference: {rel}")
            ok = False
    # wikilinks across all after-files
    for rel, text in after_content.items():
        base = str(Path(rel).parent.as_posix())
        fname = Path(rel).name
        for m in WIKILINK_RE.finditer(text):
            raw = m.group(1)
            target = raw.split("|", 1)[0].split("#", 1)[0].strip()
            if not target:
                continue
            if "<" in raw or fname.startswith("_TEMPLATE") or fname == "_SCHEMA.md" or raw == "..":
                continue
            norm = target.replace("\\", "/").strip("/")
            cands = {
                norm, f"{norm}.md", Path(norm).name, Path(norm).stem,
                (Path(base) / norm).as_posix(), f"{(Path(base) / norm).as_posix()}.md",
            }
            if not cands.intersection(existing):
                print(f"  [SIM] broken wikilink: {rel} -> [[{raw}]]")
                ok = False
    return ok


# --- main --------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="perform the migration")
    ap.add_argument("--dry-run", action="store_true", help="print plan only (default)")
    ap.add_argument("--vault", default=str(DEFAULT_VAULT), help="vault root path")
    args = ap.parse_args()

    vault = Path(args.vault)
    apply = args.apply and not args.dry_run
    mode = "APPLY" if apply else "DRY-RUN"

    if not vault.exists():
        print(f"VAULT NOT FOUND: {vault}")
        return 2
    if not STAGING_PIPELINE.exists():
        print(f"STAGING NOT FOUND: {STAGING_PIPELINE}")
        return 2

    print(f"=== Gate Manifest v4 vault migration [{mode}] ===")
    print(f"vault:   {vault}")
    print(f"staging: {STAGING_PIPELINE}\n")

    # counts
    arch = plan_archive(vault)
    cop = plan_copy(vault)
    rep = plan_replacements(vault)

    print("--- 1. ARCHIVE (move to _ARCHIV/03 Pipeline/) ---")
    for src, dst, st in arch:
        print(f"  [{st}] {src.name}")
    print(f"  ({sum(1 for _,_,s in arch if s=='MOVE')} to move, "
          f"{sum(1 for _,_,s in arch if s=='ALREADY_ARCHIVED')} already archived)\n")

    print("--- 2. COPY (staging -> vault) ---")
    for src, dst, st in cop:
        print(f"  [{st}] {dst.name}")
    print(f"  ({sum(1 for _,_,s in cop if s in ('OVERWRITE','CREATE'))} to write, "
          f"{sum(1 for _,_,s in cop if s=='STAGING_MISSING')} missing)\n")

    print("--- 3. REPLACEMENTS (wikilink retargets + tokens) ---")
    for rel, old, new, st in rep:
        print(f"  [{st}] {rel}: {old[:56]!r}")
    print(f"  ({sum(1 for *_,s in rep if s=='APPLY')} to apply, "
          f"{sum(1 for *_,s in rep if s=='ALREADY_APPLIED')} already applied, "
          f"{sum(1 for *_,s in rep if s in ('ANCHOR_NOT_FOUND','FILE_MISSING'))} unresolved)\n")

    if apply:
        print("--- executing ---")
        do_apply(vault)
        print("\n--- 4. VAULT LINTER (post-apply) ---")
        rc = run_real_linter(vault)
        print(f"linter exit code: {rc}")
        return 0 if rc == 0 else 1
    else:
        print("--- 4a. SIMULATED post-apply lint (forbidden tokens + wikilinks) ---")
        sim_ok = simulate_lint(vault)
        print(f"  simulated result: {'PASS' if sim_ok else 'FAIL'}")
        print("\n--- 4b. REAL LINTER on current (unmodified) vault [baseline] ---")
        rc = run_real_linter(vault)
        print(f"baseline linter exit code: {rc}")
        print("\n(DRY-RUN: nothing was written. Re-run with --apply to perform the migration.)")
        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())

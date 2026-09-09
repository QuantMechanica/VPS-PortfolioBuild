"""Bounded artifact-only compiler for the non-trading pattern fixture harness.

Never mirrors a terminal include, launches terminal64, changes EA inventory or
overwrites a prior binary. Ordinary strategy builds still use COMPILE_EA.
Authority and allowlist: decisions/2026-09-09_pattern_filter_repair.md, item 4.
"""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[2]
OUT = Path("D:/QM/reports/pattern_permission_repair")
DECISION = ROOT / "decisions/2026-09-09_pattern_filter_repair.md"
LABEL = "QM_pattern_permission_fixture_runner"
COMPILER = Path("D:/QM/mt5/DEV1/metaeditor64.exe")
HEADER = ROOT / "framework/include/QM/QM_PatternPermission.mqh"
BUNDLE = ROOT / "framework/tests/fixtures/pattern_permission/_bundle/pattern_fixtures.csv"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def verify_probe(root: Path) -> dict:
    root = Path(root).resolve()
    if not root.is_relative_to(OUT.resolve()) or root == OUT.resolve():
        raise ValueError("fixture compile probe outside artifact root")
    result = json.loads((root / "result.json").read_text())
    files = result.get("inputs", {})
    required = {"editor/MetaEditor64.exe", "MQL5/"+LABEL+".mq5",
                "MQL5/Include/QM/QM_PatternPermission.mqh", "pattern_fixtures.csv", "authority.md"}
    if set(files) != required or result.get("schema") != "qm.pattern-fixture-compile/v1" or result.get("status") != "PASS":
        raise ValueError("invalid fixture compile receipt")
    for relative, digest in files.items():
        path = root / relative
        if not path.resolve().is_relative_to(root) or path.is_symlink() or sha(path) != digest:
            raise ValueError("fixture compile input changed: " + relative)
    binary = root / "MQL5" / (LABEL + ".ex5")
    if sha(binary) != result["ex5_sha256"] or sha(root / "MQL5" / (LABEL + ".log")) != result["log_sha256"]:
        raise ValueError("fixture compile output changed")
    if sha(HEADER) != files["MQL5/Include/QM/QM_PatternPermission.mqh"] or sha(BUNDLE) != files["pattern_fixtures.csv"]:
        raise ValueError("fixture compile no longer matches canonical source/bundle")
    return result


def compile_probe() -> dict:
    if "CEO-DEC-PATTERN-REPAIR-20260909" not in DECISION.read_text(encoding="utf-8"):
        raise ValueError("fixture repair authority missing")
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    root = OUT / (stamp + "_" + uuid.uuid4().hex[:8])
    inputs = {"editor/MetaEditor64.exe": COMPILER,
              "MQL5/"+LABEL+".mq5": ROOT / "framework/tests" / (LABEL+".mq5"),
              "MQL5/Include/QM/QM_PatternPermission.mqh": HEADER,
              "pattern_fixtures.csv": BUNDLE, "authority.md": DECISION}
    # This harness has exactly one include and no trading dependency. Fail if
    # the source's dependency topology changes; do not broaden the copy scope.
    source = inputs["MQL5/"+LABEL+".mq5"].read_text(encoding="utf-8")
    if re.findall(r'^\s*#include\s+(.+)$', source, re.M) != ["<QM/QM_PatternPermission.mqh>"]:
        raise ValueError("fixture dependency allowlist changed")
    hashes = {rel:sha(path) for rel,path in inputs.items()}
    root.mkdir(parents=True, exist_ok=False)
    for rel,path in inputs.items():
        target = root / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
        if sha(target) != hashes[rel]:
            raise ValueError("fixture input changed during snapshot")
    source_path = root / "MQL5" / (LABEL+".mq5")
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    proc = subprocess.run([str(root / "editor/MetaEditor64.exe"), "/portable",
        "/compile:"+str(source_path), "/include:"+str(root / "MQL5"), "/log"],
        cwd=root / "editor", startupinfo=startup, creationflags=subprocess.CREATE_NO_WINDOW,
        capture_output=True, timeout=180)
    log, binary = source_path.with_suffix(".log"), source_path.with_suffix(".ex5")
    passed = log.is_file() and binary.is_file() and binary.stat().st_size > 0 and bool(
        re.search(r"Result: 0 errors, 0 warnings", log.read_text(encoding="utf-16", errors="replace")))
    result = {"schema":"qm.pattern-fixture-compile/v1", "status":"PASS" if passed else "FAIL",
              "created_at_utc":stamp, "inputs":hashes, "root":str(root), "returncode":proc.returncode,
              "ex5_sha256":sha(binary) if binary.exists() else None,
              "log_sha256":sha(log) if log.exists() else None,
              "terminal_include_mutations":0, "strategy_binary_mutations":0, "native_tester":"NOT_RUN"}
    with (root / "result.json").open("x", encoding="utf-8") as fh:
        json.dump(result, fh, indent=2)
    if passed:
        verify_probe(root)
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    if not args.execute:
        parser.error("--execute is required for the artifact-only compiler")
    result = compile_probe()
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result["status"] == "PASS" else 1)

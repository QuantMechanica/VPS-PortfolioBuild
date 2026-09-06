"""Corpus proof for router task 8f03675b (counter-indexed buffers)."""
from __future__ import annotations

import datetime as dt
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import types


OUT = Path(__file__).resolve().parent
CANON = Path("C:/QM/repo")
CANDIDATE = Path("C:/QM/worktrees/codex-buffer-counter-proof-20260906")
BASE = "eca677c1219c0d12febc074f540bf7fc1e480348"
TARGETS = {"QM5_20233", "QM5_20248", "QM5_20256", "QM5_20257", "QM5_20258", "QM5_41340"}


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def load_baseline(root: Path):
    package = types.ModuleType("counter_append_baseline")
    package.__path__ = [str(root)]
    sys.modules[package.__name__] = package
    for name in ("bounded_arrays.py", "build_gate_hardening.py"):
        content = subprocess.check_output(
            ["git", "show", f"{BASE}:tools/strategy_farm/{name}"], cwd=CANON
        )
        (root / name).write_bytes(content)
    load_module("counter_append_baseline.bounded_arrays", root / "bounded_arrays.py")
    return load_module(
        "counter_append_baseline.build_gate_hardening",
        root / "build_gate_hardening.py",
    )


def main() -> None:
    started = time.monotonic()
    sys.path.insert(0, str(CANDIDATE / "tools/strategy_farm"))
    after = load_module(
        "counter_append_candidate",
        CANDIDATE / "tools/strategy_farm/build_gate_hardening.py",
    )
    with tempfile.TemporaryDirectory(prefix="qm_counter_append_baseline_") as temp:
        before = load_baseline(Path(temp))
        rows = []
        newly_flagged = []
        for path in sorted((CANON / "framework/EAs").glob("*/*.mq5")):
            raw_bytes = path.read_bytes()
            raw = after.read_text_compatible(path)
            before_source = before.SourceFile(
                path, raw, before.strip_comments_preserve_lines(raw)
            )
            after_source = after.SourceFile(
                path, raw, after.strip_comments_preserve_lines(raw)
            )
            old_findings = before.check_indicator_buffer_bounds(before_source)
            new_findings = after.check_indicator_buffer_bounds(after_source)
            introduced = sorted(set(new_findings) - set(old_findings))
            if introduced:
                newly_flagged.append({"path": str(path), "findings": introduced})
            rows.append(
                {
                    "path": str(path.relative_to(CANON)).replace("\\", "/"),
                    "ea_id": path.name.split("_")[0] + "_" + path.name.split("_")[1],
                    "sha256": hashlib.sha256(raw_bytes).hexdigest(),
                    "before_count": len(old_findings),
                    "after_count": len(new_findings),
                    "cleared_count": len(set(old_findings) - set(new_findings)),
                    "new_count": len(introduced),
                    "before": old_findings,
                    "after": new_findings,
                }
            )

    target_rows = [row for row in rows if row["ea_id"] in TARGETS]
    cleared_eas = sorted(
        row["ea_id"] for row in target_rows
        if row["before_count"] > 0 and row["after_count"] == 0
    )
    fully_cleared_eas = sorted(
        row["ea_id"] for row in rows
        if row["before_count"] > 0 and row["after_count"] == 0
    )
    improved_eas = sorted(
        row["ea_id"] for row in rows if row["cleared_count"] > 0
    )
    result = {
        "schema": "qm.buffer-counter-append-sweep.v1",
        "task_id": "8f03675b-de8c-45a7-9386-6dd7a947012f",
        "captured_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "baseline_commit": BASE,
        "candidate_branch": "agents/codex-buffer-counter-proof-20260906",
        "candidate_head": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=CANDIDATE, text=True
        ).strip(),
        "corpus_root": str(CANON / "framework/EAs"),
        "source_count": len(rows),
        "findings_before": sum(row["before_count"] for row in rows),
        "findings_after": sum(row["after_count"] for row in rows),
        "cleared_findings": sum(row["cleared_count"] for row in rows),
        "new_finding_count": sum(row["new_count"] for row in rows),
        "newly_flagged_ea_count": len(newly_flagged),
        "cleared_target_eas": cleared_eas,
        "fully_cleared_eas": fully_cleared_eas,
        "improved_eas": improved_eas,
        "target_rows": target_rows,
        "newly_flagged": newly_flagged,
        "sources": rows,
        "duration_seconds": round(time.monotonic() - started, 3),
    }
    assert not newly_flagged, newly_flagged[:10]
    assert set(cleared_eas) == TARGETS, target_rows

    (OUT / "sweep.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    lines = [
        "# Counter-indexed buffer proof corpus sweep",
        "",
        "| EA source | Before | After | Cleared | New |",
        "|---|---:|---:|---:|---:|",
    ]
    lines.extend(
        f"| `{row['path']}` | {row['before_count']} | {row['after_count']} | "
        f"{row['cleared_count']} | {row['new_count']} |"
        for row in rows
    )
    lines.extend([
        "",
        f"Scanned {len(rows)} EA sources; findings "
        f"{result['findings_before']} -> {result['findings_after']}; "
        f"new findings: {result['new_finding_count']} across "
        f"{result['newly_flagged_ea_count']} EAs.",
        "Exact findings and source SHA-256 values are preserved in `sweep.json`.",
    ])
    (OUT / "sweep.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in result.items() if key != "sources"}, indent=2))


if __name__ == "__main__":
    main()

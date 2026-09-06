"""Reproducible corpus proof for router task 3aebf9f6 (buffer round 3)."""
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
CANDIDATE = Path("C:/QM/worktrees/codex-buffer-round3-20260906")
BASE = "160c9292a6"
TARGET_LABELS = {
    "QM5_20233_xauxag-skew-rank", "QM5_20248_xng-vr-window",
    "QM5_20256_wti-vr6-mom", "QM5_20257_wti-vr12-mom",
    "QM5_20258_wti-mom-vote", "QM5_20268_xauxag-qtail-rv",
    "QM5_20271_wti-theilsen-tr", "QM5_20276_wti-hl-mom",
    "QM5_20291_xauxag-kurt-rk", "QM5_20292_fx-carry-unwind",
    "QM5_20294_xauxag-max-rk", "QM5_21522_wti-lowdb-trend",
    "QM5_21527_wti-fallcorr-tr",
}


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def load_baseline(root: Path):
    package = types.ModuleType("buffer_round3_baseline")
    package.__path__ = [str(root)]
    sys.modules[package.__name__] = package
    for name in ("bounded_arrays.py", "build_gate_hardening.py"):
        content = subprocess.check_output(
            ["git", "show", f"{BASE}:tools/strategy_farm/{name}"], cwd=CANON
        )
        (root / name).write_bytes(content)
    load_module("buffer_round3_baseline.bounded_arrays", root / "bounded_arrays.py")
    return load_module(
        "buffer_round3_baseline.build_gate_hardening",
        root / "build_gate_hardening.py",
    )


def main() -> None:
    started = time.monotonic()
    sys.path.insert(0, str(CANDIDATE / "tools/strategy_farm"))
    after = load_module(
        "buffer_round3_candidate",
        CANDIDATE / "tools/strategy_farm/build_gate_hardening.py",
    )
    with tempfile.TemporaryDirectory(prefix="qm_buffer_round3_baseline_") as temp:
        before = load_baseline(Path(temp))
        rows = []
        newly_flagged = []
        for path in sorted((CANDIDATE / "framework/EAs").glob("*/*.mq5")):
            raw_bytes = path.read_bytes()
            raw = after.read_text_compatible(path)
            old_source = before.SourceFile(
                path, raw, before.strip_comments_preserve_lines(raw)
            )
            new_source = after.SourceFile(
                path, raw, after.strip_comments_preserve_lines(raw)
            )
            old_findings = before.check_indicator_buffer_bounds(old_source)
            new_findings = after.check_indicator_buffer_bounds(new_source)
            introduced = sorted(set(new_findings) - set(old_findings))
            if introduced:
                newly_flagged.append({"path": str(path), "findings": introduced})
            parts = path.name.split("_")
            ea_id = "_".join(parts[:2])
            rows.append({
                "path": str(path.relative_to(CANDIDATE)).replace("\\", "/"),
                "ea_id": ea_id,
                "sha256": hashlib.sha256(raw_bytes).hexdigest(),
                "before_count": len(old_findings),
                "after_count": len(new_findings),
                "cleared_count": len(set(old_findings) - set(new_findings)),
                "new_count": len(introduced),
                "before": old_findings,
                "after": new_findings,
            })

    target_rows = [
        row for row in rows
        if Path(row["path"]).parent.name in TARGET_LABELS
    ]
    clear_targets = sorted(
        row["ea_id"] for row in target_rows if row["after_count"] == 0
    )
    result = {
        "schema": "qm.buffer-round3-sweep.v1",
        "task_id": "3aebf9f6-2377-461f-abbd-c0770c55113b",
        "captured_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "baseline_commit": BASE,
        "candidate_branch": "agents/codex-buffer-round3-20260906",
        "candidate_head": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=CANDIDATE, text=True
        ).strip(),
        "corpus_root": str(CANDIDATE / "framework/EAs"),
        "source_count": len(rows),
        "findings_before": sum(row["before_count"] for row in rows),
        "findings_after": sum(row["after_count"] for row in rows),
        "cleared_findings": sum(row["cleared_count"] for row in rows),
        "new_finding_count": sum(row["new_count"] for row in rows),
        "newly_flagged_ea_count": len(newly_flagged),
        "clear_target_eas": clear_targets,
        "target_rows": target_rows,
        "newly_flagged": newly_flagged,
        "sources": rows,
        "duration_seconds": round(time.monotonic() - started, 3),
    }
    assert not newly_flagged, newly_flagged[:10]
    assert len(target_rows) == len(TARGET_LABELS), target_rows
    assert all(row["after_count"] == 0 for row in target_rows), target_rows

    (OUT / "sweep.json").write_text(
        json.dumps(result, indent=2) + "\n", encoding="utf-8"
    )
    lines = [
        "# Buffer round-3 corpus sweep", "",
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
    print(json.dumps(
        {key: value for key, value in result.items() if key != "sources"},
        indent=2,
    ))


if __name__ == "__main__":
    main()

"""Read-only corpus proof for the bounded-array monotone rollout."""
from __future__ import annotations

import datetime as dt
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import time


OUT = Path(__file__).resolve().parent
CANON = Path("C:/QM/repo")
CANDIDATE = Path("C:/QM/worktrees/codex-buffer-monotone-20260906")
BASELINE_PATH = CANON / "docs/ops/evidence/2026-09-05_buildcheck_predicate_fix/baseline_build_gate_hardening.py"
TRIAGE_ROOT = CANON / "docs/ops/evidence/2026-09-05_buffer_bound_family"
BASE = "1240b069d540d611cd6e92c2e4e115ec743844a1"


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def main() -> None:
    started = time.monotonic()
    sys.path.insert(0, str(CANDIDATE / "tools/strategy_farm"))
    before = load_module("baseline_build_gate_hardening_monotone", BASELINE_PATH)
    after = load_module(
        "candidate_build_gate_hardening_monotone",
        CANDIDATE / "tools/strategy_farm/build_gate_hardening.py",
    )

    rows = []
    mismatched_legacy = []
    newly_flagged = []
    for path in sorted((CANON / "framework/EAs").glob("*/*.mq5")):
        raw_bytes = path.read_bytes()
        raw = after.read_text_compatible(path)
        source = after.SourceFile(path, raw, after.strip_comments_preserve_lines(raw))
        old_findings = before.check_indicator_buffer_bounds(source)
        legacy_findings = after._check_indicator_buffer_bounds_legacy(source)
        new_findings = after.check_indicator_buffer_bounds(source)
        if legacy_findings != old_findings:
            mismatched_legacy.append(str(path))
        introduced = sorted(set(new_findings) - set(old_findings))
        if introduced:
            newly_flagged.append({"path": str(path), "findings": introduced})
        rows.append(
            {
                "path": str(path.relative_to(CANON)).replace("\\", "/"),
                "sha256": hashlib.sha256(raw_bytes).hexdigest(),
                "before_count": len(old_findings),
                "after_count": len(new_findings),
                "cleared_count": len(set(old_findings) - set(new_findings)),
                "new_count": len(introduced),
                "before": old_findings,
                "after": new_findings,
            }
        )

    triage = json.loads((TRIAGE_ROOT / "triage.json").read_text(encoding="utf-8-sig"))
    targets = []
    for item in triage["rows"]:
        if item["ea_id"] not in {"QM5_41186", "QM5_41187", "QM5_41188", "QM5_41190"}:
            continue
        path = TRIAGE_ROOT / item["fixture"]
        assert hashlib.sha256(path.read_bytes()).hexdigest() == item["source_sha256"]
        raw = after.read_text_compatible(path)
        source = after.SourceFile(path, raw, after.strip_comments_preserve_lines(raw))
        targets.append(
            {
                "ea_id": item["ea_id"],
                "source_sha256": item["source_sha256"],
                "before_count": len(before.check_indicator_buffer_bounds(source)),
                "after_count": len(after.check_indicator_buffer_bounds(source)),
            }
        )

    result = {
        "schema": "qm.buffer-bound-monotonicity.v1",
        "captured_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "baseline_commit": BASE,
        "candidate_branch": "agents/codex-buffer-monotone-20260906",
        "candidate_head": subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=CANDIDATE,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip(),
        "corpus_root": str(CANON / "framework/EAs"),
        "read_only": True,
        "source_count": len(rows),
        "findings_before": sum(row["before_count"] for row in rows),
        "findings_after": sum(row["after_count"] for row in rows),
        "cleared_findings": sum(row["cleared_count"] for row in rows),
        "new_finding_count": sum(row["new_count"] for row in rows),
        "newly_flagged_ea_count": len(newly_flagged),
        "legacy_parity_mismatch_count": len(mismatched_legacy),
        "targets": targets,
        "newly_flagged": newly_flagged,
        "legacy_parity_mismatches": mismatched_legacy,
        "sources": rows,
        "duration_seconds": round(time.monotonic() - started, 3),
    }
    assert not mismatched_legacy, mismatched_legacy[:10]
    assert not newly_flagged, newly_flagged[:10]
    assert sum(row["before_count"] for row in targets) == 12
    assert sum(row["after_count"] for row in targets) == 0

    (OUT / "sweep.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    lines = [
        "# EA buffer-bound monotonicity sweep",
        "",
        "| EA source | Before | After | Cleared | New |",
        "|---|---:|---:|---:|---:|",
    ]
    lines.extend(
        f"| `{row['path']}` | {row['before_count']} | {row['after_count']} | "
        f"{row['cleared_count']} | {row['new_count']} |"
        for row in rows
    )
    lines.extend(
        [
            "",
            f"Scanned {len(rows)} EA sources; findings "
            f"{result['findings_before']} -> {result['findings_after']}; "
            f"new findings: {result['new_finding_count']} across "
            f"{result['newly_flagged_ea_count']} EAs.",
            "Exact findings and source SHA-256 values are preserved in `sweep.json`.",
        ]
    )
    (OUT / "sweep.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in result.items() if key not in {"sources"}}))


if __name__ == "__main__":
    main()

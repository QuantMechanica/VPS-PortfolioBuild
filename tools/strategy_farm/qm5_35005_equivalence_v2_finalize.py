#!/usr/bin/env python3
"""Finalize the completed QM5_35005 v2 reports without launching MT5.

The governed v2 controller completed both native tests, then contained the
integration portable terminal after it ignored ShutdownTerminal=1.  Python's
dict-comprehension assignment consequently did not retain either parsed run in
the failure packet.  This fail-closed finalizer accepts only that exact
contained state, re-authenticates every durable build/run input and both native
reports, and emits the normal v2 comparison artifacts.  It never launches or
terminates a process and never creates or changes a firewall rule.
"""
from __future__ import annotations

import argparse
import calendar
import datetime as dt
import json
import os
import re
import sys
from pathlib import Path, PurePosixPath
from typing import Any, Mapping, Sequence


REPO_IMPORT_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_IMPORT_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_IMPORT_ROOT))

from tools.strategy_farm import qm5_35005_equivalence as exact
from tools.strategy_farm import qm5_35005_equivalence_v2 as v2
from tools.strategy_farm.include_mirror import running_terminal_names


FINALIZER_SCHEMA = "qm.qm5-35005-pattern-include-equivalence-finalizer/v1"
EXPECTED_EXCEPTION = (
    "integration portable tester containment failed: "
    "timed_out=True remaining=[]"
)


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise v2.ProofError(message)


def _binding_matches(expected: Mapping[str, Any]) -> dict[str, Any]:
    actual = v2.file_binding(Path(str(expected["path"])))
    _require(
        actual["sha256"] == expected.get("sha256")
        and actual["size"] == expected.get("size"),
        f"file binding drift: {actual['path']}",
    )
    return actual


def _tree_matches(expected: Mapping[str, Any]) -> dict[str, Any]:
    actual = v2.tree_inventory(Path(str(expected["root"])))
    _require(
        actual["sha256"] == expected.get("sha256")
        and actual["file_count"] == expected.get("file_count")
        and actual["total_bytes"] == expected.get("total_bytes"),
        f"tree binding drift: {actual['root']}",
    )
    return actual


def _inventory_rows(inventory: Mapping[str, Any]) -> dict[str, Mapping[str, Any]]:
    rows = inventory.get("files")
    if not isinstance(rows, list) or not rows:
        raise v2.ProofError("history inventory has no file rows")
    result: dict[str, Mapping[str, Any]] = {}
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get("relative_path"), str):
            raise v2.ProofError("history inventory row malformed")
        result[str(row["relative_path"])] = row
    return result


def _history_file_interval(relative_path: str) -> tuple[dt.date, dt.date] | None:
    path = PurePosixPath(relative_path)
    name = path.name
    history = re.fullmatch(r"(?P<year>\d{4})\.hcc", name, flags=re.IGNORECASE)
    if history:
        year = int(history.group("year"))
        return dt.date(year, 1, 1), dt.date(year, 12, 31)
    ticks = re.fullmatch(r"(?P<year>\d{4})(?P<month>\d{2})\.tkc", name, flags=re.IGNORECASE)
    if ticks:
        year = int(ticks.group("year"))
        month = int(ticks.group("month"))
        if month < 1 or month > 12:
            return None
        return (
            dt.date(year, month, 1),
            dt.date(year, month, calendar.monthrange(year, month)[1]),
        )
    return None


def history_mutation_scope(
    before: Mapping[str, Any],
    after: Mapping[str, Any],
    *,
    from_date: str = v2.FROM_DATE,
    to_date: str = v2.TO_DATE,
) -> dict[str, Any]:
    start = dt.datetime.strptime(from_date, "%Y.%m.%d").date()
    stop = dt.datetime.strptime(to_date, "%Y.%m.%d").date()
    _require(start <= stop, "history test window inverted")
    left = _inventory_rows(before)
    right = _inventory_rows(after)
    changed: list[dict[str, Any]] = []
    tested_files = 0
    for name in sorted(set(left) | set(right), key=str.casefold):
        interval = _history_file_interval(name)
        intersects = interval is None or not (interval[1] < start or interval[0] > stop)
        if interval is not None and intersects and name in left:
            tested_files += 1
        if left.get(name) != right.get(name):
            changed.append(
                {
                    "relative_path": name,
                    "before": left.get(name),
                    "after": right.get(name),
                    "recognized_interval": (
                        None
                        if interval is None
                        else {"from": interval[0].isoformat(), "to": interval[1].isoformat()}
                    ),
                    "intersects_test_window": intersects,
                }
            )
    in_window = [row for row in changed if row["intersects_test_window"]]
    _require(tested_files > 0, "history inventory has no tested-window files")
    return {
        "test_window": {"from": start.isoformat(), "to": stop.isoformat()},
        "tested_window_file_count": tested_files,
        "tested_window_unchanged": not in_window,
        "changed_file_count": len(changed),
        "changed_inside_test_window": in_window,
        "changed_outside_test_window": [
            row for row in changed if not row["intersects_test_window"]
        ],
    }


def _decode_log(path: Path) -> str:
    raw = path.read_bytes()
    for encoding in ("utf-16", "utf-16-le", "utf-8-sig", "utf-8"):
        try:
            return raw.decode(encoding)
        except UnicodeError:
            continue
    return raw.decode("utf-8", errors="replace")


def _completion_log(profile: Path) -> tuple[Path, dict[str, Any]]:
    matches: list[tuple[Path, str]] = []
    for path in (profile / "Tester").rglob("*.log"):
        if not path.is_file():
            continue
        text = _decode_log(path)
        if "Test passed in" in text and f"{v2.SYMBOL},{v2.PERIOD}" in text:
            matches.append((path, text))
    _require(bool(matches), f"completed native tester log missing: {profile}")
    path, text = max(matches, key=lambda row: row[0].stat().st_mtime_ns)
    return path, {
        "test_passed": True,
        "symbol_period_present": True,
        "final_balance_present": "final balance" in text,
        "log": v2.file_binding(path),
    }


def _firewall_rule_absent(name: str) -> bool:
    shown = v2._run(
        ["netsh", "advfirewall", "firewall", "show", "rule", f"name={name}"],
        timeout=60,
        check=False,
    )
    return (
        shown.returncode != 0
        or "No rules match" in shown.stdout
        or "Keine Regeln" in shown.stdout
    )


def validate_prior_packet(packet: Mapping[str, Any], artifact_root: Path) -> None:
    _require(packet.get("schema") == v2.SCHEMA, "prior packet schema mismatch")
    _require(packet.get("task_id") == v2.TASK_ID, "prior packet task mismatch")
    _require(packet.get("execution_status") == "FAILED", "prior packet is not failed")
    _require(packet.get("outcome") == "NOT_PROVEN", "prior packet outcome mismatch")
    _require(Path(str(packet.get("artifact_root"))).resolve() == artifact_root, "prior artifact root mismatch")
    _require(EXPECTED_EXCEPTION in str(packet.get("exception")), "unexpected prior failure")
    firewall = packet.get("firewall") or {}
    rules = firewall.get("rules") or []
    closeout = firewall.get("closeout") or []
    _require(firewall.get("all_removed") is True, "prior firewall closeout not proven")
    _require(len(rules) == 6 and len(closeout) == 6, "prior firewall coverage incomplete")
    _require(all(row.get("removed") is True for row in closeout), "prior firewall rule remained")
    _require(not packet.get("runs"), "unexpected retained run payload")


def _verify_static_bindings(
    *, repo_root: Path, artifact_root: Path, packet: dict[str, Any]
) -> dict[str, Any]:
    _require(v2._git(repo_root, "branch", "--show-current") == "agents/board-advisor", "canonical checkout branch drift")
    auth = packet["authorization"]
    _require(
        v2.sha256_file(Path(str(auth["path"]))) == auth.get("sha256"),
        "authorization manifest changed since run",
    )
    verified: dict[str, Any] = {"canonical": {}, "worktrees": {}, "compiles": {}}
    for name, binding in packet["setup"]["canonical_before"].items():
        verified["canonical"][name] = _binding_matches(binding)

    actual_parent = v2._git(repo_root, "rev-parse", f"{v2.INTEGRATION_COMMIT}^")
    _require(actual_parent == v2.PARENT_COMMIT, "integration parent drift")
    for side, commit in (("parent", v2.PARENT_COMMIT), ("integration", v2.INTEGRATION_COMMIT)):
        expected = packet["worktrees"][side]
        worktree = Path(str(expected["worktree"]))
        _require(v2._git(worktree, "rev-parse", "HEAD") == commit, f"{side} worktree commit drift")
        source = _binding_matches(expected["source"])
        include = _tree_matches(expected["include"])
        _require(
            v2._git(worktree, "rev-parse", f"HEAD:{v2.INCLUDE_RELATIVE.as_posix()}")
            == expected["git_include_tree"],
            f"{side} Git Include tree drift",
        )
        verified["worktrees"][side] = {"commit": commit, "source": source, "include": include}

        compile_row = packet["compiles"][side]
        _require(compile_row["strict_summary"] == {"errors": 0, "warnings": 0}, f"{side} compile not strict-pass")
        verified["compiles"][side] = {
            key: _binding_matches(compile_row[key])
            for key in ("metaeditor", "source", "log", "ex5")
        }
        verified["compiles"][side]["include"] = _tree_matches(compile_row["include"])
        _require(not v2._target_processes(Path(str(compile_row["metaeditor"]["path"])).parent), f"{side} compiler process remains")

    _require(
        verified["worktrees"]["parent"]["source"]["sha256"]
        == verified["worktrees"]["integration"]["source"]["sha256"],
        "worktree source bytes differ",
    )
    _require(
        verified["compiles"]["parent"]["metaeditor"]["sha256"]
        == verified["compiles"]["integration"]["metaeditor"]["sha256"],
        "compiler bytes differ",
    )
    ex5_status = v2._git(repo_root, "status", "--porcelain=v1", "--", ":(glob)**/*.ex5")
    _require(not ex5_status, "repository EX5 status changed")
    return verified


def _authenticate_report(
    *, side: str, artifact_root: Path, packet: Mapping[str, Any]
) -> dict[str, Any]:
    profile = artifact_root / "profiles" / side
    _require(not v2._target_processes(profile), f"{side} profile process remains")
    report = profile / f"{side}_equivalence_report.htm"
    ini = artifact_root / "tester_ini" / f"{side}.ini"
    report_binding = v2._wait_report_stable(report, __import__("time").monotonic() + 10)
    deals = exact.extract_deal_rows(report)
    _require(bool(deals), f"{side} native report has no Deals")
    inputs = exact.extract_report_inputs(report)
    required_inputs = {
        "qm_ea_id": "35005",
        "qm_rng_seed": str(v2.SEED),
        "RISK_PERCENT": "0",
        "RISK_FIXED": "1000",
        "qm_news_stale_max_hours": "336",
    }
    failures = {name: inputs.get(name) for name, value in required_inputs.items() if inputs.get(name) != value}
    _require(not failures, f"{side} report input binding failed: {failures}")
    identity = v2.report_identity(report)
    log, completion = _completion_log(profile)

    staged_ex5 = profile / "MQL5" / "Experts" / "QM" / "EQV35005_V2" / f"{v2.EA_LABEL}.ex5"
    staged_set = profile / "MQL5" / "Profiles" / "Tester" / Path(v2.SET_RELATIVE).name
    groups = profile / "MQL5" / "Profiles" / "Tester" / "Groups" / "Darwinex-Live_real.txt"
    ex5 = v2.file_binding(staged_ex5)
    setfile = v2.file_binding(staged_set)
    _require(ex5["sha256"] == packet["compiles"][side]["ex5"]["sha256"], f"{side} staged EX5 drift")
    _require(setfile["sha256"] == packet["setup"]["setfile"]["sha256"], f"{side} staged setfile drift")
    _require(v2.file_binding(groups)["sha256"] == packet["setup"]["canonical_before"]["tester_groups"]["sha256"], f"{side} tester groups drift")

    history_before = packet["setup"]["template_history_before"]
    history_after = v2.history_inventory(profile)
    scope = history_mutation_scope(history_before, history_after)
    _require(scope["tested_window_unchanged"], f"{side} tested-window history changed")
    terminal = v2.file_binding(profile / "terminal64.exe")
    metatester = v2.file_binding(profile / "metatester64.exe")
    programs = packet["setup"]["template_programs_before"]
    _require(terminal["sha256"] == programs["terminal64.exe"]["sha256"], f"{side} terminal binary drift")
    _require(metatester["sha256"] == programs["metatester64.exe"]["sha256"], f"{side} metatester binary drift")

    common_inputs = {
        "config": {
            "sha256": packet["setup"]["template_config_before"]["sha256"],
            "attested_pre_run_by_controller": True,
        },
        "mql5_files": {
            "sha256": packet["setup"]["template_mql5_files_before"]["sha256"],
            "attested_pre_run_by_controller": True,
        },
        "tester_groups": {
            "sha256": packet["setup"]["canonical_before"]["tester_groups"]["sha256"],
            "attested_pre_run_by_controller": True,
        },
    }
    deal_bytes = exact.canonical_deal_bytes(deals)
    return {
        "side": side,
        "started_at": None,
        "completed_at": dt.datetime.fromtimestamp(report.stat().st_mtime, tz=dt.timezone.utc).astimezone().isoformat(),
        "command_contract": ["<portable-terminal64.exe>", "/portable", "/config:<absolute-ini>"],
        "process": {
            "pid": None,
            "exit_code": None,
            "timed_out": side == "integration",
            "recovered_after_controller_containment": True,
        },
        "report": report_binding,
        "tester_ini": v2.file_binding(ini),
        "execution_ini": exact.canonical_execution_ini(ini),
        "tester_log": v2.file_binding(log),
        "tester_completion": completion,
        "deal_rows": deals,
        "deal_count": len(deals),
        "canonical_deals_sha256": v2.sha256_bytes(deal_bytes),
        "inputs": inputs,
        "report_identity": identity,
        "history_before": history_before,
        "history_after": history_after,
        "history_mutation_scope": scope,
        "profile": {
            "root": str(profile.resolve()),
            "terminal": terminal,
            "metatester": metatester,
            "ex5": ex5,
            "setfile": setfile,
            "common_inputs": common_inputs,
        },
        "processes_after": [],
    }


def _append_finalization_report(report: Path, packet: Mapping[str, Any]) -> None:
    scopes = {side: packet["runs"][side]["history_mutation_scope"] for side in ("parent", "integration")}
    lines = [
        "",
        "## Governed containment finalization",
        "",
        "The original controller completed both native tests, but the integration portable terminal ignored `ShutdownTerminal=1`. The controller contained only that disposable process at its 30-minute bound and removed all six outbound-block firewall rules. This finalization pass launched no process and re-authenticated the stable native reports and all durable build/run bindings after containment.",
        "",
        f"- Original contained failure packet SHA-256: `{packet['recovery']['prior_failure_packet_sha256']}`",
        f"- Parent post-run cache changes outside the tested window: {scopes['parent']['changed_file_count']}",
        f"- Integration post-run cache changes outside the tested window: {scopes['integration']['changed_file_count']}",
        "- Tested-window 2022 history/tick files remained byte-unchanged on both sides.",
        "- Current-year cache mutations were excluded from the equivalence variable and are listed in the packet.",
        "",
    ]
    v2.atomic_bytes(report, report.read_bytes().rstrip() + ("\n" + "\n".join(lines)).encode("utf-8"))


def finalize(args: argparse.Namespace) -> dict[str, Any]:
    repo_root = args.repo_root.resolve()
    artifact_root = args.artifact_root.resolve()
    evidence_dir = args.evidence_dir.resolve()
    _require(evidence_dir == (repo_root / "docs" / "ops" / "evidence").resolve(), "evidence directory is not canonical")
    _require(artifact_root == v2.DEFAULT_ARTIFACT_ROOT.resolve(), "unexpected finalization artifact root")
    _require(artifact_root.is_dir(), "completed artifact root missing")
    authorization = v2.validate_authorization(args.authorization_manifest, artifact_root)
    packet_path = evidence_dir / f"{v2.OUTPUT_STEM}_packet.json"
    packet_bytes = packet_path.read_bytes()
    packet = json.loads(packet_bytes.decode("utf-8-sig"))
    validate_prior_packet(packet, artifact_root)
    _require(packet["authorization"]["manifest"] == authorization, "authorization payload drift")

    rules = packet["firewall"]["rules"]
    current_rule_absence = {row["name"]: _firewall_rule_absent(str(row["name"])) for row in rules}
    _require(all(current_rule_absence.values()), "recorded firewall rule remains active")
    _require(not v2._target_processes(artifact_root), "task-owned process remains")
    verified = _verify_static_bindings(repo_root=repo_root, artifact_root=artifact_root, packet=packet)
    runs = {
        side: _authenticate_report(side=side, artifact_root=artifact_root, packet=packet)
        for side in ("parent", "integration")
    }
    comparison, pre_bytes, post_bytes = v2.build_comparison(runs["parent"], runs["integration"])
    comparison["checks"].pop("history_pre_profile_stable", None)
    comparison["checks"].pop("history_post_profile_stable", None)
    comparison["checks"]["parent_tested_window_history_unchanged"] = runs["parent"]["history_mutation_scope"]["tested_window_unchanged"]
    comparison["checks"]["integration_tested_window_history_unchanged"] = runs["integration"]["history_mutation_scope"]["tested_window_unchanged"]
    comparison["checks"]["cache_mutations_confined_outside_test_window"] = all(
        not runs[side]["history_mutation_scope"]["changed_inside_test_window"]
        for side in ("parent", "integration")
    )
    comparison["identical"] = all(comparison["checks"].values())

    original_exception = str(packet.pop("exception"))
    packet["runs"] = runs
    packet["comparison"] = comparison
    packet["execution_status"] = "COMPLETE"
    packet["outcome"] = "IDENTISCH" if comparison["identical"] else "ABWEICHEND"
    packet["completed_at"] = v2.utc_now()
    packet["factory_terminals_after"] = sorted(running_terminal_names())
    packet["firewall"]["current_rule_absence"] = current_rule_absence
    packet["recovery"] = {
        "schema": FINALIZER_SCHEMA,
        "prior_execution_status": "FAILED",
        "prior_outcome": "NOT_PROVEN",
        "prior_exception": original_exception,
        "prior_failure_packet_sha256": v2.sha256_bytes(packet_bytes),
        "prior_failure_evidence_commit": "e025e267d",
        "finalizer": v2.file_binding(Path(__file__)),
        "processes_launched": 0,
        "processes_terminated": 0,
        "firewall_rules_added": 0,
        "firewall_rules_removed": 0,
        "task_processes_before": [],
        "task_processes_after": [],
        "verified_static_bindings": verified,
    }

    canonical_after = {
        name: _binding_matches(binding)
        for name, binding in packet["setup"]["canonical_before"].items()
    }
    packet["setup"]["canonical_after"] = canonical_after
    packet["setup"]["canonical_inputs_unchanged"] = canonical_after == packet["setup"]["canonical_before"]
    packet["setup"]["template_programs_after"] = {
        name: v2.file_binding(args.template_root.resolve() / name)
        for name in ("MetaEditor64.exe", "terminal64.exe", "metatester64.exe")
    }
    packet["setup"]["template_programs_unchanged"] = packet["setup"]["template_programs_after"] == packet["setup"]["template_programs_before"]
    packet["setup"]["common_news_after"] = v2.common_news_bindings()
    packet["setup"]["common_news_unchanged"] = packet["setup"]["common_news_after"] == packet["setup"]["common_news_before"]
    _require(packet["setup"]["canonical_inputs_unchanged"], "canonical input changed after run")
    _require(packet["setup"]["template_programs_unchanged"], "template executable changed after run")
    _require(packet["setup"]["common_news_unchanged"], "common news input changed after run")

    outputs = v2._write_run_artifacts(
        evidence_dir=evidence_dir,
        packet=packet,
        pre_bytes=pre_bytes,
        post_bytes=post_bytes,
    )
    report = Path(outputs["report"])
    _append_finalization_report(report, packet)
    packet["evidence_files"]["final_report_binding"] = v2.file_binding(report)
    v2.atomic_json(Path(outputs["packet"]), packet)
    return {"status": "COMPLETE", "outcome": packet["outcome"], "outputs": outputs}


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=REPO_IMPORT_ROOT)
    parser.add_argument("--template-root", type=Path, default=v2.DEFAULT_TEMPLATE)
    parser.add_argument("--artifact-root", type=Path, default=v2.DEFAULT_ARTIFACT_ROOT)
    parser.add_argument("--evidence-dir", type=Path, default=v2.DEFAULT_EVIDENCE_DIR)
    parser.add_argument("--authorization-manifest", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    try:
        result = finalize(parse_args(argv))
    except Exception as exc:
        print(json.dumps({"status": "FAILED", "outcome": "NOT_PROVEN", "error": f"{type(exc).__name__}: {exc}"}, indent=2))
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

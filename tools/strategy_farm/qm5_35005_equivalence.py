#!/usr/bin/env python3
"""Governed pre/post runtime-equivalence proof for QM5_35005.

This is an exact, task-bound utility.  It does not compile, grade, promote, or
release an EA.  A resident terminal worker claims the append-only row, retains
both EX5 binaries, runs them sequentially in the same idle terminal with one
sealed tester configuration, canonicalizes every native Deals field, and
publishes IDENTICAL or DEVIATION evidence without a Q-gate verdict.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import html
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import time
import uuid
from dataclasses import asdict, dataclass
from html.parser import HTMLParser
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

try:
    import custom_history_contract
    import custom_history_copy_on_claim
    import custom_history_gate
    import farmctl
    from include_mirror import running_terminal_names
except ModuleNotFoundError:  # pragma: no cover - package import path
    from tools.strategy_farm import (
        custom_history_contract,
        custom_history_copy_on_claim,
        custom_history_gate,
        farmctl,
    )
    from tools.strategy_farm.include_mirror import running_terminal_names


CONTRACT_VERSION = "qm.qm5-35005-pattern-include-equivalence/v1"
TASK_ID = "b98560ce-ebd0-45e6-93bc-78d498211d93"
SOURCE_ESCALATION_TASK_ID = "9e707406-eedc-47b7-a3b3-d60a1bffe3c9"
EA_ID = "QM5_35005"
EA_NUMERIC_ID = 35005
EA_LABEL = "QM5_35005_sma-crossover-pullback-system"
QUEUE_PHASE = "Q11"
WORK_ITEM_KIND = "compile"
UTILITY_COMPLETION = "ARTIFACT_READY"
PRE_INTEGRATION_COMMIT = "82755f48a664abf1b0cc1fe5fa8833a8f3721aec"
INTEGRATION_COMMIT = "b0bdc4d72f23876398b707db72450a560718ef4a"
COMPILE_WORK_ITEM_ID = "0ca4936f-d280-42bd-adc5-fa3f44f0d117"
PRE_EX5_SHA256 = "28ef9a97341ab09666f4b8ac6a817bbdabe806c968fbc96279a0e1be0b2fbd59"
POST_EX5_SHA256 = "59d116784db396fd081175503e6e43b154593925d781e01bb18bc8a9f2f95750"
SOURCE_SHA256 = "8c5457fc7cc7b10af168f89089b7320a5118d43078f87ed73232de18bbe0d4fc"
SYMBOL = "EURUSD.DWX"
PERIOD = "H1"
MODEL = 4
RNG_SEED = 42
FROM_DATE = "2022.07.01"
TO_DATE = "2022.12.31"
YEAR = 2022
RUN_TIMEOUT_SECONDS = 1800
RUNTIME_EXPERT = rf"QM\EQV35005\{EA_LABEL}"
POST_INPUTS = (
    "opt_pp_buy1",
    "opt_pp_buy2",
    "opt_pp_buy3",
    "opt_pp_sell1",
    "opt_pp_sell2",
    "opt_pp_sell3",
)
DEAL_FIELDS = (
    "Time",
    "Deal",
    "Symbol",
    "Type",
    "Direction",
    "Volume",
    "Price",
    "Order",
    "Commission",
    "Swap",
    "Profit",
    "Balance",
    "Comment",
)
GATE_PASS_STATUSES = frozenset({"PASS_ISOLATED", "PASS_SERIALIZED_ROLLBACK"})
REPORT_INPUT_MARKERS = frozenset({"inputs", "eingaben"})
REPORT_INPUT_END_MARKERS = frozenset({"company", "firma"})


class EquivalenceError(RuntimeError):
    """A fail-closed proof precondition or execution invariant failed."""


@dataclass(frozen=True)
class FileIdentity:
    path: str
    sha256: str
    size_bytes: int
    mtime_ns: int


class _TableParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.rows: list[list[str]] = []
        self._row: list[str] | None = None
        self._in_cell = False
        self._parts: list[str] = []

    def handle_starttag(
        self, tag: str, attrs: list[tuple[str, str | None]]
    ) -> None:
        del attrs
        normalized = tag.casefold()
        if normalized == "tr":
            self._row = []
        elif normalized in {"td", "th"} and self._row is not None:
            self._in_cell = True
            self._parts = []

    def handle_data(self, data: str) -> None:
        if self._in_cell:
            self._parts.append(data)

    def handle_endtag(self, tag: str) -> None:
        normalized = tag.casefold()
        if normalized in {"td", "th"} and self._row is not None and self._in_cell:
            # MT5 may wrap a value in nested tags or non-breaking spaces.  The
            # documented canonical field representation is decoded Unicode
            # text with internal whitespace collapsed to one ASCII space.
            value = html.unescape("".join(self._parts)).replace("\xa0", " ")
            self._row.append(" ".join(value.split()))
            self._in_cell = False
            self._parts = []
        elif normalized == "tr" and self._row is not None:
            self.rows.append(self._row)
            self._row = None


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def file_identity(path: Path) -> FileIdentity:
    resolved = path.resolve()
    stat = resolved.stat()
    return FileIdentity(
        path=str(resolved),
        sha256=sha256_file(resolved),
        size_bytes=int(stat.st_size),
        mtime_ns=int(stat.st_mtime_ns),
    )


def canonical_json_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        + "\n"
    ).encode("utf-8")


def _atomic_write_bytes(path: Path, value: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.{uuid.uuid4().hex}.tmp")
    try:
        with temporary.open("xb") as handle:
            handle.write(value)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass


def atomic_write_json(path: Path, value: Any) -> None:
    _atomic_write_bytes(
        path,
        (
            json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True)
            + "\n"
        ).encode("utf-8"),
    )


def _read_text(path: Path) -> str:
    raw = path.read_bytes()
    encodings: list[str] = []
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
        encodings.append("utf-16")
    if raw.startswith(b"\xef\xbb\xbf"):
        encodings.append("utf-8-sig")
    sample = raw[: min(512, len(raw))]
    if sample and sample[1::2].count(0) > max(2, len(sample) // 8):
        encodings.append("utf-16-le")
    encodings.extend(("utf-8-sig", "utf-8", "utf-16", "utf-16-le"))
    for encoding in dict.fromkeys(encodings):
        try:
            decoded = raw.decode(encoding)
        except UnicodeError:
            continue
        if "<" in decoded and ">" in decoded:
            return decoded
    raise EquivalenceError(f"native report encoding unresolved: {path}")


def report_rows(path: Path) -> list[list[str]]:
    parser = _TableParser()
    parser.feed(_read_text(path))
    if not parser.rows:
        raise EquivalenceError(f"native report contains no table rows: {path}")
    return parser.rows


def _normalized_label(value: str) -> str:
    return " ".join(str(value).strip().rstrip(":").casefold().split())


def extract_deal_rows(path: Path) -> list[dict[str, str]]:
    """Return the native Deals table in the exact documented field schema."""

    rows = report_rows(path)
    in_deals = False
    header: tuple[str, ...] | None = None
    deals: list[dict[str, str]] = []
    for row in rows:
        if len(row) == 1 and _normalized_label(row[0]) in {"deals", "geschafte"}:
            in_deals = True
            header = None
            continue
        if not in_deals:
            continue
        if header is None:
            if tuple(row) != DEAL_FIELDS:
                raise EquivalenceError(
                    f"native Deals schema drift: expected={DEAL_FIELDS!r} observed={tuple(row)!r}"
                )
            header = tuple(row)
            continue
        # Native report footers/summary rows follow the Deals table and may
        # have several cells.  A deal row is unambiguously timestamp-led; the
        # first non-timestamp row ends the canonical trade list.
        if not row or not re.fullmatch(r"\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}", row[0]):
            break
        if len(row) != len(header):
            raise EquivalenceError(
                f"native Deals row width drift: expected={len(header)} observed={len(row)} row={row!r}"
            )
        deals.append(dict(zip(header, row)))
    if header is None:
        raise EquivalenceError(f"native report has no Deals section: {path}")
    if not deals:
        raise EquivalenceError(f"native Deals table is empty: {path}")
    traded = [row for row in deals if row.get("Symbol") and row.get("Direction")]
    if not traded:
        raise EquivalenceError(f"native Deals table has no trade deals: {path}")
    return deals


def canonical_deal_bytes(rows: Sequence[Mapping[str, str]]) -> bytes:
    lines: list[str] = []
    for row in rows:
        if tuple(row.keys()) != DEAL_FIELDS:
            raise EquivalenceError(
                f"deal row field order drift: expected={DEAL_FIELDS!r} observed={tuple(row.keys())!r}"
            )
        values = {field: str(row[field]) for field in DEAL_FIELDS}
        lines.append(
            json.dumps(values, ensure_ascii=False, separators=(",", ":"))
        )
    return (("\n".join(lines) + "\n") if lines else "").encode("utf-8")


def compare_deal_rows(
    before: Sequence[Mapping[str, str]], after: Sequence[Mapping[str, str]]
) -> dict[str, Any]:
    differences: list[dict[str, Any]] = []
    for index in range(max(len(before), len(after))):
        left = before[index] if index < len(before) else None
        right = after[index] if index < len(after) else None
        if left is None or right is None:
            differences.append(
                {"row_index": index, "pre": left, "post": right, "fields": ["<row>"]}
            )
            continue
        fields = [field for field in DEAL_FIELDS if left.get(field) != right.get(field)]
        if fields:
            differences.append(
                {
                    "row_index": index,
                    "fields": fields,
                    "pre": {field: left.get(field) for field in fields},
                    "post": {field: right.get(field) for field in fields},
                }
            )
    return {
        "identical": not differences,
        "pre_row_count": len(before),
        "post_row_count": len(after),
        "different_row_count": len(differences),
        "differences": differences,
    }


def extract_report_inputs(path: Path) -> dict[str, str]:
    rows = report_rows(path)
    in_inputs = False
    values: dict[str, str] = {}
    for row in rows:
        normalized = {_normalized_label(cell) for cell in row}
        if normalized & REPORT_INPUT_MARKERS:
            in_inputs = True
        if in_inputs and normalized & REPORT_INPUT_END_MARKERS:
            break
        if not in_inputs:
            continue
        for cell in row:
            key, separator, value = cell.partition("=")
            key = key.strip()
            if separator and re.fullmatch(r"[A-Za-z_]\w*", key):
                if key in values and values[key] != value.strip():
                    raise EquivalenceError(f"conflicting report input echo for {key}")
                values[key] = value.strip()
    if not in_inputs:
        raise EquivalenceError(f"native report has no Inputs section: {path}")
    return values


def post_input_echo_check(inputs: Mapping[str, str]) -> dict[str, Any]:
    observed = {name: inputs.get(name) for name in POST_INPUTS}
    failures = {
        name: value for name, value in observed.items() if value != "0"
    }
    return {"pass": not failures, "observed": observed, "failures": failures}


def parse_setfile(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line_number, raw in enumerate(
        path.read_text(encoding="utf-8-sig").splitlines(), 1
    ):
        line = raw.strip()
        if not line or line.startswith((";", "#")):
            continue
        if "=" not in line:
            raise EquivalenceError(f"malformed setfile line {path}:{line_number}")
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.split("||", 1)[0].strip()
        if key in values:
            raise EquivalenceError(f"duplicate setfile key {path}:{line_number}: {key}")
        values[key] = value
    return values


def validate_risk_contract(path: Path) -> dict[str, Any]:
    values = parse_setfile(path)
    try:
        fixed = float(values["RISK_FIXED"])
        percent = float(values["RISK_PERCENT"])
    except (KeyError, ValueError) as exc:
        raise EquivalenceError(f"setfile risk contract is invalid: {path}") from exc
    if fixed <= 0 or percent != 0:
        raise EquivalenceError(
            f"setfile risk contract refused: RISK_FIXED={fixed} RISK_PERCENT={percent}"
        )
    return {"RISK_FIXED": fixed, "RISK_PERCENT": percent}


def parse_tester_ini(path: Path) -> dict[str, str]:
    section = ""
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line or line.startswith((";", "#")):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1].strip()
            continue
        if section.casefold() != "tester" or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    if not values:
        raise EquivalenceError(f"tester.ini contains no [Tester] values: {path}")
    return values


def canonical_execution_ini(path: Path) -> dict[str, str]:
    # Output location is deliberately unique per run and has no execution
    # semantics.  Every other generated tester field must match exactly.
    ignored = {"Report", "ReplaceReport"}
    return {
        key: value
        for key, value in parse_tester_ini(path).items()
        if key not in ignored
    }


def _work_item_value(item: sqlite3.Row | Mapping[str, Any], key: str) -> Any:
    try:
        return item[key]
    except (KeyError, IndexError, TypeError):
        return None


def _paths(repo_root: Path) -> dict[str, Path]:
    relative_ea = Path("framework") / "EAs" / EA_LABEL
    ea_dir = repo_root / relative_ea
    return {
        "ea_dir": ea_dir,
        "mq5": ea_dir / f"{EA_LABEL}.mq5",
        "pre_ex5": ea_dir / f"{EA_LABEL}.ex5",
        "post_ex5": (
            Path(r"C:\QM\archive\repo-dirty-20260826T113012Z\tracked-before-restore")
            / relative_ea
            / f"{EA_LABEL}.ex5"
        ),
        "setfile": ea_dir / "sets" / f"{EA_LABEL}_{SYMBOL}_{PERIOD}_backtest.set",
        "compile_evidence": (
            Path(r"D:\QM\reports\work_items")
            / COMPILE_WORK_ITEM_ID
            / EA_ID
            / "COMPILE_EA"
            / "compile_evidence.json"
        ),
        "run_smoke": repo_root / "framework" / "scripts" / "run_smoke.ps1",
    }


def _require_file_hash(path: Path, expected: str, label: str) -> FileIdentity:
    if not path.is_file():
        raise EquivalenceError(f"{label} missing: {path}")
    identity = file_identity(path)
    if identity.sha256 != expected:
        raise EquivalenceError(
            f"{label} hash mismatch: expected={expected} observed={identity.sha256} path={path}"
        )
    return identity


def _load_compile_receipt(root: Path, path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise EquivalenceError(f"governed compile receipt missing: {path}")
    try:
        receipt = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise EquivalenceError(f"governed compile receipt unreadable: {path}") from exc
    checks = {
        "schema": receipt.get("schema_version") == "qm.compile-ea-evidence/v1",
        "work_item": receipt.get("work_item_id") == COMPILE_WORK_ITEM_ID,
        "ea_id": receipt.get("ea_id") == EA_ID,
        "ea_label": receipt.get("ea_label") == EA_LABEL,
        "success": receipt.get("success") is True,
        "build": receipt.get("build_check_result") == "PASS",
        "compile": receipt.get("compile_result") == "PASS",
        "errors": str(receipt.get("compile_errors")) == "0",
        "warnings": str(receipt.get("compile_warnings")) == "0",
        "post_hash": receipt.get("ex5_sha256") == POST_EX5_SHA256,
        "source_hash": (
            (receipt.get("candidate_recheck") or {}).get("mq5_sha256")
            == SOURCE_SHA256
        ),
        "no_gate_verdict": receipt.get("no_gate_verdict") is True,
    }
    failed = [name for name, passed in checks.items() if not passed]
    if failed:
        raise EquivalenceError(f"governed compile receipt authentication failed: {failed}")
    with farmctl.connect(root) as conn:
        row = conn.execute(
            "SELECT status,verdict,evidence_path,payload_json FROM work_items WHERE id=?",
            (COMPILE_WORK_ITEM_ID,),
        ).fetchone()
    if row is None:
        raise EquivalenceError("governed compile work item is absent from canonical DB")
    if (
        row["status"] != "done"
        or row["verdict"] != "COMPILE_OK"
        or os.path.normcase(str(Path(row["evidence_path"]).resolve()))
        != os.path.normcase(str(path.resolve()))
    ):
        raise EquivalenceError("governed compile DB row does not bind the receipt")
    return {
        "path": str(path.resolve()),
        "sha256": sha256_file(path),
        "checks": checks,
        "receipt": receipt,
    }


def _git_pre_identity(repo_root: Path, relative_ex5: Path) -> dict[str, Any]:
    command = ["git", "show", f"{PRE_INTEGRATION_COMMIT}:{relative_ex5.as_posix()}"]
    completed = subprocess.run(
        command,
        cwd=repo_root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=120,
        check=False,
    )
    observed = sha256_bytes(completed.stdout)
    if completed.returncode != 0 or observed != PRE_EX5_SHA256:
        raise EquivalenceError(
            "retained Git pre-integration EX5 authentication failed: "
            f"exit={completed.returncode} expected={PRE_EX5_SHA256} observed={observed}"
        )
    return {
        "commit": PRE_INTEGRATION_COMMIT,
        "path": relative_ex5.as_posix(),
        "sha256": observed,
        "size_bytes": len(completed.stdout),
    }


def _seed_contract(repo_root: Path) -> dict[str, Any]:
    relative = Path("framework/include/QM/QM_Common.mqh")
    pre = subprocess.run(
        ["git", "show", f"{PRE_INTEGRATION_COMMIT}:{relative.as_posix()}"],
        cwd=repo_root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=120,
        check=False,
    )
    current_path = repo_root / relative
    if pre.returncode != 0 or not current_path.is_file():
        raise EquivalenceError("framework RNG seed source could not be authenticated")
    pre_text = pre.stdout.decode("utf-8", errors="strict")
    current_bytes = current_path.read_bytes()
    current_text = current_bytes.decode("utf-8-sig", errors="strict")

    def _defaults(value: str) -> list[int]:
        return [
            int(match)
            for match in re.findall(r"const\s+uint\s+rng_seed\s*=\s*(\d+)", value)
        ]

    pre_defaults = _defaults(pre_text)
    current_defaults = _defaults(current_text)
    if (
        not pre_defaults
        or not current_defaults
        or set(pre_defaults) != {RNG_SEED}
        or set(current_defaults) != {RNG_SEED}
    ):
        raise EquivalenceError(
            f"framework RNG seed default drift: pre={pre_defaults} post={current_defaults}"
        )
    return {
        "value": RNG_SEED,
        "interface": "QM_FrameworkInit rng_seed default",
        "pre_commit": PRE_INTEGRATION_COMMIT,
        "pre_source_path": relative.as_posix(),
        "pre_source_sha256": sha256_bytes(pre.stdout),
        "pre_declarations": pre_defaults,
        "post_source_path": str(current_path.resolve()),
        "post_source_sha256": sha256_bytes(current_bytes),
        "post_declarations": current_defaults,
    }


def _history_projection(receipt: Mapping[str, Any]) -> list[dict[str, Any]]:
    return sorted(
        (
            {
                "relative_path": str(row["relative_path"]),
                "size": int(row["size"]),
                "sha256": str(row["sha256"]),
            }
            for row in receipt.get("files", [])
        ),
        key=lambda row: row["relative_path"].casefold(),
    )


def _prepare_history_snapshot(
    root: Path, terminal: str, artifact_root: Path, suffix: str
) -> dict[str, Any]:
    gate_before = custom_history_gate.run_worker_gate(root, terminal=terminal)
    if gate_before.get("required") is not True or (
        gate_before.get("status") not in GATE_PASS_STATUSES
        or gate_before.get("admission_allowed") is False
    ):
        raise EquivalenceError(
            f"custom-history gate refused {terminal}: {gate_before}"
        )
    activation = custom_history_gate.load_activation(root)
    if activation is None:
        raise EquivalenceError("custom-history activation disappeared")
    manifest = custom_history_contract.load_manifest(
        Path(activation["manifest_path"]), require_owner_approval=True
    )
    receipt_path = artifact_root / f"history_{suffix}_receipt.json"
    receipt = custom_history_copy_on_claim.privatize_terminal_archives(
        manifest=manifest,
        mt5_root=Path(r"D:\QM\mt5"),
        terminal=terminal,
        symbols=(SYMBOL,),
        receipt_path=receipt_path,
        farm_root=root,
    )
    if receipt.get("status") != "PASS_PRIVATIZED":
        raise EquivalenceError(f"custom-history privatization failed: {receipt}")
    gate_after = custom_history_gate.run_worker_gate(root, terminal=terminal)
    if gate_after.get("status") not in GATE_PASS_STATUSES:
        raise EquivalenceError(f"custom-history post-copy gate failed: {gate_after}")
    projection = _history_projection(receipt)
    if not projection:
        raise EquivalenceError("custom-history snapshot selected no files")
    return {
        "gate_before": gate_before,
        "gate_after": gate_after,
        "manifest_path": str(Path(activation["manifest_path"]).resolve()),
        "manifest_sha256": activation["manifest_sha256"],
        "receipt_path": str(receipt_path.resolve()),
        "receipt_file_sha256": sha256_file(receipt_path),
        "receipt_sha256": receipt["receipt_sha256"],
        "selected_file_count": len(projection),
        "selected_files": projection,
        "selected_files_sha256": sha256_bytes(canonical_json_bytes(projection)),
    }


def _wait_terminal_quiescent(terminal: str, seconds: float = 30.0) -> None:
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if terminal.upper() not in running_terminal_names():
            return
        time.sleep(0.5)
    raise EquivalenceError(f"claimed terminal did not become quiescent: {terminal}")


def _run_smoke(
    *,
    root: Path,
    repo_root: Path,
    work_item_id: str,
    terminal: str,
    side: str,
    expected_ex5_sha256: str,
    setfile: Path,
    report_root: Path,
    log_path: Path,
) -> dict[str, Any]:
    _wait_terminal_quiescent(terminal)
    command = [
        "pwsh.exe",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(repo_root / "framework" / "scripts" / "run_smoke.ps1"),
        "-EAId",
        str(EA_NUMERIC_ID),
        "-EALabel",
        EA_LABEL,
        "-Symbol",
        SYMBOL,
        "-Year",
        str(YEAR),
        "-FromDate",
        FROM_DATE,
        "-ToDate",
        TO_DATE,
        "-Terminal",
        terminal,
        "-Expert",
        RUNTIME_EXPERT,
        "-Period",
        PERIOD,
        "-Runs",
        "1",
        "-MinTrades",
        "1",
        "-Model",
        str(MODEL),
        "-TimeoutSeconds",
        str(RUN_TIMEOUT_SECONDS),
        "-SetFile",
        str(setfile),
        "-ReportRoot",
        str(report_root),
        "-DispatchPhase",
        "Q11",
        "-DispatchVersion",
        CONTRACT_VERSION,
        "-DispatchSubGateHash",
        sha256_bytes(
            canonical_json_bytes(
                {
                    "task_id": TASK_ID,
                    "symbol": SYMBOL,
                    "period": PERIOD,
                    "model": MODEL,
                    "seed": RNG_SEED,
                    "from": FROM_DATE,
                    "to": TO_DATE,
                    "setfile_sha256": sha256_file(setfile),
                }
            )
        ),
        "-ExpectedExpertSha256",
        expected_ex5_sha256,
        "-SkipExpertDeploy",
        "-SmokeMode",
    ]
    env = os.environ.copy()
    env["QM_WORK_ITEM_ID"] = work_item_id
    env["QM_WORK_ITEM_TERMINAL"] = terminal.upper()
    log_path.parent.mkdir(parents=True, exist_ok=True)
    creationflags = farmctl.suspended_runner_creation_flags()
    process = subprocess.Popen(
        command,
        cwd=repo_root,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        stdin=subprocess.DEVNULL,
        text=True,
        encoding="utf-8",
        errors="replace",
        creationflags=creationflags,
        close_fds=True,
    )
    process_identity = farmctl.bind_spawned_process_to_kill_job(
        process,
        farmctl._capture_spawned_process_identity,
        process_created_suspended=(sys.platform == "win32"),
    )
    try:
        output, _ = process.communicate(timeout=RUN_TIMEOUT_SECONDS + 600)
    except subprocess.TimeoutExpired as exc:
        process.kill()
        try:
            output, _ = process.communicate(timeout=30)
        except subprocess.TimeoutExpired:
            output = ""
        raise EquivalenceError(f"{side} run_smoke outer timeout") from exc
    finally:
        farmctl.reap_finished_job_objects()
    _atomic_write_bytes(log_path, (output or "").encode("utf-8"))
    summary_match = re.search(r"(?m)^run_smoke\.summary=(.+)$", output or "")
    summary_path = Path(summary_match.group(1).strip()) if summary_match else None
    if process.returncode != 0 or summary_path is None or not summary_path.is_file():
        raise EquivalenceError(
            f"{side} run_smoke failed: exit={process.returncode} summary={summary_path} log={log_path}"
        )
    summary = json.loads(summary_path.read_text(encoding="utf-8-sig"))
    return {
        "side": side,
        "command": command,
        "process": {"exit_code": process.returncode, **process_identity},
        "log_path": str(log_path.resolve()),
        "log_sha256": sha256_file(log_path),
        "summary_path": str(summary_path.resolve()),
        "summary_sha256": sha256_file(summary_path),
        "summary": summary,
    }


def _authenticate_smoke(
    run: Mapping[str, Any], expected_ex5_sha256: str, expected_setfile_sha256: str
) -> dict[str, Any]:
    summary = run["summary"]
    ok_runs = [row for row in summary.get("runs", []) if row.get("status") == "OK"]
    checks = {
        "result": summary.get("result") == "PASS",
        "ea_id": int(summary.get("ea_id") or 0) == EA_NUMERIC_ID,
        "expert": summary.get("expert") == RUNTIME_EXPERT,
        "symbol": summary.get("symbol") == SYMBOL,
        "period": summary.get("period") == PERIOD,
        "model": int(summary.get("model") or -1) == MODEL,
        "from_date": summary.get("from_date") == FROM_DATE,
        "to_date": summary.get("to_date") == TO_DATE,
        "terminal": str(summary.get("terminal") or "").upper()
        == str(run.get("terminal") or summary.get("terminal") or "").upper(),
        "one_ok_run": len(ok_runs) == 1,
        "nonempty_trade_list": bool(ok_runs and int(ok_runs[0].get("total_trades") or 0) > 0),
        "model4_marker": summary.get("model4_log_marker_detected") is True,
        "stable_during_run": (
            (summary.get("execution_identity") or {}).get("stable_during_run") is True
        ),
        "ex5_hash": (
            (((summary.get("execution_identity") or {}).get("expert_binary") or {}).get("deployed") or {}).get("sha256")
            == expected_ex5_sha256
        ),
        "setfile_hash": (
            ((((summary.get("execution_identity") or {}).get("setfile") or {}).get("source") or {}).get("sha256"))
            == expected_setfile_sha256
        ),
    }
    failed = [name for name, passed in checks.items() if not passed]
    if failed:
        raise EquivalenceError(
            f"{run['side']} run_smoke evidence authentication failed: {failed}"
        )
    report_path = Path(ok_runs[0]["report_canonical_path"])
    ini_path = Path(ok_runs[0]["tester_ini_path"])
    if not report_path.is_file() or not ini_path.is_file():
        raise EquivalenceError(f"{run['side']} native report/tester.ini missing")
    return {
        "checks": checks,
        "report_path": str(report_path.resolve()),
        "report_sha256": sha256_file(report_path),
        "report_size_bytes": report_path.stat().st_size,
        "tester_ini_path": str(ini_path.resolve()),
        "tester_ini_sha256": sha256_file(ini_path),
        "total_trades": int(ok_runs[0]["total_trades"]),
    }


def _stage_runtime_expert(
    source: Path, destination: Path, expected_sha256: str
) -> FileIdentity:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(
        f".{destination.name}.{os.getpid()}.{uuid.uuid4().hex}.tmp"
    )
    try:
        shutil.copyfile(source, temporary)
        if sha256_file(temporary) != expected_sha256:
            raise EquivalenceError("runtime expert temporary copy hash mismatch")
        os.replace(temporary, destination)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass
    return _require_file_hash(destination, expected_sha256, "runtime staged EX5")


def _retain_binary(source: Path, destination: Path, expected_sha256: str) -> FileIdentity:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.is_file() and sha256_file(destination) == expected_sha256:
        return file_identity(destination)
    temporary = destination.with_name(
        f".{destination.name}.{os.getpid()}.{uuid.uuid4().hex}.tmp"
    )
    try:
        shutil.copyfile(source, temporary)
        if sha256_file(temporary) != expected_sha256:
            raise EquivalenceError("retained EX5 temporary copy hash mismatch")
        os.replace(temporary, destination)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass
    return file_identity(destination)


def _validate_payload(payload: Mapping[str, Any], item_id: str) -> None:
    expected = {
        "equivalence_contract_version": CONTRACT_VERSION,
        "equivalence_task_id": TASK_ID,
        "source_escalation_task_id": SOURCE_ESCALATION_TASK_ID,
        "ea_label": EA_LABEL,
        "pre_ex5_sha256": PRE_EX5_SHA256,
        "post_ex5_sha256": POST_EX5_SHA256,
        "mq5_sha256": SOURCE_SHA256,
        "compile_work_item_id": COMPILE_WORK_ITEM_ID,
        "seed": RNG_SEED,
        "host_symbol": SYMBOL,
        "host_timeframe": PERIOD,
        "from_date": FROM_DATE,
        "to_date": TO_DATE,
        "model": MODEL,
    }
    failed = [key for key, value in expected.items() if payload.get(key) != value]
    if payload.get("no_gate_verdict") is not True:
        failed.append("no_gate_verdict")
    if str(payload.get("work_item_id") or item_id) != item_id:
        failed.append("work_item_id")
    if failed:
        raise EquivalenceError(f"equivalence payload authentication failed: {failed}")


def _same_path(left: Any, right: Path) -> bool:
    try:
        return os.path.normcase(str(Path(str(left)).resolve())) == os.path.normcase(
            str(right.resolve())
        )
    except (OSError, ValueError, TypeError):
        return False


def _validate_sealed_inputs(
    payload: Mapping[str, Any],
    paths: Mapping[str, Path],
    *,
    pre: FileIdentity,
    post: FileIdentity,
    source: FileIdentity,
    setfile: FileIdentity,
    compile_receipt: Mapping[str, Any],
) -> None:
    checks = {
        "pre_path": _same_path(payload.get("pre_ex5_path"), paths["pre_ex5"]),
        "pre_hash": payload.get("pre_ex5_sha256") == pre.sha256,
        "post_path": _same_path(payload.get("post_ex5_path"), paths["post_ex5"]),
        "post_hash": payload.get("post_ex5_sha256") == post.sha256,
        "source_path": _same_path(payload.get("mq5_path"), paths["mq5"]),
        "source_hash": payload.get("mq5_sha256") == source.sha256,
        "setfile_path": _same_path(payload.get("setfile_path"), paths["setfile"]),
        "setfile_hash": payload.get("setfile_sha256") == setfile.sha256,
        "compile_evidence_path": _same_path(
            payload.get("compile_evidence_path"), paths["compile_evidence"]
        ),
        "compile_evidence_hash": (
            payload.get("compile_evidence_sha256") == compile_receipt.get("sha256")
        ),
        "run_smoke_path": _same_path(
            payload.get("run_smoke_path"), paths["run_smoke"]
        ),
        "run_smoke_hash": (
            payload.get("run_smoke_sha256") == sha256_file(paths["run_smoke"])
        ),
        "runner_path": _same_path(payload.get("runner_path"), Path(__file__)),
        "runner_hash": payload.get("runner_sha256") == sha256_file(Path(__file__)),
        "risk_fixed": (payload.get("risk_contract") or {}).get("RISK_FIXED")
        == 1000.0,
        "risk_percent": (payload.get("risk_contract") or {}).get("RISK_PERCENT")
        == 0.0,
    }
    failed = [name for name, passed in checks.items() if not passed]
    if failed:
        raise EquivalenceError(f"sealed equivalence input drift: {failed}")


def _completion(
    root: Path,
    work_item_id: str,
    terminal: str,
    evidence_path: Path,
    evidence: Mapping[str, Any],
) -> None:
    success = evidence.get("execution_status") == "COMPLETE"
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        row = conn.execute(
            "SELECT payload_json,status,claimed_by FROM work_items WHERE id=?",
            (work_item_id,),
        ).fetchone()
        if (
            row is None
            or row["status"] != "active"
            or str(row["claimed_by"] or "").upper() != terminal.upper()
        ):
            raise EquivalenceError("equivalence work-item ownership changed")
        payload = json.loads(row["payload_json"] or "{}")
        payload.update(
            {
                "equivalence_completed_at": now,
                "equivalence_evidence_path": str(evidence_path),
                "equivalence_outcome": evidence.get("outcome"),
                "equivalence_execution_status": evidence.get("execution_status"),
                "verdict_reason": (
                    "EQUIVALENCE_ARTIFACT_READY"
                    if success
                    else "EQUIVALENCE_EXECUTION_FAILED"
                ),
                "verdict_taxonomy": "artifact" if success else "infra",
                "no_gate_verdict": True,
            }
        )
        status = "done" if success else "failed"
        verdict = UTILITY_COMPLETION if success else "INFRA_FAIL"
        cursor = conn.execute(
            "UPDATE work_items SET status=?,verdict=?,evidence_path=?,claimed_by=NULL,"
            "payload_json=?,updated_at=?,verdict_taxonomy=? "
            "WHERE id=? AND status='active' AND upper(claimed_by)=upper(?)",
            (
                status,
                verdict,
                str(evidence_path),
                json.dumps(payload, sort_keys=True),
                now,
                "artifact" if success else "infra",
                work_item_id,
                terminal,
            ),
        )
        if cursor.rowcount != 1:
            conn.rollback()
            raise EquivalenceError("equivalence completion CAS failed")
        conn.commit()


def _render_comparison_csv(path: Path, evidence: Mapping[str, Any]) -> None:
    rows = [
        ("EX5 SHA-256", PRE_EX5_SHA256, POST_EX5_SHA256, "BOUND"),
        (
            "Setfile SHA-256",
            evidence["setup"]["setfile"]["sha256"],
            evidence["setup"]["setfile"]["sha256"],
            "IDENTICAL",
        ),
        ("Symbol", SYMBOL, SYMBOL, "IDENTICAL"),
        ("Period", PERIOD, PERIOD, "IDENTICAL"),
        ("Window", f"{FROM_DATE}..{TO_DATE}", f"{FROM_DATE}..{TO_DATE}", "IDENTICAL"),
        ("Model", str(MODEL), str(MODEL), "IDENTICAL"),
        ("Seed", str(RNG_SEED), str(RNG_SEED), "IDENTICAL"),
        (
            "Terminal64 SHA-256",
            evidence["setup"]["terminal_binaries_before"]["terminal64.exe"]["sha256"],
            evidence["setup"]["terminal_binaries_before"]["terminal64.exe"]["sha256"],
            "IDENTICAL",
        ),
        (
            "History snapshot SHA-256",
            evidence["setup"]["history_before"]["selected_files_sha256"],
            evidence["setup"]["history_after"]["selected_files_sha256"],
            "IDENTICAL" if evidence["checks"]["history_snapshot_stable"] else "DIFFERENT",
        ),
        (
            "Native Deals rows",
            str(evidence["runs"]["pre"]["deal_row_count"]),
            str(evidence["runs"]["post"]["deal_row_count"]),
            "IDENTICAL" if evidence["comparison"]["identical"] else "DIFFERENT",
        ),
        (
            "Canonical Deals SHA-256",
            evidence["runs"]["pre"]["canonical_deals_sha256"],
            evidence["runs"]["post"]["canonical_deals_sha256"],
            "IDENTICAL" if evidence["checks"]["canonical_deal_bytes_equal"] else "DIFFERENT",
        ),
        (
            "Tester execution fields",
            evidence["runs"]["pre"]["execution_ini_sha256"],
            evidence["runs"]["post"]["execution_ini_sha256"],
            "IDENTICAL" if evidence["checks"]["execution_ini_equal"] else "DIFFERENT",
        ),
        (
            "Post opt_pp_* echo",
            "not required on pre binary",
            json.dumps(evidence["post_input_echo"]["observed"], sort_keys=True),
            "PASS" if evidence["post_input_echo"]["pass"] else "FAIL",
        ),
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.{uuid.uuid4().hex}.tmp")
    try:
        with temporary.open("x", encoding="utf-8", newline="") as handle:
            writer = csv.writer(handle, lineterminator="\n")
            writer.writerow(("check", "pre", "post", "comparison"))
            writer.writerows(rows)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass


def _render_markdown(path: Path, evidence: Mapping[str, Any]) -> None:
    outcome = evidence["outcome"]
    echo = evidence["post_input_echo"]["observed"]
    lines = [
        "# QM5_35005 pre/post pattern-include runtime equivalence",
        "",
        f"- Router task: `{TASK_ID}`",
        f"- Governed queue work item: `{evidence['work_item_id']}`",
        f"- Terminal worker claim: `{evidence['terminal']}`",
        f"- Outcome: **{outcome}**",
        f"- Pipeline/gate verdict: **none** (`{UTILITY_COMPLETION}` is only the utility-row completion token)",
        "",
        "## Exact comparison",
        "",
        "| Check | Pre | Post | Result |",
        "|---|---|---|---|",
        f"| EX5 SHA-256 | `{PRE_EX5_SHA256}` | `{POST_EX5_SHA256}` | bound |",
        f"| Native Deals rows | {evidence['runs']['pre']['deal_row_count']} | {evidence['runs']['post']['deal_row_count']} | {'IDENTICAL' if evidence['comparison']['identical'] else 'DIFFERENT'} |",
        f"| Canonical Deals SHA-256 | `{evidence['runs']['pre']['canonical_deals_sha256']}` | `{evidence['runs']['post']['canonical_deals_sha256']}` | {'IDENTICAL' if evidence['checks']['canonical_deal_bytes_equal'] else 'DIFFERENT'} |",
        f"| Tester execution fields | `{evidence['runs']['pre']['execution_ini_sha256']}` | `{evidence['runs']['post']['execution_ini_sha256']}` | {'IDENTICAL' if evidence['checks']['execution_ini_equal'] else 'DIFFERENT'} |",
        f"| History snapshot | `{evidence['setup']['history_before']['selected_files_sha256']}` | `{evidence['setup']['history_after']['selected_files_sha256']}` | {'IDENTICAL' if evidence['checks']['history_snapshot_stable'] else 'DIFFERENT'} |",
        "",
        f"Setup for both runs: the same terminal, runtime Expert path, exact setfile bytes, `EURUSD.DWX`, H1, model 4, framework RNG seed `{RNG_SEED}`, and `2022.07.01` through `2022.12.31`. Both native reports contain a non-empty Deals table.",
        "",
        "## Post binary input echo",
        "",
    ]
    lines.extend(f"- `{name}={echo.get(name)}`" for name in POST_INPUTS)
    lines.extend(
        [
            "",
            "## Interpretation",
            "",
            (
                "The canonical native Deals byte streams and every documented field are identical. The ordinary post-integration binary also echoes all six pattern-permission inputs at zero. This artifact is eligible for orchestration review of the compile-release hold; it does not lift the hold itself."
                if outcome == "IDENTICAL"
                else "At least one required equality or post-input condition differs. Keep the compile-release hold and escalate using the retained reports and machine-readable diff."
            ),
            "",
            f"Machine evidence: `{evidence['evidence_path']}`",
            f"Comparison CSV: `{evidence['comparison_csv_path']}`",
        ]
    )
    _atomic_write_bytes(path, ("\n".join(lines) + "\n").encode("utf-8"))


def run_work_item(
    root: Path,
    repo_root: Path,
    item: sqlite3.Row | Mapping[str, Any],
    terminal: str,
) -> dict[str, Any]:
    work_item_id = str(_work_item_value(item, "id") or "")
    terminal = str(terminal).upper()
    artifact_root = (
        Path(r"D:\QM\strategy_farm\artifacts\equivalence") / TASK_ID / work_item_id
    )
    report_root = Path(r"D:\QM\reports\work_items") / work_item_id / "equivalence"
    evidence_path = artifact_root / "equivalence_evidence.json"
    markdown_path = artifact_root / "equivalence_evidence.md"
    comparison_csv_path = artifact_root / "comparison.csv"
    started_at = farmctl.utc_now()
    evidence: dict[str, Any] = {
        "schema_version": CONTRACT_VERSION,
        "task_id": TASK_ID,
        "source_escalation_task_id": SOURCE_ESCALATION_TASK_ID,
        "work_item_id": work_item_id,
        "terminal": terminal,
        "started_at": started_at,
        "execution_status": "FAILED",
        "outcome": "NOT_PROVEN",
        "no_gate_verdict": True,
        "evidence_path": str(evidence_path),
        "comparison_csv_path": str(comparison_csv_path),
        "failure_classes": [],
    }
    runtime_destination = (
        Path(r"D:\QM\mt5")
        / terminal
        / "MQL5"
        / "Experts"
        / "QM"
        / "EQV35005"
        / f"{EA_LABEL}.ex5"
    )
    runtime_preexisting: bytes | None = None
    runtime_preexisting_identity: FileIdentity | None = None
    try:
        if not re.fullmatch(r"T(?:[1-9]|10)", terminal):
            raise EquivalenceError(f"invalid factory terminal claim: {terminal}")
        with farmctl.connect(root) as conn:
            owned = conn.execute(
                "SELECT status,claimed_by,payload_json FROM work_items WHERE id=?",
                (work_item_id,),
            ).fetchone()
        if (
            owned is None
            or owned["status"] != "active"
            or str(owned["claimed_by"] or "").upper() != terminal
        ):
            raise EquivalenceError("worker claim is not active and terminal-bound")
        payload = json.loads(owned["payload_json"] or "{}")
        _validate_payload(payload, work_item_id)
        paths = _paths(repo_root)
        pre_original_before = _require_file_hash(
            paths["pre_ex5"], PRE_EX5_SHA256, "pre-integration EX5"
        )
        post_original_before = _require_file_hash(
            paths["post_ex5"], POST_EX5_SHA256, "post-integration EX5"
        )
        source_identity = _require_file_hash(paths["mq5"], SOURCE_SHA256, "MQ5 source")
        setfile_identity = file_identity(paths["setfile"])
        risk_contract = validate_risk_contract(paths["setfile"])
        compile_receipt = _load_compile_receipt(root, paths["compile_evidence"])
        _validate_sealed_inputs(
            payload,
            paths,
            pre=pre_original_before,
            post=post_original_before,
            source=source_identity,
            setfile=setfile_identity,
            compile_receipt=compile_receipt,
        )
        relative_ex5 = paths["pre_ex5"].relative_to(repo_root)
        git_pre = _git_pre_identity(repo_root, relative_ex5)
        seed_contract = _seed_contract(repo_root)
        if git_pre["sha256"] != pre_original_before.sha256:
            raise EquivalenceError("current retained pre EX5 differs from Git pre bytes")
        _wait_terminal_quiescent(terminal)

        artifact_root.mkdir(parents=True, exist_ok=True)
        retained_pre = _retain_binary(
            paths["pre_ex5"],
            artifact_root / "binaries" / f"pre_{PRE_EX5_SHA256}.ex5",
            PRE_EX5_SHA256,
        )
        retained_post = _retain_binary(
            paths["post_ex5"],
            artifact_root / "binaries" / f"post_{POST_EX5_SHA256}.ex5",
            POST_EX5_SHA256,
        )
        if runtime_destination.is_file():
            runtime_preexisting = runtime_destination.read_bytes()
            runtime_preexisting_identity = file_identity(runtime_destination)

        terminal_root = Path(r"D:\QM\mt5") / terminal
        terminal_binaries_before = {
            name: asdict(file_identity(terminal_root / name))
            for name in ("terminal64.exe", "metatester64.exe")
        }
        history_before = _prepare_history_snapshot(
            root, terminal, artifact_root, "before"
        )
        run_smoke_before = file_identity(paths["run_smoke"])

        _stage_runtime_expert(
            Path(retained_pre.path), runtime_destination, PRE_EX5_SHA256
        )
        pre_run = _run_smoke(
            root=root,
            repo_root=repo_root,
            work_item_id=work_item_id,
            terminal=terminal,
            side="pre",
            expected_ex5_sha256=PRE_EX5_SHA256,
            setfile=paths["setfile"],
            report_root=report_root / "pre",
            log_path=artifact_root / "pre" / "run_smoke.log",
        )
        pre_run["terminal"] = terminal
        pre_auth = _authenticate_smoke(
            pre_run, PRE_EX5_SHA256, setfile_identity.sha256
        )
        if sha256_file(runtime_destination) != PRE_EX5_SHA256:
            raise EquivalenceError("pre runtime EX5 changed during its run")

        _stage_runtime_expert(
            Path(retained_post.path), runtime_destination, POST_EX5_SHA256
        )
        post_run = _run_smoke(
            root=root,
            repo_root=repo_root,
            work_item_id=work_item_id,
            terminal=terminal,
            side="post",
            expected_ex5_sha256=POST_EX5_SHA256,
            setfile=paths["setfile"],
            report_root=report_root / "post",
            log_path=artifact_root / "post" / "run_smoke.log",
        )
        post_run["terminal"] = terminal
        post_auth = _authenticate_smoke(
            post_run, POST_EX5_SHA256, setfile_identity.sha256
        )
        if sha256_file(runtime_destination) != POST_EX5_SHA256:
            raise EquivalenceError("post runtime EX5 changed during its run")

        pre_report = Path(pre_auth["report_path"])
        post_report = Path(post_auth["report_path"])
        pre_deals = extract_deal_rows(pre_report)
        post_deals = extract_deal_rows(post_report)
        pre_deal_bytes = canonical_deal_bytes(pre_deals)
        post_deal_bytes = canonical_deal_bytes(post_deals)
        pre_deal_path = artifact_root / "pre" / "native_deals.canonical.jsonl"
        post_deal_path = artifact_root / "post" / "native_deals.canonical.jsonl"
        _atomic_write_bytes(pre_deal_path, pre_deal_bytes)
        _atomic_write_bytes(post_deal_path, post_deal_bytes)
        comparison = compare_deal_rows(pre_deals, post_deals)
        atomic_write_json(artifact_root / "native_deals_diff.json", comparison)

        pre_inputs = extract_report_inputs(pre_report)
        post_inputs = extract_report_inputs(post_report)
        atomic_write_json(artifact_root / "pre" / "report_inputs.json", pre_inputs)
        atomic_write_json(artifact_root / "post" / "report_inputs.json", post_inputs)
        input_echo = post_input_echo_check(post_inputs)

        pre_ini = canonical_execution_ini(Path(pre_auth["tester_ini_path"]))
        post_ini = canonical_execution_ini(Path(post_auth["tester_ini_path"]))
        atomic_write_json(artifact_root / "pre" / "execution_ini.json", pre_ini)
        atomic_write_json(artifact_root / "post" / "execution_ini.json", post_ini)
        pre_ini_hash = sha256_bytes(canonical_json_bytes(pre_ini))
        post_ini_hash = sha256_bytes(canonical_json_bytes(post_ini))

        history_after = _prepare_history_snapshot(
            root, terminal, artifact_root, "after"
        )
        terminal_binaries_after = {
            name: asdict(file_identity(terminal_root / name))
            for name in ("terminal64.exe", "metatester64.exe")
        }
        pre_original_after = file_identity(paths["pre_ex5"])
        post_original_after = file_identity(paths["post_ex5"])
        source_after = file_identity(paths["mq5"])
        setfile_after = file_identity(paths["setfile"])
        run_smoke_after = file_identity(paths["run_smoke"])
        checks = {
            "canonical_deal_bytes_equal": pre_deal_bytes == post_deal_bytes,
            "deal_fields_equal": comparison["identical"],
            "execution_ini_equal": pre_ini == post_ini,
            "post_input_echo_zero": input_echo["pass"],
            "history_snapshot_stable": (
                history_before["selected_files_sha256"]
                == history_after["selected_files_sha256"]
            ),
            "terminal_binaries_stable": (
                terminal_binaries_before == terminal_binaries_after
            ),
            "pre_original_unchanged": pre_original_before == pre_original_after,
            "post_original_unchanged": post_original_before == post_original_after,
            "source_unchanged": source_identity == source_after,
            "setfile_unchanged": setfile_identity == setfile_after,
            "run_smoke_unchanged": run_smoke_before == run_smoke_after,
            "nonempty_trade_list": bool(pre_deals and post_deals),
        }
        outcome = "IDENTICAL" if all(checks.values()) else "DEVIATION"
        evidence.update(
            {
                "completed_at": farmctl.utc_now(),
                "execution_status": "COMPLETE",
                "outcome": outcome,
                "compile_receipt": compile_receipt,
                "git_pre_identity": git_pre,
                "setup": {
                    "symbol": SYMBOL,
                    "period": PERIOD,
                    "model": MODEL,
                    "seed": {
                        **seed_contract,
                    },
                    "from_date": FROM_DATE,
                    "to_date": TO_DATE,
                    "runtime_expert": RUNTIME_EXPERT,
                    "setfile": asdict(setfile_identity),
                    "risk_contract": risk_contract,
                    "mq5_source": asdict(source_identity),
                    "pre_original_before": asdict(pre_original_before),
                    "pre_original_after": asdict(pre_original_after),
                    "post_original_before": asdict(post_original_before),
                    "post_original_after": asdict(post_original_after),
                    "retained_pre": asdict(retained_pre),
                    "retained_post": asdict(retained_post),
                    "run_smoke_before": asdict(run_smoke_before),
                    "run_smoke_after": asdict(run_smoke_after),
                    "terminal_binaries_before": terminal_binaries_before,
                    "terminal_binaries_after": terminal_binaries_after,
                    "history_before": history_before,
                    "history_after": history_after,
                },
                "runs": {
                    "pre": {
                        **pre_auth,
                        "summary_path": pre_run["summary_path"],
                        "summary_sha256": pre_run["summary_sha256"],
                        "run_smoke_log_path": pre_run["log_path"],
                        "run_smoke_log_sha256": pre_run["log_sha256"],
                        "process": pre_run["process"],
                        "deal_row_count": len(pre_deals),
                        "canonical_deals_path": str(pre_deal_path),
                        "canonical_deals_sha256": sha256_bytes(pre_deal_bytes),
                        "execution_ini_sha256": pre_ini_hash,
                    },
                    "post": {
                        **post_auth,
                        "summary_path": post_run["summary_path"],
                        "summary_sha256": post_run["summary_sha256"],
                        "run_smoke_log_path": post_run["log_path"],
                        "run_smoke_log_sha256": post_run["log_sha256"],
                        "process": post_run["process"],
                        "deal_row_count": len(post_deals),
                        "canonical_deals_path": str(post_deal_path),
                        "canonical_deals_sha256": sha256_bytes(post_deal_bytes),
                        "execution_ini_sha256": post_ini_hash,
                    },
                },
                "post_input_echo": input_echo,
                "comparison": comparison,
                "checks": checks,
            }
        )
    except Exception as exc:  # evidence must survive every fail-closed stop
        evidence.update(
            {
                "completed_at": farmctl.utc_now(),
                "execution_status": "FAILED",
                "outcome": "NOT_PROVEN",
                "failure_classes": [type(exc).__name__],
                "exception": repr(exc),
            }
        )
    finally:
        cleanup: dict[str, Any] = {
            "runtime_path": str(runtime_destination),
            "preexisting": runtime_preexisting_identity is not None,
            "restored": False,
        }
        try:
            _wait_terminal_quiescent(terminal)
            if runtime_preexisting is not None:
                _atomic_write_bytes(runtime_destination, runtime_preexisting)
                cleanup["restored"] = (
                    file_identity(runtime_destination) == runtime_preexisting_identity
                )
            else:
                try:
                    runtime_destination.unlink()
                except FileNotFoundError:
                    pass
                cleanup["restored"] = not runtime_destination.exists()
                try:
                    runtime_destination.parent.rmdir()
                except OSError:
                    pass
        except Exception as cleanup_exc:
            cleanup["error"] = repr(cleanup_exc)
            evidence["execution_status"] = "FAILED"
            evidence["outcome"] = "NOT_PROVEN"
            evidence.setdefault("failure_classes", []).append("RUNTIME_CLEANUP_FAILED")
        evidence["runtime_cleanup"] = cleanup
        evidence["completed_at"] = farmctl.utc_now()
        atomic_write_json(evidence_path, evidence)
        if evidence.get("execution_status") == "COMPLETE":
            _render_comparison_csv(comparison_csv_path, evidence)
            _render_markdown(markdown_path, evidence)
            evidence["markdown_path"] = str(markdown_path)
            evidence["markdown_sha256"] = sha256_file(markdown_path)
            evidence["comparison_csv_sha256"] = sha256_file(comparison_csv_path)
            atomic_write_json(evidence_path, evidence)
        _completion(root, work_item_id, terminal, evidence_path, evidence)
    return {
        "action": "qm5_35005_equivalence_finished",
        "item_id": work_item_id,
        "ea_id": EA_ID,
        "terminal": terminal,
        "execution_status": evidence.get("execution_status"),
        "outcome": evidence.get("outcome"),
        "evidence_path": str(evidence_path),
        "markdown_path": evidence.get("markdown_path"),
        "no_gate_verdict": True,
    }


def _work_item_id(attempt: int) -> str:
    return str(
        uuid.uuid5(
            uuid.NAMESPACE_URL,
            f"qm://router-task/{TASK_ID}/qm5-35005-equivalence/attempt/{attempt}",
        )
    )


def _enqueue(root: Path, repo_root: Path, attempt: int) -> dict[str, Any]:
    if attempt < 1:
        raise EquivalenceError("attempt must be positive")
    paths = _paths(repo_root)
    pre = _require_file_hash(paths["pre_ex5"], PRE_EX5_SHA256, "pre-integration EX5")
    post = _require_file_hash(paths["post_ex5"], POST_EX5_SHA256, "post-integration EX5")
    source = _require_file_hash(paths["mq5"], SOURCE_SHA256, "MQ5 source")
    setfile = file_identity(paths["setfile"])
    risk = validate_risk_contract(paths["setfile"])
    compile_receipt = _load_compile_receipt(root, paths["compile_evidence"])
    git_pre = _git_pre_identity(repo_root, paths["pre_ex5"].relative_to(repo_root))
    seed_contract = _seed_contract(repo_root)
    item_id = _work_item_id(attempt)
    now = farmctl.utc_now()
    payload = {
        "equivalence_contract_version": CONTRACT_VERSION,
        "equivalence_task_id": TASK_ID,
        "source_escalation_task_id": SOURCE_ESCALATION_TASK_ID,
        "work_item_id": item_id,
        "attempt": attempt,
        "ea_label": EA_LABEL,
        "utility_phase": True,
        "no_gate_verdict": True,
        "priority_track": True,
        "diagnostic_non_admission": True,
        "diagnostic_queue_rank": 0,
        "diagnostic_allowed_terminals": [
            "T1",
            "T3",
            "T4",
            "T5",
            "T7",
            "T8",
            "T9",
            "T10",
        ],
        "avoid_terminals": ["T2", "T6"],
        "pre_ex5_path": pre.path,
        "pre_ex5_sha256": pre.sha256,
        "post_ex5_path": post.path,
        "post_ex5_sha256": post.sha256,
        "mq5_path": source.path,
        "mq5_sha256": source.sha256,
        "setfile_path": setfile.path,
        "setfile_sha256": setfile.sha256,
        "compile_work_item_id": COMPILE_WORK_ITEM_ID,
        "compile_evidence_path": compile_receipt["path"],
        "compile_evidence_sha256": compile_receipt["sha256"],
        "run_smoke_path": str(paths["run_smoke"].resolve()),
        "run_smoke_sha256": sha256_file(paths["run_smoke"]),
        "runner_path": str(Path(__file__).resolve()),
        "runner_sha256": sha256_file(Path(__file__)),
        "git_pre_identity": git_pre,
        "integration_commit": INTEGRATION_COMMIT,
        "host_symbol": SYMBOL,
        "host_timeframe": PERIOD,
        "from_date": FROM_DATE,
        "to_date": TO_DATE,
        "model": MODEL,
        "seed": RNG_SEED,
        "seed_contract": seed_contract,
        "risk_contract": risk,
        "timeout_seconds": 4200,
        "enqueued_at": now,
        "commissioned_by": f"router_ops_issue:{TASK_ID}",
    }
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        existing = conn.execute(
            "SELECT id,status,verdict,claimed_by,evidence_path,payload_json "
            "FROM work_items WHERE id=?",
            (item_id,),
        ).fetchone()
        if existing is not None:
            return {
                "enqueued": False,
                "idempotent": True,
                "work_item": dict(existing),
                "payload": json.loads(existing["payload_json"] or "{}"),
            }
        conn.execute(
            "INSERT INTO work_items "
            "(id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,"
            "payload_json,created_at,updated_at,gate_contract_version,"
            "setfile_sha256,mq5_sha256,data_window_start,data_window_end) "
            "VALUES (?,?,?,?,?,?,'pending',0,?,?,?,?,?,?,?,?)",
            (
                item_id,
                WORK_ITEM_KIND,
                QUEUE_PHASE,
                EA_ID,
                SYMBOL,
                str(paths["setfile"].resolve()),
                json.dumps(payload, sort_keys=True),
                now,
                now,
                farmctl.ACTIVE_GATE_CONTRACT_VERSION,
                setfile.sha256,
                source.sha256,
                FROM_DATE,
                TO_DATE,
            ),
        )
        conn.commit()
    return {
        "enqueued": True,
        "work_item_id": item_id,
        "phase": QUEUE_PHASE,
        "kind": WORK_ITEM_KIND,
        "payload": payload,
    }


def _status(root: Path, attempt: int) -> dict[str, Any]:
    item_id = _work_item_id(attempt)
    with farmctl.connect(root) as conn:
        row = conn.execute("SELECT * FROM work_items WHERE id=?", (item_id,)).fetchone()
    if row is None:
        return {"found": False, "work_item_id": item_id}
    value = dict(row)
    value["payload_json"] = json.loads(value.get("payload_json") or "{}")
    return {"found": True, "work_item": value}


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=farmctl.DEFAULT_ROOT)
    parser.add_argument("--repo-root", type=Path, default=farmctl.REPO_ROOT)
    subparsers = parser.add_subparsers(dest="command", required=True)
    enqueue = subparsers.add_parser("enqueue")
    enqueue.add_argument("--attempt", type=int, default=1)
    status = subparsers.add_parser("status")
    status.add_argument("--attempt", type=int, default=1)
    args = parser.parse_args(argv)
    try:
        if args.command == "enqueue":
            result = _enqueue(args.root, args.repo_root.resolve(), args.attempt)
        else:
            result = _status(args.root, args.attempt)
    except EquivalenceError as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, indent=2, sort_keys=True))
        return 2
    print(json.dumps({"ok": True, **result}, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

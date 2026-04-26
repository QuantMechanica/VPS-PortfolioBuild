#!/usr/bin/env python3
"""15-minute full dashboard refresh runner (QUAA-245).

This runner executes the complete dashboard refresh chain:
1) Rebuild full dashboard payload + HTML via generate_dashboard.py.
2) Apply live state overlay patch via refresh_dashboard_data.js.
3) Validate required DATA keys are present in the generated HTML.

Stdout emits exactly one line:
- refreshed: ...
- no change
- error: ...

Exit code is non-zero on any failed stage/validation/lock path.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


ROOT = Path(r"G:/Meine Ablage/QuantMechanica")
GENERATOR_SCRIPT = Path(
    r"C:/Users/fabia/AppData/Roaming/MetaQuotes/Terminal/"
    r"6C3C6A11D1C3791DD4DBF45421BF8028/MQL5/Files/edge_validation/output/"
    r"generate_dashboard.py"
)
GENERATOR_CWD = GENERATOR_SCRIPT.parent

OVERLAY_SCRIPT = ROOT / "Company" / "Controlling" / "refresh_dashboard_data.js"

DASHBOARD_CANONICAL = ROOT / "Dashboard" / "project_dashboard.html"
DASHBOARD_ROOT_MIRROR = ROOT / "project_dashboard.html"
DASHBOARD_MT5_MIRROR = Path(
    r"C:/Users/fabia/AppData/Roaming/MetaQuotes/Terminal/"
    r"6C3C6A11D1C3791DD4DBF45421BF8028/MQL5/Files/edge_validation/output/"
    r"project_dashboard.html"
)
LOCK_PATH = ROOT / "Company" / "scripts" / ".full_dashboard_refresh_15min.lock"

REQUIRED_DATA_KEYS = (
    "summary",
    "kpis",
    "delta_strip",
    "phase_funnel",
    "daily_trend",
    "terminals",
    "v5_construction",
    "attention_items",
    "last_check_state_snapshot",
    "refresh",
)


@dataclass
class CommandResult:
    command: list[str]
    returncode: int
    stdout: str
    stderr: str


def _run_command(command: list[str], cwd: Path | None, timeout_sec: int) -> CommandResult:
    proc = subprocess.run(
        command,
        cwd=str(cwd) if cwd else None,
        capture_output=True,
        text=True,
        timeout=timeout_sec,
    )
    return CommandResult(
        command=command,
        returncode=proc.returncode,
        stdout=proc.stdout or "",
        stderr=proc.stderr or "",
    )


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run full dashboard 15-min refresh chain.")
    parser.add_argument(
        "--python-exe",
        default=r"C:/Users/fabia/anaconda3/python.exe",
        help="Python executable used for generate_dashboard.py",
    )
    parser.add_argument(
        "--node-exe",
        default="node",
        help="Node executable used for refresh_dashboard_data.js",
    )
    parser.add_argument(
        "--generator-timeout-sec",
        type=int,
        default=900,
        help="Timeout (seconds) for full dashboard generator step",
    )
    parser.add_argument(
        "--overlay-timeout-sec",
        type=int,
        default=180,
        help="Timeout (seconds) for Controlling overlay patch step",
    )
    parser.add_argument(
        "--lock-timeout-sec",
        type=int,
        default=10,
        help="Timeout (seconds) while waiting for runner lock",
    )
    parser.add_argument(
        "--hold-lock-sec",
        type=int,
        default=0,
        help="Optional test hook: hold lock for N seconds before work",
    )
    return parser


def _file_meta(path: Path) -> dict:
    if not path.exists():
        return {"exists": False, "mtime": None, "size_bytes": None}
    stat = path.stat()
    return {"exists": True, "mtime": stat.st_mtime, "size_bytes": stat.st_size}


def _extract_data_block(html_text: str) -> dict:
    marker = "const DATA = "
    start = html_text.find(marker)
    if start < 0:
        raise RuntimeError("const DATA block not found in dashboard html")

    brace_start = html_text.find("{", start)
    if brace_start < 0:
        raise RuntimeError("DATA block opening brace not found")

    depth = 0
    in_str: str | None = None
    escape = False
    brace_end: int | None = None

    for idx in range(brace_start, len(html_text)):
        ch = html_text[idx]
        if in_str:
            if escape:
                escape = False
                continue
            if ch == "\\":
                escape = True
                continue
            if ch == in_str:
                in_str = None
            continue

        if ch in ("'", '"'):
            in_str = ch
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                brace_end = idx + 1
                break

    if brace_end is None:
        raise RuntimeError("DATA block closing brace not found")

    raw = html_text[brace_start:brace_end]
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"DATA block json parse failed: {exc}") from exc


def _missing_required_keys(payload: dict, required_keys: Iterable[str]) -> list[str]:
    return [key for key in required_keys if key not in payload]


def _parse_generator_summary(stdout: str) -> dict:
    patterns = {
        "baseline_reports": r"Baseline reports:\s+(\d+)",
        "psw_sweeps": r"PSW sweeps:\s+(\d+)",
        "ssw_sweeps": r"SSW sweeps:\s+(\d+)",
        "tsw_sweeps": r"TSW sweeps:\s+(\d+)",
        "r10_sweeps": r"R10 old sweeps:\s+(\d+)",
        "total_reports": r"Total reports:\s+(\d+)",
        "unique_eas": r"Unique EAs:\s+(\d+)",
        "pass": r"PASS:\s+(\d+)",
        "promising": r"PROMISING:\s+(\d+)",
        "fail": r"FAIL:\s+(\d+)",
    }
    out: dict[str, int] = {}
    for key, pattern in patterns.items():
        match = re.search(pattern, stdout)
        if match:
            out[key] = int(match.group(1))
    return out


def _fmt_mtime(epoch_ts: float | None) -> str:
    if epoch_ts is None:
        return "n/a"
    try:
        return time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(float(epoch_ts)))
    except Exception:
        return "n/a"


def _acquire_lock(lock_path: Path, timeout_sec: int, poll_sec: float = 0.2) -> int:
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    deadline = time.time() + max(0, timeout_sec)
    payload = f"pid={os.getpid()} started={int(time.time())}\n".encode("utf-8")
    while True:
        try:
            fd = os.open(str(lock_path), os.O_CREAT | os.O_EXCL | os.O_RDWR)
            os.write(fd, payload)
            return fd
        except FileExistsError:
            if time.time() >= deadline:
                raise TimeoutError(f"lock timeout for {lock_path}")
            time.sleep(poll_sec)


def _release_lock(fd: int | None, lock_path: Path) -> None:
    if fd is None:
        return
    try:
        os.close(fd)
    except OSError:
        pass
    try:
        lock_path.unlink()
    except FileNotFoundError:
        pass
    except OSError:
        pass


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    lock_fd: int | None = None
    try:
        lock_fd = _acquire_lock(LOCK_PATH, timeout_sec=args.lock_timeout_sec)

        # Test hook for overlap-proof: keep lock for N seconds before work.
        if args.hold_lock_sec > 0:
            time.sleep(args.hold_lock_sec)

        pre_meta = _file_meta(DASHBOARD_CANONICAL)

        if not GENERATOR_SCRIPT.is_file():
            print(f"error: missing generator: {GENERATOR_SCRIPT}")
            return 1
        if not OVERLAY_SCRIPT.is_file():
            print(f"error: missing overlay script: {OVERLAY_SCRIPT}")
            return 1

        generator_cmd = [args.python_exe, str(GENERATOR_SCRIPT), "--mode", "full"]
        try:
            generator = _run_command(generator_cmd, cwd=GENERATOR_CWD, timeout_sec=args.generator_timeout_sec)
        except subprocess.TimeoutExpired:
            print(f"error: generator timeout after {args.generator_timeout_sec}s")
            return 2
        if generator.returncode != 0:
            detail = (generator.stderr or generator.stdout).strip().splitlines()
            tail = detail[-1] if detail else f"returncode={generator.returncode}"
            print(f"error: generator failed ({tail})")
            return 2

        overlay_cmd = [args.node_exe, str(OVERLAY_SCRIPT)]
        try:
            overlay = _run_command(overlay_cmd, cwd=ROOT, timeout_sec=args.overlay_timeout_sec)
        except subprocess.TimeoutExpired:
            print(f"error: overlay timeout after {args.overlay_timeout_sec}s")
            return 3
        if overlay.returncode != 0:
            detail = (overlay.stderr or overlay.stdout).strip().splitlines()
            tail = detail[-1] if detail else f"returncode={overlay.returncode}"
            print(f"error: overlay failed ({tail})")
            return 3

        post_meta = _file_meta(DASHBOARD_CANONICAL)
        if not post_meta["exists"]:
            print(f"error: canonical dashboard missing after refresh: {DASHBOARD_CANONICAL}")
            return 4

        html_text = DASHBOARD_CANONICAL.read_text(encoding="utf-8", errors="replace")
        payload = _extract_data_block(html_text)
        missing_keys = _missing_required_keys(payload, REQUIRED_DATA_KEYS)
        if missing_keys:
            print(f"error: missing DATA keys: {','.join(missing_keys)}")
            return 5

        changed = (
            pre_meta["mtime"] != post_meta["mtime"]
            or pre_meta["size_bytes"] != post_meta["size_bytes"]
        )
        if not changed:
            print("no change")
            return 0

        generator_summary = _parse_generator_summary(generator.stdout)
        warn = ""
        if generator_summary.get("baseline_reports", -1) == 0:
            warn = " [warn: baseline_reports=0]"

        print(
            "refreshed: "
            + f"mtime {_fmt_mtime(pre_meta['mtime'])} -> {_fmt_mtime(post_meta['mtime'])}; "
            + f"size {pre_meta['size_bytes']} -> {post_meta['size_bytes']}; "
            + f"root_mirror={DASHBOARD_ROOT_MIRROR.exists()} mt5_mirror={DASHBOARD_MT5_MIRROR.exists()}"
            + warn
        )
        return 0
    except TimeoutError as exc:
        print(f"error: {exc}")
        return 6
    except RuntimeError as exc:
        print(f"error: {exc}")
        return 7
    except Exception as exc:  # defensive one-line error contract
        message = " ".join(str(exc).splitlines()).strip() or exc.__class__.__name__
        print(f"error: {message}")
        return 8
    finally:
        _release_lock(lock_fd, LOCK_PATH)


if __name__ == "__main__":
    sys.exit(main())
